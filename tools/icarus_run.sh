#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: tools/icarus_run.sh test/<tb_file>.sv [extra iverilog args...]"
  exit 2
fi

TB_FILE="$1"; shift || true
mkdir -p build
OUT="build/$(basename "${TB_FILE%.sv}").vvp"

# Collect source files deterministically
SRCS=$(find src -type f \( -name '*.sv' -o -name '*.v' \) | sort)

# Compile & run
iverilog -g2012 -Wall -I include -I src -I test -o "$OUT" $SRCS "$TB_FILE" "$@"
vvp "$OUT"
