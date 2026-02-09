#!/bin/bash
# Script to compare FPGA metrics between main and PR branches
# This script is called from the CI workflow to compare synthesis reports

set -e

# Debug: Show what files we have
echo "=== PR reports directory ==="
ls -la pr-reports/ || echo "PR reports directory not found"

echo "=== Main reports directory ==="
ls -la main-reports/ || echo "Main reports directory not found"

# Check if main branch reports exist
if [ -f "main-reports/utoss-risc-v.fit.summary" ]; then
  BASE_FIT="main-reports/utoss-risc-v.fit.summary"
  echo "Found main branch .fit.summary"
else
  BASE_FIT="none"
  echo "No main branch .fit.summary found"
fi

if [ -f "main-reports/utoss-risc-v.sta.summary" ]; then
  BASE_STA="main-reports/utoss-risc-v.sta.summary"
  echo "Found main branch .sta.summary"
else
  BASE_STA="none"
  echo "No main branch .sta.summary found"
fi

# PR reports should always exist
PR_FIT="pr-reports/utoss-risc-v.fit.summary"
PR_STA="pr-reports/utoss-risc-v.sta.summary"

# Check if PR reports exist
if [ ! -f "$PR_FIT" ]; then
  echo "ERROR: PR .fit.summary not found at $PR_FIT"
else
  echo "Found PR .fit.summary"
  echo "First 20 lines of PR .fit.summary:"
  head -20 "$PR_FIT"
fi

if [ ! -f "$PR_STA" ]; then
  echo "ERROR: PR .sta.summary not found at $PR_STA"
else
  echo "Found PR .sta.summary"
  echo "First 20 lines of PR .sta.summary:"
  head -20 "$PR_STA"
fi

# Run comparison script
python3 .github/scripts/compare_fpga_metrics.py "$BASE_FIT" "$PR_FIT" "$BASE_STA" "$PR_STA" > comparison.md

echo "=== Generated comparison report ==="
cat comparison.md

# Output for next step
echo "COMPARISON_FILE=comparison.md" >> "$GITHUB_OUTPUT"
