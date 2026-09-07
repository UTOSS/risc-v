#!/bin/bash
# Build a single comparison report from per-config metric diff artifacts.
# Usage: aggregate_metrics.sh [artifacts_dir] [output_file]

set -euo pipefail

ARTIFACTS_DIR="${1:-metrics-diff}"
OUTPUT_FILE="${2:-comparison.md}"

append_metric_cell() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "      *missing*" >> "$OUTPUT_FILE"
    return
  fi

  sed 's/^/      /' "$file" >> "$OUTPUT_FILE"
}

echo "## 📊 Synthesis & Hardening Report Summary Diff" > "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

configs=$(
  for d in "$ARTIFACTS_DIR"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    if [[ "$name" =~ ^de1-soc-synthesis-metrics-diff-(.+)$ ]]; then
      echo "${BASH_REMATCH[1]}"
    elif [[ "$name" =~ ^hardening-metrics-diff-(.+)$ ]]; then
      echo "${BASH_REMATCH[1]}"
    fi
  done | sort -u
)

if [ -z "$configs" ]; then
  echo "- *No metrics diff artifacts found*" >> "$OUTPUT_FILE"
else
  for config in $configs; do
    echo "- \`${config}\`" >> "$OUTPUT_FILE"

    # DE1-SoC synthesis section
    de1_dir="$ARTIFACTS_DIR/de1-soc-synthesis-metrics-diff-${config}"
    echo "  - **DE1-SoC synthesis**" >> "$OUTPUT_FILE"
    echo "    - Fitter summary" >> "$OUTPUT_FILE"
    append_metric_cell "$de1_dir/fitter_summary.md"
    echo "" >> "$OUTPUT_FILE"
    echo "    - Fitter by entity" >> "$OUTPUT_FILE"
    append_metric_cell "$de1_dir/fitter_by_entity.md"
    echo "" >> "$OUTPUT_FILE"
    echo "    - Timing" >> "$OUTPUT_FILE"
    append_metric_cell "$de1_dir/timing_summary.md"
    echo "" >> "$OUTPUT_FILE"

    # Nangate45 hardening section
    harden_dir="$ARTIFACTS_DIR/hardening-metrics-diff-${config}"
    echo "  - **Nangate45 hardening**" >> "$OUTPUT_FILE"
    echo "    - Utilization" >> "$OUTPUT_FILE"
    append_metric_cell "$harden_dir/hardening_utilization.md"
    echo "" >> "$OUTPUT_FILE"
    echo "    - Gate breakdown" >> "$OUTPUT_FILE"
    append_metric_cell "$harden_dir/hardening_gate_breakdown.md"
    echo "" >> "$OUTPUT_FILE"
  done
fi

echo "---" >> "$OUTPUT_FILE"
echo "*Comparing synthesis & hardening results from main branch vs. this PR*" >> "$OUTPUT_FILE"
