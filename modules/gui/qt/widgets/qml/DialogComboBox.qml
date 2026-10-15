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
import VLC.Widgets as Widgets

// drop-down in the style of the dialogs
T.ComboBox {
    id: dropDown

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    // without background until hovered
    property bool plain: false

    font.pixelSize: VLCStyle.fontSize_normal

    leftPadding: VLCStyle.margin_small
    rightPadding: VLCStyle.margin_small

    background: Rectangle {
        radius: VLCStyle.dp(2, VLCStyle.scale)
        color: (dropDown.hovered || dropDown.popup.visible) ? theme.bg.secondary
                                                            : (dropDown.plain ? "transparent" : Qt.lighter(theme.bg.primary, 1.25))
    }

    contentItem: T.Label {
        rightPadding: dropDown.indicator.width + VLCStyle.margin_xsmall
        text: dropDown.displayText
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
        color: theme.fg.secondary
        font: dropDown.font
    }

    indicator: Widgets.IconLabel {
        x: dropDown.width - width - dropDown.rightPadding
        y: (dropDown.height - height) / 2
        visible: !dropDown.plain || dropDown.hovered || dropDown.popup.visible
        text: VLCIcons.chevron_down
        font.pixelSize: VLCStyle.icon_small
        color: theme.fg.secondary
    }

    delegate: T.ItemDelegate {
        id: choice

        required property int index
        required property var modelData

        width: ListView.view.width
        padding: VLCStyle.margin_xsmall
        leftPadding: VLCStyle.margin_small

        highlighted: dropDown.highlightedIndex === index

        background: Rectangle {
            color: choice.highlighted ? theme.bg.secondary : "transparent"
        }

        contentItem: T.Label {
            text: choice.modelData
            elide: Text.ElideRight
            color: (choice.index === dropDown.currentIndex) ? theme.accent : theme.fg.primary
            font: dropDown.font
        }
    }

    popup: T.Popup {
        y: dropDown.height + VLCStyle.margin_xxxsmall
        width: dropDown.width
        height: Math.min(contentItem.implicitHeight + topPadding + bottomPadding,
                         VLCStyle.dp(300, VLCStyle.scale))
        padding: VLCStyle.margin_xxxsmall

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: dropDown.popup.visible ? dropDown.delegateModel : null
            currentIndex: dropDown.highlightedIndex
        }

        background: Rectangle {
            radius: VLCStyle.dp(4, VLCStyle.scale)
            color: theme.bg.primary
            border.color: theme.border
            border.width: VLCStyle.border
        }
    }
}
