// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QByteArray>
#include <QElapsedTimer>
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
    Q_PROPERTY(int resolution READ resolution WRITE setResolution NOTIFY resolutionChanged)
    Q_PROPERTY(bool autoQuality READ autoQuality WRITE setAutoQuality NOTIFY autoQualityChanged)
    Q_PROPERTY(double actualFps READ actualFps NOTIFY statsChanged)
    Q_PROPERTY(double cpuPercent READ cpuPercent NOTIFY statsChanged)
    Q_PROPERTY(int effectiveWidth READ effectiveWidth NOTIFY statsChanged)
    Q_PROPERTY(int effectiveHeight READ effectiveHeight NOTIFY statsChanged)
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
    int resolution() const { return m_resolution; }
    void setResolution(int resolution);
    bool autoQuality() const { return m_autoQuality; }
    void setAutoQuality(bool enabled);
    double actualFps() const { return m_actualFps; }
    double cpuPercent() const { return m_cpuPercent; }
    int effectiveWidth() const { return m_frameWidth; }
    int effectiveHeight() const { return m_frameHeight; }
    bool active() const { return m_active; }
    void setActive(bool active);
    bool playing() const { return m_playing; }
    QString error() const { return m_error; }

    void paint(QPainter *painter) override;

 signals:
    void sourceChanged();
    void frameRateChanged();
    void resolutionChanged();
    void autoQualityChanged();
    void statsChanged();
    void activeChanged();
    void playingChanged();
    void errorChanged();

 private:
    void startStream();
    void reconfigure();
    void updateStats();
    void stopStream();
    void readFrames();
    void onProcessError(QProcess::ProcessError error);
    void onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus);
    QString failureDetail(int exitCode, QProcess::ExitStatus exitStatus) const;
    void setPlaying(bool playing);
    void setError(const QString &error);


    QString m_source;
    QString m_error;
    int m_frameRate = 10;
    int m_resolution = 0;
    int m_effectiveResolution = 0;
    int m_frameWidth = 320;
    int m_frameHeight = 180;
    int m_frameBytes = 320 * 180 * 2;
    bool m_autoQuality = true;
    double m_actualFps = 0;
    double m_cpuPercent = -1;
    int m_framesShown = 0;
    qint64 m_lastCpuTicks = -1;
    int m_hotSamples = 0;
    QElapsedTimer m_statsClock;
    QTimer m_statsTimer;
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
