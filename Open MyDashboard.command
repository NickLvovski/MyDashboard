#!/bin/zsh
set -eu
cd "$(dirname "$0")"
if [[ ! -d Build/MyDashboard.app ]]; then
  /bin/zsh build.command
fi
open "$PWD/Build/MyDashboard.app"
