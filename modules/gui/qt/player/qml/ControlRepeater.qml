/*****************************************************************************
 * Copyright (C) 2023 VLC authors and VideoLAN
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

Repeater {
    id: repeater

    property int alignment: Qt.AlignVCenter

    property real availableWidth: Number.MAX_VALUE
    property real availableHeight: Number.MAX_VALUE

    // while the control bar is customized, the controls are moved by
    // dragging them, in editModel (the ControlListModel of the side)
    property bool editMode: false
    property var editModel: null

    signal requestLockUnlockAutoHide(bool lock)
    signal menuOpened(var menu)
    ///incomming signal to request all menu and popup to close
    signal forceUnlock()

    // NOTE: We apply the 'navigation chain' after adding the item.
    onItemAdded: (index, item) => {
        item.applyNavigation()
    }

    onItemRemoved: (index, item) => {
        // NOTE: We update the 'navigation chain' after removing the item.
        item.removeNavigation()

        item.recoverFocus(index)
    }

    delegate: Loader {
        id: loader

        // Settings

        source: PlayerControlbarControls.control(model.id).source

        focus: (index === 0)

        Layout.fillWidth: (item && item.Layout.minimumWidth > 0)
        Layout.minimumWidth: Layout.fillWidth ? item.Layout.minimumWidth : (item ? item.implicitWidth : -1)
        Layout.maximumWidth: Layout.fillWidth ? (item ? item.implicitWidth : -1) : -1

        Layout.minimumHeight: 0
        Layout.maximumHeight: Math.min((item && item.implicitHeight <= 0) ? Number.MAX_VALUE : item.implicitHeight, repeater.availableHeight)
        Layout.fillHeight: true

        Layout.alignment: repeater.alignment

        // the controls are not used while they are moved
        Binding {
            target: loader.item
            property: "enabled"
            value: false
            when: repeater.editMode && loader.status === Loader.Ready
        }

        // known when the control is loaded, reading the property in the
        // binding below would make it depend on itself
        property bool _hasPaintOnly: false

        // some controls, such as the spacers, are only drawn in this mode
        Binding {
            target: loader.item
            property: "paintOnly"
            value: true
            when: repeater.editMode && loader._hasPaintOnly
        }

        Item {
            id: editHandle

            // what a drop needs to know about the dragged control
            readonly property int controlId: model.id
            readonly property var dndModel: repeater.editModel
            readonly property int dndIndex: index
            readonly property bool fromPalette: false

            width: loader.width
            height: loader.height

            visible: repeater.editMode
            z: 10

            Drag.active: dragArea.drag.active
            Drag.keys: ["vlc-control"]
            Drag.source: editHandle
            Drag.hotSpot.x: width / 2
            Drag.hotSpot.y: height / 2

            readonly property ColorContext colorContext: ColorContext {
                id: editTheme
                colorSet: ColorContext.Window
            }

            // a copy of the control follows the pointer
            ShaderEffectSource {
                anchors.fill: parent
                visible: dragArea.drag.active
                sourceItem: dragArea.drag.active ? loader.item : null
                hideSource: dragArea.drag.active
                live: false
            }

            Widgets.DashedRectangle {
                anchors.fill: parent
                anchors.margins: -VLCStyle.margin_xxxsmall
                color: editTheme.fg.secondary
                opacity: 0.7
                radius: VLCStyle.dp(4, VLCStyle.scale)
            }

            // where the dropped control goes
            Rectangle {
                x: dropArea.before ? -VLCStyle.margin_xxsmall - width / 2 : parent.width + VLCStyle.margin_xxsmall - width / 2
                width: VLCStyle.dp(2, VLCStyle.scale)
                height: parent.height
                visible: dropArea.containsDrag && dropArea.drag.source !== editHandle
                color: editTheme.accent
            }

            MouseArea {
                id: dragArea

                anchors.fill: parent

                cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                drag.target: editHandle
                drag.threshold: VLCStyle.dp(4, VLCStyle.scale)

                onReleased: {
                    if (drag.active)
                        editHandle.Drag.drop()
                    // back in place, the model updates the bar
                    editHandle.x = 0
                    editHandle.y = 0
                }
            }

            DropArea {
                id: dropArea

                anchors.fill: parent

                keys: ["vlc-control"]

                // the control goes before or after this one, after the side of the drop
                readonly property bool before: drag.x < width / 2

                onDropped: (drop) => {
                    if (drop.source === editHandle || !repeater.editModel)
                        return
                    ControlEditing.applyDrop(repeater.editModel, index + (before ? 0 : 1), drop.source)
                    drop.accept(Qt.MoveAction)
                }
            }
        }

        Binding on visible {
            delayed: true // this is important
            when: condition
            value: {
                if (condition)
                    return (loader.x + loader.Layout.minimumWidth <= repeater.availableWidth)
                else
                    return true;
            }

            property bool condition: false

            Binding on condition {
                delayed: true
                value: (loader.status === Loader.Ready) &&
                       (loader.Layout.minimumWidth > 0) &&
                       (repeater.availableWidth < Number.MAX_VALUE)
            }
        }

        // Events

        onActiveFocusChanged: {
            if (activeFocus && !item?.focus) {
                recoverFocus()
            }
        }

        onLoaded: {
            _hasPaintOnly = (item.paintOnly !== undefined)

            // control should not request focus if they are not enabled:
            item.focus = Qt.binding(function() { return item.enabled && item.visible })

            // navigation parent of control is always controlLayout
            // so it can be set here unlike leftItem and rightItem:
            item.Navigation.parentItem = repeater

            if (typeof item.activeFocusOnTab === "boolean")
                item.activeFocusOnTab = true

            item.visible = Qt.binding(function() { return loader.visible })

            if (item.requestLockUnlockAutoHide)
                item.requestLockUnlockAutoHide.connect(repeater.requestLockUnlockAutoHide)

            if (item.menuOpened)
                item.menuOpened.connect(repeater.menuOpened)

            if (item.forceUnlock)
                repeater.forceUnlock.connect(item.forceUnlock)

            //can't connect to enabledChanged in a Connections
            item.onEnabledChanged.connect(() => {
                if (loader.activeFocus && !item.enabled) // Loader has focus but item is not enabled
                    recoverFocus()
            })
        }

        // Connections

        Connections {
            target: item

            enabled: loader.status === Loader.Ready

            function onVisibleChanged() {
                if (loader.activeFocus && !item.visible)
                    recoverFocus()
            }
        }

        // Functions

        function applyNavigation() {
            if (item === null) return

            const itemLeft  = repeater.itemAt(index - 1)
            const itemRight = repeater.itemAt(index + 1)

            if (itemLeft) {
                const componentLeft = itemLeft.item

                if (componentLeft)
                {
                    item.Navigation.leftItem = componentLeft

                    componentLeft.Navigation.rightItem = item
                }
            }

            if (itemRight) {
                const componentRight = itemRight.item

                if (componentRight)
                {
                    item.Navigation.rightItem = componentRight

                    componentRight.Navigation.leftItem = item
                }
            }
        }

        function removeNavigation() {
            if (item === null) return

            const itemLeft = repeater.itemAt(index - 1)

            // NOTE: The current item was removed from the repeater so we test against the
            //       same index.
            const itemRight = repeater.itemAt(index)

            if (itemLeft) {
                if (itemRight) {
                    itemLeft.item.Navigation.rightItem = itemRight.item
                    itemRight.item.Navigation.leftItem = itemLeft.item
                }
                else
                    itemLeft.item.Navigation.rightItem = null
            }
            else if (itemRight) {
                itemRight.item.Navigation.leftItem = null
            }
        }

        function recoverFocus(_index) {
            if (item === null) return

            const controlLayout = repeater.Navigation.parentItem

            if (!controlLayout || !controlLayout.visible)
                return

            if (_index === undefined)
                _index = index

            for (let i = 1; i <= Math.max(_index, repeater.count - (_index + 1)); ++i) {
                 if (i <= _index) {
                     const leftItem = repeater.itemAt(_index - i)

                     if (_focusIfFocusable(leftItem))
                         return
                 }

                 if (_index + i <= repeater.count - 1) {
                     const rightItem = repeater.itemAt(_index + i)

                     if (_focusIfFocusable(rightItem))
                         return
                 }
            }

            // focus to other alignment if focusable control
            // in the same alignment is not found:
            if (!!controlLayout.Navigation.rightItem) {
                controlLayout.Navigation.defaultNavigationRight()
            } else if (!!controlLayout.Navigation.leftItem) {
                controlLayout.Navigation.defaultNavigationLeft()
            } else if (controlLayout.altFocusAction) {
                controlLayout.altFocusAction()
            }
        }

        // Private

        function _focusIfFocusable(_loader) {
            if (_loader?.item?.focus) {
                if (item.focusReason !== undefined)
                    _loader.item.forceActiveFocus(item.focusReason)
                else {
                    console.warn("focusReason is not available in %1!".arg(item))
                    _loader.item.forceActiveFocus()
                }
                return true
            } else {
                return false
            }
        }
    }
}
