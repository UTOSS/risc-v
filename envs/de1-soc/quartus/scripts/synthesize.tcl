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

set macro_list {}

if {[string first "Zbb" $utoss_riscv_config] >= 0} {
	lappend macro_list UTOSS_RISCV_ENABLE_B_EXT
}

if {[string first "Zicsr" $utoss_riscv_config] >= 0} {
	lappend macro_list UTOSS_RISCV__ZICSR_ENABLED
}

if {[string first "M" $utoss_riscv_config] >= 0} {
	lappend macro_list UTOSS_RISCV__M_ENABLED UTOSS_RISCV__MUL_ENABLED UTOSS_RISCV__DIV_ENABLED UTOSS_RISCV__ANY_M
}

# the compiler stages (quartus_map, quartus_fit, ...) run as separate processes that read the
# assignments from the .qsf on disk, so the macros must be exported to it; otherwise they are only
# set in this process and silently ignored (every config would synthesize as plain RV32I). the .qsf
# is restored afterwards so the config macros do not leak into the checked-in project file.
set qsf_file "$project_name.qsf"
set qsf_backup "$project_name.qsf.orig"
file copy -force $qsf_file $qsf_backup

project_open $project_name

foreach macro $macro_list {
	post_message "setting $macro"
	set_global_assignment -name VERILOG_MACRO $macro
}

set flow_failed [catch {execute_flow -compile} flow_result]
project_close
file copy -force $qsf_backup $qsf_file
file delete -force $qsf_backup

if {$flow_failed} {
	error $flow_result
}
