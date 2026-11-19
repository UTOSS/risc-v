# Dump where the Fitter placed every element of the compiled design, for scripts/plot_placement.py.
#
#   quartus_cdb -t scripts/dump_placement.tcl <project> <out.tsv>
#
# Uses the Chip Planner Tcl package (available in Quartus Prime Lite). One row per placed element:
#   type       lcell | io | ram | dsp | pll   (get_nodes -type)
#   location   site on the device grid, e.g. LABCELL_X71_Y9_N2, FF_X71_Y9_N3, M10K_X69_Y6_N0;
#              I/O pins report their package pin instead (PIN_AF14)
#   element    the routing element at that site (for I/O: the I/O buffer's grid site)
#   name       full hierarchical node name, e.g. |top|utoss_riscv:core|...|ALU:alu|Add0~1
# Rows are sorted so that the file (and the figures drawn from it) only change when placement does.

package require ::quartus::project
package require ::quartus::chip_planner

lassign $argv project out_file

project_open $project
read_netlist

set rows {}
foreach type {lcell io ram dsp pll} {
  foreach_in_collection node [get_nodes -type $type] {
    lappend rows [join [list $type \
      [get_node_info -node $node -info {Location String}] \
      [get_node_info -node $node -info {Routing Element Name}] \
      [get_node_info -node $node -info {Full Node Name}]] "\t"]
  }
}

project_close

file mkdir [file dirname $out_file]
set fh [open $out_file w]
puts $fh [join {type location element name} "\t"]
foreach row [lsort $rows] {
  puts $fh $row
}
close $fh
puts "wrote [llength $rows] placed elements to $out_file"
