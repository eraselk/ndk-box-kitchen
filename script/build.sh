#!/bin/bash
set -x
BB_NAME="Enhanced"
BB_VER="v1.37.0.2"
BUILD_TYPE="dev"
BB_BUILDER="eraselk@gacorprjkt"
VERSION_CODE="${BB_VER//v/}"
VERSION_CODE="${VERSION_CODE//./}"

NDK_STABLE="0"
NDK_STABLE_VERSION="r27"
NDK_CANARY="1"
NDK_CANARY_LINK="https://github.com/eraselk/ndk-canary/releases/download/r28-canary-20240730/android-ndk-12157319-linux-x86_64.zip"

RUN_ID="${GITHUB_RUN_ID:-local}"
ZIP_NAME="${BB_NAME}-BusyBox-${BB_VER}-${RUN_ID}.zip"
TZ="Asia/Makassar"
NDK_PROJECT_PATH="/home/runner/work/ndk-box-kitchen/ndk-box-kitchen"
BUILD_LOG="${NDK_PROJECT_PATH}/build.log"
BUILD_SUCCESS=""

# Export all variables
export BB_NAME BB_VER BUILD_TYPE BB_BUILDER VERSION_CODE NDK_STABLE NDK_STABLE_VERSION NDK_CANARY NDK_CANARY_LINK RUN_ID ZIP_NAME TZ NDK_PROJECT_PATH BUILD_LOG BUILD_SUCCESS

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

upload_file() {
	local file_path="$1"
	local caption="$2"

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
}

send_msg() {
	local message="$1"

	curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
		-d chat_id="$CHAT_ID" \
		-d "disable_web_page_preview=true" \
		-d "parse_mode=html" \
		-d text="$message"
}

send_msg "<b>BusyBox CI Triggered</b>"
sleep 2
send_msg "<b>===========================
BB_NAME=$BB_NAME
BB_VERSION=$BB_VER
BUILD_TYPE=$BUILD_TYPE
BB_BUILDER=$BB_BUILDER
NDK_STABLE=$NDK_STABLE $(if [[ $NDK_STABLE -eq 1 ]]; then echo "\nNDK_STABLE_VERSION=$NDK_STABLE_VERSION"; fi)
NDK_CANARY=$NDK_CANARY
===========================</b>"

sudo ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime

if [[ $NDK_STABLE -eq 1 ]]; then
	wget -q "https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux.zip" -O "android-ndk-${NDK_VERSION}-linux.zip"
	unzip -q "android-ndk-${NDK_VERSION}-linux.zip"
	rm "android-ndk-${NDK_VERSION}-linux.zip"
	mv "android-ndk-${NDK_VERSION}" ndk
elif [[ $NDK_CANARY -eq 1 ]]; then
	wget -q "$NDK_CANARY_LINK" -O ndk-tarball
	unzip -q ndk-tarball
	rm ndk-tarball
	mv android-ndk-* ndk
fi

{
	git clone --depth=1 https://github.com/eraselk/busybox
	git clone --depth=1 https://android.googlesource.com/platform/external/selinux jni/selinux
	git clone --depth=1 https://android.googlesource.com/platform/external/pcre jni/pcre

	[[ ! -x "run.sh" ]] && chmod +x run.sh

	bash run.sh generate

	"$NDK_PROJECT_PATH/ndk/ndk-build" all -j"$(nproc --all)" && {
		git clone --depth=1 https://github.com/eraselk/busybox-template
		rm "$NDK_PROJECT_PATH/busybox-template/system/xbin/.placeholder"

		cp "$NDK_PROJECT_PATH/libs/arm64-v8a/busybox" "$NDK_PROJECT_PATH/busybox-template/system/xbin/busybox-arm64"
		cp "$NDK_PROJECT_PATH/libs/armeabi-v7a/busybox" "$NDK_PROJECT_PATH/busybox-template/system/xbin/busybox-arm"

		sed -i "s/version=.*/version=$BB_VER-$RUN_ID/" "$NDK_PROJECT_PATH/busybox-template/module.prop"
		sed -i "s/versionCode=.*/versionCode=$VERSION_CODE/" "$NDK_PROJECT_PATH/busybox-template/module.prop"

		cd "$NDK_PROJECT_PATH/busybox-template"
		zip -r9 "$ZIP_NAME" *
		mv "$ZIP_NAME" "$NDK_PROJECT_PATH"
		cd "$NDK_PROJECT_PATH"
	}
} | tee -a "${BUILD_LOG}"

if [[ -f "$NDK_PROJECT_PATH/$ZIP_NAME" ]]; then
	upload_file "$NDK_PROJECT_PATH/$ZIP_NAME" "#$BUILD_TYPE #v$VERSION_CODE $(echo -e "\n<b>Build Date: $(date +"%Y-%m-%d %H:%M")</b>")"
	upload_file "$BUILD_LOG" "Build log"
else
	upload_file "$BUILD_LOG" "<b>Build failed</b>"
fi
