# Dump the geometry of one hardening stage snapshot to plain data files, which
# scripts/plot_layout.py turns into the checked-in layout figures.
#
# Run in GUI mode (headless), because the heatmaps are only computed by the GUI:
#   QT_QPA_PLATFORM=offscreen openroad -gui -no_splash -no_settings scripts/dump_layout.tcl
#
# Inputs (environment):
#   DUMP_ODB  stage snapshot written by scripts/harden.tcl (out/pnr/<stage>.odb)
#   DUMP_DIR  output directory; gets:
#     meta.tsv       key/value: die and core box, design name
#     cells.tsv      every non-filler instance: box, master, LEF class, origin (NONE = from the
#                    netlist, TIMING = inserted by OpenROAD)
#     pins.tsv       top-level I/O pin boxes
#     power.tsv      power/ground stripe boxes per metal layer
#     clock.tsv      clock-tree edges (driver instance center -> sink instance center)
#     <name>_heatmap.csv  for each name in DUMP_HEATMAPS (`Placement`, `Routing`)
#
# All coordinates are in um.

set odb      $::env(DUMP_ODB)
set dump_dir $::env(DUMP_DIR)
set heatmaps [expr {[info exists ::env(DUMP_HEATMAPS)] ? $::env(DUMP_HEATMAPS) : ""}]

# GUI display controls that hold each heatmap's data
array set heatmap_controls {
  Placement {Heat Maps/Placement Density}
  Routing   {Heat Maps/Routing Congestion}
}

proc um {v} {
  global dbu
  return [format %.3f [expr {$v / double($dbu)}]]
}

proc box_um {box} {
  return [list [um [$box xMin]] [um [$box yMin]] [um [$box xMax]] [um [$box yMax]]]
}

proc center_um {box} {
  return [list [um [expr {([$box xMin] + [$box xMax]) / 2}]] \
               [um [expr {([$box yMin] + [$box yMax]) / 2}]]]
}

proc write_tsv {path header rows} {
  set fh [open $path w]
  puts $fh [join $header "\t"]
  foreach row [lsort -dictionary $rows] {
    puts $fh $row
  }
  close $fh
}

if {[catch {
  file mkdir $dump_dir
  read_db $odb
  set block [ord::get_db_block]
  set dbu   [$block getDefUnits]

  write_tsv "$dump_dir/meta.tsv" {key value} [list \
    "design\t[$block getName]" \
    "die\t[join [box_um [$block getDieArea]] { }]" \
    "core\t[join [box_um [$block getCoreArea]] { }]"]

  # cells
  set rows {}
  foreach inst [$block getInsts] {
    set master [$inst getMaster]
    set class  [$master getType]
    if {$class eq "CORE_SPACER"} { continue }
    lappend rows [join [concat [list [$inst getName]] [box_um [$inst getBBox]] \
      [list [$master getName] $class [$inst getSourceType]]] "\t"]
  }
  write_tsv "$dump_dir/cells.tsv" {name x0 y0 x1 y1 master class origin} $rows

  # I/O pins
  set rows {}
  foreach bterm [$block getBTerms] {
    foreach bpin [$bterm getBPins] {
      foreach box [$bpin getBoxes] {
        lappend rows [join [concat [list [$bterm getName]] [box_um $box]] "\t"]
      }
    }
  }
  write_tsv "$dump_dir/pins.tsv" {pin x0 y0 x1 y1} $rows

  # power grid stripes (special wires of the supply nets)
  set rows {}
  foreach net [$block getNets] {
    if {[$net getSigType] ni {POWER GROUND}} { continue }
    foreach swire [$net getSWires] {
      foreach wire [$swire getWires] {
        if {[$wire isVia]} { continue }
        lappend rows [join [concat [list [$net getName] [[$wire getTechLayer] getName]] \
          [box_um $wire]] "\t"]
      }
    }
  }
  write_tsv "$dump_dir/power.tsv" {net layer x0 y0 x1 y1} $rows

  # clock tree: one edge per (driver, sink) pair of every net in the clock's fan-out tree, found
  # by walking from the clock port through buffers/inverters (only those, so the walk stops at the
  # flip-flop clock pins)
  set rows {}
  set clk_port [$block findBTerm clk]
  if {$clk_port ne "NULL"} {
    set port_box [lindex [[lindex [$clk_port getBPins] 0] getBoxes] 0]
    set frontier [list [list [$clk_port getNet] [center_um $port_box] 0]]
    while {[llength $frontier]} {
      set next {}
      foreach item $frontier {
        lassign $item net from level
        foreach iterm [$net getITerms] {
          if {[$iterm isOutputSignal]} { continue }
          set inst [$iterm getInst]
          set to   [center_um [$inst getBBox]]
          set cell [[$inst getMaster] getName]
          lappend rows [join [concat $from $to [list $level $cell]] "\t"]
          if {[regexp {^(CLKBUF|BUF|INV)_} $cell]} {
            foreach out [$inst getITerms] {
              if {[$out isOutputSignal] && [$out getNet] ne "NULL"} {
                lappend next [list [$out getNet] $to [expr {$level + 1}]]
              }
            }
          }
        }
      }
      set frontier $next
    }
  }
  write_tsv "$dump_dir/clock.tsv" {x0 y0 x1 y1 level sink_master} $rows

  # heatmaps
  foreach name $heatmaps {
    set control $heatmap_controls($name)
    gui::set_display_controls $control visible true
    gui::dump_heatmap $name "$dump_dir/[string tolower $name]_heatmap.csv"
    gui::set_display_controls $control visible false
  }
} err]} {
  puts stderr "ERROR: $err"
  exit 1
}
exit 0
