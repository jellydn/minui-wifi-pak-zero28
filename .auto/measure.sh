#!/bin/bash
set -euo pipefail

# measure.sh — verifies release build integrity for zero28

PAK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PAK_DIR"

errors=0

# Check that platform.sh is tracked by git (required for release zip)
echo "=== Check 1: bin/lib/platform.sh tracked in git ==="
if git ls-files --error-unmatch bin/lib/platform.sh >/dev/null 2>&1; then
  echo "OK: platform.sh is tracked"
else
  echo "FAIL: platform.sh not tracked (will be missing from release zip)"
  errors=$((errors + 1))
fi

# Check that service scripts all source platform.sh
echo "=== Check 2: All scripts source platform.sh ==="
for f in launch.sh bin/service-off bin/service-on bin/wifi-enabled; do
  if grep -q '\. ".*lib/platform.sh"' "$f"; then
    echo "OK: $f sources platform.sh"
  else
    echo "FAIL: $f does not source platform.sh"
    errors=$((errors + 1))
  fi
done

# Check shellcheck
echo "=== Check 3: shellcheck ==="
sc=0
for f in launch.sh bin/service-off bin/service-on bin/wifi-enabled bin/lib/platform.sh; do
  count=$(shellcheck --severity=warning "$f" 2>/dev/null | grep -c "^In " || true)
  sc=$((sc + count))
done
echo "Shellcheck warnings: $sc"
if [ "$sc" -gt 0 ]; then
  errors=$((errors + sc))
fi

echo ""
echo "METRIC release_errors=$errors"
if [ "$errors" -gt 0 ]; then
  echo "FAILED: $errors issues found"
  exit 1
fi
echo "PASSED: Release integrity verified"
exit 0
