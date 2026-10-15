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

#ifndef VLC_QT_OPEN_MEDIA_HELPER_HPP
#define VLC_QT_OPEN_MEDIA_HELPER_HPP

#include <QObject>
#include <QPointer>
#include <QStringList>
#include <QUrl>
#include <QVariantList>

#include <memory>

#include "maininterface/mainctx.hpp"

class VLCProfileSelector;

/**
 * Helpers of the dialogs opening media: network streams, capture devices,
 * conversion of files, and casting to a device.
 */
class OpenMediaHelper : public QObject
{
    Q_OBJECT

    Q_PROPERTY(MainCtx* ctx READ ctx WRITE setCtx NOTIFY ctxChanged FINAL)

public:
    explicit OpenMediaHelper(QObject *parent = nullptr);
    ~OpenMediaHelper() override;

    MainCtx *ctx() const { return m_ctx; }
    void setCtx(MainCtx *ctx);

    /// text of the clipboard, to open a link that was copied
    Q_INVOKABLE QString clipboardText() const;

    /// plays media, after the current play queue is replaced
    Q_INVOKABLE void play(const QStringList &mrls, const QStringList &options = {});

    /// saves media as a playlist of the media library, if there is one
    Q_INVOKABLE void savePlaylist(const QString &name, const QStringList &mrls);

    /// capture devices, as [{name, value}]
    Q_INVOKABLE QVariantList cameras() const;
    Q_INVOKABLE QVariantList microphones() const;
    Q_INVOKABLE bool canCaptureScreen() const;

    Q_INVOKABLE void playCamera(const QString &camera, const QString &microphone);
    Q_INVOKABLE void playScreen(double framesPerSecond);

    /// conversion profiles, from the preferences of the convert dialog
    Q_INVOKABLE QStringList profiles();
    Q_INVOKABLE int currentProfile();

    /// converts files with a profile into a folder, the converted files are
    /// named after the original ones
    Q_INVOKABLE void convert(const QList<QUrl> &files, int profile, const QUrl &folder);

    /// selects the device to play on, -1 for this computer
    Q_INVOKABLE void selectRenderer(int row);

signals:
    void ctxChanged();

private:
    VLCProfileSelector *profileSelector();

    QPointer<MainCtx> m_ctx;
    std::unique_ptr<VLCProfileSelector> m_profileSelector;
};

#endif // VLC_QT_OPEN_MEDIA_HELPER_HPP
