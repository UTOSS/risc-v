# Usage: vsim -do scripts/msim_run.do TB=srli_tb

if {![info exists TB]} {
  puts "ERROR: pass TB=<top_tb_module>";
  quit -code 2
}

# Fresh work library
if {[file exists work]} { vdel -all -lib work }
vlib work
vmap work work

# If a filelist exists, prefer it
set FILELIST "filelist.f"
if {[file exists $FILELIST]} {
  vlog -sv -f $FILELIST
} else {
  # Fallback: glob a few directory depths
  set patterns {src/*.sv src/*.v src/*/*.sv src/*/*.v src/*/*/*.sv src/*/*/*.v}
  set srcs {}
  foreach p $patterns {
    set m [glob -nocomplain $p]
    set srcs [concat $srcs $m]
  }
  if {[llength $srcs] > 0} {
    eval vlog -sv +incdir+include +incdir+src +incdir+test $srcs
  }
  vlog -sv +incdir+include +incdir+src +incdir+test test/${TB}.sv
}

# Batch run
vsim -c work.${TB} -do "run -all; quit"
