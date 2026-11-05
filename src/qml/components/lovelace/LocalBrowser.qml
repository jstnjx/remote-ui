// Optional Qt WebEngine backend. Dynamically loaded to keep the stock static build usable.
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import QtWebEngine 1.10

WebEngineView {
    id: browser
    property string dashboardUrl: ""
    url: dashboardUrl
    settings.javascriptEnabled: true
    settings.localStorageEnabled: true
    settings.fullScreenSupportEnabled: false
    onLoadingChanged: {
        if (loadRequest.status === WebEngineLoadRequest.LoadFailedStatus)
            console.warn("Lovelace load failed:", loadRequest.errorString)
    }
}
