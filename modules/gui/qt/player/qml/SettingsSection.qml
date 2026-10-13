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
import VLC.Widgets as Widgets

// Collapsible card of the player settings sidebar.
FocusScope {
    id: root

    property string title
    property bool expanded: true

    // shows a switch next to the title
    property bool checkable: false
    property bool checked: false

    signal toggled(bool checked)

    default property alias contentData: content.data

    implicitHeight: card.implicitHeight

    ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    // collapsed cards are drawn like the slider tracks
    ColorContext {
        id: collapsedTheme
        colorSet: ColorContext.Slider
    }

    Rectangle {
        id: card

        width: root.width
        implicitHeight: column.implicitHeight + 2 * VLCStyle.margin_small

        radius: VLCStyle.settingsSection_radius
        color: root.expanded ? theme.bg.primary : collapsedTheme.bg.primary

        ColumnLayout {
            id: column

            x: VLCStyle.settingsSection_padding
            y: VLCStyle.margin_small
            width: parent.width - 2 * VLCStyle.settingsSection_padding

            spacing: VLCStyle.margin_normal

            T.AbstractButton {
                id: headerButton

                Layout.fillWidth: true
                implicitHeight: VLCStyle.icon_normal

                focus: true

                Accessible.role: Accessible.Button
                Accessible.name: root.title

                onClicked: root.expanded = !root.expanded

                contentItem: Item {
                    T.Label {
                        anchors.left: parent.left
                        anchors.right: root.checkable ? toggle.left : chevron.left
                        anchors.verticalCenter: parent.verticalCenter

                        text: root.title
                        elide: Text.ElideRight
                        color: theme.fg.primary
                        font.pixelSize: VLCStyle.fontSize_normal
                    }

                    Widgets.CheckButton {
                        id: toggle

                        anchors.right: chevron.left
                        anchors.rightMargin: VLCStyle.margin_small
                        anchors.verticalCenter: parent.verticalCenter

                        visible: root.checkable
                        enabled: visible

                        text: root.title

                        onClicked: root.toggled(checked)

                        // CheckButton positions its handle when checked changes, which
                        // needs to happen once its size is known
                        Component.onCompleted: Qt.callLater(() => {
                            toggle.checked = Qt.binding(() => root.checked)
                        })
                    }

                    T.Label {
                        id: chevron

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        text: root.expanded ? VLCIcons.chevron_down : VLCIcons.ic_fluent_chevron_right_24
                        font.family: VLCIcons.fontFamily
                        font.pixelSize: VLCStyle.icon_small
                        color: theme.fg.primary
                    }
                }
            }

            ColumnLayout {
                id: content

                Layout.fillWidth: true

                visible: root.expanded
                spacing: VLCStyle.margin_normal
            }
        }
    }
}
