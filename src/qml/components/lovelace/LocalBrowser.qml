// Native Home Assistant browser: rendered inside the Remote UI process tree.
// Requires QtWebEngine QML plugin and QtWebEngineProcess on the Remote.
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import QtWebEngine 1.10

WebEngineView {
    id: browser
    property string dashboardUrl: ""
    property string failure: ""
    url: dashboardUrl
    focus: true
    settings.javascriptEnabled: true
    settings.localStorageEnabled: true
    settings.fullScreenSupportEnabled: false
    settings.autoLoadImages: true
    settings.errorPageEnabled: true

    // Keep the WebEngine profile alive while the view exists; cookies and
    // localStorage are persisted under UC_DATA_HOME, not in dashboard URLs.
    profile: WebEngineProfile {
        storageName: "lovelace"
        offTheRecord: false
        persistentStoragePath: lovelaceBrowserStoragePath
        persistentCookiesPolicy: WebEngineProfile.ForcePersistentCookies
        httpCacheType: WebEngineProfile.DiskHttpCache
    }

    onLoadingChanged: {
        if (loadRequest.status === WebEngineLoadRequest.LoadFailedStatus) {
            failure = loadRequest.errorString;
            console.warn("Lovelace local load failed:", failure);
        } else if (loadRequest.status === WebEngineLoadRequest.LoadSucceededStatus) {
            failure = "";
        }
    }
    onCertificateError: {
        // Never silently bypass TLS validation for Home Assistant.
        error.rejectCertificate();
    }
    // Do not intercept touch events: native Chromium owns scrolling, taps,
    // sliders, text fields and the Home Assistant login workflow.
}
