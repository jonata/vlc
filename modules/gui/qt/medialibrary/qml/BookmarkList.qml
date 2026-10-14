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
import VLC.MediaLibrary
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Player

// Bookmarks of the current media: a click seeks to a bookmark, a double click
// renames it
FocusScope {
    id: root

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    MLBookmarkModel {
        id: bookmarkModel

        player: Player
        ml: MediaLib
    }

    ColumnLayout {
        anchors.fill: parent

        spacing: VLCStyle.margin_xsmall

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: VLCStyle.margin_small

            T.Label {
                Layout.fillWidth: true

                text: (list.count === 1) ? qsTr("1 Bookmark") : qsTr("%1 Bookmarks").arg(list.count)
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.fontSize_normal
            }

            Widgets.IconToolButton {
                text: VLCIcons.remove
                description: qsTr("Remove the bookmark")
                enabled: list.currentIndex >= 0
                onClicked: bookmarkModel.removeAt(list.currentIndex)
            }

            Widgets.IconToolButton {
                text: VLCIcons.add
                description: qsTr("Add a bookmark (Ctrl+B)")
                enabled: Player.isStarted
                onClicked: bookmarkModel.add()
            }
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true

            clip: true
            model: bookmarkModel
            currentIndex: -1

            T.ScrollBar.vertical: Widgets.ScrollBarExt { }

            delegate: T.ItemDelegate {
                id: bookmark

                required property int index
                required property var model

                width: ListView.view.width
                height: VLCStyle.dp(36, VLCStyle.scale)

                leftPadding: VLCStyle.margin_small
                rightPadding: VLCStyle.margin_small

                onClicked: {
                    list.currentIndex = index
                    bookmarkModel.select(bookmarkModel.index(index, 0))
                }

                onDoubleClicked: {
                    nameField.text = bookmark.model.name
                    nameField.visible = true
                    nameField.forceActiveFocus()
                    nameField.selectAll()
                }

                background: Rectangle {
                    radius: VLCStyle.dp(4, VLCStyle.scale)
                    color: (list.currentIndex === bookmark.index) ? theme.bg.secondary
                                                                  : (bookmark.hovered ? Qt.alpha(theme.bg.secondary, 0.5) : "transparent")
                }

                contentItem: RowLayout {
                    spacing: VLCStyle.margin_small

                    T.Label {
                        Layout.fillWidth: true

                        visible: !nameField.visible
                        text: bookmark.model.name
                        elide: Text.ElideRight
                        color: theme.fg.primary
                        font.pixelSize: VLCStyle.fontSize_normal
                    }

                    TextInput {
                        id: nameField

                        Layout.fillWidth: true

                        visible: false
                        color: theme.fg.primary
                        selectionColor: theme.accent
                        font.pixelSize: VLCStyle.fontSize_normal
                        clip: true

                        function finish(save) {
                            if (!visible)
                                return
                            visible = false
                            if (save && text.trim() !== "")
                                bookmark.model.name = text.trim()
                        }

                        onAccepted: finish(true)
                        onActiveFocusChanged: if (!activeFocus) finish(true)
                        Keys.onEscapePressed: finish(false)
                    }

                    T.Label {
                        text: bookmark.model.time
                        color: theme.fg.secondary
                        font.pixelSize: VLCStyle.fontSize_normal
                        font.features: { "tnum": 1 }
                    }
                }
            }

            T.Label {
                anchors.centerIn: parent
                width: parent.width - 2 * VLCStyle.margin_large

                visible: list.count === 0
                text: qsTr("Press + or Ctrl+B to bookmark the current time")
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.fontSize_normal
            }
        }
    }
}
