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

Reads are asynchronous, i.e. `csr_data`, the value of the CSR denoted by `address`, is available
immediately and is clocked into ID/EX register.

During WB stage, `csr_request` and `csr_data` are used to produce `csr_wb_request` which carries the
`data` containing the new contents of the CSR denoted by `address` as well as whether the write is
needed via `write_enable`.

`csr_request` also carries `write_intent`, set by the CSR decoder, which `csr_wb` uses as
`write_enable`. It is also tapped off the pipelined `csr_request` in EX, MEM and WB and fed to the
hazard unit so that it can stall a CSR instruction that reads a CSR still being written by an
earlier instruction.

### CSR plugins

`csr_data` houses all the CSRs via the generic `csr_plugin` module.

`csr_data`'s output is simply the OR of all the plugins' `read_value`s since the readout will only
ever produce one real value, and all the other ones will be zeros. To add a CSR, instantiate a
`csr_plugin` for it in `csr_data` and OR in its `read_value`.

### Implemented CSRs

| CSR                         | Address | Access     | Reset value |
|-----------------------------|---------|------------|-------------|
| [`mscratch`][spec-mscratch] | `0x340` | read/write | `0`         |
| [`mhartid`][spec-mhartid]   | `0xF14` | read-only  | `0`         |

[spec-mscratch]: https://docs.riscv.org/reference/isa/v20260120/priv/machine.html#2-1-1-13-machine-scratch-mscratch-register
[spec-mhartid]: https://docs.riscv.org/reference/isa/v20260120/priv/machine.html#2-1-1-5-hart-id-mhartid-register

Accessing an unimplemented CSR reads a zero and writes to it are ignored, and so are writes to
read-only bits.

## M extension
