#!/usr/bin/env bash
# Check-only lint for the lightpack-C3 firmware, console and tools. Never writes.
# Exits non-zero if any formatter would change a file or any linter/test fails.
# Works from any cwd.
#
#   scripts/lint.sh              format checks, biome ci, ruff, npm test
#   scripts/lint.sh --build      ... plus `pio run -e C3-USB`
#   scripts/lint.sh --cppcheck   ... plus `pio check -e C3-USB` (cppcheck)
#   scripts/lint.sh --all        both of the above
set -euo pipefail
# shellcheck source=scripts/_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

BUILD=0
CPPCHECK=0
for arg in "$@"; do
    case "$arg" in
    --build) BUILD=1 ;;
    --cppcheck) CPPCHECK=1 ;;
    --all) BUILD=1 CPPCHECK=1 ;;
    -h | --help)
        sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *) die "unknown option: $arg (try --help)" ;;
    esac
done

# Resolve every tool up front so a missing one fails before any step runs.
require git "Install git."
require npm "Install Node.js (for the console tests and biome)."
CF="$(find_clang_format)"
BIOME="$(find_biome)"
ruff --version >/dev/null
PIO=""
if ((BUILD || CPPCHECK)); then PIO="$(find_pio)"; fi

failed=()
step() {
    local name="$1"
    shift
    echo
    echo "==> $name"
    if "$@"; then
        echo "    ok: $name"
    else
        echo "    FAIL: $name"
        failed+=("$name")
    fi
}

clang_format_check() {
    local files
    mapfile -t files < <(cpp_files)
    "$CF" --dry-run --Werror --style=file "${files[@]}"
}

biome_ci() { (cd "$CONSOLE" && "$BIOME" ci --error-on-warnings); }
ruff_check() { (cd "$FW" && ruff check); }
ruff_format_check() { (cd "$FW" && ruff format --check); }

step "clang-format --dry-run --Werror" clang_format_check
step "biome ci" biome_ci
step "ruff check" ruff_check
step "ruff format --check" ruff_format_check
step "npm test (console)" npm --prefix "$CONSOLE" test --silent
if ((BUILD)); then
    step "pio run -e C3-USB" "$PIO" run -d "$FW" -e C3-USB
fi
if ((CPPCHECK)); then
    step "pio check -e C3-USB" "$PIO" check -d "$FW" -e C3-USB --fail-on-defect=low
fi

echo
if ((${#failed[@]})); then
    echo "lint FAILED: ${failed[*]}" >&2
    exit 1
fi
echo "lint passed"
