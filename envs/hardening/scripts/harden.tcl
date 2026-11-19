# Place & route of the synthesized `top` on Nangate45 with OpenROAD, followed by post-PnR timing
# with OpenSTA (the STA engine built into OpenROAD).
#
# Input : $OUT_DIR/top_pnr.v (written by scripts/harden_pre_pnr.tcl, i.e. `make harden_pre_pnr`)
# Output: $OUT_DIR/pnr/*            (odb/def/netlist + raw tool reports; 1_floorplan/2_place/
#                                    3_cts.odb stage snapshots for scripts/dump_layout.tcl)
#         $OUT_DIR/pnr/cells.tsv    (per-instance dump, parsed by scripts/parse_pnr_metrics.py)
#         $OUT_DIR/pnr/summary.json (floorplan/timing/power numbers, ditto)
#
# The flow stops after global routing + filler insertion and times the design on global-route
# parasitics; set PNR_DETAILED_ROUTE=1 to also run detailed routing (much slower).

proc env_or {name default} {
  if {[info exists ::env($name)] && $::env($name) ne ""} {
    return $::env($name)
  }
  return $default
}

set out_dir    [env_or OUT_DIR out]
set pnr_dir    "$out_dir/pnr"
set pdk_dir    [env_or PDK_DIR /opt/pdks/nangate45]
set pdk_lib    [env_or PDK_LIB "$pdk_dir/NangateOpenCellLibrary_typical.lib"]
set sdc_file   [env_or SDC_FILE constraints/top.sdc]

set core_utilization [env_or CORE_UTILIZATION 50]
set place_density    [env_or PLACE_DENSITY 0.65]
set detailed_route   [env_or PNR_DETAILED_ROUTE 0]
set threads          [env_or PNR_THREADS max]

# ---------------------------------------------------------------------------
# Nangate45 platform setup: everything taken from OpenROAD-flow-scripts lives in
# platform/nangate45/ (see the README there); this file only holds our own flow choices
# ---------------------------------------------------------------------------
set platform_dir [env_or PLATFORM_DIR platform/nangate45]
source "$platform_dir/config.tcl"

# not set by ORFS's Nangate45 platform (ORFS lets CTS pick buffers); our choice
set cts_buffers  {CLKBUF_X1 CLKBUF_X2 CLKBUF_X3}
set cts_root_buf CLKBUF_X3

set tech_lef  [env_or TECH_LEF  "$pdk_dir/$::env(TECH_LEF_NAME)"]
set cells_lef [env_or CELLS_LEF "$pdk_dir/$::env(SC_LEF_NAME)"]

foreach f [list $pdk_lib $tech_lef $cells_lef $sdc_file "$out_dir/top_pnr.v"] {
  if {![file exists $f]} {
    error "required input does not exist: $f"
  }
}

file mkdir $pnr_dir
set_thread_count $threads

proc log_stage {name} {
  puts "\n[string repeat = 78]\n== $name\n[string repeat = 78]"
}

# ---------------------------------------------------------------------------
# Load design
# ---------------------------------------------------------------------------
log_stage "load design"
read_lef     $tech_lef
read_lef     $cells_lef
read_liberty $pdk_lib
read_verilog "$out_dir/top_pnr.v"
link_design  top
read_sdc     $sdc_file
source "$platform_dir/setRC.tcl"

set_dont_use $::env(DONT_USE_CELLS)

# ---------------------------------------------------------------------------
# Floorplan, I/O pins, tapcells, power grid
# ---------------------------------------------------------------------------
log_stage "floorplan"
initialize_floorplan -utilization $core_utilization -aspect_ratio 1.0 -core_space 2.0 \
  -site $::env(PLACE_SITE)
source "$platform_dir/make_tracks.tcl"
place_pins -hor_layers $::env(IO_PLACER_H) -ver_layers $::env(IO_PLACER_V)
source "$platform_dir/tapcell.tcl"
source "$platform_dir/global_connect.tcl"
global_connect
source "$platform_dir/grid_strategy-M1-M4-M7.tcl"
pdngen

# drop buffers yosys left on the netlist; the resizer re-buffers from scratch
remove_buffers

# stage snapshots are only used to draw the layout figures (scripts/dump_layout.tcl)
write_db "$pnr_dir/1_floorplan.odb"

# ---------------------------------------------------------------------------
# Placement
# ---------------------------------------------------------------------------
log_stage "global placement"
global_placement -density $place_density -timing_driven -routability_driven -pad_left 1 -pad_right 1

log_stage "repair design (post-place)"
estimate_parasitics -placement
repair_design
repair_tie_fanout -separation 5 [join $::env(TIELO_CELL_AND_PORT) /]
repair_tie_fanout -separation 5 [join $::env(TIEHI_CELL_AND_PORT) /]

set_placement_padding -global -left 1 -right 1
detailed_placement
check_placement -verbose
write_db "$pnr_dir/2_place.odb"

