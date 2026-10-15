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

import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

// The hotkeys of the actions: searched, changed by pressing the new key,
// saved to the configuration
Widgets.CardDialog {
    id: root

    title: qsTr("Keyboard Shortcuts")
    acceptText: qsTr("Save")
    acceptEnabled: hotkeys.modified

    preferredWidth: VLCStyle.dp(1048, VLCStyle.scale)
    height: Math.min(VLCStyle.dp(800, VLCStyle.scale), (parent?.height ?? 0) - 2 * VLCStyle.margin_large)

    // the hotkey being changed: the row, and whether it is the global one
    property int _captureRow: -1
    property bool _captureGlobal: false
    readonly property bool _capturing: _captureRow >= 0

    property string _message: ""

    // while a key is captured, escape cancels it instead of closing the dialog
    closePolicy: _capturing ? T.Popup.NoAutoClose : (T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside)

    onOpened: {
        hotkeys.reload()
        searchField.text = ""
        _message = ""
        _captureRow = -1
        searchField.forceActiveFocus()
    }

    onAccepted: hotkeys.apply()

    function _capture(row, global) {
        _captureRow = row
        _captureGlobal = global
        _message = qsTr("Press the new key, or Escape to cancel.")
        captureArea.forceActiveFocus()
    }

    function _assign(key) {
        const others = hotkeys.setHotkey(_captureRow, _captureGlobal, key)
        _captureRow = -1
        _message = (others.length > 0)
                 ? qsTr("The key was removed from: %1.").arg(others.join(", "))
                 : qsTr("The changes take effect after restarting VLC.")
    }

    // the dialog is outside of the items of the window, see CardDialog
    readonly property ColorContext _theme: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.Window
    }

    HotkeysModel {
        id: hotkeys

        ctx: MainCtx
        filterText: searchField.text
    }

    // receives the key of the hotkey being changed
    Item {
        id: captureArea

        Layout.preferredWidth: 0
        Layout.preferredHeight: 0

        Keys.onPressed: (event) => {
            event.accepted = true
            if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) {
                root._captureRow = -1
                root._message = ""
                return
            }
            const key = hotkeys.keyName(event.key, event.modifiers)
            if (key !== "")
                root._assign(key)
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: VLCStyle.margin_small

        Widgets.TextFieldExt {
            id: searchField

            Layout.fillWidth: true

            placeholderText: qsTr("Search Keyboard Shortcuts...")
        }

        Widgets.DialogComboBox {
            Layout.preferredWidth: VLCStyle.dp(200, VLCStyle.scale)
            Layout.preferredHeight: searchField.height

            model: [qsTr("All Fields"), qsTr("Action"), qsTr("Hotkey"), qsTr("Global Hotkey")]
            currentIndex: hotkeys.filterField

            onActivated: (index) => { hotkeys.filterField = index }
        }

        Widgets.DialogButton {
            Layout.preferredHeight: searchField.height
            text: qsTr("Restore Defaults")
            onClicked: {
                hotkeys.resetAll()
                root._message = qsTr("The changes take effect after restarting VLC.")
            }
        }
    }

    // column titles
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: VLCStyle.margin_xsmall

        spacing: VLCStyle.margin_normal

        HeaderLabel { Layout.fillWidth: true; text: qsTr("Action") }
        HeaderLabel { Layout.preferredWidth: list._keyWidth; text: qsTr("Hotkey") }
        HeaderLabel { Layout.preferredWidth: list._keyWidth; text: qsTr("Global Hotkey") }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: VLCStyle.border
        color: theme.border
    }

    ListView {
        id: list

        readonly property real _keyWidth: VLCStyle.dp(270, VLCStyle.scale)

        Layout.fillWidth: true
        Layout.fillHeight: true

        clip: true
        model: hotkeys
        spacing: VLCStyle.margin_xsmall

        T.ScrollBar.vertical: Widgets.ScrollBarExt { }

        section.property: "group"
        section.delegate: T.Label {
            required property string section

            width: ListView.view.width
            topPadding: VLCStyle.margin_normal
            bottomPadding: VLCStyle.margin_xsmall

            text: section
            color: theme.fg.primary
            font.pixelSize: VLCStyle.fontSize_xlarge
            font.weight: Font.DemiBold
        }

        delegate: RowLayout {
            id: row

            required property int index
            required property string action
            required property string description
            required property string hotkey
            required property string globalHotkey

            width: ListView.view.width
            height: VLCStyle.dp(33, VLCStyle.scale)

            spacing: VLCStyle.margin_normal

            T.Label {
                Layout.fillWidth: true

                text: row.action
                elide: Text.ElideRight
                color: theme.fg.primary
                font.pixelSize: VLCStyle.fontSize_normal

                HoverHandler { id: actionHover }

                Widgets.ToolTipExt {
                    visible: actionHover.hovered && row.description !== ""
                    delay: VLCStyle.delayToolTipAppear
                    text: row.description
                }
            }

            KeyCell {
                Layout.preferredWidth: list._keyWidth
                Layout.fillHeight: true

                keys: row.hotkey
                capturing: root._capturing && root._captureRow === row.index && !root._captureGlobal

                onEditRequested: root._capture(row.index, false)
                onClearRequested: root._message = (hotkeys.setHotkey(row.index, false, ""), qsTr("The changes take effect after restarting VLC."))
            }

            KeyCell {
                Layout.preferredWidth: list._keyWidth
                Layout.fillHeight: true

                keys: row.globalHotkey
                capturing: root._capturing && root._captureRow === row.index && root._captureGlobal

                onEditRequested: root._capture(row.index, true)
                onClearRequested: root._message = (hotkeys.setHotkey(row.index, true, ""), qsTr("The changes take effect after restarting VLC."))
            }
        }

        T.Label {
            anchors.centerIn: parent
            visible: list.count === 0
            text: qsTr("No keyboard shortcut matches the search")
            color: theme.fg.secondary
            font.pixelSize: VLCStyle.fontSize_normal
        }
    }

    T.Label {
        Layout.fillWidth: true

        visible: root._message !== ""
        text: root._message
        wrapMode: Text.Wrap
        color: root._capturing ? theme.accent : theme.fg.secondary
        font.pixelSize: VLCStyle.fontSize_normal
    }

    component HeaderLabel: T.Label {
        color: theme.fg.secondary
        font.pixelSize: VLCStyle.fontSize_normal
    }

    // the key of a hotkey, clicked to change it
    component KeyCell: T.AbstractButton {
        id: cell

        property string keys
        property bool capturing: false

        signal editRequested()
        signal clearRequested()

        onClicked: cell.editRequested()

        Accessible.name: keys !== "" ? keys : qsTr("No hotkey")

        background: Rectangle {
            radius: VLCStyle.dp(4, VLCStyle.scale)
            color: cell.hovered ? theme.bg.secondary : Qt.lighter(theme.bg.primary, 1.25)
            border.color: cell.capturing ? theme.accent : "transparent"
            border.width: VLCStyle.dp(1, VLCStyle.scale)
        }

        contentItem: Item {
            T.Label {
                anchors.centerIn: parent
                width: parent.width - 2 * clearButton.width

                text: cell.capturing ? qsTr("Press a key...") : cell.keys
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                color: cell.capturing ? theme.accent : theme.fg.primary
                font.pixelSize: VLCStyle.fontSize_normal
            }

            Widgets.IconToolButton {
                id: clearButton

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                height: parent.height
                width: height

                visible: cell.keys !== "" && !cell.capturing
                text: VLCIcons.close
                description: qsTr("Remove the hotkey")
                font.pixelSize: VLCStyle.icon_small

                onClicked: cell.clearRequested()
            }
        }
    }
}
