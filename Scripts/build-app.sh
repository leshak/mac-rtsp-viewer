#!/bin/zsh

set -euo pipefail

repository_root="${0:A:h:h}"
configuration="${CONFIGURATION:-release}"
build_directory="$repository_root/.build/$configuration"
app_directory="$repository_root/build/RTSP Viewer.app"
contents_directory="$app_directory/Contents"
vlc_framework="$repository_root/.build/artifacts/swift-vlc/VLCKit/VLCKit.xcframework/macos-arm64_x86_64/VLCKit.framework"

cd "$repository_root"
if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  swift build --configuration "$configuration"
fi

rm -rf "$app_directory"
mkdir -p "$contents_directory/MacOS"
mkdir -p "$contents_directory/Frameworks"
mkdir -p "$contents_directory/Resources"
cp "$build_directory/RTSPViewer" "$contents_directory/MacOS/RTSPViewer"
cp "$repository_root/Support/Info.plist" "$contents_directory/Info.plist"
cp -R "$repository_root/Support/en.lproj" "$contents_directory/Resources/en.lproj"
cp -R "$repository_root/Support/ru.lproj" "$contents_directory/Resources/ru.lproj"
cp -R "$vlc_framework" "$contents_directory/Frameworks/VLCKit.framework"

codesign --force --sign - "$contents_directory/Frameworks/VLCKit.framework"
codesign --force --deep --sign - "$app_directory"

echo "$app_directory"
