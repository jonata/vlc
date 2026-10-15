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

// Network streams: the saved ones, and the ones played recently
Widgets.PageExt {
    id: root

    title: qsTr("Network Streams")

    // saved streams, as [{url, name}]
    property var savedStreams: []

    readonly property string _settingKey: "NetworkStreams/saved"

    Component.onCompleted: {
        try {
            savedStreams = JSON.parse(MainCtx.settingValue(_settingKey, "[]"))
        } catch (e) {
            savedStreams = []
        }
    }

    function _save(streams) {
        savedStreams = streams
        MainCtx.setSettingValue(_settingKey, JSON.stringify(streams))
    }

    function addStreams(urls) {
        const streams = savedStreams.slice()
        for (const url of urls) {
            if (!streams.some(stream => stream.url === url))
                streams.push({ url: url, name: "" })
        }
        _save(streams)
    }

    function removeStream(index) {
        const streams = savedStreams.slice()
        streams.splice(index, 1)
        _save(streams)
    }

    headerActions: [
        Widgets.ButtonExt {
            text: qsTr("Add")
            iconTxt: VLCIcons.add
            onClicked: addDialog.open()
        }
    ]

    readonly property ColorContext _theme: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    AddStreamDialog {
        id: addDialog
        onStreamsAdded: (urls) => root.addStreams(urls)
    }

    // the layout is not anchored to the page directly, as its size would
    // depend on the page
    Item {
        anchors.fill: parent

        focus: true

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: VLCStyle.dynamicAppMargins(parent.width) + VLCStyle.layout_left_margin
            anchors.rightMargin: VLCStyle.dynamicAppMargins(parent.width) + VLCStyle.layout_right_margin

            focus: true
            spacing: VLCStyle.margin_small

            T.Label {
                Layout.fillWidth: true
                text: qsTr("Saved")
                color: theme.fg.primary
                font.pixelSize: VLCStyle.fontSize_large
                font.weight: Font.DemiBold
            }

            T.Label {
                Layout.fillWidth: true
                visible: root.savedStreams.length === 0
                text: qsTr("Add the links of streams, or of a list of channels, to find them here.")
                wrapMode: Text.Wrap
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.fontSize_normal
            }

            ListView {
                id: savedList

                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, root.height / 2)

                visible: count > 0
                clip: true
                model: root.savedStreams

                delegate: T.ItemDelegate {
                    id: stream

                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    height: VLCStyle.dp(40, VLCStyle.scale)

                    leftPadding: VLCStyle.margin_small
                    rightPadding: VLCStyle.margin_xsmall

                    onDoubleClicked: urlModel.addAndPlay(stream.modelData.url)

                    background: Rectangle {
                        radius: VLCStyle.dp(4, VLCStyle.scale)
                        color: stream.hovered ? theme.bg.secondary : "transparent"
                    }

                    contentItem: RowLayout {
                        spacing: VLCStyle.margin_small

                        Widgets.IconLabel {
                            text: VLCIcons.tv
                            font.pixelSize: VLCStyle.icon_small
                            color: theme.fg.secondary
                        }

                        T.Label {
                            Layout.fillWidth: true
                            text: stream.modelData.name || stream.modelData.url
                            elide: Text.ElideMiddle
                            color: theme.fg.primary
                            font.pixelSize: VLCStyle.fontSize_normal
                        }

                        Widgets.IconToolButton {
                            text: VLCIcons.play
                            description: qsTr("Play")
                            onClicked: urlModel.addAndPlay(stream.modelData.url)
                        }

                        Widgets.IconToolButton {
                            text: VLCIcons.close
                            description: qsTr("Remove")
                            onClicked: root.removeStream(stream.index)
                        }
                    }
                }
            }

            T.Label {
                Layout.fillWidth: true
                Layout.topMargin: VLCStyle.margin_normal
                text: qsTr("Recently Played")
                color: theme.fg.primary
                font.pixelSize: VLCStyle.fontSize_large
                font.weight: Font.DemiBold
            }

            T.Label {
                Layout.fillWidth: true
                visible: !history.visible
                text: qsTr("The streams that are played are listed here.")
                wrapMode: Text.Wrap
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.fontSize_normal
            }

            UrlListDisplay {
                id: history

                Layout.fillWidth: true
                Layout.fillHeight: true

                visible: (model?.count ?? 0) > 0
            }

            // keeps the sections at the top when the history is empty
            Item {
                Layout.fillHeight: true
                visible: !history.visible
            }
        }
    }

    MLUrlModel {
        id: urlModel
        ml: MediaLib
    }
}
