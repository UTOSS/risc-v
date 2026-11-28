#!/usr/bin/env python3
"""Unit tests for scripts/metrics/metrics_diff.py and post_comment.js."""
import os
import shutil
import subprocess
import tempfile
import unittest

import metrics_diff as md


FIT_SUMMARY_BASE = """\
Fitter Status : Successful - Sat Nov 21 16:22:02 2026
Quartus Prime Version : 25.1std.0 Build 1129 10/21/2025 SC Lite Edition
Revision Name : utoss-risc-v
Top-level Entity Name : top
Family : Cyclone V
Device : 5CSEMA5F31C6
Timing Models : Final
Logic utilization (in ALMs) : 2,160 / 32,070 ( 7 % )
Total registers : 1575
Total pins : 15 / 457 ( 3 % )
Total virtual pins : 0
Total block memory bits : 32,768 / 4,065,280 ( < 1 % )
Total RAM Blocks : 8 / 397 ( 2 % )
Total DSP Blocks : 0 / 87 ( 0 % )
"""

FIT_SUMMARY_PR = """\
Fitter Status : Successful - Sat Nov 28 05:00:00 2026
Quartus Prime Version : 25.1std.0 Build 1129 10/21/2025 SC Lite Edition
Revision Name : utoss-risc-v
Top-level Entity Name : top
Family : Cyclone V
Device : 5CSEMA5F31C6
Timing Models : Final
Logic utilization (in ALMs) : 2,100 / 32,070 ( 7 % )
Total registers : 1600
Total pins : 15 / 457 ( 3 % )
Total virtual pins : 0
Total block memory bits : 32,768 / 4,065,280 ( < 1 % )
Total RAM Blocks : 8 / 397 ( 2 % )
Total DSP Blocks : 2 / 87 ( 2 % )
"""

STA_SUMMARY_BASE = """\
------------------------------------------------------------
Timing Analyzer Summary
------------------------------------------------------------

Type  : Slow 1100mV 85C Model Setup 'CLOCK_50'
Slack : 2.010
TNS   : 0.000

Type  : Slow 1100mV 85C Model Hold 'CLOCK_50'
Slack : 0.376
TNS   : 0.000

Type  : Fast 1100mV 0C Model Setup 'CLOCK_50'
Slack : 10.064
TNS   : -1.000

------------------------------------------------------------
"""

STA_SUMMARY_PR = """\
------------------------------------------------------------
Timing Analyzer Summary
------------------------------------------------------------

Type  : Slow 1100mV 85C Model Setup 'CLOCK_50'
Slack : 2.510
TNS   : 0.000

Type  : Slow 1100mV 85C Model Hold 'CLOCK_50'
Slack : 0.376
TNS   : 0.000

Type  : Fast 1100mV 0C Model Setup 'CLOCK_50'
Slack : 9.064
TNS   : -0.500

------------------------------------------------------------
"""

FITTER_CSV_BASE = """\
Compilation Hierarchy Node,ALMs needed [=A-B+C],[A] ALMs used in final placement,[B] Estimate of ALMs recoverable by dense packing,[C] Estimate of ALMs unavailable,ALMs used for memory,Combinational ALUTs,Dedicated Logic Registers,I/O Registers,Block Memory Bits,M10Ks,DSP Blocks,Pins,Virtual Pins,Full Hierarchy Name,Entity Name,Library Name
|top,1525.5 (0.5),1660.0 (0.5),159.5 (0.0),25.0 (0.0),0.0 (0.0),1779 (1),1568 (0),0 (0),32768,8,0,15,0,|top,top,work
   |utoss_riscv:core|,1514.6 (596.0),1645.7 (610.8),155.9 (23.1),24.9 (8.3),0.0 (0.0),1765 (684),1555 (465),0 (0),0,0,0,0,0,|top|utoss_riscv:core,utoss_riscv,work
      |ALU:alu|,343.9 (343.9),345.8 (345.8),14.7 (14.7),12.7 (12.7),0.0 (0.0),478 (478),0 (0),0 (0),0,0,0,0,0,|top|utoss_riscv:core|ALU:alu,ALU,work
"""

