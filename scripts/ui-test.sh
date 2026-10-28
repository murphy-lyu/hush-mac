#!/bin/zsh
# Isolated window: in-memory config, no real app launches or login-item APIs.
set -euo pipefail
cd "${0:A:h:h}"
qa="$PWD/build/ui-regression/Regression.app"
mkdir -p "$qa/Contents/MacOS" "$PWD/build/ModuleCache.noindex"
cat > "$qa/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleName</key><string>Hush UI Regression</string><key>CFBundleIdentifier</key><string>com.murphy.hush.qa.ui.isolated</string><key>CFBundleExecutable</key><string>Regression</string><key>CFBundlePackageType</key><string>APPL</string></dict></plist>
PLIST
xcrun swiftc -parse-as-library -module-cache-path build/ModuleCache.noindex \
  HushCore/*.swift Hush/MainView.swift Hush/LoginService.swift Hush/SettingsWindow.swift Hush/HushAppearance.swift Hush/LocalizedUI.swift IntegrationTests/VerifyUI.swift \
  -o "$qa/Contents/MacOS/Regression"
codesign --force --sign - "$qa"
"$qa/Contents/MacOS/Regression" "$@"
