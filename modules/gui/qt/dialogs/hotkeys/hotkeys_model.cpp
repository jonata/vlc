/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "hotkeys_model.hpp"

#include <QKeyEvent>

#include <algorithm>

#include <vlc_common.h>
#include <vlc_actions.h>
#include <vlc_configuration.h>
#include <vlc_modules.h>
#include <vlc_plugin.h>

#include "qt.hpp"
#include "util/vlchotkeyconverter.hpp"

namespace {

struct Group
{
    const char *name;
    QStringList prefixes;
};

// the actions are grouped after their name, the first matching group wins
const QList<Group> &groups()
{
    static const QList<Group> list = {
        { N_("Basic"), { "toggle-fullscreen", "leave-fullscreen", "position", "intf-show",
                         "intf-toggle-fscontrol", "intf-popup-menu", "intf-boss", "quit" } },
        { N_("Playback"), { "play-pause", "play", "pause", "stop", "next", "prev", "program-sid",
                            "faster", "slower", "rate-", "frame-next", "loop", "random", "record" } },
        { N_("Seeking"), { "jump", "set-bookmark", "play-bookmark" } },
        { N_("Audio"), { "vol-", "audio-track", "audiodevice", "audiodelay", "stereo", "audio" } },
        { N_("Subtitles"), { "subtitle", "subdelay", "subsync", "subpos", "spu" } },
        { N_("Video"), { "aspect-ratio", "crop", "toggle-autoscale", "zoom", "unzoom", "deinterlace",
                         "wallpaper", "video-track", "snapshot", "viewpoint", "incr-scalefactor",
                         "decr-scalefactor" } },
        { N_("Menus and Titles"), { "nav-", "disc-menu", "title-", "chapter-" } },
    };
    return list;
}

QString groupOf(const QString &action, int *order)
{
    const QList<Group> &list = groups();
    for (int i = 0; i < list.size(); ++i)
    {
        for (const QString &prefix : list[i].prefixes)
        {
            if (action.startsWith(prefix))
            {
                *order = i;
                return qtr(list[i].name);
            }
        }
    }
    *order = list.size();
    return qtr("Other");
}

} // namespace

HotkeysModel::HotkeysModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

void HotkeysModel::setCtx(MainCtx *ctx)
{
    if (m_ctx == ctx)
        return;
    m_ctx = ctx;
    emit ctxChanged();
    reload();
}

void HotkeysModel::reload()
{
    beginResetModel();

    m_actions.clear();

    module_t *main = module_get_main();
    unsigned count;
    module_config_t *config = module_config_get(main, &count);

    QHash<QString, module_config_t *> globals;
    for (unsigned i = 0; i < count; ++i)
    {
        module_config_t *item = config + i;
        if (item->i_type == CONFIG_ITEM_KEY && strncmp(item->psz_name, "global-", 7) == 0)
            globals.insert(qfu(item->psz_name + 7), item);
    }

    for (unsigned i = 0; i < count; ++i)
    {
        module_config_t *item = config + i;
        if (item->i_type != CONFIG_ITEM_KEY || strncmp(item->psz_name, "global-", 7) == 0)
            continue;

        Action action;
        action.name = qfu(item->psz_name);
        action.text = qfut(item->psz_text);
        action.description = item->psz_longtext ? qfut(item->psz_longtext) : QString();
        action.keys = qfu(item->value.psz);
        action.defaultKeys = qfu(item->orig.psz);
        action.group = groupOf(action.name.mid(4), &action.groupOrder);

        if (module_config_t *global = globals.value(action.name))
        {
            action.hasGlobal = true;
            action.globalKeys = qfu(global->value.psz);
            action.defaultGlobalKeys = qfu(global->orig.psz);
        }

        m_actions.append(action);
    }

    module_config_free(config);

    // grouped, in the order of the configuration within each group
    std::stable_sort(m_actions.begin(), m_actions.end(), [](const Action &a, const Action &b) {
        return a.groupOrder < b.groupOrder;
    });

    endResetModel();

    setModified(false);
    updateFilter();
}

void HotkeysModel::setFilterText(const QString &text)
{
    if (m_filterText == text)
        return;
    m_filterText = text;
    emit filterChanged();
    updateFilter();
}

void HotkeysModel::setFilterField(Field field)
{
    if (m_filterField == field)
        return;
    m_filterField = field;
    emit filterChanged();
    updateFilter();
}

