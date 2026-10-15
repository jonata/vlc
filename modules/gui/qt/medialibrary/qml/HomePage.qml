/******************************************************************************
 * Copyright (C) 2024 VLC authors and VideoLAN
 *
 * Author: Ash <ashutoshv191@gmail.com>
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
 ******************************************************************************/
import QtQuick
import QtQuick.Window
import QtQuick.Templates as T

import VLC.MediaLibrary

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Style

Widgets.PageExt {
    id: root

    property var pagePrefix: [] // behave like a Page

    property var sortModel: [
        { text: qsTr("Alphabetic"), criteria: "title" },
        { text: qsTr("Duration"), criteria: "duration" }
    ]

    title: qsTr("Home")

    hasGridListMode: true

    isSearchable: true

    property real listCoverHeight: VLCStyle.listAlbumCover_height
    property real listCoverWidth: VLCStyle.listAlbumCover_width
    property real listCoverRadius: VLCStyle.listAlbumCover_radius

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    signal seeAllButtonClicked(string name, int reason)

    function positionContentAtBeginning() {
        contentYBehavior.enabled = true
        flickable.contentY = -flickable.originY
        contentYBehavior.enabled = false
    }

    function setCurrentItemFocus(reason) {
        // `focus` is checked, because that indicates the item that has the focus within the focus scope
        if (continueWatchingRow.focus)
            continueWatchingRow.setCurrentItemFocus(reason)
        else if (favoritesRow.focus)
            favoritesRow.setCurrentItemFocus(reason)
        else if (newVideoRow.focus)
            newVideoRow.setCurrentItemFocus(reason)
        else if (newMusicRow.focus)
            newMusicRow.setCurrentItemFocus(reason)
        else
            coneNButtons.forceActiveFocus(reason)
    }

    contentItem: Flickable {
        id: flickable

        implicitWidth: Math.max(coneNButtons.implicitWidth, mediaRows.implicitWidth)
        implicitHeight: coneNButtons.implicitHeight + (_hasMedias ? mediaRows.implicitHeight : 0)

        contentWidth: width
        contentHeight: _hasMedias ? coneNButtons.implicitHeight + mediaRows.implicitHeight
                                  : height - topMargin - bottomMargin

        flickableDirection: Flickable.AutoFlickIfNeeded

        boundsBehavior: Flickable.StopAtBounds

        // FIXME: make the media rows positioners consider the flickable margins when adjusting flickable `contentY`.
        bottomMargin: VLCStyle.margin_large

        pixelAligned: (MainCtx.qtVersion() >= MainCtx.qtVersionCheck(6, 2, 5)) // QTBUG-103996
                      && (Screen.pixelDensity >= VLCStyle.highPixelDensityThreshold) // no need for sub-pixel alignment with high pixel density

        property bool _hasMedias: true

        Binding on _hasMedias {
            when: !continueWatchingRow.model.loading && !favoritesRow.model.loading
                  && !newVideoRow.model.loading && !newMusicRow.model.loading
            value: continueWatchingRow.visible || favoritesRow.visible
                   || newVideoRow.visible || newMusicRow.visible
            restoreMode: Binding.RestoreNone
        }

        T.ScrollBar.vertical: Widgets.ScrollBarExt {}

        // This behavior allows to have similar "smooth" animation
        // that Qt views have with `highlightFollowsCurrentItem`.
        Behavior on contentY {
            id: contentYBehavior

            enabled: false

            // NOTE: Usage of `SmoothedAnimation` is intentional here.
            SmoothedAnimation {
                duration: VLCStyle.duration_veryLong
                easing.type: Easing.InOutSine
            }
        }

        property Component implicitFlickableScrollHandler: DefaultFlickableScrollHandler { }

        // NOTE: This property can be set to null to prevent using a scroll handler:
        property FlickableScrollHandler scrollHandler: {
            if (interactive) {
                // JS ownership:
                return implicitFlickableScrollHandler.createObject(null, { target: flickable })
            } else {
                return null
            }
        }

        Component.onCompleted: {
            if (!usingTouch) {
                // Flickable filters child mouse events for flicking (even when
                // the delegate is grabbed). However, this is not a useful
                // feature for non-touch cases, so disable it here and enable
                // it if touch is detected through the hover handler:
                MainCtx.setFiltersChildMouseEvents(flickable, false)
            }
        }

        readonly property bool usingTouch: MainCtx.usingTouch

        onUsingTouchChanged: {
            if (usingTouch)
                MainCtx.setFiltersChildMouseEvents(flickable, true)
            // We do not disable filtering child mouse events
            // because Qt currently has a bug that the flickable
            // jumps when it is enabled again later on.
        }

        NoMedialibHome.ConeNButtons {
            id: coneNButtons

            focus: true

            orientation: flickable._hasMedias ? Qt.Horizontal : Qt.Vertical

            anchors.centerIn: flickable._hasMedias ? undefined : parent
            anchors.top: flickable._hasMedias ? parent.top : undefined
            anchors.left: flickable._hasMedias ? parent.left : undefined
            anchors.leftMargin: flickable._hasMedias ? newVideoRow.contentLeftMargin : 0

            Navigation.parentItem: root
            Navigation.upItem: root.header
            Navigation.downItem: mediaRows

            onActiveFocusChanged: {
                contentYBehavior.enabled = true
                Helpers.positionFlickableToContainItem(flickable, this)
                contentYBehavior.enabled = false
            }
        }

        Widgets.NavigableCol {
            id: mediaRows

            anchors.top: coneNButtons.bottom
            anchors.left: parent.left
            anchors.right: parent.right

            spacing: 0 // NOTE: We depend on the top padding of view header currently.

            Navigation.parentItem: root
            Navigation.upItem: coneNButtons

            Widgets.ViewHeader {
                visible: continueWatchingRow.visible
                text: qsTr("Continue Watching")
                view: continueWatchingRow
                seeAllButton.visible: continueWatchingRow.model.maximumCount > continueWatchingRow.model.count

                onSeeAllButtonClicked: function (reason) {
                    root.seeAllButtonClicked("continueWatching", reason)
                }
            }

            VideoAll {
                id: continueWatchingRow

                AccessibleCompat.id: "continueWatching"

                anchors.left: parent.left
                anchors.right: parent.right

                height: currentItem?.contentHeight ?? implicitHeight

                visible: model.count !== 0

                headerPositioning: ListView.InlineHeader
                enableBeginningFade: false
                enableEndFade: false
                sectionProperty: ""

                interactive: false

                emptyLabel: null

                // FIXME: `ExpandGridView` causes extreme performance degradation when `reuseItems`
                //        is true and items provided by the model change (#29084).
                reuseItems: !MainCtx.gridView

                listCoverWidth: root.listCoverWidth
                listCoverHeight: root.listCoverHeight
                listCoverRadius: root.listCoverRadius

                Navigation.parentItem: mediaRows

                model: MLRecentVideoModel {
                    ml: MediaLib

                    sortCriteria: root.sort.criteria
                    sortOrder: root.sort.order
                    searchPattern: root.search.pattern

                    // FIXME: Make limit 0 load no items, instead of loading all items.
                    limit: MainCtx.gridView ? Math.max(continueWatchingRow.currentItem?.nbItemPerRow ?? null, 1) : 5
                }

                contextMenu: MLContextMenu {
                    model: continueWatchingRow.model

                    showPlayAsAudioAction: true
                }

                onActiveFocusChanged: {
                    if (activeFocus) {
                        const item = currentItem?.currentItem ?? currentItem?._getItem(currentIndex) // FIXME: `ExpandGridView` does not have `currentItem`.
                        contentYBehavior.enabled = true
                        Helpers.positionFlickableToContainItem(flickable, item ?? this)
                        contentYBehavior.enabled = false
                    }
                }

                onCurrentIndexChanged: {
                    if (activeFocus) {
                        const item = currentItem?.currentItem ?? currentItem?._getItem(currentIndex) // FIXME: `ExpandGridView` does not have `currentItem`.
                        if (item) {
                            contentYBehavior.enabled = true
                            Helpers.positionFlickableToContainItem(flickable, item)
                            contentYBehavior.enabled = false
                        }
                    }
                }
            }

            Widgets.ViewHeader {
                visible: playlistsRow.visible
                text: qsTr("Playlists")
                view: newVideoRow
                seeAllButton.visible: playlistsRow.count > 0

                onSeeAllButtonClicked: function (reason) {
                    History.push(["playlists"], reason)
                }
            }

            // the playlists of the user, as cards
            ListView {
                id: playlistsRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: newVideoRow.contentLeftMargin

                height: VLCStyle.dp(160, VLCStyle.scale)
                visible: count > 0

                orientation: ListView.Horizontal
                spacing: VLCStyle.margin_normal
                clip: true
                interactive: contentWidth > width

                model: MLPlaylistListModel {
                    ml: MediaLib
                    playlistType: MLPlaylistListModel.PLAYLIST_TYPE_ALL
                    limit: 12

                    coverDefault: VLCStyle.noArtAlbumCover
                }

                delegate: HomeCard {
                    required property var model

                    title: model.name ?? ""
                    subtitle: qsTr("%1 items").arg(model.count ?? 0)
                    image: model.thumbnail ?? ""
                    iconText: VLCIcons.playlist

                    onClicked: History.push(["playlists", "list"], { parentId: model.id, title: model.name })
                }
            }

            Widgets.ViewHeader {
                visible: streamsRow.visible
                text: qsTr("Network Streams")
                view: newVideoRow
                seeAllButton.visible: streamsRow.count > 0

                onSeeAllButtonClicked: function (reason) {
                    History.push(["streams"], reason)
                }
            }

            // the saved streams, then the ones played recently
            Flickable {
                id: streamsRow

                property var savedStreams: []

                readonly property int count: savedRepeater.count + recentRepeater.count

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: newVideoRow.contentLeftMargin

                height: VLCStyle.dp(160, VLCStyle.scale)
                visible: count > 0

                clip: true
                contentWidth: streamsContent.width
                flickableDirection: Flickable.HorizontalFlick
                interactive: contentWidth > width

                Component.onCompleted: {
                    try {
                        savedStreams = JSON.parse(MainCtx.settingValue("NetworkStreams/saved", "[]"))
                    } catch (e) {
                        savedStreams = []
                    }
                }

                Row {
                    id: streamsContent

                    height: parent.height
                    spacing: VLCStyle.margin_normal

                    Repeater {
                        id: savedRepeater

                        model: streamsRow.savedStreams

                        delegate: HomeCard {
                            required property var modelData

                            title: modelData.name || modelData.url
                            subtitle: qsTr("Saved stream")
                            iconText: VLCIcons.tv

                            onClicked: recentStreams.addAndPlay(modelData.url)
                        }
                    }

                    Repeater {
                        id: recentRepeater

                        model: MLUrlModel {
                            id: recentStreams
                            ml: MediaLib
                            limit: 12
                        }

                        delegate: HomeCard {
                            required property var model

                            // the saved streams are already shown
                            visible: !streamsRow.savedStreams.some(stream => stream.url === model.url)
                            width: visible ? implicitWidth : 0

                            title: model.url ?? ""
                            subtitle: qsTr("Played recently")
                            iconText: VLCIcons.tv

                            onClicked: recentStreams.addAndPlay(model.url)
                        }
                    }
                }
            }

            Widgets.ViewHeader {
                visible: favoritesRow.visible
                text: qsTr("Favorites")
                view: favoritesRow
                seeAllButton.visible: favoritesRow.model.maximumCount > favoritesRow.model.count

                onSeeAllButtonClicked: function (reason) {
                    root.seeAllButtonClicked("favorites", reason)
                }
            }

            MediaView {
                id: favoritesRow

                AccessibleCompat.id: "favourites"

                anchors.left: parent.left
                anchors.right: parent.right

                height: currentItem?.contentHeight ?? implicitHeight

                visible: model.count !== 0

                listHeaderPositioning: ListView.InlineHeader
                enableBeginningFade: false
                enableEndFade: false
                listSectionProperty: ""

                interactive: false

                emptyLabel: null

                // FIXME: `ExpandGridView` causes extreme performance degradation when `reuseItems`
                //        is true and items provided by the model change (#29084).
                reuseItems: !MainCtx.gridView

                listCoverWidth: root.listCoverWidth
                listCoverHeight: root.listCoverHeight
                listCoverRadius: root.listCoverRadius

                Navigation.parentItem: mediaRows

                model: MLMediaModel {
                    favoriteOnly: true

                    ml: MediaLib

                    sortCriteria: root.sort.criteria || "insertion"
                    sortOrder: root.sort.order
                    searchPattern: root.search.pattern

                    // FIXME: Make limit 0 load no items, instead of loading all items.
                    limit: MainCtx.gridView ? Math.max(favoritesRow.currentItem?.nbItemPerRow ?? null, 1) : 5
                }

                onActiveFocusChanged: {
                    if (activeFocus) {
                        const item = currentItem?.currentItem ?? currentItem?._getItem(currentIndex) // FIXME: `ExpandGridView` does not have `currentItem`.
                        contentYBehavior.enabled = true
                        Helpers.positionFlickableToContainItem(flickable, item ?? this)
                        contentYBehavior.enabled = false
                    }
                }

                onCurrentIndexChanged: {
                    if (activeFocus) {
                        const item = currentItem?.currentItem ?? currentItem?._getItem(currentIndex) // FIXME: `ExpandGridView` does not have `currentItem`.
                        if (item) {
                            contentYBehavior.enabled = true
                            Helpers.positionFlickableToContainItem(flickable, item)
                            contentYBehavior.enabled = true
                        }
                    }
                }
            }

            Widgets.ViewHeader {
                text: qsTr("New Videos")
                visible: newVideoRow.visible
                view: newVideoRow
                seeAllButton.visible: newVideoRow.model.maximumCount > newVideoRow.model.count

                onSeeAllButtonClicked: function (reason) {
                    root.seeAllButtonClicked("newVideo", reason)
                }
            }

            VideoAll {
                id: newVideoRow

                AccessibleCompat.id: "newVideo"

                anchors.left: parent.left
                anchors.right: parent.right

                height: currentItem?.contentHeight ?? implicitHeight

                visible: model.count !== 0

                headerPositioning: ListView.InlineHeader
                enableBeginningFade: false
                enableEndFade: false
                sectionProperty: ""

                interactive: false

                emptyLabel: null

                // FIXME: `ExpandGridView` causes extreme performance degradation when `reuseItems`
                //        is true and items provided by the model change (#29084).
                reuseItems: !MainCtx.gridView

                listCoverWidth: root.listCoverWidth
                listCoverHeight: root.listCoverHeight
                listCoverRadius: root.listCoverRadius

                Navigation.parentItem: mediaRows

                model: MLVideoModel {
                    ml: MediaLib

                    sortCriteria: root.sort.criteria || "insertion"
                    sortOrder: root.sort.order
                    searchPattern: root.search.pattern

                    // FIXME: Make limit 0 load no items, instead of loading all items.
                    limit: MainCtx.gridView ? Math.max(newVideoRow.currentItem?.nbItemPerRow ?? null, 1) : 5
                }

                contextMenu: MLContextMenu {
                    model: newVideoRow.model

                    showPlayAsAudioAction: true
                }

                onActiveFocusChanged: {
                    if (activeFocus) {
                        const item = currentItem?.currentItem ?? currentItem?._getItem(currentIndex) // FIXME: `ExpandGridView` does not have `currentItem`.
                        contentYBehavior.enabled = true
                        Helpers.positionFlickableToContainItem(flickable, item ?? this)
                        contentYBehavior.enabled = false
                    }
                }

                onCurrentIndexChanged: {
                    if (activeFocus) {
                        const item = currentItem?.currentItem ?? currentItem?._getItem(currentIndex) // FIXME: `ExpandGridView` does not have `currentItem`.
                        if (item) {
                            contentYBehavior.enabled = true
                            Helpers.positionFlickableToContainItem(flickable, item)
                            contentYBehavior.enabled = false
                        }
                    }
                }
            }

            Widgets.ViewHeader {
                text: qsTr("New Music")
                visible: newMusicRow.visible
                view: newMusicRow
                seeAllButton.visible: newMusicRow.model.maximumCount > newMusicRow.model.count

                onSeeAllButtonClicked: function (reason) {
                    root.seeAllButtonClicked("newMusic", reason)
                }
            }

            MediaView {
                id: newMusicRow

                AccessibleCompat.id: "newMusic"

                anchors.left: parent.left
                anchors.right: parent.right

                height: currentItem?.contentHeight ?? implicitHeight

                visible: model.count !== 0

                listHeaderPositioning: ListView.InlineHeader
                enableBeginningFade: false
                enableEndFade: false
                listSectionProperty: ""

                interactive: false

                emptyLabel: null

                // FIXME: `ExpandGridView` causes extreme performance degradation when `reuseItems`
                //        is true and items provided by the model change (#29084).
                reuseItems: !MainCtx.gridView

                listCoverWidth: root.listCoverWidth
                listCoverHeight: root.listCoverHeight
                listCoverRadius: root.listCoverRadius

                Navigation.parentItem: mediaRows

                model: MLAudioModel {
                    ml: MediaLib

                    sortCriteria: root.sort.criteria || "insertion"
                    sortOrder: root.sort.order
                    searchPattern: root.search.pattern

                    // FIXME: Make limit 0 load no items, instead of loading all items.
                    limit: MainCtx.gridView ? Math.max(newMusicRow.currentItem?.nbItemPerRow ?? null, 1) : 5
                }

                onActiveFocusChanged: {
                    if (activeFocus) {
                        const item = currentItem?.currentItem ?? currentItem?._getItem(currentIndex) // FIXME: `ExpandGridView` does not have `currentItem`.
                        contentYBehavior.enabled = true
                        Helpers.positionFlickableToContainItem(flickable, item ?? this)
                        contentYBehavior.enabled = false
                    }
                }

                onCurrentIndexChanged: {
                    if (activeFocus) {
                        const item = currentItem?.currentItem ?? currentItem?._getItem(currentIndex) // FIXME: `ExpandGridView` does not have `currentItem`.
                        if (item) {
                            contentYBehavior.enabled = true
                            Helpers.positionFlickableToContainItem(flickable, item)
                            contentYBehavior.enabled = false
                        }
                    }
                }
            }
        }
    }

    // card of a playlist or of a stream on the home page
    component HomeCard: T.ItemDelegate {
        id: card

        readonly property ColorContext colorContext: ColorContext {
            id: homeTheme
            colorSet: ColorContext.View
        }

        property string title
        property string subtitle
        property url image
        property string iconText

        implicitWidth: VLCStyle.dp(200, VLCStyle.scale)
        width: implicitWidth
        height: VLCStyle.dp(160, VLCStyle.scale)

        padding: 0

        background: null

        contentItem: Column {
            spacing: VLCStyle.margin_xsmall

            Rectangle {
                width: card.width
                height: VLCStyle.dp(112, VLCStyle.scale)

                radius: VLCStyle.dp(6, VLCStyle.scale)
                color: card.hovered ? Qt.lighter(homeTheme.bg.secondary, 1.2) : homeTheme.bg.secondary
                clip: true

                Widgets.ImageExt {
                    anchors.fill: parent
                    visible: card.image.toString() !== ""
                    source: card.image
                    fillMode: Image.PreserveAspectCrop
                    radius: VLCStyle.dp(6, VLCStyle.scale)
                }

                Widgets.IconLabel {
                    anchors.centerIn: parent
                    visible: card.image.toString() === ""
                    text: card.iconText
                    font.pixelSize: VLCStyle.icon_large
                    color: homeTheme.accent
                }
            }

            T.Label {
                width: card.width
                text: card.title
                elide: Text.ElideRight
                color: homeTheme.fg.primary
                font.pixelSize: VLCStyle.fontSize_normal
                font.weight: Font.DemiBold
            }

            T.Label {
                width: card.width
                text: card.subtitle
                elide: Text.ElideRight
                color: homeTheme.fg.secondary
                font.pixelSize: VLCStyle.fontSize_small
            }
        }
    }
}
