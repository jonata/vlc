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
import VLC.Player
import VLC.Widgets as Widgets

// Plays on another device of the network, such as a Chromecast: the current
// media, or files
Widgets.CardDialog {
    id: root

    property int _device: -1

    readonly property var _renderers: Player.rendererManager

    title: qsTr("Stream to a Device")
    acceptText: qsTr("Play on Device")
    acceptEnabled: _device >= 0 && (Player.hasInput || fileBox.files.length > 0)

    onOpened: {
        _device = -1
        fileBox.files = []
        _renderers.StartScan()
    }

    onClosed: _renderers.StopScan()

    onAccepted: {
        helper.selectRenderer(_device)
        if (fileBox.files.length > 0)
            helper.play(fileBox.files.map(file => file.toString()))
    }

    // the dialog is outside of the items of the window, see CardDialog
    readonly property ColorContext _theme: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.Window
    }

    OpenMediaHelper {
        id: helper
        ctx: MainCtx
    }

    Widgets.DialogSectionTitle {
        text: qsTr("Device")
        description: (devices.count === 0)
                     ? ((root._renderers.status === 0) ? qsTr("Looking for devices on the network...")
                                                         : qsTr("No device was found on the network."))
                     : qsTr("Choose the device to play on.")
    }

    ListView {
        id: devices

        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, VLCStyle.dp(200, VLCStyle.scale))

        clip: true
        model: root._renderers
        spacing: VLCStyle.margin_xxxsmall

        delegate: T.ItemDelegate {
            id: device

            required property int index
            required property string name
            required property string type

            width: ListView.view.width
            height: VLCStyle.dp(40, VLCStyle.scale)

            leftPadding: VLCStyle.margin_small

            onClicked: root._device = index

            background: Rectangle {
                radius: VLCStyle.dp(4, VLCStyle.scale)
                color: (root._device === device.index) ? Qt.darker(theme.bg.primary, 1.4)
                                                        : (device.hovered ? theme.bg.secondary : "transparent")
            }

            contentItem: RowLayout {
                spacing: VLCStyle.margin_small

                Widgets.IconLabel {
                    text: VLCIcons.tv
                    font.pixelSize: VLCStyle.icon_normal
                    color: theme.fg.secondary
                }

                T.Label {
                    Layout.fillWidth: true
                    text: device.name
                    elide: Text.ElideRight
                    color: theme.fg.primary
                    font.pixelSize: VLCStyle.fontSize_normal
                }

                Widgets.IconLabel {
                    visible: root._device === device.index
                    text: VLCIcons.check
                    font.pixelSize: VLCStyle.icon_normal
                    color: theme.accent
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: VLCStyle.border
        color: theme.border
    }

    Widgets.DialogSectionTitle {
        text: qsTr("Media")
        description: Player.hasInput ? qsTr("Without files, the current media is played on the device.")
                                     : qsTr("These files will be played on the device.")
    }

    FileListBox {
        id: fileBox

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: VLCStyle.dp(150, VLCStyle.scale)
    }
}
