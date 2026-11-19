# DE1-SoC placement figures

Each `<config>/` directory holds the placement figure for one `UTOSS_RISCV_CONFIG`, drawn from the
Quartus compile of the DE1-SoC environment (Cyclone V 5CSEMA5F31C6):

```sh
make synthesize images UTOSS_RISCV_CONFIG=RV32I
```

1. `scripts/dump_placement.tcl` uses the Chip Planner Tcl package (`quartus_cdb`) to list where the
   Fitter placed every logic cell, register and memory block (`output_files/placement.tsv`).
2. `scripts/plot_placement.py` draws the figure from that list with matplotlib.

Quartus has no command-line image export for the Chip Planner, so the figure is drawn from the
placement data instead of being a screenshot.

CI redraws the figures after every compile and fails if they differ from the checked-in ones, so
commit the updated figures together with any RTL change that affects them. If your local figures
ever differ from CI's, the `de1-soc-images-<config>` artifact of the CI run has the ones CI drew.

`placement.png` follows the Chip Planner's default view, zoomed to the region of the device the
design uses:
- Each logic tile (LAB) in use is shaded blue by how many of its 60 sites are used (10 ALMs, each
  with two LUT halves and four registers). This is the Chip Planner's "Block utilization".
- Each M10K memory block in use is filled in olive.

Limitations:
- Unused tiles are left blank. Quartus's Tcl API doesn't expose the empty device layout (which
  columns are logic, memory or DSP, or the HPS region).
- I/O pins are reported by package pin (`PIN_AF14`) rather than grid site, so they aren't drawn.
