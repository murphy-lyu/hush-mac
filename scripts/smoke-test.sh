#!/bin/zsh
# Launches a disposable fixture app; does not change login items or Hush configuration.
set -euo pipefail
cd "${0:A:h:h}"
qa="$PWD/build/smoke"
mkdir -p "$qa/Probe.app/Contents/MacOS" "$PWD/build/ModuleCache.noindex"
cp IntegrationTests/Probe-Info.plist "$qa/Probe.app/Contents/Info.plist"
xcrun swiftc -parse-as-library -module-cache-path build/ModuleCache.noindex \
  IntegrationTests/Probe.swift -o "$qa/Probe.app/Contents/MacOS/Probe"
codesign --force --sign - "$qa/Probe.app"
xcrun swiftc -parse-as-library -module-cache-path build/ModuleCache.noindex \
  HushCore/Models.swift HushCore/BasicNetworkProbe.swift HushCore/NetworkReadiness.swift HushCore/LaunchRunner.swift Hush/SystemLauncher.swift \
  IntegrationTests/VerifyLaunch.swift -o "$qa/verify-launch"
"$qa/verify-launch" "$qa/Probe.app"