# ---------------------------------------------------------------------------
# Clock tree synthesis + timing repair
# ---------------------------------------------------------------------------
log_stage "clock tree synthesis"
clock_tree_synthesis -root_buf $cts_root_buf -buf_list $cts_buffers -sink_clustering_enable
set_propagated_clock [all_clocks]

estimate_parasitics -placement
repair_clock_nets
detailed_placement

log_stage "repair timing (post-CTS)"
estimate_parasitics -placement
repair_timing -setup -skip_pin_swap
repair_timing -hold -hold_margin 0.05
detailed_placement
check_placement -verbose
write_db "$pnr_dir/3_cts.odb"

# ---------------------------------------------------------------------------
# Routing
# ---------------------------------------------------------------------------
log_stage "global route"
source "$platform_dir/fastroute.tcl"
global_route -allow_congestion -congestion_report_file "$pnr_dir/congestion.rpt"

estimate_parasitics -global_routing
repair_design
repair_timing -setup -skip_pin_swap
repair_timing -hold -hold_margin 0.05
detailed_placement
check_placement -verbose
# incremental reroute of whatever the repairs above touched
global_route -start_incremental
global_route -end_incremental -allow_congestion

filler_placement $::env(FILL_CELLS)
check_placement

# parasitics are always estimated from global routing (no RCX extraction rules are installed)
set parasitics_source "global_routing"
if {$detailed_route} {
  log_stage "detailed route"
  detailed_route -output_drc "$pnr_dir/drc.rpt" -bottom_routing_layer $::env(MIN_ROUTING_LAYER) \
    -top_routing_layer $::env(MAX_ROUTING_LAYER) -verbose 1
}

# ---------------------------------------------------------------------------
# Design databases
# ---------------------------------------------------------------------------
write_db      "$pnr_dir/top.odb"
write_def     "$pnr_dir/top.def"
write_verilog "$pnr_dir/top_final.v"
write_sdc     "$pnr_dir/top.sdc"

# ---------------------------------------------------------------------------
# Post-PnR timing / power (OpenSTA)
# ---------------------------------------------------------------------------
log_stage "post-PnR STA"
estimate_parasitics -global_routing

set_power_activity -input -activity 0.1

# full reports (not diffed in CI; kept as artifacts for digging into a regression)
report_checks -path_delay max -group_count 5 -format full_clock_expanded \
  -fields {slew capacitance input_pins fanout} -digits 3 > "$pnr_dir/timing_setup.rpt"
report_checks -path_delay min -group_count 5 -format full_clock_expanded \
  -fields {slew capacitance input_pins fanout} -digits 3 > "$pnr_dir/timing_hold.rpt"
report_check_types -max_slew -max_capacitance -max_fanout -violators > "$pnr_dir/drv.rpt"
report_clock_skew -digits 3 > "$pnr_dir/clock_skew.rpt"
report_power -digits 6 > "$pnr_dir/power.rpt"
report_design_area > "$pnr_dir/design_area.rpt"

# ---------------------------------------------------------------------------
# Machine-readable dumps for scripts/parse_pnr_metrics.py
# ---------------------------------------------------------------------------
set block [ord::get_db_block]
set dbu   [$block getDefUnits]

proc rect_area_um2 {rect dbu} {
  return [expr {double([$rect dx]) * double([$rect dy]) / ($dbu * $dbu)}]
}

# one line per placed instance: name, master, LEF class, area, whether OpenROAD added it
set fh [open "$pnr_dir/cells.tsv" w]
puts $fh "instance\tmaster\tclass\tarea_um2\torigin"
foreach inst [$block getInsts] {
  set master [$inst getMaster]
  set area [expr {double([$master getWidth]) * double([$master getHeight]) / ($dbu * $dbu)}]
  puts $fh [join [list [$inst getName] [$master getName] [$master getType] \
    [format %.4f $area] [$inst getSourceType]] "\t"]
}
close $fh

set clk_period [sta::time_sta_ui [[sta::find_clock clk] period]]
set setup_wns  [worst_slack -max]
set hold_wns   [worst_slack -min]

set fh [open "$pnr_dir/summary.json" w]
puts $fh "{"
puts $fh "  \"clock_period_ns\": $clk_period,"
puts $fh "  \"setup_wns_ns\": $setup_wns,"
puts $fh "  \"setup_tns_ns\": [total_negative_slack -max],"
puts $fh "  \"hold_wns_ns\": $hold_wns,"
puts $fh "  \"hold_tns_ns\": [total_negative_slack -min],"
puts $fh "  \"setup_violating_endpoints\": [sta::endpoint_violation_count max],"
puts $fh "  \"hold_violating_endpoints\": [sta::endpoint_violation_count min],"
puts $fh "  \"die_area_um2\": [rect_area_um2 [$block getDieArea] $dbu],"
puts $fh "  \"core_area_um2\": [rect_area_um2 [$block getCoreArea] $dbu],"
puts $fh "  \"core_utilization_target_pct\": $core_utilization,"
puts $fh "  \"place_density\": $place_density,"
puts $fh "  \"parasitics\": \"$parasitics_source\""
puts $fh "}"
close $fh
