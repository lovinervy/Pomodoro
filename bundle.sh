#!/bin/sh
# Собирает приложение и упаковывает его в Pomodoro.app.
# Бандл нужен системным уведомлениям: UNUserNotificationCenter требует bundle id.
#
# Использование:
#   ./bundle.sh          — debug-сборка
#   ./bundle.sh release  — релизная сборка (оптимизации, меньше бинарник)
set -e
cd "$(dirname "$0")"

CONFIG="debug"
if [ "$1" = "release" ]; then
    CONFIG="release"
fi

# Toolchain — как в run.sh: Xcode при наличии, иначе CLT с пином SDK.
XCODE=/Applications/Xcode.app/Contents/Developer
if [ -d "$XCODE" ] && echo 'import SwiftUI' | DEVELOPER_DIR="$XCODE" swiftc -typecheck - >/dev/null 2>&1; then
    echo "==> Toolchain: Xcode ($CONFIG)"
    export DEVELOPER_DIR="$XCODE"
else
    SDK=$(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX26*.sdk 2>/dev/null | sort -V | tail -1)
    [ -z "$SDK" ] && SDK=$(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX*.sdk | sort -V | tail -1)
    echo "==> Toolchain: Command Line Tools ($CONFIG, SDK: $SDK)"
    export SDKROOT="$SDK"
fi

if [ "$CONFIG" = "release" ]; then
    swift build -c release
    BIN=.build/release/Pomodoro
else
    swift build
    BIN=.build/debug/Pomodoro
fi

APP=Pomodoro.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Pomodoro"

# Иконка (генерируется на лету, если её нет — в репозитории не хранится)
if [ ! -f Assets/AppIcon.icns ]; then
    echo "==> Генерирую иконку"
    swift Scripts/make_icon.swift Assets/AppIcon.iconset
    iconutil -c icns Assets/AppIcon.iconset -o Assets/AppIcon.icns
fi
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>ru</string>
    <key>CFBundleExecutable</key><string>Pomodoro</string>
    <key>CFBundleIdentifier</key><string>local.pomodoro.app</string>
    <key>CFBundleName</key><string>Pomodoro</string>
    <key>CFBundleDisplayName</key><string>Pomodoro</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
EOF

# Ad-hoc подпись — достаточно для локального запуска и уведомлений.
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "==> Готово: $APP ($CONFIG)"
ls -lh "$APP/Contents/MacOS/Pomodoro" | awk '{print "==> Бинарник:", $5}'
