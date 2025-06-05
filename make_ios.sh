#!/bin/sh

set -e
# https://github.com/growtopiajaw/iPhoneOS-SDK/releases/download/v1.0/iPhoneOS9.2.sdk.zip
# https://github.com/phracker/MacOSX-SDKs/releases/download/11.3/MacOSX10.11.sdk.tar.xz
# extract and place in "SDKs" folder

# This file was derived in part from https://danylokos.github.io/0x05/ as well as the files mk_iphoneos32.sh, mk_iphoneos64.sh, and mk_iphoneos_generic.sh present in this repo until fba4c52bfeaa44ea2a51cd89e0fc48a906d31d9d inclusive.

if ! command -v ldid &> /dev/null; then # If ldid is not installed
if ! command -v brew --version &> /dev/null; then
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
brew install ldid
fi

if ! command -v dpkg --version &> /dev/null; then # If dpkg is not installed
if ! command -v brew --version &> /dev/null; then
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
brew install dpkg
fi

if [ -z "$(ls -A ./ra1npoc)" ]; then
git submodule init && git submodule update
fi

IOS_SDK="./SDKs/iPhoneOS9.2.sdk"
MACOSX_SDK="./SDKs/MacOSX10.11.sdk"
FRAMEWORKS="-framework IOKit -framework CoreFoundation"
FLAGS="-Os -DDEBUG -DIPHONEOS_ARM -DApple_A6"
LIBCURL="./lib/dynamic/iphoneos-arm/libcurl.dylib"
LIBCURL64="./lib/dynamic/iphoneos-arm64/libcurl.dylib"
LIBCURL64R="./lib/dynamic/iphoneos-arm64-rootless/libcurl.dylib"

FILES="main.c ra1npoc/src/common/common.c ra1npoc/src/io/iousb.c ra1npoc/src/exploit/checkm8_arm64.c src/exploit/limera1n.c src/exploit/s5l8950x.c src/common/payload.c src/common/usb_0xa1_2.c lib/partialzip/partial.c"

# Prepare SDK for build (the iOS SDK doesn't have IOUSBLib.h)
cp -r $MACOSX_SDK/System/Library/Frameworks/IOKit.framework/Headers/ \
    $IOS_SDK/System/Library/Frameworks/IOKit.framework/Headers/ && \
cp $MACOSX_SDK/usr/include/libkern/OSTypes.h \
    $IOS_SDK/usr/include/libkern/ && \
rm -f -- ipwnder_iphoneos* && rm -f -- ipwnder_lite* && rm -f -- *.deb

# Build 32-bit binary
clang -isysroot $IOS_SDK $FILES -I./ra1npoc/src/include -I./include -lz $LIBCURL $FRAMEWORKS $FLAGS -arch armv7 -o ipwnder_iphoneos && \
strip ipwnder_iphoneos && ldid -S ipwnder_iphoneos

# Build 64-bit binary
clang -isysroot $IOS_SDK $FILES -I./ra1npoc/src/include -I./include -lz $LIBCURL64 $FRAMEWORKS $FLAGS -arch arm64 -o ipwnder_iphoneos64 && \
strip ipwnder_iphoneos64 && ldid -S ipwnder_iphoneos64

# Build rootless binary
clang -isysroot $IOS_SDK $FILES -I./ra1npoc/src/include -I./include -lz $LIBCURL64R $FRAMEWORKS $FLAGS -DIPHONEOS_ARM64 -rpath /var/jb/usr/lib -arch arm64 -o ipwnder_lite64 && \
strip ipwnder_lite64 && ldid -S ipwnder_lite64

ldid -Sent.xml ipwnder_iphoneos
ldid -Sent.xml ipwnder_iphoneos64
ldid -Sent.xml ipwnder_lite64

# Create rootful 32-bit DEB file
rm -rf -- package && mkdir -p package/usr/local/bin && \
mv ipwnder_iphoneos package/usr/local/bin/ipwnder_lite && \
mkdir package/DEBIAN && cp control package/DEBIAN/control && \
find . -name ".DS_Store" -delete && dpkg-deb -Zgzip -b package && dpkg-name package.deb

# Create rootful 64-bit DEB file (iOS 11+)
rm -rf -- package && mkdir -p package/usr/local/bin && \
mv ipwnder_iphoneos64 package/usr/local/bin/ipwnder_lite && \
mkdir package/DEBIAN && cp control64 package/DEBIAN/control && \
find . -name ".DS_Store" -delete && dpkg-deb -Zgzip -b package && dpkg-name package.deb

# Create rootless DEB file
rm -rf -- package && mkdir -p package/var/jb/usr/local/bin && \
mv ipwnder_lite64 package/var/jb/usr/local/bin/ipwnder_lite && \
mkdir package/DEBIAN && cp control64_rootless package/DEBIAN/control && \
find . -name ".DS_Store" -delete && dpkg-deb -b package && dpkg-name package.deb

# Remove package folder
rm -rf -- package
