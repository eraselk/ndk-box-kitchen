#!/bin/bash
vars=(
	BB_NAME="Enhanced"
	BB_VER="v1.37.0.2"
	BUILD_TYPE="dev"
	BB_BUILDER="eraselk@gacorprjkt"
	VERSION_CODE="${BB_VER//v/}"
	VERSION_CODE="${VERSION_CODE//./}"

	NDK_STABLE=0
	NDK_STABLE_VERSION="r27"
	NDK_CANARY=1
	NDK_CANARY_LINK='https://storage.googleapis.com/android-build/builds/aosp-master-ndk-linux-linux/12156102/dc56b824af8f420690045102aaf66937e2feedbcdb482507b833862d9d509d1d/android-ndk-12156102-linux-x86_64.zip?GoogleAccessId=gcs-sign%40android-builds-project.google.com.iam.gserviceaccount.com&Expires=1722340746&Signature=L3qsi1Rs%2Fjk1NtN63bLeQy1yvGx3FbB4kTZQBOT8kL5kiicOLsOLYnf0T9EMLyjzTN621cSpaCT%2FZyv45J%2BsafEaEN2ra76HOUo0TpkJXBMo8LDC3TJosiNPQ6NzaYT9XvPnsJBs4XC5OE5pZMAstOg9uL9%2F%2F%2BN1wH4J5F4A2kP%2BEzU%2BSQZ%2F3BQqnnh0Dul%2BtdMc29sCVsfZUEt5qERTDY58jcR%2BGeySw9id6rPZ0rG38eEhg0zr98wxs1shoMtPRoOQVmoMZlw%2FfTl%2BusTGeord0OHzjRqdOp4dnCThiJq7FI62%2BSWX8n4a5T4z%2BvaDk1NRGWO3PGbnPmImBbzbzQ%3D%3D&response-content-disposition=attachment'

	RUN_ID=${GITHUB_RUN_ID:-"local"}
	ZIP_NAME="${BB_NAME}-BusyBox-${BB_VER}-${RUN_ID}.zip"
	TZ="Asia/Makassar"
	NDK_PROJECT_PATH="/home/runner/work/ndk-box-kitchen/ndk-box-kitchen"
	BUILD_LOG="${NDK_PROJECT_PATH}/build.log"
	BUILD_SUCCESS=
)

# Export all variables
for var in ${vars[@]}; do
	export $var
done

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
			-F "parse_mode=html" \
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
NDK_STABLE=$NDK_STABLE
$(if [[ $NDK_STABLE -eq 1 ]]; then echo "NDK_STABLE_VERSION=$NDK_STABLE_VERSION"; fi)
NDK_CANARY=$NDK_CANARY
===========================</b>"

sudo ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime

if [[ $NDK_STABLE -eq 1 ]]; then
	wget -q "https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux.zip" -O android-ndk-${NDK_VERSION}-linux.zip
	unzip -q android-ndk-$NDK_VERSION-linux.zip
	rm -f android-ndk-$NDK_VERSION-linux.zip
	mv -f android-ndk-$NDK_VERSION ndk
elif [[ $NDK_CANARY -eq 1 ]]; then
	wget -q "$NDK_CANARY_LINK" -O ndk-tarball
	unzip -q ndk-tarball
	rm -f ndk-tarball
	mv -f android-ndk-* ndk
fi

{
	git clone --depth=1 https://github.com/eraselk/busybox
	git clone --depth=1 https://android.googlesource.com/platform/external/selinux jni/selinux
	git clone --depth=1 https://android.googlesource.com/platform/external/pcre jni/pcre

	[[ ! -x "run.sh" ]] && chmod +x run.sh

	bash run.sh generate

	$NDK_PROJECT_PATH/ndk/ndk-build all -j"$(nproc --all)" && {
		git clone --depth=1 https://github.com/eraselk/busybox-template
		rm -f $NDK_PROJECT_PATH/busybox-template/system/xbin/.placeholder

		cp -f $NDK_PROJECT_PATH/libs/arm64-v8a/busybox $NDK_PROJECT_PATH/busybox-template/system/xbin/busybox-arm64
		cp -f $NDK_PROJECT_PATH/libs/armeabi-v7a/busybox $NDK_PROJECT_PATH/busybox-template/system/xbin/busybox-arm
		cp -f $NDK_PROJECT_PATH/libs/x86_64/busybox $NDK_PROJECT_PATH/busybox-template/system/xbin/busybox-x64
		cp -f $NDK_PROJECT_PATH/libs/x86/busybox $NDK_PROJECT_PATH/busybox-template/system/xbin/busybox-x86

		sed -i "s/version=.*/version=$BB_VER-$RUN_ID/" $NDK_PROJECT_PATH/busybox-template/module.prop
		sed -i "s/versionCode=.*/versionCode=$VERSION_CODE/" $NDK_PROJECT_PATH/busybox-template/module.prop

		cd $NDK_PROJECT_PATH/busybox-template
		zip -r9 $ZIP_NAME *
		mv -f $ZIP_NAME $NDK_PROJECT_PATH
		cd $NDK_PROJECT_PATH
	}
} | tee -a "${BUILD_LOG}"

if [[ -f $NDK_PROJECT_PATH/$ZIP_NAME ]]; then
	upload_file "$NDK_PROJECT_PATH/$ZIP_NAME" "#$BUILD_TYPE #v$VERSION_CODE $(echo -e "\n<b>Build Date: $(date +"%Y-%m-%d %H:%M")</b>")"
	upload_file "$BUILD_LOG" "Build log"
else
	upload_file "$BUILD_LOG" "<b>Build failed</b>"
fi
