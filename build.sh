#!/usr/bin/env bash
# Build all Corne Choc Pro firmware variants.
#
# Produces in the repo root:
#   corne_choc_pro_left.uf2      - left half (central) with nice!view display
#   corne_choc_pro_right.uf2     - right half (peripheral) with nice!view display
#   settings_reset_left.uf2     - left settings reset (clears BLE bonds)
#   settings_reset_right.uf2    - right settings reset
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO"

# --- One-time setup ---------------------------------------------------------
if [ ! -d .west ]; then
  echo ">> Initializing west workspace (first run)..."
  python3 -m venv .venv
  # shellcheck disable=SC1091
  source .venv/bin/activate
  pip install --upgrade pip "setuptools<81" west
  pip install protobuf grpcio-tools
  west init -l config/
  west update
  west zephyr-export
  # Zephyr build scripts need pyelftools, PyYAML, etc.
  pip install -r zephyr/scripts/requirements-base.txt
  # ZMK hardware metadata validation
  pip install -r zmk/app/scripts/requirements.txt
else
  source .venv/bin/activate
  # Ensure dependencies are present (handles deleted zephyr/ etc.)
  if [ ! -f zephyr/scripts/west-commands.yml ]; then
    echo ">> Restoring west workspace..."
    west update
    west zephyr-export
  fi
fi

# shellcheck disable=SC1091
source ~/.zephyrrc 2>/dev/null || true

BOARD_ROOT="$REPO"   # Zephyr finds $BOARD_ROOT/boards/ — no symlink needed
APP="$REPO/zmk/app"

build() {
  local board="$1" shield="$2" out="$3" extra="${4:-}"
  echo ""
  echo ">> Building $out  (board=$board shield=$shield)"
  rm -rf build
  # shellcheck disable=SC2086
  # -DZMK_CONFIG points at config/ so the keymap/conf there override the
  #   board's defaults — same resolution the cloud build uses.
  west build -b "$board" -s "$APP" -- -DSHIELD="$shield" -DBOARD_ROOT="$BOARD_ROOT" -DZMK_CONFIG="$REPO/config" $extra
  cp build/zephyr/zmk.uf2 "$REPO/$out"
  echo "   -> $REPO/$out"
}

build corne_choc_pro_left  nice_view_disp  corne_choc_pro_left.uf2  "-DCONFIG_ZMK_STUDIO=y"
build corne_choc_pro_right nice_view_disp  corne_choc_pro_right.uf2 ""
build corne_choc_pro_left  settings_reset  settings_reset_left.uf2  ""
build corne_choc_pro_right settings_reset  settings_reset_right.uf2 ""

echo ""
echo "Done. Firmware files in $REPO:"
ls -1 "$REPO"/*.uf2
