#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
export CLANG_MODULE_CACHE_PATH="$PWD/build/ModuleCache.noindex"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/build/ModuleCache.noindex"
swift test --disable-sandbox --scratch-path build/swift-tests \
  --cache-path build/package-cache --config-path build/package-config --security-path build/package-security
