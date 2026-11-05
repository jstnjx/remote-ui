// Home Assistant Lovelace rendered directly on the Remote through Qt WebEngine.
// Requires a dynamic Qt 5.15 build with Qt WebEngine; never streams JPEGs.
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: dashboard
    property var definition: ({})
    property bool isActive: visible
    property string title: definition.name || qsTr("Home Assistant")
    property string dashboardUrl: definition.url || ""
    signal closeRequested()
    clip: true

    Rectangle { anchors.fill: parent; color: "#101115" }

    // Load QtWebEngine lazily: a stock static build must still start and allow
    // users to navigate away rather than crashing on a missing QML module.
    Loader {
        id: localBrowser
        anchors {
            left: parent.left; right: parent.right
            top: header.bottom; bottom: parent.bottom
        }
        active: dashboard.isActive
        asynchronous: false
        source: "qrc:/components/lovelace/LocalBrowser.qml"
        onLoaded: {
            if (item) item.dashboardUrl = Qt.binding(function() {
                return dashboard.dashboardUrl;
            });
        }
    }

    Item {
        anchors {
            left: parent.left; right: parent.right
            top: header.bottom; bottom: parent.bottom
        }
        visible: localBrowser.status === Loader.Error
        z: 2

        Column {
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 420)
            spacing: 14

            Text {
                width: parent.width
                text: qsTr("Embedded browser unavailable")
                color: "white"; font.pixelSize: 21; font.bold: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                text: qsTr("This UI build does not contain a compatible Qt WebEngine runtime. A shared Qt 5.15 ARM64 build with WebEngine is required.")
                color: "#c0c0c0"; font.pixelSize: 17
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }

    Rectangle {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 54; z: 3; color: "#202126"
        Text {
            text: dashboard.title
            color: "white"; font.pixelSize: 19
            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
            width: parent.width - 115
            elide: Text.ElideRight
        }
        Button {
            text: qsTr("Close")
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            onClicked: dashboard.closeRequested()
        }
    }
}
