// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QByteArray>
#include <QImage>
#include <QProcess>
#include <QQuickPaintedItem>
#include <QTimer>

// Decodes RTSP on the remote using a local FFmpeg executable. The UI needs no
// GStreamer, network streaming service, or FFmpeg development libraries.
class RtspStream : public QQuickPaintedItem {
    Q_OBJECT
    Q_PROPERTY(QString source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(int frameRate READ frameRate WRITE setFrameRate NOTIFY frameRateChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(bool playing READ playing NOTIFY playingChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)

 public:
    explicit RtspStream(QQuickItem *parent = nullptr);
    ~RtspStream() override;

    QString source() const { return m_source; }
    void setSource(const QString &source);
    int frameRate() const { return m_frameRate; }
    void setFrameRate(int frameRate);
    bool active() const { return m_active; }
    void setActive(bool active);
    bool playing() const { return m_playing; }
    QString error() const { return m_error; }

    void paint(QPainter *painter) override;

 signals:
    void sourceChanged();
    void frameRateChanged();
    void activeChanged();
    void playingChanged();
    void errorChanged();

 private:
    void startStream();
    void stopStream();
    void readFrames();
    void onProcessError(QProcess::ProcessError error);
    void onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus);
    QString failureDetail(int exitCode, QProcess::ExitStatus exitStatus) const;
    void setPlaying(bool playing);
    void setError(const QString &error);

    static constexpr int FrameWidth = 320;
    static constexpr int FrameHeight = 180;
    static constexpr int FrameBytes = FrameWidth * FrameHeight * 2;  // RGB565

    QString m_source;
    QString m_error;
    int m_frameRate = 10;
    bool m_active = false;
    bool m_reconfigurePending = false;
    bool m_playing = false;
    QProcess m_process;
    QTimer m_retryTimer;
    QTimer m_watchdogTimer;
    QByteArray m_buffer;
    QByteArray m_diagnostics;
    QImage m_frame;
};
