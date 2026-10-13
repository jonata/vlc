/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
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
import QtQuick.Window


import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.PlayerControls
import VLC.Playlist
import VLC.Widgets as Widgets
import VLC.Menus as Menus
import VLC.Util

FocusScope{
    id: root

    // Properties

    required property int textWidth

    // For now, used for d&d functionality
    // Not strictly necessary to set
    property Item plListView

    property int reservedHeight: 0

    property int topMargin: 0
    property int sideMargin: 0

    property string title

    // shown in the breadcrumb when not empty, instead of the library section
    property string folderName

    property bool showCSD: false
    property bool showToolbar: false
    property bool pinControls: false

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    // Private

    property bool _showTopBar: (pinControls === false || showToolbar === false)

    property bool _showCenterText: (pinControls && showToolbar === false)

    // single line layout: logo, menu and breadcrumb on the left, centered title
    readonly property bool _compact: _showCenterText

    readonly property string _sectionName: {
        switch (History.viewPath[1]) {
        case "home": return qsTr("Home")
        case "video": return qsTr("Video")
        case "music": return qsTr("Music")
        case "network": return qsTr("Browse")
        case "discover": return qsTr("Discover")
        default: return qsTr("Library")
        }
    }

    readonly property string _sectionIcon: {
        switch (History.viewPath[1]) {
        case "home": return VLCIcons.home
        case "video": return VLCIcons.topbar_video
        case "music": return VLCIcons.topbar_music
        case "network": return VLCIcons.topbar_network
        case "discover": return VLCIcons.topbar_discover
        default: return VLCIcons.back
        }
    }

    readonly property int _sideMargin: VLCStyle.margin_small + sideMargin

    // Aliases

    property alias resumeVisible: resumeDialog.visible

    property alias playlistVisible: playlistButton.checked

    // Signals

    signal togglePlaylistVisibility()
    signal requestLockUnlockAutoHide(bool lock)
    signal backRequested()

    ///incomming signal to request all menu and popup to close
    signal forceUnlock()

    // Settings

    Accessible.role: Accessible.ToolBar
    Accessible.name: qsTr("Player topbar")
    AccessibleCompat.id: "playerTopBar"

    // Events

    Component.onCompleted: _layout()

    onShowCSDChanged: _layout()
    onPinControlsChanged: _layout()
    onShowToolbarChanged: _layout()
    onTopMarginChanged: _layout()
    onSideMarginChanged: _layout()

    on_ShowTopBarChanged: _layout()
    on_ShowCenterTextChanged: _layout()

    // Functions

    // FIXME: Imperative layouting in QML is stupid, this needs to be gone.
    function _layoutLine(c1, c2, offset)
    {
        let c1Height = c1?.implicitHeight ?? 0
        let c2Height = c2?.implicitHeight ?? 0

        if (c2 === csdDecorations) {
            //csdDecorations.implicitHeight gets overwritten when the height is set,
            //VLCStyle.icon_normal is its initial value
            c2Height = VLCStyle.icon_normal
        }

        const lineHeight = Math.max(c1Height, c2Height)

        if (c1) {
            c1.height = lineHeight
            c1.anchors.topMargin = offset
        }

        if (c2) {
            c2.height = lineHeight
            c2.anchors.topMargin = offset
        }
        return lineHeight
    }

    // FIXME: Imperative layouting in QML is stupid, this needs to be gone.
    //FIXME: if CSD will be weirdly placed if application safe-area are used,
    //nota that if you need a safe area (kiosk mode), you probably don't need CSD
    function _layout() {
        let offset = topMargin

        if (_showCenterText) {
            //place everything on one line
            //csdDecorations.implicitHeight gets overwritten when the height is set,
            //VLCStyle.icon_normal is its initial value
            const lineHeight = Math.max(logoOrResume.implicitHeight, playlistGroup.implicitHeight, VLCStyle.icon_normal)

            centerTitleText.y = 0
            centerTitleText.height = lineHeight

            csdDecorations.height  = lineHeight

            logoOrResume.height =  lineHeight

            playlistGroup.height = lineHeight
            playlistGroup.anchors.topMargin = 0
            playlistGroup.extraRightMargin = Qt.binding(function() { return width - csdDecorations.x })


            implicitHeight = lineHeight
            offset += lineHeight

        } else {
            playlistGroup.extraRightMargin = 0

            let left = undefined
            let right = undefined
            let logoPlaced = false

            if (showToolbar) {
                left = menubar
            }

            if (showCSD) {
                right = csdDecorations
                if (!left) {
                    left = logoOrResume
                    logoPlaced = true
                }
            }

            if (!!left || !!right) {
                offset += _layoutLine(left, right, offset)

                if (showCSD) {
                    tapNDrag.height = offset
                }
            }

            if (!logoPlaced) {
                left = logoOrResume
            } else {
                left = undefined
            }

            if (_showTopBar)
                right = playlistGroup
            else
                right = undefined

            offset += _layoutLine(left, right, offset)
        }

        implicitHeight = offset
        reservedHeight = offset
    }

    // Children

    //drag and dbl click the titlebar in CSD mode
    Loader {
        id: tapNDrag

        anchors.fill: parent
        active: root.showCSD
        source: "qrc:///qt/qml/VLC/Widgets/CSDTitlebarTapNDrapHandler.qml"

        Connections {
            target: tapNDrag.item
            enabled: tapNDrag.status === Loader.Ready
            function onCsdMenuVisibleChanged() {
                root.requestLockUnlockAutoHide(tapNDrag.item.csdMenuVisible)
            }
        }
    }

    // Components -
    Menus.Menubar {
        id: menubar

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.leftMargin: root.sideMargin
        anchors.right: root.showCSD ? csdDecorations.left : parent.right


        visible: root.showToolbar
        enabled: root.showToolbar

        onHoveredChanged: menu => root.requestLockUnlockAutoHide(hovered)
        onMenuOpenedChanged: menu => root.requestLockUnlockAutoHide(menuOpened)
        onImplicitHeightChanged: root._layout()
    }

    Item {
        id: logoOrResume

        anchors.left: root.left
        anchors.top: root.top
        anchors.leftMargin:  root._sideMargin

        implicitWidth: resumeVisible ? resumeDialog.implicitWidth
                                     : logoGroup.implicitWidth

        implicitHeight: {
            if (root.resumeVisible) {
                // Only if there are multiple lines use `resumeDialog`'s implicit height, otherwise the video
                // window may get resized by few pixels unnecessarily when `resumeDialog` is no longer visible.
                if (resumeDialog.implicitHeight >= (logoGroup.implicitHeight + resumeDialog.baselineOffset))
                    return resumeDialog.implicitHeight
                else
                    return logoGroup.implicitHeight
            } else if (_showTopBar)
                return logoGroup.implicitHeight
            else
                return 0
        }

        onImplicitHeightChanged: root._layout()

        Item {
            id: logoGroup

            anchors.fill: parent

            visible: (root._showTopBar && root.resumeVisible === false)

            implicitHeight: root._compact ? VLCStyle.playerTopBar_height
                                          : VLCStyle.icon_banner + VLCStyle.margin_xxsmall * 2
            implicitWidth: root._compact ? (breadcrumb.x + breadcrumb.implicitWidth)
                                         : (backBtn.implicitWidth + logo.implicitWidth + VLCStyle.margin_xxsmall)

            Widgets.IconToolButton {
                id: backBtn

                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left

                visible: !root._compact
                enabled: visible

                objectName: "IconToolButton"
                font.pixelSize: VLCStyle.icon_banner
                text: VLCIcons.back
                description: qsTr("Back")

                AccessibleCompat.id: "topBarBackButton"

                focus: true

                Navigation.parentItem: root
                Navigation.rightItem: menuSelector
                onClicked: root.backRequested()

                onHoveredChanged: root.requestLockUnlockAutoHide(hovered)
            }

            Widgets.BannerCone {
                id: logo

                anchors.verticalCenter: parent.verticalCenter
                anchors.left: root._compact ? parent.left : backBtn.right
                anchors.leftMargin: root._compact ? VLCStyle.margin_xsmall : VLCStyle.margin_xxsmall

                color: theme.accent
            }

            Widgets.IconToolButton {
                id: compactMenuBtn

                anchors.verticalCenter: parent.verticalCenter
                anchors.left: logo.right
                anchors.leftMargin: VLCStyle.margin_xsmall

                visible: root._compact
                enabled: visible

                font.pixelSize: VLCStyle.icon_normal
                text: VLCIcons.more
                description: qsTr("Menu")

                AccessibleCompat.id: "topBarCompactMenuButton"

                checked: compactContextMenu.shown

                Navigation.parentItem: root
                Navigation.rightItem: breadcrumb

                onClicked: compactContextMenu.popup(this.mapToGlobal(0, height))

                onHoveredChanged: root.requestLockUnlockAutoHide(hovered)

                Menus.QmlGlobalMenu {
                    id: compactContextMenu

                    ctx: MainCtx

                    onAboutToShow: root.requestLockUnlockAutoHide(true)
                    onAboutToHide: root.requestLockUnlockAutoHide(false)
                }

                Connections {
                    target: root

                    function onForceUnlock() {
                        compactContextMenu.close()
                    }
                }
            }

            Rectangle {
                id: compactSeparator

                anchors.verticalCenter: parent.verticalCenter
                anchors.left: compactMenuBtn.right
                anchors.leftMargin: VLCStyle.margin_xsmall

                visible: root._compact

                width: VLCStyle.border
                height: VLCStyle.playerTopBar_separatorHeight

                color: theme.separator
            }

            // takes back to the library section the player was opened from
            Widgets.ButtonExt {
                id: breadcrumb

                anchors.verticalCenter: parent.verticalCenter
                anchors.left: compactSeparator.right
                anchors.leftMargin: VLCStyle.margin_xsmall

                visible: root._compact
                enabled: visible

                iconTxt: (root.folderName !== "") ? VLCIcons.folder : root._sectionIcon
                text: (root.folderName !== "") ? root.folderName : root._sectionName

                Accessible.name: qsTr("Back to the library")

                AccessibleCompat.id: "topBarBreadcrumbButton"

                Navigation.parentItem: root
                Navigation.leftItem: compactMenuBtn
                Navigation.rightItem: playlistGroup

                onClicked: root.backRequested()

                onHoveredChanged: root.requestLockUnlockAutoHide(hovered)
            }
        }

        ResumeDialog {
            id: resumeDialog

            anchors.fill: parent
            //add aditional margin so it align with menubar text when visible (see MenuBar.qml)
            anchors.leftMargin: VLCStyle.margin_xsmall

            maxWidth: ((root.showCSD && !root.pinControls) ? csdDecorations : playlistGroup).x
                - VLCStyle.applicationHorizontalMargin
                - VLCStyle.margin_large

            colorContext.palette: theme.palette

            Navigation.parentItem: rootPlayer

            onHidden: {
                if (activeFocus) {
                    backBtn.forceActiveFocus()
                }
            }

            onVisibleChanged: {
                root.requestLockUnlockAutoHide(visible)
            }
        }
    }

    //FIXME use the the right class
    T.Label {
        id: centerTitleText

        readonly property int _leftLimit: logoOrResume.x + logoOrResume.width
        readonly property int _rightLimit: playlistGroup.x
        readonly property int _availableWidth: _rightLimit - _leftLimit
        readonly property int _centerX: ((root.width - centerTitleText.implicitWidth) / 2)
        readonly property bool _alignHCenter: _centerX > _leftLimit
                                              && _centerX + centerTitleText.implicitWidth < _rightLimit

        visible: (_showCenterText && root.resumeVisible === false)

        enabled: visible

        width: Math.min(centerTitleText._availableWidth, centerTitleText.implicitWidth)

        leftPadding: VLCStyle.margin_small
        rightPadding: VLCStyle.margin_small

        text: root.title
        color: theme.fg.primary
        font.pixelSize: VLCStyle.fontSize_normal
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter

        on_AlignHCenterChanged: _layout()
        Component.onCompleted: _layout()

        function _layout() {
            if (_alignHCenter) {
                centerTitleText.x = 0
                centerTitleText.anchors.horizontalCenter = root.horizontalCenter
            } else {
                centerTitleText.anchors.horizontalCenter = undefined
                centerTitleText.x = Qt.binding(function() { return centerTitleText._leftLimit })
            }
        }
    }

    //FIXME use the the right class
    T.Label {
        id: leftTitleText

        anchors.left: parent.left
        anchors.top: logoOrResume.bottom
        anchors.leftMargin: root._sideMargin

        width: root.textWidth - VLCStyle.margin_normal

        visible: !root.pinControls

        enabled: visible

        topPadding: VLCStyle.margin_large
        leftPadding: logo.x

        text: root.title
        horizontalAlignment: Text.AlignLeft
        color: theme.fg.primary
        font.weight: Font.DemiBold
        font.pixelSize: VLCStyle.dp(18, VLCStyle.scale)
        elide: Text.ElideRight
    }

    Loader {
        id: csdDecorations

        anchors.top: parent.top
        anchors.right: parent.right

        focus: false
        height: VLCStyle.icon_normal
        active: root.showCSD
        enabled: root.showCSD
        visible: root.showCSD
        source:  VLCStyle.palette.hasCSDImage
            ? "qrc:///qt/qml/VLC/Widgets/CSDThemeButtonSet.qml"
            : "qrc:///qt/qml/VLC/Widgets/CSDWindowButtonSet.qml"

        Connections {
            target: csdDecorations.item
            enabled: csdDecorations.status === Loader.Ready
            function onButtonHoveredChanged() { root.requestLockUnlockAutoHide(csdDecorations.item.buttonHovered) }
        }
    }

    Row {
        id: playlistGroup

        property int extraRightMargin: 0

        focus: true
        spacing: VLCStyle.margin_xxsmall

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: root._sideMargin + extraRightMargin

        visible: root._showTopBar

        Widgets.IconToolButton {
            id: compactFullscreenBtn

            anchors.verticalCenter: parent.verticalCenter

            visible: root._compact && Player.hasVideoOutput
            enabled: visible

            font.pixelSize: VLCStyle.icon_normal
            text: Player.fullscreen ? VLCIcons.defullscreen : VLCIcons.fullscreen
            description: qsTr("Fullscreen")

            AccessibleCompat.id: "topBarFullscreenButton"

            Navigation.parentItem: root
            Navigation.leftItem: breadcrumb

            onClicked: Player.fullscreen = !Player.fullscreen

            onHoveredChanged: root.requestLockUnlockAutoHide(hovered)
        }

        Widgets.IconToolButton {
            id: menuSelector

            anchors.verticalCenter: parent.verticalCenter
            visible: !root.showToolbar && !root._compact
            enabled: visible
            focus: visible
            font.pixelSize: VLCStyle.icon_banner

            width: VLCStyle.bannerButton_width
            height: VLCStyle.bannerButton_height

            text: VLCIcons.more
            description: qsTr("Menu")

            AccessibleCompat.id: "topBarMenuButton"

            checked: contextMenu.shown

            Navigation.parentItem: root
            Navigation.leftItem: backBtn
            Navigation.rightItem: playlistButton

            onClicked: contextMenu.popup(this.mapToGlobal(0, height))

            onHoveredChanged: root.requestLockUnlockAutoHide(hovered)

            Menus.QmlGlobalMenu {
                id: contextMenu

                ctx: MainCtx

                onAboutToShow: root.requestLockUnlockAutoHide(true)
                onAboutToHide: root.requestLockUnlockAutoHide(false)
            }

            Connections {
                target: root

                function onForceUnlock() {
                    contextMenu.close()
                }
            }
        }

        PlaylistPane.PlaylistToggleButton {
            id: playlistButton

            anchors.verticalCenter: parent.verticalCenter
            objectName: ControlListModel.PLAYLIST_BUTTON
            font.pixelSize: VLCStyle.icon_banner
            text: VLCIcons.playlist
            description: qsTr("Play Queue")

            AccessibleCompat.id: "topBarPlayqueueButton"

            // the play queue button is part of the control bar in the compact layout
            visible: !root._compact
            enabled: visible

            focus: root.showToolbar

            width: VLCStyle.bannerButton_width
            height: VLCStyle.bannerButton_height

            plListView: root.plListView
            
            Navigation.parentItem: root
            Navigation.leftItem: menuSelector.visible ? menuSelector : backBtn

            onClicked: togglePlaylistVisibility()

            Accessible.onToggleAction:togglePlaylistVisibility()

            onHoveredChanged: root.requestLockUnlockAutoHide(hovered)
        }
    }
}
