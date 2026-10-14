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

#include "folder_media_model.hpp"

#include <QCollator>
#include <QDir>
#include <QFileInfo>
#include <QSet>

#include <algorithm>

#include <vlc_common.h>
#include <vlc_interface.h>

namespace {

const QSet<QString> &audioExtensions()
{
    static const QSet<QString> extensions = []() {
        QSet<QString> set;
        for (const char *extension : { EXTENSIONS_AUDIO_CSV })
            set.insert(QString::fromLatin1(extension));
        return set;
    }();
    return extensions;
}

const QSet<QString> &videoExtensions()
{
    static const QSet<QString> extensions = []() {
        QSet<QString> set;
        for (const char *extension : { EXTENSIONS_VIDEO_CSV })
            set.insert(QString::fromLatin1(extension));
        return set;
    }();
    return extensions;
}

} // namespace

FolderMediaModel::FolderMediaModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

void FolderMediaModel::setFolder(const QUrl &folder)
{
    if (m_folder == folder)
        return;
    m_folder = folder;
    reload();
    emit folderChanged();
}

QString FolderMediaModel::folderName() const
{
    if (!m_folder.isLocalFile())
        return {};

    const QString name = QDir(m_folder.toLocalFile()).dirName();
    return name.isEmpty() ? m_folder.toLocalFile() : name;
}

QUrl FolderMediaModel::parentFolder() const
{
    if (!m_folder.isLocalFile())
        return {};

    QDir dir(m_folder.toLocalFile());
    if (!dir.cdUp())
        return {};
    return QUrl::fromLocalFile(dir.absolutePath());
}

QUrl FolderMediaModel::folderOf(const QUrl &file)
{
    if (!file.isLocalFile())
        return {};
    return QUrl::fromLocalFile(QFileInfo(file.toLocalFile()).absolutePath());
}

int FolderMediaModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_entries.size();
}

QVariant FolderMediaModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_entries.size())
        return {};

    const Entry &entry = m_entries[index.row()];
    switch (role)
    {
    case Qt::DisplayRole:
        return entry.name;
    case UrlRole:
        return entry.url;
    case IsFolderRole:
        return entry.isFolder;
    case IsAudioRole:
        return entry.isAudio;
    default:
        return {};
    }
}

QHash<int, QByteArray> FolderMediaModel::roleNames() const
{
    return {
        { Qt::DisplayRole, "display" },
        { UrlRole, "url" },
        { IsFolderRole, "isFolder" },
        { IsAudioRole, "isAudio" }
    };
}

void FolderMediaModel::reload()
{
    const int previousCount = m_entries.size();

    beginResetModel();
    m_entries.clear();

    if (m_folder.isLocalFile())
    {
        const QDir dir(m_folder.toLocalFile());
        const QFileInfoList infos = dir.entryInfoList(QDir::AllDirs | QDir::Files | QDir::NoDotAndDotDot
                                                      | QDir::Readable);

        for (const QFileInfo &info : infos)
        {
            if (info.isHidden())
                continue;

            if (info.isDir())
            {
                m_entries.append({ info.fileName(), QUrl::fromLocalFile(info.absoluteFilePath()), true, false });
                continue;
            }

            const QString extension = info.suffix().toLower();
            const bool isAudio = audioExtensions().contains(extension);
            if (!isAudio && !videoExtensions().contains(extension))
                continue;

            m_entries.append({ info.fileName(), QUrl::fromLocalFile(info.absoluteFilePath()), false, isAudio });
        }

        // folders first, then "Episode 2" before "Episode 10"
        QCollator collator;
        collator.setNumericMode(true);
        collator.setCaseSensitivity(Qt::CaseInsensitive);
        std::sort(m_entries.begin(), m_entries.end(), [&collator](const Entry &a, const Entry &b) {
            if (a.isFolder != b.isFolder)
                return a.isFolder;
            return collator.compare(a.name, b.name) < 0;
        });
    }

    endResetModel();

    if (m_entries.size() != previousCount)
        emit countChanged();
}
