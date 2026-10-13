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

#ifndef VLC_QT_PLAYER_SETTINGS_HPP
#define VLC_QT_PLAYER_SETTINGS_HPP

#include <QColor>
#include <QObject>
#include <QPointer>
#include <QStringList>
#include <QVariantList>

#include "player_controller.hpp"

/**
 * Image adjustments of the video outputs, using the "adjust" video filter.
 *
 * Changes apply to the current video outputs and are kept in the
 * configuration, so that the next video outputs use them as well.
 */
class VideoAdjust : public QObject
{
    Q_OBJECT

    Q_PROPERTY(PlayerController* player READ player WRITE setPlayer NOTIFY playerChanged FINAL)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged FINAL)
    Q_PROPERTY(float contrast READ contrast WRITE setContrast NOTIFY valuesChanged FINAL)
    Q_PROPERTY(float brightness READ brightness WRITE setBrightness NOTIFY valuesChanged FINAL)
    Q_PROPERTY(float hue READ hue WRITE setHue NOTIFY valuesChanged FINAL)
    Q_PROPERTY(float saturation READ saturation WRITE setSaturation NOTIFY valuesChanged FINAL)
    Q_PROPERTY(float gamma READ gamma WRITE setGamma NOTIFY valuesChanged FINAL)

public:
    explicit VideoAdjust(QObject *parent = nullptr);

    PlayerController *player() const { return m_player; }
    void setPlayer(PlayerController *player);

    bool enabled() const { return m_enabled; }
    void setEnabled(bool enabled);

    float contrast() const { return m_contrast; }
    float brightness() const { return m_brightness; }
    float hue() const { return m_hue; }
    float saturation() const { return m_saturation; }
    float gamma() const { return m_gamma; }

    void setContrast(float value) { setValue("contrast", m_contrast, value); }
    void setBrightness(float value) { setValue("brightness", m_brightness, value); }
    void setHue(float value) { setValue("hue", m_hue, value); }
    void setSaturation(float value) { setValue("saturation", m_saturation, value); }
    void setGamma(float value) { setValue("gamma", m_gamma, value); }

    /// restores the neutral values and disables the filter
    Q_INVOKABLE void reset();

signals:
    void playerChanged();
    void enabledChanged();
    void valuesChanged();

private:
    void setValue(const char *name, float &member, float value);

    QPointer<PlayerController> m_player;

    bool m_enabled = false;
    float m_contrast = 1.f;
    float m_brightness = 1.f;
    float m_hue = 0.f;
    float m_saturation = 1.f;
    float m_gamma = 1.f;
};

/**
 * Audio equalizer of the player audio output.
 */
class AudioEqualizer : public QObject
{
    Q_OBJECT

    Q_PROPERTY(PlayerController* player READ player WRITE setPlayer NOTIFY playerChanged FINAL)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged FINAL)
    Q_PROPERTY(float preamp READ preamp WRITE setPreamp NOTIFY preampChanged FINAL)
    Q_PROPERTY(QVariantList bands READ bands NOTIFY bandsChanged FINAL)
    Q_PROPERTY(QStringList bandNames READ bandNames CONSTANT FINAL)
    Q_PROPERTY(QStringList presetNames READ presetNames CONSTANT FINAL)
    // index of the applied preset, -1 when the bands were changed by hand
    Q_PROPERTY(int preset READ preset NOTIFY presetChanged FINAL)

public:
    explicit AudioEqualizer(QObject *parent = nullptr);

    PlayerController *player() const { return m_player; }
    void setPlayer(PlayerController *player);

    bool enabled() const { return m_enabled; }
    void setEnabled(bool enabled);

    float preamp() const { return m_preamp; }
    void setPreamp(float value);

    QVariantList bands() const;
    QStringList bandNames() const;
    QStringList presetNames() const;
    int preset() const { return m_preset; }

    Q_INVOKABLE void setBand(int index, float value);
    Q_INVOKABLE void applyPreset(int index);

signals:
    void playerChanged();
    void enabledChanged();
    void preampChanged();
    void bandsChanged();
    void presetChanged();

private:
    void applyBands();

    QPointer<PlayerController> m_player;

    bool m_enabled = false;
    float m_preamp = 0.f;
    QList<float> m_bands;
    int m_preset = -1;
};

/**
 * Style of the subtitles rendered by VLC (text renderer and video output
 * options).
 *
 * These options are read again each time a subtitle is rendered, so that
 * changes apply to the subtitles currently shown. The text scale is set on
 * the player, which has its own value.
 */
class SubtitleStyle : public QObject
{
    Q_OBJECT

    Q_PROPERTY(PlayerController* player READ player WRITE setPlayer NOTIFY playerChanged FINAL)
    // size relative to the default one, in percent
    Q_PROPERTY(int textScale READ textScale WRITE setTextScale NOTIFY textScaleChanged FINAL)
    Q_PROPERTY(QColor textColor READ textColor WRITE setTextColor NOTIFY textColorChanged FINAL)
    Q_PROPERTY(int outlineThickness READ outlineThickness WRITE setOutlineThickness NOTIFY outlineThicknessChanged FINAL)
    // opacity of the box drawn behind the text, from 0 to 255
    Q_PROPERTY(int backgroundOpacity READ backgroundOpacity WRITE setBackgroundOpacity NOTIFY backgroundOpacityChanged FINAL)
    // distance from the bottom of the video, in pixels
    Q_PROPERTY(int margin READ margin WRITE setMargin NOTIFY marginChanged FINAL)

public:
    explicit SubtitleStyle(QObject *parent = nullptr);

    PlayerController *player() const { return m_player; }
    void setPlayer(PlayerController *player);

    int textScale() const { return m_textScale; }
    void setTextScale(int scale);

    QColor textColor() const { return m_textColor; }
    void setTextColor(const QColor &color);

    int outlineThickness() const { return m_outlineThickness; }
    void setOutlineThickness(int thickness);

    int backgroundOpacity() const { return m_backgroundOpacity; }
    void setBackgroundOpacity(int opacity);

    int margin() const { return m_margin; }
    void setMargin(int margin);

    /// restores the default values of the options
    Q_INVOKABLE void reset();

signals:
    void playerChanged();
    void textScaleChanged();
    void textColorChanged();
    void outlineThicknessChanged();
    void backgroundOpacityChanged();
    void marginChanged();

private:
    QPointer<PlayerController> m_player;

    int m_textScale = 100;
    QColor m_textColor = Qt::white;
    int m_outlineThickness = 4;
    int m_backgroundOpacity = 0;
    int m_margin = 0;
};

#endif // VLC_QT_PLAYER_SETTINGS_HPP
