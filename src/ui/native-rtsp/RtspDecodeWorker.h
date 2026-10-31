// Copyright (c) 2026 UCOS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QImage>
#include <QThread>
#include <QString>
#include <atomic>
#include <cstdint>

// A native, in-process FFmpeg RTSP reader. No FFmpeg subprocess or HTTP proxy.
class RtspDecodeWorker final : public QThread {
    Q_OBJECT
public:
    explicit RtspDecodeWorker(QString rtspUrl, int targetWidth = 640,
                              int maxFps = 15, QObject *parent = nullptr);
    void requestStop();
    ~RtspDecodeWorker() override;

signals:
    void frameDecoded(const QImage &frame);
    void streamError(const QString &message);

protected:
    void run() override;

private:
    static int interrupt(void *opaque);
    bool decodeSession();

    QString m_rtspUrl;
    const int m_targetWidth;
    const int m_maxFps;
    std::atomic_bool m_stop {false};
    std::atomic<int64_t> m_deadlineUs {0};
};
