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

import VLC.MediaLibrary
import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style

// Recently played media, the most recent first
Widgets.PageExt {
    id: root

    title: qsTr("Recent")

    headerActions: [
        Widgets.ButtonExt {
            text: qsTr("Clear")
            iconTxt: VLCIcons.clear
            enabled: recentModel.count > 0
            onClicked: recentModel.clearHistory()
        }
    ]

    MediaView {
        focus: true

        anchors.fill: parent

        // the history has its own order
        sortModel: []

        model: MLRecentMediaModel {
            id: recentModel

            ml: MediaLib

            searchPattern: root.search.pattern
        }

        displayMarginBeginning: root.displayMarginBeginning
        displayMarginEnd: root.displayMarginEnd

        enableBeginningFade: root.enableBeginningFade
        enableEndFade: root.enableEndFade
    }
}
