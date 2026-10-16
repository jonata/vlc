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

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Dialogs

// Customization of the control bar over the player: the controls of the bar
// are moved there, controls are dragged from this card to add them and back
// to it to remove them. The layouts are the profiles of the control bar.
FocusScope {
    id: root

    signal closeRequested()

    readonly property var _profiles: MainCtx.controlbarProfileModel

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    // the changes are dropped on cancel, the profiles are saved as they are
    // when the customization starts
    function start() {
        _profiles.save(false)
    }

    function cancel() {
        _profiles.reload()
        root.closeRequested()
    }

    function save() {
        _profiles.save()
        root.closeRequested()
    }

    function _profileNames() {
        const names = []
        for (let i = 0; i < _profiles.count; ++i)
            names.push(_profiles.getProfile(i).name)
        return names
    }

    Keys.onEscapePressed: root.cancel()

    implicitWidth: VLCStyle.dp(874, VLCStyle.scale)
    implicitHeight: column.implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: VLCStyle.seekPreview_radius
        color: Qt.alpha(theme.bg.primary, 0.97)
        border.color: theme.border
        border.width: VLCStyle.border
    }

    ColumnLayout {
        id: column

        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: VLCStyle.margin_xsmall
            Layout.leftMargin: VLCStyle.margin_normal

            T.Label {
                Layout.fillWidth: true
                text: qsTr("Customize Player")
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.fontSize_large
            }

            Widgets.IconToolButton {
                text: VLCIcons.close
                description: qsTr("Close")
                onClicked: root.cancel()
            }
        }

        T.Label {
            Layout.fillWidth: true
            Layout.leftMargin: VLCStyle.margin_normal
            Layout.rightMargin: VLCStyle.margin_normal
            Layout.bottomMargin: VLCStyle.margin_small

            text: qsTr("Drag items around and out of the box below to re-order them. Drag items into the box to remove them from the player.")
            wrapMode: Text.Wrap
            color: theme.fg.secondary
            font.pixelSize: VLCStyle.fontSize_normal
        }

        // layouts, saved as profiles
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: VLCStyle.margin_normal
            Layout.rightMargin: VLCStyle.margin_normal
            Layout.bottomMargin: VLCStyle.margin_small

            spacing: VLCStyle.margin_small

            T.Label {
                text: qsTr("Layout")
                color: theme.fg.primary
                font.pixelSize: VLCStyle.fontSize_normal
            }

            Widgets.DialogComboBox {
                Layout.fillWidth: true
                Layout.preferredHeight: VLCStyle.dp(32, VLCStyle.scale)

                model: { root._profiles.count; return root._profileNames() }
                currentIndex: root._profiles.selectedProfile

                onActivated: (index) => { root._profiles.selectedProfile = index }
            }

            Widgets.DialogButton {
                text: qsTr("Save as New Layout...")
                onClicked: {
                    const result = DialogsProvider.getTextDialog(null, qsTr("New Layout"), qsTr("Name of the layout:"),
                                                                 root._profiles.currentModel?.name ?? "")
                    if (result.ok && result.text !== "")
                        root._profiles.cloneSelectedProfile(result.text)
                }
            }
        }

        // the available controls, also where controls are removed
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: VLCStyle.dp(380, VLCStyle.scale)

            color: removeArea.containsDrag ? Qt.alpha(theme.accent, 0.1) : Qt.darker(theme.bg.primary, 1.15)

            GridView {
                id: controlsGrid

                anchors.fill: parent
                anchors.margins: VLCStyle.margin_normal

                clip: true
                cellWidth: VLCStyle.dp(92, VLCStyle.scale)
                cellHeight: VLCStyle.dp(100, VLCStyle.scale)

                model: PlayerControlbarControls.controlList

                T.ScrollBar.vertical: Widgets.ScrollBarExt { }

                delegate: Item {
                    id: paletteItem

                    required property var modelData

                    width: controlsGrid.cellWidth
                    height: controlsGrid.cellHeight

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: VLCStyle.margin_small
                        width: parent.width - VLCStyle.margin_xsmall
                        spacing: VLCStyle.margin_xsmall

                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: VLCStyle.dp(36, VLCStyle.scale)
                            height: width

                            Widgets.DashedRectangle {
                                anchors.fill: parent
                                color: theme.fg.secondary
                                opacity: 0.6
                                radius: VLCStyle.dp(4, VLCStyle.scale)
                            }

                            // moved while dragged, the control stays in the list
                            Item {
                                id: ghost

                                readonly property int controlId: paletteItem.modelData.id
                                readonly property bool fromPalette: true

                                // not bound to the parent, which changes while dragged
                                width: VLCStyle.dp(36, VLCStyle.scale)
                                height: width

                                Drag.active: dragArea.drag.active
                                Drag.keys: ["vlc-control"]
                                Drag.source: ghost
                                Drag.hotSpot.x: width / 2
                                Drag.hotSpot.y: height / 2

                                // the list clips its items, the control is
                                // moved above the card while it is dragged
                                states: State {
                                    when: dragArea.drag.active

                                    ParentChange { target: ghost; parent: root.parent }
                                    PropertyChanges { target: ghost; z: 100 }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    visible: dragArea.drag.active
                                    radius: VLCStyle.dp(4, VLCStyle.scale)
                                    color: theme.bg.secondary
                                    border.color: theme.accent
                                    border.width: VLCStyle.border
                                }

                                T.Label {
                                    anchors.centerIn: parent
                                    text: paletteItem.modelData.label
                                    font.family: VLCIcons.fontFamily
                                    font.pixelSize: VLCStyle.icon_normal
                                    color: dragArea.drag.active ? theme.accent : theme.fg.primary
                                }
                            }

                            MouseArea {
                                id: dragArea

                                anchors.fill: parent

                                cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                drag.target: ghost

                                onReleased: {
                                    if (drag.active)
                                        ghost.Drag.drop()
                                    ghost.x = 0
                                    ghost.y = 0
                                }
                            }
                        }

                        T.Label {
                            width: parent.width
                            text: paletteItem.modelData.text
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            color: theme.fg.secondary
                            font.pixelSize: VLCStyle.fontSize_small
                        }
                    }
                }
            }

            // a control of the bar dropped here is removed from it
            DropArea {
                id: removeArea

                anchors.fill: parent

                keys: ["vlc-control"]

                onDropped: (drop) => {
                    const source = drop.source
                    if (source && !source.fromPalette && source.dndModel) {
                        source.dndModel.remove(source.dndIndex)
                        drop.accept(Qt.MoveAction)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: VLCStyle.margin_normal

            Widgets.DialogButton {
                text: qsTr("Cancel")
                onClicked: root.cancel()
            }

            Item { Layout.fillWidth: true }

            Widgets.DialogButton {
                text: qsTr("Save")
                accent: true
                enabled: root._profiles.currentModel?.dirty ?? false
                onClicked: root.save()
            }
        }
    }
}
