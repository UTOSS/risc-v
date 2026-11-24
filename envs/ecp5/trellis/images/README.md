# ECP5 placement figures

Each `<config>/` directory holds the placement figure for one `UTOSS_RISCV_CONFIG`, drawn from the
open-source ECP5 flow (`yosys` + `slang` + `nextpnr-ecp5` + `ecppack`) targeting the Lattice
`LFE5U-25F-7BG256I` (`CABGA256`, speed grade `7`):

```sh
make synthesize images UTOSS_RISCV_CONFIG=RV32I
```

1. `nextpnr-ecp5 --write out/top_placed.json --report out/pnr_report.json` exports the placed
   netlist (including exact `X/Y/BEL` coordinates for every primitive) and utilization/Fmax report.
2. `scripts/plot_placement.py` draws the figure from those files with matplotlib (deterministic,
   compressed with `optipng`).

CI redraws the figures on every PR and the `update-generated-images` job automatically commits any
updated figures back to internal PR branches (they are also uploaded as `ecp5-images-<config>`
artifacts). You can also run `make test_images UTOSS_RISCV_CONFIG=<config>` locally to check for
drift.

`placement.png` mirrors the DE1-SoC placement view, zoomed to the region of the device the design
uses:
- Each logic tile (PLC) in use is shaded blue by how many of its 16 sites are used (4 slices, each
  with two LUT4s and two flip-flops).
- Each `DP16KD` 18 Kb EBR memory block in use is filled in olive.
- Any `MULT18X18D`/`ALU54B` DSP blocks in use are filled in amber.
- Any `TRELLIS_IO` pin tiles within the zoomed view are filled in coral.
