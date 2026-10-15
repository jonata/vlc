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

#include "preferences_model.hpp"

#include <vlc_common.h>
#include <vlc_configuration.h>
#include <vlc_plugin.h>

#include "qt.hpp"

PreferencesModel::PreferencesModel(QObject *parent)
    : QObject(parent)
{
}

void PreferencesModel::setCtx(MainCtx *ctx)
{
    if (m_ctx == ctx)
        return;
    m_ctx = ctx;
    emit ctxChanged();
}

QVariantMap PreferencesModel::option(const QString &name) const
{
    QVariantMap result;
    const module_config_t *item = config_FindConfig(qtu(name));
    result.insert(QStringLiteral("exists"), item != nullptr);
    if (!item)
        return result;

    QString type;
    switch (item->i_type)
    {
    case CONFIG_ITEM_BOOL: type = QStringLiteral("bool"); break;
    case CONFIG_ITEM_RGB: type = QStringLiteral("color"); break;
    case CONFIG_ITEM_FLOAT: type = QStringLiteral("float"); break;
    case CONFIG_ITEM_LOADFILE:
    case CONFIG_ITEM_SAVEFILE: type = QStringLiteral("file"); break;
    case CONFIG_ITEM_DIRECTORY: type = QStringLiteral("folder"); break;
    case CONFIG_ITEM_PASSWORD: type = QStringLiteral("password"); break;
    default:
        if (IsConfigIntegerType(item->i_type))
            type = QStringLiteral("int");
        else
            type = QStringLiteral("string");
        break;
    }
    result.insert(QStringLiteral("type"), type);
    result.insert(QStringLiteral("text"), item->psz_text ? qfut(item->psz_text) : name);
    result.insert(QStringLiteral("description"), item->psz_longtext ? qfut(item->psz_longtext) : QString());

    QVariantList choices;
    if (IsConfigIntegerType(item->i_type))
    {
        result.insert(QStringLiteral("min"), QVariant::fromValue(item->min.i));
        result.insert(QStringLiteral("max"), QVariant::fromValue(item->max.i));
        result.insert(QStringLiteral("default"), QVariant::fromValue(item->orig.i));

        int64_t *values = nullptr;
        char **texts = nullptr;
        const ssize_t count = config_GetIntChoices(item->psz_name, &values, &texts);
        for (ssize_t i = 0; i < count; ++i)
        {
            choices.append(QVariantMap { { "value", QVariant::fromValue(values[i]) }, { "text", qfu(texts[i]) } });
            free(texts[i]);
        }
        free(values);
        free(texts);
    }
    else if (IsConfigFloatType(item->i_type))
    {
        result.insert(QStringLiteral("min"), item->min.f);
        result.insert(QStringLiteral("max"), item->max.f);
        result.insert(QStringLiteral("default"), item->orig.f);
    }
    else if (IsConfigStringType(item->i_type))
    {
        result.insert(QStringLiteral("default"), qfu(item->orig.psz));

        char **values = nullptr;
        char **texts = nullptr;
        const ssize_t count = config_GetPszChoices(item->psz_name, &values, &texts);
        for (ssize_t i = 0; i < count; ++i)
        {
            choices.append(QVariantMap { { "value", qfu(values[i]) }, { "text", qfu(texts[i]) } });
            free(values[i]);
            free(texts[i]);
        }
        free(values);
        free(texts);
    }
    else
    {
        result.insert(QStringLiteral("default"), item->orig.i != 0);
    }
    result.insert(QStringLiteral("choices"), choices);

    return result;
}

QVariant PreferencesModel::value(const QString &name) const
{
    const auto pending = m_pending.constFind(name);
    if (pending != m_pending.cend())
        return *pending;

    const QByteArray key = name.toUtf8();
    switch (config_GetType(key.constData()))
    {
    case VLC_VAR_BOOL:
        return config_GetInt(key.constData()) != 0;
    case VLC_VAR_INTEGER:
        return QVariant::fromValue(config_GetInt(key.constData()));
    case VLC_VAR_FLOAT:
        return config_GetFloat(key.constData());
    case VLC_VAR_STRING:
    {
        char *value = config_GetPsz(key.constData());
        const QString result = qfu(value);
        free(value);
        return result;
    }
    default:
        return {};
    }
}

void PreferencesModel::setValue(const QString &name, const QVariant &value)
{
    if (this->value(name) == value)
        return;

    const bool wasModified = modified();
    m_pending.insert(name, value);
    ++m_revision;
    emit valuesChanged();
    if (!wasModified)
        emit modifiedChanged();
}

void PreferencesModel::apply()
{
    if (m_pending.isEmpty())
        return;

    for (auto it = m_pending.cbegin(); it != m_pending.cend(); ++it)
    {
        const QByteArray key = it.key().toUtf8();
        switch (config_GetType(key.constData()))
        {
        case VLC_VAR_BOOL:
        case VLC_VAR_INTEGER:
            config_PutInt(key.constData(), it.value().toLongLong());
            break;
        case VLC_VAR_FLOAT:
            config_PutFloat(key.constData(), it.value().toFloat());
            break;
        case VLC_VAR_STRING:
            config_PutPsz(key.constData(), qtu(it.value().toString()));
            break;
        default:
            break;
        }
    }
    m_pending.clear();

    if (m_ctx)
    {
        config_SaveConfigFile(m_ctx->getIntf());
        m_ctx->reloadPrefs();
        // the accent color is applied right away
        emit m_ctx->accentColorChanged();
    }

    ++m_revision;
    emit valuesChanged();
    emit modifiedChanged();
}

void PreferencesModel::revert()
{
    if (m_pending.isEmpty())
        return;
    m_pending.clear();
    ++m_revision;
    emit valuesChanged();
    emit modifiedChanged();
}

void PreferencesModel::resetAll()
{
    m_pending.clear();
    config_ResetAll();
    if (m_ctx)
    {
        config_SaveConfigFile(m_ctx->getIntf());
        m_ctx->reloadPrefs();
        emit m_ctx->accentColorChanged();
    }
    ++m_revision;
    emit valuesChanged();
    emit modifiedChanged();
}

QUrl PreferencesModel::configFolder() const
{
    char *folder = config_GetUserDir(VLC_CONFIG_DIR);
    const QUrl result = QUrl::fromLocalFile(qfu(folder));
    free(folder);
    return result;
}
