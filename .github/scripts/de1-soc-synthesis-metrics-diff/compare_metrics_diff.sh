#!/bin/bash
# Script to compare a synthesis report between main and PR branches
# Usage: compare_metrics_diff.sh <main_report_path> <pr_report_path>
# Example: compare_metrics_diff.sh "main-reports/report.summary" "pr-reports/report.summary"

set -e

if [ $# -lt 2 ]; then
  echo "Usage: $0 <main_report_path> <pr_report_path>" >&2
  exit 1
fi

MAIN_REPORT="$1"
PR_REPORT="$2"

if [ ! -f "$PR_REPORT" ]; then
  echo "ERROR: PR report not found at $PR_REPORT" >&2
  exit 1
fi

{
  if [ -f "$MAIN_REPORT" ]; then
    # Generate diff and capture output
    DIFF_OUTPUT=$(diff -u "$MAIN_REPORT" "$PR_REPORT" | tail -n +3 || true)
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
    cat "$PR_REPORT"
    echo "\`\`\`"
    echo "</details>"
  fi
}
