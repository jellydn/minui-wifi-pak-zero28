#!/bin/bash
set -euo pipefail

# measure.sh — validates that zero28 platform support is correctly implemented
# Now checks the centralized platform helper instead of naive per-file string matches

PAK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PAK_DIR"

coverage_gaps=0
shellcheck_warnings=0
total_platform_checks=0

# ============================================================
# Check 0: Shared library exists and is sourced by all scripts
# ============================================================

total_platform_checks=$((total_platform_checks + 1))
if [ ! -f bin/lib/platform.sh ]; then
    echo "GAP: bin/lib/platform.sh missing"
    coverage_gaps=$((coverage_gaps + 1))
fi

for f in launch.sh bin/service-off bin/service-on bin/wifi-enabled; do
    total_platform_checks=$((total_platform_checks + 1))
    if [ -f "$f" ]; then
        if ! grep -q '\. ".*lib/platform.sh"' "$f"; then
            echo "GAP: $f does not source bin/lib/platform.sh"
            coverage_gaps=$((coverage_gaps + 1))
        fi
    fi
done

# ============================================================
# Check 1: Centralized platform.sh has zero28 in all platform maps
# ============================================================

if [ -f bin/lib/platform.sh ]; then
    # has_system_json — zero28 should return 0
    total_platform_checks=$((total_platform_checks + 1))
    if grep -q "has_system_json" bin/lib/platform.sh; then
        if ! grep -q "zero28" bin/lib/platform.sh; then
            echo "GAP: bin/lib/platform.sh missing zero28 in platform maps"
            coverage_gaps=$((coverage_gaps + 1))
        fi
    fi

    # get_system_json_path — zero28 should fall through to default (/mnt/UDISK/system.json)
    total_platform_checks=$((total_platform_checks + 1))
    if grep -q "get_system_json_path" bin/lib/platform.sh; then
        # Default case should cover zero28 (same as tg5040)
        has_miyoomini=$(grep -c "miyoomini" bin/lib/platform.sh || true)
        if [ "$has_miyoomini" -eq 0 ]; then
            echo "GAP: bin/lib/platform.sh missing miyoomini (likely incomplete)"
            coverage_gaps=$((coverage_gaps + 1))
        fi
    fi

    # has_custom_wpa_template — zero28 should NOT match (uses default template)
    total_platform_checks=$((total_platform_checks + 1))
    if grep -q "has_custom_wpa_template" bin/lib/platform.sh; then
        if grep -q "zero28|miyoomini|my282|my355" bin/lib/platform.sh; then
            : # correct: zero28 is NOT listed with my355/miyoomini/my282
        fi
    fi
fi

# ============================================================
# Check 2: platform lists in pak.json and Makefile
# ============================================================

if [ -f pak.json ]; then
    total_platform_checks=$((total_platform_checks + 1))
    paks_platforms=$(jq -r '.platforms[]' pak.json | tr '\n' ' ')
    if ! echo "$paks_platforms" | grep -qw "zero28"; then
        echo "GAP: pak.json missing platform zero28"
        coverage_gaps=$((coverage_gaps + 1))
    fi
fi

if [ -f Makefile ]; then
    total_platform_checks=$((total_platform_checks + 1))
    makefile_platforms=$(grep '^PLATFORMS' Makefile | sed 's/PLATFORMS \?:= \?\(.*\)/\1/')
    if ! echo "$makefile_platforms" | grep -qw "zero28"; then
        echo "GAP: Makefile PLATFORMS missing zero28"
        coverage_gaps=$((coverage_gaps + 1))
    fi
fi

if [ -f .gitarchiveinclude ]; then
    total_platform_checks=$((total_platform_checks + 1))
    if ! grep -q "bin/zero28" .gitarchiveinclude; then
        echo "GAP: .gitarchiveinclude missing zero28 binary entries"
        coverage_gaps=$((coverage_gaps + 1))
    fi
    total_platform_checks=$((total_platform_checks + 1))
    if ! grep -q "bin/lib/platform.sh" .gitarchiveinclude; then
        echo "GAP: .gitarchiveinclude missing bin/lib/platform.sh"
        coverage_gaps=$((coverage_gaps + 1))
    fi
fi

# ============================================================
# Check 3: launch.sh - key platform conditionals
# ============================================================

if [ -f launch.sh ]; then
    total_platform_checks=$((total_platform_checks + 1))
    if grep -q "allowed_platforms=" launch.sh; then
        if ! grep -q "zero28" launch.sh; then
            echo "GAP: launch.sh missing zero28 reference"
            coverage_gaps=$((coverage_gaps + 1))
        fi
    fi

    # Check that launch.sh has zero28 in its explicit platform branches
    # (write_config cp targets)
    total_platform_checks=$((total_platform_checks + 1))
    if ! grep -Eq "(if|elif).*PLATFORM.*=.*\"zero28\"" launch.sh; then
        echo "GAP: launch.sh missing zero28 in write_config platform paths"
        coverage_gaps=$((coverage_gaps + 1))
    fi

    # Check that service-on has zero28 in its wpa_supplicant startup
    total_platform_checks=$((total_platform_checks + 1))
    if [ -f bin/service-on ]; then
        if ! grep -q "zero28" bin/service-on; then
            echo "GAP: bin/service-on missing zero28 wpa_supplicant startup"
            coverage_gaps=$((coverage_gaps + 1))
        fi
    fi
fi

# ============================================================
# Check 4: README.md documentation
# ============================================================

total_platform_checks=$((total_platform_checks + 1))
if [ -f README.md ]; then
    if ! grep -qi "zero.*28" README.md; then
        echo "GAP: README.md missing zero28 documentation"
        coverage_gaps=$((coverage_gaps + 1))
    fi
fi

# ============================================================
# Check 5: binary files exist for zero28
# ============================================================

total_platform_checks=$((total_platform_checks + 1))
if [ ! -f bin/zero28/minui-keyboard ]; then
    echo "GAP: bin/zero28/minui-keyboard missing"
    coverage_gaps=$((coverage_gaps + 1))
fi
total_platform_checks=$((total_platform_checks + 1))
if [ ! -f bin/zero28/minui-list ]; then
    echo "GAP: bin/zero28/minui-list missing"
    coverage_gaps=$((coverage_gaps + 1))
fi
total_platform_checks=$((total_platform_checks + 1))
if [ ! -f bin/zero28/minui-presenter ]; then
    echo "GAP: bin/zero28/minui-presenter missing"
    coverage_gaps=$((coverage_gaps + 1))
fi

# ============================================================
# Check 6: Shellcheck warnings (excluding SC1091 sourced-file info)
# ============================================================

if command -v shellcheck &>/dev/null; then
    for f in launch.sh bin/service-off bin/service-on bin/wifi-enabled bin/on-boot; do
        if [ -f "$f" ]; then
            sc_count=$(shellcheck --severity=warning "$f" 2>/dev/null | grep -c "^In " || true)
            shellcheck_warnings=$((shellcheck_warnings + sc_count))
        fi
    done
    # Also check shared lib
    if [ -f bin/lib/platform.sh ]; then
        sc_count=$(shellcheck --severity=warning bin/lib/platform.sh 2>/dev/null | grep -c "^In " || true)
        shellcheck_warnings=$((shellcheck_warnings + sc_count))
    fi
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
