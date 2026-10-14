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

#include "seek_thumbnailer.hpp"

#include <QFile>

#include <vlc_common.h>
#include <vlc_input_item.h>
#include <vlc_preparser.h>

#include "qt.hpp"

namespace {

constexpr int thumbnailWidth = 240;
constexpr vlc_tick_t thumbnailTimeout = VLC_TICK_FROM_SEC(5);

} // namespace

SeekThumbnailer::SeekThumbnailer(QObject *parent)
    : QObject(parent)
{
}

SeekThumbnailer::~SeekThumbnailer()
{
    reset();
    if (m_preparser)
        vlc_preparser_Delete(m_preparser);
}

void SeekThumbnailer::setCtx(MainCtx *ctx)
{
    if (m_ctx == ctx)
        return;
    m_ctx = ctx;
    emit ctxChanged();
}

void SeekThumbnailer::setUrl(const QUrl &url)
{
    if (m_url == url)
        return;
    m_url = url;
    reset();
    emit urlChanged();
}

void SeekThumbnailer::reset()
{
    m_pendingPosition = -1.;

    if (m_request)
    {
        // the request is released once it has ended
        vlc_preparser_Cancel(m_preparser, m_request);
    }

    if (!m_thumbnail.isEmpty())
    {
        QFile::remove(m_thumbnail.toLocalFile());
        m_thumbnail.clear();
        m_thumbnailPosition = -1.;
        emit thumbnailChanged();
    }
}

void SeekThumbnailer::request(double position)
{
    // generating thumbnails of a remote media would be too slow
    if (!m_ctx || !m_url.isLocalFile() || !m_dir.isValid())
        return;

    position = std::clamp(position, 0., 1.);

    if (m_request)
    {
        // generated once the current request has ended
        m_pendingPosition = position;
        return;
    }

    submit(position);
}

void SeekThumbnailer::submit(double position)
{
    if (!m_preparser)
    {
        const struct vlc_preparser_cfg cfg = {
            .types = VLC_PREPARSER_TYPE_THUMBNAIL_TO_FILES,
            .max_parser_threads = 0,
            .max_thumbnailer_threads = 1,
            .timeout = thumbnailTimeout,
            // the thumbnails of local files are generated in process
            .external_process = false,
        };
        m_preparser = vlc_preparser_New(VLC_OBJECT(m_ctx->getIntf()), &cfg);
        if (!m_preparser)
            return;
    }

    input_item_t *item = input_item_New(qtu(m_url.toString(QUrl::FullyEncoded)), nullptr);
    if (!item)
        return;

    m_requestFile = m_dir.filePath(QStringLiteral("thumbnail-%1.png").arg(m_counter++));
    const QByteArray path = m_requestFile.toUtf8();

    struct vlc_thumbnailer_arg arg = {};
    arg.seek.type = vlc_thumbnailer_arg::seek::VLC_THUMBNAILER_SEEK_POS;
    arg.seek.pos = position;
    arg.seek.speed = vlc_thumbnailer_arg::seek::VLC_THUMBNAILER_SEEK_FAST;
    arg.hw_dec = false;

    struct vlc_thumbnailer_output output = {};
    output.format = VLC_THUMBNAILER_FORMAT_PNG;
    output.width = thumbnailWidth;
    output.height = 0; // keeps the aspect ratio
    output.crop = false;
    output.file_path = path.constData();
    output.creat_mode = 0600;

    static const struct vlc_thumbnailer_to_files_cbs cbs = {
        .on_ended = &SeekThumbnailer::onEndedCallback,
    };

    vlc_preparser_req *req = vlc_preparser_req_NewThumbnailToFiles(m_preparser, item, &arg,
                                                                   &output, 1, &cbs, this);
    input_item_Release(item);
    if (!req)
        return;

    m_request = req;
    m_requestPosition = position;

    if (vlc_preparser_Submit(m_preparser, req) != VLC_SUCCESS)
    {
        vlc_preparser_req_Release(req);
        m_request = nullptr;
    }
}

void SeekThumbnailer::onEndedCallback(vlc_preparser_req *req, int status,
                                      const bool *results, size_t count, void *data)
{
    auto that = static_cast<SeekThumbnailer *>(data);
    const bool success = (status == VLC_SUCCESS) && count > 0 && results[0];

    // called from the preparser thread
    QMetaObject::invokeMethod(that, [that, req, success]() {
        that->onEnded(req, success);
    }, Qt::QueuedConnection);
}

void SeekThumbnailer::onEnded(vlc_preparser_req *req, bool success)
{
    if (req != m_request)
        return;

    vlc_preparser_req_Release(req);
    m_request = nullptr;

    if (success)
    {
        if (!m_thumbnail.isEmpty())
            QFile::remove(m_thumbnail.toLocalFile());

        m_thumbnail = QUrl::fromLocalFile(m_requestFile);
        m_thumbnailPosition = m_requestPosition;
        emit thumbnailChanged();
    }
    else
    {
        QFile::remove(m_requestFile);
    }

    if (m_pendingPosition >= 0.)
    {
        const double position = m_pendingPosition;
        m_pendingPosition = -1.;
        submit(position);
    }
}
