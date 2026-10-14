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

#include "subtitle_matcher.hpp"

#include <QCollator>
#include <QDir>
#include <QFileDialog>
#include <QFileInfo>
#include <QRegularExpression>
#include <QSet>
#include <QSettings>

#include <algorithm>

#include <vlc_common.h>
#include <vlc_input_item.h>
#include <vlc_interface.h>
#include <vlc_player.h>
#include <vlc_playlist.h>

#include "qt.hpp"
#include "player/player_controller.hpp"

namespace {

const QString associationsKey = QStringLiteral("SubtitleAssociations/medias");

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

const QSet<QString> &subtitleExtensions()
{
    // the list is given as "*.srt;*.ass;..."
    static const QSet<QString> extensions = []() {
        QSet<QString> set;
        const QStringList patterns = QString::fromLatin1(EXTENSIONS_SUBTITLE).split(';', Qt::SkipEmptyParts);
        for (const QString &pattern : patterns)
            set.insert(pattern.mid(pattern.indexOf('.') + 1).toLower());
        return set;
    }();
    return extensions;
}

QList<QUrl> filesOf(const QUrl &folder, const QSet<QString> &extensions)
{
    if (!folder.isLocalFile())
        return {};

    QFileInfoList infos = QDir(folder.toLocalFile()).entryInfoList(QDir::Files | QDir::Readable);

    // natural order, so that episode 2 comes before episode 10
    QCollator collator;
    collator.setNumericMode(true);
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    std::sort(infos.begin(), infos.end(), [&collator](const QFileInfo &a, const QFileInfo &b) {
        return collator.compare(a.fileName(), b.fileName()) < 0;
    });

    QList<QUrl> files;
    for (const QFileInfo &info : infos)
    {
        if (extensions.contains(info.suffix().toLower()))
            files.append(QUrl::fromLocalFile(info.absoluteFilePath()));
    }
    return files;
}

QString fileName(const QUrl &url)
{
    return QFileInfo(url.toLocalFile()).fileName();
}

QString baseName(const QUrl &url)
{
    return QFileInfo(url.toLocalFile()).completeBaseName();
}

// lower case letters and digits only, to compare names
QString normalized(const QString &name)
{
    QString result;
    for (const QChar c : name)
    {
        if (c.isLetterOrNumber())
            result.append(c.toLower());
    }
    return result;
}

} // namespace

//
// SubtitleMatcher
//

SubtitleMatcher::SubtitleMatcher(QObject *parent)
    : QAbstractListModel(parent)
{
}

void SubtitleMatcher::setCtx(MainCtx *ctx)
{
    if (m_ctx == ctx)
        return;
    m_ctx = ctx;
    emit ctxChanged();
    reload();
}

void SubtitleMatcher::setScope(Scope scope)
{
    if (m_scope == scope)
        return;
    m_scope = scope;
    emit scopeChanged();
    reload();
}

void SubtitleMatcher::setMedia(const QUrl &media)
{
    if (m_media == media)
        return;
    m_media = media;
    emit mediaChanged();

    if (m_media.isLocalFile())
        setSubtitleFolder(QUrl::fromLocalFile(QFileInfo(m_media.toLocalFile()).absolutePath()));
    else
        reload();
}

void SubtitleMatcher::setSubtitleFolder(const QUrl &folder)
{
    if (m_subtitleFolder == folder)
        return;
    m_subtitleFolder = folder;
    emit subtitleFolderChanged();
    reload();
}

QStringList SubtitleMatcher::subtitleNames() const
{
    QStringList names;
    for (const QUrl &url : m_subtitles)
        names.append(fileName(url));
    return names;
}

bool SubtitleMatcher::hasSelection() const
{
    return std::any_of(m_rows.cbegin(), m_rows.cend(), [this](const Row &row) {
        return (m_scope == FileScope) ? row.checked : row.subtitle >= 0;
    });
}

int SubtitleMatcher::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_rows.size();
}

QVariant SubtitleMatcher::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_rows.size())
        return {};

    const Row &row = m_rows.at(index.row());
    switch (role)
    {
    case Qt::DisplayRole:
    case NameRole:
        return row.name;
    case CheckedRole:
        return row.checked;
    case SubtitleRole:
        return row.subtitle;
    case SubtitleNameRole:
        return (row.subtitle >= 0) ? fileName(m_subtitles.at(row.subtitle)) : QString();
    default:
        return {};
    }
}

QHash<int, QByteArray> SubtitleMatcher::roleNames() const
{
    return {
        { NameRole, "name" },
        { CheckedRole, "checked" },
        { SubtitleRole, "subtitle" },
        { SubtitleNameRole, "subtitleName" },
    };
}

