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

import VLC.MainInterface
import VLC.MediaLibrary
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util

// Button of the top bar of the library, to add content where it is needed:
// a folder to the library, a playlist, or a file to play
Widgets.IconToolButton {
    id: root

    text: VLCIcons.add
    description: qsTr("Add")

    font.pixelSize: VLCStyle.icon_banner
    height: VLCStyle.bannerButton_height
    width: VLCStyle.bannerButton_width

    onClicked: menu.popup([], root.mapToGlobal(0, root.height))

    MLFolderModel {
        id: folderModel
        ctx: MainCtx
    }

    NewPlaylistDialog {
        id: newPlaylistDialog
    }

    NativeMenu {
        id: menu

        actions: [{
            text: qsTr("Add a Folder to the Library..."),
            action: () => {
                const folder = DialogsProvider.getFolderUrl(qsTr("Add a Folder to the Library"))
                if (folder.toString() !== "")
                    folderModel.add(folder)
            }
        }, {
            text: qsTr("New Playlist..."),
            action: () => newPlaylistDialog.open()
        }, {
            text: qsTr("Open File..."),
            action: () => DialogsProvider.simpleOpenDialog()
        }, {
            text: qsTr("Open Network Stream..."),
            action: () => History.push(["streams"])
        }]

        onRequestData: (requestID) => setData(requestID, [])
    }
}
