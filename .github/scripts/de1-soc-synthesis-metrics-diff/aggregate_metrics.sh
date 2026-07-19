#!/bin/bash
# Build a single comparison report from per-config metric diff artifacts.
# Usage: aggregate_metrics.sh [artifacts_dir] [output_file]

set -euo pipefail

ARTIFACTS_DIR="${1:-metrics-diff}"
OUTPUT_FILE="${2:-comparison.md}"

append_metric_cell() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "     *missing*" >> "$OUTPUT_FILE"
    return
  fi

  sed 's/^/     /' "$file" >> "$OUTPUT_FILE"
}

echo "## 🔧 DE1-SoC Synthesis Report Summary Diff" > "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

found_any=false
while IFS= read -r dir; do
  found_any=true
  config="${dir##*de1-soc-synthesis-metrics-diff-}"

  echo "- \`${config}\`" >> "$OUTPUT_FILE"
  echo "  1. Fitter Summary" >> "$OUTPUT_FILE"
  append_metric_cell "$dir/fitter_summary.md"
  echo "" >> "$OUTPUT_FILE"
  echo "  2. Fitter by entity" >> "$OUTPUT_FILE"
  append_metric_cell "$dir/fitter_by_entity.md"
  echo "" >> "$OUTPUT_FILE"
  echo "  3. Timing" >> "$OUTPUT_FILE"
  append_metric_cell "$dir/timing_summary.md"
  echo "" >> "$OUTPUT_FILE"
done < <(find "$ARTIFACTS_DIR" -mindepth 1 -maxdepth 1 -type d -name 'de1-soc-synthesis-metrics-diff-*' | sort)

if [ "$found_any" = false ]; then
  echo "- *No metrics diff artifacts found*" >> "$OUTPUT_FILE"
fi

echo "" >> "$OUTPUT_FILE"
echo "---" >> "$OUTPUT_FILE"
echo "*Comparing synthesis results from main branch vs. this PR*" >> "$OUTPUT_FILE"
