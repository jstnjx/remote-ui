// Copyright (c) 2026 UCOS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QByteArray>
#include <QElapsedTimer>
#include <QImage>
#include <QMutex>
#include <QNetworkAccessManager>
#include <QPointer>
#include <QQuickPaintedItem>
#include <QTimer>

class QNetworkReply;
class QPainter;

namespace uc {
namespace ui {

// Renders a persistent HTTP multipart MJPEG connection directly to Qt Quick.
// Unlike Qt 5 AVFoundation HLS playback, each painted frame is a real JPEG
// received from the stream rather than a frozen PlayingState.
class RtspMjpegSurface : public QQuickPaintedItem {
    Q_OBJECT
    Q_PROPERTY(QString streamUrl READ streamUrl WRITE setStreamUrl NOTIFY streamUrlChanged)
    Q_PROPERTY(QString viewToken READ viewToken WRITE setViewToken NOTIFY viewTokenChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)

public:
    explicit RtspMjpegSurface(QQuickItem *parent = nullptr);
    ~RtspMjpegSurface() override;

    QString streamUrl() const { return m_streamUrl; }
    QString viewToken() const { return m_viewToken; }
    bool active() const { return m_active; }

    void setStreamUrl(const QString &value);
    void setViewToken(const QString &value);
    void setActive(bool value);
    void paint(QPainter *painter) override;

signals:
    void streamUrlChanged();
    void viewTokenChanged();
    void activeChanged();

private:
    void start();
    void stop();
    void scheduleReconnect(const QString &reason);
    void consume(const QByteArray &bytes);

    QString m_streamUrl;
    QString m_viewToken;
    bool m_active = false;
    QNetworkAccessManager m_network;
    QPointer<QNetworkReply> m_reply;
    QTimer m_watchdog;
    QTimer m_retry;
    QElapsedTimer m_connectClock;
    QElapsedTimer m_frameClock;
    QByteArray m_buffer;
    QMutex m_frameMutex;
    QImage m_frame;
    int m_backoffMs = 500;
};

} // namespace ui
} // namespace uc
