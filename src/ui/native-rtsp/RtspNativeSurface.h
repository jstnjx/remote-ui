// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QImage>
#include <QPointer>
#include <QQuickPaintedItem>
#include <QString>
class QPainter;
class RtspDecodeWorker;

// An RTSP presentation item for Qt Quick on Remote Two/3.
// Input must be a direct rtsp:// or rtsps:// camera URL, not an HTTP sidecar.
class RtspNativeSurface final : public QQuickPaintedItem {
    Q_OBJECT
    Q_PROPERTY(QString endpointRef READ endpointRef WRITE setEndpointRef NOTIFY endpointRefChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(int decodeWidth READ decodeWidth WRITE setDecodeWidth NOTIFY decodeWidthChanged)
    Q_PROPERTY(int maxFps READ maxFps WRITE setMaxFps NOTIFY maxFpsChanged)
public:
    explicit RtspNativeSurface(QQuickItem *parent = nullptr);
    ~RtspNativeSurface() override;
    QString endpointRef() const { return m_endpointRef; }
    bool active() const { return m_active; }
    int decodeWidth() const { return m_decodeWidth; }
    int maxFps() const { return m_maxFps; }
    void setEndpointRef(const QString &ref);
    void setActive(bool value);
    void setDecodeWidth(int value);
    void setMaxFps(int value);
    void paint(QPainter *painter) override;
signals:
    void endpointRefChanged();
    void activeChanged();
    void decodeWidthChanged();
    void maxFpsChanged();
private:
    void start();
    void stop();
    QString m_endpointRef;
    bool m_active = false;
    int m_decodeWidth = 640;
    int m_maxFps = 15;
    QPointer<RtspDecodeWorker> m_worker;
    QImage m_frame;
};
