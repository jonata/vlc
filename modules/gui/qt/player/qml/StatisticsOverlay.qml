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

// Statistics of the current playback, shown over the video
Rectangle {
    id: root

    implicitWidth: grid.implicitWidth + 2 * VLCStyle.seekPreview_padding
    implicitHeight: grid.implicitHeight + 2 * VLCStyle.seekPreview_padding

    radius: VLCStyle.seekPreview_radius
    color: Qt.alpha(theme.bg.primary, 0.85)

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    PlaybackStatistics {
        id: statistics
        player: root.visible ? Player : null
    }

    function _bitrate(kbps: real) : string {
        return (kbps >= 1000) ? qsTr("%1 Mb/s").arg((kbps / 1000).toFixed(2))
                              : qsTr("%1 kb/s").arg(Math.round(kbps))
    }

    readonly property var _rows: {
        const rows = []
        if (statistics.videoCodec !== "") {
            rows.push([qsTr("Video"), statistics.videoCodec])
            if (statistics.videoSize.width > 0)
                rows.push([qsTr("Resolution"), statistics.videoSize.width + "×" + statistics.videoSize.height])
            rows.push([qsTr("Frame rate"), qsTr("%1 fps").arg(statistics.frameRate.toFixed(2))])
            rows.push([qsTr("Dropped frames"), qsTr("%1 late, %2 lost").arg(statistics.latePictures).arg(statistics.lostPictures)])
        }
        if (statistics.audioCodec !== "") {
            rows.push([qsTr("Audio"), statistics.audioCodec])
            if (statistics.audioRate > 0)
                rows.push([qsTr("Sample rate"), qsTr("%1 Hz, %2 channels").arg(statistics.audioRate).arg(statistics.audioChannels)])
            rows.push([qsTr("Dropped audio"), qsTr("%1 buffers").arg(statistics.lostAudioBuffers)])
        }
        rows.push([qsTr("Input bitrate"), _bitrate(statistics.inputBitrate)])
        rows.push([qsTr("Content bitrate"), _bitrate(statistics.contentBitrate)])
        return rows
    }

    GridLayout {
        id: grid

        x: VLCStyle.seekPreview_padding
        y: VLCStyle.seekPreview_padding

        columns: 2
        columnSpacing: VLCStyle.margin_normal
        rowSpacing: VLCStyle.margin_xxxsmall

        Repeater {
            model: root._rows

            T.Label {
                required property var modelData
                required property int index

                Layout.row: index
                Layout.column: 0

                text: modelData[0]
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.fontSize_normal
            }
        }

        Repeater {
            model: root._rows

            T.Label {
                required property var modelData
                required property int index

                Layout.row: index
                Layout.column: 1

                text: modelData[1]
                color: theme.fg.primary
                font.pixelSize: VLCStyle.fontSize_normal
                font.features: { "tnum": 1 }
            }
        }
    }
}
