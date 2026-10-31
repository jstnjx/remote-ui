// Copyright (c) 2026 UCOS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
#include "rtspMjpegSurface.h"

#include <QDebug>
#include <QMutexLocker>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QPainter>
#include <QUrl>

namespace uc {
namespace ui {

RtspMjpegSurface::RtspMjpegSurface(QQuickItem *parent)
    : QQuickPaintedItem(parent) {
    setAntialiasing(false);
    setFillColor(Qt::black);
    setOpaquePainting(true);
    m_retry.setSingleShot(true);
    QObject::connect(&m_retry, &QTimer::timeout, this, &RtspMjpegSurface::start);

    m_watchdog.setInterval(1500);
    QObject::connect(&m_watchdog, &QTimer::timeout, this, [this]() {
        if (!m_active || !m_reply) return;
        // Startup can take longer than subsequent frames. Reset the connection
        // when FFmpeg stops producing complete JPEGs without closing HTTP.
        const bool stalled = m_frameClock.isValid()
            ? m_frameClock.elapsed() > 6000
            : m_connectClock.isValid() && m_connectClock.elapsed() > 12000;
        if (stalled) scheduleReconnect(QStringLiteral("stream stalled"));
    });
}

RtspMjpegSurface::~RtspMjpegSurface() { stop(); }

void RtspMjpegSurface::setStreamUrl(const QString &value) {
    if (m_streamUrl == value) return;
    m_streamUrl = value;
    emit streamUrlChanged();
    if (m_active) start();
}

void RtspMjpegSurface::setViewToken(const QString &value) {
    if (m_viewToken == value) return;
    m_viewToken = value;
    emit viewTokenChanged();
    if (m_active) start();
}

void RtspMjpegSurface::setActive(bool value) {
    if (m_active == value) return;
    m_active = value;
    emit activeChanged();
    if (m_active) start();
    else stop();
}

void RtspMjpegSurface::start() {
    stop();
    if (!m_active || m_streamUrl.isEmpty() || m_viewToken.isEmpty()) return;

    const QUrl url(m_streamUrl);
    if (!url.isValid() || (url.scheme() != QLatin1String("http")
                           && url.scheme() != QLatin1String("https"))) {
        qWarning() << "RTSP MJPEG: invalid streaming URL";
        return;
    }

    QNetworkRequest request(url);
    request.setRawHeader("Accept", "multipart/x-mixed-replace");
    // Authorization remains an HTTP header, never part of a logged URL.
    request.setRawHeader("Authorization", "Bearer " + m_viewToken.toUtf8());
    request.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::AlwaysNetwork);
    request.setAttribute(QNetworkRequest::FollowRedirectsAttribute, false);

    m_buffer.clear();
    m_frameClock.invalidate();
    m_connectClock.start();
    m_reply = m_network.get(request);
    QNetworkReply *reply = m_reply.data();
    QObject::connect(reply, &QIODevice::readyRead, this, [this, reply]() {
        if (reply != m_reply.data()) return;
        consume(reply->readAll());
    });
    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        if (reply != m_reply.data()) return;
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        scheduleReconnect(QStringLiteral("stream disconnected (HTTP %1)").arg(status));
    });
    m_watchdog.start();
}

void RtspMjpegSurface::stop() {
    m_retry.stop();
    m_watchdog.stop();
    if (m_reply) {
        QNetworkReply *reply = m_reply.data();
        m_reply.clear();
        QObject::disconnect(reply, nullptr, this, nullptr);
        reply->abort();
        reply->deleteLater();
    }
    m_buffer.clear();
}

void RtspMjpegSurface::scheduleReconnect(const QString &reason) {
    if (!m_active) return;
    qWarning() << "RTSP MJPEG:" << reason << "- reconnecting";
    stop();
    const int delay = m_backoffMs;
    m_backoffMs = qMin(m_backoffMs * 2, 8000);
    m_retry.start(delay);
}

void RtspMjpegSurface::consume(const QByteArray &bytes) {
    m_buffer.append(bytes);
    const QByteArray soi = QByteArray::fromHex("ffd8");
    const QByteArray eoi = QByteArray::fromHex("ffd9");
    bool gotFrame = false;
    for (;;) {
        const int first = m_buffer.indexOf(soi);
        if (first < 0) {
            // Preserve a trailing FF in case the JPEG SOI (FF D8) is split
            // across consecutive network chunks.
            const bool partialSoi = !m_buffer.isEmpty()
                && static_cast<unsigned char>(m_buffer.at(m_buffer.size() - 1)) == 0xff;
            m_buffer = partialSoi ? QByteArray(1, static_cast<char>(0xff)) : QByteArray();
            break;
        }
        if (first > 0) m_buffer.remove(0, first);
        const int last = m_buffer.indexOf(eoi, 2);
        if (last < 0) break;
        const QByteArray jpeg = m_buffer.left(last + 2);
        m_buffer.remove(0, last + 2);
        QImage decoded = QImage::fromData(jpeg, "JPG");
        if (!decoded.isNull()) {
            {
                QMutexLocker lock(&m_frameMutex);
                m_frame = decoded;
            }
            m_frameClock.restart();
            m_backoffMs = 500;
            gotFrame = true;
        }
    }
    // Bound corrupted or unexpectedly large responses to avoid RAM growth.
    if (m_buffer.size() > 4 * 1024 * 1024) m_buffer.clear();
    if (gotFrame) update();
}

void RtspMjpegSurface::paint(QPainter *painter) {
    QImage frame;
    {
        QMutexLocker lock(&m_frameMutex);
        frame = m_frame; // implicitly shared until the next frame arrives
    }
    const QRectF dst = boundingRect();
    painter->fillRect(dst, Qt::black);
    if (frame.isNull() || dst.isEmpty()) return;

    const qreal imageWidth = frame.width();
    const qreal imageHeight = frame.height();
    const qreal dstAspect = dst.width() / dst.height();
    const qreal frameAspect = imageWidth / imageHeight;
    QRectF src(0, 0, imageWidth, imageHeight);
    if (frameAspect > dstAspect) {
        const qreal width = imageHeight * dstAspect;
        src.setX((imageWidth - width) / 2.0);
        src.setWidth(width);
    } else {
        const qreal height = imageWidth / dstAspect;
        src.setY((imageHeight - height) / 2.0);
        src.setHeight(height);
    }
    painter->drawImage(dst, frame, src);
}

} // namespace ui
} // namespace uc
