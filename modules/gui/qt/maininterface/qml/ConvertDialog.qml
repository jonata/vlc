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

// Converts files to a format, into a folder
Widgets.CardDialog {
    id: root

    property url folder: ""

    title: qsTr("Convert")
    acceptText: qsTr("Convert")
    acceptEnabled: fileBox.files.length > 0 && folder.toString() !== ""

    onOpened: {
        fileBox.files = []
        folder = ""
        profileBox.model = helper.profiles()
        profileBox.currentIndex = helper.currentProfile()
    }

    onAccepted: helper.convert(fileBox.files, profileBox.currentIndex, folder)

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
        text: qsTr("Files")
        description: qsTr("These files will be converted, one after the other, in the play queue.")
    }

    FileListBox {
        id: fileBox

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: VLCStyle.dp(150, VLCStyle.scale)

        // the converted files go next to the first one by default
        onFilesChanged: {
            if (files.length > 0 && root.folder.toString() === "") {
                const first = files[0].toString()
                root.folder = first.substring(0, first.lastIndexOf("/"))
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: VLCStyle.border
        color: theme.border
    }

    Widgets.DialogSectionTitle {
        text: qsTr("Format")
    }

    Widgets.DialogComboBox {
        id: profileBox

        Layout.fillWidth: true
        Layout.preferredHeight: VLCStyle.dp(36, VLCStyle.scale)
    }

    Widgets.DialogSectionTitle {
        text: qsTr("Destination Folder")
        description: qsTr("The converted files are named after the original ones.")
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: VLCStyle.margin_small

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(36, VLCStyle.scale)

            radius: VLCStyle.dp(4, VLCStyle.scale)
            color: Qt.lighter(theme.bg.primary, 1.25)

            T.Label {
                anchors.fill: parent
                anchors.leftMargin: VLCStyle.margin_small
                anchors.rightMargin: VLCStyle.margin_small

                text: root.folder.toString() !== ""
                      ? decodeURIComponent(root.folder.toString().replace(/^file:\/\//, ""))
                      : qsTr("No folder")
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideMiddle
                color: theme.fg.primary
                font.pixelSize: VLCStyle.fontSize_normal
            }
        }

        Widgets.DialogButton {
            text: qsTr("Browse")
            onClicked: {
                const folder = DialogsProvider.getFolderUrl(qsTr("Destination Folder"))
                if (folder.toString() !== "")
                    root.folder = folder
            }
        }
    }
}
