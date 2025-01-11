#Created by Joonseo Park
import cocotb #cocoTB library
from cocotb.triggers import Timer
from cocotb.triggers import ClockCycles
from cocotb.triggers import RisingEdge
from cocotb.clock import Clock

#Implement function for checking each state
#check if each state that the FSM goes to corresponds to the states that we should see (as described in dictionaries)
#for state inthisdict
async def checkStates(statesList: list, dut) -> bool:
for state in statesList:
if (dut.FSMState.value != statesList[state]):
return [False, statesList[state]]
await RisingEdge(dut.clk)
return True

#Testbench function
@cocotb.test()
async def ControlFSMTB(dut):

correctStates = True

#start() is a cocoTB trigger for starting a concurrent execution
cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

#reset the DUT for 2 clock cycles
dut.reset.value = 1
await ClockCycles(dut.clk, 2, rising=True)
assert dut.FSMState.value == 0b0000, "Error: upon reset, the FSM state is not set to FETCH"

#Opcode = 7'b0110011 (R-Type)
dut.opcode.value = 0b0110011
RTypeStates = [0b0000, 0b0001, 0b0010, 0b0110, 0b0000]
correctStates = await checkStates(RTypeStates, dut)
assert correctStates[0] == True, f"Incorrect states generated for opcode = {dut.opcode.value}, (R-Type). The first incorrect state is {correctStates[1]}"

#Opcode = 7'b0010011 (I-Type)
dut.opcode.value = 0b0010011
ITypeStates = [0b0000, 0b0001, 0b0100, 0b0110, 0b0000]
correctStates = await checkStates(ITypeStates, dut)
assert correctStates[0] == True, f"Incorrect states generated for opcode = {dut.opcode.value}, (I-Type). The first incorrect state is {correctStates[1]}"

#Opcode = 7'b0000011 (lw)
dut.opcode.value = 0b0000011
LWTypeStates = [0b0000, 0b0001, 0b0101, 0b1000, 0b1001, 0b0000]
correctStates = await checkStates(LWTypeStates, dut)
assert correctStates[0] == True, f"Incorrect states generated for opcode = {dut.opcode.value}, (lw). The first incorrect state is {correctStates[1]}"

#Opcode = 7'b0100011 (sw)
dut.opcode.value = 0b0100011
SWTypeStates = [0b0000, 0b0001, 0b0101, 0b0111]
correctStates = await checkStates(LWTypeStates, dut)
assert correctStates[0] == True, f"Incorrect states generated for opcode = {dut.opcode.value}, (sw). The first incorrect state is {correctStates[1]}"

#Opcode = 7'b1101111 (J-Type)
dut.opcode.value = 0b1101111
JTypeStates = [0b0000, 0b0001, 0b0011, 0b0110, 0b0000]
correctStates = await checkStates(LWTypeStates, dut)
assert correctStates[0] == True, f"Incorrect states generated for opcode = {dut.opcode.value}, (J-Type). The first incorrect state is {correctStates[1]}"
