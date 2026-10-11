#!/bin/zsh
set -eu
cd "$(dirname "$0")"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
app_path="$PWD/Build/MyDashboard.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources" .build/module-cache
xcrun swiftc -swift-version 5 -parse-as-library -O -module-name MyDashboard \
  -target "$(uname -m)-apple-macosx14.0" -module-cache-path "$PWD/.build/module-cache" \
  Sources/MyDashboard/*.swift -o "$app_path/Contents/MacOS/MyDashboard"
xcrun swiftc -module-cache-path "$PWD/.build/module-cache" Tools/MakeIcon.swift -o .build/make-icon
.build/make-icon .build/AppIcon.iconset "$app_path/Contents/Resources/AppIcon.icns"
cat > "$app_path/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Мой курс</string>
<key>CFBundleDisplayName</key><string>Мой курс</string>
<key>CFBundleIdentifier</key><string>local.my-dashboard.MyDashboard</string>
<key>CFBundleExecutable</key><string>MyDashboard</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
codesign --force --sign - "$app_path"
print "Готово: $app_path"
