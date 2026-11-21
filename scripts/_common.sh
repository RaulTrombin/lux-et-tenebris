# Shared helpers for scripts/format.sh and scripts/lint.sh. Sourced, not run.
# shellcheck shell=bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FW="$ROOT/Firmware/lightpack-C3"
CONSOLE="$FW/console"

# Pinned so every machine formats identically. clang-format output differs
# between major versions; ruff and biome between minor ones.
CLANG_FORMAT_MAJOR=18
RUFF_VERSION=0.17.6

die() {
    echo "error: $*" >&2
    exit 1
}

# clang-format: $CLANG_FORMAT, else clang-format-18, else clang-format.
find_clang_format() {
    local cf="${CLANG_FORMAT:-}"
    if [[ -z "$cf" ]]; then
        if command -v "clang-format-$CLANG_FORMAT_MAJOR" >/dev/null 2>&1; then
            cf="clang-format-$CLANG_FORMAT_MAJOR"
        elif command -v clang-format >/dev/null 2>&1; then
            cf=clang-format
        else
            die "clang-format $CLANG_FORMAT_MAJOR not found. Install it (apt install clang-format-18," \
                "or LLVM 18 on Windows/macOS) or set CLANG_FORMAT=/path/to/clang-format."
        fi
    fi
    local ver
    ver="$("$cf" --version | sed -nE 's/.*version ([0-9]+)\..*/\1/p')"
    [[ "$ver" == "$CLANG_FORMAT_MAJOR" ]] ||
        die "$cf is version ${ver:-unknown}; clang-format $CLANG_FORMAT_MAJOR is required" \
            "(other majors format differently). Set CLANG_FORMAT to a v$CLANG_FORMAT_MAJOR binary."
    echo "$cf"
}

# The C/C++ files in scope: tracked files under src/ only. tools/button_probe,
# the legacy firmwares and everything else are outside this list by construction.
cpp_files() {
    git -C "$FW" ls-files -- 'src/*.cpp' 'src/*.h' | sed "s|^|$FW/|"
}

# Biome comes from console/node_modules (the only devDependency there).
find_biome() {
    local b="$CONSOLE/node_modules/.bin/biome"
    [[ -x "$b" ]] || die "biome not installed. Run: (cd Firmware/lightpack-C3/console && npm ci)"
    echo "$b"
}

# Ruff runs ephemerally through uvx or pipx; nothing is installed globally.
ruff() {
    if command -v uvx >/dev/null 2>&1; then
        uvx "ruff@$RUFF_VERSION" "$@"
    elif command -v pipx >/dev/null 2>&1; then
        pipx run "ruff==$RUFF_VERSION" "$@"
    else
        die "neither uvx nor pipx found; install uv (https://docs.astral.sh/uv/) or pipx to run ruff."
    fi
}

find_pio() {
    if command -v pio >/dev/null 2>&1; then
        echo pio
    elif [[ -x "$HOME/.platformio/penv/bin/pio" ]]; then
        echo "$HOME/.platformio/penv/bin/pio"
    elif [[ -x "$HOME/.platformio/penv/Scripts/pio.exe" ]]; then
        echo "$HOME/.platformio/penv/Scripts/pio.exe"
    else
        die "PlatformIO (pio) not found on PATH or in ~/.platformio/penv."
    fi
}

require() {
    command -v "$1" >/dev/null 2>&1 || die "$1 not found. $2"
}
