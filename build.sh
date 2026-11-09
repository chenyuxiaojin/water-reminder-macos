#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
APP="$PWD/喝水提醒.app"
mkdir -p "$APP/Contents/MacOS"
xcrun swiftc Sources/WaterReminder.swift -O -o "$APP/Contents/MacOS/WaterReminder" -framework AppKit -framework SwiftUI
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>WaterReminder</string>
<key>CFBundleIdentifier</key><string>com.local.water-reminder</string>
<key>CFBundleName</key><string>喝水提醒</string>
<key>CFBundleDisplayName</key><string>喝水提醒</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
"$APP/Contents/MacOS/WaterReminder" --self-test
printf 'Built: %s\n' "$APP"
