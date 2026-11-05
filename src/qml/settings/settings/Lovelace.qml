// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Config 1.0
import "qrc:/settings" as Settings
import "qrc:/components" as Components

// Keep this screen consistent with the native settings design system.
// All text is clipped/wrapped to the 480px display; no desktop ComboBoxes.
Settings.Page {
    id: settingsPage
    scrollTarget: flickable
    initialFocusItem: dashboardRow

    property int editingIndex: -1
    property string selectedEngine: "remote"
    property string selectedPlacement: "overlay"
    property var pickerHandler: null
    readonly property var entries: Config.lovelaceDashboards
    readonly property var selectedEntry: editingIndex >= 0 && editingIndex < entries.length
                                         ? entries[editingIndex] : null

    function loadEntry(index) {
        editingIndex = index;
        const d = index < 0 ? {} : entries[index];
        nameInput.inputValue = d.name || "";
        urlInput.inputValue = d.url || "";
        rendererInput.inputValue = d.renderer || "";
        selectedEngine = d.engine === "local" ? "local" : "remote";
        selectedPlacement = d.placement === "page" ? "page" : "overlay";
        message.text = "";
    }

    function openPicker(kind) {
        pickerModel.clear();
        if (kind === "dashboard") {
            for (let i = 0; i < entries.length; ++i) {
                pickerModel.append({ name: entries[i].name || entries[i].url,
                                     value: String(i) });
            }
            pickerHandler = function(value) { loadEntry(Number(value)); };
        } else if (kind === "engine") {
            pickerModel.append({ name: qsTr("Remote Chromium renderer"), value: "remote" });
            pickerModel.append({ name: qsTr("Local Qt WebEngine (if installed)"), value: "local" });
            pickerHandler = function(value) { selectedEngine = value; };
        } else {
            pickerModel.append({ name: qsTr("Home screen overlay"), value: "overlay" });
            pickerModel.append({ name: qsTr("Additional dashboard page"), value: "page" });
            pickerHandler = function(value) { selectedPlacement = value; };
        }
        pickerLoader.setSource("qrc:/components/PopupList.qml", {
            title: kind === "dashboard" ? qsTr("Select dashboard") :
                   kind === "engine" ? qsTr("Rendering engine") : qsTr("Display location"),
            listModel: pickerModel, showSearch: false
        });
    }

    function validUrl(value) {
        // Basic frontend guard; Config enforces scheme, host, and userinfo.
        return /^https?:\/\/[^\s/@]+(?:\/|$)/i.test(value);
    }

    function saveEntry() {
        const url = urlInput.inputValue.trim();
        const renderer = rendererInput.inputValue.trim();
        if (!validUrl(url)) {
            message.text = qsTr("Enter a valid HTTP(S) Home Assistant dashboard URL.");
            urlInput.showError(message.text);
            return;
        }
        if (selectedEngine === "remote" && !validUrl(renderer)) {
            message.text = qsTr("Enter an HTTP(S) Chromium renderer address.");
            rendererInput.showError(message.text);
            return;
        }
        if (editingIndex < 0 && entries.length >= 12) {
            message.text = qsTr("Maximum of 12 dashboards reached.");
            return;
        }
        const dashboards = entries.slice();
        const entry = {
            name: nameInput.inputValue.trim() || qsTr("Home Assistant"),
            url: url,
            renderer: selectedEngine === "remote" ? renderer : "",
            engine: selectedEngine,
            placement: selectedPlacement
        };
        if (editingIndex < 0) dashboards.push(entry);
        else dashboards[editingIndex] = entry;
        Config.lovelaceDashboards = dashboards;
        keyboard.hide();
        loadEntry(-1);
        message.text = qsTr("Dashboard saved.");
    }

    function removeEntry() {
        if (editingIndex < 0) return;
        const dashboards = entries.slice();
        dashboards.splice(editingIndex, 1);
        Config.lovelaceDashboards = dashboards;
        keyboard.hide();
        loadEntry(-1);
        message.text = qsTr("Dashboard removed.");
    }

    ListModel { id: pickerModel }

    Flickable {
        id: flickable
        anchors { left: parent.left; right: parent.right; top: topNavigation.bottom; bottom: parent.bottom }
        contentWidth: width
        contentHeight: content.height + 24
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: content
            width: flickable.width
            spacing: 0

            Components.MenuRow {
                id: dashboardRow
                text: qsTr("Dashboard")
                value: selectedEntry ? (selectedEntry.name || qsTr("Unnamed")) : qsTr("New dashboard")
                chevron: entries.length > 0
                enabled: entries.length > 0
                keypadActivatable: true
                selected: activeFocus && ui.keyNavigationActive
                onClicked: settingsPage.openPicker("dashboard")
                KeyNavigation.down: newButton
            }
            Components.Divider {}

            Components.Button {
                id: newButton
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                Layout.topMargin: 12
                text: qsTr("Add new dashboard")
                variant: "secondary"
                trigger: function() { settingsPage.loadEntry(-1); }
                KeyNavigation.down: nameInput.inputField
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                Layout.topMargin: 20
                text: selectedEntry ? qsTr("Edit dashboard") : qsTr("Dashboard details")
                color: colors.textPrimary
                font: fonts.label()
            }
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                Layout.topMargin: 12
                text: qsTr("Name")
                color: colors.textSecondary
                font: fonts.help()
            }
            Components.InputField {
                id: nameInput
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                label: qsTr("Dashboard name")
                moveInput: false
                keyboardFollowsFocus: true
                navUp: newButton
                navDown: urlInput.inputField
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                Layout.topMargin: 16
                text: qsTr("Lovelace URL")
                color: colors.textSecondary
                font: fonts.help()
            }
            Components.InputField {
                id: urlInput
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                label: qsTr("Home Assistant URL")
                moveInput: false
                keyboardFollowsFocus: true
                navUp: nameInput.inputField
                navDown: engineRow
            }
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                Layout.topMargin: 6
                wrapMode: Text.WordWrap
                text: qsTr("Example: http://homeassistant.local:8123/lovelace/home")
                color: colors.textSecondary
                font: fonts.caption()
            }

            Components.MenuRow {
                id: engineRow
                text: qsTr("Rendering")
                value: selectedEngine === "local" ? qsTr("Local") : qsTr("Remote")
                chevron: true
                keypadActivatable: true
                selected: activeFocus && ui.keyNavigationActive
                onClicked: settingsPage.openPicker("engine")
                KeyNavigation.up: urlInput.inputField
                KeyNavigation.down: selectedEngine === "remote" ? rendererInput.inputField : placementRow
            }
            Components.Divider {}

            ColumnLayout {
                Layout.fillWidth: true
                visible: selectedEngine === "remote"
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    Layout.topMargin: 14
                    text: qsTr("Renderer address")
                    color: colors.textSecondary
                    font: fonts.help()
                }
                Components.InputField {
                    id: rendererInput
                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    label: qsTr("Renderer URL")
                    moveInput: false
                    keyboardFollowsFocus: true
                    navUp: engineRow
                    navDown: placementRow
                }
                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    Layout.topMargin: 6
                    wrapMode: Text.WordWrap
                    color: colors.textSecondary
                    font: fonts.caption()
                    text: qsTr("Example: http://192.168.1.10:8765")
                }
            }

            Components.MenuRow {
                id: placementRow
                text: qsTr("Open as")
                value: selectedPlacement === "page" ? qsTr("Page") : qsTr("Overlay")
                chevron: true
                keypadActivatable: true
                selected: activeFocus && ui.keyNavigationActive
                onClicked: settingsPage.openPicker("placement")
                KeyNavigation.up: selectedEngine === "remote" ? rendererInput.inputField : engineRow
                KeyNavigation.down: saveButton
            }
            Components.Divider {}

            Text {
                id: message
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                Layout.topMargin: 12
                visible: text !== ""
                wrapMode: Text.WordWrap
                color: colors.textSecondary
                font: fonts.help()
            }

            Components.Button {
                id: saveButton
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                Layout.topMargin: 16
                text: qsTr("Save dashboard")
                trigger: function() { settingsPage.saveEntry(); }
                KeyNavigation.up: placementRow
                KeyNavigation.down: removeButton
            }
            Components.Button {
                id: removeButton
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                Layout.topMargin: 12
                visible: editingIndex >= 0
                enabled: editingIndex >= 0
                variant: "destructive"
                text: qsTr("Delete dashboard")
                trigger: function() { settingsPage.removeEntry(); }
                KeyNavigation.up: saveButton
            }
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                Layout.topMargin: 18
                Layout.bottomMargin: 28
                wrapMode: Text.WordWrap
                text: qsTr("Local rendering requires Qt WebEngine on the remote. Remote rendering uses the Chromium service on your network.")
                color: colors.textSecondary
                font: fonts.help()
            }
        }
    }

    Loader {
        id: pickerLoader
        anchors.fill: parent
        z: 10
        Connections {
            target: pickerLoader.item
            ignoreUnknownSignals: true
            function onItemSelected(value) {
                if (settingsPage.pickerHandler) settingsPage.pickerHandler(value);
            }
            function onDone() {
                settingsPage.pickerHandler = null;
                pickerLoader.source = "";
            }
        }
    }
}
