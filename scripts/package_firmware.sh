#!/usr/bin/env bash
# Package a built C3-USB image into a release folder, following the steps in
# Firmware/lightpack-C3/releases/README.md ("cutting a release"). Works from any cwd.
#
#   scripts/package_firmware.sh [--build] [--version V] [OUT_DIR]
#
#   --build      run `pio run -e C3-USB` first (otherwise the existing build is used)
#   --version V  label for file names and the manifest (default: LIGHTPACK_FW_VERSION)
#   OUT_DIR      default: Firmware/lightpack-C3/.pio/dist/<version>
#
# Output: app image, bootloader, partition table, boot_app0, merged factory image,
# ESP Web Tools manifest.json, SHA256SUMS.txt, BUILD.txt and THIRD-PARTY-NOTICES.md.
set -euo pipefail
# shellcheck source=scripts/_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

BUILD=0
VERSION=""
OUT=""
while (($#)); do
    case "$1" in
    --build) BUILD=1 ;;
    --version)
        VERSION="${2:?--version needs a value}"
        shift
        ;;
    -h | --help)
        sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    -*) die "unknown option: $1 (try --help)" ;;
    *) OUT="$1" ;;
    esac
    shift
done

PIO="$(find_pio)"
if [[ -z "$VERSION" ]]; then
    VERSION="$(sed -nE 's/^#define LIGHTPACK_FW_VERSION "([^"]+)".*/\1/p' "$FW/src/shared/variables.h")"
    [[ -n "$VERSION" ]] || die "could not read LIGHTPACK_FW_VERSION from src/shared/variables.h"
fi
OUT="${OUT:-$FW/.pio/dist/$VERSION}"

if ((BUILD)); then
    "$PIO" run -d "$FW" -e C3-USB
fi

BUILD_DIR="$FW/.pio/build/C3-USB"
for f in firmware.bin bootloader.bin partitions.bin; do
    [[ -f "$BUILD_DIR/$f" ]] || die "$BUILD_DIR/$f missing; build first (or pass --build)"
done
BOOT_APP0="$HOME/.platformio/packages/framework-arduinoespressif32/tools/partitions/boot_app0.bin"
[[ -f "$BOOT_APP0" ]] || die "boot_app0.bin not found at $BOOT_APP0"

mkdir -p "$OUT"
cp "$BUILD_DIR/firmware.bin" "$BUILD_DIR/bootloader.bin" "$BUILD_DIR/partitions.bin" "$OUT/"
cp "$BOOT_APP0" "$OUT/"
cp "$ROOT/THIRD-PARTY-NOTICES.md" "$OUT/"

FACTORY="lightpack-C3-$VERSION-factory.bin"
# Offsets and flash settings as in releases/README.md; the order matters.
(cd "$OUT" && "$PIO" pkg exec --package="tool-esptoolpy" -- esptool.py --chip esp32c3 merge_bin \
    -o "$FACTORY" --flash_mode qio --flash_freq 80m --flash_size 4MB \
    0x0 bootloader.bin 0x8000 partitions.bin 0xe000 boot_app0.bin 0x10000 firmware.bin)

# The browser installer flashes the factory image at offset 0 (see V0.4-pre/manifest.json).
cat >"$OUT/manifest.json" <<EOF
{
  "name": "lightpack-C3",
  "version": "$VERSION",
  "builds": [
    {
      "chipFamily": "ESP32-C3",
      "parts": [
        { "path": "$FACTORY", "offset": 0 }
      ]
    }
  ]
}
EOF

(cd "$OUT" && sha256sum -- *.bin >SHA256SUMS.txt)

{
    echo "version: $VERSION"
    echo "built:   $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "source:  $(git -C "$ROOT" describe --always --dirty --tags 2>/dev/null || echo unknown)"
    echo
    for f in firmware.bin "$FACTORY"; do
        printf '%-40s %8d bytes\n' "$f" "$(stat -c%s "$OUT/$f")"
    done
} >"$OUT/BUILD.txt"

echo "packaged $VERSION into $OUT:"
ls -l "$OUT"