FITTER_CSV_PR = """\
Compilation Hierarchy Node,ALMs needed [=A-B+C],[A] ALMs used in final placement,[B] Estimate of ALMs recoverable by dense packing,[C] Estimate of ALMs unavailable,ALMs used for memory,Combinational ALUTs,Dedicated Logic Registers,I/O Registers,Block Memory Bits,M10Ks,DSP Blocks,Pins,Virtual Pins,Full Hierarchy Name,Entity Name,Library Name
|top,1500.0 (0.5),1640.0 (0.5),165.0 (0.0),25.0 (0.0),0.0 (0.0),1750 (1),1568 (0),0 (0),32768,8,0,15,0,|top,top,work
   |utoss_riscv:core|,1514.6 (596.0),1645.7 (610.8),155.9 (23.1),24.9 (8.3),0.0 (0.0),1765 (684),1555 (465),0 (0),0,0,0,0,0,|top|utoss_riscv:core,utoss_riscv,work
      |ALU:alu|,343.9 (343.9),345.8 (345.8),14.7 (14.7),12.7 (12.7),0.0 (0.0),478 (478),0 (0),0 (0),0,0,0,0,0,|top|utoss_riscv:core|ALU:alu,ALU,work
"""

SYNTH_UTIL_BASE = """\
Hierarchy Node,Total Cells,Total Area (um^2),Combinational Cells,Combinational Area (um^2),Sequential Cells,Sequential Area (um^2)
top,30931,58389.93,25077,31918.14,5854,26471.79
ALU$top.core.u_execute_stage.alu,1040,1171.46,1040,1171.46,0,0.00
"""

SYNTH_UTIL_PR = """\
Hierarchy Node,Total Cells,Total Area (um^2),Combinational Cells,Combinational Area (um^2),Sequential Cells,Sequential Area (um^2)
top,30831,58189.93,24977,31718.14,5854,26471.79
ALU$top.core.u_execute_stage.alu,1040,1171.46,1040,1171.46,0,0.00
"""

PNR_GATES_BASE = """\
====================================================================
            OPENROAD POST-PNR GATE BREAKDOWN (Nangate45)
====================================================================
Cell Type        |      Count |  Total Area (um^2) |   % Area
--------------------------------------------------------------------
DFF_X1           |       5334 |           24120.35 |   32.74%
BUF_X16          |        295 |            1961.75 |    2.66%
OLD_ONLY_X1      |         10 |              20.00 |    0.03%
--------------------------------------------------------------------
TOTAL (logic)    |       5639 |           26102.10 |  100.00%
====================================================================

Inserted by OpenROAD         |      Count |        Area (um^2)
--------------------------------------------------------------------
CTS buffers                  |       1683 |            1818.64
hold buffers                 |          0 |               0.00
filler cells                 |      50254 |           42351.19
====================================================================
"""

PNR_GATES_PR = """\
====================================================================
            OPENROAD POST-PNR GATE BREAKDOWN (Nangate45)
====================================================================
Cell Type        |      Count |  Total Area (um^2) |   % Area
--------------------------------------------------------------------
DFF_X1           |       5334 |           24120.35 |   32.80%
BUF_X16          |        250 |            1662.50 |    2.26%
NEW_ONLY_X1      |          5 |              15.00 |    0.02%
--------------------------------------------------------------------
TOTAL (logic)    |       5589 |           25797.85 |  100.00%
====================================================================

Inserted by OpenROAD         |      Count |        Area (um^2)
--------------------------------------------------------------------
CTS buffers                  |       1600 |            1720.00
hold buffers                 |          0 |               0.00
filler cells                 |      50400 |           42500.00
====================================================================
"""

