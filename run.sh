#!/usr/bin/env bash
# Runs the app with local Supabase credentials injected via --dart-define.
# Credentials live in env.local.json (gitignored). Without them the app runs
# fully offline (sync disabled).
set -euo pipefail
cd "$(dirname "$0")"
flutter run --dart-define-from-file=env.local.json "$@"
