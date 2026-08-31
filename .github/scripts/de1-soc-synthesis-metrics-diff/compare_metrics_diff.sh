#!/bin/bash
# Script to compare a synthesis report between base and PR branches
# Usage: compare_metrics_diff.sh <base_report_path> <pr_report_path>
# Example: compare_metrics_diff.sh "base-reports/report.summary" "pr-reports/report.summary"

set -e

if [ $# -lt 2 ]; then
  echo "Usage: $0 <base_report_path> <pr_report_path>" >&2
  exit 1
fi

BASE_REPORT="$1"
PR_REPORT="$2"
BASE_BRANCH="${BASE_BRANCH:-base branch}"

if [ ! -f "$PR_REPORT" ]; then
  echo "ERROR: PR report not found at $PR_REPORT" >&2
  exit 1
fi

{
  if [ -f "$BASE_REPORT" ]; then
    # Generate diff and capture output
    DIFF_OUTPUT=$(diff -u "$BASE_REPORT" "$PR_REPORT" | tail -n +3 || true)
    if [ -z "$DIFF_OUTPUT" ]; then
      echo "*No changes detected*"
    else
      echo "\`\`\`diff"
      echo "$DIFF_OUTPUT"
      echo "\`\`\`"
    fi
  else
    echo "*No baseline available from \`$BASE_BRANCH\` branch*"
    echo ""
    echo "<details>"
    echo "<summary>View PR synthesis results</summary>"
    echo ""
    echo "\`\`\`"
    cat "$PR_REPORT"
    echo "\`\`\`"
    echo "</details>"
  fi
}
