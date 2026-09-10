#!/usr/bin/env bash
# Vercel's build image has no Flutter/Dart SDK preinstalled, so this
# installs it before building. SUPABASE_URL/SUPABASE_ANON_KEY are compiled
# in via --dart-define (see lib/core/config/env_config.dart) rather than a
# bundled .env asset, since Flutter Web has no server process to load a
# runtime secrets file from -- set both as Vercel Project Environment
# Variables (see docs/DEPLOYMENT.md).
set -euo pipefail

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  echo "error: SUPABASE_URL and SUPABASE_ANON_KEY must be set as Vercel project environment variables." >&2
  exit 1
fi

FLUTTER_DIR="$HOME/flutter"
if [ ! -d "$FLUTTER_DIR" ]; then
  git clone -b stable --depth 1 https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$PATH:$FLUTTER_DIR/bin"

flutter config --enable-web --no-analytics
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
