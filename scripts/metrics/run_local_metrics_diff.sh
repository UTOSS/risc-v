#!/usr/bin/env bash
# Run synthesis and/or hardening on the latest locally fetched main (in a temp snapshot,
# without running `git fetch`) and on the current working tree, then generate the exact
# same Markdown metrics diff report that CI posts on pull requests.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

if [ -n "${METRICS_BASE_REF:-}" ]; then
  BASE_REF="$METRICS_BASE_REF"
elif git rev-parse --verify --quiet origin/main >/dev/null; then
  BASE_REF="origin/main"
else
  BASE_REF="main"
fi

if ! git rev-parse --verify --quiet "$BASE_REF" >/dev/null; then
  echo "ERROR: Baseline git ref '$BASE_REF' does not exist locally." >&2
  echo "Fetch main or set METRICS_BASE_REF=<ref>." >&2
  exit 1
fi

CONFIGS="${METRICS_CONFIGS:-RV32I RV32IZbb_Zbkb RV32IZicsr}"
TARGETS="${METRICS_TARGETS:-de1-soc hardening benchmarks}"
OUTPUT_FILE="${METRICS_DIFF_OUT:-out/metrics-diff.md}"

BASE_SHA="$(git rev-parse --short "$BASE_REF")"
TMP_DIR="$(mktemp -d -t utoss-metrics-diff.XXXXXX)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

BASE_REPO="$TMP_DIR/base-repo"
REPORTS_DIR="$TMP_DIR/reports"
DIFFS_DIR="$TMP_DIR/diffs"
mkdir -p "$BASE_REPO" "$REPORTS_DIR" "$DIFFS_DIR"

echo "==> Exporting baseline snapshot of $BASE_REF ($BASE_SHA) into $BASE_REPO"
git archive "$BASE_REF" | tar -x -C "$BASE_REPO"

has_target() {
  local needle="$1"
  for t in $TARGETS; do
    if [ "$t" = "$needle" ]; then
      return 0
    fi
  done
  return 1
}

collect_de1_soc() {
  local repo="$1"
  local config="$2"
  local dest="$3"
  local qdir="$repo/envs/de1-soc/quartus"

  mkdir -p "$dest/output_files" "$dest/metrics"
  make -C "$repo/envs/de1-soc/poc"
  make -C "$qdir" synthesize UTOSS_RISCV_CONFIG="$config"
  # Remove stale CSV/pretty output so older snapshots (like unmerged main) always regenerate
  rm -f "$qdir/metrics/fitter_utilization.csv" "$qdir/metrics/fitter_utilization.pretty.txt"
  make -C "$qdir" pretty-metrics

  cp "$qdir/output_files/utoss-risc-v.fit.summary" "$dest/output_files/"
  cp "$qdir/output_files/utoss-risc-v.sta.summary" "$dest/output_files/"
  cp "$qdir/metrics/fitter_utilization.csv" "$dest/metrics/"
  cp "$qdir/metrics/fitter_utilization.pretty.txt" "$dest/metrics/"
}

collect_hardening() {
  local repo="$1"
  local config="$2"
  local dest="$3"
  local hdir="$repo/envs/hardening"

  mkdir -p "$dest/metrics"
  # Use harden_pnr when available so tracked layout PNGs are not modified in the working tree;
  # fall back to `harden` on older baseline snapshots that don't have `harden_pnr` yet.
  if make -C "$hdir" -n harden_pnr >/dev/null 2>&1; then
    make -C "$hdir" harden_pnr UTOSS_RISCV_CONFIG="$config"
  else
    make -C "$hdir" harden UTOSS_RISCV_CONFIG="$config"
  fi

  for f in \
    synthesis_utilization.csv \
    synthesis_utilization.pretty.txt \
    gate_breakdown.txt \
    pnr_utilization.csv \
    pnr_utilization.pretty.txt \
    pnr_gate_breakdown.txt \
    pnr_timing.txt; do
    if [ -f "$hdir/metrics/$f" ]; then
      cp "$hdir/metrics/$f" "$dest/metrics/"
    fi
  done
}

