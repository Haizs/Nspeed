INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Nspeed

Nspeed_FILES = Tweak.x
Nspeed_CFLAGS = -fobjc-arc
Nspeed_ARCHS = armv7 arm64 arm64e

include $(THEOS_MAKE_PATH)/tweak.mk