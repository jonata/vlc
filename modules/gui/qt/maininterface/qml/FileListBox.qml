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

// files dropped into the box or picked by clicking it, for the dialogs
Rectangle {
    id: root

    // URLs of the files
    property var files: []

    function addFiles(urls) {
        const all = files.slice()
        for (const url of urls) {
            const text = url.toString()
            if (!all.some(file => file.toString() === text))
                all.push(url)
        }
        files = all
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.Window
    }

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
