#!/bin/zsh
set -eu
cd "$(dirname "$0")"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
app_path="$PWD/Build/MyDashboard.app"
mkdir -p Build .build/module-cache
staging_root=$(mktemp -d "$PWD/Build/.MyDashboard.XXXXXX")
bundle_path="$staging_root/MyDashboard.app"
previous_path="$staging_root/previous.app"
cleanup() {
  if [[ ! -d "$app_path" && -d "$previous_path" ]]; then
    mv "$previous_path" "$app_path"
  fi
  rm -rf "$staging_root"
}
trap cleanup EXIT
mkdir -p "$bundle_path/Contents/MacOS" "$bundle_path/Contents/Resources"
xcrun swiftc -swift-version 5 -parse-as-library -O -module-name MyDashboard \
  -target "$(uname -m)-apple-macosx14.0" -module-cache-path "$PWD/.build/module-cache" \
  Sources/MyDashboard/*.swift -o "$bundle_path/Contents/MacOS/MyDashboard"
xcrun swiftc -module-cache-path "$PWD/.build/module-cache" Tools/MakeIcon.swift -o .build/make-icon
.build/make-icon .build/AppIcon.iconset "$bundle_path/Contents/Resources/AppIcon.icns"
cat > "$bundle_path/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Мой курс</string>
<key>CFBundleDisplayName</key><string>Мой курс</string>
<key>CFBundleIdentifier</key><string>local.my-dashboard.MyDashboard</string>
<key>CFBundleExecutable</key><string>MyDashboard</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.1</string>
<key>CFBundleVersion</key><string>2</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
codesign --force --sign - "$bundle_path"
codesign --verify --deep --strict "$bundle_path"
if [[ -d "$app_path" ]]; then
  mv "$app_path" "$previous_path"
fi
mv "$bundle_path" "$app_path"
print "Готово: $app_path"
