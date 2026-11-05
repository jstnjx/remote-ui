// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QByteArray>
#include <QImage>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QQuickPaintedItem>
#include <QTimer>
#include <QUrl>

class LovelaceFrame : public QQuickPaintedItem {
    Q_OBJECT
    Q_PROPERTY(QString renderer READ renderer WRITE setRenderer NOTIFY rendererChanged)
    Q_PROPERTY(QString dashboardUrl READ dashboardUrl WRITE setDashboardUrl NOTIFY dashboardUrlChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)

public:
    explicit LovelaceFrame(QQuickItem* parent = nullptr);
    QString renderer() const { return m_renderer; }
    QString dashboardUrl() const { return m_dashboardUrl; }
    bool active() const { return m_active; }
    QString error() const { return m_error; }
    void setRenderer(const QString& value);
    void setDashboardUrl(const QString& value);
    void setActive(bool value);
    void paint(QPainter* painter) override;

    Q_INVOKABLE void refresh();

signals:
    void rendererChanged();
    void dashboardUrlChanged();
    void activeChanged();
    void errorChanged();

private:
    void setError(const QString& value);
    QNetworkAccessManager m_network;
    QNetworkReply* m_pending = nullptr;
    QTimer m_poll;
    QImage m_lastFrame;
    QByteArray m_lastBytes;
    QString m_renderer;
    QString m_dashboardUrl;
    QString m_error;
    bool m_active = true;
    quint64 m_generation = 0;
};
