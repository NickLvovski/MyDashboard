#!/bin/zsh
set -eu
cd "$(dirname "$0")"
if [[ ! -x Build/MyDashboard.app/Contents/MacOS/MyDashboard || ! -f Build/MyDashboard.app/Contents/Info.plist ]] ||
   ! /usr/bin/plutil -lint Build/MyDashboard.app/Contents/Info.plist >/dev/null 2>&1; then
  /bin/zsh build.command
fi
open "$PWD/Build/MyDashboard.app"
