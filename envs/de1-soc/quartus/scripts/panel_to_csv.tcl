load_package report
project_open utoss-risc-v
load_report

set panel_name  [lindex $argv 0]
set output_file [lindex $argv 1]

set fh [open $output_file w]
set num_rows [get_number_of_rows -name $panel_name]

for {set i 0} {$i < $num_rows} {incr i} {
  set row_data [get_report_panel_row -name $panel_name -row $i]
  puts $fh [join $row_data ","]
}

close $fh
unload_report
project_close
