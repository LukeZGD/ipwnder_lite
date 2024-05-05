#!/bin/sh

# Built on macOS 14.4.1
# The iPhoneOS 9.2 SDK must be present in /Applications/Xcode.app. I've put the entire Xcode 7.2 here; the fact that it's incompatible is irrelevant.
# Xcode 15.3 is at /Applications/Xcode15.app. You can use a different version but it must be compatible with the system macOS.

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

IOS_SDK="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS9.2.sdk"
MACOSX_SDK="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.11.sdk"
FRAMEWORKS="-framework IOKit -framework CoreFoundation"
FLAGS="-Os -DDEBUG -DIPHONEOS_ARM -DApple_A6"
LIBCURL="./lib/dynamic/iphoneos-arm/libcurl.dylib"
LIBCURL64="./lib/dynamic/iphoneos-arm64/libcurl.dylib"
LIBCURL64R="./lib/dynamic/iphoneos-arm64-rootless/libcurl.dylib"

FILES="main.c ra1npoc/src/common/common.c ra1npoc/src/io/iousb.c ra1npoc/src/exploit/checkm8_arm64.c src/exploit/limera1n.c src/exploit/s5l8950x.c src/common/payload.c src/common/usb_0xa1_2.c lib/partialzip/partial.c"

# Prepare SDK for build (the iOS SDK doesn't have IOUSBLib.h)
sudo cp -r $MACOSX_SDK/System/Library/Frameworks/IOKit.framework/Headers/ \
    $IOS_SDK/System/Library/Frameworks/IOKit.framework/Headers/ && \
sudo cp $MACOSX_SDK/usr/include/libkern/OSTypes.h \
    $IOS_SDK/usr/include/libkern/ && \
sudo xcode-select -s /Applications/Xcode15.app && \
sudo xcodebuild -license accept && \
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

# Join them together
lipo -create -output ipwnder_lite -arch armv7 ipwnder_iphoneos -arch arm64 ipwnder_iphoneos64 && rm -f -- ipwnder_iphoneos* && \
codesign -f -s - --entitlements ent.xml -i ipwnder_lite ipwnder_lite && \
codesign -f -s - --entitlements ent.xml -i ipwnder_lite64 ipwnder_lite64

# Create rootful DEB file
rm -rf -- package && mkdir -p package/usr/local/bin && \
mv ipwnder_lite package/usr/local/bin/ipwnder_lite && \
mkdir package/DEBIAN && cp control package/DEBIAN/control && \
find . -name ".DS_Store" -delete && dpkg-deb -b package && dpkg-name package.deb

# Create rootless DEB file
rm -rf -- package && mkdir -p package/var/jb/usr/local/bin && \
mv ipwnder_lite64 package/var/jb/usr/local/bin/ipwnder_lite && \
mkdir package/DEBIAN && cp control64 package/DEBIAN/control && \
find . -name ".DS_Store" -delete && dpkg-deb -b package && dpkg-name package.deb

# Remove package folder
rm -rf -- package
