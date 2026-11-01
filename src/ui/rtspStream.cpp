// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
#include "rtspStream.h"

#include <QCoreApplication>
#include <QFileInfo>
#include <QPainter>
#include <QRegularExpression>
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
    // Keep a bounded buffer of FFmpeg diagnostics. Never log or display raw
    // stderr: error lines can contain camera credentials embedded in the URL.
    connect(&m_process, &QProcess::readyReadStandardError, this, [this] {
        m_diagnostics.append(m_process.readAllStandardError());
        if (m_diagnostics.size() > 8192) {
            m_diagnostics = m_diagnostics.right(8192);
        }
    });
    connect(&m_process, &QProcess::errorOccurred, this, &RtspStream::onProcessError);
    connect(&m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this,
            &RtspStream::onProcessFinished);
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
    m_diagnostics.clear();
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
        QStringLiteral("-timeout"), QStringLiteral("5000000"),
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
    m_diagnostics.clear();
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

QString RtspStream::failureDetail(int exitCode, QProcess::ExitStatus exitStatus) const {
    // Check known failures before showing the final FFmpeg line, which is
    // frequently just "Error opening input files".
    const QString lower = QString::fromUtf8(m_diagnostics).toLower();
    if (lower.contains(QStringLiteral("401 unauthorized")) ||
        lower.contains(QStringLiteral("401 (unauthorized")) ||
        lower.contains(QStringLiteral("server returned 401")) ||
        lower.contains(QStringLiteral("403 forbidden"))) {
        return tr("Camera authentication failed (401/403). Check RTSP credentials.");
    }
    if (lower.contains(QStringLiteral("404 not found")) || lower.contains(QStringLiteral("404 (not found"))) {
        return tr("Camera stream not found (404). Check the RTSP path.");
    }
    if (lower.contains(QStringLiteral("461 unsupported transport")) ||
        lower.contains(QStringLiteral("unsupported transport"))) {
        return tr("Camera rejected RTSP over TCP (461).");
    }
    if (lower.contains(QStringLiteral("connection refused"))) {
        return tr("RTSP connection refused. Check camera host and port.");
    }
    if (lower.contains(QStringLiteral("connection timed out")) ||
        lower.contains(QStringLiteral("timed out"))) {
        return tr("RTSP connection timed out. Check camera network access.");
    }
    if (lower.contains(QStringLiteral("network is unreachable")) ||
        lower.contains(QStringLiteral("no route to host"))) {
        return tr("Camera network unreachable from the remote.");
    }
    if (lower.contains(QStringLiteral("option not found")) ||
        lower.contains(QStringLiteral("unrecognized option"))) {
        return tr("FFmpeg does not support an input option.");
    }
    if (lower.contains(QStringLiteral("no such filter")) ||
        lower.contains(QStringLiteral("error reinitializing filters")) ||
        lower.contains(QStringLiteral("error while filtering"))) {
        return tr("FFmpeg video filter failed.");
    }
    if (lower.contains(QStringLiteral("unknown decoder")) ||
        lower.contains(QStringLiteral("decoder not found")) ||
        lower.contains(QStringLiteral("unsupported codec"))) {
        return tr("Camera video codec is not supported.");
    }
    if (exitStatus == QProcess::CrashExit) {
        return tr("FFmpeg was terminated (signal/crash). Try an H.264 low-resolution camera substream.");
    }

    // Show one short, sanitized diagnostic when FFmpeg reports a new error.
    // Never expose RTSP URLs or usernames/passwords in the UI.
    QString diagnostic = QString::fromUtf8(m_diagnostics);
    const QRegularExpression rtspUrl(QStringLiteral("rtsps?://[^\\s\\\"'<>]+"),
                                     QRegularExpression::CaseInsensitiveOption);
    diagnostic.replace(rtspUrl, QStringLiteral("[RTSP URL]"));
    const QUrl url(m_source);
    if (!url.password().isEmpty()) {
        diagnostic.replace(url.password(), QStringLiteral("[redacted]"));
        diagnostic.replace(QString::fromUtf8(QUrl::toPercentEncoding(url.password())), QStringLiteral("[redacted]"));
    }
    if (!url.userName().isEmpty()) {
        diagnostic.replace(url.userName(), QStringLiteral("[redacted]"));
    }
    const QStringList lines = diagnostic.split(QRegularExpression(QStringLiteral("[\\r\\n]+")),
                                               Qt::SkipEmptyParts);
    if (!lines.isEmpty()) {
        return tr("FFmpeg: %1").arg(lines.last().trimmed().left(180));
    }
    return tr("FFmpeg exited (code %1). Check the camera stream.").arg(exitCode);
}

void RtspStream::onProcessError(QProcess::ProcessError error) {
    if (!m_active) {
        return;
    }
    if (error == QProcess::FailedToStart) {
        setError(tr("FFmpeg could not start. Check ARM64 compatibility and file permissions."));
    } else if (error == QProcess::Crashed) {
        setError(tr("FFmpeg crashed or was terminated. Try a low-resolution H.264 stream."));
    } else {
        setError(tr("FFmpeg process error (%1).").arg(static_cast<int>(error)));
    }
    m_watchdogTimer.stop();
    m_retryTimer.start();
}

void RtspStream::onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus) {
    // Read stderr that arrived between the last readyRead signal and exit.
    m_diagnostics.append(m_process.readAllStandardError());
    if (m_diagnostics.size() > 8192) {
        m_diagnostics = m_diagnostics.right(8192);
    }
    m_watchdogTimer.stop();
    m_buffer.clear();
    m_frame = QImage();
    setPlaying(false);
    update();
    if (m_active) {
        if (m_error.isEmpty()) {
            setError(failureDetail(exitCode, exitStatus));
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
