# Experimental reference decoder for Remote 3 Qt 5.15.
# The cross-toolchain must provide ARM64 FFmpeg pkg-config entries.
CONFIG += c++17 link_pkgconfig
PKGCONFIG += libavformat libavcodec libavutil libswscale
INCLUDEPATH += $$PWD
HEADERS += $PWD/RtspDeviceConfig.h \
           $PWD/RtspDecodeWorker.h \
           $$PWD/RtspNativeSurface.h
SOURCES += $PWD/RtspDeviceConfig.cpp \
           $PWD/RtspDecodeWorker.cpp \
           $$PWD/RtspNativeSurface.cpp
