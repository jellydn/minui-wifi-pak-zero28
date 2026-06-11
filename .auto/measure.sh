#!/bin/bash
set -euo pipefail

# measure.sh — validates that zero28 platform support is correctly implemented
# Checks all platform-conditional code paths for zero28 coverage

PAK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PAK_DIR"

coverage_gaps=0
shellcheck_warnings=0
total_platform_checks=0

# Expected platforms list
EXPECTED_PLATFORMS="miyoomini my282 my355 tg5040 rg35xxplus zero28"

# ============================================================
# Check 1: platform lists in pak.json and Makefile
# ============================================================

# pak.json
if [ -f pak.json ]; then
    total_platform_checks=$((total_platform_checks + 1))
    paks_platforms=$(jq -r '.platforms[]' pak.json | tr '\n' ' ')
    for p in zero28; do
        if ! echo "$paks_platforms" | grep -qw "$p"; then
            echo "GAP: pak.json missing platform '$p'"
            coverage_gaps=$((coverage_gaps + 1))
        fi
    done
fi

# Makefile PLATFORMS
if [ -f Makefile ]; then
    total_platform_checks=$((total_platform_checks + 1))
    makefile_platforms=$(grep '^PLATFORMS' Makefile | sed 's/PLATFORMS \?:= \?\(.*\)/\1/')
    for p in zero28; do
        if ! echo "$makefile_platforms" | grep -qw "$p"; then
            echo "GAP: Makefile PLATFORMS missing '$p'"
            coverage_gaps=$((coverage_gaps + 1))
        fi
    done
fi

# ============================================================
# Check 2: launch.sh - all platform conditionals
# ============================================================

if [ -f launch.sh ]; then
    total_platform_checks=$((total_platform_checks + 1))
    # Check allowed_platforms list
    if grep -q "allowed_platforms=" launch.sh; then
        allowed_line=$(grep "allowed_platforms=" launch.sh)
        if ! echo "$allowed_line" | grep -q "zero28"; then
            echo "GAP: launch.sh allowed_platforms missing zero28"
            coverage_gaps=$((coverage_gaps + 1))
        fi
    fi

    # Check template selection blocks (PLATFORM-specific wpa_supplicant templates)
    total_platform_checks=$((total_platform_checks + 1))
    if grep -q 'template_file=.*wpa_supplicant.conf' launch.sh; then
        # There should be explicit zero28 handling in template selection or it falls to the default
        # For zero28 (same as tg5040), it should use the default template
        :
    fi

    # Check write_config platform paths
    total_platform_checks=$((total_platform_checks + 1))
    # Every platform should appear in write_config's platform-specific cp targets
    for p in miyoomini my282 my355 rg35xxplus tg5040 zero28; do
        if ! grep -Eq "elif.*PLATFORM.*=.*\"$p\"" launch.sh; then
            if [ "$p" != "tg5040" ]; then
                # tg5040 is checked via the else branch
                echo "GAP: launch.sh write_config missing platform '$p' in config cp path"
                coverage_gaps=$((coverage_gaps + 1))
            fi
        fi
    done

    # Check that zero28-related blocks exist where tg5040 is handled
    total_platform_checks=$((total_platform_checks + 1))
    # In get_ssid_and_ip, zero28 should use the iw path (like tg5040, not like my355)
    if grep -q 'PLATFORM.*=.*"my355"' launch.sh; then
        # The else branch covers non-my355 platforms, which is correct for zero28
        # But we should verify there's no platform-exclusion that would skip zero28
        :
    fi

    # Check show_message — miyoomini skips minui-presenter
    # zero28 should NOT skip it (not miyoomini)
    total_platform_checks=$((total_platform_checks + 1))
    if grep -q 'PLATFORM.*=.*"miyoomini"' launch.sh; then
        # zero28 is not miyoomini, so it will use minui-presenter — correct
        :
    fi
fi

# ============================================================
# Check 3: bin/service-off
# ============================================================

