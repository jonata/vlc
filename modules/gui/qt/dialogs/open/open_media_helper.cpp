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

#include "open_media_helper.hpp"

#include <QClipboard>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QRegularExpression>

#include <vlc_common.h>
#include <vlc_configuration.h>
#include <vlc_media_library.h>
#include <vlc_modules.h>

#include "qt.hpp"
#include "dialogs/sout/profile_selector.hpp"
#include "player/player_controller.hpp"
#include "playlist/media.hpp"
#include "playlist/playlist_controller.hpp"
#include "util/renderer_manager.hpp"
#include "util/soutchain.hpp"

namespace {

QVariantList choices(const char *option)
{
    QVariantList list;
    char **values = nullptr;
    char **texts = nullptr;
    const ssize_t count = config_GetPszChoices(option, &values, &texts);
    for (ssize_t i = 0; i < count; ++i)
    {
        const QString value = qfu(values[i]);
        if (!value.isEmpty())
            list.append(QVariantMap { { "name", qfu(texts[i]) }, { "value", value } });
        free(values[i]);
        free(texts[i]);
    }
    free(values);
    free(texts);
    return list;
}

// an option value of an MRL may not contain a colon
QString colonEscape(QString value)
{
    return value.replace(':', QStringLiteral("\\:"));
}

} // namespace

OpenMediaHelper::OpenMediaHelper(QObject *parent)
    : QObject(parent)
{
}

OpenMediaHelper::~OpenMediaHelper() = default;

void OpenMediaHelper::setCtx(MainCtx *ctx)
{
    if (m_ctx == ctx)
        return;
    m_ctx = ctx;
    emit ctxChanged();
}

QString OpenMediaHelper::clipboardText() const
{
    const QClipboard *clipboard = QGuiApplication::clipboard();
    QString text = clipboard->text(QClipboard::Clipboard).trimmed();
    if (text.isEmpty() && clipboard->supportsSelection())
        text = clipboard->text(QClipboard::Selection).trimmed();
    return text;
}

void OpenMediaHelper::play(const QStringList &mrls, const QStringList &options)
{
    if (!m_ctx || mrls.isEmpty())
        return;

    QVector<vlc::playlist::Media> medias;
    for (const QString &mrl : mrls)
        medias.append(vlc::playlist::Media(mrl, QString(), options));

    m_ctx->getIntf()->p_mainPlaylistController->append(medias, true);
}

void OpenMediaHelper::savePlaylist(const QString &name, const QStringList &mrls)
{
    if (!m_ctx || name.trimmed().isEmpty() || mrls.isEmpty())
        return;

    vlc_medialibrary_t *ml = vlc_ml_instance_get(m_ctx->getIntf());
    if (!ml)
        return;

    vlc_ml_playlist_t *playlist = vlc_ml_playlist_create(ml, qtu(name.trimmed()));
    if (!playlist)
        return;

    for (const QString &mrl : mrls)
    {
        vlc_ml_media_t *media = vlc_ml_get_media_by_mrl(ml, qtu(mrl));
        if (!media)
            media = vlc_ml_new_external_media(ml, qtu(mrl));
        if (!media)
            continue;
        vlc_ml_playlist_append(ml, playlist->i_id, &media->i_id, 1);
        vlc_ml_media_release(media);
    }
    vlc_ml_playlist_release(playlist);
}

QVariantList OpenMediaHelper::cameras() const
{
#ifdef _WIN32
    return choices("dshow-vdev");
#elif defined(__APPLE__)
    return {};
#else
    QVariantList list;
    if (!module_exists("v4l2"))
        return list;
    const QStringList nodes = QDir(QStringLiteral("/dev")).entryList({ QStringLiteral("video*") }, QDir::System, QDir::Name);
    for (const QString &node : nodes)
    {
        const QString path = QStringLiteral("/dev/") + node;
        list.append(QVariantMap { { "name", path }, { "value", path } });
    }
    return list;
#endif
}

