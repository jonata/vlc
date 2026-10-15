/*****************************************************************************
 * Copyright (C) 2020 VLC authors and VideoLAN
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
import VLC.PlayerControls

FocusScope {
    id: playerControlLayout

    // Properties

    property real spacing: VLCStyle.margin_normal // spacing between controls

    property real layoutSpacing: VLCStyle.margin_xxlarge // spacing between layouts (left, center, and right)

    property int identifier: -1

    // optional item laid out between the left and right controls, it takes
    // the remaining space (used for the inline seek bar)
    property Item centerItem: null

    // the controls are moved, added and removed by dragging them
    property bool editMode: false

    readonly property PlayerControlbarModel model: {
        if (!!MainCtx.controlbarProfileModel.currentModel)
            return MainCtx.controlbarProfileModel.currentModel.getModel(identifier)
        else
            return null
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    // Signals

    signal requestLockUnlockAutoHide(bool lock)
    signal menuOpened(var menu)
    ///incomming signal to request all menu and popup to close
    signal forceUnlock()

    // Settings

    implicitWidth: loaderLeftRight.active ? loaderLeftRight.implicitWidth
                                          : (loaderLeft.implicitWidth + loaderCenter.implicitWidth + loaderRight.implicitWidth)

    implicitHeight: loaderLeftRight.active ? loaderLeftRight.implicitHeight
                                           : Math.max(loaderLeft.implicitHeight, loaderCenter.implicitHeight, loaderRight.implicitHeight)

    // Events

    Component.onCompleted: console.assert(identifier >= 0)

    // Children

    Loader {
        id: loaderLeftRight

        anchors.fill: parent

        active: (!loaderCenter.active || !!playerControlLayout.centerItem) &&
                playerControlLayout.model &&
                ((playerControlLayout.model.left && (playerControlLayout.model.left.count > 0)) ||
                (playerControlLayout.model.right && (playerControlLayout.model.right.count > 0)) ||
                (!!playerControlLayout.centerItem && playerControlLayout.model.center && (playerControlLayout.model.center.count > 0)))

        focus: active

        sourceComponent: RowLayout {
            spacing: playerControlLayout.spacing

            focus: true

            // TODO: Qt >= 5.13 Use QConcatenateTablesProxyModel
            //       instead of multiple repeaters

            ControlRepeater {
                id: leftRepeater

                editMode: playerControlLayout.editMode
                editModel: playerControlLayout.model.left
                model: ControlListFilter {
                    sourceModel: playerControlLayout.model.left

                    // every control is shown while editing, so that the rows
                    // of the filter are those of the model
                    player: playerControlLayout.editMode ? null : Player
                    ctx: playerControlLayout.editMode ? null : MainCtx
                }

                Navigation.parentItem: playerControlLayout
                Navigation.rightAction: function() {
                    const item = centerRepeater.itemAt(0) ?? rightRepeater.itemAt(0)
                    if (item)
                        item.forceActiveFocus(Qt.TabFocusReason)
                    else
                        return false
                }

                availableWidth: loaderLeftRight.width
                availableHeight: loaderLeftRight.height

                Component.onCompleted: {
                    requestLockUnlockAutoHide.connect(playerControlLayout.requestLockUnlockAutoHide)
                    menuOpened.connect(playerControlLayout.menuOpened)
                    playerControlLayout.forceUnlock.connect(leftRepeater.forceUnlock)
                }
            }

            EditorDropZone {
                visible: playerControlLayout.editMode
                targetModel: playerControlLayout.model.left
            }

            // center controls are only shown here when the center is taken by centerItem
            ControlRepeater {
                id: centerRepeater

                editMode: playerControlLayout.editMode
                editModel: playerControlLayout.model.center
                model: playerControlLayout.centerItem ? _centerFilter : null

                readonly property ControlListFilter _centerFilter: ControlListFilter {
                    sourceModel: playerControlLayout.model.center

                    // every control is shown while editing, so that the rows
                    // of the filter are those of the model
                    player: playerControlLayout.editMode ? null : Player
                    ctx: playerControlLayout.editMode ? null : MainCtx
                }

                Navigation.parentItem: playerControlLayout
                Navigation.leftAction: function() {
                    const item = leftRepeater.itemAt(leftRepeater.count - 1)
                    if (item)
                        item.forceActiveFocus(Qt.BacktabFocusReason)
                    else
                        return false
                }
                Navigation.rightAction: function() {
                    const item = rightRepeater.itemAt(0)
                    if (item)
                        item.forceActiveFocus(Qt.TabFocusReason)
                    else
                        return false
                }

                availableWidth: loaderLeftRight.width
                availableHeight: loaderLeftRight.height

                Component.onCompleted: {
                    requestLockUnlockAutoHide.connect(playerControlLayout.requestLockUnlockAutoHide)
                    menuOpened.connect(playerControlLayout.menuOpened)
                    playerControlLayout.forceUnlock.connect(centerRepeater.forceUnlock)
                }
            }

            Item {
                id: centerFiller

                function containsVisibleItem(repeater) {
                    for (let i = 0; i < repeater.count; ++i) {
                        const item = repeater.itemAt(i)

                        if (item && item.visible)
                            return true
                    }

                    return false
                }

                Layout.minimumWidth: {
                    if (playerControlLayout.centerItem)
                        return playerControlLayout.centerItem.implicitWidth + 2 * playerControlLayout.layoutSpacing
                    return (containsVisibleItem(leftRepeater) && containsVisibleItem(rightRepeater)) ? playerControlLayout.layoutSpacing
                                                                                                     : 0
                }

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: true

                children: playerControlLayout.centerItem ? [playerControlLayout.centerItem] : []
            }

            ControlRepeater {
                id: rightRepeater

                editMode: playerControlLayout.editMode
                editModel: playerControlLayout.model.right
                model: ControlListFilter {
                    sourceModel: playerControlLayout.model.right

                    // every control is shown while editing, so that the rows
                    // of the filter are those of the model
                    player: playerControlLayout.editMode ? null : Player
                    ctx: playerControlLayout.editMode ? null : MainCtx
                }

                Navigation.parentItem: playerControlLayout
                Navigation.leftAction: function() {
                    const item = centerRepeater.itemAt(centerRepeater.count - 1) ?? leftRepeater.itemAt(leftRepeater.count - 1)
                    if (item)
                        item.forceActiveFocus(Qt.BacktabFocusReason)
                    else
                        return false
                }

                availableWidth: loaderLeftRight.width
                availableHeight: loaderLeftRight.height

                Component.onCompleted: {
                    requestLockUnlockAutoHide.connect(playerControlLayout.requestLockUnlockAutoHide)
                    menuOpened.connect(playerControlLayout.menuOpened)
                    playerControlLayout.forceUnlock.connect(rightRepeater.forceUnlock)
                }
            }

            EditorDropZone {
                visible: playerControlLayout.editMode
                targetModel: playerControlLayout.model.right
            }

        }
    }


    Loader {
        id: loaderLeft

        anchors {
            right: loaderCenter.left
            left: parent.left
            top: parent.top
            bottom: parent.bottom

            // Spacing for the filler item acts as padding
            rightMargin: layoutSpacing - spacing
        }

        active: !!playerControlLayout.model?.left && (playerControlLayout.model.left.count > 0) &&
                !loaderLeftRight.active

        focus: active

        sourceComponent: ControlLayout {
            id: leftControlLayout

            editMode: playerControlLayout.editMode
            editModel: playerControlLayout.model.left

            model: ControlListFilter {
                sourceModel: playerControlLayout.model.left

                player: playerControlLayout.editMode ? null : Player
                ctx: playerControlLayout.editMode ? null : MainCtx
            }

            alignment: (Qt.AlignVCenter | Qt.AlignLeft)

            spacing: playerControlLayout.spacing

            focus: true

            altFocusAction: () => Navigation.defaultNavigationRight()

            Navigation.parentItem: playerControlLayout
            Navigation.rightItem: loaderCenter.item

            Component.onCompleted: {
                requestLockUnlockAutoHide.connect(playerControlLayout.requestLockUnlockAutoHide)
                menuOpened.connect(playerControlLayout.menuOpened)
                playerControlLayout.forceUnlock.connect(leftControlLayout.forceUnlock)
            }
        }
    }

    Loader {
        id: loaderCenter

        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            bottom: parent.bottom
        }

        // TODO: "ControlListFilter"'s count......
        active: !!playerControlLayout.model && !!playerControlLayout.model.center && (playerControlLayout.model.center.count > 0) &&
                !playerControlLayout.centerItem

        Binding on width {
            delayed: true
            when: loaderCenter._componentCompleted
            value: {
                const item = loaderCenter.item

                const minimumWidth = (item && item.Layout.minimumWidth > 0) ? item.Layout.minimumWidth : implicitWidth
                const maximumWidth = (item && item.Layout.maximumWidth > 0) ? item.Layout.maximumWidth : implicitWidth

                if ((loaderLeft.active && (loaderLeft.width > 0)) || (loaderRight.active && (loaderRight.width > 0))) {
                    return minimumWidth
                } else {
                    return Math.min(loaderCenter.parent.width, maximumWidth)
                }
            }
        }

        property bool _componentCompleted: false

        Component.onCompleted: {
            _componentCompleted = true
        }

        sourceComponent: ControlLayout {
            id: centerControlLayout

            editMode: playerControlLayout.editMode
            editModel: playerControlLayout.model.center

            model: ControlListFilter {
                sourceModel: playerControlLayout.model.center

                player: playerControlLayout.editMode ? null : Player
                ctx: playerControlLayout.editMode ? null : MainCtx
            }

            focus: true

            spacing: playerControlLayout.spacing

            altFocusAction: () => Navigation.defaultNavigationUp()

            Navigation.parentItem: playerControlLayout
            Navigation.leftItem: loaderLeft.item
            Navigation.rightItem: loaderRight.item

            Component.onCompleted: {
                requestLockUnlockAutoHide.connect(playerControlLayout.requestLockUnlockAutoHide)
                menuOpened.connect(playerControlLayout.menuOpened)
                playerControlLayout.forceUnlock.connect(centerControlLayout.forceUnlock)
            }
        }
    }

    Loader {
        id: loaderRight

        anchors {
            left: loaderCenter.right
            right: parent.right
            top: parent.top
            bottom: parent.bottom

            // Spacing for the filler item acts as padding
            leftMargin: layoutSpacing - spacing
        }

        active: !!playerControlLayout.model && !!playerControlLayout.model.right && (playerControlLayout.model.right.count > 0) &&
                !loaderLeftRight.active

        sourceComponent: ControlLayout {
            id: rightControlLayout

            editMode: playerControlLayout.editMode
            editModel: playerControlLayout.model.right

            model: ControlListFilter {
                sourceModel: playerControlLayout.model.right

                player: playerControlLayout.editMode ? null : Player
                ctx: playerControlLayout.editMode ? null : MainCtx
            }

            alignment: (Qt.AlignVCenter | Qt.AlignRight)

            spacing: playerControlLayout.spacing

            focus: true

            altFocusAction: () => Navigation.defaultNavigationLeft()

            Navigation.parentItem: playerControlLayout
            Navigation.leftItem: loaderCenter.item

            onRequestLockUnlockAutoHide: (lock) => playerControlLayout.requestLockUnlockAutoHide(lock)

            onMenuOpened: (menu) => playerControlLayout.menuOpened(menu)

            Component.onCompleted:{
                playerControlLayout.forceUnlock.connect(rightControlLayout.forceUnlock)
            }
        }
    }
}
