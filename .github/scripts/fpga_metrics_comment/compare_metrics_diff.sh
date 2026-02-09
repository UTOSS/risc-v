#!/bin/bash
# Script to compare FPGA metrics between main and PR branches using git diff
# This script is called from the CI workflow to compare synthesis reports

set -e

# Get the workflow run ID from environment (passed from the workflow)
MAIN_RUN_ID="${MAIN_WORKFLOW_RUN_ID:-}"
MAIN_RUN_URL=""
if [ -n "$MAIN_RUN_ID" ]; then
  MAIN_RUN_URL="https://github.com/${GITHUB_REPOSITORY}/actions/runs/${MAIN_RUN_ID}"
fi

# Check if main branch reports exist
if [ -f "main-reports/utoss-risc-v.fit.summary" ]; then
  BASE_FIT="main-reports/utoss-risc-v.fit.summary"
  echo "Found main branch .fit.summary"
else
  BASE_FIT=""
  echo "No main branch .fit.summary found"
fi

if [ -f "main-reports/utoss-risc-v.sta.summary" ]; then
  BASE_STA="main-reports/utoss-risc-v.sta.summary"
  echo "Found main branch .sta.summary"
else
  BASE_STA=""
  echo "No main branch .sta.summary found"
fi

# PR reports should always exist
PR_FIT="pr-reports/utoss-risc-v.fit.summary"
PR_STA="pr-reports/utoss-risc-v.sta.summary"

# Check if PR reports exist
if [ ! -f "$PR_FIT" ]; then
  echo "ERROR: PR .fit.summary not found at $PR_FIT"
  exit 1
fi

if [ ! -f "$PR_STA" ]; then
  echo "ERROR: PR .sta.summary not found at $PR_STA"
  exit 1
fi

echo "Found PR synthesis reports"

# Generate comparison report
{
  echo "## 🔧 FPGA Synthesis Report"
  echo ""
  
  # FIT Summary comparison
  echo "### 📊 Fitter Summary (.fit.summary)"
  echo ""
  if [ -n "$BASE_FIT" ]; then
    # Generate diff and capture output
    DIFF_OUTPUT=$(diff -u "$BASE_FIT" "$PR_FIT" | tail -n +3 || true)
    if [ -z "$DIFF_OUTPUT" ]; then
      echo "*No changes detected*"
    else
      echo "\`\`\`diff"
      echo "$DIFF_OUTPUT"
      echo "\`\`\`"
    fi
  else
    echo "*No baseline available from main branch*"
    echo ""
    echo "<details>"
    echo "<summary>View PR synthesis results</summary>"
    echo ""
    echo "\`\`\`"
    cat "$PR_FIT"
    echo "\`\`\`"
    echo "</details>"
  fi
  echo ""
  
  # STA Summary comparison
  echo "### ⏱️ Timing Analysis Summary (.sta.summary)"
  echo ""
  if [ -n "$BASE_STA" ]; then
    # Generate diff and capture output
    DIFF_OUTPUT=$(diff -u "$BASE_STA" "$PR_STA" | tail -n +3 || true)
    if [ -z "$DIFF_OUTPUT" ]; then
      echo "*No changes detected*"
    else
      echo "\`\`\`diff"
      echo "$DIFF_OUTPUT"
      echo "\`\`\`"
    fi
  else
    echo "*No baseline available from main branch*"
    echo ""
    echo "<details>"
    echo "<summary>View PR synthesis results</summary>"
    echo ""
    echo "\`\`\`"
    cat "$PR_STA"
    echo "\`\`\`"
    echo "</details>"
  fi
  echo ""
  
  echo "---"
  if [ -n "$MAIN_RUN_URL" ]; then
    echo "*Comparing synthesis results from [main branch run]($MAIN_RUN_URL) vs. this PR*"
  else
    echo "*Comparing synthesis results from main branch vs. this PR*"
  fi
} > comparison.md

echo "=== Generated comparison report ==="
cat comparison.md

# Output for next step
echo "COMPARISON_FILE=comparison.md" >> "$GITHUB_OUTPUT"
