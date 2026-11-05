// Home Assistant dashboard surface; web engines are deliberately lazy loaded.
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: dashboard
    property var definition: ({})
    property bool isActive: visible
    property string title: definition.name || qsTr("Home Assistant")
    property string engine: definition.engine || "remote"
    property string dashboardUrl: definition.url || ""
    property string rendererUrl: (definition.renderer || "").replace(/\/$/, "")
    signal closeRequested()
    clip: true

    Rectangle { anchors.fill: parent; color: "#101115" }

    Loader {
        id: localBrowser
        anchors { fill: parent; topMargin: 54 }
        active: dashboard.isActive && dashboard.engine === "local"
        source: "qrc:/components/lovelace/LocalBrowser.qml"
        onLoaded: item.dashboardUrl = Qt.binding(function() { return dashboard.dashboardUrl })
    }

    // Remote rendering endpoint uses browser-owned session state; credentials must
    // never be embedded in dashboard URLs. Frames are fetched only while visible.
    property int frameNumber: 0
    Timer {
        interval: 750
        repeat: true
        running: dashboard.isActive && dashboard.engine === "remote" &&
                 dashboard.rendererUrl.length > 0
        onTriggered: dashboard.frameNumber++
    }
    Image {
        id: frame
        anchors { fill: parent; topMargin: 54 }
        visible: dashboard.engine === "remote" && dashboard.rendererUrl !== ""
        asynchronous: true
        cache: false
        fillMode: Image.Stretch
        source: visible && dashboard.isActive
                ? dashboard.rendererUrl + "/frame?url=" + encodeURIComponent(dashboard.dashboardUrl)
                  + "&width=" + Math.round(width) + "&height=" + Math.round(height)
                  + "&v=" + dashboard.frameNumber
                : ""
    }
    MouseArea {
        anchors { fill: frame }
        enabled: frame.visible && dashboard.isActive
        preventStealing: true
        property real downX: 0
        property real downY: 0
        onPressed: { downX = mouse.x; downY = mouse.y; mouse.accepted = true }
        onReleased: {
            if (Math.abs(mouse.x - downX) < 8 && Math.abs(mouse.y - downY) < 8)
                dashboard.sendEvent({type:"click", x:mouse.x, y:mouse.y});
            else dashboard.sendEvent({type:"swipe", x:downX, y:downY, toX:mouse.x, toY:mouse.y});
        }
        onWheel: dashboard.sendEvent({type:"scroll", x:wheel.x, y:wheel.y, deltaY:-wheel.angleDelta.y})
    }
    function sendEvent(eventData) {
        if (engine !== "remote" || !rendererUrl) return;
        const xhr = new XMLHttpRequest();
        xhr.open("POST", rendererUrl + "/input?url=" + encodeURIComponent(dashboardUrl));
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.send(JSON.stringify(eventData));
        frameNumber++;
    }

    // Keep errors inside the content viewport, below the fixed title bar.
    // Qt's default text size is much too large for the Remote 3 screen.
    Item {
        id: emptyState
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom;
                  topMargin: 54 }
        visible: (dashboard.engine === "remote" && dashboard.rendererUrl === "") ||
                 (dashboard.engine === "local" && localBrowser.status === Loader.Error)
        z: 2

        Column {
            width: Math.min(parent.width - 48, 420)
            anchors.centerIn: parent
            spacing: 14
            Text {
                width: parent.width
                color: "white"
                font.pixelSize: 21
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: dashboard.engine === "local" ? qsTr("Local rendering unavailable") :
                                                     qsTr("Renderer not configured")
            }
            Text {
                width: parent.width
                color: "#c0c0c0"
                font.pixelSize: 17
                lineHeight: 1.15
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: dashboard.engine === "local"
                      ? qsTr("This Remote UI build has no Qt WebEngine browser. Use Remote rendering with the Chromium companion service.")
                      : qsTr("Set a rendering service address in Home Assistant dashboard settings.")
            }
            Text {
                width: parent.width
                color: "#aaaaaa"
                font.pixelSize: 15
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("Press Close to return.")
            }
        }
    }
    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 54; color: "#202126"; z: 3
        Text {
            text: dashboard.title; color: "white"; font.pixelSize: 19
            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
            width: parent.width - 100; elide: Text.ElideRight
        }
        Button {
            text: qsTr("Close")
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            onClicked: dashboard.closeRequested()
        }
    }
}
