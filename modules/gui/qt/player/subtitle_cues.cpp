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

#include "subtitle_cues.hpp"

#include <QCryptographicHash>
#include <QScopeGuard>

#include <algorithm>
#include <vector>

#include <vlc_common.h>
#include <vlc_demux.h>
#include <vlc_es_out.h>
#include <vlc_input_item.h>
#include <vlc_player.h>
#include <vlc_stream.h>
#include <vlc_variables.h>

#include "qt.hpp"
#include "maininterface/mainctx.hpp"
#include "player/player_controller.hpp"
#include "player/input_models.hpp"

namespace {

// cues without a duration are shown until the next one, or for this long
constexpr vlc_tick_t defaultCueLength = VLC_TICK_FROM_SEC(2);

struct Cue
{
    vlc_tick_t start;
    vlc_tick_t length;
};

/// output of the demuxer, keeping the times of the blocks of one track
struct CueOutput
{
    es_out_t out;
    int trackId;
    std::vector<Cue> cues;

    struct Track
    {
        bool wanted;
    };

    static es_out_id_t *add(es_out_t *out, input_source_t *, const es_format_t *fmt)
    {
        auto *self = container_of(out, CueOutput, out);
        auto *track = new Track{ fmt->i_cat == SPU_ES && fmt->i_id == self->trackId };
        return reinterpret_cast<es_out_id_t *>(track);
    }

    static int send(es_out_t *out, es_out_id_t *id, block_t *block)
    {
        auto *self = container_of(out, CueOutput, out);
        const auto *track = reinterpret_cast<Track *>(id);

        if (track->wanted)
        {
            const vlc_tick_t start = (block->i_pts != VLC_TICK_INVALID) ? block->i_pts : block->i_dts;
            if (start != VLC_TICK_INVALID)
                self->cues.push_back({ start - VLC_TICK_0, block->i_length });
        }

        block_Release(block);
        return VLC_SUCCESS;
    }

    static void del(es_out_t *, es_out_id_t *id)
    {
        delete reinterpret_cast<Track *>(id);
    }

    static int control(es_out_t *, input_source_t *, int query, va_list args)
    {
        switch (query)
        {
        case ES_OUT_GET_ES_STATE:
        {
            // demuxers can skip the data of the other tracks
            const auto *track = reinterpret_cast<Track *>(va_arg(args, es_out_id_t *));
            *va_arg(args, bool *) = track->wanted;
            return VLC_SUCCESS;
        }
        case ES_OUT_SET_PCR:
        case ES_OUT_SET_GROUP_PCR:
        case ES_OUT_RESET_PCR:
        case ES_OUT_SET_ES:
        case ES_OUT_SET_ES_STATE:
        case ES_OUT_SET_ES_FMT:
        case ES_OUT_SET_GROUP:
        case ES_OUT_DEL_GROUP:
        case ES_OUT_SET_GROUP_META:
        case ES_OUT_SET_GROUP_EPG:
        case ES_OUT_SET_META:
            return VLC_SUCCESS;
        default:
            return VLC_EGENERIC;
        }
    }

    static void destroy(es_out_t *)
    {
    }
};

const struct es_out_callbacks cueOutputCallbacks = {
    &CueOutput::add,
    &CueOutput::send,
    &CueOutput::del,
    &CueOutput::control,
    &CueOutput::destroy,
};

/// reads the times of the subtitles of a track, returns them sorted
std::vector<Cue> readCues(vlc_object_t *intf, const std::string &url, const char *demuxName,
                          int trackId, const std::atomic<bool> &cancelled)
{
    CueOutput output;
    output.out.cbs = &cueOutputCallbacks;
    output.trackId = trackId;

    // demuxers expect some variables of the input object they run for
    vlc_object_t *parent = static_cast<vlc_object_t *>(vlc_object_create(intf, sizeof(vlc_object_t)));
    if (!parent)
        return {};
    var_Create(parent, "sub-original-fps", VLC_VAR_FLOAT);

    const auto release = qScopeGuard([parent]() { vlc_object_delete(parent); });

    stream_t *stream = vlc_stream_NewURL(parent, url.c_str());
    if (!stream)
        return {};

    demux_t *demux = demux_New(parent, demuxName, url.c_str(), stream, &output.out);
    if (!demux && strcmp(demuxName, "any") != 0)
        demux = demux_New(parent, "any", url.c_str(), stream, &output.out);
    if (!demux)
    {
        vlc_stream_Delete(stream);
        return {};
    }

    while (!cancelled && demux_Demux(demux) == VLC_DEMUXER_SUCCESS)
        ;

    demux_Delete(demux);

    std::vector<Cue> cues = std::move(output.cues);
    std::sort(cues.begin(), cues.end(), [](const Cue &a, const Cue &b) { return a.start < b.start; });

    for (size_t i = 0; i < cues.size(); ++i)
    {
        if (cues[i].length > 0)
            continue;
        cues[i].length = defaultCueLength;
        if (i + 1 < cues.size())
            cues[i].length = std::min(cues[i].length, cues[i + 1].start - cues[i].start);
    }
    return cues;
}

} // namespace

SubtitleCues::SubtitleCues(QObject *parent)
    : QObject(parent)
{
}

