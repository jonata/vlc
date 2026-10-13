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

#include "player_settings.hpp"

#include <cmath>

#include <vlc_common.h>
#include <vlc_aout.h>
#include <vlc_configuration.h>
#include <vlc_player.h>
#include <vlc_variables.h>
#include <vlc_vout.h>

#include "qt.hpp"
#include "player_controller.hpp"

#include "../../../audio_filter/equalizer_presets.h"

namespace {

/// adds or removes a module from a filter chain, such as "video-filter"
QString changeFilterChain(const QString &chain, const char *module, bool add)
{
    QStringList list = chain.split(':', Qt::SkipEmptyParts);
    const QString name = qfu(module);

    if (add && !list.contains(name))
        list << name;
    else if (!add)
        list.removeAll(name);

    return list.join(':');
}

QString configString(const char *name)
{
    char *value = config_GetPsz(name);
    const QString result = qfu(value ? value : "");
    free(value);
    return result;
}

bool chainContains(const QString &chain, const char *module)
{
    return chain.split(':', Qt::SkipEmptyParts).contains(qfu(module));
}

constexpr float floatEpsilon = 0.001f;

} // namespace

//
// VideoAdjust
//

VideoAdjust::VideoAdjust(QObject *parent)
    : QObject(parent)
{
    m_enabled = chainContains(configString("video-filter"), "adjust");

    m_contrast = config_GetFloat("contrast");
    m_brightness = config_GetFloat("brightness");
    m_hue = config_GetFloat("hue");
    m_saturation = config_GetFloat("saturation");
    m_gamma = config_GetFloat("gamma");
}

void VideoAdjust::setPlayer(PlayerController *player)
{
    if (m_player == player)
        return;
    m_player = player;
    emit playerChanged();
}

void VideoAdjust::setEnabled(bool enabled)
{
    if (m_enabled == enabled)
        return;
    m_enabled = enabled;

    // start from the chain of the current video output, if any, as other
    // filters may have been enabled for it only
    QString chain = configString("video-filter");
    if (m_player)
    {
        if (const auto vout = m_player->getVout(); vout != nullptr)
        {
            char *value = var_GetString(vout.get(), "video-filter");
            chain = qfu(value ? value : "");
            free(value);
        }
    }

    chain = changeFilterChain(chain, "adjust", enabled);
    config_PutPsz("video-filter", qtu(chain));

    if (m_player)
    {
        for (const auto &vout : m_player->getVouts())
            var_SetString(vout.get(), "video-filter", qtu(chain));
    }

    emit enabledChanged();
}

void VideoAdjust::setValue(const char *name, float &member, float value)
{
    if (std::fabs(member - value) < floatEpsilon)
        return;
    member = value;

    config_PutFloat(name, value);

    if (m_player)
    {
        // the variables only exist on the video outputs using the filter
        for (const auto &vout : m_player->getVouts())
            var_SetFloat(vout.get(), name, value);
    }

    emit valuesChanged();

    // changing a value is meant to be seen
    setEnabled(true);
}

void VideoAdjust::reset()
{
    setContrast(1.f);
    setBrightness(1.f);
    setHue(0.f);
    setSaturation(1.f);
    setGamma(1.f);
    setEnabled(false);
}

//
// AudioEqualizer
//

AudioEqualizer::AudioEqualizer(QObject *parent)
    : QObject(parent)
{
    m_enabled = chainContains(configString("audio-filter"), "equalizer");
    m_preamp = config_GetFloat("equalizer-preamp");

    const QStringList bands = configString("equalizer-bands").split(' ', Qt::SkipEmptyParts);
    for (int i = 0; i < EQZ_BANDS_MAX; ++i)
        m_bands.append((i < bands.size()) ? bands[i].toFloat() : 0.f);

    const QString preset = configString("equalizer-preset");
    for (int i = 0; i < NB_PRESETS; ++i)
    {
        if (preset == qfu(preset_list[i]))
        {
            m_preset = i;
            break;
        }
    }
}

void AudioEqualizer::setPlayer(PlayerController *player)
{
    if (m_player == player)
        return;
    m_player = player;
    emit playerChanged();
}

void AudioEqualizer::setEnabled(bool enabled)
{
    if (m_enabled == enabled)
        return;
    m_enabled = enabled;

    config_PutPsz("audio-filter",
                  qtu(changeFilterChain(configString("audio-filter"), "equalizer", enabled)));

    if (m_player)
        vlc_player_aout_EnableFilter(m_player->getPlayer(), "equalizer", enabled);

    emit enabledChanged();
}

void AudioEqualizer::setPreamp(float value)
{
    if (std::fabs(m_preamp - value) < floatEpsilon)
        return;
    m_preamp = value;

    config_PutFloat("equalizer-preamp", value);

    if (m_player)
    {
        if (const auto aout = m_player->getAout(); aout != nullptr)
            var_SetFloat(aout.get(), "equalizer-preamp", value);
    }

    emit preampChanged();
    setEnabled(true);
}

QVariantList AudioEqualizer::bands() const
{
    QVariantList list;
    for (const float band : m_bands)
        list.append(band);
    return list;
}

QStringList AudioEqualizer::bandNames() const
{
    if (config_GetInt("equalizer-vlcfreqs"))
        return { qtr("60 Hz"), qtr("170 Hz"), qtr("310 Hz"), qtr("600 Hz"), qtr("1 KHz"),
                 qtr("3 KHz"), qtr("6 KHz"), qtr("12 KHz"), qtr("14 KHz"), qtr("16 KHz") };

    return { qtr("31 Hz"), qtr("63 Hz"), qtr("125 Hz"), qtr("250 Hz"), qtr("500 Hz"),
             qtr("1 KHz"), qtr("2 KHz"), qtr("4 KHz"), qtr("8 KHz"), qtr("16 KHz") };
}

QStringList AudioEqualizer::presetNames() const
{
    QStringList names;
    for (int i = 0; i < NB_PRESETS; ++i)
        names.append(qfut(preset_list_text[i]));
    return names;
}

void AudioEqualizer::setBand(int index, float value)
{
    if (index < 0 || index >= m_bands.size())
        return;
    if (std::fabs(m_bands[index] - value) < floatEpsilon)
        return;

    m_bands[index] = value;
    applyBands();

    if (m_preset != -1)
    {
        m_preset = -1;
        emit presetChanged();
    }

    emit bandsChanged();
    setEnabled(true);
}

void AudioEqualizer::applyPreset(int index)
{
    if (index < 0 || index >= NB_PRESETS)
        return;

    const eqz_preset_t &preset = eqz_preset_10b[index];

    for (int i = 0; i < m_bands.size() && i < preset.i_band; ++i)
        m_bands[i] = preset.f_amp[i];

    config_PutPsz("equalizer-preset", preset_list[index]);

    if (m_player)
    {
        if (const auto aout = m_player->getAout(); aout != nullptr)
            var_SetString(aout.get(), "equalizer-preset", preset_list[index]);
    }

    applyBands();
    emit bandsChanged();

    // setPreamp() enables the equalizer
    m_preset = index;
    setPreamp(preset.f_preamp);
    emit presetChanged();
    setEnabled(true);
}

void AudioEqualizer::applyBands()
{
    QStringList values;
    for (const float band : m_bands)
        values.append(QString::number(band, 'f', 1));
    const QString bands = values.join(' ');

    config_PutPsz("equalizer-bands", qtu(bands));

    if (m_player)
    {
        if (const auto aout = m_player->getAout(); aout != nullptr)
            var_SetString(aout.get(), "equalizer-bands", qtu(bands));
    }
}