void HotkeysModel::updateFilter()
{
    beginResetModel();

    m_rows.clear();
    const QString text = m_filterText.trimmed();
    for (int i = 0; i < m_actions.size(); ++i)
    {
        const Action &action = m_actions.at(i);
        const auto matches = [&text](const QString &value) {
            return value.contains(text, Qt::CaseInsensitive);
        };

        bool match = text.isEmpty();
        if (!match && (m_filterField == AllFields || m_filterField == ActionField))
            match = matches(action.text) || matches(action.group);
        if (!match && (m_filterField == AllFields || m_filterField == HotkeyField))
            match = matches(displayKeys(action.keys));
        if (!match && (m_filterField == AllFields || m_filterField == GlobalHotkeyField))
            match = matches(displayKeys(action.globalKeys));

        if (match)
            m_rows.append(i);
    }

    endResetModel();
    emit countChanged();
}

int HotkeysModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_rows.size();
}

QString HotkeysModel::displayKeys(const QString &keys)
{
    // several keys are separated by tabs
    QStringList list = keys.split('\t', Qt::SkipEmptyParts);
    for (QString &key : list)
    {
        QStringList parts = key.split('+');
        if (parts.last().size() == 1)
            parts.last() = parts.last().toUpper();
        key = parts.join('+');
    }
    return list.join(QStringLiteral(", "));
}

QVariant HotkeysModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_rows.size())
        return {};

    const Action &action = m_actions.at(m_rows.at(index.row()));
    switch (role)
    {
    case Qt::DisplayRole:
    case ActionRole:
        return action.text;
    case DescriptionRole:
        return action.description;
    case GroupRole:
        return action.group;
    case HotkeyRole:
        return displayKeys(action.keys);
    case GlobalHotkeyRole:
        return displayKeys(action.globalKeys);
    default:
        return {};
    }
}

QHash<int, QByteArray> HotkeysModel::roleNames() const
{
    return {
        { ActionRole, "action" },
        { DescriptionRole, "description" },
        { GroupRole, "group" },
        { HotkeyRole, "hotkey" },
        { GlobalHotkeyRole, "globalHotkey" },
    };
}

QString HotkeysModel::keyName(int key, int modifiers) const
{
    // a modifier alone is not a hotkey
    switch (key)
    {
    case Qt::Key_Shift:
    case Qt::Key_Control:
    case Qt::Key_Alt:
    case Qt::Key_Meta:
    case Qt::Key_AltGr:
        return {};
    default:
        break;
    }

    QKeyEvent event(QEvent::KeyPress, key, Qt::KeyboardModifiers(modifiers));
    const int code = qtEventToVLCKey(&event);
    if (code == KEY_UNSET)
        return {};

    char *name = vlc_keycode2str(code, false);
    if (!name)
        return {};
    const QString result = qfu(name);
    free(name);
    return result;
}

QStringList HotkeysModel::setHotkey(int row, bool global, const QString &key)
{
    if (row < 0 || row >= m_rows.size())
        return {};

    const int target = m_rows.at(row);
    Action &action = m_actions[target];
    if (global && !action.hasGlobal)
        return {};

    QStringList others;
    if (!key.isEmpty())
    {
        // a key triggers a single action
        for (int i = 0; i < m_actions.size(); ++i)
        {
            if (i == target)
                continue;
            QString &keys = global ? m_actions[i].globalKeys : m_actions[i].keys;
            QStringList list = keys.split('\t', Qt::SkipEmptyParts);
            if (list.removeAll(key) > 0)
            {
                keys = list.join('\t');
                others.append(m_actions[i].text);
            }
        }
    }

    (global ? action.globalKeys : action.keys) = key;

    setModified(true);
    updateFilter();
    return others;
}

void HotkeysModel::resetAll()
{
    for (Action &action : m_actions)
    {
        action.keys = action.defaultKeys;
        action.globalKeys = action.defaultGlobalKeys;
    }
    setModified(true);
    updateFilter();
}

void HotkeysModel::apply()
{
    for (const Action &action : m_actions)
    {
        config_PutPsz(qtu(action.name), qtu(action.keys));
        if (action.hasGlobal)
            config_PutPsz(qtu(QStringLiteral("global-") + action.name), qtu(action.globalKeys));
    }

    if (m_ctx)
        config_SaveConfigFile(m_ctx->getIntf());

    setModified(false);
}

void HotkeysModel::setModified(bool modified)
{
    if (m_modified == modified)
        return;
    m_modified = modified;
    emit modifiedChanged();
}