PNR_TIMING_BASE = """\
====================================================================
          OPENROAD/OPENSTA POST-PNR TIMING SUMMARY (Nangate45)
====================================================================
Parasitics                       : global_routing

-- Timing ----------------------------------------------------------
Clock period (clk)               :    10.000 ns
Setup WNS                        :     5.670 ns
Setup TNS                        :     0.000 ns
Setup violating endpoints        :         0
Hold WNS                         :     0.093 ns
Hold TNS                         :     0.000 ns
Hold violating endpoints         :         0
Min. period (period - setup WNS) :     4.330 ns
Est. Fmax                        :    230.93 MHz
Clock skew (setup)               :    -0.050 ns

-- Design rule violations ------------------------------------------
Max slew violations              :         0
Max capacitance violations       :         0
Max fanout violations            :         0

-- Area ------------------------------------------------------------
Die area                         :    119529.23 um^2
Core area                        :    116219.12 um^2
Std cell area (logic + taps)     :     73867.93 um^2
Core utilization                 :       63.56 %
  (floorplan target 50%, placement density 0.65)

-- Power (typical corner, 10% input activity) ----------------------
Internal                         :       5.6280 mW
Switching                        :       1.9039 mW
Leakage                          :       1.6495 mW
Total                            :       9.1814 mW
====================================================================
"""

PNR_TIMING_PR = """\
====================================================================
          OPENROAD/OPENSTA POST-PNR TIMING SUMMARY (Nangate45)
====================================================================
Parasitics                       : global_routing

-- Timing ----------------------------------------------------------
Clock period (clk)               :    10.000 ns
Setup WNS                        :     6.000 ns
Setup TNS                        :     0.000 ns
Setup violating endpoints        :         0
Hold WNS                         :     0.093 ns
Hold TNS                         :     0.000 ns
Hold violating endpoints         :         0
Min. period (period - setup WNS) :     4.000 ns
Est. Fmax                        :    250.00 MHz
Clock skew (setup)               :    -0.020 ns

-- Design rule violations ------------------------------------------
Max slew violations              :         0
Max capacitance violations       :         0
Max fanout violations            :         0

-- Area ------------------------------------------------------------
Die area                         :    119529.23 um^2
Core area                        :    116219.12 um^2
Std cell area (logic + taps)     :     74000.00 um^2
Core utilization                 :       63.67 %
  (floorplan target 50%, placement density 0.65)

-- Power (typical corner, 10% input activity) ----------------------
Internal                         :       5.5000 mW
Switching                        :       1.9039 mW
Leakage                          :       1.6495 mW
Total                            :       9.0534 mW
====================================================================
"""


