// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15
import Entity.Controller 1.0
import Entity.Light 1.0
import Entity.Climate 1.0
import Entity.Cover 1.0
import "qrc:/components" as Components
import "qrc:/components/entities/activity" as ActivityComponents

// Native Light feature pages are embedded inline. Climate and Cover expose
// the same controls and styling as their native entity details, sized for the
// Activity grid. No full-screen entity overlay is opened.
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

    // Activity owns the page-gesture lock. Native controls remain inline.
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

    // Follow the same feature order as native Light.qml.
    property int lightPage: 0
    readonly property bool hasColor: entityObj && entityKind === "LIGHT" &&
                                     entityObj.hasFeature(LightFeatures.Color)
    readonly property string lightSource:
        entityObj && entityKind === "LIGHT" ?
          (!entityObj.hasFeature(LightFeatures.Dim)
             ? "qrc:/components/entities/light/OnOff.qml"
             : lightPage === 1 && hasColor
               ? "qrc:/components/entities/light/Color.qml"
               : "qrc:/components/entities/light/Brightness.qml") : ""

    Component.onCompleted: resolveTarget()
    Component.onDestruction: endGesture()
    onEntityKindChanged: resolveTarget()
    onEntitySelectorChanged: resolveTarget()
    onCommandEntityIdChanged: if (!entitySelector) resolveTarget()
    onActivityEntityChanged: if (!entitySelector) resolveTarget()
    onEntityIdChanged: bindEntity()
    onEntityObjChanged: lightPage = 0
    onWidgetActiveChanged: if (!widgetActive) endGesture()

    Connections {
        target: EntityController
        function onEntityLoaded(success, id) {
            if (id === card.entityId) card.bindEntity();
            else if (success && !card.entityId) card.resolveTarget();
        }
    }


    // PointHandler is a PASSIVE pointer observer in Qt 5.15: it watches a
    // press in the card (including child sliders and tumblers) without taking
    // their exclusive grab. Unlike a MouseArea overlay, controls remain fully
    // draggable. Page swiping is disabled from the first press until release.
    PointHandler {
        id: gestureObserver
        enabled: card.ready
        target: null
        onActiveChanged: {
            if (active) card.beginGesture();
            else card.endGesture();
        }
    }

    Item {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 9 }
        height: 40
        visible: card.entityObj !== null
        Components.Icon {
            id: entityIcon
            icon: card.entityObj ? card.entityObj.icon : ""
            size: 38
            color: colors.offwhite
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            anchors { left: entityIcon.right; right: parent.right; leftMargin: 7; verticalCenter: parent.verticalCenter }
            text: card.entityObj ? card.entityObj.name : ""
            color: colors.offwhite
            font: fonts.label()
            maximumLineCount: 1
            elide: Text.ElideRight
        }
        // Native Light's POWER / DPAD_MIDDLE action toggles the same entity.
        // Keep it available on the card while brightness is the visible page.
        Components.HapticMouseArea {
            anchors { left: entityIcon.left; right: entityIcon.right; top: parent.top; bottom: parent.bottom }
            visible: card.entityKind === "LIGHT"
            enabled: card.ready && visible
            preventStealing: true
            onClicked: card.entityObj.toggle()
        }
    }

    Item {
        id: content
        clip: true
        anchors {
            left: parent.left; right: parent.right
            top: header.bottom; bottom: lightTabs.top
            leftMargin: 10; rightMargin: 10; topMargin: 2
        }

        // These are not replicas: these are the actual native Light.qml
        // feature pages. Only the viewport is scaled to the Activity cell.
        // The unscaled sizes match the entity detail's original coordinates.
        Loader {
            id: nativeLightPage
            active: card.ready && card.entityKind === "LIGHT"
            asynchronous: false
            source: card.lightSource
            width: 460
            height: 650
            transformOrigin: Item.TopLeft
            scale: Math.max(.1, Math.min(content.width / width, content.height / height))
            onLoaded: if (item) item.entityObj = card.entityObj
        }
        Binding {
            target: nativeLightPage.item
            property: "entityObj"
            value: card.entityObj
            when: nativeLightPage.status === Loader.Ready && nativeLightPage.item !== null
        }

        ActivityComponents.InlineClimateControls {
            anchors.fill: parent
            visible: card.entityKind === "CLIMATE" && card.entityObj !== null
            enabled: card.ready
            entityObj: card.entityKind === "CLIMATE" ? card.entityObj : null
            acceptsCommands: card.ready
        }

        ActivityComponents.InlineCoverControls {
            anchors.fill: parent
            visible: card.entityKind === "COVER" && card.entityObj !== null
            enabled: card.ready
            entityObj: card.entityKind === "COVER" ? card.entityObj : null
            acceptsCommands: card.ready
        }
    }

    // Use the native Light detail's separate brightness and color feature
    // pages; tab switching stays within the Activity card.
    Row {
        id: lightTabs
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 7 }
        height: card.entityKind === "LIGHT" && card.hasColor ? 34 : 0
        visible: height > 0
        spacing: 6
        Repeater {
            model: [
                {label: qsTr("Brightness"), index: 0},
                {label: qsTr("Color"), index: 1}
            ]
            delegate: Rectangle {
                width: (lightTabs.width - 6) / 2
                height: lightTabs.height
                radius: ui.cornerRadiusSmall
                color: card.lightPage === modelData.index ? colors.offwhite : colors.medium
                Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    font: fonts.help()
                    color: card.lightPage === modelData.index ? colors.black : colors.offwhite
                }
                Components.HapticMouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    enabled: card.ready
                    onClicked: card.lightPage = modelData.index
                }
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
        z: 2
    }
}
