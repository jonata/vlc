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

// Shown on the first run: a welcome with a media folder and the privacy
// choice, then the theme and its accent color, then the basic shortcuts
T.Popup {
    id: root

    property int step: 0
    readonly property int _lastStep: 2

    property url mediaFolder: onboarding.defaultMediaFolder()

    // the theme chosen on the second step (ColorSchemeModel)
    property int colorScheme: 0

    // accent colors offered, "default" is the orange of VLC
    readonly property var _accents: ["default", "#3478f6", "#8e5cf6", "#e3489b", "#e5484d", "#30a46c", "#12a594", "system"]

    parent: T.Overlay.overlay
    anchors.centerIn: parent

    width: Math.min(VLCStyle.dp(1090, VLCStyle.scale), (parent?.width ?? 0) - 2 * VLCStyle.margin_large)
    height: Math.min(VLCStyle.dp(759, VLCStyle.scale), (parent?.height ?? 0) - 2 * VLCStyle.margin_large)

    modal: true
    focus: true
    padding: 0

    // the choices are needed, the onboarding is finished with its last step
    closePolicy: T.Popup.NoAutoClose

    T.Overlay.modal: Rectangle {
        color: Qt.alpha("black", 0.5)
    }

    Onboarding {
        id: onboarding
        ctx: MainCtx
    }

    function finish() {
        onboarding.finish(privacyCheck.checked, root.mediaFolder)
        root.close()
    }

    background: Rectangle {
        radius: VLCStyle.seekPreview_radius
        color: theme.bg.primary
        border.color: theme.border
        border.width: VLCStyle.border
    }

    contentItem: ColumnLayout {
        // the popup is outside of the items of the window, see CardDialog
        readonly property ColorContext colorContext: ColorContext {
            id: theme
            palette: VLCStyle.palette
            colorSet: ColorContext.Window
        }

        spacing: 0

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: VLCStyle.margin_xlarge

            currentIndex: root.step

            // welcome
            StepPage {
                ColumnLayout {
                    width: parent.width
                    height: Math.max(implicitHeight, parent.parent.height)
                    spacing: VLCStyle.margin_normal

                    Item { Layout.fillHeight: true }

                    Widgets.BannerCone {
                        Layout.alignment: Qt.AlignHCenter
                        sourceSize: Qt.size(VLCStyle.dp(96, VLCStyle.scale), VLCStyle.dp(96, VLCStyle.scale))
                        color: theme.accent
                    }

                    T.Label {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: qsTr("Welcome to VLC!")
                        color: theme.fg.primary
                        font.pixelSize: VLCStyle.dp(32, VLCStyle.scale)
                        font.weight: Font.DemiBold
                    }

                    T.Label {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        Layout.maximumWidth: VLCStyle.dp(640, VLCStyle.scale)
                        text: qsTr("VLC is a free and open source cross-platform multimedia player and framework that plays most multimedia files as well as DVDs, Audio CDs, VCDs, and various streaming protocols.")
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        color: theme.fg.secondary
                        font.pixelSize: VLCStyle.fontSize_large
                    }

                    Item { Layout.preferredHeight: VLCStyle.margin_large }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        Layout.maximumWidth: VLCStyle.dp(520, VLCStyle.scale)
                        spacing: VLCStyle.margin_small

                        T.Label {
                            text: qsTr("Choose a Media Folder to get started with")
                            color: theme.fg.primary
                            font.pixelSize: VLCStyle.fontSize_normal
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: VLCStyle.margin_small

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: VLCStyle.dp(36, VLCStyle.scale)

                                radius: VLCStyle.dp(4, VLCStyle.scale)
                                color: Qt.lighter(theme.bg.primary, 1.25)

                                T.Label {
                                    anchors.fill: parent
                                    anchors.leftMargin: VLCStyle.margin_small
                                    anchors.rightMargin: VLCStyle.margin_small

                                    text: root.mediaFolder.toString() !== ""
                                          ? decodeURIComponent(root.mediaFolder.toString().replace(/^file:\/\//, ""))
                                          : qsTr("No folder")
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideMiddle
                                    color: theme.fg.primary
                                    font.pixelSize: VLCStyle.fontSize_normal
                                }
                            }

                            Widgets.DialogButton {
                                text: qsTr("Browse")
                                onClicked: {
                                    const folder = DialogsProvider.getFolderUrl(qsTr("Choose a Media Folder"))
                                    if (folder.toString() !== "")
                                        root.mediaFolder = folder
                                }
                            }
                        }

                        // VLC asks before using the network for the metadata
                        Widgets.CheckBoxExt {
                            id: privacyCheck

                            Layout.fillWidth: true
                            Layout.topMargin: VLCStyle.margin_small

                            checked: true
                            text: qsTr("Find cover art and information about my media on the internet")
                        }

                        T.Label {
                            Layout.fillWidth: true
                            text: qsTr("VLC does not collect or transmit any personal data. When this is checked, the names of some of your media may be sent to third party services to find their metadata.")
                            wrapMode: Text.Wrap
                            color: theme.fg.secondary
                            font.pixelSize: VLCStyle.fontSize_small
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // theme and color
            StepPage {
                ColumnLayout {
                    width: parent.width
                    height: Math.max(implicitHeight, parent.parent.height)
                    spacing: VLCStyle.margin_xlarge

                    Item { Layout.fillHeight: true }

                    T.Label {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: qsTr("Select your preferred theme and color.")
                        color: theme.fg.primary
                        font.pixelSize: VLCStyle.dp(28, VLCStyle.scale)
                        font.weight: Font.DemiBold
                    }

                    // the cards shrink in a small window
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        Layout.maximumWidth: 3 * VLCStyle.dp(180, VLCStyle.scale) + 2 * spacing
                        spacing: Math.min(VLCStyle.margin_xlarge, root.width / 40)

                        ThemeCard { text: qsTr("Light"); scheme: 1; lightPart: 1; onChosen: onboarding.setColorScheme(scheme) }
                        ThemeCard { text: qsTr("Dark"); scheme: 2; lightPart: 0; onChosen: onboarding.setColorScheme(scheme) }
                        ThemeCard { text: qsTr("System"); scheme: 0; lightPart: 0.5; onChosen: onboarding.setColorScheme(scheme) }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: VLCStyle.margin_normal

                        Repeater {
                            model: root._accents

                            T.AbstractButton {
                                id: swatch

                                required property string modelData

                                readonly property bool _selected: onboarding.accentColor === modelData

                                implicitWidth: VLCStyle.dp(36, VLCStyle.scale)
                                implicitHeight: implicitWidth

                                Accessible.name: modelData === "default" ? qsTr("Orange")
                                                : modelData === "system" ? qsTr("System accent color")
                                                : modelData

                                onClicked: onboarding.accentColor = modelData

                                background: Rectangle {
                                    radius: width / 2
                                    color: "transparent"
                                    border.color: swatch._selected ? theme.fg.primary : "transparent"
                                    border.width: VLCStyle.dp(2, VLCStyle.scale)
                                }

                                contentItem: Item {
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: parent.width - VLCStyle.dp(8, VLCStyle.scale)
                                        height: width
                                        radius: width / 2

                                        // the system accent is shown as a split circle
                                        color: swatch.modelData === "default" ? "#ff8800"
                                             : swatch.modelData === "system" ? "transparent"
                                             : swatch.modelData
                                        border.color: theme.fg.secondary
                                        border.width: swatch.modelData === "system" ? VLCStyle.dp(2, VLCStyle.scale) : 0

                                        Widgets.IconLabel {
                                            anchors.centerIn: parent
                                            visible: swatch.modelData === "system"
                                            text: VLCIcons.settings
                                            font.pixelSize: VLCStyle.icon_small
                                            color: theme.fg.secondary
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // shortcuts
            StepPage {
                ColumnLayout {
                    width: parent.width
                    height: Math.max(implicitHeight, parent.parent.height)
                    spacing: VLCStyle.margin_large

                    T.Label {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: qsTr("Learn the basic keyboard shortcuts.")
                        color: theme.fg.primary
                        font.pixelSize: VLCStyle.dp(28, VLCStyle.scale)
                        font.weight: Font.DemiBold
                    }

                    // one column in a small window
                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: (root.width < VLCStyle.dp(760, VLCStyle.scale)) ? 1 : 2
                        columnSpacing: VLCStyle.margin_xlarge
                        rowSpacing: VLCStyle.margin_large

                        ShortcutColumn {
                            shortcuts: [
                                { text: qsTr("Play / Pause"), keys: [onboarding.hotkey("play-pause")] },
                                { text: qsTr("Seek Backward / Forward"), keys: [onboarding.hotkey("jump-extrashort"), onboarding.hotkey("jump+extrashort")] },
                                { text: qsTr("Previous / Next Item"), keys: [onboarding.hotkey("prev"), onboarding.hotkey("next")] },
                                { text: qsTr("Next Frame"), keys: [onboarding.hotkey("frame-next")] },
                                { text: qsTr("Cycle Subtitle Track"), keys: [onboarding.hotkey("subtitle-track")] },
                                { text: qsTr("Cycle Audio Track"), keys: [onboarding.hotkey("audio-track")] }
                            ]
                        }

                        ShortcutColumn {
                            shortcuts: [
                                { text: qsTr("Toggle Fullscreen"), keys: [onboarding.hotkey("toggle-fullscreen")] },
                                { text: qsTr("Increase / Decrease Volume"), keys: [onboarding.hotkey("vol-up"), onboarding.hotkey("vol-down")] },
                                { text: qsTr("Hide / Show Interface"), keys: ["Ctrl+H"] },
                                { text: qsTr("Bookmark the Current Time"), keys: ["Ctrl+B"] },
                                { text: qsTr("Take a Snapshot"), keys: [onboarding.hotkey("snapshot")] },
                                { text: qsTr("Record"), keys: [onboarding.hotkey("record")] }
                            ]
                        }
                    }

                    T.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: qsTr("Find the full list in the menu, under Tools, Keyboard Shortcuts.")
                        color: theme.fg.secondary
                        font.pixelSize: VLCStyle.fontSize_normal
                    }
                }
            }
        }

        // navigation between the steps
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: VLCStyle.margin_large
            Layout.topMargin: 0

            Widgets.DialogButton {
                visible: root.step > 0
                text: qsTr("Back")
                onClicked: root.step -= 1
            }

            Item { Layout.fillWidth: true }

            Row {
                spacing: VLCStyle.margin_xsmall

                Repeater {
                    model: root._lastStep + 1

                    Rectangle {
                        required property int index

                        width: VLCStyle.dp(8, VLCStyle.scale)
                        height: width
                        radius: width / 2
                        color: index === root.step ? theme.accent : theme.border
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Widgets.DialogButton {
                text: root.step === root._lastStep ? qsTr("Finish") : qsTr("Next")
                accent: true
                onClicked: {
                    if (root.step === root._lastStep)
                        root.finish()
                    else
                        root.step += 1
                }
            }
        }
    }

    // a step, which scrolls when the window is too small for it
    component StepPage: Flickable {
        clip: true
        // room for the scroll bar, beside the content
        rightMargin: VLCStyle.margin_normal
        contentWidth: width - rightMargin
        contentHeight: contentItem.childrenRect.height
        boundsBehavior: Flickable.StopAtBounds

        T.ScrollBar.vertical: Widgets.ScrollBarExt { }
    }

    // a theme, applied when chosen, with a sketch of the interface
    component ThemeCard: T.AbstractButton {
        id: card

        property int scheme
        // how much of the sketch is light, the system theme is shown half and half
        property real lightPart

        readonly property bool _selected: MainCtx.colorScheme.scheme === scheme

        signal chosen()

        readonly property ColorContext colorContext: ColorContext {
            id: cardTheme
            palette: VLCStyle.palette
            colorSet: ColorContext.Window
        }

        implicitWidth: VLCStyle.dp(180, VLCStyle.scale)
        implicitHeight: VLCStyle.dp(150, VLCStyle.scale)

        Layout.fillWidth: true
        Layout.preferredWidth: implicitWidth
        Layout.minimumWidth: VLCStyle.dp(80, VLCStyle.scale)

        onClicked: card.chosen()

        background: null

        contentItem: Column {
            spacing: VLCStyle.margin_small

            Rectangle {
                width: card.width
                height: VLCStyle.dp(116, VLCStyle.scale)

                radius: VLCStyle.dp(8, VLCStyle.scale)
                color: "#1d1d1d"
                border.color: card._selected ? cardTheme.accent : cardTheme.border
                border.width: card._selected ? VLCStyle.dp(2, VLCStyle.scale) : VLCStyle.border
                clip: true

                // the light part of the sketch
                Rectangle {
                    x: VLCStyle.dp(2, VLCStyle.scale)
                    y: x
                    width: (parent.width - 2 * x) * card.lightPart
                    height: parent.height - 2 * y
                    radius: VLCStyle.dp(6, VLCStyle.scale)
                    color: "#f2f2f2"
                }

                // a video and a control bar
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: VLCStyle.dp(12, VLCStyle.scale)
                    anchors.bottomMargin: VLCStyle.dp(28, VLCStyle.scale)
                    radius: VLCStyle.dp(4, VLCStyle.scale)
                    color: "#6b6b6b"
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: VLCStyle.dp(12, VLCStyle.scale)
                    height: VLCStyle.dp(8, VLCStyle.scale)
                    radius: height / 2
                    color: cardTheme.accent
                }
            }

            T.Label {
                width: card.width
                text: card.text
                horizontalAlignment: Text.AlignHCenter
                color: card._selected ? cardTheme.fg.primary : cardTheme.fg.secondary
                font.pixelSize: VLCStyle.fontSize_normal
            }
        }
    }

    // shortcuts, each with its keys
    component ShortcutColumn: ColumnLayout {
        property var shortcuts: []

        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: VLCStyle.margin_normal

        Repeater {
            model: parent.shortcuts

            RowLayout {
                id: shortcutRow

                required property var modelData

                Layout.fillWidth: true
                spacing: VLCStyle.margin_xsmall

                T.Label {
                    Layout.fillWidth: true
                    text: shortcutRow.modelData.text
                    color: shortcutRow.colorContext.fg.primary
                    font.pixelSize: VLCStyle.fontSize_large
                }

                Repeater {
                    model: shortcutRow.modelData.keys.filter(key => key !== "")

                    Rectangle {
                        required property string modelData

                        implicitWidth: Math.max(implicitHeight, keyLabel.implicitWidth + 2 * VLCStyle.margin_small)
                        implicitHeight: VLCStyle.dp(36, VLCStyle.scale)

                        radius: VLCStyle.dp(6, VLCStyle.scale)
                        color: Qt.lighter(shortcutRow.colorContext.bg.primary, 1.3)
                        border.color: shortcutRow.colorContext.border
                        border.width: VLCStyle.border

                        T.Label {
                            id: keyLabel
                            anchors.centerIn: parent
                            text: parent.modelData
                            color: shortcutRow.colorContext.fg.primary
                            font.pixelSize: VLCStyle.fontSize_normal
                        }
                    }
                }

                readonly property ColorContext colorContext: ColorContext {
                    palette: VLCStyle.palette
                    colorSet: ColorContext.Window
                }
            }
        }
    }
}
