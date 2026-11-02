// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15
import Entity.Controller 1.0
import Entity.Light 1.0
import Entity.Climate 1.0
import Entity.Cover 1.0
import "qrc:/components" as Components

// Activity card for LIGHT, CLIMATE and COVER. Tapping opens the SAME native
// entity detail overlay as an entity tile (including its existing controls,
// mode menus, temperature tumbler and position/color sliders). No duplicated
// full-screen control logic or oversized sliders live inside the Activity grid.
Rectangle {
    id: card
    color: colors.dark
    radius: ui.cornerRadiusSmall
    clip: true

    property string entityKind: "LIGHT"
    property string entitySelector: ""
    property string commandEntityId: ""
    property var activityEntity: null
    property bool widgetActive: false
    property string entityId: ""
    property var entityObj: null
    property string selectionError: ""

    // Activity owns the third-container overlay and page-gesture lock.
    property var openEntityDetail: function(entity) {}
    property var beginPageGesture: function() {}
    property var endPageGesture: function() {}
    property bool gestureHeld: false

    readonly property string typeName: entityKind === "LIGHT" ? "light" :
                                       entityKind === "CLIMATE" ? "climate" : "cover"
    readonly property bool entityAvailable: entityObj && entityObj.enabled && (
        entityKind === "LIGHT" ? entityObj.state !== LightStates.Unavailable :
        entityKind === "CLIMATE" ? entityObj.state !== ClimateStates.Unavailable :
                                   entityObj.state !== CoverStates.Unavailable)
    readonly property bool ready: widgetActive && entityAvailable &&
                                  EntityController.mayCommandEntity(entityObj.enabled)

    function resolveTarget() {
        const known = EntityController.getIdsByType(typeName) || [];
        const selector = entitySelector.trim().toLowerCase();
        let id = "";
        let error = "";

        if (selector) {
            const matches = known.filter(function(candidate) {
                const full = candidate.toLowerCase();
                const tail = full.substring(full.lastIndexOf(".") + 1);
                return full === selector || tail === selector ||
                       tail.indexOf(selector) === 0;
            });
            if (matches.length === 1) id = matches[0];
            else if (matches.length > 1) error = qsTr("Ambiguous entity. Use a longer ID.");
            else if (selector.indexOf(".") !== -1) id = entitySelector.trim();
            else error = qsTr("No matching %1 entity").arg(typeName);
        } else {
            const preferred = [];
            if (commandEntityId) preferred.push(commandEntityId);
            const included = activityEntity && activityEntity.includedEntities ?
                             activityEntity.includedEntities : [];
            for (let i = 0; i < included.length; ++i) preferred.push(included[i]);
            for (let j = 0; j < preferred.length; ++j) {
                if (known.indexOf(preferred[j]) !== -1) {
                    id = preferred[j];
                    break;
                }
            }
            if (!id && known.length === 1) id = known[0];
            if (!id) error = qsTr("Use %1;entity_id to select a device").arg(entityKind);
        }

        selectionError = error;
        if (id !== entityId) entityId = id;
        else bindEntity();
    }

    function bindEntity() {
        const obj = entityId ? EntityController.get(entityId) : null;
        entityObj = obj && obj.getTypeAsString() === typeName ? obj : null;
        if (!obj && entityId) EntityController.load(entityId);
    }

    function beginGesture() {
        if (gestureHeld) return;
        gestureHeld = true;
        beginPageGesture();
    }

    function endGesture() {
        if (!gestureHeld) return;
        gestureHeld = false;
        endPageGesture();
    }

    function openNativeDetail() {
        if (!ready) return;
        // The Activity supplies loadThirdContainer(screenUrl(entity), ...).
        // No new popup mimics the native entity UI.
        openEntityDetail(entityObj);
    }

    function mainValue() {
        if (!entityObj) return "";
        switch (entityKind) {
        case "LIGHT":
            return entityObj.state === LightStates.On ? qsTr("On") : qsTr("Off");
        case "CLIMATE":
            if (!entityObj.hasFeature(ClimateFeatures.Target_temperature))
                return entityObj.stateAsString;
            return entityObj.targetTemperature.toLocaleString(Qt.locale(), 'f',
                       entityObj.targetTemperatureStep === 1 ? 0 : 1) +
                   entityObj.temperatureLabel;
        case "COVER":
            return entityObj.positionAvailable ? entityObj.position + "%" :
                   entityObj.stateAsString;
        default:
            return entityObj.stateAsString;
        }
    }

    function secondaryValue() {
        if (!entityObj) return "";
        switch (entityKind) {
        case "LIGHT":
            return entityObj.hasFeature(LightFeatures.Dim) ?
                   Math.round(entityObj.brightness / 255 * 100) + "%" : entityObj.stateInfo;
        case "CLIMATE":
            return entityObj.currentTemperatureAvailable ?
                   qsTr("Current %1%2").arg(entityObj.currentTemperature.toLocaleString(
                       Qt.locale(), 'f', entityObj.targetTemperatureStep === 1 ? 0 : 1))
                       .arg(entityObj.temperatureLabel) : entityObj.stateAsString;
        case "COVER":
            return entityObj.stateAsString;
        default:
            return "";
        }
    }

    Component.onCompleted: resolveTarget()
    Component.onDestruction: endGesture()
    onEntityKindChanged: resolveTarget()
    onEntitySelectorChanged: resolveTarget()
    onCommandEntityIdChanged: if (!entitySelector) resolveTarget()
    onActivityEntityChanged: if (!entitySelector) resolveTarget()
    onEntityIdChanged: bindEntity()
    onWidgetActiveChanged: if (!widgetActive) endGesture()

    Connections {
        target: EntityController
        function onEntityLoaded(success, id) {
            if (id === card.entityId) card.bindEntity();
            else if (success && !card.entityId) card.resolveTarget();
        }
    }

    Column {
        anchors { fill: parent; margins: 12 }
        spacing: 8
        visible: card.entityObj !== null
        Row {
            width: parent.width
            height: 40
            spacing: 8
            Components.Icon {
                icon: card.entityObj ? card.entityObj.icon : ""
                color: colors.offwhite
                size: 40
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                width: Math.max(0, parent.width - 48)
                text: card.entityObj ? card.entityObj.name : ""
                anchors.verticalCenter: parent.verticalCenter
                color: colors.offwhite
                font: fonts.label()
                maximumLineCount: 1
                elide: Text.ElideRight
            }
        }
        Text {
            width: parent.width
            height: Math.max(40, card.height - 147)
            text: card.mainValue()
            verticalAlignment: Text.AlignVCenter
            color: colors.offwhite
            font: fonts.primaryFont(Math.min(47, Math.max(27, card.width * .17)), "Light")
            elide: Text.ElideRight
            maximumLineCount: 1
        }
        Text {
            width: parent.width
            text: card.secondaryValue()
            color: colors.light
            font: fonts.help()
            elide: Text.ElideRight
            maximumLineCount: 1
        }
        Row {
            width: parent.width
            spacing: 6
            Components.Icon {
                icon: "uc:arrow-up-right-and-arrow-down-left-from-center"
                color: colors.light
                size: 26
            }
            Text {
                text: qsTr("Open controls")
                color: colors.light
                font: fonts.help()
            }
        }
    }

    Text {
        anchors { fill: parent; margins: 14 }
        visible: !card.ready
        text: card.selectionError || (!card.entityObj ? qsTr("Loading entity…") :
              !card.widgetActive ? qsTr("Activity inactive") : qsTr("Entity unavailable"))
        color: colors.textSecondary
        font: fonts.help()
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    // Capture the complete card touch sequence so the activity PathView cannot
    // steal a drag or interpret an attempted tap as a page swipe. Unlike a
    // slider, no gesture is forwarded by this surface to a second controller.
    Components.HapticMouseArea {
        anchors.fill: parent
        enabled: card.ready
        preventStealing: true
        onPressed: card.beginGesture()
        onReleased: card.endGesture()
        onCanceled: card.endGesture()
        onClicked: card.openNativeDetail()
    }
}
