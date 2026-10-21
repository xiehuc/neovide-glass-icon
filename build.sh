#!/bin/bash
set -euo pipefail

# Compile Icon Composer sources using Xcode; preserve the generated ICNS unchanged.
# Set DEVELOPER_DIR to use a nonstandard Xcode installation.
script_dir="$(cd "$(dirname "$0")" && pwd)"
fail() { echo "Error: $*" >&2; exit 1; }
if [[ "${1:-}" == -h || "${1:-}" == --help ]]; then
  echo "Usage: $0 [input.icon] [output.icns]"
  echo "No arguments: compile the only .icon next to this script."
  echo "Requires full Xcode supporting your Icon Composer file. ICNS output is unmodified."
  exit 0
fi
(( $# <= 2 )) || fail "Expected input.icon and optional output.icns."
if (( $# == 0 )); then
  shopt -s nullglob
  sources=("$script_dir"/*.icon)
  (( ${#sources[@]} == 1 )) || fail "Put exactly one .icon next to build.sh, or specify its path."
  src="${sources[0]}"
else
  src="$1"
fi
[[ "$src" = /* ]] || src="$PWD/$src"
[[ -e "$src" && "$src" == *.icon ]] || fail "Icon Composer .icon not found: $src"
name="$(basename "$src" .icon)"
out="${2:-${src%.icon}.icns}"
[[ "$out" = /* ]] || out="$PWD/$out"
[[ "$out" == *.icns ]] || fail "Output must end in .icns."
[[ ! -e "$out" ]] || fail "Output already exists: $out (choose another output name)."
[[ -d "$(dirname "$out")" ]] || fail "Output directory does not exist."

# Prefer the user's selected toolchain; fall back without changing xcode-select.
if ! xcrun --find actool >/dev/null 2>&1; then
  if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  fi
fi
if ! actool_check="$(xcrun --find actool 2>&1)"; then
  printf '%s\n' "$actool_check" >&2
  fail "Xcode could not resolve actool. See the original error above (license, first-launch setup, or toolchain path)."
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/compiled"
echo "Compiling: $src"
xcrun actool "$src" \
  --app-icon "$name" \
  --compile "$tmp_dir/compiled" \
  --output-partial-info-plist "$tmp_dir/icon-info.plist" \
  --minimum-deployment-target 11.0 \
  --platform macosx \
  --target-device mac
compiled="$tmp_dir/compiled/$name.icns"
[[ -f "$compiled" ]] || fail "actool did not generate $name.icns. Check the compiler output and Xcode version."

# Copy the compiler output byte-for-byte, without resizing or repacking.
cp "$compiled" "$out"
echo "Created: $out"
