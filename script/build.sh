#!/usr/bin/env bash

upload_file() {
	local file_path="$1"
	local caption="$2"

if [[ -f "$file_path" ]]; then
	if [[ -n $caption ]]; then
		curl -s -F document=@"$file_path" "https://api.telegram.org/bot${TOKEN}/sendDocument" \
			-F chat_id="$CHAT_ID" \
			-F "disable_web_page_preview=true" \
			-F "parse_mode=``html" \
			-F caption="$caption"
	else
		curl -s -F document=@"$file_path" "https://api.telegram.org/bot${TOKEN}/sendDocument" \
			-F "disable_web_page_preview=true" \
			-F chat_id="$CHAT_ID"
	fi
fi
}

send_msg() {
	local message="$1"

	curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
		-d chat_id="$CHAT_ID" \
		-d "disable_web_page_preview=true" \
		-d "parse_mode=html" \
		-d text="$message"
}

set_tz_to() {
    TZ="$1"
    if [[ -n "$TZ" ]] && [[ -n "$2" ]]; then
        echo "set_tz(): Max 1 Argument"
        exit 1
    elif [[ -z "$TZ" ]]; then
        echo "set_tz(): Recived 0 Argument, expected 1."
        exit 1
    fi
    
    if ! sudo ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime 2>/dev/null; then
        echo "set_tz(): Failed to set Time Zone"
        exit 1
    fi
}

set_tz_to "Asia/Makassar"

NDK_PROJECT_PATH=$(pwd)

BB_NAME="Enhanced"
BB_VER="v1.37.0.3"
BB_TIME_STAMP="$(date +%Y%m%d%H%M)"
BUILD_TYPE="rel"

# set 'true' if you wanna use the canary version of ndk
NDK_CANARY=false
# TIP: you can replace this ndk canary with your own ndk canary.
NDK_CANARY_LINK="https://github.com/eraselk/ndk-canary/releases/download/r28-canary-20240730/android-ndk-12157319-linux-x86_64.zip"

# set 'true' if you wanna use the stable version of ndk
NDK_STABLE=true
NDK_STABLE_VERSION="r27b"

VERSION_CODE="$(echo "$BB_VER" | tr -d 'v.')"

ZIP_NAME="${BB_NAME}-BusyBox-${BB_VER}-${BB_TIME_STAMP}.zip"

# Export all variables
export BB_NAME BB_VER BB_TIME_STAMP BUILD_TYPE BB_BUILDER VERSION_CODE NDK_STABLE NDK_STABLE_VERSION NDK_CANARY NDK_CANARY_LINK RUN_ID ZIP_NAME TZ NDK_PROJECT_PATH BUILD_LOG BUILD_SUCCESS

# Check if TOKEN is set
if [[ -z $TOKEN ]]; then
	echo "Error: Variable TOKEN not defined"
	exit 1
fi

# Check if CHAT_ID is set
if [[ -z $CHAT_ID ]]; then
	echo "Error: Variable CHAT_ID not defined"
	exit 1
fi

send_msg "<b>BusyBox CI Triggered</b>"
sleep 2
send_msg "<b>===========================
BB_NAME=$BB_NAME
BB_VERSION=$BB_VER
BUILD_TYPE=$BUILD_TYPE
BB_TIME_STAMP=$BB_TIME_STAMP
NDK_STABLE=$NDK_STABLE $(if $NDK_STABLE; then echo -e "\nNDK_STABLE_VERSION=$NDK_STABLE_VERSION"; fi)
NDK_CANARY=$NDK_CANARY
===========================</b>"

if $NDK_STABLE; then
	wget -q "https://dl.google.com/android/repository/android-ndk-${NDK_STABLE_VERSION}-linux.zip" -O "android-ndk-${NDK_STABLE_VERSION}-linux.zip"
	unzip -q "android-ndk-${NDK_STABLE_VERSION}-linux.zip"
	rm "android-ndk-${NDK_STABLE_VERSION}-linux.zip"
	mv "android-ndk-${NDK_STABLE_VERSION}" ndk
elif $NDK_CANARY; then
	wget -q "$NDK_CANARY_LINK" -O ndk-tarball
	unzip -q ndk-tarball
	rm ndk-tarball
	mv android-ndk-* ndk
fi
	git clone --depth=1 https://github.com/eraselk/busybox
	git clone --depth=1 https://android.googlesource.com/platform/external/selinux jni/selinux
	git clone --depth=1 https://android.googlesource.com/platform/external/pcre jni/pcre

	[[ -x "run.sh" ]] || chmod +x run.sh

	bash run.sh generate

	if $NDK_PROJECT_PATH/ndk/ndk-build all -j$(nproc --all); then
		git clone --depth=1 https://github.com/eraselk/busybox-template
    
		cp "$NDK_PROJECT_PATH/libs/arm64-v8a/busybox" "$NDK_PROJECT_PATH/busybox-template/system/xbin/busybox-arm64"
		cp "$NDK_PROJECT_PATH/libs/armeabi-v7a/busybox" "$NDK_PROJECT_PATH/busybox-template/system/xbin/busybox-arm"

		sed -i "s/version=.*/version=$BB_VER-$RUN_ID/" "$NDK_PROJECT_PATH/busybox-template/module.prop"
		sed -i "s/versionCode=.*/versionCode=$VERSION_CODE/" "$NDK_PROJECT_PATH/busybox-template/module.prop"

		cd "$NDK_PROJECT_PATH/busybox-template"
		zip -r9 "$ZIP_NAME" *
		mv "$ZIP_NAME" "$NDK_PROJECT_PATH"
		cd "$NDK_PROJECT_PATH"
	fi

if [[ -f "$NDK_PROJECT_PATH/$ZIP_NAME" ]]; then
	upload_file "$NDK_PROJECT_PATH/$ZIP_NAME" "#$BUILD_TYPE #v$VERSION_CODE $(echo -e "\n<b>Build Date: $(date +"%Y-%m-%d %H:%M")</b>")"
fi
