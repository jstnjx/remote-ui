// SPDX-License-Identifier: GPL-3.0-or-later
#include "RtspDeviceConfig.h"
#include <QDir>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QTimer>
#include <QtGlobal>
#ifdef Q_OS_UNIX
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
#endif

RtspDeviceConfig *RtspDeviceConfig::s_instance = nullptr;

RtspDeviceConfig::RtspDeviceConfig(QObject *parent) : QObject(parent) {
    s_instance = this;
    const QString explicitPath = qEnvironmentVariable("UC_NATIVE_RTSP_CONFIG_PATH");
    const QString configDir = qEnvironmentVariable("UC_CONFIG_HOME");
    m_path = !explicitPath.isEmpty() ? explicitPath
           : configDir.isEmpty() ? QString() : QDir(configDir).filePath("video-streams.json");
    QObject::connect(&m_watcher, &QFileSystemWatcher::fileChanged, this,
                     [this] { QTimer::singleShot(100, this, &RtspDeviceConfig::reload); });
    if (!m_path.isEmpty()) {
        QObject::connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this,
                         [this] { QTimer::singleShot(100, this, &RtspDeviceConfig::reload); });
        m_watcher.addPath(QFileInfo(m_path).absolutePath());
        reload();
    }
}

RtspDeviceConfig *RtspDeviceConfig::instance() { return s_instance; }

void RtspDeviceConfig::reload() {
    // Fail closed: never retain old credentials after file removal or invalid
    // permissions. Replacing the file revokes all previously opened endpoints
    // as soon as their widgets are deactivated/recreated.
    m_urls.clear();
    m_items.clear();
    if (m_path.isEmpty()) return;

    QFileInfo info(m_path);
    if (!info.exists()) {
        ++m_revision; emit revisionChanged();
        return;
    }

    QByteArray bytes;
#ifdef Q_OS_UNIX
    const QByteArray filename = QFile::encodeName(m_path);
    const int fd = ::open(filename.constData(), O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0) { qWarning("RTSP device config: cannot open protected file"); return; }
    struct stat st {};
    const bool safe = ::fstat(fd, &st) == 0 && S_ISREG(st.st_mode) &&
                      st.st_uid == ::geteuid() && (st.st_mode & 077) == 0 &&
                      st.st_size <= 1024 * 1024;
    if (safe) {
        char chunk[4096];
        ssize_t count = 0;
        while ((count = ::read(fd, chunk, sizeof(chunk))) > 0 &&
               bytes.size() + count <= 1024 * 1024)
            bytes.append(chunk, static_cast<int>(count));
        if (count < 0 || bytes.size() > 1024 * 1024) bytes.clear();
    }
    ::close(fd);
    if (!safe || bytes.isEmpty()) {
        qWarning("RTSP device config: file must be owner-only (0600), regular and <=1MB");
        ++m_revision; emit revisionChanged();
        return;
    }
#else
    qWarning("RTSP device config: only supported on Unix device builds");
    return;
#endif

    QJsonParseError parseError {};
    const QJsonDocument parsed = QJsonDocument::fromJson(bytes, &parseError);
    if (parseError.error != QJsonParseError::NoError || !parsed.isObject()) {
        qWarning("RTSP device config: invalid JSON");
        ++m_revision; emit revisionChanged();
        return;
    }
    const QJsonObject doc = parsed.object();
    if (doc.value("version").toInt() != 1) {
        qWarning("RTSP device config: unsupported version");
        ++m_revision; emit revisionChanged();
        return;
    }

    const QJsonObject endpoints = doc.value("endpoints").toObject();
    for (auto it = endpoints.begin(); it != endpoints.end(); ++it) {
        const QString url = it.value().toObject().value("url").toString();
        if (it.key().isEmpty() || it.key().size() > 128) continue;
        if (url.startsWith("rtsp://", Qt::CaseInsensitive) ||
            url.startsWith("rtsps://", Qt::CaseInsensitive))
            m_urls.insert(it.key(), url);
    }

    for (const QJsonValue &entry : doc.value("widgets").toArray()) {
        if (!entry.isObject()) continue;
        const QJsonObject item = entry.toObject();
        const QString ref = item.value("endpoint_ref").toString();
        const QString activity = item.value("activity_id").toString();
        const QString page = item.value("page_id").toString();
        if (!m_urls.contains(ref) || activity.isEmpty() || page.isEmpty()) continue;
        const QJsonObject pos = item.value("location").toObject();
        const QJsonObject size = item.value("size").toObject();
        const int x = pos.value("x").toInt(-1), y = pos.value("y").toInt(-1);
        const int w = size.value("width").toInt(0), h = size.value("height").toInt(0);
        if (x < 0 || y < 0 || w < 1 || h < 1 || x + w > 12 || y + h > 12) continue;
        QVariantMap record;
        record.insert("activity_id", activity);
        record.insert("page_id", page);
        record.insert("endpoint_ref", ref);
        record.insert("name", item.value("name").toString("Video Stream").left(50));
        record.insert("location", QVariantMap{{"x", x}, {"y", y}});
        record.insert("size", QVariantMap{{"width", w}, {"height", h}});
        record.insert("decode_width", qBound(160, item.value("decode_width").toInt(640), 1280));
        record.insert("max_fps", qBound(1, item.value("max_fps").toInt(15), 30));
        m_items.append(record);
    }
    if (!m_watcher.files().contains(m_path)) m_watcher.addPath(m_path);
    ++m_revision;
    emit revisionChanged();
}

QString RtspDeviceConfig::resolveUrl(const QString &endpointRef) const {
    return m_urls.value(endpointRef);
}

QVariantList RtspDeviceConfig::widgetsForPage(const QString &activityId,
                                              const QString &pageId) const {
    QVariantList out;
    for (const QVariant &value : m_items) {
        const QVariantMap item = value.toMap();
        if (item.value("activity_id").toString() == activityId &&
            item.value("page_id").toString() == pageId)
            out.append(item);
    }
    return out;
}