SubtitleCues::~SubtitleCues()
{
    stop();
}

void SubtitleCues::setCtx(MainCtx *ctx)
{
    if (m_ctx == ctx)
        return;

    if (m_ctx)
    {
        PlayerController *player = m_ctx->getIntf()->p_mainPlayerController;
        disconnect(player, nullptr, this, nullptr);
        disconnect(player->getSubtitleTracks(), nullptr, this, nullptr);
    }

    m_ctx = ctx;

    if (m_ctx)
    {
        PlayerController *player = m_ctx->getIntf()->p_mainPlayerController;
        TrackListModel *tracks = player->getSubtitleTracks();

        connect(player, &PlayerController::inputChanged, this, &SubtitleCues::refresh);
        connect(tracks, &QAbstractItemModel::dataChanged, this, &SubtitleCues::refresh);
        connect(tracks, &QAbstractItemModel::modelReset, this, &SubtitleCues::refresh);
        connect(tracks, &QAbstractItemModel::rowsInserted, this, &SubtitleCues::refresh);
        connect(tracks, &QAbstractItemModel::rowsRemoved, this, &SubtitleCues::refresh);
    }

    emit ctxChanged();
    refresh();
}

void SubtitleCues::setActive(bool active)
{
    if (m_active == active)
        return;
    m_active = active;
    emit activeChanged();
    refresh();
}

void SubtitleCues::refresh()
{
    if (!m_ctx || !m_active)
    {
        stop();
        reset();
        return;
    }

    qt_intf_t *intf = m_ctx->getIntf();
    vlc_player_t *player = intf->p_mainPlayerController->getPlayer();

    // find the source of the selected track: its string identifier starts
    // with the MD5 sum of the URL of the subtitle file it comes from, or with
    // the category for the tracks of the media itself
    std::string url;
    const char *demuxName = "any";
    int trackId = -1;
    {
        vlc_player_locker lock{player};

        const vlc_player_track *track = vlc_player_GetSelectedTrack(player, SPU_ES);
        input_item_t *media = vlc_player_GetCurrentMedia(player);
        if (track && media)
        {
            const QString strId = QString::fromUtf8(vlc_es_id_GetStrId(track->es_id));
            const QStringList parts = strId.split('/');

            bool ok = false;
            trackId = parts.last().toInt(&ok);
            if (!ok || parts.contains(QLatin1String("cc")))
                trackId = -1;

            if (trackId >= 0 && parts.first() == QLatin1String("spu"))
            {
                char *uri = input_item_GetURI(media);
                if (uri)
                    url = uri;
                free(uri);
            }
            else if (trackId >= 0)
            {
                vlc_mutex_locker itemLock(&media->lock);
                for (int i = 0; i < media->i_slaves; ++i)
                {
                    const input_item_slave_t *slave = media->pp_slaves[i];
                    const QByteArray hash = QCryptographicHash::hash(QByteArray(slave->psz_uri),
                                                                     QCryptographicHash::Md5).toHex();
                    if (QString::fromLatin1(hash) == parts.first())
                    {
                        url = slave->psz_uri;
                        if (slave->i_type == SLAVE_TYPE_SPU)
                            demuxName = "subtitle";
                        break;
                    }
                }
            }
        }
    }

    // reading a remote media would download it entirely
    const QUrl qurl(QString::fromStdString(url));
    if (!qurl.isLocalFile())
        url.clear();

    const QString key = url.empty() ? QString() : QString::fromStdString(url) + '#' + QString::number(trackId);
    if (key == m_key)
        return;

    stop();
    reset();
    m_key = key;

    if (url.empty())
        return;

    const quint64 generation = ++m_generation;
    auto cancelled = std::make_shared<std::atomic<bool>>(false);
    m_cancelled = cancelled;

    vlc_object_t *parent = VLC_OBJECT(intf);
    QPointer<SubtitleCues> self = this;
    m_thread = std::thread([=]() {
        const std::vector<Cue> cues = readCues(parent, url, demuxName, trackId, *cancelled);
        if (*cancelled)
            return;

        QList<qreal> times;
        times.reserve(cues.size() * 2);
        for (const Cue &cue : cues)
        {
            times.append(MS_FROM_VLC_TICK(cue.start));
            times.append(MS_FROM_VLC_TICK(cue.start + cue.length));
        }

        QMetaObject::invokeMethod(self, [self, generation, times = std::move(times)]() mutable {
            if (self)
                self->onRead(generation, std::move(times));
        }, Qt::QueuedConnection);
    });
}

void SubtitleCues::stop()
{
    if (m_cancelled)
        *m_cancelled = true;
    if (m_thread.joinable())
        m_thread.join();
    m_cancelled.reset();
    m_key.clear();
}

void SubtitleCues::reset()
{
    if (!m_cues.isEmpty())
    {
        m_cues.clear();
        emit cuesChanged();
    }
    if (m_ready)
    {
        m_ready = false;
        emit readyChanged();
    }
}

void SubtitleCues::onRead(quint64 generation, QList<qreal> cues)
{
    if (generation != m_generation)
        return;

    m_cues = std::move(cues);
    m_ready = true;
    emit cuesChanged();
    emit readyChanged();
}