collect_benchmarks() {
  local repo="$1"
  local config="$2"
  local dest="$3"

  mkdir -p "$dest"
  if [ -f "$repo/coremark/Makefile" ]; then
    make -C "$repo/coremark" run UTOSS_RISCV_CONFIG="$config"
    if [ -f "$repo/coremark/out/$config/coremark_metrics.txt" ]; then
      cp "$repo/coremark/out/$config/coremark_metrics.txt" "$dest/coremark_metrics.txt"
    fi
  fi
  if [ -f "$repo/embench/Makefile" ]; then
    make -C "$repo/embench" run UTOSS_RISCV_CONFIG="$config" -j"$(nproc)"
    if [ -f "$repo/embench/out/$config/embench_metrics.txt" ]; then
      cp "$repo/embench/out/$config/embench_metrics.txt" "$dest/embench_metrics.txt"
    fi
    if [ -f "$repo/embench/out/$config/results.json" ]; then
      cp "$repo/embench/out/$config/results.json" "$dest/embench_results.json"
    fi
  fi
}

for config in $CONFIGS; do
  if has_target "de1-soc"; then
    base_de1="$REPORTS_DIR/base/de1-soc-$config"
    pr_de1="$REPORTS_DIR/pr/de1-soc-$config"

    echo "==> [de1-soc][$config] Building baseline ($BASE_REF)"
    if ! collect_de1_soc "$BASE_REPO" "$config" "$base_de1"; then
      echo "WARNING: Baseline de1-soc failed for $config; reporting without baseline." >&2
      rm -rf "$base_de1"
    fi

    echo "==> [de1-soc][$config] Building current working tree"
    collect_de1_soc "$REPO_ROOT" "$config" "$pr_de1"

    make --no-print-directory metrics-diff-de1-soc \
      BASE_DIR="$base_de1" \
      PR_DIR="$pr_de1" \
      DIFF_OUT_DIR="$DIFFS_DIR/de1-soc-synthesis-metrics-diff-$config"
  fi

  if has_target "hardening"; then
    base_harden="$REPORTS_DIR/base/hardening-$config"
    pr_harden="$REPORTS_DIR/pr/hardening-$config"

    echo "==> [hardening][$config] Building baseline ($BASE_REF)"
    if ! collect_hardening "$BASE_REPO" "$config" "$base_harden"; then
      echo "WARNING: Baseline hardening failed for $config; reporting without baseline." >&2
      rm -rf "$base_harden"
    fi

    echo "==> [hardening][$config] Building current working tree"
    collect_hardening "$REPO_ROOT" "$config" "$pr_harden"

    make --no-print-directory metrics-diff-hardening \
      BASE_DIR="$base_harden" \
      PR_DIR="$pr_harden" \
      DIFF_OUT_DIR="$DIFFS_DIR/hardening-metrics-diff-$config"
  fi

  if has_target "benchmarks"; then
    base_bench="$REPORTS_DIR/base/benchmarks-$config"
    pr_bench="$REPORTS_DIR/pr/benchmarks-$config"

    echo "==> [benchmarks][$config] Running baseline ($BASE_REF)"
    if ! collect_benchmarks "$BASE_REPO" "$config" "$base_bench"; then
      echo "WARNING: Baseline benchmarks failed for $config; reporting without baseline." >&2
      rm -rf "$base_bench"
    fi

    echo "==> [benchmarks][$config] Running current working tree"
    collect_benchmarks "$REPO_ROOT" "$config" "$pr_bench"

    make --no-print-directory metrics-diff-benchmarks \
      BASE_DIR="$base_bench" \
      PR_DIR="$pr_bench" \
      DIFF_OUT_DIR="$DIFFS_DIR/benchmarks-metrics-diff-$config"
  fi
done

make --no-print-directory metrics-diff-aggregate \
  ARTIFACTS_DIR="$DIFFS_DIR" \
  OUTPUT_FILE="$OUTPUT_FILE" \
  BASE_LABEL="$BASE_REF ($BASE_SHA)" \
  HEAD_LABEL="local working tree"

echo "==> Metrics diff report written to $OUTPUT_FILE"
