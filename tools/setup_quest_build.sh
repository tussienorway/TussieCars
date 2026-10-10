#!/usr/bin/env bash
# Unpacks Godot's Android Gradle template into android/build, which the "Quest 3" preset needs.
set -euo pipefail
cd "$(dirname "$0")/.."
templates="${GODOT_TEMPLATES:-$HOME/.local/share/godot/export_templates}"
dir="$(ls -d "$templates"/*/ | sort | tail -1)"
rm -rf android/build
mkdir -p android/build
unzip -q -o "$dir/android_source.zip" -d android/build
cat "$dir/version.txt" > android/.build_version
touch android/build/.gdignore
echo "Android build template $(cat android/.build_version) installed in android/build"
