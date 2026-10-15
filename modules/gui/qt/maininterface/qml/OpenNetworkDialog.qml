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
import VLC.Widgets as Widgets

// Plays network streams, several links at once, which can be kept in the
// network streams of the library and saved as a playlist
Widgets.CardDialog {
    id: root

    // fills the links with the text of the clipboard when opened
    property bool fromClipboard: false

    title: qsTr("Open Network Stream")
    acceptText: qsTr("Play")
    acceptEnabled: _urls.length > 0

    preferredWidth: VLCStyle.dp(1048, VLCStyle.scale)

    // one link per line
    readonly property var _urls: urlField.text.split(/\s+/).filter(url => url !== "")

    onOpened: {
        urlField.text = fromClipboard ? helper.clipboardText() : ""
        nameField.text = ""
        urlField.forceActiveFocus()
        urlField.selectAll()
    }

    onAccepted: {
        const urls = _urls
        if (keepCheck.checked)
            _keepStreams(urls)
        if (nameField.text.trim() !== "")
            helper.savePlaylist(nameField.text.trim(), urls)
        helper.play(urls)
    }

    // the network streams page of the library lists the saved streams
    function _keepStreams(urls) {
        let streams = []
        try {
            streams = JSON.parse(MainCtx.settingValue("NetworkStreams/saved", "[]"))
        } catch (e) {
            streams = []
        }
        for (const url of urls) {
            if (!streams.some(stream => stream.url === url))
                streams.push({ url: url, name: nameField.text.trim() })
        }
        MainCtx.setSettingValue("NetworkStreams/saved", JSON.stringify(streams))
    }

    // the dialog is outside of the items of the window, see CardDialog
    readonly property ColorContext _theme: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.Window
    }

    OpenMediaHelper {
        id: helper
        ctx: MainCtx
    }

    Widgets.DialogSectionTitle {
        text: qsTr("Network URL")
        description: qsTr("You can enter multiple links to load, one per line. A link to a playlist file is expanded when played.")
    }

    T.TextArea {
        id: urlField

        Layout.fillWidth: true
        Layout.preferredHeight: VLCStyle.dp(194, VLCStyle.scale)

        padding: VLCStyle.margin_small
        wrapMode: TextEdit.WrapAnywhere

        placeholderText: qsTr("e.g., https://www.example.com/stream.avi")
        placeholderTextColor: theme.fg.secondary
        color: theme.fg.primary
        selectionColor: theme.accent
        font.pixelSize: VLCStyle.fontSize_normal

        background: Rectangle {
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: Qt.lighter(theme.bg.primary, 1.25)
            border.color: urlField.activeFocus ? theme.accent : "transparent"
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: VLCStyle.border
        color: theme.border
    }

    Widgets.DialogSectionTitle {
        visible: MainCtx.mediaLibraryAvailable
        text: qsTr("Playlist Name (optional)")
        description: qsTr("With a name, the links are also saved as a playlist, displayed with this title.")
    }

    Widgets.TextFieldExt {
        id: nameField

        Layout.fillWidth: true
        visible: MainCtx.mediaLibraryAvailable

        placeholderText: qsTr("e.g., Favorite TV Channels")
    }

    Widgets.CheckBoxExt {
        id: keepCheck

        Layout.fillWidth: true
        visible: MainCtx.mediaLibraryAvailable

        text: qsTr("Keep the links in the network streams of the library")
    }
}
