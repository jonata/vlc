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

#ifndef VLC_QT_SUBTITLE_CUES_HPP
#define VLC_QT_SUBTITLE_CUES_HPP

#include <QObject>
#include <QPointer>
#include <QList>
#include <QString>

#include <atomic>
#include <memory>
#include <thread>

#include "maininterface/mainctx.hpp"

/**
 * Times of the subtitles of the selected subtitle track.
 *
 * The track is read again from its source (the media, or the subtitle file
 * added to it) in a background thread, as the player only gives the
 * subtitles as they are displayed.
 */
class SubtitleCues : public QObject
{
    Q_OBJECT

    Q_PROPERTY(MainCtx* ctx READ ctx WRITE setCtx NOTIFY ctxChanged FINAL)
    // the cues are only read while active
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged FINAL)
    // start and end of each cue, in milliseconds: [start0, end0, start1, end1, ...]
    Q_PROPERTY(QList<qreal> cues READ cues NOTIFY cuesChanged FINAL)
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged FINAL)

public:
    explicit SubtitleCues(QObject *parent = nullptr);
    ~SubtitleCues() override;

    MainCtx *ctx() const { return m_ctx; }
    void setCtx(MainCtx *ctx);

    bool active() const { return m_active; }
    void setActive(bool active);

    const QList<qreal> &cues() const { return m_cues; }
    bool ready() const { return m_ready; }

signals:
    void ctxChanged();
    void activeChanged();
    void cuesChanged();
    void readyChanged();

private:
    struct Reader;

    void refresh();
    void stop();
    void reset();
    void onRead(quint64 generation, QList<qreal> cues);

    QPointer<MainCtx> m_ctx;
    bool m_active = false;

    QList<qreal> m_cues;
    bool m_ready = false;

    // source and track of the cues
    QString m_key;

    quint64 m_generation = 0;
    std::shared_ptr<std::atomic<bool>> m_cancelled;
    std::thread m_thread;
};

#endif // VLC_QT_SUBTITLE_CUES_HPP
