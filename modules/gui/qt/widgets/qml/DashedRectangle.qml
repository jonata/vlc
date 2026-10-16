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

// outline with dashes, as around what can be moved; drawn with rectangles,
// as the builds of Qt of VLC have no Canvas and no Shapes
Item {
    id: root

    property color color: "white"
    // the corners are left open, the dashes stop before them
    property real radius: 4
    property real lineWidth: 1
    property var dashPattern: [3, 3]

    readonly property real _dash: dashPattern[0] * lineWidth
    readonly property real _gap: dashPattern[1] * lineWidth

    component Edge: Item {
        id: edge

        // along the length, the dashes are spread evenly
        property real length
        property bool vertical: false

        readonly property int _count: Math.max(1, Math.floor((length + root._gap) / (root._dash + root._gap)))
        readonly property real _step: (_count > 1) ? (length - root._dash) / (_count - 1) : 0

        Repeater {
            model: edge._count

            Rectangle {
                required property int index

                x: edge.vertical ? 0 : index * edge._step
                y: edge.vertical ? index * edge._step : 0
                width: edge.vertical ? root.lineWidth : root._dash
                height: edge.vertical ? root._dash : root.lineWidth
                color: root.color
            }
        }
    }

    readonly property real _inset: Math.min(radius, width / 2, height / 2)

    Edge { x: root._inset; y: 0; length: root.width - 2 * root._inset }
    Edge { x: root._inset; y: root.height - root.lineWidth; length: root.width - 2 * root._inset }
    Edge { x: 0; y: root._inset; length: root.height - 2 * root._inset; vertical: true }
    Edge { x: root.width - root.lineWidth; y: root._inset; length: root.height - 2 * root._inset; vertical: true }
}
