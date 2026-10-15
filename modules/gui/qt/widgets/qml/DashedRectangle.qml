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

// outline with dashes, as around what can be moved
Canvas {
    id: root

    property color color: "white"
    property real radius: 4
    property real lineWidth: 1
    property var dashPattern: [3, 3]

    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.strokeStyle = root.color
        ctx.lineWidth = root.lineWidth
        ctx.setLineDash(root.dashPattern)

        const inset = root.lineWidth / 2
        const w = width - 2 * inset
        const h = height - 2 * inset
        const r = Math.min(root.radius, w / 2, h / 2)

        ctx.beginPath()
        ctx.roundedRect(inset, inset, w, h, r, r)
        ctx.stroke()
    }
}
