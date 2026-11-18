# Verbatim copy of OpenROAD-flow-scripts flow/platforms/nangate45/tapcell.tcl @ 7a57dddc8
#   https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts/blob/7a57dddc8427845f75a14bd975328ee8717a1c8b/flow/platforms/nangate45/tapcell.tcl
# Do not edit below the marker; re-sync from upstream instead (see README.md).
# ----8<---- upstream content starts here
tapcell \
  -distance 120 \
  -tapcell_master "$::env(TAP_CELL_NAME)" \
  -endcap_master "$::env(TAP_CELL_NAME)"
