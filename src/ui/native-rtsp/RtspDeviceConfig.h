// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QObject>
#include <QHash>
#include <QString>
#include <QVariantList>
#include <QFileSystemWatcher>

// Temporary device-local configuration adapter until Core can persist
// Video Stream widgets. Never exposes camera URLs to QML.
class RtspDeviceConfig final : public QObject {
    Q_OBJECT
    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged)
public:
    explicit RtspDeviceConfig(QObject *parent = nullptr);
    ~RtspDeviceConfig() override;
    static RtspDeviceConfig *instance();
    int revision() const { return m_revision; }
    Q_INVOKABLE QVariantList widgetsForPage(const QString &activityId,
                                           const QString &pageId) const;
    // C++ only (deliberately NOT Q_INVOKABLE): never return URLs to QML.
    QString resolveUrl(const QString &endpointRef) const;
signals:
    void revisionChanged();
private:
    void reload();
    QString m_path;
    QHash<QString, QString> m_urls;
    QVariantList m_items;
    QFileSystemWatcher m_watcher;
    int m_revision = 0;
    static RtspDeviceConfig *s_instance;
};
