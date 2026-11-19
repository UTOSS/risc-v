# Hardening layout figures

Each `<config>/` directory holds the figures for one `UTOSS_RISCV_CONFIG`. `make harden` draws them
(or `make harden_images` redraws them from an existing run):

1. `scripts/dump_layout.tcl` loads each stage snapshot that `scripts/harden.tcl` saved
   (`out/pnr/1_floorplan.odb`, `2_place.odb`, `3_cts.odb` and the final `top.odb`). It dumps cells,
   pins, power stripes, clock-tree connections and the routing congestion map to `out/layout/`.
2. `scripts/plot_layout.py` draws the figures from that data with matplotlib.

CI redraws the figures and fails if they differ from the checked-in ones, so commit the updated figures
together with any RTL or flow change that affects the layout. GitHub's PR view can compare old and new
versions side by side, as a swipe, or as an overlay. If your local figures ever differ from CI's, the
`hardening-images-<config>` artifact of the CI run has the ones CI drew.

The figures are byte-for-byte reproducible because matplotlib is pinned (`../requirements.txt`) and
uses its own bundled fonts.

| Figure | Stage | What it shows |
|---|---|---|
| `floorplan.png` | after floorplan | Die and core outline, power grid (metal1 rails, metal4 and metal7 stripes), tap cells and I/O pins, before any logic is placed |
| `placement.png` | after placement | Share of each 5 µm bin covered by logic cells |
| `clocktree.png` | after clock tree synthesis | Clock nets from the `clk` pin through each buffer level to the flip-flops |
| `modules.png` | final | Logic cells colored by the RTL module they came from, with cell count, area and share per module |
| `congestion.png` | final | Global-routing resource usage per routing tile |

The module groups and their colors are the `MODULES` table in `scripts/plot_layout.py`. A module
without its own entry is counted under its closest listed parent.
