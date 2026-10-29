#!/bin/sh
set -eu

SONGA_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SONGA_TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/songa-integration-check.XXXXXX")
trap 'rm -rf "$SONGA_TEST_DIR"' EXIT HUP INT TERM
export XDG_DATA_HOME="$SONGA_TEST_DIR/data"
export XDG_CONFIG_HOME="$SONGA_TEST_DIR/config"
export XDG_CACHE_HOME="$SONGA_TEST_DIR/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"

godot --headless --path "$SONGA_ROOT" --editor --import > "$SONGA_TEST_DIR/import.log" 2>&1 || {
    cat "$SONGA_TEST_DIR/import.log"
    exit 1
}
# Godot may exit successfully after import despite reporting a script error.
if grep -Eq 'SCRIPT ERROR|Parse Error|Compile Error' "$SONGA_TEST_DIR/import.log"; then
    cat "$SONGA_TEST_DIR/import.log"
    exit 1
fi
godot --headless --path "$SONGA_ROOT" --script tests/smoke.gd
godot --headless --path "$SONGA_ROOT" --script tests/integration.gd
