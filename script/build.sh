#!/usr/bin/env bash

# Define variables
BB_VER="v1.36.1"
BB_CHECKOUT="1_36_1"
NDK_VERSION="r27-beta2"
ZIP_NAME="Busybox-${BB_VER}-${RUN_ID}.zip"

if [[ -z "$RUN_ID" ]]; then
echo "Error: Variable RUN_ID not defined"
exit 1
elif [[ -z "$TOKEN" ]]; then
echo "Error: Variable TOKEN not defined"
exit 1
elif [[ -z "$CHAT_ID" ]]; then
echo "Error: Variable CHAT_ID not defined"
exit 1
fi

# Package
sudo apt update -y && sudo apt upgrade -y

# Download NDK
wget -q https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux.zip
unzip -q android-ndk-${NDK_VERSION}-linux.zip
rm -f android-ndk-${NDK_VERSION}-linux.zip
mv -f android-ndk-${NDK_VERSION} ndk

# Export Variable
export NDK_PROJECT_PATH=/home/runner/work/ndk-box-kitchen/ndk-box-kitchen

# Clone and checkout busybox
git clone https://git.busybox.net/busybox
cd busybox
git checkout ${BB_CHECKOUT}
cd ..

# Clone modules
git clone --depth=1 https://github.com/eraselk/pcre jni/pcre
git clone --depth=1 https://github.com/eraselk/selinux jni/selinux

# Apply Patches and Generate Makefile
if ! [[ -x "run.sh" ]]; then
    chmod +x run.sh
fi
bash run.sh patch
bash run.sh generate

# Build busybox (arm64-v8a and armeabi-v7a)
/home/runner/work/ndk-box-kitchen/ndk-box-kitchen/ndk/ndk-build all

# Clone Module Template
git clone --depth=1 https://github.com/eraselk/busybox-template

# Move busybox binaries to module template
rm -f /home/runner/work/ndk-box-kitchen/ndk-box-kitchen/busybox-template/system/xbin/.placeholder
cp -f /home/runner/work/ndk-box-kitchen/ndk-box-kitchen/libs/arm64-v8a/busybox /home/runner/work/ndk-box-kitchen/ndk-box-kitchen/busybox-template/system/xbin/busybox-arm64
cp -f /home/runner/work/ndk-box-kitchen/ndk-box-kitchen/libs/armeabi-v7a/busybox /home/runner/work/ndk-box-kitchen/ndk-box-kitchen/busybox-template/system/xbin/busybox-arm
sed -i "s/version=.*/version=${BB_VER}-${RUN_ID}/" /home/runner/work/ndk-box-kitchen/ndk-box-kitchen/busybox-template/module.prop

# Zipping
cd /home/runner/work/ndk-box-kitchen/ndk-box-kitchen/busybox-template
zip -r9 ${ZIP_NAME} *
mv -f ${ZIP_NAME} /home/runner/work/ndk-box-kitchen/ndk-box-kitchen
cd /home/runner/work/ndk-box-kitchen/ndk-box-kitchen

# Upload to Telegram
curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendDocument" \
-F chat_id="${CHAT_ID}" \
-F document=@"/home/runner/work/ndk-box-kitchen/ndk-box-kitchen/${ZIP_NAME}" 