TARGET = iphone:clang:latest:15.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = NotifyIcon
NotifyIcon_FILES = Tweak.xm
NotifyIcon_CFLAGS = -fobjc-arc
NotifyIcon_FRAMEWORKS = UIKit Foundation QuartzCore

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS_MAKE_PATH)/tweak.mk
