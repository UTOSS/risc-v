yosys -import

set utoss_riscv_config "RV32I"
if {[info exists ::env(UTOSS_RISCV_CONFIG)] && $::env(UTOSS_RISCV_CONFIG) ne ""} {
	set utoss_riscv_config $::env(UTOSS_RISCV_CONFIG)
}

set out_dir "out"
if {[info exists ::env(OUT_DIR)] && $::env(OUT_DIR) ne ""} {
	set out_dir $::env(OUT_DIR)
}

set base_dir "../../.."
if {[info exists ::env(BASE_DIR)] && $::env(BASE_DIR) ne ""} {
	set base_dir $::env(BASE_DIR)
}

set macro_args [list "-DUTOSS_RISCV_SYNTHESIS"]

if {[string first "Zbb" $utoss_riscv_config] >= 0} {
	lappend macro_args "-DUTOSS_RISCV__ENABLE_B_EXT"
}
if {[string first "Zicsr" $utoss_riscv_config] >= 0} {
	lappend macro_args "-DUTOSS_RISCV__ENABLE_ZICSR_EXT"
}
if {[string first "M" $utoss_riscv_config] >= 0} {
	lappend macro_args "-DUTOSS_RISCV__ENABLE_M_EXT"
}

file mkdir $out_dir

plugin -i slang
yosys -import

set slang_cmd [list read_slang --top top --best-effort-hierarchy --single-unit --compat vcs \
	--unroll-limit 10000]

foreach m $macro_args {
	lappend slang_cmd $m
}

lappend slang_cmd \
	"-I$base_dir" \
	"-I$base_dir/src/headers" \
	"-I$base_dir/src/interfaces" \
	"-I$base_dir/src/ext/b" \
	"-I$base_dir/src/ext/m" \
	"-I$base_dir/src/ext/zicsr"

set src_files [lsort [split [exec find "$base_dir/src" -name "*.sv"] "\n"]]
foreach f $src_files {
	if {$f ne ""} {
		lappend slang_cmd $f
	}
}

lappend slang_cmd "../memory_map.sv"
lappend slang_cmd "../top.sv"

puts "Running: $slang_cmd"
eval $slang_cmd

# Synthesize to ECP5 primitives while keeping hierarchy briefly so we can
# capture per-module LUT/FF/BRAM/DSP utilization, then flatten for nextpnr-ecp5.
# Note: synth_ecp5 runs flatten by default unless -noflatten is passed; run
# with -noflatten first to collect hierarchical stats, then flatten + write_json.
synth_ecp5 -top top -noflatten
tee -o "$out_dir/synth_stats.json" stat -json -hierarchy
tee -o "$out_dir/synth_stats.txt" stat -hierarchy

flatten
opt_clean -purge
write_json "$out_dir/top.json"
