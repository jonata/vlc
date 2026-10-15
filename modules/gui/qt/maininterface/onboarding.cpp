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

#include "onboarding.hpp"

#include <vlc_common.h>
#include <vlc_configuration.h>
#include <vlc_media_library.h>
#include <vlc_url.h>
#include <vlc_variables.h>

#include "qt.hpp"
#include "util/color_scheme_model.hpp"
#include "medialibrary/medialib.hpp"

Onboarding::Onboarding(QObject *parent)
    : QObject(parent)
{
}

void Onboarding::setCtx(MainCtx *ctx)
{
    if (m_ctx == ctx)
        return;
    if (m_ctx)
        disconnect(m_ctx, &MainCtx::accentColorChanged, this, &Onboarding::accentColorChanged);
    m_ctx = ctx;
    // the accent color may be changed by another instance
    if (m_ctx)
        connect(m_ctx, &MainCtx::accentColorChanged, this, &Onboarding::accentColorChanged);
    emit ctxChanged();
}

QString Onboarding::accentColor() const
{
    char *color = config_GetPsz("qt-accent-color");
    const QString result = color ? qfu(color) : QStringLiteral("default");
    free(color);
    return result;
}

void Onboarding::setAccentColor(const QString &color)
{
    if (accentColor() == color)
        return;
    config_PutPsz("qt-accent-color", qtu(color));
    if (m_ctx)
        emit m_ctx->accentColorChanged();
    else
        emit accentColorChanged();
}

bool Onboarding::isFirstRun() const
{
    return m_ctx && var_InheritBool(m_ctx->getIntf(), "qt-privacy-ask");
}

QUrl Onboarding::defaultMediaFolder() const
{
    char *folder = config_GetUserDir(VLC_VIDEOS_DIR);
    if (!folder)
        return {};
    const QUrl url = QUrl::fromLocalFile(qfu(folder));
    free(folder);
    return url;
}

void Onboarding::setColorScheme(int scheme)
{
    if (!m_ctx)
        return;

    ColorSchemeModel *model = m_ctx->getColorScheme();
    const QVector<ColorSchemeModel::Item> schemes = model->getSchemes();
    for (int i = 0; i < schemes.size(); ++i)
    {
        if (schemes.at(i).scheme == scheme)
        {
            model->setCurrentIndex(i);
            return;
        }
    }
}

QString Onboarding::hotkey(const QString &action) const
{
    char *keys = config_GetPsz(qtu(QStringLiteral("key-") + action));
    if (!keys)
        return {};
    QString key = qfu(keys).section('\t', 0, 0);
    free(keys);

    QStringList parts = key.split('+');
    if (!parts.isEmpty() && parts.last().size() == 1)
        parts.last() = parts.last().toUpper();
    return parts.join('+');
}

void Onboarding::finish(bool metadataNetworkAccess, const QUrl &mediaFolder)
{
    if (!m_ctx)
        return;

    qt_intf_t *intf = m_ctx->getIntf();

    config_PutInt("metadata-network-access", metadataNetworkAccess);
    config_PutInt("qt-privacy-ask", 0);

    if (vlc_medialibrary_t *ml = vlc_ml_instance_get(intf))
    {
        if (mediaFolder.isLocalFile())
            vlc_ml_add_folder(ml, qtu(mediaFolder.toString(QUrl::FullyEncoded)));
    }

    // the media library waits for the privacy choice before indexing
    if (MediaLib *medialib = m_ctx->getMediaLibrary())
        medialib->reload();

    m_ctx->reloadPrefs();
    config_SaveConfigFile(intf);
}
