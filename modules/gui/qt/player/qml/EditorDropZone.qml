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
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

// End of a side of the control bar while it is customized, a control
// dropped on it is added at the end of the side
Item {
    id: root

    // ControlListModel of the side
    property var targetModel: null

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    implicitWidth: VLCStyle.icon_normal + VLCStyle.margin_xsmall
    implicitHeight: VLCStyle.icon_normal + VLCStyle.margin_xsmall

    Layout.alignment: Qt.AlignVCenter

    Widgets.DashedRectangle {
        anchors.fill: parent
        color: dropArea.containsDrag ? theme.accent : theme.fg.secondary
        opacity: dropArea.containsDrag ? 1 : 0.5
        radius: VLCStyle.dp(4, VLCStyle.scale)
    }

    Widgets.IconLabel {
        anchors.centerIn: parent
        text: VLCIcons.add
        font.pixelSize: VLCStyle.icon_small
        color: dropArea.containsDrag ? theme.accent : theme.fg.secondary
    }

    DropArea {
        id: dropArea

        anchors.fill: parent

        keys: ["vlc-control"]

        onDropped: (drop) => {
            if (!root.targetModel)
                return
            ControlEditing.applyDrop(root.targetModel, root.targetModel.count, drop.source)
            drop.accept(Qt.MoveAction)
        }
    }
}
