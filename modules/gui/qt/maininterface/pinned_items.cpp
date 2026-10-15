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

    return props;
}

void PinnedItems::save()
{
    if (m_settings)
        m_settings->setValue(settingKey, m_items);
    emit itemsChanged();
}
