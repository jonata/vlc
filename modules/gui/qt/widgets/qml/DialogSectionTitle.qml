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

// a title with a description, at the top of a section of a dialog
ColumnLayout {
    id: root

    property alias text: titleLabel.text
    property alias description: descriptionLabel.text

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    Layout.fillWidth: true
    spacing: VLCStyle.margin_xxsmall

    T.Label {
        id: titleLabel
        Layout.fillWidth: true
        color: theme.fg.primary
        font.pixelSize: VLCStyle.fontSize_xlarge
        font.weight: Font.DemiBold
    }

    T.Label {
        id: descriptionLabel
        Layout.fillWidth: true
        visible: text !== ""
        wrapMode: Text.Wrap
        color: theme.fg.secondary
        font.pixelSize: VLCStyle.fontSize_normal
    }
}
