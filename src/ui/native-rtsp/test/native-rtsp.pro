QT += core gui qml quick
CONFIG += console c++17 link_pkgconfig
CONFIG -= app_bundle
TEMPLATE = app
TARGET = native-rtsp-test
PKGCONFIG += libavformat libavcodec libavutil libswscale
INCLUDEPATH += ..
SOURCES += native-rtsp-test.cpp \
           ../RtspDeviceConfig.cpp \
           ../RtspDecodeWorker.cpp \
           ../RtspNativeSurface.cpp
HEADERS += ../RtspDeviceConfig.h \
           ../RtspDecodeWorker.h \
           ../RtspNativeSurface.h
