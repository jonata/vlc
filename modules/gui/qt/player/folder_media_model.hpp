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

#ifndef VLC_QT_FOLDER_MEDIA_MODEL_HPP
#define VLC_QT_FOLDER_MEDIA_MODEL_HPP

#include <QAbstractListModel>
#include <QUrl>
#include <QVector>

/**
 * Subfolders and media files of a local folder, the folders first, sorted
 * by name in natural order.
 */
class FolderMediaModel : public QAbstractListModel
{
    Q_OBJECT

    Q_PROPERTY(QUrl folder READ folder WRITE setFolder NOTIFY folderChanged FINAL)
    Q_PROPERTY(QString folderName READ folderName NOTIFY folderChanged FINAL)
    // invalid if the folder is the root
    Q_PROPERTY(QUrl parentFolder READ parentFolder NOTIFY folderChanged FINAL)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged FINAL)

public:
    enum Roles {
        UrlRole = Qt::UserRole + 1,
        IsFolderRole,
        IsAudioRole
    };

    explicit FolderMediaModel(QObject *parent = nullptr);

    QUrl folder() const { return m_folder; }
    void setFolder(const QUrl &folder);

    QString folderName() const;
    QUrl parentFolder() const;

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    /// the folder containing a local media file
    Q_INVOKABLE static QUrl folderOf(const QUrl &file);

signals:
    void folderChanged();
    void countChanged();

private:
    struct Entry
    {
        QString name;
        QUrl url;
        bool isFolder;
        bool isAudio;
    };

    void reload();

    QUrl m_folder;
    QVector<Entry> m_entries;
};

#endif // VLC_QT_FOLDER_MEDIA_MODEL_HPP
