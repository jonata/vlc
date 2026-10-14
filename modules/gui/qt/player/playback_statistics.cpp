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

#include "playback_statistics.hpp"

#include <vlc_common.h>
#include <vlc_player.h>
#include <vlc_es.h>

namespace {

QString codecName(vlc_fourcc_t codec)
{
    const char *description = vlc_fourcc_GetDescription(UNKNOWN_ES, codec);
    if (description && *description)
        return QString::fromUtf8(description);

    char name[5] = {};
    vlc_fourcc_to_char(codec, name);
    return QString::fromLatin1(name).trimmed();
}

} // namespace

PlaybackStatistics::PlaybackStatistics(QObject *parent)
    : QObject(parent)
{
}

void PlaybackStatistics::setPlayer(PlayerController *player)
{
    if (m_player == player)
        return;

    if (m_player)
        disconnect(m_player, nullptr, this, nullptr);

    m_player = player;

    if (m_player)
        connect(m_player, &PlayerController::statisticsUpdated,
                this, &PlaybackStatistics::onStatisticsUpdated);

    m_frameRateTimer.invalidate();
    emit playerChanged();
}

void PlaybackStatistics::onStatisticsUpdated(const input_stats_t &stats)
{
    // the player gives bitrates in bytes per millisecond
    m_inputBitrate = stats.f_input_bitrate * 8000;
    m_contentBitrate = stats.f_demux_bitrate * 8000;

    const qint64 displayed = static_cast<qint64>(stats.i_displayed_pictures);
    if (m_frameRateTimer.isValid() && displayed >= m_displayedPictures)
    {
        const qint64 elapsed = m_frameRateTimer.restart();
        if (elapsed > 0)
            m_frameRate = (displayed - m_displayedPictures) * 1000. / elapsed;
    }
    else
    {
        m_frameRateTimer.start();
        m_frameRate = 0.;
    }

    m_displayedPictures = displayed;
    m_latePictures = static_cast<qint64>(stats.i_late_pictures);
    m_lostPictures = static_cast<qint64>(stats.i_lost_pictures);
    m_lostAudioBuffers = static_cast<qint64>(stats.i_lost_abuffers);

    updateFormats();

    emit updated();
}

void PlaybackStatistics::updateFormats()
{
    m_videoCodec.clear();
    m_videoSize = {};
    m_audioCodec.clear();
    m_audioRate = 0;
    m_audioChannels = 0;

    if (!m_player)
        return;

    vlc_player_t *player = m_player->getPlayer();
    vlc_player_locker lock{player};

    if (const vlc_player_track *track = vlc_player_GetSelectedTrack(player, VIDEO_ES))
    {
        const video_format_t &video = track->fmt.video;
        m_videoCodec = codecName(track->fmt.i_codec);
        m_videoSize = QSize(video.i_visible_width, video.i_visible_height);
    }

    if (const vlc_player_track *track = vlc_player_GetSelectedTrack(player, AUDIO_ES))
    {
        m_audioCodec = codecName(track->fmt.i_codec);
        m_audioRate = track->fmt.audio.i_rate;
        m_audioChannels = track->fmt.audio.i_channels;
    }
}
