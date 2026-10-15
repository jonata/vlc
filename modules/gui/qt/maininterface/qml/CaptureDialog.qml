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

// Plays a capture device: a camera with its microphone, or the screen
Widgets.CardDialog {
    id: root

    title: qsTr("Open Capture Device")
    acceptText: qsTr("Play")
    acceptEnabled: _screen || cameraBox.currentIndex >= 0

    readonly property var _cameras: helper.cameras()
    readonly property var _microphones: helper.microphones()
    readonly property bool _screen: sourceBox.currentIndex === 1

    readonly property var _frameRates: [10, 15, 24, 30, 60]

    onAccepted: {
        if (_screen) {
            helper.playScreen(_frameRates[rateBox.currentIndex])
        } else {
            // the first choice is no microphone
            const microphone = (micBox.currentIndex > 0) ? _microphones[micBox.currentIndex - 1].value : ""
            helper.playCamera(_cameras[cameraBox.currentIndex].value, microphone)
        }
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
        text: qsTr("Source")
        description: qsTr("Play what a camera captures, or what is on the screen.")
    }

    Widgets.DialogComboBox {
        id: sourceBox

        Layout.fillWidth: true
        Layout.preferredHeight: VLCStyle.dp(36, VLCStyle.scale)

        model: helper.canCaptureScreen() ? [qsTr("Camera"), qsTr("Screen")] : [qsTr("Camera")]
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: VLCStyle.border
        color: theme.border
    }

    // camera
    ColumnLayout {
        Layout.fillWidth: true
        visible: !root._screen
        spacing: VLCStyle.margin_normal

        Widgets.DialogSectionTitle {
            text: qsTr("Camera")
            description: root._cameras.length === 0 ? qsTr("No camera was found.") : ""
        }

        Widgets.DialogComboBox {
            id: cameraBox

            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(36, VLCStyle.scale)

            visible: root._cameras.length > 0
            model: root._cameras.map(device => device.name)
            currentIndex: root._cameras.length > 0 ? 0 : -1
        }

        Widgets.DialogSectionTitle {
            text: qsTr("Microphone")
        }

        Widgets.DialogComboBox {
            id: micBox

            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(36, VLCStyle.scale)

            model: [qsTr("No microphone")].concat(root._microphones.map(device => device.name))
        }
    }

    // screen
    ColumnLayout {
        Layout.fillWidth: true
        visible: root._screen
        spacing: VLCStyle.margin_normal

        Widgets.DialogSectionTitle {
            text: qsTr("Frame Rate")
            description: qsTr("Images captured each second.")
        }

        Widgets.DialogComboBox {
            id: rateBox

            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(36, VLCStyle.scale)

            model: root._frameRates.map(rate => qsTr("%1 fps").arg(rate))
            currentIndex: 3
        }
    }

    Item { Layout.fillHeight: true }
}
