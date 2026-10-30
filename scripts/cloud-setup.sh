#!/bin/bash
# Setup script for the widowd Claude Code on the web environment.
# Paste this whole file into the environment's settings under "Setup script".
# It runs once when each new session's container is built, starting in the
# directory above the repository checkout.
set -euo pipefail

FLUTTER_VERSION=3.47.8

if ! command -v flutter >/dev/null 2>&1; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git /opt/flutter
  ln -sf /opt/flutter/bin/flutter /usr/local/bin/flutter
  ln -sf /opt/flutter/bin/dart /usr/local/bin/dart
fi

flutter config --no-analytics --enable-web >/dev/null
flutter --version
flutter precache --web

cd widowd
flutter pub get
