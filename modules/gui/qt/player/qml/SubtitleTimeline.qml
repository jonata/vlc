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

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Util

// Seek bar zoomed on a window around the current time, showing when the
// subtitles appear. Dragging the subtitles, or the arrow buttons, changes
// the subtitle delay.
FocusScope {
    id: root

    // start and end of each cue, in milliseconds: [start0, end0, start1, end1, ...]
    property var cues: []

    property real barHeight: VLCStyle.seekBar_height

    // visible duration, in milliseconds
    readonly property var _windowLengths: [10000, 25000, 50000, 100000, 200000]
    property int zoomLevel: 2
    readonly property real windowLength: _windowLengths[zoomLevel]

    // first visible time, in milliseconds
    property real windowStart: 0
    readonly property real windowEnd: windowStart + windowLength

    readonly property real _length: Player.length.toMilliseconds()
    readonly property real _time: Player.time.toMilliseconds()
    readonly property real _delay: Player.subtitleDelayMS

    // the subtitle delay changes by this much with the arrow buttons
    readonly property int delayStep: 50

    implicitHeight: barHeight
    implicitWidth: VLCStyle.dp(200, VLCStyle.scale)

    // keeps the current time in the window, turning pages as it moves
    function _follow() {
        if (_mouseArea._mode === "cue")
            return
        if (_time < windowStart || _time > windowStart + windowLength * 0.9)
            windowStart = Math.max(0, Math.min(_time - windowLength * 0.1, Math.max(0, _length - windowLength)))
    }

    on_TimeChanged: _follow()
    onWindowLengthChanged: {
        windowStart = Math.max(0, _time - windowLength / 2)
        _follow()
    }
    Component.onCompleted: _follow()

    function _xOf(ms: real) : real {
        return (ms - windowStart) / windowLength * track.width
    }

    function _timeAt(x: real) : real {
        return windowStart + Helpers.clamp(x / track.width, 0, 1) * windowLength
    }

    function _seek(ms: real) {
        if (_length > 0)
            Player.position = Helpers.clamp(ms / _length, 0, 1)
    }

    function _setDelay(ms: int) {
        Player.subtitleDelayMS = ms
        delayLabel.show()
    }

    // returns whether a cue is displayed at this time
    function _cueAt(ms: real) : bool {
        const t = ms - _delay
        for (let i = 0; i + 1 < cues.length; i += 2) {
            if (cues[i] > t)
                return false
            if (cues[i + 1] >= t)
                return true
        }
        return false
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Slider
    }

    Rectangle {
        anchors.fill: parent

        radius: VLCStyle.seekBar_radius
        color: theme.bg.primary
    }

    Row {
        id: leftButtons

        anchors.left: parent.left
        anchors.leftMargin: VLCStyle.seekBar_inset
        anchors.verticalCenter: parent.verticalCenter

        spacing: VLCStyle.seekBar_inset

        TimelineButton {
            text: qsTr("Show the subtitles earlier")
            iconText: VLCIcons.ic_fluent_chevron_left_24
            onClicked: root._setDelay(root._delay - root.delayStep)
        }

        TimelineButton {
            text: qsTr("Zoom out")
            iconText: VLCIcons.remove
            enabled: root.zoomLevel < root._windowLengths.length - 1
            autoRepeat: false
            onClicked: root.zoomLevel += 1
        }
    }

    Row {
        id: rightButtons

        anchors.right: parent.right
        anchors.rightMargin: VLCStyle.seekBar_inset
        anchors.verticalCenter: parent.verticalCenter

        spacing: VLCStyle.seekBar_inset

        TimelineButton {
            text: qsTr("Zoom in")
            iconText: VLCIcons.add
            enabled: root.zoomLevel > 0
            autoRepeat: false
            onClicked: root.zoomLevel -= 1
        }

        TimelineButton {
            text: qsTr("Show the subtitles later")
            iconText: VLCIcons.ic_fluent_chevron_right_24
            onClicked: root._setDelay(root._delay + root.delayStep)
        }
    }

    Item {
        id: track

        anchors.left: leftButtons.right
        anchors.right: rightButtons.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: VLCStyle.seekBar_inset

        clip: true

        // played part
        Rectangle {
            width: Helpers.clamp(root._xOf(root._time), 0, track.width)
            height: parent.height

            radius: VLCStyle.seekBar_handleRadius
            color: theme.bg.highlight
        }

        // the cues, shifted by the subtitle delay
        Repeater {
            model: Math.floor(root.cues.length / 2)

            Rectangle {
                required property int index

                readonly property real _start: root.cues[2 * index] + root._delay
                readonly property real _end: root.cues[2 * index + 1] + root._delay

                visible: _end >= root.windowStart && _start <= root.windowEnd

                x: root._xOf(_start)
                width: Math.max(VLCStyle.dp(2, VLCStyle.scale), root._xOf(_end) - x)
                height: parent.height

                radius: VLCStyle.seekBar_handleRadius
                color: Qt.alpha(theme.fg.secondary, 0.3)
            }
        }

        // handle, its right edge follows the time
        Rectangle {
            readonly property real _x: root._xOf(root._time)

            visible: _x >= 0 && _x <= track.width

            x: Math.max(0, _x - width)
            width: VLCStyle.seekBar_handleWidth
            height: parent.height

            radius: VLCStyle.seekBar_handleRadius
            color: theme.fg.primary
        }

        MouseArea {
            id: _mouseArea

            anchors.fill: parent

            // "seek" while scrubbing, "cue" while dragging the subtitles
            property string _mode: ""
            property real _pressX: 0
            property int _pressDelay: 0

            hoverEnabled: true
            cursorShape: (_mode === "cue" || (_mode === "" && containsMouse && root._cueAt(root._timeAt(mouseX))))
                         ? Qt.SizeHorCursor : Qt.ArrowCursor

            onPressed: (mouse) => {
                _pressX = mouse.x
                _pressDelay = root._delay
                if (root._cueAt(root._timeAt(mouse.x))) {
                    _mode = "cue"
                } else {
                    _mode = "seek"
                    root._seek(root._timeAt(mouse.x))
                }
            }

            onPositionChanged: (mouse) => {
                if (_mode === "cue") {
                    const shift = (mouse.x - _pressX) / track.width * root.windowLength
                    root._setDelay(Math.round((_pressDelay + shift) / 10) * 10)
                } else if (_mode === "seek") {
                    root._seek(root._timeAt(mouse.x))
                }
            }

            onReleased: _mode = ""
            onCanceled: _mode = ""
        }
    }

    // subtitle delay, shown while it changes
    Rectangle {
        id: delayLabel

        function show() {
            visible = true
            hideTimer.restart()
        }

        visible: false

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: VLCStyle.margin_xsmall

        width: delayText.implicitWidth + 2 * VLCStyle.seekPreview_padding
        height: delayText.implicitHeight + VLCStyle.seekPreview_padding

        radius: VLCStyle.seekBar_radius
        color: Qt.alpha(theme.bg.primary, 0.95)

        T.Label {
            id: delayText

            anchors.centerIn: parent

            text: qsTr("Subtitle delay: %1 ms").arg(root._delay)
            color: theme.fg.secondary
            font.pixelSize: VLCStyle.fontSize_normal
        }

        Timer {
            id: hideTimer
            interval: 1500
            onTriggered: {
                // stays while the subtitles are dragged
                if (_mouseArea._mode === "cue")
                    restart()
                else
                    delayLabel.visible = false
            }
        }
    }

    component TimelineButton: T.AbstractButton {
        id: button

        property string iconText

        width: root.barHeight - 2 * VLCStyle.seekBar_inset
        height: width

        autoRepeat: true
        focusPolicy: Qt.NoFocus

        Accessible.name: text

        background: Rectangle {
            radius: VLCStyle.seekBar_handleRadius
            color: button.enabled ? (button.pressed ? Qt.darker(theme.fg.primary, 1.2) : theme.fg.primary)
                                  : theme.bg.highlight
        }

        contentItem: T.Label {
            text: button.iconText
            font.family: VLCIcons.fontFamily
            font.pixelSize: VLCStyle.icon_small
            color: theme.bg.primary
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
