#!/usr/bin/env bash
# Open the OpenROAD GUI on the noVNC desktop (started from the desktop's right-click menu).
#
#   openroad-gui.sh          load the last `make harden` result (envs/hardening/out/pnr/top.odb)
#                            together with the liberty + SDC, so timing paths can be inspected
#   openroad-gui.sh --empty  start the GUI without a design
#
# Any other `out/pnr/*.odb` stage snapshot can be opened from the GUI's Tcl console with
# `read_db <path>` (in a fresh GUI).

set -euo pipefail

WORKSPACE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HARDENING_DIR="$WORKSPACE/envs/hardening"
ODB="$HARDENING_DIR/out/pnr/top.odb"
PDK_LIB="${PDK_LIB:-/opt/pdks/nangate45/NangateOpenCellLibrary_typical.lib}"
SDC="$HARDENING_DIR/constraints/top.sdc"

export DISPLAY="${DISPLAY:-:1}"
cd "$HARDENING_DIR"

if [[ "${1:-}" == "--empty" ]]; then
  exec openroad -gui
fi

if [[ ! -f "$ODB" ]]; then
  xmessage -center "No hardened layout found at:
$ODB

Run 'make harden' in envs/hardening first." || true
  exit 1
fi

script="$(mktemp --suffix=.tcl)"
cat > "$script" <<EOF
read_db $ODB
read_liberty $PDK_LIB
read_sdc $SDC
set_propagated_clock [all_clocks]
estimate_parasitics -global_routing
puts "Loaded $ODB (timing uses global-route parasitics, as in scripts/harden.tcl)"
EOF

exec openroad -gui "$script"
