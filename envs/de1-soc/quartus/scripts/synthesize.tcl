package require ::quartus::project
package require ::quartus::flow


if {[info exists ::env(QUARTUS_PROJECT_NAME)] && $::env(QUARTUS_PROJECT_NAME) ne ""} {
	set project_name $::env(QUARTUS_PROJECT_NAME)
} else {
	error "need QUARTUS_PROJECT_NAME environment variable"
}

if {[info exists ::env(UTOSS_RISCV_CONFIG)] && $::env(UTOSS_RISCV_CONFIG) ne ""} {
	set utoss_riscv_config $::env(UTOSS_RISCV_CONFIG)
} else {
	error "need UTOSS_RISCV_CONFIG environment variable"
}

set config_upper [string toupper $utoss_riscv_config]
set macro_list {}

if {[string first "B" $config_upper] >= 0} {
	lappend macro_list UTOSS_RISCV_ENABLE_B_EXT
}

project_open $project_name

foreach macro $macro_list {
	post_message "setting $macro"
	set_global_assignment -name VERILOG_MACRO $macro
}

execute_flow -compile -dont_export_assignments
project_close -dont_export_assignments
