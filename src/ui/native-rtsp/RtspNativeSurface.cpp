// SPDX-License-Identifier: GPL-3.0-or-later
#include "RtspNativeSurface.h"
#include "RtspDecodeWorker.h"
#include "RtspDeviceConfig.h"
#include <QPainter>
#include <QTimer>
#include <QtGlobal>

RtspNativeSurface::RtspNativeSurface(QQuickItem *parent)
    : QQuickPaintedItem(parent) {
    setFillColor(Qt::black);
    setOpaquePainting(true);
    setAntialiasing(false);
    if (RtspDeviceConfig::instance()) {
        QObject::connect(RtspDeviceConfig::instance(), &RtspDeviceConfig::revisionChanged,
                         this, [this] { if (m_active) start(); });
    }
    QObject::connect(this, &QQuickItem::visibleChanged, this, [this]() {
        if (m_active && isVisible()) start();
        else stop();
    });
}

RtspNativeSurface::~RtspNativeSurface() { stop(); }

void RtspNativeSurface::setEndpointRef(const QString &value) {
    if (value == m_endpointRef) return;
    m_endpointRef = value;
    emit endpointRefChanged();
    if (m_active) start();
}
void RtspNativeSurface::setActive(bool value) {
    if (value == m_active) return;
    m_active = value;
    emit activeChanged();
    if (m_active) start(); else stop();
}
void RtspNativeSurface::setDecodeWidth(int value) {
    value = qBound(160, value, 1280);
    if (value == m_decodeWidth) return;
    m_decodeWidth = value;
    emit decodeWidthChanged();
    if (m_active) start();
}
void RtspNativeSurface::setMaxFps(int value) {
    value = qBound(1, value, 30);
    if (value == m_maxFps) return;
    m_maxFps = value;
    emit maxFpsChanged();
    if (m_active) start();
}

void RtspNativeSurface::stop() {
    if (!m_worker) return;
    RtspDecodeWorker *old = m_worker;
    m_worker = nullptr;
    disconnect(old, nullptr, this, nullptr);
    old->requestStop();
    // Do not block the GUI thread waiting for camera network timeouts.
}

void RtspNativeSurface::start() {
    stop();
    m_frame = QImage();
    update();
    if (!m_active || !isVisible() || m_endpointRef.isEmpty()) return;
    const RtspDeviceConfig *config = RtspDeviceConfig::instance();
    if (!config) return;
    // Only the C++ decoder sees the URL. QML receives an opaque endpoint_ref.
    const QString url = config->resolveUrl(m_endpointRef);
    if (url.isEmpty()) return;
    auto *worker = new RtspDecodeWorker(url, m_decodeWidth, m_maxFps);
    m_worker = worker;
    QObject::connect(worker, &RtspDecodeWorker::frameDecoded, this,
        [this, worker](const QImage &frame) {
            if (m_worker != worker || !m_active || !isVisible()) return;
            m_frame = frame;
            update();
        }, Qt::QueuedConnection);
    QObject::connect(worker, &QThread::finished, worker, &QObject::deleteLater);
    worker->start();
}

void RtspNativeSurface::paint(QPainter *painter) {
    const QRectF bounds = boundingRect();
    painter->fillRect(bounds, Qt::black);
    if (m_frame.isNull()) return;
    const QSizeF natural = m_frame.size();
    const qreal scale = qMax(bounds.width() / natural.width(),
                             bounds.height() / natural.height());
    const QSizeF targetSize(natural.width() * scale, natural.height() * scale);
    const QRectF target(bounds.center().x() - targetSize.width() / 2,
                        bounds.center().y() - targetSize.height() / 2,
                        targetSize.width(), targetSize.height());
    painter->drawImage(target, m_frame);
}
