// Home Assistant dashboard surface; web engines are deliberately lazy loaded.
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import QtQuick.Controls 2.15
import Lovelace 1.0

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

    // A single persistent painted surface prevents blank frames and QML Image
    // texture churn. It draws the last valid JPEG until another one is decoded.
    property string inputError: ""
    property var pendingRequests: []

    LovelaceFrame {
        id: frame
        anchors { fill: parent; topMargin: 54 }
        renderer: dashboard.rendererUrl
        dashboardUrl: dashboard.dashboardUrl
        active: dashboard.isActive && dashboard.engine === "remote"
        visible: dashboard.engine === "remote"
    }
    MouseArea {
        id: touchLayer
        anchors.fill: frame
        z: 1
        enabled: dashboard.isActive && dashboard.engine === "remote" &&
                 dashboard.rendererUrl !== ""
        preventStealing: true
        propagateComposedEvents: false
        acceptedButtons: Qt.LeftButton
        property real downX: 0
        property real downY: 0
        onPressed: {
            downX = mouse.x;
            downY = mouse.y;
            mouse.accepted = true;
        }
        onReleased: {
            const dx = mouse.x - downX;
            const dy = mouse.y - downY;
            if (Math.abs(dx) < 10 && Math.abs(dy) < 10)
                dashboard.sendEvent({type:"click", x:mouse.x, y:mouse.y});
            else
                dashboard.sendEvent({type:"swipe", x:downX, y:downY,
                                     toX:mouse.x, toY:mouse.y});
            mouse.accepted = true;
        }
        onWheel: {
            dashboard.sendEvent({type:"scroll", x:wheel.x, y:wheel.y,
                                 deltaY:-wheel.angleDelta.y});
            wheel.accepted = true;
        }
    }

    function sendEvent(eventData) {
        if (engine !== "remote" || !rendererUrl) return;
        const xhr = new XMLHttpRequest();
        const endpoint = rendererUrl + "/input?url=" + encodeURIComponent(dashboardUrl);
        xhr.open("POST", endpoint);
        xhr.setRequestHeader("Content-Type", "text/plain;charset=UTF-8");
        pendingRequests.push(xhr);
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            const index = pendingRequests.indexOf(xhr);
            if (index >= 0) pendingRequests.splice(index, 1);
            if (xhr.status < 200 || xhr.status >= 300) {
                inputError = qsTr("Touch input failed (HTTP %1)").arg(xhr.status);
                console.warn("Lovelace input failed:", xhr.status, xhr.responseText);
            } else {
                inputError = "";
                frame.refresh();
            }
        };
        xhr.send(JSON.stringify(eventData));
    }

    Text {
        visible: dashboard.engine === "remote" && (frame.error !== "" || inputError !== "")
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom;
                  margins: 12 }
        z: 3
        color: "#ffbd7a"
        font.pixelSize: 15
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: frame.error !== "" ? frame.error : inputError
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
