# Verbatim copy of OpenROAD-flow-scripts flow/platforms/nangate45/fastroute.tcl @ 7a57dddc8
#   https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts/blob/7a57dddc8427845f75a14bd975328ee8717a1c8b/flow/platforms/nangate45/fastroute.tcl
# Do not edit below the marker; re-sync from upstream instead (see README.md).
# ----8<---- upstream content starts here
set_global_routing_layer_adjustment metal2-metal3 0.5
set_global_routing_layer_adjustment metal4-$::env(MAX_ROUTING_LAYER) 0.25

set_routing_layers -clock $::env(MIN_CLK_ROUTING_LAYER)-$::env(MAX_ROUTING_LAYER)
set_routing_layers -signal $::env(MIN_ROUTING_LAYER)-$::env(MAX_ROUTING_LAYER)
