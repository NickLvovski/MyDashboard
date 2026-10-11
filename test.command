#!/bin/zsh
set -eu
cd "$(dirname "$0")"
mkdir -p .build/module-cache
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
xcrun swiftc -swift-version 5 -parse-as-library -module-cache-path "$PWD/.build/module-cache" \
  Sources/MyDashboard/Models.swift Sources/MyDashboard/DashboardStore.swift tests/ModelChecks.swift \
  -o .build/model-checks
.build/model-checks