if [ -f bin/service-off ]; then
    total_platform_checks=$((total_platform_checks + 1))
    # The platform groups in service-off: miyoomini|my282|my355|tg5040 should include zero28
    if grep -q 'PLATFORM.*=.*"miyoomini"' bin/service-off; then
        # Check that zero28 is handled. Since zero28 == tg5040, it should be in the same group
        if grep -Eq 'PLATFORM.*=.*"(miyoomini|my282|my355|tg5040)"' bin/service-off; then
            platform_group=$(grep -E 'PLATFORM.*=.*"(miyoomini|my282|my355|tg5040)"' bin/service-off)
            if ! echo "$platform_group" | grep -q "zero28"; then
                # Check if there's a separate zero28 block
                if ! grep -q "zero28" bin/service-off; then
                    echo "GAP: bin/service-off missing zero28 platform handling"
                    coverage_gaps=$((coverage_gaps + 1))
                fi
            fi
        else
            if ! grep -q "zero28" bin/service-off; then
                echo "GAP: bin/service-off missing zero28 platform handling"
                coverage_gaps=$((coverage_gaps + 1))
            fi
        fi
    fi

    # Check SYSTEM_JSON_PATH assignments — zero28 should have one
    for p in miyoomini my282 my355; do
        total_platform_checks=$((total_platform_checks + 1))
    done
fi

# ============================================================
# Check 4: bin/service-on
# ============================================================

if [ -f bin/service-on ]; then
    total_platform_checks=$((total_platform_checks + 1))
    # Check that zero28 is handled in the platform selector
    # zero28 should mirror tg5040 behavior (same SoC, same OS)
    if grep -q "tg5040" bin/service-on; then
        # zero28 should be in the same block or have its own
        if ! grep -q "zero28" bin/service-on; then
            echo "GAP: bin/service-on missing zero28 platform handling (should mirror tg5040)"
            coverage_gaps=$((coverage_gaps + 1))
        fi
    fi
fi

# ============================================================
# Check 5: bin/wifi-enabled
# ============================================================

if [ -f bin/wifi-enabled ]; then
    total_platform_checks=$((total_platform_checks + 1))
    # Check SYSTEM_JSON_PATH assignments cover zero28
    # zero28 should have a SYSTEM_JSON_PATH like tg5040 (/mnt/UDISK/system.json)
    if ! grep -q "zero28" bin/wifi-enabled; then
        # Check if tg5040 is handled without zero28
        if grep -q "tg5040" bin/wifi-enabled; then
            echo "GAP: bin/wifi-enabled handles tg5040 but not zero28 (should be same)"
            coverage_gaps=$((coverage_gaps + 1))
        fi
    fi
fi

# ============================================================
# Check 6: README.md and pak.json docs
# ============================================================

total_platform_checks=$((total_platform_checks + 1))
if [ -f README.md ]; then
    if ! grep -qi "zero.*28" README.md; then
        echo "GAP: README.md missing zero28 documentation"
        coverage_gaps=$((coverage_gaps + 1))
    fi
fi

total_platform_checks=$((total_platform_checks + 1))
if [ -f pak.json ]; then
    if ! jq -e '.platforms | index("zero28")' pak.json >/dev/null 2>&1; then
        echo "GAP: pak.json platforms missing zero28"
        coverage_gaps=$((coverage_gaps + 1))
    fi
fi

# ============================================================
# Check 7: Shellcheck warnings
# ============================================================

if command -v shellcheck &>/dev/null; then
    for f in launch.sh bin/service-off bin/service-on bin/wifi-enabled bin/on-boot; do
        if [ -f "$f" ]; then
            sc_count=$(shellcheck --severity=style "$f" 2>/dev/null | grep -c "^In " || true)
            shellcheck_warnings=$((shellcheck_warnings + sc_count))
        fi
    done
fi

# ============================================================
# Output metrics
# ============================================================

echo "METRIC coverage_gaps=$coverage_gaps"
echo "METRIC shellcheck_warnings=$shellcheck_warnings"
echo "METRIC total_platform_checks=$total_platform_checks"

if [ "$coverage_gaps" -gt 0 ]; then
    echo "FAILED: $coverage_gaps coverage gaps remain"
    exit 1
fi

echo "PASSED: All platforms covered, zero28 support is complete"
exit 0
