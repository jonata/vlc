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

#ifndef VLC_QT_PREFERENCES_MODEL_HPP
#define VLC_QT_PREFERENCES_MODEL_HPP

#include <QHash>
#include <QObject>
#include <QPointer>
#include <QUrl>
#include <QVariant>
#include <QVariantMap>

#include "maininterface/mainctx.hpp"

/**
 * Options of the configuration, as edited in the preferences: each option is
 * described from the configuration (type, range, choices and descriptions),
 * and the changes are kept until apply().
 */
class PreferencesModel : public QObject
{
    Q_OBJECT

    Q_PROPERTY(MainCtx* ctx READ ctx WRITE setCtx NOTIFY ctxChanged FINAL)
    Q_PROPERTY(bool modified READ modified NOTIFY modifiedChanged FINAL)
    // incremented on each change, for the bindings on the values
    Q_PROPERTY(int revision READ revision NOTIFY valuesChanged FINAL)

public:
    explicit PreferencesModel(QObject *parent = nullptr);

    MainCtx *ctx() const { return m_ctx; }
    void setCtx(MainCtx *ctx);

    bool modified() const { return !m_pending.isEmpty(); }
    int revision() const { return m_revision; }

    /**
     * description of an option: {exists, type, text, description, min, max,
     * choices: [{value, text}], default}. The type is "bool", "int",
     * "float", "string", "file", "folder", "password" or "color".
     */
    Q_INVOKABLE QVariantMap option(const QString &name) const;

    /// value of an option, changed or not
    Q_INVOKABLE QVariant value(const QString &name) const;
    Q_INVOKABLE void setValue(const QString &name, const QVariant &value);

    /// saves the changes to the configuration
    Q_INVOKABLE void apply();
    /// drops the changes
    Q_INVOKABLE void revert();
    /// restores the default value of every option, and saves it
    Q_INVOKABLE void resetAll();

    /// folder of the configuration files
    Q_INVOKABLE QUrl configFolder() const;

signals:
    void ctxChanged();
    void modifiedChanged();
    void valuesChanged();

private:
    QPointer<MainCtx> m_ctx;
    QHash<QString, QVariant> m_pending;
    int m_revision = 0;
};

#endif // VLC_QT_PREFERENCES_MODEL_HPP
