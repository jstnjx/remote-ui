// Lovelace configuration. No dashboard credentials are stored in config.ini.
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Config 1.0
import "qrc:/settings" as Settings

Settings.Page {
    id: root
    property int editingIndex: -1
    function loadEntry(i) {
        editingIndex = i;
        const d = i < 0 ? {} : Config.lovelaceDashboards[i];
        nameField.text = d.name || "";
        urlField.text = d.url || "";
        rendererField.text = d.renderer || "";
        engineSelector.currentIndex = d.engine === "local" ? 0 : 1;
        placementSelector.currentIndex = d.placement === "overlay" ? 1 : 0;
    }
    function saveEntry() {
        const url = urlField.text.trim();
        if (!/^https?:\/\/[^\s@/]+/i.test(url)) {
            statusText.text = qsTr("Enter an HTTP(S) dashboard URL without credentials.");
            return;
        }
        const renderer = rendererField.text.trim();
        if (engineSelector.currentIndex === 1 &&
            !/^https?:\/\/[^\s@/]+/i.test(renderer)) {
            statusText.text = qsTr("Remote rendering requires an HTTP(S) renderer address.");
            return;
        }
        const rows = Config.lovelaceDashboards.slice();
        const entry = {name: nameField.text.trim() || "Lovelace",
                       url: url, renderer: renderer,
                       engine: engineSelector.currentIndex === 0 ? "local" : "remote",
                       placement: placementSelector.currentIndex === 1 ? "overlay" : "page"};
        if (editingIndex < 0) rows.push(entry); else rows[editingIndex] = entry;
        Config.lovelaceDashboards = rows;
        statusText.text = qsTr("Saved.");
        loadEntry(-1);
    }
    Flickable {
        anchors { left: parent.left; right: parent.right; top: topNavigation.bottom; bottom: parent.bottom }
        contentWidth: width
        contentHeight: content.implicitHeight + 40
        clip: true
        ScrollBar.vertical: ScrollBar {}
        ColumnLayout {
            id: content
            width: parent.width
            anchors.leftMargin: 16
            spacing: 8
            Label { text: qsTr("Configured dashboards"); color: "white"; font.pixelSize: 22 }
            Repeater {
                model: Config.lovelaceDashboards
                delegate: RowLayout {
                    Layout.fillWidth: true
                    Label { text: modelData.name || modelData.url; color: "white"; Layout.fillWidth: true; elide: Text.ElideRight }
                    Button { text: qsTr("Edit"); onClicked: root.loadEntry(index) }
                    Button {
                        text: qsTr("Remove")
                        onClicked: {
                            const copy = Config.lovelaceDashboards.slice();
                            copy.splice(index, 1);
                            Config.lovelaceDashboards = copy;
                        }
                    }
                }
            }
            Label { text: editingIndex < 0 ? qsTr("Add dashboard") : qsTr("Edit dashboard"); color: "white"; font.pixelSize: 22 }
            Label { text: qsTr("Name"); color: "white" }
            TextField { id: nameField; Layout.fillWidth: true; placeholderText: "Living Room" }
            Label { text: qsTr("Home Assistant dashboard URL"); color: "white" }
            TextField { id: urlField; Layout.fillWidth: true; placeholderText: "http://homeassistant.local:8123/lovelace/home" }
            Label { text: qsTr("Rendering engine"); color: "white" }
            ComboBox { id: engineSelector; Layout.fillWidth: true; model: [qsTr("Local browser (requires WebEngine)"), qsTr("Remote browser service")]; currentIndex: 1 }
            Label { text: qsTr("Renderer address (remote engine)"); color: "white"; visible: engineSelector.currentIndex === 1 }
            TextField {
                id: rendererField; Layout.fillWidth: true; visible: engineSelector.currentIndex === 1
                placeholderText: "http://renderer.local:8765"
            }
            Label { text: qsTr("Home screen placement"); color: "white" }
            ComboBox { id: placementSelector; Layout.fillWidth: true; model: [qsTr("Additional page"), qsTr("Launcher overlay")] }
            Label { id: statusText; color: "#ffbd7a"; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            RowLayout {
                Button { text: qsTr("Save"); onClicked: root.saveEntry() }
                Button { text: qsTr("New"); onClicked: root.loadEntry(-1) }
            }
            Label {
                Layout.fillWidth: true; wrapMode: Text.WordWrap; color: "#b6b6b6"
                text: qsTr("Remote rendering needs the companion Chromium service. Local rendering only works on a firmware build with Qt WebEngine.")
            }
        }
    }
}
