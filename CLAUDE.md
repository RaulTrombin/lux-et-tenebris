# CLAUDE.md

Lux et Tenebris: ESP32 LED controller boards (KiCad) and their Arduino/PlatformIO firmware.

## Layout

| Path | What |
|---|---|
| `Firmware/lightpack-C3/` | **Active firmware.** Lux et Portabilis V2 (ESP32-C3). See its own `CLAUDE.md`. |
| `Firmware/lightpack-C3/console/` | Zero-install Web Serial console (plain ES modules, no build step) |
| `Firmware/lightpack-C3/tools/` | Computer-side Python (USB installer/updater, PlatformIO build hook) |
| `Firmware/lightpack/` | Legacy: Devkit V1 (ESP32-WROOM) firmware |
| `Firmware/Mavuika8266/` | Legacy: ESP8266 sketch |
| `install/` | Browser flasher page (GitHub Pages) |
| `Hardware/`, `Simulations/`, `Media/` | KiCad projects, simulations, media. Not code. |
| `scripts/` | `format.sh` and `lint.sh` for the lightpack-C3 firmware, console and tools |

Tooling, lint and formatting cover only `Firmware/lightpack-C3/{src, console/js, console/tests, tools/*.py}`.
Leave the legacy firmwares, `tools/button_probe` and everything outside that scope as they are.

## Commands

Run from `Firmware/lightpack-C3/` (on Linux, `pio` may be `~/.platformio/penv/bin/pio`):

```bash
pio run -e C3-USB                    # build the firmware
pio run -e C3-USB -t upload          # flash over USB
pio run -e C3-OTA -t upload          # flash over WiFi (espota, lightpack.local)
pio run -e C3-RF -t upload           # RF bench probe, builds src/rf_probe.cpp instead of main.cpp
pio check -e C3-USB                  # cppcheck
(cd console && npm ci && npm test)   # console protocol tests; npm ci installs Biome (dev only)
```

From anywhere in the repo:

```bash
scripts/lint.sh          # clang-format, biome ci, ruff check + format --check, npm test
scripts/lint.sh --all    # ... plus pio run -e C3-USB and pio check -e C3-USB
scripts/format.sh        # rewrite in-scope files with clang-format 18, Biome and ruff
```

## Rules

- Run `scripts/lint.sh` before finishing any change. For any firmware change, also build
  C3-USB (`scripts/lint.sh --all` does both).
- Never edit `releases/**` or `console/vendor/**` by hand. `releases/` holds build artifacts,
  regenerated only by the steps in `Firmware/lightpack-C3/releases/README.md`. `vendor/` is an
  unmodified third-party bundle.
- Never reflow comments. They are hand-wrapped (`ReflowComments: false` in `.clang-format`).
- Never add runtime dependencies to the console. It is served as static files to Chrome/Edge
  89+. Biome is its only (dev) dependency. Don't use JS APIs newer than Chrome 89 (for example,
  no `Object.hasOwn`).
- Mechanical reformat commits go in `.git-blame-ignore-revs`. Enable once per clone:
  `git config blame.ignoreRevsFile .git-blame-ignore-revs`.
