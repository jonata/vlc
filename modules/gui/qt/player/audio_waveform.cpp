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

#include "audio_waveform.hpp"

#include <algorithm>
#include <cmath>
#include <mutex>
#include <vector>

#include <vlc_common.h>
#include <vlc_input_item.h>
#include <vlc_player.h>
#include <vlc_tick.h>

#include "qt.hpp"
#include "maininterface/mainctx.hpp"

namespace {

// duration covered by each stored peak
constexpr vlc_tick_t peakInterval = VLC_TICK_FROM_MS(50);

// the audio is downmixed to a low sample rate, which is enough for peaks
constexpr int analysisSampleRate = 8000;

} // namespace

/**
 * State shared with the stream output and player callbacks, which are
 * called from other threads.
 */
struct WaveformAnalysis
{
    AudioWaveform *owner = nullptr;
    vlc_player_t *player = nullptr;
    vlc_player_listener_id *listener = nullptr;

    std::mutex lock;
    std::vector<float> peaks; // one peak per peakInterval
    vlc_tick_t length = 0;
    bool finished = false;

    // only used by the stream output thread
    std::vector<uint8_t> buffer;

    static void prerender(void *data, uint8_t **buffer, size_t size)
    {
        auto analysis = static_cast<WaveformAnalysis *>(data);
        analysis->buffer.resize(size);
        *buffer = analysis->buffer.data();
    }

    static void postrender(void *data, uint8_t *pcm, unsigned channels, unsigned rate,
                           unsigned samples, unsigned bitsPerSample, size_t, vlc_tick_t pts)
    {
        auto analysis = static_cast<WaveformAnalysis *>(data);
        if (bitsPerSample != 32 || channels == 0 || rate == 0)
            return;

        const auto values = reinterpret_cast<const float *>(pcm);
        const vlc_tick_t start = pts - VLC_TICK_0;

        std::lock_guard<std::mutex> guard(analysis->lock);
        for (unsigned i = 0; i < samples; ++i)
        {
            const vlc_tick_t time = start + vlc_tick_from_samples(i, rate);
            if (time < 0)
                continue;

            const size_t index = time / peakInterval;
            if (index >= analysis->peaks.size())
                analysis->peaks.resize(index + 1, 0.f);

            float peak = 0.f;
            for (unsigned c = 0; c < channels; ++c)
                peak = std::max(peak, std::fabs(values[i * channels + c]));
            analysis->peaks[index] = std::max(analysis->peaks[index], peak);
        }
    }

    static void onLengthChanged(vlc_player_t *, vlc_tick_t length, void *data)
    {
        auto analysis = static_cast<WaveformAnalysis *>(data);
        std::lock_guard<std::mutex> guard(analysis->lock);
        analysis->length = length;
    }

    static void onStateChanged(vlc_player_t *, enum vlc_player_state state, void *data)
    {
        if (state != VLC_PLAYER_STATE_STOPPED)
            return;

        auto analysis = static_cast<WaveformAnalysis *>(data);
        {
            std::lock_guard<std::mutex> guard(analysis->lock);
            if (analysis->finished)
                return;
            analysis->finished = true;
        }

        // the player can not be deleted from its own callbacks
        QMetaObject::invokeMethod(analysis->owner, [owner = analysis->owner, analysis]() {
            owner->finish(analysis);
        }, Qt::QueuedConnection);
    }
};

void AudioWaveform::finish(WaveformAnalysis *analysis)
{
    if (m_analysis.get() != analysis)
        return; // a newer analysis was started

    publish();
    stop();

    if (!m_ready)
    {
        m_ready = true;
        emit readyChanged();
    }
}

AudioWaveform::AudioWaveform(QObject *parent)
    : QObject(parent)
{
    m_publishTimer.setInterval(250);
    connect(&m_publishTimer, &QTimer::timeout, this, &AudioWaveform::publish);
}

AudioWaveform::~AudioWaveform()
{
    stop();
}

void AudioWaveform::setCtx(MainCtx *ctx)
{
    if (m_ctx == ctx)
        return;
    m_ctx = ctx;
    emit ctxChanged();
    start();
}

void AudioWaveform::setUrl(const QUrl &url)
{
    if (m_url == url)
        return;
    m_url = url;
    emit urlChanged();
    start();
}

