# DE1-SoC placement figures

Each `<config>/` directory holds the figures for one `UTOSS_RISCV_CONFIG`, drawn from the Quartus
compile of the DE1-SoC environment (Cyclone V 5CSEMA5F31C6):

```sh
make synthesize images UTOSS_RISCV_CONFIG=RV32I
```

1. `scripts/dump_placement.tcl` uses the Chip Planner Tcl package (`quartus_cdb`) to list where the
   Fitter placed every logic cell, register and memory block (`output_files/placement.tsv`).
2. `scripts/plot_placement.py` draws the figures from that list with matplotlib.

Quartus has no command-line image export for the Chip Planner, so these are drawn from the
placement data instead of being screenshots.

CI redraws the figures after every compile and fails if they differ from the checked-in ones, so
commit the updated figures together with any RTL change that affects them. If your local figures
ever differ from CI's, the `de1-soc-images-<config>` artifact of the CI run has the ones CI drew.

| Figure | What it shows |
|---|---|
| `placement.png` | The region of the device the design uses. Each grey square is a device tile (logic block or memory block) in use. Logic cells (squares) and registers (dots) are colored by RTL module, and M10K memory blocks are outlined. Device X/Y are tile indices, so the view is stretched to fill the plot. |
| `resources.png` | Logic cells (LUTs), registers, M10K memory blocks and I/O pins used by each RTL module. |

Module groups and colors are the `MODULES` table in `scripts/plot_placement.py`. They match the
ASIC figures in `envs/hardening/images/`, so the same module has the same color in both.

Limitations:
- Only sites the design uses are drawn. Quartus's Tcl API doesn't expose the empty device layout
  (which columns are logic, memory or DSP, or the HPS region).
- I/O pins are reported by package pin (`PIN_AF14`) rather than grid site, so they appear in
  `resources.png` but not in `placement.png`.
