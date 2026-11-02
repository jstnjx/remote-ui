// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import QtQuick.Controls 2.15
import Entity.Climate 1.0
import Haptic 1.0
import "qrc:/components" as Components

// The inline counterpart to the native Climate detail's temperature Tumbler,
// current-temperature label, plus/minus steps and native HVAC mode commands.
// Uses the same live model, target-temperature index and unit formatting.
Item {
    id: controls
    property var entityObj: null
    property bool acceptsCommands: false
    readonly property bool canSet: acceptsCommands && entityObj &&
        entityObj.hasFeature(ClimateFeatures.Target_temperature)
    readonly property bool hasMode: entityObj &&
        entityObj.hasAnyFeature([ClimateFeatures.On_off, ClimateFeatures.Heat, ClimateFeatures.Cool])
    property bool initialized: false

    function setFromEntity() {
        if (!entityObj || !entityObj.model || temperatureTumbler.moving)
            return;
        const index = entityObj.getModelIndexFromTemperature(entityObj.targetTemperature);
        if (index < 0 || index >= temperatureTumbler.count) return;
        temperatureTumbler.currentIndex = index;
        temperatureTumbler.positionViewAtIndex(index, ListView.Center);
        initialized = true;
    }
    function commitTarget() {
        if (!canSet || !initialized || temperatureTumbler.moving) return;
        const index = temperatureTumbler.currentIndex;
        if (index < 0 || index >= entityObj.model.length) return;
        if (Math.abs(entityObj.model[index] - entityObj.targetTemperature) < .001) return;
        entityObj.setTargetTemperature(entityObj.model[index]);
    }
    function moveTarget(delta) {
        if (!canSet || temperatureTumbler.count < 1) return;
        temperatureTumbler.currentIndex = Math.min(temperatureTumbler.count - 1,
            Math.max(0, temperatureTumbler.currentIndex + delta));
        temperatureTumbler.positionViewAtIndex(temperatureTumbler.currentIndex, ListView.Center);
        targetCommit.restart();
    }
    function changeMode() {
        if (!acceptsCommands || !hasMode) return;
        const modes = [];
        if (entityObj.hasFeature(ClimateFeatures.On_off)) modes.push(ClimateStates.Off);
        if (entityObj.hasFeature(ClimateFeatures.Heat)) modes.push(ClimateStates.Heat);
        if (entityObj.hasFeature(ClimateFeatures.Cool)) modes.push(ClimateStates.Cool);
        if (entityObj.hasAllFeatures([ClimateFeatures.Heat, ClimateFeatures.Cool]))
            modes.push(ClimateStates.Auto);
        if (!modes.length) return;
        const next = modes[(modes.indexOf(entityObj.state) + 1) % modes.length];
        if (next === ClimateStates.Off) entityObj.turnOff();
        else entityObj.setHvacMode(next);
    }
    function modeLabel() {
        if (!entityObj) return "";
        switch (entityObj.state) {
        case ClimateStates.Off: return qsTr("Off");
        case ClimateStates.Heat: return qsTr("Heat");
        case ClimateStates.Cool: return qsTr("Cool");
        case ClimateStates.Auto: return qsTr("Auto");
        case ClimateStates.Heat_cool: return qsTr("Heat/Cool");
        case ClimateStates.Fan: return qsTr("Fan");
        default: return qsTr("Mode");
        }
    }

    Component.onCompleted: Qt.callLater(setFromEntity)
    onEntityObjChanged: {
        initialized = false;
        Qt.callLater(setFromEntity);
    }
    Connections {
        target: controls.entityObj
        ignoreUnknownSignals: true
        function onTargetTemperatureChanged() { controls.setFromEntity(); }
        function onModelChanged() { Qt.callLater(controls.setFromEntity); }
    }

    Timer {
        id: targetCommit
        interval: 300
        repeat: false
        onTriggered: controls.commitTarget()
    }

    // The exact Qt Controls Tumbler used by the native climate entity screen.
    Tumbler {
        id: temperatureTumbler
        width: parent.width
        height: Math.max(90, parent.height - 50)
        model: controls.entityObj ? controls.entityObj.model : []
        visibleItemCount: 3
        wrap: false
        enabled: controls.canSet
        onMovingChanged: {
            if (!moving) targetCommit.restart();
        }
        delegate: Item {
            width: temperatureTumbler.width
            height: temperatureTumbler.height / 3
            property bool current: Tumbler.tumbler && Tumbler.tumbler.currentIndex === index
            Text {
                anchors.centerIn: parent
                text: controls.entityObj && controls.entityObj.model[index] !== undefined ?
                      controls.entityObj.model[index].toLocaleString(Qt.locale(), 'f',
                          controls.entityObj.targetTemperatureStep === 1 ? 0 : 1) : "--"
                font: fonts.primaryFont(current ? 48 : 30, current ? "Light" : "ExtraLight")
                color: !current || !controls.entityObj || !controls.entityObj.currentTemperatureAvailable ?
                       colors.offwhite : controls.entityObj.currentTemperature >
                       controls.entityObj.targetTemperature ? colors.blue :
                       controls.entityObj.currentTemperature < controls.entityObj.targetTemperature ?
                       colors.red : colors.offwhite
                opacity: current ? 1 : .55
            }
        }
    }

    Row {
        anchors { top: parent.top; right: parent.right; rightMargin: 4 }
        spacing: 6
        z: 2
        Rectangle {
            width: 40; height: 36
            color: colors.dark; radius: ui.cornerRadiusSmall
            Components.Icon { anchors.centerIn: parent; icon: "uc:minus"; color: colors.offwhite; size: 28 }
            Components.HapticMouseArea {
                anchors.fill: parent
                enabled: controls.canSet
                preventStealing: true
                onClicked: controls.moveTarget(-1)
            }
        }
        Rectangle {
            width: 40; height: 36
            color: colors.dark; radius: ui.cornerRadiusSmall
            Components.Icon { anchors.centerIn: parent; icon: "uc:plus"; color: colors.offwhite; size: 28 }
            Components.HapticMouseArea {
                anchors.fill: parent
                enabled: controls.canSet
                preventStealing: true
                onClicked: controls.moveTarget(1)
            }
        }
    }
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 42
        color: colors.medium
        radius: ui.cornerRadiusSmall
        Text {
            anchors.centerIn: parent
            text: controls.modeLabel()
            font: fonts.help()
            color: colors.offwhite
        }
        Components.HapticMouseArea {
            anchors.fill: parent
            enabled: controls.acceptsCommands && controls.hasMode
            preventStealing: true
            onClicked: controls.changeMode()
        }
    }
}
