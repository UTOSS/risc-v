yosys -import

set utoss_riscv_config "RV32I"
if {[info exists ::env(UTOSS_RISCV_CONFIG)] && $::env(UTOSS_RISCV_CONFIG) ne ""} {
	set utoss_riscv_config $::env(UTOSS_RISCV_CONFIG)
}

set mem_size 128
if {[info exists ::env(MEM_SIZE)] && $::env(MEM_SIZE) ne ""} {
	set mem_size $::env(MEM_SIZE)
}

set boot_addr 0
if {[info exists ::env(BOOT_ADDR)] && $::env(BOOT_ADDR) ne ""} {
	set boot_addr $::env(BOOT_ADDR)
}

if {![info exists ::env(PDK_LIB)] || $::env(PDK_LIB) eq ""} {
	error "PDK_LIB environment variable is not set. Please specify PDK_LIB (e.g. export PDK_LIB=/path/to/library.lib)"
}
set pdk_lib $::env(PDK_LIB)
if {![file exists $pdk_lib]} {
	error "PDK_LIB file does not exist: $pdk_lib"
}

set out_dir "out"
if {[info exists ::env(OUT_DIR)] && $::env(OUT_DIR) ne ""} {
	set out_dir $::env(OUT_DIR)
}

set metrics_dir "metrics"
if {[info exists ::env(METRICS_DIR)] && $::env(METRICS_DIR) ne ""} {
	set metrics_dir $::env(METRICS_DIR)
}

set base_dir "../.."
if {[info exists ::env(BASE_DIR)] && $::env(BASE_DIR) ne ""} {
	set base_dir $::env(BASE_DIR)
}

set config_upper [string toupper $utoss_riscv_config]
set macro_args [list "-DUTOSS_RISCV_HARDENING" "-DUTOSS_RISCV_SYNTHESIS"]

if {[string first "B" $config_upper] >= 0} {
	lappend macro_args "-DUTOSS_RISCV_ENABLE_B_EXT"
}
if {[string first "M" $config_upper] >= 0} {
	lappend macro_args "-DUTOSS_RISCV__M_ENABLED" "-DUTOSS_RISCV__MUL_ENABLED" "-DUTOSS_RISCV__DIV_ENABLED" "-DUTOSS_RISCV__ANY_M"
}

file mkdir $out_dir
file mkdir $metrics_dir

plugin -i slang
yosys -import

set slang_cmd [list read_slang --top top --best-effort-hierarchy --single-unit --compat vcs \
    -GMEM_SIZE=$mem_size -GBOOT_ADDR=$boot_addr]

foreach m $macro_args {
    lappend slang_cmd $m
}

lappend slang_cmd "-I$base_dir" "-I$base_dir/src/headers" "-I$base_dir/src/interfaces" "-I$base_dir/src/ext/b" "-I$base_dir/src/ext/m"

# Automatically collect all .sv files in src/
# With --top top, Slang only elaborates the design hierarchy rooted at top,
# ignoring uninstantiated modules like Logger.sv.
# Header files (.svh) are resolved automatically via `include and -I include paths.
set src_files [split [exec find "$base_dir/src" -name "*.sv"] "\n"]
foreach f $src_files {
	if {$f ne ""} {
		lappend slang_cmd $f
	}
}

# Synth environment files
lappend slang_cmd "memory_map.sv"
lappend slang_cmd "top.sv"

puts "Running: $slang_cmd"
eval $slang_cmd

hierarchy -check -top top
synth -top top -noabc
dfflibmap -liberty $pdk_lib
abc -liberty $pdk_lib
clean

write_verilog -noattr "$out_dir/top_synth.v"
tee -o "$out_dir/stats.json" stat -json -liberty $pdk_lib -hierarchy
tee -o "$metrics_dir/stat_summary.txt" stat -liberty $pdk_lib -hierarchy
tee -o "$metrics_dir/cmos_transistor_stat.txt" stat -tech cmos
