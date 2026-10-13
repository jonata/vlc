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

#ifndef VLC_QT_AUDIO_WAVEFORM_HPP
#define VLC_QT_AUDIO_WAVEFORM_HPP

#include <QObject>
#include <QPointer>
#include <QTimer>
#include <QUrl>

#include <memory>

#include "maininterface/mainctx.hpp"

struct WaveformAnalysis;

/**
 * Computes the waveform of a local audio file, to be drawn on the seek bar.
 *
 * The file is decoded as fast as possible by a separate player, using the
 * stream output, and the peaks are published progressively.
 */
class AudioWaveform : public QObject
{
    Q_OBJECT

    Q_PROPERTY(MainCtx* ctx READ ctx WRITE setCtx NOTIFY ctxChanged FINAL)
    // local file to analyze, analysis is stopped when empty
    Q_PROPERTY(QUrl url READ url WRITE setUrl NOTIFY urlChanged FINAL)
    // peak of each bar, from 0 to 1
    Q_PROPERTY(QList<qreal> peaks READ peaks NOTIFY peaksChanged FINAL)
    // the whole file has been analyzed
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged FINAL)

public:
    static constexpr int barCount = 300;

    explicit AudioWaveform(QObject *parent = nullptr);
    ~AudioWaveform() override;

    MainCtx *ctx() const { return m_ctx; }
    void setCtx(MainCtx *ctx);

    QUrl url() const { return m_url; }
    void setUrl(const QUrl &url);

    QList<qreal> peaks() const { return m_peaks; }
    bool ready() const { return m_ready; }

signals:
    void ctxChanged();
    void urlChanged();
    void peaksChanged();
    void readyChanged();

private:
    friend struct WaveformAnalysis;

    void start();
    void stop();
    void publish();
    void finish(WaveformAnalysis *analysis);

    QPointer<MainCtx> m_ctx;
    QUrl m_url;
    QList<qreal> m_peaks;
    bool m_ready = false;

    std::unique_ptr<WaveformAnalysis> m_analysis;
    QTimer m_publishTimer;
};

#endif // VLC_QT_AUDIO_WAVEFORM_HPP
