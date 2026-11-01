#!/bin/sh
# Сборка и запуск Pomodoro.
#
# Приоритет — полный Xcode (свежий SDK, плагин SwiftUIMacros).
# Если Xcode нет или лицензия не принята — откат на Command Line Tools
# с пином на SDK 26.x (в SDK 27 @State стал макросом, чей плагин есть
# только в Xcode).
set -e
cd "$(dirname "$0")"

XCODE=/Applications/Xcode.app/Contents/Developer

use_xcode() {
    [ -d "$XCODE" ] || return 1
    # Проба: лицензия принята и toolchain живой?
    echo 'import SwiftUI' | DEVELOPER_DIR="$XCODE" swiftc -typecheck - >/dev/null 2>&1
}

if use_xcode; then
    echo "==> Toolchain: Xcode"
    export DEVELOPER_DIR="$XCODE"
else
    SDK=$(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX26*.sdk 2>/dev/null | sort -V | tail -1)
    if [ -z "$SDK" ]; then
        SDK=$(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX*.sdk | sort -V | tail -1)
    fi
    echo "==> Toolchain: Command Line Tools (SDK: $SDK)"
    export SDKROOT="$SDK"
fi

case "$1" in
    test)  swift test ;;
    build) swift build ;;
    *)     swift run ;;
esac
