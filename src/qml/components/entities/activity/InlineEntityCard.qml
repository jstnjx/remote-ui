// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import QtQuick.Controls 2.15
import Entity.Controller 1.0
import Entity.Light 1.0
import Entity.Climate 1.0
import Entity.Cover 1.0
import "qrc:/components" as Components

// Compact native-styled cards for a configured Activity Text widget.
// LIGHT[;id], CLIMATE[;id] and COVER[;id] use the existing entity API.
// This is deliberately not a scaled-down full-screen BaseDetail: its sliders
// and hit targets remain usable within 2x2 (or larger) grid cells.
Rectangle {
    id: card
    radius: ui.cornerRadiusSmall
    color: colors.dark
    clip: true

    property string entityKind: "LIGHT"
    property string entitySelector: ""
    property string commandEntityId: ""
    property var activityEntity: null
    property bool widgetActive: false
    property string entityId: ""
    property var entityObj: null
    property string selectionError: ""

    readonly property string typeName: entityKind === "LIGHT" ? "light" :
                                       entityKind === "CLIMATE" ? "climate" : "cover"
    readonly property bool ready: widgetActive && entityObj &&
                                  entityObj.enabled && EntityController.mayCommandEntity(entityObj.enabled)
    readonly property bool hasPosition: entityKind === "COVER" && entityObj &&
                                        entityObj.hasFeature(CoverFeatures.Position)
    readonly property bool hasBrightness: entityKind === "LIGHT" && entityObj &&
                                          entityObj.hasFeature(LightFeatures.Dim)
    readonly property bool hasColorTemperature: hasBrightness && height >= 260 &&
                                          entityObj.hasFeature(LightFeatures.Color_temperature)

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

    function changeTarget(delta) {
        if (!ready || entityKind !== "CLIMATE" ||
                !entityObj.hasFeature(ClimateFeatures.Target_temperature))
            return;
        const step = entityObj.targetTemperatureStep > 0 ? entityObj.targetTemperatureStep : 0.5;
        const target = Math.round((entityObj.targetTemperature + delta * step) / step) * step;
        entityObj.setTargetTemperature(Math.max(entityObj.minTemperature,
                                                Math.min(entityObj.maxTemperature, target)));
    }

    function cycleClimateMode() {
        if (!ready || entityKind !== "CLIMATE") return;
        const choices = [];
        if (entityObj.hasFeature(ClimateFeatures.On_off)) choices.push(ClimateStates.Off);
        if (entityObj.hasFeature(ClimateFeatures.Heat)) choices.push(ClimateStates.Heat);
        if (entityObj.hasFeature(ClimateFeatures.Cool)) choices.push(ClimateStates.Cool);
        if (entityObj.hasAllFeatures([ClimateFeatures.Heat, ClimateFeatures.Cool]))
            choices.push(ClimateStates.Auto);
        if (!choices.length) return;
        const next = choices[(choices.indexOf(entityObj.state) + 1) % choices.length];
        if (next === ClimateStates.Off) entityObj.turnOff();
        else entityObj.setHvacMode(next);
    }

    Component.onCompleted: resolveTarget()
    onEntityKindChanged: resolveTarget()
    onEntitySelectorChanged: resolveTarget()
    onCommandEntityIdChanged: if (!entitySelector) resolveTarget()
    onActivityEntityChanged: if (!entitySelector) resolveTarget()
    onEntityIdChanged: bindEntity()
    Connections {
        target: EntityController
        function onEntityLoaded(success, id) {
            if (id === card.entityId) card.bindEntity();
            else if (!card.entityId && success) card.resolveTarget();
        }
    }

    Item {
        anchors { fill: parent; margins: 10 }
        visible: card.entityObj !== null
        Column {
            anchors.fill: parent
            spacing: 6

            Row {
                width: parent.width
                height: 34
                spacing: 7
                Components.Icon {
                    icon: card.entityObj ? card.entityObj.icon : ""
                    color: colors.offwhite
                    size: 38
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    width: Math.max(0, parent.width - 50)
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.entityObj ? card.entityObj.name : ""
                    color: colors.offwhite
                    font: fonts.label()
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            // LIGHT: the native on/off tile and horizontal compact brightness.
            Item {
                width: parent.width
                height: Math.max(0, parent.height - 40)
                visible: card.entityKind === "LIGHT"
                Row {
                    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom }
                    spacing: 8
                    Rectangle {
                        width: Math.min(74, Math.max(54, parent.width * .32))
                        height: Math.min(width, parent.height)
                        radius: ui.cornerRadiusSmall
                        color: card.entityObj && card.entityObj.state === LightStates.On ?
                               colors.offwhite : colors.medium
                        Components.Icon {
                            anchors.centerIn: parent
                            icon: "uc:power-off"
                            color: card.entityObj && card.entityObj.state === LightStates.On ?
                                   colors.black : colors.offwhite
                            size: 40
                        }
                        Components.HapticMouseArea {
                            anchors.fill: parent
                            enabled: card.ready
                            onClicked: card.entityObj.toggle()
                        }
                    }
                    Column {
                        width: Math.max(0, parent.width - 84)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        Text {
                            width: parent.width
                            text: card.entityObj && card.entityObj.state === LightStates.On ?
                                  qsTr("On") : qsTr("Off")
                            font: fonts.primaryFont(30)
                            color: colors.offwhite
                        }
                        Text {
                            visible: card.hasBrightness
                            text: card.entityObj ? Math.round(card.entityObj.brightness / 255 * 100) + "%" : ""
                            font: fonts.help()
                            color: colors.light
                        }
                        Slider {
                            width: parent.width
                            height: 36
                            visible: card.hasBrightness
                            enabled: card.ready
                            from: 0
                            to: 255
                            stepSize: 1
                            value: card.entityObj && card.entityKind === "LIGHT" ? card.entityObj.brightness : 0
                            onPressedChanged: if (!pressed && card.ready)
                                card.entityObj.setBrightness(Math.round(value))
                        }
                        Slider {
                            width: parent.width
                            height: 30
                            visible: card.hasColorTemperature
                            enabled: card.ready
                            from: 0
                            to: card.entityObj ? Math.max(1, card.entityObj.colorTempSteps) : 1
                            stepSize: 1
                            value: card.entityObj && card.entityKind === "LIGHT" ? card.entityObj.colorTemp : 0
                            onPressedChanged: if (!pressed && card.ready)
                                card.entityObj.setColorTemperature(Math.round(value))
                        }
                    }
                }
            }

            // CLIMATE: native target temperature and HVAC state/mode behavior.
            Column {
                width: parent.width
                height: Math.max(0, parent.height - 40)
                visible: card.entityKind === "CLIMATE"
                spacing: 6
                Text {
                    width: parent.width
                    text: card.entityObj && card.entityObj.currentTemperatureAvailable ?
                          qsTr("Room %1%2").arg(card.entityObj.currentTemperature.toFixed(1))
                                        .arg(card.entityObj.temperatureLabel) :
                          qsTr("Temperature unavailable")
                    color: colors.light
                    font: fonts.help()
                    elide: Text.ElideRight
                }
                Row {
                    width: parent.width
                    height: 58
                    spacing: 7
                    Rectangle {
                        width: 48; height: 50
                        radius: ui.cornerRadiusSmall
                        color: colors.medium
                        Components.Icon { anchors.centerIn: parent; icon: "uc:minus"; size: 34; color: colors.offwhite }
                        Components.HapticMouseArea {
                            anchors.fill: parent
                            enabled: card.ready && card.entityObj &&
                                     card.entityObj.hasFeature(ClimateFeatures.Target_temperature)
                            onClicked: card.changeTarget(-1)
                        }
                    }
                    Text {
                        width: Math.max(0, parent.width - 110)
                        height: parent.height
                        text: card.entityObj ?
                            card.entityObj.targetTemperature.toFixed(card.entityObj.targetTemperatureStep === 1 ? 0 : 1) +
                            card.entityObj.temperatureLabel : "--"
                        color: colors.offwhite
                        font: fonts.primaryFont(Math.min(37, Math.max(22, card.width * .12)))
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        width: 48; height: 50
                        radius: ui.cornerRadiusSmall
                        color: colors.medium
                        Components.Icon { anchors.centerIn: parent; icon: "uc:plus"; size: 34; color: colors.offwhite }
                        Components.HapticMouseArea {
                            anchors.fill: parent
                            enabled: card.ready && card.entityObj &&
                                     card.entityObj.hasFeature(ClimateFeatures.Target_temperature)
                            onClicked: card.changeTarget(1)
                        }
                    }
                }
                Rectangle {
                    width: parent.width
                    height: Math.min(40, Math.max(27, parent.height - 105))
                    radius: ui.cornerRadiusSmall
                    color: colors.medium
                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (!card.entityObj) return "";
                            switch (card.entityObj.state) {
                            case ClimateStates.Off: return qsTr("Off");
                            case ClimateStates.Heat: return qsTr("Heat");
                            case ClimateStates.Cool: return qsTr("Cool");
                            case ClimateStates.Auto: return qsTr("Auto");
                            default: return qsTr("Mode");
                            }
                        }
                        font: fonts.help()
                        color: colors.offwhite
                    }
                    Components.HapticMouseArea {
                        anchors.fill: parent
                        enabled: card.ready
                        onClicked: card.cycleClimateMode()
                    }
                }
            }

            // COVER: native Open / Stop / Close semantics and position control.
            Column {
                width: parent.width
                height: Math.max(0, parent.height - 40)
                visible: card.entityKind === "COVER"
                spacing: 7
                Text {
                    width: parent.width
                    text: card.entityObj && card.entityObj.positionAvailable ?
                          qsTr("Position %1%").arg(card.entityObj.position) :
                          card.entityObj ? card.entityObj.stateInfo : ""
                    font: fonts.help()
                    color: colors.light
                    elide: Text.ElideRight
                }
                Slider {
                    width: parent.width
                    height: 37
                    visible: card.hasPosition
                    enabled: card.ready
                    from: 0
                    to: 100
                    stepSize: 1
                    value: card.entityObj && card.entityKind === "COVER" &&
                           card.entityObj.positionAvailable ? card.entityObj.position : 0
                    onPressedChanged: if (!pressed && card.ready)
                        card.entityObj.setPosition(Math.round(value))
                }
                Row {
                    width: parent.width
                    height: 62
                    spacing: 7
                    Repeater {
                        model: [
                            {label: qsTr("Open"), glyph: "uc:arrow-up", cmd: "open"},
                            {label: qsTr("Stop"), glyph: "uc:stop", cmd: "stop"},
                            {label: qsTr("Close"), glyph: "uc:arrow-down", cmd: "close"}
                        ]
                        delegate: Rectangle {
                            width: (parent.width - 14) / 3
                            height: Math.min(62, parent.height)
                            radius: ui.cornerRadiusSmall
                            color: colors.medium
                            Column {
                                anchors.centerIn: parent
                                spacing: 1
                                Components.Icon {
                                    icon: modelData.glyph
                                    size: 32
                                    color: colors.offwhite
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Text {
                                    text: modelData.label
                                    color: colors.offwhite
                                    font: fonts.help()
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                            Components.HapticMouseArea {
                                anchors.fill: parent
                                enabled: card.ready && card.entityObj &&
                                    ((modelData.cmd === "open" && card.entityObj.hasFeature(CoverFeatures.Open)) ||
                                     (modelData.cmd === "close" && card.entityObj.hasFeature(CoverFeatures.Close)) ||
                                     (modelData.cmd === "stop" && card.entityObj.hasFeature(CoverFeatures.Stop)))
                                onClicked: {
                                    if (modelData.cmd === "open") card.entityObj.open();
                                    else if (modelData.cmd === "close") card.entityObj.close();
                                    else card.entityObj.stop();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Text {
        anchors { fill: parent; margins: 12 }
        visible: !card.entityObj || !card.widgetActive || !card.entityObj.enabled
        text: card.selectionError || (!card.entityObj ? qsTr("Loading entity…") :
              !card.widgetActive ? qsTr("Activity inactive") : qsTr("Entity unavailable"))
        color: colors.textSecondary
        font: fonts.help()
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