QVariantList OpenMediaHelper::microphones() const
{
#ifdef _WIN32
    return choices("dshow-adev");
#elif defined(__APPLE__)
    return {};
#else
    // the capture nodes of ALSA, pcmC0D0c is the device hw:0,0
    QVariantList list;
    const QStringList nodes = QDir(QStringLiteral("/dev/snd")).entryList({ QStringLiteral("pcmC*D*c") }, QDir::System, QDir::Name);
    static const QRegularExpression pattern(QStringLiteral("^pcmC(\\d+)D(\\d+)c$"));
    for (const QString &node : nodes)
    {
        const QRegularExpressionMatch match = pattern.match(node);
        if (!match.hasMatch())
            continue;
        const QString device = QStringLiteral("hw:%1,%2").arg(match.captured(1), match.captured(2));
        list.append(QVariantMap { { "name", device }, { "value", device } });
    }
    return list;
#endif
}

bool OpenMediaHelper::canCaptureScreen() const
{
    return module_exists("screen");
}

void OpenMediaHelper::playCamera(const QString &camera, const QString &microphone)
{
#ifdef _WIN32
    QStringList options { QStringLiteral("dshow-vdev=") + colonEscape(camera) };
    if (!microphone.isEmpty())
        options << QStringLiteral("dshow-adev=") + colonEscape(microphone);
    play({ QStringLiteral("dshow://") }, options);
#else
    QStringList options;
    if (!microphone.isEmpty())
        options << QStringLiteral("input-slave=alsa://") + microphone;
    play({ QStringLiteral("v4l2://") + camera }, options);
#endif
}

void OpenMediaHelper::playScreen(double framesPerSecond)
{
    play({ QStringLiteral("screen://") }, { QStringLiteral("screen-fps=%1").arg(framesPerSecond) });
}

VLCProfileSelector *OpenMediaHelper::profileSelector()
{
    // the profiles are those of the convert dialog, which reads and
    // converts them, it is not shown
    if (!m_profileSelector)
        m_profileSelector = std::make_unique<VLCProfileSelector>(nullptr);
    return m_profileSelector.get();
}

QStringList OpenMediaHelper::profiles()
{
    return profileSelector()->profileNames();
}

int OpenMediaHelper::currentProfile()
{
    return std::max(profileSelector()->currentProfile(), 0);
}

void OpenMediaHelper::convert(const QList<QUrl> &files, int profile, const QUrl &folder)
{
    if (!m_ctx || files.isEmpty() || !folder.isLocalFile())
        return;

    VLCProfileSelector *selector = profileSelector();
    selector->selectProfile(profile);

    QVector<vlc::playlist::Media> medias;
    for (const QUrl &file : files)
    {
        SoutChain chain = selector->getTranscode();
        chain.header(QStringLiteral(" :sout=#") + chain.getHeader());
        chain.end();

        // the converted file is named after the original one, in the folder
        const QFileInfo source(file.toLocalFile());
        QString destination = QDir(folder.toLocalFile()).filePath(source.completeBaseName() + '.' + selector->getMux());
        if (QFileInfo(destination) == source)
            destination = QDir(folder.toLocalFile()).filePath(source.completeBaseName() + QStringLiteral("-converted.") + selector->getMux());

        SoutModule access("file");
        access.option("no-overwrite");
        SoutModule output("std");
        output.option("access", access);
        output.option("mux", selector->getMux());
        output.option("dst", destination);
        chain.module(output);

        const QString title = qtr("Converting %1").arg(source.fileName());
        medias.append(vlc::playlist::Media(file.toString(QUrl::FullyEncoded), title,
                                           chain.to_string().split(QStringLiteral(" :"), Qt::SkipEmptyParts)));
    }

    // the play queue holds the conversions, as the convert dialog does
    vlc::playlist::PlaylistController *playlist = m_ctx->getIntf()->p_mainPlaylistController;
    playlist->clear();
    playlist->append(medias, true);
}

void OpenMediaHelper::selectRenderer(int row)
{
    if (!m_ctx)
        return;

    RendererManager *renderers = m_ctx->getIntf()->p_mainPlayerController->getRendererManager();
    if (row < 0)
    {
        renderers->disableRenderer();
        return;
    }
    renderers->setData(renderers->index(row), true, RendererManager::SELECTED);
}
