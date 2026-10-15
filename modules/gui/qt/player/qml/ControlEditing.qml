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

pragma Singleton

import QtQuick

// Edition of the control bar, shared by its controls and its drop zones
QtObject {
    // the drag in progress, null if none
    property Item dragSource: null

    /**
     * applies the drop of a control at an index of a side (ControlListModel):
     * a control of the list of available controls is added, a control of
     * the bar is moved, within its side or to another one
     */
    function applyDrop(targetModel, destIndex, source) {
        if (!source || !targetModel)
            return

        if (source.fromPalette) {
            targetModel.insert(destIndex, { "id": source.controlId })
            return
        }

        if (source.dndModel === targetModel) {
            let to = destIndex
            if (to > source.dndIndex)
                to -= 1
            if (to !== source.dndIndex)
                targetModel.move(source.dndIndex, to)
            return
        }

        targetModel.insert(destIndex, { "id": source.controlId })
        source.dndModel.remove(source.dndIndex)
    }
}
