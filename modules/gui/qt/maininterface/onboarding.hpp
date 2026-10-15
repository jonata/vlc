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

#ifndef VLC_QT_ONBOARDING_HPP
#define VLC_QT_ONBOARDING_HPP

#include <QObject>
#include <QPointer>
#include <QUrl>

#include "maininterface/mainctx.hpp"

/**
 * Settings chosen in the onboarding shown on the first run, in place of the
 * first run wizard: the access to the network for the metadata, the color
 * scheme and its accent, and a folder for the media library.
 */
class Onboarding : public QObject
{
    Q_OBJECT

    Q_PROPERTY(MainCtx* ctx READ ctx WRITE setCtx NOTIFY ctxChanged FINAL)
    // "default", "system" or a color such as "#3478f6"
    Q_PROPERTY(QString accentColor READ accentColor WRITE setAccentColor NOTIFY accentColorChanged FINAL)

public:
    explicit Onboarding(QObject *parent = nullptr);

    MainCtx *ctx() const { return m_ctx; }
    void setCtx(MainCtx *ctx);

    QString accentColor() const;
    void setAccentColor(const QString &color);

    /// whether the onboarding was not done yet
    Q_INVOKABLE bool isFirstRun() const;

    /// the folder of the videos of the user, proposed for the media library
    Q_INVOKABLE QUrl defaultMediaFolder() const;

    /// applies a color scheme (ColorSchemeModel::ColorScheme) right away
    Q_INVOKABLE void setColorScheme(int scheme);

    /// hotkey of an action of the core, as shown to the user ("Space", "Ctrl+Up")
    Q_INVOKABLE QString hotkey(const QString &action) const;

    /// saves the choices, the onboarding is not shown again
    Q_INVOKABLE void finish(bool metadataNetworkAccess, const QUrl &mediaFolder);

signals:
    void ctxChanged();
    void accentColorChanged();

private:
    QPointer<MainCtx> m_ctx;
};

#endif // VLC_QT_ONBOARDING_HPP
