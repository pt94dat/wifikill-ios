ARCHS = arm64
TARGET = iphone:clang:latest:12.0
DEBUG = 0
FINALPACKAGE = 1
include $(THEOS)/makefiles/common.mk
APPLICATION_NAME = LanGuard
LanGuard_FILES = $(wildcard Sources/*/*.m) Sources/Network/LGNetwork.c
LanGuard_FRAMEWORKS = UIKit Foundation Security SystemConfiguration
LanGuard_CFLAGS = -fobjc-arc -Wall -Wextra -Werror=unguarded-availability-new -I Sources
LanGuard_RESOURCE_DIRS = Resources
LanGuard_CODESIGN_FLAGS = -SResources/entitlements.plist
LanGuard_INSTALL_PATH = /Applications
include $(THEOS_MAKE_PATH)/application.mk
