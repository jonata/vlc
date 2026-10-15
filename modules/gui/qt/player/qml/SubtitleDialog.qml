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
import VLC.Util

// Adds subtitle files to the current video, to the videos of its folder, or to
// the videos of the play queue. The choices are kept for the next playbacks.
FocusScope {
    id: root

    signal closeRequested()

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    Keys.onEscapePressed: root.closeRequested()

    SubtitleMatcher {
        id: matcher

        ctx: MainCtx
        media: root.visible ? Player.url : ""
    }

    // dims the player, closes on a click outside of the dialog
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha("black", 0.5)

        TapHandler {
            onTapped: root.closeRequested()
        }
    }

    Rectangle {
        id: card

        anchors.centerIn: parent

        width: Math.min(VLCStyle.dp(1048, VLCStyle.scale), parent.width - 2 * VLCStyle.margin_large)
        height: Math.min(VLCStyle.dp(800, VLCStyle.scale), parent.height - 2 * VLCStyle.margin_large)

        radius: VLCStyle.seekPreview_radius
        color: theme.bg.primary
        border.color: theme.border
        border.width: VLCStyle.border

        // keeps the clicks from closing the dialog
        TapHandler { }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: VLCStyle.margin_small

            spacing: VLCStyle.margin_small

            // title
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: VLCStyle.margin_xsmall

                T.Label {
                    Layout.fillWidth: true

                    text: qsTr("Add Subtitles")
                    color: theme.fg.secondary
                    font.pixelSize: VLCStyle.fontSize_large
                }

                Widgets.IconToolButton {
                    text: VLCIcons.close
                    description: qsTr("Close")
                    onClicked: root.closeRequested()
                }
            }

            // what the subtitles are added to, and where they are taken from
            RowLayout {
                Layout.fillWidth: true

                spacing: VLCStyle.margin_small

                DropDown {
                    id: scopeBox

                    Layout.preferredWidth: VLCStyle.dp(190, VLCStyle.scale)
                    Layout.preferredHeight: VLCStyle.dp(32, VLCStyle.scale)

                    model: [qsTr("To This File"), qsTr("To This Folder"), qsTr("To This Playlist")]
                    currentIndex: matcher.scope

                    onActivated: (index) => { matcher.scope = index }
                }

                T.AbstractButton {
                    id: folderButton

                    Layout.fillWidth: true
                    Layout.preferredHeight: VLCStyle.dp(32, VLCStyle.scale)

                    Accessible.name: qsTr("Subtitle folder")

                    onClicked: matcher.chooseFolder()

                    background: Rectangle {
                        radius: VLCStyle.dp(2, VLCStyle.scale)
                        color: folderButton.hovered ? theme.bg.secondary : Qt.lighter(theme.bg.primary, 1.25)
                    }

                    contentItem: RowLayout {
                        spacing: VLCStyle.margin_small

                        Widgets.IconLabel {
                            Layout.leftMargin: VLCStyle.margin_small

                            text: VLCIcons.folder
                            font.pixelSize: VLCStyle.icon_normal
                            color: theme.fg.secondary
                        }

                        T.Label {
                            Layout.fillWidth: true

                            text: {
                                const path = matcher.subtitleFolder.toString().replace(/^file:\/\//, "")
                                return decodeURIComponent(path).split("/").filter(part => part !== "").join(" / ")
                            }
                            elide: Text.ElideLeft
                            color: theme.fg.secondary
                            font.pixelSize: VLCStyle.fontSize_normal
                        }
                    }
                }
            }

            ListView {
                id: list

                Layout.fillWidth: true
                Layout.fillHeight: true

                clip: true
                model: matcher
                spacing: VLCStyle.margin_xxxsmall

                T.ScrollBar.vertical: Widgets.ScrollBarExt { }

                delegate: matcher.scope === SubtitleMatcher.FileScope ? fileDelegate : matchDelegate

                T.Label {
                    anchors.centerIn: parent

                    visible: list.count === 0
                    text: (matcher.scope === SubtitleMatcher.FileScope) ? qsTr("No subtitle file in this folder")
                                                                         : qsTr("No video to match")
                    color: theme.fg.secondary
                    font.pixelSize: VLCStyle.fontSize_normal
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Widgets.DialogButton {
                    text: qsTr("Cancel")
                    onClicked: root.closeRequested()
                }

                Item { Layout.fillWidth: true }

                Widgets.DialogButton {
                    text: qsTr("Save")
                    enabled: matcher.hasSelection
                    accent: true

                    onClicked: {
                        matcher.save()
                        root.closeRequested()
                    }
                }
            }
        }
    }

    // a subtitle file, to check
    Component {
        id: fileDelegate

        T.ItemDelegate {
            id: fileItem

            required property int index
            required property var model

            readonly property bool _checked: model.checked

            width: ListView.view.width
            height: VLCStyle.dp(36, VLCStyle.scale)

            onClicked: matcher.toggle(index)

            background: Rectangle {
                radius: VLCStyle.dp(4, VLCStyle.scale)
                color: fileItem._checked ? Qt.darker(theme.bg.primary, 1.4)
                                        : (fileItem.hovered ? theme.bg.secondary : "transparent")
            }

            contentItem: RowLayout {
                spacing: VLCStyle.margin_small

                Widgets.IconLabel {
                    Layout.leftMargin: VLCStyle.margin_xsmall
                    text: VLCIcons.audiosub
                    font.pixelSize: VLCStyle.icon_normal
                    color: theme.fg.secondary
                }

                T.Label {
                    Layout.fillWidth: true
                    text: fileItem.model.name
                    elide: Text.ElideMiddle
                    color: theme.fg.primary
                    font.pixelSize: VLCStyle.fontSize_normal
                }

                Widgets.IconLabel {
                    Layout.rightMargin: VLCStyle.margin_xsmall
                    visible: fileItem._checked
                    text: VLCIcons.check
                    font.pixelSize: VLCStyle.icon_normal
                    color: theme.accent
                }
            }
        }
    }

    // a video, with the subtitle file matched to it
    Component {
        id: matchDelegate

        Item {
            id: matchItem

            required property int index
            required property string name
            required property int subtitle

            width: ListView.view.width
            height: VLCStyle.dp(36, VLCStyle.scale)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: VLCStyle.margin_xsmall
                anchors.rightMargin: VLCStyle.margin_xsmall

                spacing: VLCStyle.margin_small

                Widgets.IconLabel {
                    text: VLCIcons.topbar_video
                    font.pixelSize: VLCStyle.icon_normal
                    color: theme.fg.secondary
                }

                T.Label {
                    Layout.preferredWidth: implicitWidth
                    Layout.maximumWidth: matchItem.width * 0.4

                    text: matchItem.name
                    elide: Text.ElideMiddle
                    color: theme.fg.primary
                    font.pixelSize: VLCStyle.fontSize_normal
                }

                // dashed line from the video to its subtitle
                Row {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter

                    clip: true
                    spacing: VLCStyle.dp(4, VLCStyle.scale)

                    opacity: (matchItem.subtitle >= 0) ? 1 : 0.3

                    Repeater {
                        model: Math.ceil(parent.width / VLCStyle.dp(10, VLCStyle.scale))

                        Rectangle {
                            width: VLCStyle.dp(6, VLCStyle.scale)
                            height: VLCStyle.dp(1, VLCStyle.scale)
                            color: theme.fg.secondary
                        }
                    }
                }

                Widgets.IconLabel {
                    text: VLCIcons.audiosub
                    font.pixelSize: VLCStyle.icon_normal
                    color: theme.fg.secondary
                }

                DropDown {
                    Layout.preferredWidth: matchItem.width * 0.4

                    plain: true
                    Layout.preferredHeight: VLCStyle.dp(30, VLCStyle.scale)

                    // the first choice removes the subtitle
                    model: [qsTr("No subtitle")].concat(matcher.subtitleNames)
                    currentIndex: matchItem.subtitle + 1

                    onActivated: (index) => matcher.setSubtitle(matchItem.index, index - 1)
                }
            }
        }
    }

    // drop-down in the style of the dialog
    component DropDown: T.ComboBox {
        id: dropDown

        // without background until hovered
        property bool plain: false

        font.pixelSize: VLCStyle.fontSize_normal

        leftPadding: VLCStyle.margin_small
        rightPadding: VLCStyle.margin_small

        background: Rectangle {
            radius: VLCStyle.dp(2, VLCStyle.scale)
            color: (dropDown.hovered || dropDown.popup.visible) ? theme.bg.secondary
                                                                : (dropDown.plain ? "transparent" : Qt.lighter(theme.bg.primary, 1.25))
        }

        contentItem: T.Label {
            rightPadding: dropDown.indicator.width + VLCStyle.margin_xsmall
            text: dropDown.displayText
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            color: theme.fg.secondary
            font: dropDown.font
        }

        indicator: Widgets.IconLabel {
            x: dropDown.width - width - dropDown.rightPadding
            y: (dropDown.height - height) / 2
            visible: !dropDown.plain || dropDown.hovered || dropDown.popup.visible
            text: VLCIcons.chevron_down
            font.pixelSize: VLCStyle.icon_small
            color: theme.fg.secondary
        }

        delegate: T.ItemDelegate {
            id: choice

            required property int index
            required property var modelData

            width: ListView.view.width
            padding: VLCStyle.margin_xsmall
            leftPadding: VLCStyle.margin_small

            highlighted: dropDown.highlightedIndex === index

            background: Rectangle {
                color: choice.highlighted ? theme.bg.secondary : "transparent"
            }

            contentItem: T.Label {
                text: choice.modelData
                elide: Text.ElideRight
                color: (choice.index === dropDown.currentIndex) ? theme.accent : theme.fg.primary
                font: dropDown.font
            }
        }

        popup: T.Popup {
            y: dropDown.height + VLCStyle.margin_xxxsmall
            width: dropDown.width
            height: Math.min(contentItem.implicitHeight + topPadding + bottomPadding,
                             VLCStyle.dp(300, VLCStyle.scale))
            padding: VLCStyle.margin_xxxsmall

            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: dropDown.popup.visible ? dropDown.delegateModel : null
                currentIndex: dropDown.highlightedIndex
            }

            background: Rectangle {
                radius: VLCStyle.dp(4, VLCStyle.scale)
                color: theme.bg.primary
                border.color: theme.border
                border.width: VLCStyle.border
            }
        }
    }
}
