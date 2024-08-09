include $(CLEAR_VARS)
LOCAL_MODULE := busybox
LOCAL_C_INCLUDES := $(LOCAL_PATH)/include
LOCAL_STATIC_LIBRARIES := libselinux
LOCAL_LDFLAGS := -static -Wl,--wrap=realpath -Wl,--wrap=rename -Wl,--wrap=renameat
LOCAL_CFLAGS := \
-w -include include/autoconf.h -D__USE_BSD -D__USE_GNU \
-DBB_VER=\"$(BB_VER)\" -DBB_TIME_STAMP=\"$(BB_TIME_STAMP)\" \
-DBB_NAME=\"$(BB_NAME)\" -DBB_BUILD_TYPE=\"$(BUILD_TYPE)\"

LOCAL_SRC_FILES := \
