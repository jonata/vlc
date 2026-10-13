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

import VLC.Style

// Labelled slider of the player settings sidebar, drawn like the seek bar:
// a dark track, a tinted fill and a bar shaped handle.
T.Slider {
    id: control

    property string label
    property string valueText

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Slider

        enabled: control.enabled
        focused: control.visualFocus
        hovered: control.hovered
    }

    ColorContext {
        id: textTheme
        colorSet: ColorContext.Window
    }

    implicitWidth: VLCStyle.dp(200, VLCStyle.scale)
    implicitHeight: topPadding + VLCStyle.settingsSlider_handleHeight

    topPadding: header.implicitHeight + VLCStyle.margin_xsmall
    leftPadding: 0
    rightPadding: 0
    bottomPadding: 0

    hoverEnabled: true
    focusPolicy: Qt.StrongFocus

    Accessible.name: label

    Item {
        id: header

        width: control.width
        implicitHeight: Math.max(labelText.implicitHeight, valueLabel.implicitHeight)

        T.Label {
            id: labelText

            anchors.left: parent.left
            anchors.right: valueLabel.left
            anchors.rightMargin: VLCStyle.margin_xsmall

            text: control.label
            elide: Text.ElideRight
            color: textTheme.fg.primary
            font.pixelSize: VLCStyle.fontSize_normal
        }

        T.Label {
            id: valueLabel

            anchors.right: parent.right

            text: control.valueText
            color: textTheme.fg.primary
            font.pixelSize: VLCStyle.fontSize_normal
        }
    }

    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + (control.availableHeight - height) / 2

        width: control.availableWidth
        height: VLCStyle.settingsSlider_height

        radius: VLCStyle.settingsSlider_radius
        color: theme.bg.primary

        Rectangle {
            x: VLCStyle.settingsSlider_inset
            y: VLCStyle.settingsSlider_inset

            width: Math.max(0, control.handle.x - control.leftPadding + control.handle.width / 2 - x)
            height: parent.height - 2 * VLCStyle.settingsSlider_inset

            radius: VLCStyle.settingsSlider_radius - VLCStyle.settingsSlider_inset
            color: theme.bg.highlight
        }
    }

    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + (control.availableHeight - height) / 2

        width: VLCStyle.settingsSlider_handleWidth
        height: VLCStyle.settingsSlider_handleHeight

        radius: width / 2
        color: theme.fg.primary

        border.width: control.visualFocus ? VLCStyle.focus_border : 0
        border.color: theme.visualFocus
    }
}
