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

// Adds network streams, or a playlist of them when it is given a name
Widgets.CardDialog {
    id: root

    // emitted with the URLs to save as streams, when no playlist is created
    signal streamsAdded(var urls)

    title: qsTr("Open Network Stream")
    acceptText: qsTr("Save")
    acceptEnabled: _urls.length > 0

    preferredWidth: VLCStyle.dp(1048, VLCStyle.scale)

    // one link per line
    readonly property var _urls: urlField.text.split(/\s+/).filter(url => url !== "")

    onOpened: {
        urlField.text = ""
        nameField.text = ""
        urlField.forceActiveFocus()
    }

    onAccepted: {
        const name = nameField.text.trim()
        if (name !== "")
            playlistModel.create(name, _urls)
        else
            root.streamsAdded(_urls)
    }

    readonly property ColorContext _theme: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    MLPlaylistListModel {
        id: playlistModel
        ml: MediaLib
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
        text: qsTr("Playlist Name (optional)")
        description: qsTr("With a name, the links are saved as a playlist, displayed with this title.")
    }

    Widgets.TextFieldExt {
        id: nameField

        Layout.fillWidth: true

        placeholderText: qsTr("e.g., Favorite TV Channels")
    }
}
