#!/usr/bin/env bash
# Open the Quartus GUI on the noVNC desktop with the DE1-SoC project loaded (started from the
# desktop's right-click menu). Open the Chip Planner from Tools > Chip Planner; it shows the
# placement of the last `make synthesize` in envs/de1-soc/quartus.
#
# On first launch Quartus asks two one-off questions (a "thank you for installing" splash and an
# "only open trusted projects" prompt); both are remembered in ~/.altera.quartus.

set -euo pipefail

WORKSPACE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_DIR="$WORKSPACE/envs/de1-soc/quartus"
PROJECT="utoss-risc-v"

export DISPLAY="${DISPLAY:-:1}"
cd "$PROJECT_DIR"

if [[ ! -d db ]]; then
  xmessage -center "No compiled Quartus database in:
$PROJECT_DIR/db

The project will open, but the Chip Planner needs a compile first:
  cd envs/de1-soc/quartus && make synthesize UTOSS_RISCV_CONFIG=RV32I" || true
fi

exec quartus "$PROJECT.qpf"