void AudioWaveform::start()
{
    stop();

    if (!m_peaks.isEmpty())
    {
        m_peaks.clear();
        emit peaksChanged();
    }
    if (m_ready)
    {
        m_ready = false;
        emit readyChanged();
    }

    // analyzing a remote media would download it entirely
    if (!m_ctx || !m_url.isLocalFile())
        return;

    auto analysis = std::make_unique<WaveformAnalysis>();
    analysis->owner = this;

    vlc_object_t *parent = VLC_OBJECT(m_ctx->getIntf());
    analysis->player = vlc_player_New(parent, VLC_PLAYER_LOCK_NORMAL);
    if (!analysis->player)
        return;

    input_item_t *item = input_item_New(qtu(m_url.toString(QUrl::FullyEncoded)), nullptr);
    if (!item)
    {
        vlc_player_Delete(analysis->player);
        return;
    }

    const QString sout = QStringLiteral(
        ":sout=#transcode{acodec=f32l,channels=1,samplerate=%1}"
        ":smem{audio-prerender-callback=%2,audio-postrender-callback=%3,audio-data=%4,no-time-sync}")
        .arg(analysisSampleRate)
        .arg(reinterpret_cast<intptr_t>(&WaveformAnalysis::prerender))
        .arg(reinterpret_cast<intptr_t>(&WaveformAnalysis::postrender))
        .arg(reinterpret_cast<intptr_t>(analysis.get()));

    input_item_AddOption(item, qtu(sout), VLC_INPUT_OPTION_TRUSTED);
    input_item_AddOption(item, ":no-sout-video", VLC_INPUT_OPTION_TRUSTED);
    input_item_AddOption(item, ":no-sout-spu", VLC_INPUT_OPTION_TRUSTED);
    input_item_AddOption(item, ":no-sub-autodetect-file", VLC_INPUT_OPTION_TRUSTED);

    static const struct vlc_player_cbs callbacks = []() {
        struct vlc_player_cbs cbs = {};
        cbs.on_state_changed = &WaveformAnalysis::onStateChanged;
        cbs.on_length_changed = &WaveformAnalysis::onLengthChanged;
        return cbs;
    }();

    vlc_player_Lock(analysis->player);
    analysis->listener = vlc_player_AddListener(analysis->player, &callbacks, analysis.get());
    int ret = vlc_player_SetCurrentMedia(analysis->player, item);
    if (ret == VLC_SUCCESS)
        ret = vlc_player_Start(analysis->player);
    vlc_player_Unlock(analysis->player);

    input_item_Release(item);

    m_analysis = std::move(analysis);

    if (ret != VLC_SUCCESS)
    {
        stop();
        return;
    }

    m_publishTimer.start();
}

void AudioWaveform::stop()
{
    m_publishTimer.stop();

    if (!m_analysis)
        return;

    std::unique_ptr<WaveformAnalysis> analysis = std::move(m_analysis);

    vlc_player_Lock(analysis->player);
    if (analysis->listener)
        vlc_player_RemoveListener(analysis->player, analysis->listener);
    vlc_player_Stop(analysis->player);
    vlc_player_Unlock(analysis->player);

    // waits for the input, so that the callbacks are not called anymore
    vlc_player_Delete(analysis->player);
}

void AudioWaveform::publish()
{
    if (!m_analysis)
        return;

    std::vector<float> stored;
    vlc_tick_t length;
    {
        std::lock_guard<std::mutex> guard(m_analysis->lock);
        stored = m_analysis->peaks;
        length = m_analysis->length;
    }

    if (length <= 0 || stored.empty())
        return;

    const size_t total = std::max<size_t>(1, length / peakInterval);

    QList<qreal> bars(barCount, 0.0);
    float maximum = 0.f;
    for (size_t i = 0; i < stored.size(); ++i)
    {
        const int bar = std::min<size_t>(barCount - 1, i * barCount / total);
        bars[bar] = std::max<qreal>(bars[bar], stored[i]);
        maximum = std::max(maximum, stored[i]);
    }

    // normalized, so that quiet files are visible as well
    if (maximum > 0.f)
    {
        for (qreal &bar : bars)
            bar /= maximum;
    }

    m_peaks = bars;
    emit peaksChanged();
}