void SubtitleMatcher::toggle(int row)
{
    if (m_scope != FileScope || row < 0 || row >= m_rows.size())
        return;
    m_rows[row].checked = !m_rows[row].checked;
    emit dataChanged(index(row), index(row), { CheckedRole });
    emit selectionChanged();
}

void SubtitleMatcher::setSubtitle(int row, int subtitle)
{
    if (m_scope == FileScope || row < 0 || row >= m_rows.size())
        return;
    if (subtitle < -1 || subtitle >= m_subtitles.size())
        subtitle = -1;
    m_rows[row].subtitle = subtitle;
    emit dataChanged(index(row), index(row), { SubtitleRole, SubtitleNameRole });
    emit selectionChanged();
}

void SubtitleMatcher::chooseFolder()
{
    const QUrl folder = QFileDialog::getExistingDirectoryUrl(nullptr, qtr("Subtitle folder"), m_subtitleFolder);
    if (!folder.isEmpty())
        setSubtitleFolder(folder);
}

QString SubtitleMatcher::episodeKey(const QString &fileName)
{
    // S01E02, 1x02, E02 or Ep 2, the numbers without their leading zeros
    static const QRegularExpression seasonEpisode(QStringLiteral("(?:^|[^a-z0-9])s(\\d{1,3})[ ._-]?e(\\d{1,4})"),
                                                  QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression crossed(QStringLiteral("(?:^|[^a-z0-9])(\\d{1,2})x(\\d{1,3})(?:[^0-9]|$)"),
                                            QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression episode(QStringLiteral("(?:^|[^a-z0-9])(?:e|ep|episode)[ ._-]?(\\d{1,4})(?:[^0-9]|$)"),
                                            QRegularExpression::CaseInsensitiveOption);

    QRegularExpressionMatch match = seasonEpisode.match(fileName);
    if (!match.hasMatch())
        match = crossed.match(fileName);
    if (match.hasMatch())
        return QStringLiteral("s%1e%2").arg(match.captured(1).toInt()).arg(match.captured(2).toInt());

    match = episode.match(fileName);
    if (match.hasMatch())
        return QStringLiteral("e%1").arg(match.captured(1).toInt());
    return {};
}

int SubtitleMatcher::bestSubtitle(const QString &videoName) const
{
    // the same episode
    const QString key = episodeKey(videoName);
    if (!key.isEmpty())
    {
        for (qsizetype i = 0; i < m_subtitles.size(); ++i)
        {
            const QString subtitleKey = episodeKey(fileName(m_subtitles.at(i)));
            if (subtitleKey == key)
                return i;
            // "e3" matches "s01e03" when the video has no season
            if (key.startsWith('e') && subtitleKey.endsWith(key))
                return i;
        }
    }

    // a name starting with the name of the video
    const QString name = normalized(videoName);
    for (qsizetype i = 0; i < m_subtitles.size(); ++i)
    {
        if (normalized(baseName(m_subtitles.at(i))).startsWith(name))
            return i;
    }
    return -1;
}

QList<QUrl> SubtitleMatcher::playlistVideos() const
{
    if (!m_ctx)
        return {};

    QList<QUrl> videos;
    vlc_playlist_t *playlist = m_ctx->getIntf()->p_playlist;
    vlc_playlist_Lock(playlist);
    const size_t count = vlc_playlist_Count(playlist);
    for (size_t i = 0; i < count; ++i)
    {
        input_item_t *media = vlc_playlist_item_GetMedia(vlc_playlist_Get(playlist, i));
        char *uri = input_item_GetURI(media);
        const QUrl url(QString::fromUtf8(uri));
        free(uri);
        if (url.isLocalFile() && videoExtensions().contains(QFileInfo(url.toLocalFile()).suffix().toLower()))
            videos.append(url);
    }
    vlc_playlist_Unlock(playlist);
    return videos;
}

void SubtitleMatcher::reload()
{
    beginResetModel();

    m_subtitles = filesOf(m_subtitleFolder, subtitleExtensions());
    m_rows.clear();

    if (m_scope == FileScope)
    {
        // the subtitles named after the media are checked
        const QString mediaName = m_media.isLocalFile() ? normalized(baseName(m_media)) : QString();
        const QString mediaKey = m_media.isLocalFile() ? episodeKey(fileName(m_media)) : QString();
        for (const QUrl &url : m_subtitles)
        {
            Row row;
            row.url = url;
            row.name = fileName(url);
            row.checked = !mediaName.isEmpty()
                       && (normalized(baseName(url)).startsWith(mediaName)
                           || (!mediaKey.isEmpty() && episodeKey(row.name) == mediaKey));
            m_rows.append(row);
        }
    }
    else
    {
        const QList<QUrl> videos = (m_scope == FolderScope)
            ? filesOf(QUrl::fromLocalFile(QFileInfo(m_media.toLocalFile()).absolutePath()), videoExtensions())
            : playlistVideos();

        for (const QUrl &url : videos)
        {
            Row row;
            row.url = url;
            row.name = fileName(url);
            row.subtitle = bestSubtitle(baseName(url));
            m_rows.append(row);
        }
    }

    endResetModel();

    emit subtitlesChanged();
    emit countChanged();
    emit selectionChanged();
}

void SubtitleMatcher::save()
{
    if (!m_ctx)
        return;

    QHash<QUrl, QList<QUrl>> subtitles;
    if (m_scope == FileScope)
    {
        if (!m_media.isLocalFile())
            return;
        QList<QUrl> &files = subtitles[m_media];
        for (const Row &row : m_rows)
        {
            if (row.checked)
                files.append(row.url);
        }
    }
    else
    {
        for (const Row &row : m_rows)
            subtitles[row.url] = (row.subtitle >= 0) ? QList<QUrl>{ m_subtitles.at(row.subtitle) } : QList<QUrl>{};
    }

    qt_intf_t *intf = m_ctx->getIntf();
    SubtitleLoader::setSubtitles(intf, subtitles);
    SubtitleLoader::load(intf);
}

//
// SubtitleLoader
//

SubtitleLoader::SubtitleLoader(QObject *parent)
    : QObject(parent)
{
}

void SubtitleLoader::setCtx(MainCtx *ctx)
{
    if (m_ctx == ctx)
        return;

    if (m_ctx)
        disconnect(m_ctx->getIntf()->p_mainPlayerController, nullptr, this, nullptr);

    m_ctx = ctx;

    if (m_ctx)
    {
        connect(m_ctx->getIntf()->p_mainPlayerController, &PlayerController::inputChanged, this, [this](bool hasInput) {
            if (hasInput && m_ctx)
                load(m_ctx->getIntf());
        });
        load(m_ctx->getIntf());
    }

    emit ctxChanged();
}

QList<QUrl> SubtitleLoader::subtitles(qt_intf_t *intf, const QUrl &media)
{
    const QVariantMap all = intf->mainSettings->value(associationsKey).toMap();
    QList<QUrl> files;
    for (const QVariant &file : all.value(media.toString(QUrl::FullyEncoded)).toList())
        files.append(file.toUrl());
    return files;
}

void SubtitleLoader::setSubtitles(qt_intf_t *intf, const QHash<QUrl, QList<QUrl>> &subtitles)
{
    QVariantMap all = intf->mainSettings->value(associationsKey).toMap();
    for (auto it = subtitles.cbegin(); it != subtitles.cend(); ++it)
    {
        const QString key = it.key().toString(QUrl::FullyEncoded);
        if (it.value().isEmpty())
        {
            all.remove(key);
            continue;
        }
        QVariantList files;
        for (const QUrl &file : it.value())
            files.append(file);
        all.insert(key, files);
    }
    intf->mainSettings->setValue(associationsKey, all);
}

void SubtitleLoader::load(qt_intf_t *intf)
{
    vlc_player_t *player = intf->p_player;

    QUrl media;
    QSet<QString> loaded;
    {
        vlc_player_locker lock{player};
        input_item_t *item = vlc_player_GetCurrentMedia(player);
        if (!item)
            return;

        char *uri = input_item_GetURI(item);
        media = QUrl(QString::fromUtf8(uri));
        free(uri);

        vlc_mutex_locker itemLock(&item->lock);
        for (int i = 0; i < item->i_slaves; ++i)
            loaded.insert(QUrl(QString::fromUtf8(item->pp_slaves[i]->psz_uri)).toString(QUrl::FullyEncoded));
    }

    const QList<QUrl> files = subtitles(intf, media);
    bool first = true;
    for (const QUrl &file : files)
    {
        const QString uri = file.toString(QUrl::FullyEncoded);
        if (loaded.contains(uri) || !QFileInfo::exists(file.toLocalFile()))
            continue;

        // the first added subtitle is selected
        vlc_player_locker lock{player};
        vlc_player_AddAssociatedMedia(player, SPU_ES, qtu(uri), first, false, false);
        first = false;
    }
}
