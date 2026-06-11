#!/bin/bash
set -euo pipefail

# measure.sh — measures code duplication in the Wifi pak
# Metric: code_duplication_points — number of redundant/duplicated code blocks

PAK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PAK_DIR"

dup_points=0
unique_sourced=0

# ============================================================
# Check 1: Shared library sourced by all scripts
# ============================================================

for f in launch.sh bin/service-off bin/service-on bin/wifi-enabled; do
    if [ -f "$f" ]; then
        unique_sourced=$((unique_sourced + 1))
        if ! grep -q '\. ".*lib/platform.sh"' "$f"; then
            echo "DUP: $f does not source bin/lib/platform.sh (missed extraction opportunity)"
            dup_points=$((dup_points + 1))
        fi
    fi
done

# ============================================================
# Check 2: Credential parsing should use parse_wifi_line helper
# ============================================================

if [ -f launch.sh ]; then
    # Count occurrences of raw colon-splitting patterns that should use parse_wifi_line
    raw_split=$(grep -c 'echo .*|.*cut -d:' launch.sh || true)
    if [ "$raw_split" -gt 0 ]; then
        echo "DUP: $raw_split raw credential-splitting patterns not using parse_wifi_line()"
        dup_points=$((dup_points + raw_split))
    fi

    # Count inline comment-skipping grep -q "^#" patterns
    comment_skip=$(grep -c 'grep.*"^#"' launch.sh || true)
    if [ "$comment_skip" -gt 1 ]; then
        duplicates=$((comment_skip - 1))
        echo "DUP: $duplicates extra inline comment-skipping patterns not using parse_wifi_line()"
        dup_points=$((dup_points + duplicates))
    fi

    # Count inline colon-format checks
    colon_check=$(grep -c 'grep -q ":"' launch.sh || true)
    if [ "$colon_check" -gt 1 ]; then
        duplicates=$((colon_check - 1))
        echo "DUP: $duplicates extra inline colon-format checks not using parse_wifi_line()"
        dup_points=$((dup_points + duplicates))
    fi
fi

# ============================================================
# Check 3: platform.sh has all expected functions
# ============================================================

expected_funcs="normalize_platform has_system_json get_system_json_path set_system_json get_system_json has_custom_wpa_template get_wpa_template_path get_wpa_conf_path install_wpa_config has_netplan parse_wifi_line"
missing=0
for func in $expected_funcs; do
    if [ -f bin/lib/platform.sh ]; then
        if ! grep -q "^${func}()" bin/lib/platform.sh; then
            missing=$((missing + 1))
        fi
    fi
done
if [ "$missing" -gt 0 ]; then
    echo "DUP: $missing expected functions missing from bin/lib/platform.sh"
    dup_points=$((dup_points + missing))
fi

# ============================================================
# Check 4: No raw per-platform chains in main scripts (should use helpers)
# ============================================================

# Look for multi-branch platform conditionals outside the shared lib
for f in bin/service-off bin/wifi-enabled; do
    if [ -f "$f" ]; then
        # These should use has_system_json/get_system_json_path instead of explicit PLATFORM checks
        explicit_checks=$(grep -c 'PLATFORM.*=' "$f" || true)
        if [ "$explicit_checks" -gt 2 ]; then
            redundant=$((explicit_checks - 2))
            echo "DUP: $redundant extra explicit PLATFORM checks in $f"
            dup_points=$((dup_points + redundant))
        fi
    fi
done

# ============================================================
# Output metrics
# ============================================================

echo "METRIC code_duplication_points=$dup_points"
echo "METRIC unique_sourced=$unique_sourced"
echo "METRIC lib_functions=$((9 + $(grep -c '^parse_wifi_line()' bin/lib/platform.sh 2>/dev/null || true)))"

if [ "$dup_points" -gt 0 ]; then
    echo "FAILED: $dup_points duplication points remain"
    exit 1
fi

echo "PASSED: No code duplication detected"
exit 0
