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

#ifndef VLC_QT_PINNED_ITEMS_HPP
#define VLC_QT_PINNED_ITEMS_HPP

#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

class QSettings;

/**
 * Pages of the library pinned to the side navigation, such as playlists or
 * folders of videos.
 *
 * Each item is a map with:
 * - key: identifies the item, to unpin it or know whether it is pinned
 * - title: shown in the side navigation
 * - icon: an icon of the icon font
 * - path: path of the page in the navigation history
 * - props: properties of the page, the "parentId" is a serialized MLItemId
 */
class PinnedItems : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QVariantList items READ items NOTIFY itemsChanged FINAL)

public:
    explicit PinnedItems(QSettings *settings, QObject *parent = nullptr);

    QVariantList items() const { return m_items; }

    Q_INVOKABLE bool isPinned(const QString &key) const;
    Q_INVOKABLE void pin(const QString &key, const QString &title, const QString &icon,
                         const QStringList &path, const QVariantMap &props = {});
    Q_INVOKABLE void unpin(const QString &key);

    /// properties of the page of an item, to navigate to it
    Q_INVOKABLE QVariantMap pageProps(int index) const;

signals:
    void itemsChanged();

private:
    void save();

    QSettings *m_settings;
    QVariantList m_items;
};

#endif // VLC_QT_PINNED_ITEMS_HPP
