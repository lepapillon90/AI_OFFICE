#!/usr/bin/env bash
# Builds the Flutter web app for Vercel. Vercel's build image doesn't have
# Flutter preinstalled, so this fetches the stable SDK first (shallow clone
# to keep it quick), then builds a release web bundle to build/web, which
# vercel.json points to as the output directory.
set -euo pipefail

if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi
export PATH="$PATH:$(pwd)/flutter/bin"

flutter config --enable-web
flutter pub get
flutter build web --release
