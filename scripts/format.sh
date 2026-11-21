#!/usr/bin/env bash
# Rewrite every in-scope file with its formatter (clang-format, biome, ruff).
# Formatting only: no lint autofixes are applied. Works from any cwd.
#
# Scope: Firmware/lightpack-C3/{src, console/js, console/tests, tools/*.py}.
# Never touched: console/vendor, releases, tools/button_probe, legacy firmwares.
set -euo pipefail
# shellcheck source=scripts/_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

require git "Install git."
CF="$(find_clang_format)"
BIOME="$(find_biome)"

echo "==> clang-format ($("$CF" --version | head -1))"
mapfile -t files < <(cpp_files)
"$CF" -i --style=file "${files[@]}"

echo "==> biome format"
(cd "$CONSOLE" && "$BIOME" format --write)

echo "==> ruff format"
(cd "$FW" && ruff format)

echo "done. Review with: git diff --stat"
