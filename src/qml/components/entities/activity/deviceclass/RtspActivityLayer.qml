// GPL-3.0-or-later. Optional desktop simulator RTSP activity overlay.
import QtQuick 2.15

Item {
    id: layer
    property string activityId: ""
    property string pageId: ""
    property int gridWidth: 4
    property int gridHeight: 6
    property bool active: false
    property var widgets: []
    readonly property bool hasWidgets: widgets.length > 0
    readonly property string baseUrl: rtspWidgetUrl ? String(rtspWidgetUrl).replace(/\/+$/, "") : ""
    readonly property string viewToken: rtspWidgetViewToken ? String(rtspWidgetViewToken) : ""
    property int generation: 0

    function reload() {
        ++generation;
        const current = generation;
        if (!activityId || !pageId || !baseUrl || !viewToken) {
            widgets = [];
            return;
        }
        const xhr = new XMLHttpRequest();
        xhr.open("GET", baseUrl + "/api/activities/" + encodeURIComponent(activityId)
                 + "/pages/" + encodeURIComponent(pageId) + "/widgets");
        xhr.setRequestHeader("Authorization", "Bearer " + viewToken);
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || current !== generation) return;
            if (xhr.status !== 200) {
                console.warn("RTSP widget lookup HTTP " + xhr.status);
                widgets = [];
                return;
            }
            try {
                const data = JSON.parse(xhr.responseText);
                widgets = Array.isArray(data) ? data.filter(function(w) { return w.enabled; }) : [];
            } catch (e) {
                console.warn("Invalid RTSP widget response: " + e);
                widgets = [];
            }
        };
        xhr.send();
    }

    Component.onCompleted: reload()
    onActivityIdChanged: reload()
    onPageIdChanged: reload()
    onActiveChanged: if (active) reload()
    Timer {
        interval: 15000
        repeat: true
        running: layer.active && layer.baseUrl !== "" && layer.viewToken !== ""
        onTriggered: layer.reload()
    }
    Repeater {
        model: layer.widgets
        delegate: RtspTile {
            widget: modelData
            baseUrl: layer.baseUrl
            viewToken: layer.viewToken
            active: layer.active
            x: modelData.location.x * layer.width / Math.max(1, layer.gridWidth)
            y: modelData.location.y * layer.height / Math.max(1, layer.gridHeight)
            width: modelData.size.width * layer.width / Math.max(1, layer.gridWidth)
            height: modelData.size.height * layer.height / Math.max(1, layer.gridHeight)
        }
    }
}
