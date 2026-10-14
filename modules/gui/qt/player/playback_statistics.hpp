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

#ifndef VLC_QT_PLAYBACK_STATISTICS_HPP
#define VLC_QT_PLAYBACK_STATISTICS_HPP

#include <QObject>
#include <QPointer>
#include <QElapsedTimer>
#include <QSize>

#include "player_controller.hpp"

/**
 * Statistics of the current playback, as shown over the video.
 *
 * The values follow the statistics of the player, which are updated about
 * once per second while playing.
 */
class PlaybackStatistics : public QObject
{
    Q_OBJECT

    Q_PROPERTY(PlayerController* player READ player WRITE setPlayer NOTIFY playerChanged FINAL)

    // in kb/s
    Q_PROPERTY(qreal inputBitrate MEMBER m_inputBitrate NOTIFY updated FINAL)
    Q_PROPERTY(qreal contentBitrate MEMBER m_contentBitrate NOTIFY updated FINAL)

    Q_PROPERTY(QString videoCodec MEMBER m_videoCodec NOTIFY updated FINAL)
    Q_PROPERTY(QSize videoSize MEMBER m_videoSize NOTIFY updated FINAL)
    Q_PROPERTY(QString audioCodec MEMBER m_audioCodec NOTIFY updated FINAL)
    Q_PROPERTY(int audioRate MEMBER m_audioRate NOTIFY updated FINAL)
    Q_PROPERTY(int audioChannels MEMBER m_audioChannels NOTIFY updated FINAL)

    // displayed pictures per second
    Q_PROPERTY(qreal frameRate MEMBER m_frameRate NOTIFY updated FINAL)
    Q_PROPERTY(qint64 displayedPictures MEMBER m_displayedPictures NOTIFY updated FINAL)
    Q_PROPERTY(qint64 latePictures MEMBER m_latePictures NOTIFY updated FINAL)
    Q_PROPERTY(qint64 lostPictures MEMBER m_lostPictures NOTIFY updated FINAL)
    Q_PROPERTY(qint64 lostAudioBuffers MEMBER m_lostAudioBuffers NOTIFY updated FINAL)

public:
    explicit PlaybackStatistics(QObject *parent = nullptr);

    PlayerController *player() const { return m_player; }
    void setPlayer(PlayerController *player);

signals:
    void playerChanged();
    void updated();

private:
    void onStatisticsUpdated(const input_stats_t &stats);
    void updateFormats();

    QPointer<PlayerController> m_player;

    qreal m_inputBitrate = 0.;
    qreal m_contentBitrate = 0.;

    QString m_videoCodec;
    QSize m_videoSize;
    QString m_audioCodec;
    int m_audioRate = 0;
    int m_audioChannels = 0;

    qreal m_frameRate = 0.;
    qint64 m_displayedPictures = 0;
    qint64 m_latePictures = 0;
    qint64 m_lostPictures = 0;
    qint64 m_lostAudioBuffers = 0;

    QElapsedTimer m_frameRateTimer;
};

#endif // VLC_QT_PLAYBACK_STATISTICS_HPP
