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

#ifndef VLC_QT_SEEK_THUMBNAILER_HPP
#define VLC_QT_SEEK_THUMBNAILER_HPP

#include <QObject>
#include <QPointer>
#include <QTemporaryDir>
#include <QUrl>

#include "maininterface/mainctx.hpp"

extern "C" {
    typedef struct vlc_preparser_t vlc_preparser_t;
    typedef struct vlc_preparser_req vlc_preparser_req;
}

/**
 * Generates the thumbnails shown while hovering the seek bar, for local
 * video files.
 *
 * Only one thumbnail is generated at a time, the position requested in the
 * meantime is generated next.
 */
class SeekThumbnailer : public QObject
{
    Q_OBJECT

    Q_PROPERTY(MainCtx* ctx READ ctx WRITE setCtx NOTIFY ctxChanged FINAL)
    // media to generate the thumbnails from, disabled when empty
    Q_PROPERTY(QUrl url READ url WRITE setUrl NOTIFY urlChanged FINAL)
    // last generated thumbnail, a local image file
    Q_PROPERTY(QUrl thumbnail READ thumbnail NOTIFY thumbnailChanged FINAL)
    // position of the last generated thumbnail, from 0 to 1
    Q_PROPERTY(double thumbnailPosition READ thumbnailPosition NOTIFY thumbnailChanged FINAL)

public:
    explicit SeekThumbnailer(QObject *parent = nullptr);
    ~SeekThumbnailer() override;

    MainCtx *ctx() const { return m_ctx; }
    void setCtx(MainCtx *ctx);

    QUrl url() const { return m_url; }
    void setUrl(const QUrl &url);

    QUrl thumbnail() const { return m_thumbnail; }
    double thumbnailPosition() const { return m_thumbnailPosition; }

    /// requests the thumbnail at a position, from 0 to 1
    Q_INVOKABLE void request(double position);

signals:
    void ctxChanged();
    void urlChanged();
    void thumbnailChanged();

private:
    void reset();
    void submit(double position);
    void onEnded(vlc_preparser_req *req, bool success);

    static void onEndedCallback(vlc_preparser_req *req, int status,
                                const bool *results, size_t count, void *data);

    QPointer<MainCtx> m_ctx;
    QUrl m_url;

    vlc_preparser_t *m_preparser = nullptr;
    vlc_preparser_req *m_request = nullptr;
    double m_requestPosition = 0.;
    QString m_requestFile;
    double m_pendingPosition = -1.;

    QTemporaryDir m_dir;
    int m_counter = 0;

    QUrl m_thumbnail;
    double m_thumbnailPosition = -1.;
};

#endif // VLC_QT_SEEK_THUMBNAILER_HPP
