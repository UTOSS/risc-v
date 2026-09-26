# Microarchitecture Specification

The goal of this document is to provide a reference specification for the UTOSS RISC-V core
imeplementation. This document contains the architectural details of the design of the core and its
components.

## High-level

The core is implemented using a 5-stage pipelined microarchitecture, with the following stages
present:
1. Instruction Fetch
2. Instruction Decode
3. Execute
4. Memory
5. Write-back

A hazard unit is also present to coordinate interactions with the internals of the stages to ensure
correct functioning.

The main datapath involves movement of the instruction through the pipeline, and the writeback of
the data back into the decode stage as part of write-back stage since this is where the register
file resides. Memory access is performed primarily during the corresponding stage, with fetch stage
having read-only access as well.

The overall high-level structure is defined below:

![Top-Level Architecture](diagrams/top.svg)

## Base ISA

### Instruction fetch stage

### Instruction decode stage

### Execute stage

### Memory stage

### Write-back stage

## Memory

## B extension

## C extension

## Zicsr extension

Spec: [5.1. "Zicsr" Extension for Control and Status Register (CSR) Instructions, Version
2.0](https://docs.riscv.org/reference/isa/v20260120/unpriv/zicsr.html)

![Zicsr Architecture](diagrams/zicsr.svg)

Implemented across ID and WB stages. The CSR data is read via a `csr_request` data structure that
contains things like `address`, `bit`, etc [TODO: specify more clearly].

Reads are asynchronous, i.e. the `csr_data` containing the register value among other things [TODO:
specify more clearly] is available immediately and is clocked into ID/EX register.

During WB stage, `csr_request` and `csr_data` are used to produce `cst_wb_request` which carries the
`data` containing the new contents of the CSR denoted by `address` as well as whether the write is
needed via `write_enable`.

CSR decoder also produces `write_intent` to indicate to the hazard unit that sequential CSR
instructions interested in reading of writing the same CSR address.

## M extension
