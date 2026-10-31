// SPDX-License-Identifier: GPL-3.0-or-later
#include "RtspDecodeWorker.h"

#include <QElapsedTimer>
#include <QtGlobal>
#include <algorithm>
#include <utility>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/error.h>
#include <libavutil/time.h>
#include <libswscale/swscale.h>
}

namespace {
QString errorText(int code) {
    char data[AV_ERROR_MAX_STRING_SIZE] = {};
    av_strerror(code, data, sizeof(data));
    return QString::fromUtf8(data);
}
}

RtspDecodeWorker::RtspDecodeWorker(QString rtspUrl, int targetWidth, int maxFps,
                                 QObject *parent)
    : QThread(parent), m_rtspUrl(std::move(rtspUrl)),
      m_targetWidth(qBound(160, targetWidth, 1280)),
      m_maxFps(qBound(1, maxFps, 30)) {}

RtspDecodeWorker::~RtspDecodeWorker() {
    requestStop();
    // FFmpeg's interrupt_callback ensures that an interrupted network read
    // unwinds. Never delete a QThread while its run() is active.
    wait();
}

void RtspDecodeWorker::requestStop() {
    m_stop.store(true, std::memory_order_release);
}

int RtspDecodeWorker::interrupt(void *opaque) {
    auto *worker = static_cast<RtspDecodeWorker *>(opaque);
    return worker->m_stop.load(std::memory_order_acquire) ||
           (worker->m_deadlineUs.load(std::memory_order_relaxed) &&
            av_gettime_relative() >
                worker->m_deadlineUs.load(std::memory_order_relaxed));
}

void RtspDecodeWorker::run() {
    avformat_network_init();
    int retryMs = 500;
    while (!m_stop.load(std::memory_order_acquire)) {
        if (decodeSession()) retryMs = 500;
        // Reconnect after a failed/ended stream, but stop rapidly on hide.
        for (int remaining = retryMs;
             remaining > 0 && !m_stop.load(std::memory_order_acquire);
             remaining -= 50)
            QThread::msleep(static_cast<unsigned long>(std::min(remaining, 50)));
        retryMs = std::min(retryMs * 2, 8000);
    }
}

bool RtspDecodeWorker::decodeSession() {
    const QByteArray url = m_rtspUrl.toUtf8();
    if (!(url.startsWith("rtsp://") || url.startsWith("rtsps://"))) {
        emit streamError(QStringLiteral("RTSP URL must use rtsp:// or rtsps://"));
        requestStop();
        return false;
    }

    AVFormatContext *format = avformat_alloc_context();
    if (!format) { emit streamError(QStringLiteral("FFmpeg allocation failed")); return false; }
    format->interrupt_callback.callback = &RtspDecodeWorker::interrupt;
    format->interrupt_callback.opaque = this;

    AVDictionary *opts = nullptr;
    av_dict_set(&opts, "rtsp_transport", "tcp", 0);
    av_dict_set(&opts, "rw_timeout", "7000000", 0);
    m_deadlineUs.store(av_gettime_relative() + 8000000, std::memory_order_relaxed);
    const int openResult = avformat_open_input(&format, url.constData(), nullptr, &opts);
    av_dict_free(&opts);
    if (openResult < 0) {
        if (format) avformat_close_input(&format);
        if (!m_stop.load()) emit streamError(QStringLiteral("RTSP connect: ") + errorText(openResult));
        return false;
    }
    m_deadlineUs.store(av_gettime_relative() + 8000000, std::memory_order_relaxed);

    const int info = avformat_find_stream_info(format, nullptr);
    if (info < 0) {
        if (!m_stop.load()) emit streamError(QStringLiteral("RTSP stream info: ") + errorText(info));
        avformat_close_input(&format);
        return false;
    }

    const int index = av_find_best_stream(format, AVMEDIA_TYPE_VIDEO, -1, -1, nullptr, 0);
    if (index < 0) {
        emit streamError(QStringLiteral("No video stream available"));
        avformat_close_input(&format);
        return false;
    }

    const AVCodecParameters *params = format->streams[index]->codecpar;
    const AVCodec *codec = avcodec_find_decoder(params->codec_id);
    AVCodecContext *decoder = codec ? avcodec_alloc_context3(codec) : nullptr;
    if (!decoder) {
        emit streamError(QStringLiteral("Video codec not available in device FFmpeg"));
        avformat_close_input(&format);
        return false;
    }

    int result = avcodec_parameters_to_context(decoder, params);
    if (result >= 0) result = avcodec_open2(decoder, codec, nullptr);
    if (result < 0) {
        emit streamError(QStringLiteral("Cannot initialize decoder: ") + errorText(result));
        avcodec_free_context(&decoder);
        avformat_close_input(&format);
        return false;
    }

    AVPacket *packet = av_packet_alloc();
    AVFrame *frame = av_frame_alloc();
    SwsContext *sws = nullptr;
    bool producedFrame = false;
    QElapsedTimer displayed;
    displayed.invalidate();
    const int minIntervalMs = 1000 / m_maxFps;

    if (!packet || !frame) {
        emit streamError(QStringLiteral("Frame allocation failed"));
    } else {
        while (!m_stop.load(std::memory_order_acquire)) {
            m_deadlineUs.store(av_gettime_relative() + 8000000, std::memory_order_relaxed);
            result = av_read_frame(format, packet);
            if (result < 0) break;
            if (packet->stream_index == index) {
                result = avcodec_send_packet(decoder, packet);
                if (result >= 0) {
                    while (!m_stop.load() && avcodec_receive_frame(decoder, frame) == 0) {
                        if (frame->width <= 0 || frame->height <= 0) {
                            av_frame_unref(frame);
                            continue;
                        }
                        if (displayed.isValid() && displayed.elapsed() < minIntervalMs) {
                            av_frame_unref(frame);
                            continue;
                        }
                        const int w = std::min(m_targetWidth, frame->width);
                        const int h = std::max(2, (frame->height * w / frame->width) & ~1);
                        QImage image(w, h, QImage::Format_RGB888);
                        if (image.isNull()) {
                            av_frame_unref(frame);
                            continue;
                        }
                        sws = sws_getCachedContext(
                            sws, frame->width, frame->height,
                            static_cast<AVPixelFormat>(frame->format), w, h,
                            AV_PIX_FMT_RGB24, SWS_BILINEAR, nullptr, nullptr, nullptr);
                        if (sws) {
                            uint8_t *out[] = {image.bits(), nullptr, nullptr, nullptr};
                            const int lines[] = {image.bytesPerLine(), 0, 0, 0};
                            if (sws_scale(sws, frame->data, frame->linesize, 0,
                                          frame->height, out, lines) > 0) {
                                emit frameDecoded(image.copy());
                                displayed.restart();
                                producedFrame = true;
                            }
                        }
                        av_frame_unref(frame);
                    }
                }
            }
            av_packet_unref(packet);
        }
    }
    if (sws) sws_freeContext(sws);
    av_frame_free(&frame);
    av_packet_free(&packet);
    avcodec_free_context(&decoder);
    avformat_close_input(&format);
    m_deadlineUs.store(0, std::memory_order_relaxed);
    if (!m_stop.load()) emit streamError(QStringLiteral("RTSP stream ended or stalled"));
    return producedFrame;
}
