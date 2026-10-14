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
import VLC.Playlist
import VLC.Widgets as Widgets
import VLC.Util

// Media of the folder being played, shown next to the video so that the
// next episode can be picked without leaving the player.
FocusScope {
    id: root

    signal closeRequested()

    implicitWidth: VLCStyle.compactLibrary_width

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Library")

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    Keys.onEscapePressed: root.closeRequested()

    // opens in the folder of the current media
    function showCurrentFolder() {
        const folder = folderModel.folderOf(Player.url)
        if (folder.toString() !== "")
            folderModel.folder = folder
    }

    onVisibleChanged: {
        if (visible)
            showCurrentFolder()
    }

    Component.onCompleted: {
        if (visible)
            showCurrentFolder()
    }

    // follows the media being played
    Connections {
        target: Player

        function onInputChanged(hasInput) {
            if (hasInput && root.visible)
                root.showCurrentFolder()
        }
    }

    FolderMediaModel {
        id: folderModel
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.darker(theme.bg.primary, 1.9)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: VLCStyle.margin_normal

        spacing: VLCStyle.margin_small

        RowLayout {
            Layout.fillWidth: true
            spacing: VLCStyle.margin_xsmall

            Widgets.IconToolButton {
                text: VLCIcons.back
                description: qsTr("Parent folder")

                enabled: folderModel.parentFolder.toString() !== ""

                onClicked: folderModel.folder = folderModel.parentFolder
            }

            T.Label {
                Layout.fillWidth: true

                text: folderModel.folderName
                elide: Text.ElideMiddle
                color: theme.fg.primary
                font.pixelSize: VLCStyle.fontSize_large
                font.weight: Font.DemiBold
            }

            Widgets.IconToolButton {
                text: VLCIcons.close
                description: qsTr("Close")

                onClicked: root.closeRequested()
            }
        }

        T.Label {
            Layout.fillWidth: true

            visible: folderModel.count === 0
            text: qsTr("No media in this folder")
            color: theme.fg.primary
            opacity: 0.6
            font.pixelSize: VLCStyle.fontSize_normal
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true

            clip: true
            model: folderModel
            boundsBehavior: Flickable.StopAtBounds

            T.ScrollBar.vertical: Widgets.ScrollBarExt { }

            delegate: T.ItemDelegate {
                id: row

                required property int index
                // "display" is a final property of the delegate
                required property var model
                required property url url
                required property bool isFolder
                required property bool isAudio

                readonly property bool isCurrent: url.toString() === Player.url.toString()

                width: ListView.view.width
                implicitHeight: VLCStyle.icon_normal + VLCStyle.margin_small

                hoverEnabled: true

                Accessible.role: Accessible.ListItem
                Accessible.name: model.display

                onClicked: {
                    if (isFolder)
                        folderModel.folder = url
                    else
                        MainPlaylistController.append(url, true)
                }

                background: Rectangle {
                    radius: VLCStyle.settingsSection_radius
                    color: row.hovered ? theme.bg.primary : "transparent"
                }

                contentItem: RowLayout {
                    spacing: VLCStyle.margin_small

                    T.Label {
                        Layout.leftMargin: VLCStyle.margin_xsmall

                        text: row.isFolder ? VLCIcons.folder
                                           : (row.isAudio ? VLCIcons.topbar_music : VLCIcons.topbar_video)
                        font.family: VLCIcons.fontFamily
                        font.pixelSize: VLCStyle.icon_small
                        color: row.isCurrent ? theme.accent : theme.fg.primary
                    }

                    T.Label {
                        Layout.fillWidth: true

                        text: row.model.display
                        elide: Text.ElideRight
                        color: row.isCurrent ? theme.accent : theme.fg.primary
                        font.pixelSize: VLCStyle.fontSize_normal
                    }

                    Widgets.IconToolButton {
                        visible: !row.isFolder && (row.hovered || hovered)

                        text: VLCIcons.add
                        description: qsTr("Add to the play queue")

                        onClicked: MainPlaylistController.append(row.url, false)
                    }
                }
            }
        }
    }
}
