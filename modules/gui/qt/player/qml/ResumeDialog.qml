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
import QtQuick.Templates as T


import VLC.MainInterface
import VLC.Player
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util

// Offers to continue the playback where it was left, as a card near the
// playback controls
FocusScope {
    id: resumePanel

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    visible: false
    enabled: visible

    Accessible.role: Accessible.Dialog
    Accessible.name: qsTr("Resume dialog")

    signal hidden()

    function showResumePanel ()
    {
        resumePanel.visible = true
        continueBtn.forceActiveFocus()
        resumeTimeout.start()
    }

    function hideResumePanel() {
        resumeTimeout.stop()
        resumePanel.visible = false
        Player.acknowledgeRestoreCallback()
        hidden()
    }

    Timer {
        id: resumeTimeout
        interval: 10000
        onTriggered: {
            resumePanel.visible = false
            hidden()
        }
    }

    Connections {
        target: Player
        function onCanRestorePlaybackChanged() {
            if (Player.canRestorePlayback) {
                showResumePanel()
            } else {
                hideResumePanel()
            }
        }
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    Component.onCompleted: {
        if (Player.canRestorePlayback) {
            showResumePanel()
        }
    }

    Navigation.cancelAction: function() {
        hideResumePanel()
    }

    Rectangle {
        id: card

        anchors.fill: parent

        implicitWidth: row.implicitWidth + 2 * VLCStyle.seekPreview_padding
        implicitHeight: row.implicitHeight + 2 * VLCStyle.seekPreview_padding

        radius: VLCStyle.seekPreview_radius
        color: Qt.alpha(theme.bg.primary, 0.95)

        RowLayout {
            id: row

            anchors.centerIn: parent

            spacing: VLCStyle.margin_xsmall

            T.Label {
                id: label

                Layout.leftMargin: VLCStyle.margin_xsmall
                Layout.rightMargin: VLCStyle.margin_small

                color: theme.fg.primary
                font.pixelSize: VLCStyle.fontSize_normal

                text: qsTr("Continue where you left off?")
            }

            Widgets.ButtonExt {
                id: continueBtn

                text: qsTr("Continue")

                AccessibleCompat.id: "resumeContinueButton"

                font.bold: true
                color: theme.accent
                focus: true
                onClicked: {
                    Player.restorePlaybackPos()
                    hideResumePanel()
                }

                Navigation.parentItem: resumePanel
                Navigation.rightItem: closeBtn
                Keys.priority: Keys.AfterItem
                Keys.onPressed: (event) =>  continueBtn.Navigation.defaultKeyAction(event)
            }

            Widgets.ButtonExt {
                id: closeBtn

                text: qsTr("Dismiss")

                AccessibleCompat.id: "resumeDismissButton"

                color: theme.fg.primary
                onClicked: hideResumePanel()

                Navigation.parentItem: resumePanel
                Navigation.leftItem: continueBtn
                Keys.priority: Keys.AfterItem
                Keys.onPressed: (event) => closeBtn.Navigation.defaultKeyAction(event)
            }
        }
    }
}
