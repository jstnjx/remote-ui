// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import Entity.Controller 1.0
import Entity.Remote 1.0
import Haptic 1.0
import "qrc:/components" as Components

// TP[;remote_id] is an activity-local gesture surface.
// Swipe = one directional key, tap = OK/select, hold = mapped long press.
// Prefer the entity's native buttonMapping; otherwise use its remote.send_cmd
// feature with common direction names. No commands are sent while inactive.
Rectangle {
    id: pad
    color: colors.dark
    radius: ui.cornerRadiusSmall
    clip: true

    property string entitySelector: ""
    property string commandEntityId: ""
    property var activityEntity: null
    property bool widgetActive: false
    property string entityId: ""
    property var remoteObj: null
    property string selectionError: ""
    property string feedback: ""
    readonly property bool ready: widgetActive && remoteObj &&
                                  remoteObj.enabled && EntityController.mayCommandEntity(remoteObj.enabled)
    readonly property bool haRemote: remoteObj &&
                                     /home[_-]?assistant|homeassistant/i.test(
                                        String(remoteObj.integrationId || "") + " " +
                                        String(remoteObj.id || ""))

    function resolveTarget() {
        const known = EntityController.getIdsByType("remote") || [];
        const selector = entitySelector.trim().toLowerCase();
        let resolved = "";
        let error = "";
        if (selector) {
            const matches = known.filter(function(id) {
                const full = id.toLowerCase();
                const tail = full.substring(full.lastIndexOf(".") + 1);
                return full === selector || tail === selector || tail.indexOf(selector) === 0;
            });
            if (matches.length === 1) resolved = matches[0];
            else if (matches.length > 1) error = qsTr("Ambiguous remote. Use a longer ID.");
            else if (selector.indexOf(".") !== -1) resolved = entitySelector.trim();
            else error = qsTr("Remote not found: %1").arg(entitySelector);
        } else {
            const linked = [];
            if (commandEntityId) linked.push(commandEntityId);
            const included = activityEntity && activityEntity.includedEntities ?
                             activityEntity.includedEntities : [];
            for (let i = 0; i < included.length; ++i) linked.push(included[i]);
            for (let j = 0; j < linked.length; ++j) {
                if (known.indexOf(linked[j]) !== -1) {
                    resolved = linked[j];
                    break;
                }
            }
            if (!resolved && known.length === 1) resolved = known[0];
            if (!resolved) error = qsTr("Use TP;remote_id to select a remote");
        }
        selectionError = error;
        if (entityId !== resolved) entityId = resolved;
        else bindRemote();
    }

    function bindRemote() {
        const target = entityId ? EntityController.get(entityId) : null;
        remoteObj = target && target.getTypeAsString() === "remote" ? target : null;
        if (!target && entityId) EntityController.load(entityId);
    }

    function dispatch(direction, longPress) {
        if (!ready) return;
        const buttonName = direction === "select" ? "DPAD_MIDDLE" :
                           "DPAD_" + direction.toUpperCase();
        const mapping = remoteObj.buttonMapping || [];
        for (let i = 0; i < mapping.length; ++i) {
            const row = mapping[i];
            if (row.button !== buttonName) continue;
            const cmd = longPress ? row.long_press : row.short_press;
            if (!cmd || !cmd.cmd_id) continue;
            EntityController.onEntityCommand(remoteObj.id, cmd.cmd_id,
                                             cmd.params ? cmd.params : {});
            feedback = direction;
            Haptic.play(Haptic.Bump);
            feedbackTimer.restart();
            return;
        }

        // This fallback only uses supported Remote entity command features;
        // some integrations require their own buttonMapping / command names.
        if (!remoteObj.hasFeature(RemoteFeatures.Send_cmd) &&
                !remoteObj.hasFeature(RemoteFeatures.Send)) {
            feedback = qsTr("No directional commands configured");
            feedbackTimer.restart();
            return;
        }
        if (longPress) return; // Never guess a hold command.
        const command = direction === "select" ? (haRemote ? "select" : "OK") :
                        (haRemote ? direction : direction.toUpperCase());
        const cmd = remoteObj.hasFeature(RemoteFeatures.Send_cmd)
                    ? "remote.send_cmd" : "remote.send";
        EntityController.onEntityCommand(remoteObj.id, cmd, {command: command});
        feedback = direction;
        Haptic.play(Haptic.Bump);
        feedbackTimer.restart();
    }

    Component.onCompleted: resolveTarget()
    onEntitySelectorChanged: resolveTarget()
    onCommandEntityIdChanged: if (!entitySelector) resolveTarget()
    onActivityEntityChanged: if (!entitySelector) resolveTarget()
    onEntityIdChanged: bindRemote()
    Connections {
        target: EntityController
        function onEntityLoaded(success, id) {
            if (id === pad.entityId) pad.bindRemote();
            else if (success && !pad.entityId) pad.resolveTarget();
        }
    }

    Timer {
        id: feedbackTimer
        interval: 450
        repeat: false
        onTriggered: pad.feedback = ""
    }

    // Touch area intentionally spans the full widget, not five buttons.
    // A quick tap selects; a swipe (minimum 26 px) sends exactly one key.
    // An actual long press only uses the mapped long-press command.
    MouseArea {
        id: gesture
        anchors.fill: parent
        enabled: pad.ready
        preventStealing: true
        hoverEnabled: false
        property real startX: 0
        property real startY: 0
        property bool longPressed: false
        onPressed: {
            startX = mouse.x;
            startY = mouse.y;
            longPressed = false;
        }
        onPressAndHold: {
            const dx = mouse.x - startX;
            const dy = mouse.y - startY;
            if (Math.abs(dx) >= 26 || Math.abs(dy) >= 26) return;
            longPressed = true;
            pad.dispatch("select", true);
        }
        onReleased: {
            if (longPressed) return;
            const dx = mouse.x - startX;
            const dy = mouse.y - startY;
            if (Math.max(Math.abs(dx), Math.abs(dy)) < 26)
                pad.dispatch("select", false);
            else if (Math.abs(dx) >= Math.abs(dy))
                pad.dispatch(dx > 0 ? "right" : "left", false);
            else
                pad.dispatch(dy > 0 ? "down" : "up", false);
        }
    }

    // Reuse the native typography, icon glyphs, background and state palette.
    Components.Icon {
        anchors { top: parent.top; topMargin: 5; horizontalCenter: parent.horizontalCenter }
        icon: "uc:chevron-up"; size: 26; color: colors.light
    }
    Components.Icon {
        anchors { bottom: parent.bottom; bottomMargin: 5; horizontalCenter: parent.horizontalCenter }
        icon: "uc:chevron-down"; size: 26; color: colors.light
    }
    Components.Icon {
        anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
        icon: "uc:chevron-left"; size: 26; color: colors.light
    }
    Components.Icon {
        anchors { right: parent.right; rightMargin: 5; verticalCenter: parent.verticalCenter }
        icon: "uc:chevron-right"; size: 26; color: colors.light
    }
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(72, Math.max(40, Math.min(parent.width, parent.height) * .33))
        height: width
        radius: width / 2
        color: pad.feedback === "select" ? colors.offwhite : colors.medium
        Components.Icon {
            anchors.centerIn: parent
            icon: "uc:circle"
            size: 32
            color: colors.offwhite
            visible: pad.feedback !== "select"
        }
    }
    Text {
        anchors { bottom: parent.bottom; bottomMargin: 4; horizontalCenter: parent.horizontalCenter }
        width: Math.max(0, parent.width - 40)
        text: pad.feedback && pad.feedback.length > 8 ? pad.feedback : ""
        font: fonts.help()
        color: colors.light
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }
    Text {
        anchors { fill: parent; margins: 14 }
        visible: !pad.ready
        text: pad.selectionError || (!pad.remoteObj ? qsTr("Loading remote…") :
              !pad.widgetActive ? qsTr("Activity inactive") : qsTr("Remote unavailable"))
        font: fonts.help()
        color: colors.textSecondary
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