class TestMetricsDiff(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="test-metrics-diff-")

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _write(self, relpath, content):
        path = os.path.join(self.tmp, relpath)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        return path

    def test_fit_summary_skips_timestamp_and_formats_changes(self):
        b = self._write("base.fit.summary", FIT_SUMMARY_BASE)
        p = self._write("pr.fit.summary", FIT_SUMMARY_PR)
        out = md.diff_fit_summary(b, p)

        # Metadata timestamp changed, should NOT appear in the diff table
        self.assertNotIn("| Fitter Status |", out)
        # ALMs improved (lower is better -> green)
        self.assertIn("| Logic utilization (in ALMs) | 🟢 2,160 → 2,100 (-60 / -2.78%) |", out)
        # Registers regressed (higher -> red)
        self.assertIn("| Total registers | 🔴 1,575 → 1,600 (+25 / +1.59%) |", out)
        # DSPs went from 0 -> 2 (N/A percentage)
        self.assertIn("| Total DSP Blocks | 🔴 0 → 2 (+2 / N/A) |", out)
        # Unchanged metrics omitted from table
        self.assertNotIn("| Total pins |", out)
        self.assertNotIn("| Total RAM Blocks |", out)
        # Full text report included inside collapsible details
        self.assertIn("<summary>Full report: Fitter Summary</summary>", out)
        self.assertIn("Fitter Status : Successful - Sat Nov 28", out)

    def test_fit_summary_unchanged_reports_no_changes(self):
        b = self._write("base.fit.summary", FIT_SUMMARY_BASE)
        p = self._write("pr.fit.summary", FIT_SUMMARY_BASE)
        out = md.diff_fit_summary(b, p)
        self.assertIn("*No changes detected*", out)
        self.assertIn("<details>", out)

    def test_sta_summary_direction_and_negative_tns(self):
        b = self._write("base.sta.summary", STA_SUMMARY_BASE)
        p = self._write("pr.sta.summary", STA_SUMMARY_PR)
        out = md.diff_sta_summary(b, p)

        table_part, details_part = out.split("<!-- FULL_REPORT_START -->", 1)
        # Setup slack increased -> green; TNS unchanged -> blank cell
        self.assertIn(
            "| Slow 1100mV 85C Model Setup 'CLOCK_50' | 🟢 2.010 → 2.510 (+0.500 / +24.88%) |  |",
            table_part,
        )
        # Hold row completely unchanged -> omitted from table, still present in full report
        self.assertNotIn("Slow 1100mV 85C Model Hold", table_part)
        self.assertIn("Slow 1100mV 85C Model Hold", details_part)
        # Fast Setup: slack dropped -> red; TNS went -1.000 -> -0.500 -> green (+0.500 / +50.00%)
        self.assertIn(
            "| Fast 1100mV 0C Model Setup 'CLOCK_50' | 🔴 10.064 → 9.064 (-1.000 / -9.94%) | 🟢 -1.000 → -0.500 (+0.500 / +50.00%) |",
            table_part,
        )

    def test_fitter_utilization_all_numeric_columns_and_blank_unchanged_cells(self):
        b = self._write("base.csv", FITTER_CSV_BASE)
        p = self._write("pr.csv", FITTER_CSV_PR)
        pretty = self._write("pr.pretty.txt", "PRETTY CONTENT\n")
        out = md.diff_fitter_by_entity(b, p, pretty)

        # All 13 numeric columns present in header
        for col in (
            "ALMs Needed",
            "[A] ALMs Used",
            "[B] ALMs Recoverable",
            "[C] ALMs Unavailable",
            "ALMs (Mem)",
            "Comb ALUTs",
            "Registers",
            "I/O Regs",
            "Block Mem Bits",
            "M10Ks",
            "DSPs",
            "Pins",
            "Virtual Pins",
        ):
            self.assertIn(col, out)

        # Unchanged child rows omitted
        self.assertNotIn("utoss_riscv:core", out)
        # [B] Recoverable ALMs increased -> green (higher is better!)
        self.assertIn("🟢 159.5 → 165.0 (+5.5 / +3.45%)", out)
        # ALMs needed decreased -> green
        self.assertIn("🟢 1,525.5 → 1,500.0 (-25.5 / -1.67%)", out)
        # Pretty text embedded in collapsible block
        self.assertIn("PRETTY CONTENT", out)

    def test_utilization_csv_escapes_dollar_with_backticks(self):
        b = self._write("base.csv", SYNTH_UTIL_BASE)
        p = self._write("pr.csv", SYNTH_UTIL_PR)
        out = md.diff_utilization_csv(
            b, p, None, title="Hardening Utilization", key_header="Hierarchy / Module"
        )
        table_part, details_part = out.split("<!-- FULL_REPORT_START -->", 1)
        self.assertIn("| `top` | 🟢 30,931 → 30,831 (-100 / -0.32%) |", table_part)
        # Seq cells & Seq area unchanged -> blank cells at end of row
        self.assertIn("|  |  |", table_part)
        # Unchanged ALU row omitted from table, still present in full report
        self.assertNotIn("ALU$top", table_part)
        self.assertIn("ALU$top", details_part)

    def test_pnr_gate_breakdown_both_tables_added_removed_and_filler_neutral(self):
        b = self._write("base_gates.txt", PNR_GATES_BASE)
        p = self._write("pr_gates.txt", PNR_GATES_PR)
        out = md.diff_gate_breakdown(b, p, title="Post-PnR Gate Breakdown")

        # DFF_X1 count/area unchanged, only % Area changed (neutral)
        self.assertIn("| `DFF_X1` |  |  | ⚪ 32.74 → 32.80 (+0.06 / +0.18%) |", out)
        # Added cell marked with orange circle
        self.assertIn("| 🟠 `NEW_ONLY_X1` *(new)* | 🔴 0 → 5 (+5 / new) |", out)
        # Removed cell struck through across label and cells
        self.assertIn(
            "| ~~`OLD_ONLY_X1`~~ | ~~🟢 10 → 0 (-10 / -100.00%)~~ | ~~🟢 20.00 → 0.00 (-20.00 / -100.00%)~~ | ~~⚪ 0.03 → 0.00 (-0.03 / -100.00%)~~ |",
            out,
        )
        # TOTAL pinned at bottom of first table
        self.assertIn("| **TOTAL (logic)** | 🟢 5,639 → 5,589 (-50 / -0.89%) |", out)
        # Inserted by OpenROAD second table: CTS buffers green, filler cells neutral, hold omitted
        self.assertIn("| CTS buffers | 🟢 1,683 → 1,600 (-83 / -4.93%) |", out)
        self.assertIn("| filler cells | ⚪ 50,254 → 50,400 (+146 / +0.29%) |", out)
        self.assertNotIn("| hold buffers |", out)

    def test_pnr_timing_directions_and_clock_skew_abs(self):
        b = self._write("base_timing.txt", PNR_TIMING_BASE)
        p = self._write("pr_timing.txt", PNR_TIMING_PR)
        out = md.diff_pnr_timing(b, p)

        table_part, details_part = out.split("<!-- FULL_REPORT_START -->", 1)
        self.assertIn("| Timing | Setup WNS (ns) | 🟢 5.670 → 6.000 (+0.330 / +5.82%) |", table_part)
        self.assertIn("| Timing | Min. period (period - setup WNS) (ns) | 🟢 4.330 → 4.000 (-0.330 / -7.62%) |", table_part)
        self.assertIn("| Timing | Est. Fmax (MHz) | 🟢 230.93 → 250.00 (+19.07 / +8.26%) |", table_part)
        # Clock skew went -0.050 -> -0.020 (closer to 0 -> improved!)
        self.assertIn("| Timing | Clock skew (setup) (ns) | 🟢 -0.050 → -0.020 (+0.030 / +60.00%) |", table_part)
        # Std cell area increased -> red; Core utilization -> neutral
        self.assertIn("| Area | Std cell area (logic + taps) (um^2) | 🔴 73,867.93 → 74,000.00 (+132.07 / +0.18%) |", table_part)
        self.assertIn("| Area | Core utilization (%) | ⚪ 63.56 → 63.67 (+0.11 / +0.17%) |", table_part)
        # Power decreased -> green
        self.assertIn("| Power | Total (mW) | 🟢 9.1814 → 9.0534 (-0.1280 / -1.39%) |", table_part)
        # Unchanged items omitted from table, still in full report
        self.assertNotIn("Clock period (clk)", table_part)
        self.assertNotIn("Die area", table_part)
        self.assertIn("Clock period (clk)", details_part)

    def test_missing_baseline_shows_message_and_full_report(self):
        p = self._write("pr.fit.summary", FIT_SUMMARY_PR)
        out = md.diff_fit_summary(None, p)
        self.assertIn("*No baseline available*", out)
        self.assertIn("<summary>Full report: Fitter Summary</summary>", out)

    def test_cli_end_to_end_and_aggregate(self):
        base_de1 = os.path.join(self.tmp, "base_de1")
        pr_de1 = os.path.join(self.tmp, "pr_de1")
        self._write("base_de1/output_files/utoss-risc-v.fit.summary", FIT_SUMMARY_BASE)
        self._write("pr_de1/output_files/utoss-risc-v.fit.summary", FIT_SUMMARY_PR)
        self._write("base_de1/output_files/utoss-risc-v.sta.summary", STA_SUMMARY_BASE)
        self._write("pr_de1/output_files/utoss-risc-v.sta.summary", STA_SUMMARY_PR)
        self._write("base_de1/metrics/fitter_utilization.csv", FITTER_CSV_BASE)
        self._write("pr_de1/metrics/fitter_utilization.csv", FITTER_CSV_PR)

        artifacts = os.path.join(self.tmp, "artifacts")
        out_de1 = os.path.join(artifacts, "de1-soc-synthesis-metrics-diff-RV32I")
        md.main(["de1-soc", "--base-dir", base_de1, "--pr-dir", pr_de1, "--out-dir", out_de1])

        combined = os.path.join(self.tmp, "comparison.md")
        md.main(["aggregate", "--artifacts-dir", artifacts, "--output", combined])

        with open(combined, "r", encoding="utf-8") as f:
            text = f.read()
        self.assertIn("## 📊 Synthesis, Hardening & Benchmark Report Summary Diff", text)
        self.assertIn("### `RV32I`", text)
        self.assertIn("#### DE1-SoC Synthesis", text)
        self.assertIn("🟢 2,160 → 2,100 (-60 / -2.78%)", text)

    def test_benchmarks_coremark_embench_and_aggregate(self):
        coremark_base = """\
ISA Config             : RV32I/rv32i
Iterations             : 1
Timed Cycles           : 100000
Instructions Retired   : 80000
CPI (Cycles / Instret) : 1.2500
IPC (Instret / Cycle)  : 0.8000
CoreMark / MHz         : 10.0000
Stall Cycles (timed)   : 10000 (10.00%)
Flush Cycles (timed)   : 5000 (5.00%)
Total Sim Cycles       : 105000
Total Sim Instret      : 82000
"""
        coremark_pr = """\
ISA Config             : RV32I/rv32i
Iterations             : 1
Timed Cycles           : 95000
Instructions Retired   : 80000
CPI (Cycles / Instret) : 1.1875
IPC (Instret / Cycle)  : 0.8421
CoreMark / MHz         : 10.5263
Stall Cycles (timed)   : 8000 (8.42%)
Flush Cycles (timed)   : 5000 (5.26%)
Total Sim Cycles       : 100000
Total Sim Instret      : 82000
"""
        embench_base = """\
ISA Config: RV32I/rv32i
Benchmark        Status   Text(B)       Cycles      Instret      CPI     IPC  Stall%  Flush%
--------------------------------------------------------------------------------------------
aha-mont64       PASS        1200       500000       400000   1.2500  0.8000  10.00%   5.00%
crc32            PASS         800       200000       160000   1.2500  0.8000  10.00%   5.00%
old-bench        PASS         500       100000        80000   1.2500  0.8000  10.00%   5.00%
--------------------------------------------------------------------------------------------
TOTAL/AGG        3/3                    800000       640000   1.2500  0.8000  10.00%   5.00%
GEOMEAN                                                       1.2500  0.8000
"""
        embench_pr = """\
ISA Config: RV32I/rv32i
Benchmark        Status   Text(B)       Cycles      Instret      CPI     IPC  Stall%  Flush%
--------------------------------------------------------------------------------------------
aha-mont64       PASS        1200       480000       400000   1.2000  0.8333   8.00%   5.00%
crc32            PASS         800       200000       160000   1.2500  0.8000  10.00%   5.00%
new-bench        PASS         600       120000       100000   1.2000  0.8333   7.00%   4.00%
--------------------------------------------------------------------------------------------
TOTAL/AGG        3/3                    800000       660000   1.2121  0.8250   8.33%   4.80%
GEOMEAN                                                       1.2164  0.8221
"""
        base_b = os.path.join(self.tmp, "base_bench")
        pr_b = os.path.join(self.tmp, "pr_bench")
        self._write("base_bench/coremark_metrics.txt", coremark_base)
        self._write("pr_bench/coremark_metrics.txt", coremark_pr)
        self._write("base_bench/embench_metrics.txt", embench_base)
        self._write("pr_bench/embench_metrics.txt", embench_pr)

        artifacts = os.path.join(self.tmp, "bench_artifacts")
        out_b = os.path.join(artifacts, "benchmarks-metrics-diff-RV32I")
        md.main(["benchmarks", "--base-dir", base_b, "--pr-dir", pr_b, "--out-dir", out_b])

        with open(os.path.join(out_b, "coremark.md"), "r", encoding="utf-8") as f:
            cm_out = f.read()
        cm_table = cm_out.split("<!-- FULL_REPORT_START -->", 1)[0]
        self.assertIn("| Timed Cycles | 🟢 100,000 → 95,000 (-5,000 / -5.00%) |", cm_table)
        self.assertIn("| CPI (Cycles / Instret) | 🟢 1.2500 → 1.1875 (-0.0625 / -5.00%) |", cm_table)
        self.assertIn("| IPC (Instret / Cycle) | 🟢 0.8000 → 0.8421 (+0.0421 / +5.26%) |", cm_table)
        self.assertIn("| CoreMark / MHz | 🟢 10.0000 → 10.5263 (+0.5263 / +5.26%) |", cm_table)
        self.assertNotIn("Iterations", cm_table)

        with open(os.path.join(out_b, "embench.md"), "r", encoding="utf-8") as f:
            em_out = f.read()
        em_table = em_out.split("<!-- FULL_REPORT_START -->", 1)[0]
        self.assertIn("| `aha-mont64` |  |  | 🟢 500,000 → 480,000 (-20,000 / -4.00%) |", em_table)
        self.assertNotIn("crc32", em_table)
        self.assertIn("| 🟠 `new-bench` *(new)* |", em_table)
        self.assertIn("| ~~`old-bench`~~ |", em_table)
        self.assertIn("| **TOTAL/AGG** |", em_table)
        self.assertIn("| **GEOMEAN** |", em_table)

        combined = os.path.join(self.tmp, "bench_comparison.md")
        md.main(["aggregate", "--artifacts-dir", artifacts, "--output", combined])
        with open(combined, "r", encoding="utf-8") as f:
            agg_text = f.read()
        self.assertIn("#### Benchmarks (CPI / Cycles)", agg_text)
        self.assertIn("##### CoreMark", agg_text)
        self.assertIn("##### Embench-IoT", agg_text)

    def test_post_comment_js_strips_full_reports_and_links_artifact(self):
        if shutil.which("node") is None:
            self.skipTest("node not installed")
        js_path = os.path.abspath(
            os.path.join(
                os.path.dirname(__file__),
                "../../.github/scripts/metrics-diff/post_comment.js",
            )
        )
        script = f"""
        const {{ formatPrComment }} = require({js_path!r});
        const big = '<!-- FULL_REPORT_START -->\\n<details>\\n<summary>Full report: Big</summary>\\n' + 'x'.repeat(70000) + '\\n</details>\\n<!-- FULL_REPORT_END -->';
        const small = '<!-- FULL_REPORT_START -->\\n<details>\\n<summary>Full report: Small</summary>\\nhello\\n</details>\\n<!-- FULL_REPORT_END -->';
        const input = '## Header\\n| A | B |\\n| --- | --- |\\n| 1 | 2 |\\n' + big + '\\n' + small;
        const out = formatPrComment(input, {{
          artifactUrl: 'https://example.com/run/1/artifacts/42',
          summaryUrl: 'https://example.com/run/1',
        }});
        if (out.length > 65000) process.exit(1);
        if (!out.includes('| 1 | 2 |')) process.exit(2);
        if (out.includes('Full report: Big') || out.includes('Full report: Small')) process.exit(3);
        if (!out.includes('https://example.com/run/1/artifacts/42')) process.exit(4);
        if (!out.includes('https://example.com/run/1')) process.exit(5);
        console.log('OK len=' + out.length);
        """
        res = subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True)
        self.assertIn("OK len=", res.stdout)


if __name__ == "__main__":
    unittest.main()
