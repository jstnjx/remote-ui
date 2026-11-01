// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import QtQuick.Controls 2.15
import Entity.Controller 1.0
import Entity.MediaPlayer 1.0
import "qrc:/components" as Components
import "qrc:/components/entities/media_player" as MediaPlayerComponents

// Text Button syntax: ACTIVITY_LAUNCHER;id, ACTIVITY_SWITCHER,
// KEYBOARD_SHORTCUT;media-player-id, APP_LAUNCHER;select-or-player-id.
// The optional entity ID opens a picker when absent.
Rectangle {
    id: widget
    width: 120
    height: 90
    radius: ui.cornerRadiusSmall
    color: colors.dark
    border { color: colors.medium; width: 1 }
    clip: true

    property string widgetType: ""
    property string targetEntityId: ""
    property string fallbackMediaPlayerId: ""
    property var launchActivity: function(entityId) {}
    property var openKeyboard: function(entityId) {}
    property var listAction: function(value) {}
    property var browsingEntity: null
    readonly property bool activityWidget: widgetType === "ACTIVITY_LAUNCHER" ||
                                           widgetType === "ACTIVITY_SWITCHER"
    readonly property bool keyboardWidget: widgetType === "KEYBOARD_SHORTCUT" ||
                                           widgetType === "KEYBOARD"
    readonly property string title: activityWidget ? qsTr("Activities") :
                                    keyboardWidget ? qsTr("Keyboard") : qsTr("Apps / Games")
    readonly property string iconName: activityWidget ? "uc:tv" :
                                       keyboardWidget ? "uc:keyboard" : "uc:grid-2"

    function showList(title, items, callback) {
        pickerModel.clear();
        for (let i = 0; i < items.length; ++i) {
            pickerModel.append({name: items[i].name, value: items[i].value});
        }
        listAction = callback;
        picker.title = title;
        picker.state = "visible";
    }

    function chooseActivity() {
        const ids = EntityController.getIdsByType("activity");
        const options = [];
        for (let i = 0; i < ids.length; ++i) {
            const entity = EntityController.get(ids[i]);
            if (entity) options.push({name: entity.name, value: entity.id});
        }
        showList(qsTr("Choose activity"), options, function(id) { widget.launchActivity(id); });
    }

    function chooseKeyboardTarget() {
        const ids = EntityController.getIdsByType("media_player");
        const options = [];
        for (let i = 0; i < ids.length; ++i) {
            const entity = EntityController.get(ids[i]);
            if (entity) options.push({name: entity.name, value: entity.id});
        }
        showList(qsTr("Keyboard target"), options, function(id) { widget.openKeyboard(id); });
    }

    function openAppTarget(id) {
        const entity = EntityController.get(id);
        if (!entity) {
            if (id) EntityController.load(id);
            return;
        }
        if (entity.getTypeAsString() === "select") {
            const options = [];
            const values = entity.options;
            for (let i = 0; i < values.length; ++i) {
                options.push({name: values[i], value: values[i]});
            }
            showList(qsTr("Launch app / game"), options,
                     function(value) { entity.selectOption(value); });
            return;
        }
        if (entity.getTypeAsString() === "media_player") {
            const canBrowse = entity.hasFeature(MediaPlayerFeatures.Browse_media) ||
                              entity.hasFeature(MediaPlayerFeatures.Search_media);
            if (canBrowse) {
                browsingEntity = entity;
                mediaBrowser.open();
            } else {
                showList(qsTr("App / game launcher"),
                         [{name: qsTr("This player does not support media browsing"), value: ""}],
                         function() {});
            }
        }
    }

    function chooseAppTarget() {
        const ids = EntityController.getIdsByType("select")
                        .concat(EntityController.getIdsByType("media_player"));
        const options = [];
        for (let i = 0; i < ids.length; ++i) {
            const entity = EntityController.get(ids[i]);
            if (entity) options.push({name: entity.name, value: entity.id});
        }
        showList(qsTr("App / game source"), options,
                 function(value) {
                     // Close the chooser before opening the second popup. This
                     // prevents the first popup's exit transition swallowing it.
                     widget.targetEntityId = value;
                     deferredAppOpen.entityId = value;
                     deferredAppOpen.restart();
                 });
    }

    function activate() {
        if (activityWidget) {
            if (targetEntityId && widgetType === "ACTIVITY_LAUNCHER") {
                launchActivity(targetEntityId);
            } else {
                chooseActivity();
            }
        } else if (keyboardWidget) {
            const target = targetEntityId || fallbackMediaPlayerId;
            if (target) openKeyboard(target);
            else chooseKeyboardTarget();
        } else {
            if (targetEntityId) openAppTarget(targetEntityId);
            else chooseAppTarget();
        }
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 16
        spacing: 4

        Components.Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            icon: widget.iconName
            size: Math.min(54, widget.height * 0.5)
            color: colors.offwhite
        }
        Text {
            width: parent.width
            text: widget.title
            color: colors.offwhite
            font: fonts.primaryFont(Math.min(22, widget.height * 0.18))
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.WordWrap
        }
    }

    Components.HapticMouseArea {
        anchors.fill: parent
        onClicked: widget.activate()
    }

    Timer {
        id: deferredAppOpen
        interval: 380
        repeat: false
        property string entityId: ""
        onTriggered: widget.openAppTarget(entityId)
    }

    ListModel { id: pickerModel }

    Components.PopupList {
        id: picker
        parent: Overlay.overlay
        listModel: pickerModel
        showSearch: pickerModel.count > 8
        onItemSelected: widget.listAction(value)
        onDone: widget.listAction = function(value) {}
    }

    MediaPlayerComponents.MediaBrowser {
        id: mediaBrowser
        parent: Overlay.overlay
        entityObj: widget.browsingEntity
    }
}
