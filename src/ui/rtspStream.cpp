// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
#include "rtspStream.h"

#include <QCoreApplication>
#include <QFileInfo>
#include <QPainter>
#include <QStandardPaths>
#include <QUrl>

RtspStream::RtspStream(QQuickItem *parent) : QQuickPaintedItem(parent), m_process(this) {
    setFillColor(Qt::black);
    setAntialiasing(false);

    m_retryTimer.setSingleShot(true);
    m_retryTimer.setInterval(3000);
    connect(&m_retryTimer, &QTimer::timeout, this, &RtspStream::startStream);

    m_watchdogTimer.setSingleShot(true);
    m_watchdogTimer.setInterval(12000);
    connect(&m_watchdogTimer, &QTimer::timeout, this, [this] {
        if (!m_active) {
            return;
        }
        setError(tr("No video received. Reconnecting..."));
        if (m_process.state() != QProcess::NotRunning) {
            m_process.kill();
        }
    });

    connect(&m_process, &QProcess::readyReadStandardOutput, this, &RtspStream::readFrames);
    // Always drain stderr; FFmpeg output can contain credentials in an RTSP URL,
    // so it is intentionally neither logged nor shown on the device.
    connect(&m_process, &QProcess::readyReadStandardError, this, [this] {
        m_process.readAllStandardError();
    });
    connect(&m_process, &QProcess::errorOccurred, this, &RtspStream::onProcessError);
    connect(&m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this,
            [this](int, QProcess::ExitStatus) { onProcessFinished(); });
}

RtspStream::~RtspStream() {
    m_active = false;
    m_retryTimer.stop();
    m_watchdogTimer.stop();
    if (m_process.state() != QProcess::NotRunning) {
        m_process.kill();
        m_process.waitForFinished(500);
    }
}

void RtspStream::setSource(const QString &source) {
    const QString value = source.trimmed();
    if (m_source == value) {
        return;
    }
    m_source = value;
    emit sourceChanged();
    stopStream();
    if (m_active && m_process.state() == QProcess::NotRunning) {
        startStream();
    }
}

void RtspStream::setActive(bool active) {
    if (m_active == active) {
        return;
    }
    m_active = active;
    emit activeChanged();
    if (active) {
        if (m_process.state() == QProcess::NotRunning) {
            startStream();
        }
    } else {
        stopStream();
    }
}

void RtspStream::setPlaying(bool playing) {
    if (m_playing != playing) {
        m_playing = playing;
        emit playingChanged();
    }
}

void RtspStream::setError(const QString &error) {
    if (m_error != error) {
        m_error = error;
        emit errorChanged();
    }
}

void RtspStream::stopStream() {
    m_retryTimer.stop();
    m_watchdogTimer.stop();
    m_buffer.clear();
    m_frame = QImage();
    setPlaying(false);
    setError(QString());
    update();
    if (m_process.state() != QProcess::NotRunning) {
        m_process.kill();
    }
}

void RtspStream::startStream() {
    if (!m_active || m_process.state() != QProcess::NotRunning) {
        return;
    }

    const QUrl url(m_source);
    if (!url.isValid() || url.scheme().compare(QStringLiteral("rtsp"), Qt::CaseInsensitive) != 0 ||
        url.host().isEmpty()) {
        setError(tr("Invalid RTSP address"));
        return;
    }

    // A custom UI package may include bin/ffmpeg. Otherwise use the FFmpeg
    // already installed on the device. Operators may override the binary path.
    QString program = QString::fromLocal8Bit(qgetenv("UC_RTSP_FFMPEG")).trimmed();
    if (program.isEmpty()) {
        const QString bundled = QCoreApplication::applicationDirPath() + QStringLiteral("/ffmpeg");
        if (QFileInfo(bundled).isExecutable()) {
            program = bundled;
        } else {
            program = QStandardPaths::findExecutable(QStringLiteral("ffmpeg"));
        }
    }
    if (program.isEmpty() || !QFileInfo(program).isExecutable()) {
        setError(tr("FFmpeg is not installed on the remote"));
        return;
    }

    // Decode only 10 fps to a small RGB565 buffer to limit RAM, GPU uploads,
    // and software rendering work. The camera's own low-resolution substream
    // is recommended because decoding its source resolution still costs CPU.
    const QStringList arguments = {
        QStringLiteral("-hide_banner"), QStringLiteral("-loglevel"), QStringLiteral("error"),
        QStringLiteral("-nostdin"), QStringLiteral("-rtsp_transport"), QStringLiteral("tcp"),
        QStringLiteral("-rw_timeout"), QStringLiteral("5000000"),
        QStringLiteral("-i"), m_source,
        QStringLiteral("-map"), QStringLiteral("0:v:0"),
        QStringLiteral("-an"), QStringLiteral("-sn"), QStringLiteral("-dn"),
        QStringLiteral("-vf"),
        QStringLiteral("fps=10,scale=320:180:force_original_aspect_ratio=decrease:flags=fast_bilinear,"
                       "pad=320:180:(ow-iw)/2:(oh-ih)/2"),
        QStringLiteral("-pix_fmt"), QStringLiteral("rgb565le"),
        QStringLiteral("-f"), QStringLiteral("rawvideo"), QStringLiteral("pipe:1")
    };

    m_buffer.clear();
    setError(QString());
    m_process.start(program, arguments, QIODevice::ReadOnly);
    m_watchdogTimer.start();
}

void RtspStream::readFrames() {
    m_buffer.append(m_process.readAllStandardOutput());

    // Keep only the newest complete frame. Remove whole frames to preserve
    // frame boundaries even if stdout ends with a partial frame.
    const int completeFrames = m_buffer.size() / FrameBytes;
    if (completeFrames > 1) {
        m_buffer.remove(0, (completeFrames - 1) * FrameBytes);
    }
    if (m_buffer.size() < FrameBytes) {
        return;
    }

    // copy() owns pixel storage after we reuse m_buffer.
    m_frame = QImage(reinterpret_cast<const uchar *>(m_buffer.constData()), FrameWidth, FrameHeight,
                     FrameWidth * 2, QImage::Format_RGB16).copy();
    m_buffer.remove(0, FrameBytes);
    if (!m_frame.isNull()) {
        m_watchdogTimer.start();
        setError(QString());
        setPlaying(true);
        update();
    }
}

void RtspStream::onProcessError(QProcess::ProcessError) {
    if (m_active) {
        setError(tr("Video decoder failed. Retrying..."));
        m_watchdogTimer.stop();
        m_retryTimer.start();
    }
}

void RtspStream::onProcessFinished() {
    m_watchdogTimer.stop();
    m_buffer.clear();
    m_frame = QImage();
    setPlaying(false);
    update();
    if (m_active) {
        if (m_error.isEmpty()) {
            setError(tr("Stream disconnected. Reconnecting..."));
        }
        m_retryTimer.start();
    }
}

void RtspStream::paint(QPainter *painter) {
    painter->fillRect(boundingRect(), Qt::black);
    if (m_frame.isNull()) {
        return;
    }
    const QSizeF original(m_frame.size());
    QSizeF fitted = original;
    fitted.scale(boundingRect().size(), Qt::KeepAspectRatio);
    const QRectF rect((width() - fitted.width()) / 2.0, (height() - fitted.height()) / 2.0,
                      fitted.width(), fitted.height());
    painter->setRenderHint(QPainter::SmoothPixmapTransform, false);
    painter->drawImage(rect, m_frame);
}
