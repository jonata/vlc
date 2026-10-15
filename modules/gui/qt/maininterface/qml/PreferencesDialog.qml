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
import VLC.Style
import VLC.Widgets as Widgets

// The preferences: pages of options grouped by subject, each option shown
// after its type in the configuration (switch, choices, slider, text, file),
// the changes are saved together
Widgets.CardDialog {
    id: root

    title: qsTr("Preferences")
    acceptText: qsTr("Save")
    acceptEnabled: prefs.modified || _schemeChanged

    preferredWidth: VLCStyle.dp(1048, VLCStyle.scale)
    height: Math.min(VLCStyle.dp(865, VLCStyle.scale), (parent?.height ?? 0) - 2 * VLCStyle.margin_large)

    property int currentPage: 0

    // pages of the options found in the configuration, see _build()
    property var pages: []

    // the color scheme chosen, applied when saved
    property int _scheme: -1
    readonly property bool _schemeChanged: _scheme >= 0 && _scheme !== MainCtx.colorScheme.scheme

    readonly property string _search: searchField.text.trim().toLowerCase()
    readonly property bool _searching: _search !== ""

    // accent colors offered, "default" is the orange of VLC
    readonly property var _accents: ["default", "#3478f6", "#8e5cf6", "#e3489b", "#e5484d", "#30a46c", "#12a594", "system"]

    readonly property real _controlWidth: VLCStyle.dp(280, VLCStyle.scale)

    onOpened: {
        prefs.revert()
        _scheme = -1
        searchField.text = ""
        pages = _build()
        flickable.contentY = 0
        searchField.forceActiveFocus()
    }

    onClosed: prefs.revert()

    onAccepted: {
        if (_schemeChanged)
            onboarding.setColorScheme(_scheme)
        prefs.apply()
    }

    // the dialog is outside of the items of the window, see CardDialog
    readonly property ColorContext _theme: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.Window
    }

    PreferencesModel {
        id: prefs
        ctx: MainCtx
    }

    // to apply the color scheme
    Onboarding {
        id: onboarding
        ctx: MainCtx
    }

    Component {
        id: recentsComponent

        MLRecentMediaModel { }
    }

    // a row is an option of the configuration {option, label}, or one of
    // the interface {kind: "theme", "accent", "button" or "mainctx"};
    // the options missing from this build of VLC are not shown
    function _definitions() {
        return [
            { group: qsTr("App"), title: qsTr("Global"), heading: qsTr("Global Settings"), sections: [
                { title: qsTr("Appearance"), rows: [
                    { kind: "theme", label: qsTr("Theme") },
                    { kind: "accent", label: qsTr("Accent color") },
                ] },
                { title: qsTr("Startup"), rows: [
                    { option: "qt-error-dialogs", label: qsTr("Show confirmation and error dialogs") },
                    { option: "qt-updates-notif", label: qsTr("Check for updates automatically") },
                ] },
                { title: qsTr("Diagnostics"), rows: [
                    { option: "file-logging", label: qsTr("Save a log") },
                    { option: "logfile", label: qsTr("Log file") },
                    { option: "verbose", label: qsTr("Log details") },
                ] },
                { title: qsTr("Settings"), advanced: true, rows: [
                    { option: "logmode", label: qsTr("Log format") },
                    { option: "stats", label: qsTr("Collect playback statistics") },
                    { kind: "button", action: "configFolder", label: qsTr("Open configurations folder"), button: qsTr("Open") },
                    { kind: "button", action: "resetAll", label: qsTr("Reset all settings"), button: qsTr("Reset") },
                ] },
                { title: qsTr("Developer Options"), advanced: true, rows: [
                    { option: "syslog", label: qsTr("Write to the system log") },
                    { option: "syslog-debug", label: qsTr("Include debug messages in the system log") },
                    { option: "syslog-ident", label: qsTr("System log identity") },
                    { option: "syslog-facility", label: qsTr("System log facility") },
                ] },
            ] },
            { group: qsTr("App"), title: qsTr("Interface"), heading: qsTr("Interface Settings"), sections: [
                { title: qsTr("Window"), rows: [
                    { option: "embedded-video", label: qsTr("Play video inside main window") },
                    { option: "qt-video-autoresize", label: qsTr("Resize window to fit video") },
                    { option: "video-on-top", label: qsTr("Keep window above other windows") },
                    { option: "video-deco", label: qsTr("Show window decorations") },
                    { option: "qt-name-in-title", label: qsTr("Show the file name in the title bar") },
                    { option: "qt-fullscreen-screennumber", label: qsTr("Open fullscreen on screen") },
                ] },
                { title: qsTr("Playback Controls"), rows: [
                    { option: "qt-minimal-view", label: qsTr("Start in compact mode") },
                    { option: "mouse-hide-timeout", label: qsTr("Hide the controls after (ms)") },
                    { option: "qt-fs-controller", label: qsTr("Show controls in fullscreen") },
                ] },
                { title: qsTr("Notifications and System Tray"), rows: [
                    { option: "qt-system-tray", label: qsTr("Show a system tray icon") },
                    { option: "qt-start-minimized", label: qsTr("Start minimized to the tray") },
                    { option: "qt-close-to-system-tray", label: qsTr("Close to the tray") },
                    { option: "qt-notification", label: qsTr("Show a popup when the track changes") },
                ] },
                { title: qsTr("Interface"), advanced: true, rows: [
                    { option: "qt-opacity", label: qsTr("Window opacity") },
                    { option: "qt-pause-minimized", label: qsTr("Pause video when window is minimized") },
                    { option: "qt-auto-raise", label: qsTr("Bring VLC to the front when playback starts") },
                    { option: "qt-embedded-open", label: qsTr("Show the file browser inside the open dialog") },
                    { option: "qt-icon-change", label: qsTr("Allow the app icon to change") },
                    { option: "qt-fs-opacity", label: qsTr("Fullscreen controls opacity") },
                    { option: "qt-fs-sensitivity", label: qsTr("Fullscreen controls sensitivity") },
                    { option: "qt-backdrop-blur", label: qsTr("Blur the background of the panels") },
                    { option: "qt-smooth-scrolling", label: qsTr("Smooth scrolling") },
                ] },
            ] },
            { group: qsTr("App"), title: qsTr("Privacy"), heading: qsTr("Privacy Settings"), sections: [
                { title: qsTr("History"), rows: [
                    { kind: "button", action: "clearHistory", label: qsTr("Clear history now"), button: qsTr("Clear"),
                      available: MainCtx.mediaLibraryAvailable },
                ] },
                { title: qsTr("Network"), rows: [
                    { option: "metadata-network-access", label: qsTr("Fetch titles and cover art from the internet") },
                    { option: "lastfm-username", label: qsTr("Last.fm username") },
                    { option: "lastfm-password", label: qsTr("Last.fm password") },
                    { option: "scrobbler-url", label: qsTr("Last.fm submission URL") },
                ] },
            ] },
            { group: qsTr("App"), title: qsTr("Controls"), heading: qsTr("Mouse, Keyboard & Remote Controls"), sections: [
                { title: qsTr("Keyboard Shortcuts"), rows: [
                    { kind: "button", action: "shortcuts", label: qsTr("Keyboard shortcuts"), button: qsTr("Edit Keyboard Shortcuts") },
                ] },
                { title: qsTr("Skip Amounts"), rows: [
                    { option: "extrashort-jump-size", label: qsTr("Very short skip (s)") },
                    { option: "short-jump-size", label: qsTr("Short skip (s)") },
                    { option: "medium-jump-size", label: qsTr("Medium skip (s)") },
                    { option: "long-jump-size", label: qsTr("Long skip (s)") },
                ] },
                { title: qsTr("Mouse"), rows: [
                    { option: "hotkeys-y-wheel-mode", label: qsTr("Scroll wheel") },
                    { option: "hotkeys-x-wheel-mode", label: qsTr("Horizontal scroll") },
                ] },
            ] },
            { group: qsTr("App"), title: qsTr("Files"), heading: qsTr("Playlists, Folders & Files"), sections: [
                { title: qsTr("Opening Files"), rows: [
                    { option: "one-instance", label: qsTr("Only allow one VLC window") },
                    { option: "one-instance-when-started-from-file", label: qsTr("Apply to files opened from the file manager") },
                    { option: "playlist-enqueue", label: qsTr("Add to the playlist instead of replacing it") },
                    { option: "recursive", label: qsTr("When opening a folder") },
                    { option: "show-hiddenfiles", label: qsTr("Show hidden files") },
                ] },
                { title: qsTr("Metadata & Artwork"), rows: [
                    { option: "media-library", label: qsTr("Use the media library") },
                ] },
                { title: qsTr("Files"), advanced: true, rows: [
                    { option: "ignore-filetypes", label: qsTr("Ignored extensions") },
                ] },
            ] },
            { group: qsTr("Media"), title: qsTr("Playback"), heading: qsTr("Playback Preferences"), sections: [
                { title: qsTr("Startup"), rows: [
                    { option: "restore-playback-pos", label: qsTr("Continue where you left off") },
                    { option: "playlist-autostart", label: qsTr("Start playing as soon as a file opens") },
                    { option: "rate", label: qsTr("Default playback speed") },
                ] },
                { title: qsTr("Tracks"), rows: [
                    { option: "preferred-resolution", label: qsTr("Preferred video quality") },
                    { option: "menu-language", label: qsTr("Preferred menu language") },
                    { option: "audio-track", label: qsTr("Default audio track") },
                    { option: "sub-track", label: qsTr("Default subtitle track") },
                ] },
                { title: qsTr("Order"), rows: [
                    { option: "loop", label: qsTr("Repeat all") },
                    { option: "repeat", label: qsTr("Repeat the current item") },
                    { option: "random", label: qsTr("Shuffle") },
                    { option: "play-and-stop", label: qsTr("Stop after each item") },
                    { option: "play-and-exit", label: qsTr("Quit when playback finishes") },
                ] },
                { title: qsTr("Seeking"), rows: [
                    { option: "input-fast-seek", label: qsTr("Seek quickly to the nearest key frame") },
                    { kind: "mainctx", property: "seekThumbnails", label: qsTr("Show thumbnail while scrubbing") },
                    { kind: "mainctx", property: "seekWaveform", label: qsTr("Show waveform on the seek bar") },
                ] },
                { title: qsTr("Files & Discs"), rows: [
                    { option: "dvd", label: qsTr("Default optical drive") },
                    { option: "avi-index", label: qsTr("Repair damaged AVI files") },
                    { option: "mkv-preload-local-dir", label: qsTr("Load matching .mkv files from the same folder") },
                ] },
                { title: qsTr("Playback"), advanced: true, rows: [
                    { option: "input-timeshift-path", label: qsTr("Time-shift buffer folder") },
                    { option: "input-timeshift-granularity", label: qsTr("Time-shift buffer size") },
                ] },
            ] },
            { group: qsTr("Media"), title: qsTr("Video"), heading: qsTr("Video Defaults"), sections: [
                { title: qsTr("Output"), rows: [
                    { option: "video", label: qsTr("Enable video") },
                    { option: "fullscreen", label: qsTr("Start videos in fullscreen") },
                    { option: "disable-screensaver", label: qsTr("Stop the screensaver during playback") },
                    { option: "video-wallpaper", label: qsTr("Play video as desktop wallpaper") },
                ] },
                { title: qsTr("Picture"), rows: [
                    { option: "hue", label: qsTr("Hue") },
                    { option: "brightness", label: qsTr("Brightness") },
                    { option: "contrast", label: qsTr("Contrast") },
                    { option: "saturation", label: qsTr("Saturation") },
                    { option: "gamma", label: qsTr("Gamma") },
                ] },
                { title: qsTr("Deinterlacing"), rows: [
                    { option: "deinterlace", label: qsTr("Deinterlacing") },
                    { option: "deinterlace-mode", label: qsTr("Method") },
                ] },
                { title: qsTr("Framing"), rows: [
                    { option: "aspect-ratio", label: qsTr("Aspect ratio") },
                    { option: "crop", label: qsTr("Crop") },
                    { option: "autoscale", label: qsTr("Scale video to the window") },
                    { option: "zoom", label: qsTr("Zoom") },
                    { option: "align", label: qsTr("Position in the window") },
                ] },
                { title: qsTr("Snapshots"), rows: [
                    { option: "snapshot-path", label: qsTr("Save to") },
                    { option: "snapshot-prefix", label: qsTr("File name prefix") },
                    { option: "snapshot-format", label: qsTr("Format") },
                    { option: "snapshot-width", label: qsTr("Width") },
                    { option: "snapshot-height", label: qsTr("Height") },
                    { option: "snapshot-sequential", label: qsTr("Number files sequentially") },
                    { option: "snapshot-preview", label: qsTr("Show a preview after capture") },
                ] },
                { title: qsTr("Video"), advanced: true, rows: [
                    { option: "custom-aspect-ratios", label: qsTr("Custom aspect ratios") },
                    { option: "custom-crop-ratios", label: qsTr("Custom crop ratios") },
                    { option: "monitor-par", label: qsTr("Monitor pixel aspect ratio") },
                ] },
            ] },
            { group: qsTr("Media"), title: qsTr("Audio"), heading: qsTr("Audio Defaults"), sections: [
                { title: qsTr("Output"), rows: [
                    { option: "audio", label: qsTr("Enable audio") },
                    { option: "aout", label: qsTr("Output module") },
                    { option: "stereo-mode", label: qsTr("Speaker setup") },
                ] },
                { title: qsTr("Volume"), rows: [
                    { option: "qt-max-volume", label: qsTr("Maximum volume (%)") },
                    { option: "volume-save", label: qsTr("Remember the volume") },
                    { option: "volume-step", label: qsTr("Volume step") },
                ] },
                { title: qsTr("Loudness"), rows: [
                    { option: "audio-replay-gain-mode", label: qsTr("Replay gain") },
                    { option: "audio-replay-gain-preamp", label: qsTr("Replay gain preamp") },
                ] },
                { title: qsTr("Effects"), rows: [
                    { option: "equalizer-preset", label: qsTr("Equalizer preset") },
                    { option: "equalizer-2pass", label: qsTr("Two-pass") },
                ] },
                { title: qsTr("Tracks"), rows: [
                    { option: "audio-language", label: qsTr("Preferred audio language") },
                    { option: "audio-desync", label: qsTr("Audio delay (ms)") },
                ] },
                { title: qsTr("Visualization"), rows: [
                    { option: "audio-visual", label: qsTr("Visualizer") },
                ] },
                { title: qsTr("Audio"), advanced: true, rows: [
                    { option: "spdif", label: qsTr("Pass compressed audio to the receiver") },
                    { option: "force-dolby-surround", label: qsTr("Detect Dolby Surround") },
                    { option: "audio-resampler", label: qsTr("Resampler") },
                    { option: "role", label: qsTr("Media role") },
                ] },
            ] },
            { group: qsTr("Media"), title: qsTr("Subtitles"), heading: qsTr("Subtitle Defaults"), sections: [
                { title: qsTr("Tracks & Languages"), rows: [
                    { option: "spu", label: qsTr("Enable subtitles") },
                    { option: "sub-language", label: qsTr("Preferred language") },
                    { option: "subsdec-encoding", label: qsTr("Text encoding") },
                ] },
                { title: qsTr("Loading Subtitles"), rows: [
                    { option: "sub-autodetect-file", label: qsTr("Load subtitle files automatically") },
                    { option: "sub-autodetect-fuzzy", label: qsTr("File name matching") },
                ] },
                { title: qsTr("Appearance"), rows: [
                    { option: "freetype-font", label: qsTr("Font") },
                    { option: "freetype-rel-fontsize", label: qsTr("Font size") },
                    { option: "freetype-bold", label: qsTr("Bold") },
                    { option: "freetype-color", label: qsTr("Text color") },
                    { option: "freetype-opacity", label: qsTr("Text opacity") },
                    { option: "freetype-outline-thickness", label: qsTr("Outline thickness") },
                    { option: "freetype-outline-color", label: qsTr("Outline color") },
                    { option: "freetype-shadow-opacity", label: qsTr("Shadow opacity") },
                    { option: "freetype-shadow-color", label: qsTr("Shadow color") },
                    { option: "freetype-shadow-distance", label: qsTr("Shadow distance") },
                    { option: "freetype-background-opacity", label: qsTr("Background opacity") },
                    { option: "freetype-background-color", label: qsTr("Background color") },
                    { option: "sub-margin", label: qsTr("Distance from the bottom") },
                ] },
                { title: qsTr("Timing"), rows: [
                    { kind: "mainctx", property: "subtitleTimeline", label: qsTr("Show the subtitle timeline on the seek bar") },
                ] },
                { title: qsTr("On-Screen Messages"), rows: [
                    { option: "osd", label: qsTr("Show feedback for shortcuts") },
                    { option: "video-title-show", label: qsTr("Show filename when a video starts") },
                    { option: "video-title-timeout", label: qsTr("Show filename for (ms)") },
                    { option: "video-title-position", label: qsTr("Filename position") },
                ] },
                { title: qsTr("Subtitles"), advanced: true, rows: [
                    { option: "sub-autodetect-path", label: qsTr("Load subtitles from these folders") },
                    { option: "freetype-shadow-angle", label: qsTr("Shadow angle") },
                    { option: "freetype-monofont", label: qsTr("Monospace font") },
                    { option: "sub-text-scale", label: qsTr("Text scale (%)") },
                ] },
            ] },
            { group: qsTr("System"), title: qsTr("Network"), heading: qsTr("Network Connections & Security"), sections: [
                { title: qsTr("Buffering (ms)"), rows: [
                    { option: "file-caching", label: qsTr("Local files") },
                    { option: "disc-caching", label: qsTr("Discs") },
                    { option: "network-caching", label: qsTr("Network streams") },
                    { option: "live-caching", label: qsTr("Live capture") },
                ] },
                { title: qsTr("Proxy"), rows: [
                    { option: "http-proxy", label: qsTr("HTTP proxy") },
                    { option: "http-proxy-pwd", label: qsTr("HTTP proxy password") },
                ] },
                { title: qsTr("Security"), rows: [
                    { option: "gnutls-system-trust", label: qsTr("Verify certificates against the system trust store") },
                ] },
            ] },
            { group: qsTr("System"), title: qsTr("Performance"), heading: qsTr("Performance Settings"), sections: [
                { title: qsTr("Decoding"), rows: [
                    { option: "avcodec-hw", label: qsTr("Hardware-accelerated decoding") },
                    { option: "avcodec-skiploopfilter", label: qsTr("Skip the H.264 loop filter") },
                    { option: "avcodec-threads", label: qsTr("Decoding threads") },
                ] },
                { title: qsTr("Smooth Playback"), rows: [
                    { option: "drop-late-frames", label: qsTr("Drop frames when the system can't keep up") },
                    { option: "rt-priority", label: qsTr("Give VLC real-time priority") },
                    { option: "rt-offset", label: qsTr("Process priority") },
                ] },
                { title: qsTr("Developer"), advanced: true, rows: [
                    { option: "encoder", label: qsTr("Encoder") },
                    { option: "codec", label: qsTr("Decoder") },
                    { option: "clock-synchro", label: qsTr("Clock synchronisation") },
                    { option: "clock-jitter", label: qsTr("Clock jitter (ms)") },
                    { option: "clock-master", label: qsTr("Clock source") },
                ] },
            ] },
            { group: qsTr("System"), title: qsTr("Recording"), heading: qsTr("Recording, Casting & Streaming Out"), sections: [
                { title: qsTr("Recording"), rows: [
                    { option: "input-record-path", label: qsTr("Save recordings to") },
                    { option: "input-record-native", label: qsTr("Record without re-encoding when possible") },
                ] },
                { title: qsTr("Streaming"), rows: [
                    { option: "sout-display", label: qsTr("Play locally while streaming") },
                    { option: "sout-audio", label: qsTr("Include audio") },
                    { option: "sout-video", label: qsTr("Include video") },
                    { option: "sout-spu", label: qsTr("Include subtitles") },
                ] },
            ] },
            { group: qsTr("System"), title: qsTr("Extensions"), heading: qsTr("Extensions"), sections: [
                { title: qsTr("Add-ons"), rows: [
                    { kind: "button", action: "plugins", label: qsTr("Plugins and extensions"), button: qsTr("Manage") },
                    { option: "qt-autoload-extensions", label: qsTr("Load add-ons on startup") },
                ] },
            ] },
        ]
    }

    // the pages with the options found, each row with the description of
    // its option and its kind of control
    function _build() {
        const result = []
        for (const page of _definitions()) {
            const sections = []
            for (const section of page.sections) {
                const rows = []
                for (const row of section.rows) {
                    if (row.option) {
                        const info = prefs.option(row.option)
                        if (!info.exists)
                            continue
                        row.info = info
                        row.kind = _kind(info)
                    } else if (row.available === false) {
                        continue
                    }
                    if (!row.label)
                        row.label = row.info.text
                    row.description = row.info?.description ?? ""
                    rows.push(row)
                }
                if (rows.length > 0) {
                    section.rows = rows
                    sections.push(section)
                }
            }
            page.sections = sections
            page.hasAdvanced = sections.some((section) => !!section.advanced)
            result.push(page)
        }
        return result
    }

    function _kind(info) {
        if (info.choices.length > 0)
            return "choice"
        if (info.type === "int" || info.type === "float")
            return (info.max > info.min && info.max - info.min <= 10000) ? "slider" : "number"
        return info.type
    }

    function _rowMatches(row) {
        return !_searching
                || row.label.toLowerCase().includes(_search)
                || row.description.toLowerCase().includes(_search)
    }

    function _sectionMatches(section) {
        return section.rows.some((row) => _rowMatches(row))
    }

    function _pageMatches(page) {
        return page.sections.some((section) => _sectionMatches(section))
    }

    function _action(action) {
        switch (action) {
        case "configFolder":
            Qt.openUrlExternally(prefs.configFolder())
            break
        case "resetAll":
            prefs.resetAll()
            break
        case "clearHistory": {
            const recents = recentsComponent.createObject(root, { ml: MainCtx.mediaLibrary })
            recents.clearHistory()
            recents.destroy()
            break
        }
        case "shortcuts":
            DialogsProvider.showKeyboardShortcutsDialog()
            break
        case "plugins":
            DialogsProvider.pluginDialog()
            break
        }
    }

    footerContent: Widgets.DialogButton {
        text: qsTr("All Settings...")
        onClicked: {
            root.close()
            DialogsProvider.advancedPrefsDialog()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true

        spacing: VLCStyle.margin_large

        // the pages, grouped
        ColumnLayout {
            // its rows fill it, it does not fill the dialog
            Layout.fillWidth: false
            Layout.preferredWidth: VLCStyle.dp(220, VLCStyle.scale)
            Layout.fillHeight: true

            spacing: VLCStyle.margin_xxsmall

            Widgets.TextFieldExt {
                id: searchField

                Layout.fillWidth: true
                Layout.bottomMargin: VLCStyle.margin_small

                placeholderText: qsTr("Search")
            }

            Repeater {
                model: root.pages

                delegate: ColumnLayout {
                    id: pageEntry

                    required property int index
                    required property var modelData

                    Layout.fillWidth: true
                    spacing: VLCStyle.margin_xxsmall

                    T.Label {
                        Layout.fillWidth: true
                        Layout.topMargin: (pageEntry.index > 0) ? VLCStyle.margin_small : 0
                        Layout.leftMargin: VLCStyle.margin_small

                        visible: pageEntry.index === 0
                                 || root.pages[pageEntry.index - 1].group !== pageEntry.modelData.group

                        text: pageEntry.modelData.group
                        color: theme.fg.secondary
                        font.pixelSize: VLCStyle.fontSize_small
                    }

                    T.ItemDelegate {
                        id: pageButton

                        readonly property bool _current: !root._searching && root.currentPage === pageEntry.index

                        Layout.fillWidth: true
                        implicitHeight: VLCStyle.dp(32, VLCStyle.scale)

                        leftPadding: VLCStyle.margin_small
                        rightPadding: VLCStyle.margin_small

                        // while searching, the pages without results are dimmed
                        opacity: (!root._searching || root._pageMatches(pageEntry.modelData)) ? 1 : 0.4

                        onClicked: {
                            searchField.text = ""
                            root.currentPage = pageEntry.index
                            flickable.contentY = 0
                        }

                        background: Rectangle {
                            radius: VLCStyle.dp(6, VLCStyle.scale)
                            color: pageButton._current ? theme.bg.secondary
                                                       : pageButton.hovered ? Qt.alpha(theme.bg.secondary, 0.5)
                                                                            : "transparent"
                        }

                        contentItem: T.Label {
                            text: pageEntry.modelData.title
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            color: pageButton._current ? theme.fg.primary : theme.fg.secondary
                            font.pixelSize: VLCStyle.fontSize_normal
                            font.weight: pageButton._current ? Font.DemiBold : Font.Normal
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }

        Rectangle {
            Layout.fillHeight: true
            implicitWidth: VLCStyle.border
            color: theme.border
        }

        // the options of the page, or the results of the search
        Flickable {
            id: flickable

            Layout.fillWidth: true
            Layout.fillHeight: true

            clip: true
            contentWidth: width
            contentHeight: content.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            T.ScrollBar.vertical: Widgets.ScrollBarExt { }

            ColumnLayout {
                id: content

                width: flickable.width - VLCStyle.margin_normal
                spacing: VLCStyle.margin_large

                T.Label {
                    Layout.fillWidth: true
                    visible: root._searching && !root.pages.some((page) => root._pageMatches(page))
                    text: qsTr("No settings match \"%1\".").arg(searchField.text.trim())
                    color: theme.fg.secondary
                    font.pixelSize: VLCStyle.fontSize_normal
                }

                Repeater {
                    model: root.pages

                    delegate: ColumnLayout {
                        id: page

                        required property int index
                        required property var modelData

                        property bool advancedExpanded: false

                        Layout.fillWidth: true
                        spacing: VLCStyle.margin_large

                        visible: root._searching ? root._pageMatches(modelData)
                                                 : index === root.currentPage

                        T.Label {
                            Layout.fillWidth: true

                            text: page.modelData.heading
                            color: theme.fg.primary
                            font.pixelSize: root._searching ? VLCStyle.fontSize_large : VLCStyle.fontSize_xxlarge
                            font.weight: Font.DemiBold
                        }

                        Repeater {
                            model: page.modelData.sections.filter((section) => !section.advanced)
                            delegate: sectionComponent
                        }

                        // the options most do not need, folded
                        T.ItemDelegate {
                            id: advancedButton

                            Layout.fillWidth: true
                            implicitHeight: VLCStyle.dp(36, VLCStyle.scale)

                            visible: page.modelData.hasAdvanced && !root._searching
                            padding: 0

                            onClicked: page.advancedExpanded = !page.advancedExpanded

                            background: Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: VLCStyle.border
                                color: theme.border
                            }

                            contentItem: RowLayout {
                                spacing: VLCStyle.margin_xsmall

                                T.Label {
                                    Layout.fillWidth: true
                                    text: qsTr("Advanced Options")
                                    color: advancedButton.hovered ? theme.fg.primary : theme.fg.secondary
                                    font.pixelSize: VLCStyle.fontSize_large
                                    font.weight: Font.DemiBold
                                }

                                Widgets.IconLabel {
                                    text: page.advancedExpanded ? VLCIcons.chevron_up : VLCIcons.chevron_down
                                    color: theme.fg.secondary
                                    font.pixelSize: VLCStyle.icon_small
                                }
                            }
                        }

                        Repeater {
                            model: (page.advancedExpanded || root._searching)
                                   ? page.modelData.sections.filter((section) => !!section.advanced) : []
                            delegate: sectionComponent
                        }
                    }
                }

                Item { implicitHeight: VLCStyle.margin_small }
            }
        }
    }

    Component {
        id: sectionComponent

        ColumnLayout {
            id: section

            required property var modelData

            Layout.fillWidth: true
            spacing: VLCStyle.margin_xsmall

            visible: root._sectionMatches(modelData)

            T.Label {
                Layout.fillWidth: true
                Layout.bottomMargin: VLCStyle.margin_xxsmall

                text: section.modelData.title
                color: theme.fg.primary
                font.pixelSize: VLCStyle.fontSize_large
                font.weight: Font.DemiBold
            }

            Repeater {
                model: section.modelData.rows

                delegate: RowLayout {
                    id: prefRow

                    required property var modelData

                    readonly property var row: modelData
                    readonly property var info: row.info ?? ({})
                    // the value, changed or not
                    readonly property var value: {
                        void prefs.revision
                        return row.option ? prefs.value(row.option) : undefined
                    }

                    function set(value) {
                        prefs.setValue(row.option, value)
                    }

                    Layout.fillWidth: true
                    Layout.minimumHeight: VLCStyle.dp(36, VLCStyle.scale)

                    spacing: VLCStyle.margin_small
                    visible: root._rowMatches(row)

                    T.Label {
                        Layout.fillWidth: true

                        text: prefRow.row.label
                        wrapMode: Text.Wrap
                        color: theme.fg.primary
                        font.pixelSize: VLCStyle.fontSize_normal
                    }

                    // the description of the option
                    Widgets.IconLabel {
                        visible: prefRow.row.description !== ""
                                 && prefRow.row.description !== prefRow.row.label

                        text: VLCIcons.info
                        color: infoHover.hovered ? theme.fg.primary : theme.fg.secondary
                        font.pixelSize: VLCStyle.icon_small

                        HoverHandler { id: infoHover }

                        Widgets.ToolTipExt {
                            visible: infoHover.hovered
                            text: prefRow.row.description
                            width: Math.min(implicitWidth, VLCStyle.dp(360, VLCStyle.scale))
                        }
                    }

                    Loader {
                        // for the controls
                        readonly property Item rowItem: prefRow

                        Layout.preferredWidth: (prefRow.row.kind === "bool" || prefRow.row.kind === "mainctx")
                                               ? implicitWidth : root._controlWidth

                        sourceComponent: {
                            switch (prefRow.row.kind) {
                            case "bool": return boolControl
                            case "mainctx": return mainCtxControl
                            case "choice": return choiceControl
                            case "slider": return sliderControl
                            case "number": return numberControl
                            case "file":
                            case "folder": return pathControl
                            case "color": return colorControl
                            case "theme": return themeControl
                            case "accent": return accentControl
                            case "button": return buttonControl
                            default: return textControl
                            }
                        }
                    }
                }
            }
        }
    }

    // the controls, in a loader of a row (see prefRow)

    Component {
        id: boolControl

        Widgets.CheckButton {
            id: control

            readonly property Item prefRow: parent?.rowItem ?? null

            text: prefRow?.row.label ?? ""
            onClicked: prefRow.set(checked)

            // CheckButton positions its handle when checked changes, which
            // needs to happen once its size is known
            Component.onCompleted: Qt.callLater(() => {
                control.checked = Qt.binding(() => !!control.prefRow?.value)
            })
        }
    }

    Component {
        id: mainCtxControl

        Widgets.CheckButton {
            id: control

            readonly property Item prefRow: parent?.rowItem ?? null

            text: prefRow?.row.label ?? ""
            onClicked: MainCtx[prefRow.row.property] = checked

            Component.onCompleted: Qt.callLater(() => {
                control.checked = Qt.binding(() => !!(control.prefRow && MainCtx[control.prefRow.row.property]))
            })
        }
    }

    Component {
        id: choiceControl

        Widgets.DialogComboBox {
            readonly property Item prefRow: parent?.rowItem ?? null
            readonly property var _choices: prefRow?.info.choices ?? []

            implicitHeight: VLCStyle.dp(32, VLCStyle.scale)

            model: _choices.map((choice) => choice.text || String(choice.value))
            // the values may be numbers of different types
            currentIndex: _choices.findIndex((choice) => choice.value == prefRow?.value)

            onActivated: (index) => prefRow.set(_choices[index].value)
        }
    }

    Component {
        id: sliderControl

        RowLayout {
            id: control

            readonly property Item prefRow: parent?.rowItem ?? null
            readonly property bool _integer: prefRow?.info.type === "int"

            spacing: VLCStyle.margin_small

            Widgets.SliderExt {
                id: slider

                Layout.fillWidth: true

                from: control.prefRow?.info.min ?? 0
                to: control.prefRow?.info.max ?? 1
                stepSize: control._integer ? 1 : (to - from) / 100
                value: Number(control.prefRow?.value ?? 0)

                onMoved: control.prefRow.set(control._integer ? Math.round(value) : value)
            }

            T.Label {
                Layout.preferredWidth: VLCStyle.dp(48, VLCStyle.scale)

                horizontalAlignment: Text.AlignRight
                text: control._integer ? Math.round(slider.value)
                                       : Number(slider.value).toFixed(2)
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.fontSize_normal
            }
        }
    }

    Component {
        id: numberControl

        Widgets.TextFieldExt {
            readonly property Item prefRow: parent?.rowItem ?? null

            text: prefRow ? String(prefRow.value ?? "") : ""
            validator: (prefRow?.info.type === "int") ? intValidator : doubleValidator

            onEditingFinished: {
                const value = Number(text)
                if (!isNaN(value))
                    prefRow.set(prefRow.info.type === "int" ? Math.round(value) : value)
            }

            RegularExpressionValidator { id: intValidator; regularExpression: /-?\d+/ }
            RegularExpressionValidator { id: doubleValidator; regularExpression: /-?\d*[.,]?\d*/ }
        }
    }

    Component {
        id: textControl

        Widgets.TextFieldExt {
            readonly property Item prefRow: parent?.rowItem ?? null

            text: prefRow ? String(prefRow.value ?? "") : ""
            echoMode: (prefRow?.info.type === "password") ? TextInput.Password : TextInput.Normal

            onEditingFinished: prefRow.set(text)
        }
    }

    Component {
        id: pathControl

        RowLayout {
            id: control

            readonly property Item prefRow: parent?.rowItem ?? null

            spacing: VLCStyle.margin_xsmall

            Widgets.TextFieldExt {
                id: pathField

                Layout.fillWidth: true

                text: control.prefRow ? String(control.prefRow.value ?? "") : ""
                onEditingFinished: control.prefRow.set(text)
            }

            Widgets.DialogButton {
                Layout.preferredHeight: pathField.height

                text: qsTr("Browse")

                onClicked: {
                    const folder = control.prefRow.info.type === "folder"
                    const url = folder ? DialogsProvider.getFolderUrl(control.prefRow.row.label)
                                       : (DialogsProvider.getOpenMediaUrls(control.prefRow.row.label)[0] ?? "")
                    const path = url.toString()
                    if (path === "")
                        return
                    control.prefRow.set(path.startsWith("file://") ? decodeURIComponent(path.substring(7)) : path)
                }
            }
        }
    }

    Component {
        id: colorControl

        RowLayout {
            id: control

            readonly property Item prefRow: parent?.rowItem ?? null
            readonly property string _color: "#" + Number(prefRow?.value ?? 0).toString(16).padStart(6, "0")

            spacing: VLCStyle.margin_small

            Rectangle {
                implicitWidth: VLCStyle.dp(24, VLCStyle.scale)
                implicitHeight: implicitWidth
                radius: width / 2
                color: control._color
                border.color: theme.border
                border.width: VLCStyle.border
            }

            Widgets.TextFieldExt {
                Layout.fillWidth: true

                text: control._color.toUpperCase()
                validator: RegularExpressionValidator { regularExpression: /#?[0-9a-fA-F]{0,6}/ }

                onEditingFinished: {
                    const value = parseInt(text.replace("#", ""), 16)
                    if (!isNaN(value))
                        control.prefRow.set(value)
                }
            }
        }
    }

    Component {
        id: themeControl

        Widgets.DialogComboBox {
            implicitHeight: VLCStyle.dp(32, VLCStyle.scale)

            // in the order of ColorSchemeModel::ColorScheme
            model: [qsTr("System"), qsTr("Light"), qsTr("Dark")]
            currentIndex: (root._scheme >= 0) ? root._scheme : MainCtx.colorScheme.scheme

            onActivated: (index) => { root._scheme = index }
        }
    }

    Component {
        id: accentControl

        Row {
            id: control

            readonly property string _selected: {
                void prefs.revision
                return prefs.value("qt-accent-color") || "default"
            }

            layoutDirection: Qt.RightToLeft
            spacing: VLCStyle.margin_xsmall

            Repeater {
                // from the right
                model: root._accents.slice().reverse()

                delegate: T.AbstractButton {
                    id: swatch

                    required property string modelData

                    readonly property bool _selected: control._selected === modelData

                    implicitWidth: VLCStyle.dp(26, VLCStyle.scale)
                    implicitHeight: implicitWidth

                    T.ToolTip.visible: hovered
                    T.ToolTip.text: modelData === "default" ? qsTr("VLC orange")
                                  : modelData === "system" ? qsTr("System accent color")
                                  : modelData

                    onClicked: prefs.setValue("qt-accent-color", modelData)

                    background: Rectangle {
                        radius: width / 2
                        color: "transparent"
                        border.color: swatch._selected ? theme.fg.primary : "transparent"
                        border.width: VLCStyle.dp(2, VLCStyle.scale)
                    }

                    contentItem: Item {
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: VLCStyle.dp(4, VLCStyle.scale)
                            radius: width / 2
                            color: swatch.modelData === "default" ? "#ff8800"
                                 : swatch.modelData === "system" ? theme.fg.secondary
                                 : swatch.modelData
                        }
                    }
                }
            }
        }
    }

    Component {
        id: buttonControl

        Item {
            readonly property Item prefRow: parent?.rowItem ?? null

            implicitHeight: button.implicitHeight

            Widgets.DialogButton {
                id: button

                anchors.right: parent.right

                text: parent.prefRow?.row.button ?? ""
                onClicked: root._action(parent.prefRow.row.action)
            }
        }
    }
}
