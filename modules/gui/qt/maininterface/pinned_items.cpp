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

#include "pinned_items.hpp"

#include <QSettings>

#include "medialibrary/mlqmltypes.hpp"
#include "network/networkmediamodel.hpp"

#include <vlc_media_source.h>

namespace {

const QString settingKey = QStringLiteral("SideNavigation/pinned");

} // namespace

PinnedItems::PinnedItems(QSettings *settings, QObject *parent)
    : QObject(parent)
    , m_settings(settings)
{
    if (m_settings)
        m_items = m_settings->value(settingKey).toList();
}

bool PinnedItems::isPinned(const QString &key) const
{
    for (const QVariant &item : m_items)
    {
        if (item.toMap().value(QStringLiteral("key")).toString() == key)
            return true;
    }
    return false;
}

void PinnedItems::pin(const QString &key, const QString &title, const QString &icon,
                      const QStringList &path, const QVariantMap &props)
{
    if (key.isEmpty() || isPinned(key))
        return;

    m_items.append(QVariantMap {
        { QStringLiteral("key"), key },
        { QStringLiteral("title"), title },
        { QStringLiteral("icon"), icon },
        { QStringLiteral("path"), path },
        { QStringLiteral("props"), props },
    });
    save();
}

void PinnedItems::unpin(const QString &key)
{
    const qsizetype count = m_items.size();
    m_items.removeIf([&key](const QVariant &item) {
        return item.toMap().value(QStringLiteral("key")).toString() == key;
    });
    if (m_items.size() != count)
        save();
}

QVariantMap PinnedItems::pageProps(int index) const
{
    if (index < 0 || index >= m_items.size())
        return {};

    QVariantMap props = m_items.at(index).toMap().value(QStringLiteral("props")).toMap();

    // the identifier of an item of the media library is saved as text
    const auto parentId = props.find(QStringLiteral("parentId"));
    if (parentId != props.end())
        *parentId = QVariant::fromValue(MLItemId::fromString(parentId->toString()));

    // a folder that is browsed is saved as its address, its tree is built
    // again, as for the folders of the user (see StandardPathModel)
    const auto folderUrl = props.find(QStringLiteral("folderUrl"));
    if (folderUrl != props.end())
    {
        const QUrl url = folderUrl->toUrl();
        const QString title = m_items.at(index).toMap().value(QStringLiteral("title")).toString();
        props.erase(folderUrl);

        input_item_t *item = input_item_NewDirectory(qtu(url.toString(QUrl::FullyEncoded)), qtu(title),
                                                     url.isLocalFile() ? ITEM_LOCAL : ITEM_NET);
        if (item)
        {
            MediaTreePtr tree(vlc_media_tree_New(), false);
            if (tree)
            {
                MediaTreeLocker lock{tree};
                vlc_media_tree_Add(tree.get(), &tree->root, item);
            }
            if (tree)
                props.insert(QStringLiteral("tree"),
                             QVariant::fromValue(NetworkTreeItem(tree, SharedInputItem(item, false))));
            else
                input_item_Release(item);
        }
    }

    return props;
}

void PinnedItems::save()
{
    if (m_settings)
        m_settings->setValue(settingKey, m_items);
    emit itemsChanged();
}
