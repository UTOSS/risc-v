# Nangate45 platform setup (from OpenROAD-flow-scripts)

Every Nangate45-specific setting used by `scripts/harden.tcl` lives in this directory. All of it is taken from
[OpenROAD-flow-scripts (ORFS)](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts), `flow/platforms/nangate45/`,
at commit `7a57dddc8427845f75a14bd975328ee8717a1c8b`. That is the same commit `Dockerfile.ci` pins the
Nangate45 LEF files to.

| File | Upstream | How it was taken |
|---|---|---|
| `config.tcl` | `config.mk` | Translated to Tcl (only the variables we use, values unchanged, line numbers noted) |
| `setRC.tcl` | `setRC.tcl` | Verbatim: per-layer wire R/C for parasitic estimation |
| `make_tracks.tcl` | `make_tracks.tcl` | Verbatim: routing tracks per metal layer |
| `global_connect.tcl` | `global_connect.tcl` | Verbatim: connects cell VDD/VSS pins to the supply nets |
| `grid_strategy-M1-M4-M7.tcl` | `grid_strategy-M1-M4-M7.tcl` | Verbatim: power grid |
| `tapcell.tcl` | `tapcell.tcl` | Verbatim: well-tap cell insertion |
| `fastroute.tcl` | `fastroute.tcl` | Verbatim: global routing layer limits and capacity adjustments |

The verbatim files contain a short header followed by a `----8<----` marker. Everything below the marker is
byte-identical to upstream. To update them, re-download each file from the new ORFS commit, replace
the content below the marker, and bump the commit hash in the headers, in this README and in `Dockerfile.ci`.

Settings that are **not** from ORFS (CTS buffers, utilization, placement density, hold margin, and so on)
are flow choices made by this project and live in `scripts/harden.tcl` and the hardening `Makefile`.
