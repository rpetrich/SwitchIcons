ifeq ($(shell [ -f ./framework/makefiles/common.mk ] && echo 1 || echo 0),0)
all clean package install::
	git submodule update --init
	./framework/git-submodule-recur.sh init
	$(MAKE) $(MAKEFLAGS) MAKELEVEL=0 $@
else

ARCHS = armv7

SDKVERSION = 6.1
INCLUDE_SDKVERSION = 6.1
TARGET_IPHONEOS_DEPLOYMENT_VERSION = 5.0
TARGET=:clang

TWEAK_NAME = SwitchIcons
SwitchIcons_FILES = Tweak.x
SwitchIcons_FRAMEWORKS = Foundation UIKit
SwitchIcons_LIBRARIES = flipswitch

include framework/makefiles/common.mk
include framework/makefiles/tweak.mk

endif
