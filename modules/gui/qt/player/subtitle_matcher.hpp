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

#ifndef VLC_QT_SUBTITLE_MATCHER_HPP
#define VLC_QT_SUBTITLE_MATCHER_HPP

#include <QAbstractListModel>
#include <QPointer>
#include <QStringList>
#include <QUrl>

#include "maininterface/mainctx.hpp"

/**
 * Subtitle files to add to a media, to the videos of its folder, or to the
 * videos of the play queue.
 *
 * With the file scope, the rows are the subtitle files of the subtitle
 * folder, several of them can be checked. With the other scopes, the rows
 * are the videos, each matched with one of the subtitle files.
 *
 * The choices are saved, so that the subtitles are added again whenever the
 * videos are played (see SubtitleLoader).
 */
class SubtitleMatcher : public QAbstractListModel
{
    Q_OBJECT

    Q_PROPERTY(MainCtx* ctx READ ctx WRITE setCtx NOTIFY ctxChanged FINAL)
    Q_PROPERTY(Scope scope READ scope WRITE setScope NOTIFY scopeChanged FINAL)
    // the current media, whose folder is the default subtitle folder
    Q_PROPERTY(QUrl media READ media WRITE setMedia NOTIFY mediaChanged FINAL)
    Q_PROPERTY(QUrl subtitleFolder READ subtitleFolder WRITE setSubtitleFolder NOTIFY subtitleFolderChanged FINAL)
    // names of the subtitle files of the subtitle folder
    Q_PROPERTY(QStringList subtitleNames READ subtitleNames NOTIFY subtitlesChanged FINAL)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged FINAL)
    // whether saving would add any subtitle
    Q_PROPERTY(bool hasSelection READ hasSelection NOTIFY selectionChanged FINAL)

public:
    enum Scope {
        FileScope,
        FolderScope,
        PlaylistScope
    };
    Q_ENUM(Scope)

    enum Roles {
        NameRole = Qt::UserRole + 1,
        CheckedRole,     // file scope: whether the subtitle file is added
        SubtitleRole,    // other scopes: index of the matched subtitle file, -1 if none
        SubtitleNameRole
    };

    explicit SubtitleMatcher(QObject *parent = nullptr);

    MainCtx *ctx() const { return m_ctx; }
    void setCtx(MainCtx *ctx);

    Scope scope() const { return m_scope; }
    void setScope(Scope scope);

    QUrl media() const { return m_media; }
    void setMedia(const QUrl &media);

    QUrl subtitleFolder() const { return m_subtitleFolder; }
    void setSubtitleFolder(const QUrl &folder);

    QStringList subtitleNames() const;

    bool hasSelection() const;

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    /// file scope: checks or unchecks a subtitle file
    Q_INVOKABLE void toggle(int row);
    /// other scopes: matches a video with a subtitle file, -1 for none
    Q_INVOKABLE void setSubtitle(int row, int subtitle);

    /// asks for the subtitle folder
    Q_INVOKABLE void chooseFolder();

    /// saves the choices and adds the subtitles to the current media
    Q_INVOKABLE void save();

    /// key of the episode in a file name ("s01e02", "e12"...), empty if none
    static QString episodeKey(const QString &fileName);

signals:
    void ctxChanged();
    void scopeChanged();
    void mediaChanged();
    void subtitleFolderChanged();
    void subtitlesChanged();
    void countChanged();
    void selectionChanged();

private:
    struct Row
    {
        QUrl url;
        QString name;
        bool checked = false;
        int subtitle = -1;
    };

    void reload();
    QList<QUrl> playlistVideos() const;
    int bestSubtitle(const QString &videoName) const;

    QPointer<MainCtx> m_ctx;
    Scope m_scope = FileScope;
    QUrl m_media;
    QUrl m_subtitleFolder;

    QList<QUrl> m_subtitles;
    QList<Row> m_rows;
};

/**
 * Adds the subtitles saved for a media whenever it is played.
 */
class SubtitleLoader : public QObject
{
    Q_OBJECT

    Q_PROPERTY(MainCtx* ctx READ ctx WRITE setCtx NOTIFY ctxChanged FINAL)

public:
    explicit SubtitleLoader(QObject *parent = nullptr);

    MainCtx *ctx() const { return m_ctx; }
    void setCtx(MainCtx *ctx);

    /// subtitle files saved for a media
    static QList<QUrl> subtitles(qt_intf_t *intf, const QUrl &media);
    /// saves the subtitle files of medias, replacing the previous ones
    static void setSubtitles(qt_intf_t *intf, const QHash<QUrl, QList<QUrl>> &subtitles);
    /// adds the saved subtitles of the current media which are not loaded yet
    static void load(qt_intf_t *intf);

signals:
    void ctxChanged();

private:
    QPointer<MainCtx> m_ctx;
};

#endif // VLC_QT_SUBTITLE_MATCHER_HPP
