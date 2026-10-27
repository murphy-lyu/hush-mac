#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
xcodebuild -project Hush.xcodeproj -scheme Hush -configuration Release \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
app="$PWD/build/Build/Products/Release/Hush.app"
/usr/bin/codesign --force --sign - "$app"
/usr/bin/codesign --verify --strict "$app"
print "Built: $app"
