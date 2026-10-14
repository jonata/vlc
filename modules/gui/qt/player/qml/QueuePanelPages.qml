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
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Player
import VLC.Util

// Tabs of the queue panel: the queue itself (shown by the panel), the
// bookmarks and the chapters of the current media
Item {
    id: root

    enum Tab {
        Queue,
        Bookmarks,
        Chapters
    }

    property int currentTab: QueuePanelPages.Tab.Queue

    readonly property real tabBarHeight: tabBar.height

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    RowLayout {
        id: tabBar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        height: VLCStyle.dp(40, VLCStyle.scale)
        spacing: 0

        Repeater {
            model: [
                { tab: QueuePanelPages.Tab.Queue, icon: VLCIcons.playlist, text: qsTr("Queue"), enabled: true },
                { tab: QueuePanelPages.Tab.Bookmarks, icon: VLCIcons.bookmark, text: qsTr("Bookmarks"),
                  enabled: MainCtx.mediaLibraryAvailable },
                { tab: QueuePanelPages.Tab.Chapters, icon: VLCIcons.list, text: qsTr("Chapters"), enabled: true }
            ]

            T.TabButton {
                id: tabButton

                required property var modelData

                Layout.fillWidth: true
                Layout.preferredWidth: 1

                leftPadding: VLCStyle.margin_xxsmall
                rightPadding: VLCStyle.margin_xxsmall
                Layout.fillHeight: true

                visible: modelData.enabled
                checked: root.currentTab === modelData.tab
                text: modelData.text

                onClicked: root.currentTab = modelData.tab

                background: Item {
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: VLCStyle.margin_small
                        anchors.rightMargin: VLCStyle.margin_small

                        height: VLCStyle.dp(2, VLCStyle.scale)
                        visible: tabButton.checked
                        color: theme.accent
                    }
                }

                // the label is elided when the panel is narrow
                contentItem: RowLayout {
                    spacing: VLCStyle.margin_xsmall

                    Item { Layout.fillWidth: true }

                    Widgets.IconLabel {
                        text: tabButton.modelData.icon
                        font.pixelSize: VLCStyle.icon_small
                        color: tabButton.checked ? theme.accent : theme.fg.secondary
                    }

                    T.Label {
                        Layout.maximumWidth: Math.max(0, tabButton.availableWidth - VLCStyle.icon_small - parent.spacing)
                        text: tabButton.text
                        elide: Text.ElideRight
                        font.pixelSize: VLCStyle.fontSize_normal
                        color: tabButton.checked ? theme.fg.primary : theme.fg.secondary
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: tabBar.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: VLCStyle.margin_small

        Loader {
            id: bookmarksLoader

            anchors.fill: parent

            visible: root.currentTab === QueuePanelPages.Tab.Bookmarks
            active: MainCtx.mediaLibraryAvailable
                    && (visible || status === Loader.Ready)
            source: "qrc:///qt/qml/VLC/MediaLibrary/BookmarkList.qml"
        }

        ListView {
            id: chapters

            anchors.fill: parent

            visible: root.currentTab === QueuePanelPages.Tab.Chapters
            clip: true
            model: visible ? Player.chapters : null

            T.ScrollBar.vertical: Widgets.ScrollBarExt { }

            delegate: T.ItemDelegate {
                id: chapter

                required property int index
                required property var model

                width: ListView.view.width
                height: VLCStyle.dp(36, VLCStyle.scale)

                leftPadding: VLCStyle.margin_small
                rightPadding: VLCStyle.margin_small

                onClicked: Player.chapters.selectChapter(index)

                background: Rectangle {
                    radius: VLCStyle.dp(4, VLCStyle.scale)
                    color: chapter.model.checked ? theme.bg.secondary
                                                 : (chapter.hovered ? Qt.alpha(theme.bg.secondary, 0.5) : "transparent")
                }

                contentItem: RowLayout {
                    spacing: VLCStyle.margin_normal

                    T.Label {
                        Layout.preferredWidth: VLCStyle.dp(20, VLCStyle.scale)
                        text: chapter.index + 1
                        color: theme.accent
                        font.pixelSize: VLCStyle.fontSize_normal
                    }

                    T.Label {
                        Layout.fillWidth: true
                        text: chapter.model.display
                        elide: Text.ElideRight
                        color: theme.fg.primary
                        font.pixelSize: VLCStyle.fontSize_normal
                    }

                    T.Label {
                        text: chapter.model.time.formatHMS(VLCTick.AlwaysShowHours)
                        color: theme.fg.secondary
                        font.pixelSize: VLCStyle.fontSize_normal
                        font.features: { "tnum": 1 }
                    }
                }
            }

            T.Label {
                anchors.centerIn: parent
                visible: chapters.count === 0
                text: qsTr("This media has no chapters")
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.fontSize_normal
            }
        }
    }
}
