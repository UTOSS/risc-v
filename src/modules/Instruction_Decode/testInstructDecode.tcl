# create default "work" directory, where compiled Verilog goes
vlib work

#compile all Verilog modules in project to working directory
vlog Instruction_Decode.v ControlFSM.v ALU_Decoder.v RegisterFile.v 

#load simulation with Instruction Decode as top level module
vsim Instruction_Decode

#log all signals and add some signals to waveform window
log {/*}

# add wave {/*} would add all items in top level simulation module
add wave {/*}

# create clock
force {clk} 0 0ns, 1 {5 ns} -r 10ns 
#10ns period clock

force {reset} 1;

run 20ns

force {reset} 0;

force {instr} 32'b11111111110001001010001100000011; #lw x6, -4(x6)

#run 70 nanoseconds
run 70ns

force {instr} 32'b00000000011001001010010000100011; #sw x6, 8(x9)

run 70ns

force {instr} 32'b00000000011000101110001000110011; #or x4, x5, x6

run 70ns

force {instr} 32'b11111110010000100000101011100011; #beq x4, x4, L7

run 70ns


