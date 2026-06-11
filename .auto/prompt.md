# Autoresearch: Support wifi for MagicX Mini Zero 28

## Objective
Add `zero28` platform support to the minui-wifi-pak so it works on the MagicX Mini Zero 28 (MinUI platform ID: `zero28`). The Zero 28 uses the same Allwinner A133P SoC and Tina Linux as the Trimui Smart Pro/Brick (`tg5040`), so its WiFi support should mirror tg5040's approach.

## Metrics
- **Primary**: coverage_gaps (count, lower is better) — number of platform-conditional code paths that don't handle `zero28`
- **Secondary**: shellcheck_warnings (count), total_platform_checks (count)

> ⚠️ Both metrics are saturated at zero. Further iterations must define a new primary metric or pivot to a different optimization target.

## How to Run
`./.auto/measure.sh` — outputs `METRIC name=number` lines.

## Files in Scope
- `pak.json` — platform list, needs `zero28` added
- `Makefile` — PLATFORMS list, needs `zero28` added
- `launch.sh` — main app script with platform-conditional config paths, service management, wifi scanning
- `bin/service-off` — wifi disable logic per platform
- `bin/service-on` — wifi enable logic per platform
- `bin/wifi-enabled` — wifi status check per platform
- `bin/on-boot` — calls `service-on`, may need platform awareness
- `res/wpa_supplicant.conf.tmpl` — default wpa_supplicant template (zero28 should use this, mirrors tg5040)
- `res/settings*.json` — UI template files (platform-agnostic, should be fine)
- `README.md` — documentation, needs zero28 listed

## Off Limits
- Do NOT modify `.gitignore`, `.gitattributes`, `.github/`, `screenshots/`, `lib/` (these are binary dependencies or infra)
- Do NOT remove or break existing platform support
- Do NOT add new external dependencies

## Constraints
- All platform conditional checks must handle `zero28` explicitly — no fallthrough to a default branch that masks missing support
- The `zero28` platform uses Moss-zero28 (Tina Linux, same as tg5040/TSP/Brick) so wpa_supplicant config paths should follow tg5040 pattern (`/etc/wifi/wpa_supplicant.conf`)
- The `zero28` platform has `iw` available from the Moss/ReMoss system (does NOT need the bundled miyoomini iw binary)
- The `zero28` platform uses the same `ctrl_interface=/etc/wifi/sockets` pattern as tg5040
- WiFi chipset on zero28 is RTL8189ES (confirmed in reMoss builds), using nl80211 driver — same as tg5040

## Zero 28 Architecture
- SoC: Allwinner A133P (same as Trimui Smart Pro / Brick)
- OS: Moss-zero28 (Tina Linux, same base as tg5040)
- WiFi: RTL8189ES (SDIO), nl80211 driver
- Platform ID in MinUI: `zero28`
- SD card: TF1 = Moss (OS), TF2 = MinUI (apps/games)
- WiFi paths should mirror tg5040: `/etc/wifi/wpa_supplicant.conf`, standard `iw`/`wpa_supplicant`/`udhcpc`

## What's Been Tried
- ✅ Initial implementation complete (coverage_gaps: 9→0)
  - Added `zero28` to `pak.json`, `Makefile`, `.gitarchiveinclude`
  - Added `zero28` to `launch.sh`:
    - `allowed_platforms` list
    - `write_config()` — grouped with `tg5040` for `/etc/wifi/wpa_supplicant.conf` path
  - Added `zero28` to `bin/service-off` — grouped with tg5040/miyoomini/my282/my355 for system.json management
  - Added `zero28` to `bin/service-on` — mirrors tg5040: wpa_supplicant -D nl80211 with /etc/wifi/sockets control interface
  - `bin/wifi-enabled` — default `/mnt/UDISK/system.json` path works correctly (same as tg5040)
  - Downloaded `minui-keyboard-zero28`, `minui-list-zero28`, `minui-presenter-zero28` from upstream releases
  - Updated `README.md` with device documentation
- ✅ Architecture cleanup (shellcheck: 1→0, code duplication eliminated)
  - Created `bin/lib/platform.sh` with: `normalize_platform`, `has_system_json`, `get_system_json_path`, `set_system_json`, `get_system_json`, `has_custom_wpa_template`, `get_wpa_template_path`, `get_wpa_conf_path`, `install_wpa_config`, `has_netplan`, `parse_wifi_line`
  - Refactored `bin/service-off`, `bin/service-on`, `bin/wifi-enabled` to source shared library
  - Refactored `launch.sh` to use shared platform helpers
  - Fixed 4 unused loop variable warnings (`for _ in` instead of `for i in`)
  - Netplan-specific logic extracted to `has_netplan()` helper
  - Credential parsing extracted to `parse_wifi_line()` — 24 lines eliminated from launch.sh
- Architecture rationale: Zero 28 uses the same Allwinner A133P SoC and Tina Linux as tg5040 (Trimui Smart Pro/Brick), with RTL8189ES WiFi via nl80211. All system paths are identical.

## Saturated Metrics — Next Ideas
Both proxy metrics (coverage_gaps=0, shellcheck_warnings=0) are at optimum. Future work needs a new primary metric:
- 🧪 **Functional validation**: Test the pak on real Zero 28 hardware — this is the only way to catch runtime regressions
- 🔌 **Extract wpa_supplicant startup block**: `bin/service-on` still has per-platform startup code (miyoomini uses /customer/app, tg5040/zero28 use wpa_supplicant directly, my282/my355 similar). Could extract `install_wpa_supplicant()` to platform.sh
- 🤝 **Platform family concept**: Codify A133, Sigmastar, Anbernic families to make future additions even simpler
- 📝 **No-use-effect review**: Not applicable (shell scripts), but the extracted pattern is clean
