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
import VLC.Dialogs
import VLC.Widgets as Widgets
import VLC.Util

// Settings used while watching, grouped in four tabs: subtitles, audio,
// video and playback.
FocusScope {
    id: root

    enum Tab {
        Subtitles,
        Audio,
        Video,
        Playback
    }

    property int currentTab: SettingsSidebar.Tab.Subtitles

    signal closeRequested()
    signal addSubtitlesRequested()

    implicitWidth: VLCStyle.settingsSidebar_width

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Player settings")

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    Keys.onEscapePressed: root.closeRequested()

    VideoAdjust {
        id: videoAdjust
        player: Player
    }

    AudioEqualizer {
        id: audioEqualizer
        player: Player
    }

    SubtitleStyle {
        id: subtitleStyle
        player: Player
    }

    // Show presets: the settings can be saved for the folder of the media,
    // typically the episodes of a show, and are restored when a media of
    // this folder is played.

    PlayerPresets {
        id: presets
        ctx: MainCtx
    }

    // folder of the current media, local files only
    readonly property string currentFolder: {
        const url = Player.url.toString()
        if (!url.startsWith("file://"))
            return ""
        const path = decodeURIComponent(url.substring(7))
        return path.substring(0, path.lastIndexOf("/"))
    }

    readonly property string _currentFolderName: currentFolder.substring(currentFolder.lastIndexOf("/") + 1)
    readonly property bool _hasPreset: presets.has(currentFolder) && presets.folders.length >= 0

    // the preset was restored for the current media
    property bool presetApplied: false

    function collectSettings() {
        return {
            "subtitleDelay": Player.subtitleDelayMS,
            "subtitleSpeed": Player.subtitleFPS,
            "subtitleTrack": presets.checkedRow(Player.subtitleTracks),
            "subtitleLanguage": presets.checkedLanguage(Player.subtitleTracks),
            "textScale": subtitleStyle.textScale,
            "textColor": subtitleStyle.textColor.toString(),
            "outlineThickness": subtitleStyle.outlineThickness,
            "backgroundOpacity": subtitleStyle.backgroundOpacity,
            "margin": subtitleStyle.margin,
            "audioDelay": Player.audioDelayMS,
            "audioTrack": presets.checkedRow(Player.audioTracks),
            "audioLanguage": presets.checkedLanguage(Player.audioTracks),
            "equalizerEnabled": audioEqualizer.enabled,
            "equalizerPreset": audioEqualizer.preset,
            "equalizerPreamp": audioEqualizer.preamp,
            "equalizerBands": audioEqualizer.bands,
            "adjustEnabled": videoAdjust.enabled,
            "contrast": videoAdjust.contrast,
            "brightness": videoAdjust.brightness,
            "hue": videoAdjust.hue,
            "saturation": videoAdjust.saturation,
            "gamma": videoAdjust.gamma,
            "rate": Player.rate
        }
    }

    function applySettings(values) {
        Player.subtitleDelayMS = values.subtitleDelay ?? 0
        Player.subtitleFPS = values.subtitleSpeed ?? 1
        // the tracks are selected by language, as their order may change between episodes
        if (!presets.checkLanguage(Player.subtitleTracks, values.subtitleLanguage ?? ""))
            presets.checkRow(Player.subtitleTracks, values.subtitleTrack ?? -1)

        subtitleStyle.textScale = values.textScale ?? subtitleStyle.textScale
        subtitleStyle.textColor = values.textColor ?? subtitleStyle.textColor
        subtitleStyle.outlineThickness = values.outlineThickness ?? subtitleStyle.outlineThickness
        subtitleStyle.backgroundOpacity = values.backgroundOpacity ?? subtitleStyle.backgroundOpacity
        subtitleStyle.margin = values.margin ?? subtitleStyle.margin

        Player.audioDelayMS = values.audioDelay ?? 0
        if (!presets.checkLanguage(Player.audioTracks, values.audioLanguage ?? ""))
            presets.checkRow(Player.audioTracks, values.audioTrack ?? -1)

        // changing the values enables the filters, their state is restored afterwards
        if ((values.equalizerPreset ?? -1) >= 0) {
            audioEqualizer.applyPreset(values.equalizerPreset)
        } else {
            const bands = values.equalizerBands ?? []
            for (let i = 0; i < bands.length; ++i)
                audioEqualizer.setBand(i, bands[i])
            audioEqualizer.preamp = values.equalizerPreamp ?? audioEqualizer.preamp
        }
        audioEqualizer.enabled = values.equalizerEnabled ?? false

        videoAdjust.contrast = values.contrast ?? 1
        videoAdjust.brightness = values.brightness ?? 1
        videoAdjust.hue = values.hue ?? 0
        videoAdjust.saturation = values.saturation ?? 1
        videoAdjust.gamma = values.gamma ?? 1
        videoAdjust.enabled = values.adjustEnabled ?? false

        Player.rate = values.rate ?? 1
    }

    Connections {
        target: Player

        function onInputChanged(hasInput) {
            root.presetApplied = false
            if (hasInput)
                presetTimer.restart()
            else
                presetTimer.stop()
        }
    }

    // the sidebar may be created once the media has started
    Component.onCompleted: {
        if (Player.isStarted)
            presetTimer.start()
    }

    // the tracks are known a moment after the media starts
    Timer {
        id: presetTimer

        interval: 1500

        onTriggered: {
            if (!presets.has(root.currentFolder))
                return
            root.applySettings(presets.load(root.currentFolder))
            root.presetApplied = true
        }
    }

    // outline thickness of each choice of the subtitle style
    readonly property var _outlineThicknesses: [0, 2, 4, 6]

    // Sleep timer: pauses the playback after a delay, or stops it at the
    // end of the current media. The delays are in minutes, 0 is off and -1
    // is the end of the current media.
    readonly property var _sleepDelays: [0, 15, 30, 45, 60, 90, -1]
    property int sleepChoice: 0
    property real _sleepDeadline: 0
    property int _sleepRemaining: 0 // in seconds

    onSleepChoiceChanged: {
        const minutes = _sleepDelays[sleepChoice]
        _sleepDeadline = (minutes > 0) ? Date.now() + minutes * 60 * 1000 : 0
        _sleepRemaining = minutes * 60
    }

    Timer {
        interval: 1000
        repeat: true
        running: root._sleepDeadline > 0

        onTriggered: {
            root._sleepRemaining = Math.max(0, Math.round((root._sleepDeadline - Date.now()) / 1000))
            if (root._sleepRemaining === 0) {
                MainPlaylistController.pause()
                root.sleepChoice = 0
            }
        }
    }

    Connections {
        target: MainPlaylistController
        enabled: root._sleepDelays[root.sleepChoice] === -1

        // the next media started: the current one has ended
        function onCurrentIndexChanged() {
            MainPlaylistController.stop()
            root.sleepChoice = 0
        }
    }

    Rectangle {
        anchors.fill: parent

        // a bit darker than the bars, so that the sections stand out
        color: Qt.darker(theme.bg.primary, 1.9)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: VLCStyle.margin_normal

        spacing: VLCStyle.margin_normal

        RowLayout {
            Layout.fillWidth: true

            spacing: VLCStyle.margin_xsmall

            Repeater {
                model: [
                    { tab: SettingsSidebar.Tab.Subtitles, icon: VLCIcons.audiosub, text: qsTr("Subtitles") },
                    { tab: SettingsSidebar.Tab.Audio, icon: VLCIcons.audio_tracks, text: qsTr("Audio") },
                    { tab: SettingsSidebar.Tab.Video, icon: VLCIcons.topbar_video, text: qsTr("Video") },
                    { tab: SettingsSidebar.Tab.Playback, icon: VLCIcons.effect_filter, text: qsTr("Playback") }
                ]

                delegate: Widgets.IconToolButton {
                    required property var modelData

                    text: modelData.icon
                    description: modelData.text

                    checkable: true
                    checked: root.currentTab === modelData.tab

                    onClicked: root.currentTab = modelData.tab
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Widgets.IconToolButton {
                text: VLCIcons.close
                description: qsTr("Close")

                onClicked: root.closeRequested()
            }
        }

        T.Label {
            Layout.fillWidth: true

            text: {
                switch (root.currentTab) {
                case SettingsSidebar.Tab.Audio: return qsTr("Audio")
                case SettingsSidebar.Tab.Video: return qsTr("Video")
                case SettingsSidebar.Tab.Playback: return qsTr("Playback")
                default: return qsTr("Subtitles")
                }
            }

            color: theme.fg.primary
            font.pixelSize: VLCStyle.fontSize_large
            font.weight: Font.DemiBold
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: presetColumn.implicitHeight + 2 * VLCStyle.margin_small

            visible: root.currentFolder !== ""

            radius: VLCStyle.settingsSection_radius
            color: theme.bg.primary

            ColumnLayout {
                id: presetColumn

                x: VLCStyle.settingsSection_padding
                y: VLCStyle.margin_small
                width: parent.width - 2 * VLCStyle.settingsSection_padding

                spacing: VLCStyle.margin_xsmall

                T.Label {
                    Layout.fillWidth: true

                    text: root._hasPreset ? qsTr("Preset of \u201c%1\u201d").arg(root._currentFolderName)
                                          : qsTr("No preset for \u201c%1\u201d").arg(root._currentFolderName)
                    elide: Text.ElideMiddle
                    color: theme.fg.primary
                    font.pixelSize: VLCStyle.fontSize_normal
                }

                T.Label {
                    Layout.fillWidth: true

                    visible: root.presetApplied
                    text: qsTr("Restored for this media")
                    color: theme.accent
                    font.pixelSize: VLCStyle.fontSize_small
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: VLCStyle.margin_xsmall

                    ActionButton {
                        text: root._hasPreset ? qsTr("Update") : qsTr("Save for this folder")
                        onClicked: presets.save(root.currentFolder, root.collectSettings())
                    }

                    ActionButton {
                        visible: root._hasPreset
                        text: qsTr("Remove")
                        onClicked: {
                            presets.remove(root.currentFolder)
                            root.presetApplied = false
                        }
                    }
                }
            }
        }

        Flickable {
            id: flickable

            Layout.fillWidth: true
            Layout.fillHeight: true

            clip: true
            contentHeight: tabs.item?.implicitHeight ?? 0
            boundsBehavior: Flickable.StopAtBounds

            T.ScrollBar.vertical: Widgets.ScrollBarExt {
                policy: (flickable.contentHeight > flickable.height) ? T.ScrollBar.AsNeeded
                                                                    : T.ScrollBar.AlwaysOff
            }

            Loader {
                id: tabs

                width: flickable.width

                // only the current page is loaded, so that the content height is its height
                sourceComponent: [subtitlesPage, audioPage, videoPage, playbackPage][root.currentTab]
            }
        }
    }

    Component {
        id: subtitlesPage

        ColumnLayout {
            spacing: VLCStyle.margin_small

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("Track")

                SettingsOptionList {
                    Layout.fillWidth: true
                    model: Player.subtitleTracks
                    emptyText: qsTr("No subtitles")
                }
            }

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("Timing")

                SettingsSlider {
                    Layout.fillWidth: true

                    label: qsTr("Delay")
                    valueText: qsTr("%1 ms").arg(Player.subtitleDelayMS)

                    from: -10000
                    to: 10000
                    stepSize: 50
                    snapMode: T.Slider.SnapAlways

                    value: Player.subtitleDelayMS
                    onMoved: Player.subtitleDelayMS = value
                }

                SettingsSlider {
                    Layout.fillWidth: true

                    label: qsTr("Speed")
                    valueText: qsTr("%1x").arg(Player.subtitleFPS.toFixed(2))

                    from: 0.5
                    to: 2
                    stepSize: 0.05
                    snapMode: T.Slider.SnapAlways

                    value: Player.subtitleFPS
                    onMoved: Player.subtitleFPS = value
                }
            }

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("Style")

                SettingsSlider {
                    Layout.fillWidth: true

                    label: qsTr("Size")
                    valueText: qsTr("%1%").arg(subtitleStyle.textScale)

                    from: 50
                    to: 300
                    stepSize: 5
                    snapMode: T.Slider.SnapAlways

                    value: subtitleStyle.textScale
                    onMoved: subtitleStyle.textScale = value
                }

                T.Label {
                    Layout.fillWidth: true

                    text: qsTr("Color")
                    color: theme.fg.primary
                    font.pixelSize: VLCStyle.fontSize_normal
                }

                Row {
                    spacing: VLCStyle.margin_small

                    Repeater {
                        model: ["#ffffff", "#ffff00", "#00ffff", "#00ff00", "#ff8000"]

                        delegate: T.AbstractButton {
                            id: swatch

                            required property string modelData

                            readonly property bool selected: Qt.colorEqual(subtitleStyle.textColor, modelData)

                            implicitWidth: VLCStyle.icon_normal
                            implicitHeight: VLCStyle.icon_normal

                            Accessible.role: Accessible.RadioButton
                            Accessible.name: modelData
                            Accessible.checked: selected

                            onClicked: subtitleStyle.textColor = modelData

                            background: Rectangle {
                                radius: width / 2
                                color: swatch.modelData

                                border.width: swatch.selected ? VLCStyle.dp(2, VLCStyle.scale) : 0
                                border.color: theme.accent
                            }
                        }
                    }
                }

                T.Label {
                    Layout.fillWidth: true

                    text: qsTr("Text outline")
                    color: theme.fg.primary
                    font.pixelSize: VLCStyle.fontSize_normal
                }

                SettingsOptionList {
                    Layout.fillWidth: true

                    choices: [qsTr("None"), qsTr("Thin"), qsTr("Normal"), qsTr("Thick")]
                    currentIndex: root._outlineThicknesses.indexOf(subtitleStyle.outlineThickness)

                    onSelected: (index) => { subtitleStyle.outlineThickness = root._outlineThicknesses[index] }
                }

                SettingsSlider {
                    Layout.fillWidth: true

                    label: qsTr("Background")
                    valueText: qsTr("%1%").arg(Math.round(subtitleStyle.backgroundOpacity / 2.55))

                    from: 0
                    to: 255
                    stepSize: 1
                    snapMode: T.Slider.SnapAlways

                    value: subtitleStyle.backgroundOpacity
                    onMoved: subtitleStyle.backgroundOpacity = value
                }

                SettingsSlider {
                    Layout.fillWidth: true

                    label: qsTr("Position")
                    valueText: qsTr("%1 px").arg(subtitleStyle.margin)

                    from: 0
                    to: 300
                    stepSize: 5
                    snapMode: T.Slider.SnapAlways

                    value: subtitleStyle.margin
                    onMoved: subtitleStyle.margin = value
                }

                ActionButton {
                    text: qsTr("Reset")
                    onClicked: subtitleStyle.reset()
                }
            }

            ActionButton {
                text: qsTr("Add subtitle file...")
                onClicked: root.addSubtitlesRequested()
            }
        }
    }

    Component {
        id: audioPage

        ColumnLayout {
            spacing: VLCStyle.margin_small

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("Track")

                SettingsOptionList {
                    Layout.fillWidth: true
                    model: Player.audioTracks
                }
            }

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("Output device")

                SettingsOptionList {
                    Layout.fillWidth: true
                    model: Player.audioDevices
                }
            }

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("Timing")

                SettingsSlider {
                    Layout.fillWidth: true

                    label: qsTr("Delay")
                    valueText: qsTr("%1 ms").arg(Player.audioDelayMS)

                    from: -10000
                    to: 10000
                    stepSize: 50
                    snapMode: T.Slider.SnapAlways

                    value: Player.audioDelayMS
                    onMoved: Player.audioDelayMS = value
                }
            }

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("Equalizer")

                checkable: true
                checked: audioEqualizer.enabled
                onToggled: (checked) => { audioEqualizer.enabled = checked }

                SettingsSlider {
                    Layout.fillWidth: true

                    label: qsTr("Preamp")
                    valueText: qsTr("%1 dB").arg(audioEqualizer.preamp.toFixed(1))

                    from: -20
                    to: 20
                    stepSize: 0.5
                    snapMode: T.Slider.SnapAlways

                    value: audioEqualizer.preamp
                    onMoved: audioEqualizer.preamp = value
                }

                Repeater {
                    model: audioEqualizer.bandNames

                    delegate: SettingsSlider {
                        required property int index
                        required property string modelData

                        Layout.fillWidth: true

                        label: modelData
                        valueText: qsTr("%1 dB").arg(audioEqualizer.bands[index].toFixed(1))

                        from: -20
                        to: 20
                        stepSize: 0.5
                        snapMode: T.Slider.SnapAlways

                        value: audioEqualizer.bands[index]
                        onMoved: audioEqualizer.setBand(index, value)
                    }
                }
            }

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("Equalizer preset")
                expanded: false

                SettingsOptionList {
                    Layout.fillWidth: true

                    choices: audioEqualizer.presetNames
                    currentIndex: audioEqualizer.preset

                    onSelected: (index) => audioEqualizer.applyPreset(index)
                }
            }

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("Stereo mode")
                expanded: false

                SettingsOptionList {
                    Layout.fillWidth: true
                    model: Player.audioStereoMode
                }
            }

            ActionButton {
                text: qsTr("More audio effects...")
                onClicked: DialogsProvider.extendedDialog()
            }
        }
    }

    Component {
        id: videoPage

        ColumnLayout {
            spacing: VLCStyle.margin_small

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("Adjust")

                checkable: true
                checked: videoAdjust.enabled
                onToggled: (checked) => { videoAdjust.enabled = checked }

                SettingsSlider {
                    Layout.fillWidth: true

                    label: qsTr("Hue")
                    valueText: qsTr("%1°").arg(Math.round(videoAdjust.hue))

                    from: -180
                    to: 180
                    stepSize: 1
                    snapMode: T.Slider.SnapAlways

                    value: videoAdjust.hue
                    onMoved: videoAdjust.hue = value
                }

                SettingsSlider {
                    Layout.fillWidth: true

                    label: qsTr("Brightness")
                    valueText: videoAdjust.brightness.toFixed(2)

                    from: 0
                    to: 2
                    stepSize: 0.01
                    snapMode: T.Slider.SnapAlways

                    value: videoAdjust.brightness
                    onMoved: videoAdjust.brightness = value
                }

                SettingsSlider {
                    Layout.fillWidth: true

                    label: qsTr("Contrast")
                    valueText: videoAdjust.contrast.toFixed(2)

                    from: 0
                    to: 2
                    stepSize: 0.01
                    snapMode: T.Slider.SnapAlways

                    value: videoAdjust.contrast
                    onMoved: videoAdjust.contrast = value
                }

                SettingsSlider {
                    Layout.fillWidth: true

                    label: qsTr("Saturation")
                    valueText: videoAdjust.saturation.toFixed(2)

                    from: 0
                    to: 3
                    stepSize: 0.01
                    snapMode: T.Slider.SnapAlways

                    value: videoAdjust.saturation
                    onMoved: videoAdjust.saturation = value
                }

                SettingsSlider {
                    Layout.fillWidth: true

                    label: qsTr("Gamma")
                    valueText: videoAdjust.gamma.toFixed(2)

                    from: 0.01
                    to: 5
                    stepSize: 0.01
                    snapMode: T.Slider.SnapAlways

                    value: videoAdjust.gamma
                    onMoved: videoAdjust.gamma = value
                }

                ActionButton {
                    text: qsTr("Reset")
                    onClicked: videoAdjust.reset()
                }
            }

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("Aspect ratio")

                SettingsOptionList {
                    Layout.fillWidth: true
                    model: Player.aspectRatio
                }
            }

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("Crop")
                expanded: false

                SettingsOptionList {
                    Layout.fillWidth: true
                    model: Player.crop
                }
            }

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("Zoom")
                expanded: false

                SettingsOptionList {
                    Layout.fillWidth: true
                    model: Player.zoom
                }
            }

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("Deinterlace")
                expanded: false

                SettingsOptionList {
                    Layout.fillWidth: true
                    model: Player.deinterlace
                }
            }

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("Track")
                expanded: false

                SettingsOptionList {
                    Layout.fillWidth: true
                    model: Player.videoTracks
                }
            }

            ActionButton {
                text: qsTr("More video effects...")
                onClicked: DialogsProvider.extendedDialog()
            }
        }
    }

    Component {
        id: playbackPage

        ColumnLayout {
            spacing: VLCStyle.margin_small

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("Speed")

                SettingsSlider {
                    Layout.fillWidth: true

                    label: qsTr("Playback speed")
                    valueText: qsTr("%1x").arg(Player.rate.toFixed(2))

                    from: 0.25
                    to: 4
                    stepSize: 0.05
                    snapMode: T.Slider.SnapAlways

                    value: Player.rate
                    onMoved: Player.rate = value
                }
            }

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("Loop")

                ActionButton {
                    text: {
                        switch (Player.ABloopState) {
                        case Player.ABLOOP_STATE_A: return qsTr("Set loop end (B)")
                        case Player.ABLOOP_STATE_B: return qsTr("Clear A-B loop")
                        default: return qsTr("Set loop start (A)")
                        }
                    }
                    onClicked: Player.toggleABloopState()
                }
            }

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("Sleep timer")

                SettingsOptionList {
                    Layout.fillWidth: true

                    choices: [qsTr("Off"), qsTr("15 minutes"), qsTr("30 minutes"), qsTr("45 minutes"),
                              qsTr("1 hour"), qsTr("1 hour 30 minutes"), qsTr("End of current media")]
                    currentIndex: root.sleepChoice

                    onSelected: (index) => { root.sleepChoice = index }
                }

                T.Label {
                    Layout.fillWidth: true

                    visible: root._sleepDeadline > 0

                    text: qsTr("Pausing in %1").arg(
                              Math.floor(root._sleepRemaining / 60) + ":" + String(root._sleepRemaining % 60).padStart(2, "0"))
                    color: theme.accent
                    font.pixelSize: VLCStyle.fontSize_normal
                }
            }

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("Audio visualizer")
                expanded: false

                // the visualizations are those of the audio output
                SettingsOptionList {
                    Layout.fillWidth: true
                    model: Player.audioVisualization
                    emptyText: qsTr("Available during audio playback")
                }
            }

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("Display")

                SettingsToggle {
                    text: qsTr("Show the subtitle timeline on the seek bar")
                    checked: MainCtx.subtitleTimeline
                    onToggled: (checked) => { MainCtx.subtitleTimeline = checked }
                }

                SettingsToggle {
                    text: qsTr("Show thumbnail while scrubbing")
                    checked: MainCtx.seekThumbnails
                    onToggled: (checked) => { MainCtx.seekThumbnails = checked }
                }

                SettingsToggle {
                    text: qsTr("Show waveform on the seek bar")
                    checked: MainCtx.seekWaveform
                    onToggled: (checked) => { MainCtx.seekWaveform = checked }
                }

                SettingsToggle {
                    text: qsTr("Show statistics")
                    checked: MainCtx.playbackStatistics
                    onToggled: (checked) => { MainCtx.playbackStatistics = checked }
                }
            }

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("Chapters")

                visible: Player.hasChapters

                SettingsOptionList {
                    Layout.fillWidth: true
                    model: Player.chapters
                }
            }

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("Titles")
                expanded: false

                visible: Player.hasTitles

                SettingsOptionList {
                    Layout.fillWidth: true
                    model: Player.titles
                }
            }

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("Programs")
                expanded: false

                visible: Player.hasPrograms

                SettingsOptionList {
                    Layout.fillWidth: true
                    model: Player.programs
                }
            }
        }
    }

    component ActionButton: Widgets.ButtonExt {
        Layout.fillWidth: true
    }

    // a labelled switch, for options that are on or off
    component SettingsToggle: Item {
        id: settingsToggle

        property alias text: toggleLabel.text
        property bool checked: false

        signal toggled(bool checked)

        Layout.fillWidth: true
        implicitHeight: Math.max(toggleLabel.implicitHeight, toggleButton.implicitHeight)

        T.Label {
            id: toggleLabel

            anchors.left: parent.left
            anchors.right: toggleButton.left
            anchors.rightMargin: VLCStyle.margin_small
            anchors.verticalCenter: parent.verticalCenter

            elide: Text.ElideRight
            color: theme.fg.primary
            font.pixelSize: VLCStyle.fontSize_normal
        }

        Widgets.CheckButton {
            id: toggleButton

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            text: toggleLabel.text

            onClicked: settingsToggle.toggled(checked)

            // CheckButton positions its handle when checked changes, which
            // needs to happen once its size is known
            Component.onCompleted: Qt.callLater(() => {
                toggleButton.checked = Qt.binding(() => settingsToggle.checked)
            })
        }
    }
}
