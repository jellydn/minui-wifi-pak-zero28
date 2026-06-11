#!/bin/bash
set -euo pipefail

# measure.sh — validates that generated wpa_supplicant.conf has properly escaped values
# Primary metric: config_unescaped_values — unescaped quote/backslash positions in config generation

PAK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PAK_DIR"

config_unescaped_values=0

# ============================================================
# Check: does launch.sh escape special chars in SSID/PSK?
# ============================================================

if [ -f launch.sh ]; then
    # The wpa config generation writes ssid="<value>" and psk="<value>"
    # If the value contains " or \, those must be escaped as \" and \\
    # Check: does the ssid=$parsed_ssid / psk=$parsed_psk get escaped before embedding?

    # Scan for the config generation block: echo '    ssid="$ssid"' and echo '    psk="$psk"'
    # These write values directly without sed escaping
    if grep -nE 'echo.*ssid="\$ssid"' launch.sh >/dev/null 2>&1; then
        echo "BUG: SSID embedded directly in wpa_supplicant.conf without escaping quotes/backslashes"
        config_unescaped_values=$((config_unescaped_values + 1))
    fi
    if grep -nE 'echo.*psk="\$psk"' launch.sh >/dev/null 2>&1; then
        echo "BUG: PSK embedded directly in wpa_supplicant.conf without escaping quotes/backslashes"
        config_unescaped_values=$((config_unescaped_values + 1))
    fi
    if grep -nE 'password:.*\$psk' launch.sh >/dev/null 2>&1; then
        echo "BUG: PSK embedded directly in netplan.yaml without escaping"
        config_unescaped_values=$((config_unescaped_values + 1))
    fi
fi

echo "METRIC config_unescaped_values=$config_unescaped_values"

if [ "$config_unescaped_values" -gt 0 ]; then
    echo "FAILED: $config_unescaped_values unescaped config values"
    exit 1
fi

echo "PASSED: All config values properly escaped"
exit 0
