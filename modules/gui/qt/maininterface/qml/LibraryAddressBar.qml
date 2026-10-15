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
import VLC.Util

// Path of the current page of the library, each part leads back to its page:
// "Music / Albums", "Videos / The Wand", "Playlists / Favorite Videos"
Row {
    id: root

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    // names of the sections and of their pages
    readonly property var _names: ({
        "home": qsTr("Home"),
        "recent": qsTr("Recent"),
        "video": qsTr("Videos"),
        "music": qsTr("Music"),
        "playlists": qsTr("Playlists"),
        "streams": qsTr("Network Streams"),
        "network": qsTr("Browse"),
        "discover": qsTr("Discover"),
        "albums": qsTr("Albums"),
        "artists": qsTr("Artists"),
        "tracks": qsTr("Songs"),
        "genres": qsTr("Genres"),
        "services": qsTr("Services"),
        "url": qsTr("URL"),
        "continueWatching": qsTr("Continue Watching"),
        "favorites": qsTr("Favorites"),
        "newVideo": qsTr("New Videos"),
        "newMusic": qsTr("New Music")
    })

    // [{text, path}], the pages without a name (such as "all") are skipped,
    // the last part is named after the title of the page when it has one
    readonly property var crumbs: {
        const path = History.viewPath
        const result = []
        for (let i = 0; i < path.length; ++i) {
            const name = root._names[path[i]]
            if (name !== undefined)
                result.push({ text: name, path: path.slice(0, i + 1) })
        }

        // reading a missing key of the properties would add it, which the
        // page loader would then assign to the next pages
        const props = History.viewProp
        const title = (props && props.keys().indexOf("title") >= 0) ? (props.title ?? "") : ""
        if (title !== "" && path.length > 1)
            result.push({ text: title, path: path })
        return result
    }

    spacing: VLCStyle.margin_xxsmall

    Repeater {
        model: root.crumbs

        Row {
            id: crumb

            required property var modelData
            required property int index

            readonly property bool _last: index === root.crumbs.length - 1

            spacing: VLCStyle.margin_xxsmall

            Widgets.IconLabel {
                anchors.verticalCenter: parent.verticalCenter
                visible: crumb.index > 0
                text: VLCIcons.breadcrumb_sep
                font.pixelSize: VLCStyle.icon_small
                color: theme.fg.secondary
            }

            T.AbstractButton {
                id: button

                anchors.verticalCenter: parent.verticalCenter

                implicitWidth: implicitContentWidth + leftPadding + rightPadding
                implicitHeight: implicitContentHeight + topPadding + bottomPadding

                // the current page is not a link
                enabled: !crumb._last
                padding: VLCStyle.margin_xxsmall
                leftPadding: VLCStyle.margin_xsmall
                rightPadding: VLCStyle.margin_xsmall

                text: crumb.modelData.text

                onClicked: History.push(crumb.modelData.path)

                background: Rectangle {
                    radius: VLCStyle.dp(4, VLCStyle.scale)
                    color: button.hovered ? theme.bg.secondary : "transparent"
                }

                contentItem: T.Label {
                    text: button.text
                    elide: Text.ElideRight
                    color: crumb._last ? theme.fg.primary : theme.fg.secondary
                    font.pixelSize: VLCStyle.fontSize_normal
                    font.weight: crumb._last ? Font.DemiBold : Font.Normal
                }
            }
        }
    }
}
