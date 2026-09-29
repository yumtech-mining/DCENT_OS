#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
TARGET_MATRIX_TOOL="$SCRIPT_DIR/target_matrix.py"

cd "$ROOT_DIR"

if ! command -v python3 >/dev/null 2>&1; then
    printf '%s\n' "Python 3 is required." >&2
    exit 1
fi
if ! command -v cargo >/dev/null 2>&1; then
    printf '%s\n' "Cargo is not on PATH. Install rustup and source the espup environment first." >&2
    exit 1
fi

python3 "$TARGET_MATRIX_TOOL" validate

require_target_property() {
    property=$1
    expected=$2
    actual=$(python3 "$TARGET_MATRIX_TOOL" lookup nerdqaxe-pp "$property")
    if [ "$actual" != "$expected" ]; then
        printf 'nerdqaxe-pp %s is %s; expected %s. Refusing to build.\n' \
            "$property" "$actual" "$expected" >&2
        exit 1
    fi
}

require_target_property feature nerdqaxe-pp
require_target_property asic BM1370
require_target_property chip_count 4
require_target_property release_scope internal
require_target_property support_tier experimental
require_target_property install_policy lab-only

if [ -z "${CARGO_TARGET_DIR:-}" ]; then
    CARGO_TARGET_DIR="$HOME/nqpp-build"
fi
mkdir -p "$CARGO_TARGET_DIR"
export CARGO_TARGET_DIR
export ESP_IDF_SDKCONFIG_DEFAULTS=sdkconfig.defaults

printf '%s\n' "Building experimental NerdQaxe++ (4x BM1370) only."
printf '%s\n' "This compiles an ELF; it does not package or flash the miner."
cargo build --locked --release -p dcentaxe --no-default-features --features nerdqaxe-pp

ELF_PATH="$CARGO_TARGET_DIR/xtensa-esp32s3-espidf/release/dcentaxe"
if [ ! -f "$ELF_PATH" ]; then
    printf 'Build finished without the expected ELF: %s\n' "$ELF_PATH" >&2
    exit 1
fi

printf 'Build succeeded. ELF: %s\n' "$ELF_PATH"
sha256sum "$ELF_PATH"
