#!/bin/bash
build_and_release() {
    echo "[+] Building SakuraLauncher for $2..."
    start_time=$(date +%s)
    xcodebuild -configuration Release -scheme SakuraLauncher \
        ARCHS=$1 ONLY_ACTIVE_ARCH=NO \
        archive -archivePath release/$1.xcarchive >release/$1.build.log 2>&1
    if [ $? -ne 0 ]; then
        echo "    - Build failed!"
        exit 1
    fi
    echo "    - Took $(($(date +%s) - $start_time))s!"

    product_dir="release/$1.xcarchive/Products/Applications"

    echo "[+] Creating disk image $2..."
    start_time=$(date +%s)
    create-dmg \
        --volname "SakuraFrp 启动器 ($2)" \
        --volicon "$product_dir/SakuraLauncher.app/Contents/Resources/AppIcon.icns" \
        --background "release_background.png" \
        --window-pos 200 120 \
        --window-size 800 340 \
        --icon-size 90 \
        --text-size 14 \
        --codesign "Developer ID Application" \
        --icon "SakuraLauncher.app" 175 130 \
        --no-internet-enable \
        --hide-extension "SakuraLauncher.app" \
        --app-drop-link 625 130 \
        "release/SakuraLauncher_macOS_$1.dmg" \
        "$product_dir/" >release/$1.dmg.log 2>&1
    if [ $? -ne 0 ]; then
        echo "    - Action failed!"
        exit 1
    fi
    echo "    - Took $(($(date +%s) - $start_time))s!"
}

do_notraize() {
    target="release/SakuraLauncher_macOS_$1.dmg"

    echo "[+] Notarizing $target..."
    start_time=$(date +%s)
    xcrun notarytool submit $target \
        --verbose \
        --wait \
        --keychain-profile "AC_PASSWORD" >release/$1.notarize.log 2>&1
    if [ $? -ne 0 ]; then
        echo "    - Notarization failed!"
        exit 1
    fi
    echo "    - Took $(($(date +%s) - $start_time))s!"

    echo "[+] Stapling $target..."
    xcrun stapler staple $target
    if [ $? -ne 0 ]; then
        echo "    - Stapling failed!"
        exit 1
    fi
    xcrun stapler validate $target
    echo "    - Done!"
}

rm -rf release
mkdir -p release

build_and_release "x86_64" "Intel"
build_and_release "arm64" "Apple Silicon"

do_notraize "x86_64"
do_notraize "arm64"
