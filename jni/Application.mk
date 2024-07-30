APP_ABI := armeabi-v7a arm64-v8a
APP_PLATFORM := android-35
APP_CFLAGS := -Wall -O3 -mllvm -polly -flto -funified-lto -flto=jobserver -fuse-ld=lld
APP_LDFLAGS := -Wl,--lto=full -Wl,--lto-O3 -Wl,--mllvm=-polly -Wl,--gc-sections -Wl,--as-needed -Wl,--icf=all
APP_CFLAGS += -fno-unwind-tables -fno-asynchronous-unwind-tables -fno-stack-protector -U_FORTIFY_SOURCE
APP_SUPPORT_FLEXIBLE_PAGE_SIZES := true

ifeq ($(OS),Windows_NT)
APP_SHORT_COMMANDS := true
endif
