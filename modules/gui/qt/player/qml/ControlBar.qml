/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
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
import QtQml.Models


import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.Util

T.Pane {
    id: root

    enum TimeTextPosition {
        Hide,
        AboveSlider,
        LeftRightSlider,
        Inline // time and slider are laid out between the controls, on a single row
    }

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    topInset: _inline ? 0 : sliderY

    bottomPadding: VLCStyle.margin_xsmall

    readonly property real sliderY: mapFromItem(contentItem, 0, contentItem.sliderY).y
    property int textPosition: ControlBar.TimeTextPosition.AboveSlider
    property int identifier: -1
    property real sliderHeight: VLCStyle.heightBar_xxsmall
    property real bookmarksHeight: VLCStyle.controlBarBookmarksHeight
    property bool showRemainingTime: true

    // the controls are customized (see PlayerControlLayout)
    property bool editMode: false

    readonly property bool _inline: (textPosition === ControlBar.TimeTextPosition.Inline)

    // the single row layout always shows the hours, like in the design
    readonly property int _timeFormatFlags: _inline ? VLCTick.AlwaysShowHours : 0

    property var menu: undefined

    signal requestLockUnlockAutoHide(bool lock)

    ///incomming signal to request all menu and popup to close
    signal forceUnlock()

    enabled: visible

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => root.Navigation.defaultKeyAction(event)
    Navigation.cancelAction: function() { History.previous(Qt.BacktabFocusReason) }

    Accessible.name: qsTr("Player controls")
    AccessibleCompat.id: "playerControlBar"

    function showChapterMarks() {
        if (contentItem.trackPositionSlider)
            contentItem.trackPositionSlider.showChapterMarks()
    }

    function applyMenu(menu) {
        if (root.menu === menu)
            return

        // NOTE: When applying a new menu we hide the previous one.
        if (menu)
            dismiss()

        root.menu = menu
    }

    function dismiss() {
        if ((typeof menu === undefined) || !menu)
            return
        if (menu.hasOwnProperty("dismiss"))
            menu.dismiss()
        else if (menu.hasOwnProperty("close"))
            menu.close()
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    SeekThumbnailer {
        id: seekThumbnailer

        ctx: MainCtx
        url: (root._inline && MainCtx.seekThumbnails && Player.hasVideoOutput && Player.isStarted) ? Player.url : ""
    }

    SubtitleCues {
        id: subtitleCues

        ctx: MainCtx
        active: root._inline && MainCtx.subtitleTimeline && Player.isStarted
    }

    // the subtitle timeline replaces the seek bar when the subtitles are known
    readonly property bool _subtitleTimeline: subtitleCues.ready && subtitleCues.cues.length > 0

    // time at a number of milliseconds, rounded to the second for the labels
    function _timeAt(ms: real) : var {
        const length = Player.length
        const lengthMs = Math.max(1, length.toMilliseconds())
        return length.scale((Math.round(ms / 1000) * 1000 + 1) / lengthMs)
    }

    AudioWaveform {
        id: audioWaveform

        ctx: MainCtx
        url: (root._inline && MainCtx.seekWaveform && !Player.hasVideoOutput && Player.isStarted) ? Player.url : ""
    }

    TextMetrics {
        id: timeTextMetrics
        font.pixelSize: {
            switch (textPosition) {
            case ControlBar.TimeTextPosition.LeftRightSlider:
                return VLCStyle.fontSize_small
            case ControlBar.TimeTextPosition.Inline:
                return VLCStyle.seekBar_timeFontSize
            default:
                return VLCStyle.fontSize_normal
            }
        }

        readonly property real preferredWidth: {
            switch (textPosition) {
            case ControlBar.TimeTextPosition.LeftRightSlider:
                return width
            case ControlBar.TimeTextPosition.Inline:
                return Math.max(width, VLCStyle.seekBar_timeWidth)
            default:
                return -1
            }
        }
        text: {
            // This text metrics is used for both the time and length, as we want them to have the same width.
            // Length might not be reported in some cases, for that reason we should check both and use the bigger one.

            // Some extra space to compensate non-monospaced fonts ("-" takes more space than ":", double "-" for guarantee)
            return (Player.time.isSubHour() && Player.length.isSubHour() && !root._inline) ? "00--00" : "00--00--00"
        }
    }

    background: Rectangle {
        color: theme.bg.primary
    }

    contentItem: ColumnLayout {
        spacing: VLCStyle.margin_xsmall

        readonly property real sliderY: root._inline ? 0 : row2.y

        property alias trackPositionSlider: trackPositionSlider

        property alias mediaRemainingTime: mediaRemainingTime

        property alias playerControlLayout: playerControlLayout

        readonly property list<Item> strayItems: [
            T.Label {
                id: mediaTime

                Layout.preferredWidth: timeTextMetrics.preferredWidth

                text: {
                    const length = Player.length
                    const flags = (length.isSubSecond() ? VLCTick.SubSecondFormattedAsMS : 0) | root._timeFormatFlags
                    // the subtitle timeline shows the times of its window
                    if (root._subtitleTimeline)
                        return root._timeAt(subtitleTimeline.windowStart).formatHMS(flags)
                    return Player.time.formatHMS(flags)
                }
                color: theme.fg.primary
                font: timeTextMetrics.font
                horizontalAlignment: Text.AlignHCenter

                // TODO: Do not use `Binding` when minimum Qt is 6.12:
                Binding {
                    target: mediaTime
                    property: "mutabilityGroup"
                    when: (mediaTime.mutabilityGroup !== undefined)
                    value: (Player.playingState === Player.PLAYING_STATE_PLAYING) ? Item.ModerateMutabilityGroup
                                                                                  : Item.StaticMutabilityGroup
                }

                anchors.left: (parent === pseudoRow) ? parent.left : undefined
                anchors.verticalCenter: (parent === pseudoRow) ? parent.verticalCenter : undefined
            },
            T.Label {
                id: mediaRemainingTime

                Layout.preferredWidth: timeTextMetrics.preferredWidth

                readonly property bool showRemainingTime: (MainCtx.showRemainingTime && Player.remainingTime.valid())

                text: {
                    if (root._subtitleTimeline) {
                        const end = Math.min(subtitleTimeline.windowEnd, Player.length.toMilliseconds())
                        return root._timeAt(end).formatHMS(VLCTick.SubSecondFormattedAsMS | root._timeFormatFlags)
                    }
                    return showRemainingTime
                           ? "-" + Player.remainingTime.formatHMS(VLCTick.SubSecondFormattedAsMS | root._timeFormatFlags)
                           : Player.length.formatHMS(VLCTick.SubSecondFormattedAsMS | root._timeFormatFlags)
                }
                color: mediaTime.color
                font: timeTextMetrics.font
                horizontalAlignment: Text.AlignHCenter

                visible: root.showRemainingTime

                // TODO: Do not use `Binding` when minimum Qt is 6.12:
                Binding {
                    target: mediaRemainingTime
                    property: "mutabilityGroup"
                    when: (mediaRemainingTime.mutabilityGroup !== undefined)
                    value: ((Player.playingState === Player.PLAYING_STATE_PLAYING) &&
                            mediaRemainingTime.showRemainingTime) ? Item.ModerateMutabilityGroup
                                                                  : Item.StaticMutabilityGroup
                }

                anchors.right: (parent === pseudoRow) ? parent.right : undefined
                anchors.verticalCenter: (parent === pseudoRow) ? parent.verticalCenter : undefined

                TapHandler {
                    onTapped: (eventPoint, button) => {
                        MainCtx.showRemainingTime = !MainCtx.showRemainingTime
                    }
                }

                HoverHandler {
                    id: mediaRemainingTimeHover
                }

                Widgets.ToolTipExt {
                    colorContext.palette: theme.palette

                    visible: mediaRemainingTimeHover.hovered && MainCtx.showRemainingTime && Player.rate !== 1
                    delay: VLCStyle.delayToolTipAppear
                    text: {
                        if (!visible)
                            return ""

                        const playbackSpeed = Math.abs(Player.rate)
                        const adjustedRemainingTime = Player.remainingTime.scale(1 / playbackSpeed)
                            ? Player.remainingTime.scale(1 / playbackSpeed)
                            : Player.remainingTime

                        return qsTr("%1 (%2x)")
                            .arg(adjustedRemainingTime.formatHMS())
                            .arg(+Player.rate.toFixed(2))
                    }

                    x: (parent.width - width) / 2
                }
            },
            SliderBar {
                id: trackPositionSlider

                barHeight: root._inline ? VLCStyle.seekBar_height : root.sliderHeight
                blockStyle: root._inline

                // the audio player shows the waveform of local files
                waveformPeaks: MainCtx.seekWaveform ? audioWaveform.peaks : []

                seekThumbnailer: root._inline ? seekThumbnailer : null

                // the slider is reparented between rows, so the palette can not
                // be reliably inherited from its parent
                colorContext.palette: theme.palette

                Accessible.role: Accessible.Slider
                Accessible.name: qsTr("Progress")
                AccessibleCompat.id: "progressSlider"

                Layout.fillWidth: true
                enabled: Player.playingState === Player.PLAYING_STATE_PLAYING || Player.playingState === Player.PLAYING_STATE_PAUSED

                Navigation.parentItem: root
                Navigation.downItem: playerControlLayout

                activeFocusOnTab: true

                focus: true

                Keys.onPressed: (event) => {
                    Navigation.defaultKeyAction(event)
                }
            },
            SubtitleTimeline {
                id: subtitleTimeline

                Layout.fillWidth: true

                barHeight: VLCStyle.seekBar_height
                cues: subtitleCues.cues

                colorContext.palette: theme.palette
            },
            Loader {
                id: bookmarksLoader

                parent: root
                // TODO: position the bookmarks relative to the inline slider
                active: MainCtx.mediaLibraryAvailable && !root._inline
                source: "qrc:///qt/qml/VLC/MediaLibrary/Bookmarks.qml"

                x: root.leftPadding + trackPositionSlider.x + row2.Layout.leftMargin
                y: row2.y + row2.height + VLCStyle.margin_xxsmall
                width: trackPositionSlider.width

                onLoaded: {
                   item.barHeight = Qt.binding(function() { return bookmarksHeight })
                   item.controlBarHovered = Qt.binding(function() { return root.hovered })
                   item.yShift = Qt.binding(function() { return row2.height + VLCStyle.margin_xxsmall })
                }
            },
            RowLayout {
                id: inlineRow

                // parented by playerControlLayout when it is used as its center item
                anchors.fill: parent ? parent : undefined
                anchors.leftMargin: playerControlLayout.layoutSpacing
                anchors.rightMargin: playerControlLayout.layoutSpacing

                spacing: VLCStyle.margin_xsmall

                children: root._inline ? [mediaTime, root._subtitleTimeline ? subtitleTimeline : trackPositionSlider, mediaRemainingTime]
                                       : []
            }
        ]

        Item {
            // BUG: RowLayout can not be used here
            // because of a Qt bug. (Height is
            // incorrectly determined. Could be
            // about nested layouting).

            id: pseudoRow
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.leftMargin: VLCStyle.margin_normal
            Layout.rightMargin: VLCStyle.margin_normal

            implicitHeight: visible ? Math.max(mediaTime.implicitHeight, mediaRemainingTime.implicitHeight) : 0

            visible: children.length > 0

            children: {
                switch (textPosition) {
                case ControlBar.TimeTextPosition.AboveSlider:
                    return [mediaTime, mediaRemainingTime]
                case ControlBar.TimeTextPosition.Hide:
                case ControlBar.TimeTextPosition.LeftRightSlider:
                case ControlBar.TimeTextPosition.Inline:
                default:
                    return []
                }
            }
        }

        RowLayout {
            id: row2

            children: {
                switch (textPosition) {
                case ControlBar.TimeTextPosition.Hide:
                case ControlBar.TimeTextPosition.AboveSlider:
                    return [trackPositionSlider]
                case ControlBar.TimeTextPosition.LeftRightSlider:
                    return [mediaTime, trackPositionSlider, mediaRemainingTime]
                case ControlBar.TimeTextPosition.Inline:
                default:
                    return []
                }
            }

            visible: children.length > 0

            spacing: VLCStyle.margin_xsmall

            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.leftMargin: (textPosition === ControlBar.TimeTextPosition.LeftRightSlider) ? VLCStyle.margin_xsmall
                                                                                              : 0

            Layout.rightMargin: Layout.leftMargin
        }

        PlayerControlLayout {
            id: playerControlLayout

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: root._inline ? VLCStyle.controlBarInlineSpacing : VLCStyle.margin_large
            Layout.rightMargin: Layout.leftMargin

            identifier: root.identifier
            editMode: root.editMode

            centerItem: root._inline ? inlineRow : null

            spacing: root._inline ? VLCStyle.margin_xsmall : VLCStyle.margin_normal
            layoutSpacing: root._inline ? VLCStyle.controlBarInlineSpacing : VLCStyle.margin_xxlarge

            implicitHeight: {
                if (root._inline)
                    return VLCStyle.controlLayoutHeightInline
                return MainCtx.pinVideoControls ? VLCStyle.controlLayoutHeightPinned
                                                : VLCStyle.controlLayoutHeight
            }

            visible: !model?.empty ?? false

            Navigation.upItem: trackPositionSlider.enabled ? trackPositionSlider : root.Navigation.upItem

            onRequestLockUnlockAutoHide: (lock) => root.requestLockUnlockAutoHide(lock)

            onMenuOpened: (menu) => root.applyMenu(menu)

            Component.onCompleted: {
                root.forceUnlock.connect(playerControlLayout.forceUnlock)
            }
        }
    }
}
