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

import VLC.Style

// List of selectable options of the player settings sidebar. The model
// provides the "display" and "checked" roles, like the track, audio
// device and variable choice models.
ColumnLayout {
    id: root

    property var model

    // shown when the model is empty
    property string emptyText: qsTr("None")

    spacing: 0

    ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    T.Label {
        Layout.fillWidth: true

        visible: repeater.count === 0

        text: root.emptyText
        color: theme.fg.primary
        opacity: 0.6
        font.pixelSize: VLCStyle.fontSize_normal
    }

    Repeater {
        id: repeater

        model: root.model

        delegate: T.ItemDelegate {
            id: delegate

            required property var model

            Layout.fillWidth: true
            implicitHeight: VLCStyle.icon_normal + VLCStyle.margin_xsmall

            hoverEnabled: true

            Accessible.role: Accessible.RadioButton
            Accessible.name: delegate.model.display
            Accessible.checked: delegate.model.checked

            onClicked: delegate.model.checked = true

            contentItem: Item {
                T.Label {
                    id: check

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    width: VLCStyle.icon_normal

                    text: VLCIcons.check
                    font.family: VLCIcons.fontFamily
                    font.pixelSize: VLCStyle.icon_small
                    color: theme.accent
                    visible: delegate.model.checked
                }

                T.Label {
                    anchors.left: check.right
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    text: delegate.model.display
                    elide: Text.ElideRight
                    color: (delegate.model.checked || delegate.hovered) ? Qt.lighter(theme.fg.primary, 1.4)
                                                                         : theme.fg.primary
                    font.pixelSize: VLCStyle.fontSize_normal
                }
            }
        }
    }
}
