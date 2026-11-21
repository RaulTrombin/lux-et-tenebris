# CLAUDE.md: lightpack-C3 firmware

ESP32-C3 SuperMini firmware for Lux et Portabilis V2. Arduino-ESP32 3.0.1 on PlatformIO
(`espressif32@6.11.0`). Build, test and lint commands are in the repo-root `CLAUDE.md`.

## Code structure

- **Header-only unity build.** `src/main.cpp` includes `src/shared/dependencies.h`, which
  includes every library and then every `src/**/*.h` in dependency order. Headers define
  functions and globals directly and carry `#if !defined(SERVICE_...)` guards.
- **Include order in `dependencies.h` is load-bearing.** Later headers use globals and
  functions from earlier ones, and its comments say why each one sits where it does. Add a new
  header at the point where everything it uses is already included. `SortIncludes: Never`
  keeps clang-format from reordering it.
- `src/rf_probe.cpp` is a standalone bench probe with its own `setup()`/`loop()`.
  `build_src_filter` builds it only in `C3-RF` and excludes it everywhere else.
- `tools/button_probe/` is a separate PlatformIO project (`pio run -d tools/button_probe`),
  not an environment of this one.
- `tools/build_plain_ar.py` is a pre-build hook for Windows Device Guard hosts. See the note in
  `platformio.ini`.
- `src/services/webpage.h` embeds the device web page in a raw string,
  `R"HTMLPAGE(...)HTMLPAGE"`. Its contents are HTML/JS, not C++, and formatters must not touch
  them.

## Comments

Comments use Better Comments markers and explain *why*, not what:
`//*` for the main point, `//?` for supporting detail, `//!` for warnings and hard-won facts
(measurements, past failures). Keep them hand-wrapped. The same markers appear as `;*` `;?` `;!`
in `platformio.ini`.

## Versioning and CHANGELOG

- The firmware version is `LIGHTPACK_FW_VERSION` in `src/shared/variables.h` (for example
  `"0.6.4-dev"`). It is reported over USB and on the web page.
- A user-visible change bumps the patch number and adds a section at the top of
  `CHANGELOG.md`: `## [x.y.z-dev] - YYYY-MM-DD`, a one-line summary, then bullets.
- That commit's subject ends with the version: `Console: add Wi-Fi provisioning over USB; 0.6.3-dev`.
  Subjects start with the area: `Firmware:`, `Console:`, `Docs:`, `Release:`, `USB updater:`.
- When a build should be installable from the console, the same commit refreshes
  `releases/latest/` (`firmware.bin`, `SHA256SUMS.txt`, `manifest.json`, `BUILD.txt`) by the
  steps in `releases/README.md`.

## Static analysis

`pio check -e C3-USB` runs cppcheck with `check_skip_packages = yes`. That setting is required:
cppcheck can't parse the toolchain's libstdc++ headers. Library findings are suppressed in
`platformio.ini`. Findings in `src/` are fixed, or suppressed inline with a reason:
`// cppcheck-suppress <id> ; <reason>`.
