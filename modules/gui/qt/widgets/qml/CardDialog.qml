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

// Modal dialog over the window: a title bar, the content, and a footer to
// cancel or accept
T.Popup {
    id: root

    property string title
    property string acceptText: qsTr("Save")
    property bool acceptEnabled: true

    property real preferredWidth: VLCStyle.dp(713, VLCStyle.scale)

    default property alias content: body.data

    signal accepted()

    parent: T.Overlay.overlay
    anchors.centerIn: parent

    width: Math.min(preferredWidth, (parent?.width ?? preferredWidth) - 2 * VLCStyle.margin_large)
    // a popup of the templates is not sized after its content
    implicitHeight: implicitContentHeight + topPadding + bottomPadding
    height: Math.min(implicitHeight, (parent?.height ?? implicitHeight) - 2 * VLCStyle.margin_large)

    modal: true
    focus: true
    padding: 0

    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside

    T.Overlay.modal: Rectangle {
        color: Qt.alpha("black", 0.5)
    }

    background: Rectangle {
        radius: VLCStyle.seekPreview_radius
        color: theme.bg.primary
        border.color: theme.border
        border.width: VLCStyle.border
    }

    contentItem: ColumnLayout {
        // the popup is outside of the items of the window, the colors are
        // given to its content, for the widgets in it
        readonly property ColorContext colorContext: ColorContext {
            id: theme
            palette: VLCStyle.palette
            colorSet: ColorContext.Window
        }

        spacing: 0

        // title
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: VLCStyle.margin_xsmall
            Layout.leftMargin: VLCStyle.margin_normal

            T.Label {
                Layout.fillWidth: true

                text: root.title
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.fontSize_large
            }

            Widgets.IconToolButton {
                text: VLCIcons.close
                description: qsTr("Close")
                onClicked: root.close()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: VLCStyle.border
            color: theme.border
        }

        ColumnLayout {
            id: body

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: VLCStyle.margin_large

            spacing: VLCStyle.margin_normal
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: VLCStyle.margin_large
            Layout.topMargin: 0

            Widgets.DialogButton {
                text: qsTr("Cancel")
                onClicked: root.close()
            }

            Item { Layout.fillWidth: true }

            Widgets.DialogButton {
                text: root.acceptText
                accent: true
                enabled: root.acceptEnabled

                onClicked: {
                    root.accepted()
                    root.close()
                }
            }
        }
    }
}
