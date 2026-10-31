// SPDX-License-Identifier: GPL-3.0-or-later
#include "../RtspDeviceConfig.h"
#include "../RtspNativeSurface.h"
#include <QGuiApplication>
#include <QTemporaryDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QVariantMap>
#include <QDebug>

static bool saveFixture(const QString &path, const QByteArray &contents) {
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) return false;
    if (file.write(contents) != contents.size()) return false;
    file.close();
    return QFile::setPermissions(path, QFileDevice::ReadOwner | QFileDevice::WriteOwner);
}

int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    QTemporaryDir temp;
    if (!temp.isValid()) return 1;
    const QString path = temp.filePath("video-streams.json");
    const QByteArray fixture = R"JSON({
      "version": 1,
      "endpoints": {
        "front-door": { "url": "rtsp://user:secret@127.0.0.1:554/live" }
      },
      "widgets": [{
        "activity_id": "uc.main.activity.test",
        "page_id": "page-one",
        "endpoint_ref": "front-door",
        "name": "Front Door",
        "location": {"x": 1, "y": 2},
        "size": {"width": 2, "height": 2},
        "decode_width": 640,
        "max_fps": 15
      }]
    })JSON";
    if (!saveFixture(path, fixture)) return 2;
    qputenv("UC_NATIVE_RTSP_CONFIG_PATH", QFile::encodeName(path));
    RtspDeviceConfig config;
    if (RtspDeviceConfig::instance() != &config) return 3;
    if (config.resolveUrl("front-door").isEmpty()) return 4;
    const QVariantList items = config.widgetsForPage("uc.main.activity.test", "page-one");
    if (items.size() != 1) return 5;
    if (config.widgetsForPage("different-activity", "page-one").size() != 0) return 6;
    const QVariantMap item = items.first().toMap();
    if (item.value("endpoint_ref").toString() != "front-door") return 7;
    if (QJsonDocument::fromVariant(items).toJson().contains("secret")) return 8;

    RtspNativeSurface surface;
    surface.setEndpointRef("front-door");
    if (surface.endpointRef() != "front-door") return 9;
    // No active network traffic in the test: verify only bindings, decoding
    // compiles and credential visibility. Real RTSP needs hardware testing.

    // Configs that permit group/other access must be rejected.
    if (!QFile::setPermissions(path, QFileDevice::ReadOwner |
                                    QFileDevice::WriteOwner |
                                    QFileDevice::ReadGroup)) return 10;
    const int before = config.revision();
    QMetaObject::invokeMethod(&config, "reload", Qt::DirectConnection);
    if (config.revision() <= before) return 11;
    if (!config.resolveUrl("front-door").isEmpty()) return 12;
    if (!config.widgetsForPage("uc.main.activity.test", "page-one").isEmpty()) return 13;
    qInfo("Native RTSP configuration tests passed");
    return 0;
}
