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

#ifndef VLC_QT_HOTKEYS_MODEL_HPP
#define VLC_QT_HOTKEYS_MODEL_HPP

#include <QAbstractListModel>
#include <QList>
#include <QPointer>
#include <QString>

#include "maininterface/mainctx.hpp"

/**
 * The hotkeys of the actions, grouped and filtered, as edited in the keyboard
 * shortcuts dialog. The changes are kept until apply().
 */
class HotkeysModel : public QAbstractListModel
{
    Q_OBJECT

    Q_PROPERTY(MainCtx* ctx READ ctx WRITE setCtx NOTIFY ctxChanged FINAL)
    Q_PROPERTY(QString filterText READ filterText WRITE setFilterText NOTIFY filterChanged FINAL)
    Q_PROPERTY(Field filterField READ filterField WRITE setFilterField NOTIFY filterChanged FINAL)
    Q_PROPERTY(bool modified READ modified NOTIFY modifiedChanged FINAL)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged FINAL)

public:
    enum Field {
        AllFields,
        ActionField,
        HotkeyField,
        GlobalHotkeyField
    };
    Q_ENUM(Field)

    enum Roles {
        ActionRole = Qt::UserRole + 1,
        DescriptionRole,
        GroupRole,
        HotkeyRole,
        GlobalHotkeyRole
    };

    explicit HotkeysModel(QObject *parent = nullptr);

    MainCtx *ctx() const { return m_ctx; }
    void setCtx(MainCtx *ctx);

    QString filterText() const { return m_filterText; }
    void setFilterText(const QString &text);

    Field filterField() const { return m_filterField; }
    void setFilterField(Field field);

    bool modified() const { return m_modified; }

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    /// name of the key of a key event, as written in the configuration
    Q_INVOKABLE QString keyName(int key, int modifiers) const;

    /**
     * assigns a key to the hotkey (or the global hotkey) of a row, an empty
     * key removes it. The key is removed from the other actions using it,
     * their names are returned.
     */
    Q_INVOKABLE QStringList setHotkey(int row, bool global, const QString &key);

    /// restores the default hotkeys of all the actions
    Q_INVOKABLE void resetAll();

    /// saves the changes to the configuration
    Q_INVOKABLE void apply();

    /// reloads the hotkeys from the configuration, dropping the changes
    Q_INVOKABLE void reload();

signals:
    void ctxChanged();
    void filterChanged();
    void modifiedChanged();
    void countChanged();

private:
    struct Action
    {
        QString name;   // "key-play-pause"
        QString text;
        QString description;
        QString group;
        int groupOrder = 0;
        QString keys;
        QString globalKeys;
        QString defaultKeys;
        QString defaultGlobalKeys;
        bool hasGlobal = false;
    };

    void updateFilter();
    void setModified(bool modified);
    static QString displayKeys(const QString &keys);

    QPointer<MainCtx> m_ctx;
    QList<Action> m_actions;
    QList<int> m_rows; // indexes of the actions matching the filter

    QString m_filterText;
    Field m_filterField = AllFields;
    bool m_modified = false;
};

#endif // VLC_QT_HOTKEYS_MODEL_HPP
