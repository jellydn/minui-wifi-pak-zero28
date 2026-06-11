# Autoresearch: Support wifi for MagicX Mini Zero 28

## Objective
Add `zero28` platform support to the minui-wifi-pak so it works on the MagicX Mini Zero 28 (MinUI platform ID: `zero28`). The Zero 28 uses the same Allwinner A133P SoC and Tina Linux as the Trimui Smart Pro/Brick (`tg5040`), so its WiFi support should mirror tg5040's approach.

## Metrics
- **Primary**: coverage_gaps (count, lower is better) — number of platform-conditional code paths that don't handle `zero28`
- **Secondary**: shellcheck_warnings (count), total_platform_checks (count)

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
- N/A — initial implementation
