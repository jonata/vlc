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

import VLC.MediaLibrary
import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util

// Creates a playlist of the media library, with a name and its files
Widgets.CardDialog {
    id: root

    // URLs of the files to add
    property var files: []

    title: qsTr("New Playlist")
    acceptText: qsTr("Save")
    acceptEnabled: nameField.text.trim() !== ""

    onOpened: {
        nameField.text = ""
        files = []
        nameField.forceActiveFocus()
    }

    onAccepted: playlistModel.create(nameField.text.trim(), files)

    function addFiles(urls) {
        const all = files.slice()
        for (const url of urls) {
            const text = url.toString()
            if (!all.some(file => file.toString() === text))
                all.push(url)
        }
        files = all
    }

    // the dialog is outside of the items of the window, see CardDialog
    readonly property ColorContext _theme: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.Window
    }

    MLPlaylistListModel {
        id: playlistModel
        ml: MediaLib
    }

    Widgets.DialogSectionTitle {
        text: qsTr("Playlist Details")
        description: qsTr("The playlist will be saved and displayed with this title.")
    }

    Widgets.TextFieldExt {
        id: nameField

        Layout.fillWidth: true

        placeholderText: qsTr("e.g., Favorite Videos")

        onAccepted: {
            if (root.acceptEnabled) {
                root.accepted()
                root.close()
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: VLCStyle.border
        color: theme.border
    }

    Widgets.DialogSectionTitle {
        text: qsTr("Select Files")
        description: qsTr("These files will be added to the playlist.")
    }

    // drop zone, which also opens a file dialog
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: VLCStyle.dp(186, VLCStyle.scale)

        radius: VLCStyle.dp(6, VLCStyle.scale)
        color: dropArea.containsDrag ? Qt.alpha(theme.accent, 0.1) : Qt.lighter(theme.bg.primary, 1.25)
        border.color: dropArea.containsDrag ? theme.accent : "transparent"

        DropArea {
            id: dropArea

            anchors.fill: parent

            onDropped: (drop) => {
                if (drop.hasUrls) {
                    root.addFiles(drop.urls)
                    drop.accept()
                }
            }
        }

        TapHandler {
            onTapped: root.addFiles(DialogsProvider.getOpenMediaUrls(qsTr("Select Files")))
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 2 * VLCStyle.margin_large

            visible: root.files.length === 0
            spacing: VLCStyle.margin_small

            T.Label {
                Layout.fillWidth: true
                text: qsTr("Drag files into the box or click here to select files.")
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.fontSize_normal
            }

            Widgets.IconLabel {
                Layout.alignment: Qt.AlignHCenter
                text: VLCIcons.add
                font.pixelSize: VLCStyle.icon_normal
                color: theme.fg.secondary
            }
        }

        ListView {
            anchors.fill: parent
            anchors.margins: VLCStyle.margin_small

            visible: root.files.length > 0
            clip: true
            model: root.files

            delegate: RowLayout {
                id: fileRow

                required property var modelData
                required property int index

                width: ListView.view.width
                height: VLCStyle.dp(32, VLCStyle.scale)

                spacing: VLCStyle.margin_small

                Widgets.IconLabel {
                    text: VLCIcons.topbar_video
                    font.pixelSize: VLCStyle.icon_small
                    color: theme.fg.secondary
                }

                T.Label {
                    Layout.fillWidth: true
                    text: decodeURIComponent(fileRow.modelData.toString().split("/").pop())
                    elide: Text.ElideMiddle
                    color: theme.fg.primary
                    font.pixelSize: VLCStyle.fontSize_normal
                }

                Widgets.IconToolButton {
                    text: VLCIcons.close
                    description: qsTr("Remove")
                    onClicked: {
                        const all = root.files.slice()
                        all.splice(fileRow.index, 1)
                        root.files = all
                    }
                }
            }
        }
    }
}
