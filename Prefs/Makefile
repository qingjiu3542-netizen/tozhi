include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = NotifyIconPrefs
NotifyIconPrefs_FILES = NISettingsController.m NIAppListController.m
NotifyIconPrefs_FRAMEWORKS = UIKit Foundation
NotifyIconPrefs_PRIVATE_FRAMEWORKS = Preferences
NotifyIconPrefs_INSTALL_PATH = /Library/PreferenceBundles
NotifyIconPrefs_RESOURCE_FILES = Root.plist Info.plist
NotifyIconPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
