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

// button of the footer of a dialog, filled with the accent color for its main action
T.Button {
    id: button

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    // the main action of the dialog
    property bool accent: false

    implicitWidth: Math.max(VLCStyle.dp(96, VLCStyle.scale), implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: VLCStyle.dp(32, VLCStyle.scale)

    leftPadding: VLCStyle.margin_normal
    rightPadding: VLCStyle.margin_normal

    font.pixelSize: VLCStyle.fontSize_normal
    font.weight: Font.DemiBold

    opacity: enabled ? 1 : 0.5

    background: Rectangle {
        radius: VLCStyle.dp(4, VLCStyle.scale)
        color: {
            const base = button.accent ? Qt.alpha(theme.accent, 0.25) : Qt.lighter(theme.bg.primary, 1.4)
            return button.pressed ? Qt.darker(base, 1.2) : (button.hovered ? Qt.lighter(base, 1.2) : base)
        }
    }

    contentItem: T.Label {
        text: button.text
        font: button.font
        color: button.accent ? theme.accent : theme.fg.primary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
