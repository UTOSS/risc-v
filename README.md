# risc-v

UTOSS' 5-stage pipelined RISC-V core with synchronous memory support.

## Architecture

![Core Architecture](docs/diagrams/utoss_riscv_pipelined.png)

## Getting Started

Checkout Setting up Developement Environment wiki page if you wuld like to develop locally. You can
also create a
[Codespace](https://docs.github.com/en/codespaces/about-codespaces/what-are-codespaces) which will
use our [devcontainer image](.devcontainer/Dockerfile) with all the necessary tools preinstalled.

## Project structure

```mermaid
flowchart BT
  subgraph src_blk["<code>src/</code> — core RTL"]
    direction LR
    s_top["<code>utoss_riscv.sv</code><br/>top module"]:::src
    s_stages["<code>stages/</code> & <code>modules/</code><br/>"]:::src
    s_ext["<code>ext/</code>"]:::src
    s_hdr["<code>headers/</code><br/><code>interfaces/</code><br/><code>packages/</code><br/><code>utils/</code>"]:::src
  end

  subgraph test_blk["<code>test/</code> verification & test suites"]
    direction LR
    t_sv["<code>sv/</code><br/>SV Unit Testbenches"]:::test
    t_pyuvm["<code>PyUVM/</code><br/>PyUVM & cocotb"]:::test
    t_riscof["<code>riscof/</code><br/>ISA Compliance"]:::test
    t_dv["<code>utoss_riscv_dv/</code><br/>Random Instruction DV"]:::test
    t_mcy["<code>mcy/</code><br/>Mutation Coverage"]:::test
  end

  subgraph envs_blk["<code>envs/</code> execution environments"]
    direction LR
    e_sim["<code>simulation/</code><br/>Simulation Top & Memory"]:::env
    e_de1["<code>de1-soc/</code><br/>DE1-SoC FPGA & Quartus"]:::env
    e_harden["<code>hardening/</code><br/>Nangate45 Synth & OpenROAD PnR"]:::env
  end

  subgraph bench_blk["<code>benchmarks/</code> — performance benchmarks"]
    direction LR
    b_coremark["<code>coremark/</code><br/>EEMBC CoreMark"]:::bench
    b_embench["<code>embench/</code><br/>Embench-IoT Suite"]:::bench
  end

  subgraph checks_blk["<code>checks/</code> — static checks & linting"]
    direction LR
    c_svlint["<code>svlint.toml</code><br/>SVLint style & design rules"]:::check
    c_ts["<code>check_timescale.py</code><br/>Timescale Header Check"]:::check
  end

  infra_blk["<code>infra/</code> — CI & Toolchain Dockerfiles"]:::infra

  test_blk -->|tests| src_blk
  envs_blk -->|depends on| src_blk
  bench_blk -->|depends on| src_blk
  checks_blk -->|checks| src_blk
  infra_blk ~~~ src_blk

  classDef src fill:transparent,stroke:#f97316,stroke-width:2px
  classDef test fill:transparent,stroke:#6366f1,stroke-width:2px
  classDef env fill:transparent,stroke:#0ea5e9,stroke-width:2px
  classDef bench fill:transparent,stroke:#10b981,stroke-width:2px
  classDef check fill:transparent,stroke:#f43f5e,stroke-width:2px
  classDef infra fill:transparent,stroke:#14b8a6,stroke-width:2px

  style src_blk fill:transparent,stroke:#f97316,stroke-width:2px
  style test_blk fill:transparent,stroke:#6366f1,stroke-width:2px
  style envs_blk fill:transparent,stroke:#0ea5e9,stroke-width:2px
  style bench_blk fill:transparent,stroke:#10b981,stroke-width:2px
  style checks_blk fill:transparent,stroke:#f43f5e,stroke-width:2px
```

## Development

Put new modules into `src/` folder.

### Formatting

We use SVLint to make sure our SystemVerilog code is well formatted. Use the following command to
check for new offences:
```
$ make svlint
```

### Testbenches

It is important that new functionality is tested to a reasonable extent by using test benches. To
run all existing testbenches use `make run_tb`

To create a new test bench, if you are on Linux use the following command:
```
$ make new_tb name="something"
```

If you are on Windows, create a new testbench file in `test/sv/` folder named `something_tb.sv` (the
`_tb.sv` suffix and extension are necessary for the test suite to recognize this file as a
testbench). Copy the content of `test/sv/tb_template.sv.m4` into your newly-created testbench file and
start writing the test bench.
