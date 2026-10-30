// GPL-3.0-or-later. Optional desktop simulator RTSP activity overlay.
import QtQuick 2.15

Item {
    id: rtspOverlay
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
                const next = Array.isArray(data) ? data.filter(function(w) { return w.enabled; }) : [];
                // Keep the existing player instances alive when polling returns unchanged
                // metadata, otherwise the HLS session would restart every 15 seconds.
                if (JSON.stringify(next) !== JSON.stringify(widgets)) widgets = next;
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
        running: rtspOverlay.active && rtspOverlay.baseUrl !== "" && rtspOverlay.viewToken !== ""
        onTriggered: rtspOverlay.reload()
    }
    Repeater {
        model: rtspOverlay.widgets
        delegate: RtspTile {
            widget: modelData
            baseUrl: rtspOverlay.baseUrl
            viewToken: rtspOverlay.viewToken
            active: rtspOverlay.active
            x: modelData.location.x * rtspOverlay.width / Math.max(1, rtspOverlay.gridWidth)
            y: modelData.location.y * rtspOverlay.height / Math.max(1, rtspOverlay.gridHeight)
            width: modelData.size.width * rtspOverlay.width / Math.max(1, rtspOverlay.gridWidth)
            height: modelData.size.height * rtspOverlay.height / Math.max(1, rtspOverlay.gridHeight)
        }
    }
}
