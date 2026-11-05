// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
#include "lovelaceFrame.h"

#include <QNetworkRequest>
#include <QPainter>
#include <QUrlQuery>

LovelaceFrame::LovelaceFrame(QQuickItem* parent) : QQuickPaintedItem(parent) {
    setAntialiasing(false);
    setFillColor(Qt::black);
    m_poll.setInterval(900);
    connect(&m_poll, &QTimer::timeout, this, &LovelaceFrame::refresh);
    connect(this, &QQuickItem::widthChanged, this, &LovelaceFrame::refresh);
    connect(this, &QQuickItem::heightChanged, this, &LovelaceFrame::refresh);
}

void LovelaceFrame::setRenderer(const QString& value) {
    if (m_renderer == value) return;
    m_renderer = value;
    ++m_generation;
    emit rendererChanged();
    refresh();
}
void LovelaceFrame::setDashboardUrl(const QString& value) {
    if (m_dashboardUrl == value) return;
    m_dashboardUrl = value;
    ++m_generation;
    m_lastBytes.clear();
    m_lastFrame = QImage();
    update();
    emit dashboardUrlChanged();
    refresh();
}
void LovelaceFrame::setActive(bool value) {
    if (m_active == value) return;
    m_active = value;
    emit activeChanged();
    if (value) refresh();
    else m_poll.stop();
}
void LovelaceFrame::setError(const QString& value) {
    if (m_error == value) return;
    m_error = value;
    emit errorChanged();
}

void LovelaceFrame::refresh() {
    if (m_active && !m_poll.isActive()) m_poll.start();
    if (!m_active || m_pending || m_dashboardUrl.isEmpty() ||
        m_renderer.isEmpty() || width() < 10 || height() < 10)
        return;
    const QUrl origin(m_renderer);
    if (!origin.isValid() || (origin.scheme() != "http" && origin.scheme() != "https") ||
        !origin.userInfo().isEmpty() || origin.host().isEmpty()) {
        setError(QStringLiteral("Invalid renderer address"));
        return;
    }
    QUrl endpoint = origin.resolved(QUrl(QStringLiteral("/frame")));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("url"), m_dashboardUrl);
    query.addQueryItem(QStringLiteral("width"), QString::number(qRound(width())));
    query.addQueryItem(QStringLiteral("height"), QString::number(qRound(height())));
    query.addQueryItem(QStringLiteral("v"), QString::number(++m_generation));
    endpoint.setQuery(query);

    QNetworkRequest request(endpoint);
    request.setRawHeader("Cache-Control", "no-cache");
    request.setAttribute(QNetworkRequest::FollowRedirectsAttribute, false);
    const quint64 generation = m_generation;
    QNetworkReply* reply = m_network.get(request);
    m_pending = reply;
    connect(reply, &QNetworkReply::finished, this, [this, reply, generation]() {
        if (m_pending == reply) m_pending = nullptr;
        const QByteArray bytes = reply->readAll();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (generation == m_generation && reply->error() == QNetworkReply::NoError && status == 200) {
            if (bytes != m_lastBytes) {
                QImage next = QImage::fromData(bytes, "JPEG");
                if (!next.isNull()) {
                    m_lastFrame = next;
                    m_lastBytes = bytes;
                    update();  // Same painted item and GPU surface: never swap QML Image objects.
                    setError(QString());
                } else {
                    setError(QStringLiteral("Invalid JPEG from renderer"));
                }
            }
        } else if (generation == m_generation) {
            setError(QStringLiteral("Renderer HTTP %1: %2").arg(status).arg(reply->errorString()));
        }
        reply->deleteLater();
    });
}
void LovelaceFrame::paint(QPainter* painter) {
    painter->fillRect(boundingRect(), Qt::black);
    if (!m_lastFrame.isNull()) painter->drawImage(boundingRect(), m_lastFrame);
}
