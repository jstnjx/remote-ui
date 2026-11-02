// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Config 1.0
import Entity.Controller 1.0
import "qrc:/settings" as Settings
import "qrc:/components" as Components

Settings.Page {
    id: settingsPage
    scrollTarget: flickable
    initialFocusItem: ruleRow

    property int ruleIndex: -1
    property var selectionHandler: null
    readonly property var rules: Config.keyboardRules
    readonly property var rule: ruleIndex >= 0 && ruleIndex < rules.length ? rules[ruleIndex] : null

    function nameOf(entityId) {
        if (!entityId) return qsTr("Not selected");
        const obj = EntityController.get(entityId);
        return obj ? obj.name : entityId;
    }

    function namesOf(ids) {
        if (!ids || ids.length === 0) return qsTr("Not selected");
        if (ids.length === 1) return nameOf(ids[0]);
        return qsTr("%1 selected").arg(ids.length);
    }

    function editRule(part, value) {
        if (!rule) return;
        const all = Config.keyboardRules.slice();
        const updated = Object.assign({}, all[ruleIndex]);
        updated[part] = value;
        if (part === "activityId") updated.sensorIds = [];
        all[ruleIndex] = updated;
        Config.keyboardRules = all;
    }

    function addRule() {
        const all = Config.keyboardRules.slice();
        all.push({id: "rule-" + Date.now() + "-" + Math.floor(Math.random() * 1000000),
                  activityId: "", sensorIds: [], mediaPlayerIds: [],
                  prompt: qsTr("Enter text on the media player?")});
        Config.keyboardRules = all;
        ruleIndex = all.length - 1;
    }

    function removeRule() {
        if (!rule) return;
        const all = Config.keyboardRules.slice();
        all.splice(ruleIndex, 1);
        Config.keyboardRules = all;
        ruleIndex = all.length ? Math.min(ruleIndex, all.length - 1) : -1;
    }

    function sensorChoices() {
        // No dependency on activity.includedEntities: Core can keep sensors
        // outside that list. Include configured sensors and page sensor tiles.
        const ids = EntityController.getIdsByType("sensor").slice();
        const activity = rule ? EntityController.get(rule.activityId) : null;
        if (activity && activity.ui && activity.ui.pages) {
            const pages = activity.ui.pages;
            for (let p = 0; p < pages.length; ++p) {
                const items = pages[p].items || [];
                for (let i = 0; i < items.length; ++i) {
                    const item = items[i];
                    if (item.type === "sensor" && item.sensor && item.sensor.sensor_id &&
                            ids.indexOf(item.sensor.sensor_id) < 0) {
                        ids.push(item.sensor.sensor_id);
                        EntityController.load(item.sensor.sensor_id);
                    }
                }
            }
        }
        const result = [];
        for (let i = 0; i < ids.length; ++i) {
            const obj = EntityController.get(ids[i]);
            if (!obj) {
                result.push(ids[i]);
                continue;
            }
            const raw = String(obj.rawValue).trim().toLowerCase();
            if (obj.getDeviceClass().toLowerCase() === "binary" ||
                    raw === "on" || raw === "off") result.push(ids[i]);
        }
        return result;
    }

    function openPicker(part) {
        if (!rule) return;
        pickerModel.clear();
        let ids = part === "activityId" ? EntityController.getIdsByType("activity") :
                  part === "sensorIds" ? sensorChoices() :
                  EntityController.getIdsByType("media_player").concat(
                      EntityController.getIdsByType("remote"));
        const multiple = part !== "activityId";
        const selected = multiple ? (rule[part] || []) : [];
        if (!multiple) pickerModel.append({name: qsTr("None"), value: ""});
        for (let i = 0; i < ids.length; ++i) {
            const checked = selected.indexOf(ids[i]) >= 0;
            const item = EntityController.get(ids[i]);
            const nativeKeyboard = item && (String(item.integrationId || "").toLowerCase().indexOf("appletv_keyboard") >= 0 ||
                                             String(item.id || "").toLowerCase().indexOf("appletv_keyboard") >= 0 ||
                                             String(item.name || "").toLowerCase().indexOf("apple tv keyboard -") === 0);
            const typeLabel = nativeKeyboard ? qsTr("Apple TV Keyboard: ") :
                              item && item.getTypeAsString() === "remote" ?
                              qsTr("Remote: ") : part === "mediaPlayerIds" ?
                              qsTr("Media player: ") : "";
            pickerModel.append({name: (checked ? "✓  " : "") + typeLabel + nameOf(ids[i]), value: ids[i]});
        }
        selectionHandler = function(value) {
            if (!multiple) {
                editRule(part, value);
            } else {
                const chosen = (rule[part] || []).slice();
                const i = chosen.indexOf(value);
                if (i < 0) chosen.push(value);
                else chosen.splice(i, 1);
                editRule(part, chosen);
                for (let j = 0; j < pickerModel.count; ++j) {
                    const item = pickerModel.get(j);
                    pickerModel.setProperty(j, "name",
                                            ((chosen.indexOf(item.value) >= 0) ? "✓  " : "") +
                                            (part === "mediaPlayerIds" ?
                                             (String(item.value).toLowerCase().indexOf("appletv_keyboard") >= 0 ?
                                              qsTr("Apple TV Keyboard: ") :
                                              ((EntityController.get(item.value) &&
                                                String(EntityController.get(item.value).name || "").toLowerCase().indexOf("apple tv keyboard -") === 0) ?
                                               qsTr("Apple TV Keyboard: ") :
                                               ((EntityController.get(item.value) &&
                                                 EntityController.get(item.value).getTypeAsString() === "remote")
                                                ? qsTr("Remote: ") : qsTr("Media player: ")))) : "") +
                                            nameOf(item.value));
                }
                if (pickerLoader.item) pickerLoader.item.popupListmodel.reload();
            }
        };
        pickerLoader.setSource("qrc:/components/PopupList.qml", {
            title: part === "activityId" ? qsTr("Activity") :
                   part === "sensorIds" ? qsTr("On/Off sensors") : qsTr("Remote / media-player targets"),
            listModel: pickerModel, showSearch: pickerModel.count > 8,
            closeOnSelected: !multiple
        });
    }

    function openRulePicker() {
        pickerModel.clear();
        const current = Config.keyboardRules;
        for (let i = 0; i < current.length; ++i) {
            pickerModel.append({
                name: nameOf(current[i].activityId) + " — " + (current[i].prompt || qsTr("Keyboard")),
                value: String(i)
            });
        }
        selectionHandler = function(value) { ruleIndex = parseInt(value, 10); };
        pickerLoader.setSource("qrc:/components/PopupList.qml", {
            title: qsTr("Choose keyboard rule"), listModel: pickerModel,
            showSearch: pickerModel.count > 8
        });
    }

    ListModel { id: pickerModel }

    Flickable {
        id: flickable
        anchors { left: parent.left; right: parent.right; top: topNavigation.bottom; bottom: parent.bottom }
        contentWidth: width
        contentHeight: rows.height
        clip: true
        ColumnLayout {
            id: rows
            width: parent.width
            spacing: 0

            Components.MenuRow {
                id: ruleRow
                text: qsTr("Rule")
                value: rule ? (settingsPage.nameOf(rule.activityId) + " (" + (ruleIndex + 1) + "/" + rules.length + ")") :
                              qsTr("No rules")
                selected: activeFocus && ui.keyNavigationActive
                chevron: true
                keypadActivatable: true
                enabled: rules.length > 0
                onClicked: settingsPage.openRulePicker()
                KeyNavigation.down: addRuleButton
            }
            Components.Divider {}

            Components.Button {
                id: addRuleButton
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                text: qsTr("Add rule")
                trigger: function() { settingsPage.addRule(); }
                KeyNavigation.up: ruleRow
                KeyNavigation.down: activityRow
            }

            Components.MenuRow {
                id: activityRow
                text: qsTr("Activity")
                enabled: rule !== null
                value: rule ? nameOf(rule.activityId) : ""
                chevron: true
                selected: activeFocus && ui.keyNavigationActive
                keypadActivatable: true
                onClicked: settingsPage.openPicker("activityId")
                KeyNavigation.up: addRuleButton
                KeyNavigation.down: sensorRow
            }
            Components.Divider {}

            Components.MenuRow {
                id: sensorRow
                text: qsTr("On/Off sensors (any On)")
                value: rule ? namesOf(rule.sensorIds) : ""
                enabled: rule !== null && rule.activityId !== ""
                chevron: true
                selected: activeFocus && ui.keyNavigationActive
                keypadActivatable: true
                onClicked: settingsPage.openPicker("sensorIds")
                KeyNavigation.up: activityRow
                KeyNavigation.down: targetRow
            }
            Components.Divider {}

            Components.MenuRow {
                id: targetRow
                text: qsTr("Text input targets")
                value: rule ? namesOf(rule.mediaPlayerIds) : ""
                enabled: rule !== null
                chevron: true
                selected: activeFocus && ui.keyNavigationActive
                keypadActivatable: true
                onClicked: settingsPage.openPicker("mediaPlayerIds")
                KeyNavigation.up: sensorRow
                KeyNavigation.down: promptInput.inputField
            }
            Components.Divider {}

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.topMargin: 14
                text: qsTr("Prompt text")
                color: colors.textPrimary
                font: fonts.label()
            }
            Components.InputField {
                id: promptInput
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                enabled: rule !== null
                moveInput: false
                keyboardFollowsFocus: true
                label: qsTr("Prompt")
                inputValue: rule ? rule.prompt : ""
                navUp: targetRow
                navDown: savePromptButton
            }
            Components.Button {
                id: savePromptButton
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                enabled: rule !== null
                text: qsTr("Save prompt text")
                trigger: function() { editRule("prompt", promptInput.inputValue.trim()); keyboard.hide(); }
                KeyNavigation.up: promptInput.inputField
                KeyNavigation.down: deleteRuleButton
            }
            Components.Button {
                id: deleteRuleButton
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                enabled: rule !== null
                variant: "destructive"
                text: qsTr("Delete selected rule")
                trigger: function() { settingsPage.removeRule(); }
                KeyNavigation.up: savePromptButton
            }
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                Layout.topMargin: 14
                wrapMode: Text.WordWrap
                font: fonts.help()
                color: colors.textSecondary
                text: qsTr("Each rule applies only in its selected activity. Any selected sensor changing "
                           + "to On offers the keyboard once, until all sensors return to Off. "
                           + "For Apple TV, select the Apple TV Keyboard media-player entity (Apple TV Keyboard:). "
                           + "Its Search action sends text directly through the Apple TV Companion connection. "
                           + "Home Assistant Apple TV Remote cannot send keyboard text using remote.send_command. "
                           + "In multi-select lists, select entries to toggle them, then press Back.")
            }
        }
    }

    Loader {
        id: pickerLoader
        anchors.fill: parent
        Connections {
            target: pickerLoader.item
            ignoreUnknownSignals: true
            function onItemSelected(value) {
                if (settingsPage.selectionHandler) settingsPage.selectionHandler(value);
            }
            function onDone() {
                settingsPage.selectionHandler = null;
                pickerLoader.source = "";
            }
        }
    }
    Component.onCompleted: {
        ruleIndex = rules.length ? 0 : -1;
    }
}
