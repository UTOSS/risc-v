# Tcl translation of OpenROAD-flow-scripts flow/platforms/nangate45/config.mk @ 7a57dddc8
#   https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts/blob/7a57dddc8427845f75a14bd975328ee8717a1c8b/flow/platforms/nangate45/config.mk
#
# config.mk is Make syntax, so it cannot be copied verbatim. Only the variables our flow uses are
# carried over, with values unchanged and the upstream line number noted. They are set as ::env
# entries because the verbatim ORFS scripts next to this file (tapcell.tcl, fastroute.tcl) read
# them from there, exactly as they do inside ORFS.

# Tech/Libs (config.mk:7-8); LEF directory is installed by infra/Dockerfile.ci
set ::env(TECH_LEF_NAME) NangateOpenCellLibrary.tech.lef
set ::env(SC_LEF_NAME)   NangateOpenCellLibrary.macro.mod.lef

# Dont use cells to ease congestion (config.mk:16)
set ::env(DONT_USE_CELLS) {TAPCELL_X1 FILLCELL_X1 AOI211_X1 OAI211_X1}

# Fill cells used in fill cell insertion (config.mk:19)
set ::env(FILL_CELLS) {FILLCELL_X1 FILLCELL_X2 FILLCELL_X4 FILLCELL_X8 FILLCELL_X16 FILLCELL_X32}

# Tie cells (config.mk:28-29)
set ::env(TIEHI_CELL_AND_PORT) {LOGIC1_X1 Z}
set ::env(TIELO_CELL_AND_PORT) {LOGIC0_X1 Z}

# Placement site for core cells (config.mk:50)
set ::env(PLACE_SITE) FreePDK45_38x28_10R_NP_162NW_34O

# IO Placer pin layers (config.mk:53-54)
set ::env(IO_PLACER_H) metal5
set ::env(IO_PLACER_V) metal6

# Endcap and Welltie cells (config.mk:62)
set ::env(TAP_CELL_NAME) TAPCELL_X1

# FastRoute options (config.mk:75-77)
set ::env(MIN_ROUTING_LAYER)     metal2
set ::env(MIN_CLK_ROUTING_LAYER) metal4
set ::env(MAX_ROUTING_LAYER)     metal10
