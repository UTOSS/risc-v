#!/usr/bin/env python3
"""
Parse synthesis, hardening, and PnR metric reports, produce structured Markdown
diff tables with collapsible full text reports, and aggregate per-config reports
into a single Markdown summary (used identically by CI and local `make metrics-diff`).
"""
import argparse
import csv
import math
import os
import re
import sys
from collections import OrderedDict
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple


# ---------------------------------------------------------------------------
# Formatting helpers
# ---------------------------------------------------------------------------

CIRCLE_BETTER = "\U0001f7e2"   # green circle
CIRCLE_WORSE = "\U0001f534"    # red circle
CIRCLE_NEUTRAL = "\u26aa"      # white circle
CIRCLE_NEW = "\U0001f7e0"      # orange circle


@dataclass
class ColSpec:
    key: str
    header: str
    direction: str  # "lower", "higher", "abs_lower", "neutral"
    decimals: int   # 0 for int, >0 for fixed-point float


def format_num(value: float, decimals: int) -> str:
    if decimals == 0:
        return f"{int(round(value)):,}"
    if abs(value) < 0.5 * (10 ** (-decimals)):
        value = 0.0
    return f"{value:,.{decimals}f}"


def format_signed_num(value: float, decimals: int) -> str:
    if decimals == 0:
        iv = int(round(value))
        return f"{iv:+,}"
    if abs(value) < 0.5 * (10 ** (-decimals)):
        value = 0.0
    return f"{value:+,.{decimals}f}"


def is_changed(old: float, new: float, decimals: int) -> bool:
    eps = 0.5 * (10 ** (-decimals)) if decimals > 0 else 0.5
    return abs(new - old) >= eps - 1e-12


def direction_circle(old: float, new: float, direction: str) -> str:
    if direction == "neutral":
        return CIRCLE_NEUTRAL
    if direction == "lower":
        return CIRCLE_BETTER if new < old else CIRCLE_WORSE
    if direction == "higher":
        return CIRCLE_BETTER if new > old else CIRCLE_WORSE
    if direction == "abs_lower":
        if math.isclose(abs(new), abs(old), rel_tol=0.0, abs_tol=1e-12):
            return CIRCLE_NEUTRAL
        return CIRCLE_BETTER if abs(new) < abs(old) else CIRCLE_WORSE
    return CIRCLE_NEUTRAL


def format_diff_cell(
    old: Optional[float],
    new: Optional[float],
    direction: str,
    decimals: int,
    *,
    is_added: bool = False,
    is_removed: bool = False,
) -> str:
    """Format a single changed table cell, or return '' if unchanged."""
    if old is None and new is None:
        return ""
    old_val = 0.0 if old is None else old
    new_val = 0.0 if new is None else new

    if not is_changed(old_val, new_val, decimals):
        return ""

    delta = new_val - old_val
    circle = direction_circle(old_val, new_val, direction)
    old_s = format_num(old_val, decimals)
    new_s = format_num(new_val, decimals)
    delta_s = format_signed_num(delta, decimals)

    if abs(old_val) < 1e-12:
        pct_s = "new" if is_added else "N/A"
    else:
        pct = (delta / abs(old_val)) * 100.0
        pct_s = f"{pct:+.2f}%"

    return f"{circle} {old_s} \u2192 {new_s} ({delta_s} / {pct_s})"


def escape_md_cell(text: str) -> str:
    return text.replace("|", "\\|")


def render_table(headers: List[str], rows: List[List[str]]) -> str:
    lines = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join("---" for _ in headers) + " |",
    ]
    for r in rows:
        lines.append("| " + " | ".join(r) + " |")
    return "\n".join(lines)


def render_full_report_details(title: str, raw_path: Optional[str]) -> str:
    if not raw_path or not os.path.isfile(raw_path):
        return ""
    with open(raw_path, "r", encoding="utf-8", errors="replace") as f:
        raw_lines = [line.rstrip() for line in f.read().splitlines()]
    raw_text = "\n".join(raw_lines).strip("\n")
    if not raw_text:
        return ""
    return (
        "\n<!-- FULL_REPORT_START -->\n"
        "<details>\n"
        f"<summary>Full report: {title}</summary>\n\n"
        "```text\n"
        f"{raw_text}\n"
        "```\n\n"
        "</details>\n"
        "<!-- FULL_REPORT_END -->\n"
    )


def render_section_output(
    body_blocks: List[str],
    title: str,
    raw_pr_path: Optional[str],
    *,
    has_baseline: bool,
    has_pr: bool,
) -> str:
    if not has_pr:
        return "*Report not generated*\n"
    parts: List[str] = []
    if not has_baseline:
        parts.append("*No baseline available*")
    elif not body_blocks:
        parts.append("*No changes detected*")
    else:
        parts.extend(body_blocks)
    details = render_full_report_details(title, raw_pr_path)
    out = "\n\n".join(parts) + "\n"
    if details:
        out += details
    return out


# ---------------------------------------------------------------------------
# Generic multi-column table diff
# ---------------------------------------------------------------------------

def style_row(label: str, cells: List[str], *, is_added: bool, is_removed: bool) -> List[str]:
    if is_added:
        return [f"{CIRCLE_NEW} {label} *(new)*"] + cells
    if is_removed:
        return [f"~~{label}~~"] + [f"~~{c}~~" if c else "" for c in cells]
    return [label] + cells


def diff_table_rows(
    base_rows: "OrderedDict[str, Dict[str, float]]",
    pr_rows: "OrderedDict[str, Dict[str, float]]",
    col_specs: List[ColSpec],
    *,
    key_header: str,
    label_fn=None,
    row_direction_override=None,
    pin_last_keys: Tuple[str, ...] = (),
) -> Optional[str]:
    """Diff two OrderedDicts of {row_key: {col_key: float}} into a Markdown table."""
    all_keys: List[str] = []
    seen = set()
    for src in (pr_rows, base_rows):
        for k in src:
            if k not in seen and k not in pin_last_keys:
                seen.add(k)
                all_keys.append(k)
    for k in pin_last_keys:
        if k in pr_rows or k in base_rows:
            all_keys.append(k)

    md_rows: List[List[str]] = []
    for k in all_keys:
        in_base = k in base_rows
        in_pr = k in pr_rows
        b_vals = base_rows.get(k, {})
        p_vals = pr_rows.get(k, {})

        cells: List[str] = []
        any_changed = False
        for spec in col_specs:
            direction = spec.direction
            if row_direction_override is not None:
                direction = row_direction_override(k, spec)
            cell = format_diff_cell(
                b_vals.get(spec.key) if in_base else 0.0,
                p_vals.get(spec.key) if in_pr else 0.0,
                direction,
                spec.decimals,
                is_added=(not in_base and in_pr),
                is_removed=(in_base and not in_pr),
            )
            if cell:
                any_changed = True
            cells.append(cell)

        if not any_changed:
            continue

        label = label_fn(k) if label_fn else escape_md_cell(k)
        md_rows.append(
            style_row(label, cells, is_added=(not in_base and in_pr), is_removed=(in_base and not in_pr))
        )

    if not md_rows:
        return None

    headers = [key_header] + [s.header for s in col_specs]
    return render_table(headers, md_rows)


# ---------------------------------------------------------------------------
# Parsers & per-report diff builders
# ---------------------------------------------------------------------------

FIT_SUMMARY_SKIP_KEYS = {
    "Fitter Status",
    "Quartus Prime Version",
    "Revision Name",
    "Top-level Entity Name",
    "Family",
    "Device",
    "Timing Models",
}


def parse_fit_summary(path: str) -> "OrderedDict[str, Tuple[float, int]]":
    metrics: "OrderedDict[str, Tuple[float, int]]" = OrderedDict()
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            if ":" not in line:
                continue
            key, val = line.split(":", 1)
            key = key.strip()
            val = val.strip()
            if not key or key in FIT_SUMMARY_SKIP_KEYS:
                continue
            m = re.match(r"^([+-]?[\d,]+(?:\.(\d+))?)", val)
            if not m:
                continue
            num_str = m.group(1).replace(",", "")
            decimals = len(m.group(2)) if m.group(2) else 0
            metrics[key] = (float(num_str), decimals)
    return metrics


def diff_fit_summary(base_path: Optional[str], pr_path: Optional[str]) -> str:
    has_pr = bool(pr_path and os.path.isfile(pr_path))
    has_base = bool(base_path and os.path.isfile(base_path))
    blocks: List[str] = []

    if has_pr and has_base:
        base_m = parse_fit_summary(base_path)
        pr_m = parse_fit_summary(pr_path)
        all_keys = list(OrderedDict.fromkeys(list(pr_m.keys()) + list(base_m.keys())))
        rows: List[List[str]] = []
        for k in all_keys:
            in_base = k in base_m
            in_pr = k in pr_m
            b_val, b_dec = base_m.get(k, (None, 0))
            p_val, p_dec = pr_m.get(k, (None, 0))
            dec = max(b_dec, p_dec)
            cell = format_diff_cell(
                b_val,
                p_val,
                "lower",
                dec,
                is_added=(not in_base and in_pr),
                is_removed=(in_base and not in_pr),
            )
            if cell:
                rows.append(
                    style_row(
                        escape_md_cell(k),
                        [cell],
                        is_added=(not in_base and in_pr),
                        is_removed=(in_base and not in_pr),
                    )
                )
        if rows:
            blocks.append(render_table(["Metric", "Diff"], rows))

    return render_section_output(
        blocks, "Fitter Summary", pr_path, has_baseline=has_base, has_pr=has_pr
    )


QUARTUS_FITTER_COL_MAP: Dict[str, Tuple[str, str, int]] = {
    "ALMs needed [=A-B+C]": ("ALMs Needed", "lower", 1),
    "[A] ALMs used in final placement": ("[A] ALMs Used", "lower", 1),
    "[B] Estimate of ALMs recoverable by dense packing": ("[B] ALMs Recoverable", "higher", 1),
    "[C] Estimate of ALMs unavailable": ("[C] ALMs Unavailable", "lower", 1),
    "ALMs used for memory": ("ALMs (Mem)", "lower", 1),
    "Combinational ALUTs": ("Comb ALUTs", "lower", 0),
    "Dedicated Logic Registers": ("Registers", "lower", 0),
    "I/O Registers": ("I/O Regs", "lower", 0),
    "Block Memory Bits": ("Block Mem Bits", "lower", 0),
    "M10Ks": ("M10Ks", "lower", 0),
    "DSP Blocks": ("DSPs", "lower", 0),
    "Pins": ("Pins", "lower", 0),
    "Virtual Pins": ("Virtual Pins", "lower", 0),
}

QUARTUS_NON_NUMERIC_COLS = {
    "Compilation Hierarchy Node",
    "Full Hierarchy Name",
    "Entity Name",
    "Library Name",
}


def parse_quartus_cell_value(raw: str) -> Tuple[Optional[float], Optional[float], int]:
    """Parse '1525.5 (0.5)' or '1779 (1)' or '32768' -> (cumulative, local, decimals)."""
    s = raw.strip()
    m = re.match(
        r"^([+-]?[\d,]+(?:\.(\d+))?)(?:\s*\(\s*([+-]?[\d,]+(?:\.\d+)?)\s*\))?$",
        s,
    )
    if not m:
        return None, None, 0
    cum = float(m.group(1).replace(",", ""))
    dec = len(m.group(2)) if m.group(2) else 0
    loc = float(m.group(3).replace(",", "")) if m.group(3) is not None else None
    return cum, loc, dec


def parse_fitter_utilization_csv(
    path: str,
) -> Tuple[List[ColSpec], "OrderedDict[str, Dict[str, Tuple[float, Optional[float]]]]"]:
    rows: "OrderedDict[str, Dict[str, Tuple[float, Optional[float]]]]" = OrderedDict()
    col_specs: List[ColSpec] = []
    inferred_dec: Dict[str, int] = {}

    with open(path, "r", encoding="utf-8", errors="replace", newline="") as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames or []
        numeric_cols = [c for c in fieldnames if c and c not in QUARTUS_NON_NUMERIC_COLS]

        for r in reader:
            full_name = (r.get("Full Hierarchy Name") or "").strip()
            node_name = (r.get("Compilation Hierarchy Node") or "").strip()
            key = full_name or node_name
            if not key:
                continue
            vals: Dict[str, Tuple[float, Optional[float]]] = {}
            for col in numeric_cols:
                cum, loc, dec = parse_quartus_cell_value(r.get(col, ""))
                if cum is not None:
                    vals[col] = (cum, loc)
                    inferred_dec[col] = max(inferred_dec.get(col, 0), dec)
            rows[key] = vals

    for col in numeric_cols:
        if col in QUARTUS_FITTER_COL_MAP:
            header, direction, dec = QUARTUS_FITTER_COL_MAP[col]
        else:
            header, direction, dec = escape_md_cell(col), "lower", inferred_dec.get(col, 0)
        col_specs.append(ColSpec(key=col, header=header, direction=direction, decimals=dec))

    return col_specs, rows


def format_quartus_hierarchy(full_name: str) -> str:
    parts = [p for p in full_name.strip().split("|") if p]
    clean = " / ".join(parts) if parts else full_name
    return f"`{escape_md_cell(clean)}`"


def diff_fitter_by_entity(
    base_csv: Optional[str],
    pr_csv: Optional[str],
    pr_pretty: Optional[str],
) -> str:
    has_pr = bool(pr_csv and os.path.isfile(pr_csv))
    has_base = bool(base_csv and os.path.isfile(base_csv))
    raw_path = pr_pretty if (pr_pretty and os.path.isfile(pr_pretty)) else pr_csv
    blocks: List[str] = []

    if has_pr and has_base:
        base_specs, base_rows = parse_fitter_utilization_csv(base_csv)
        pr_specs, pr_rows = parse_fitter_utilization_csv(pr_csv)
        # Preserve PR column order, append any base-only columns
        spec_map = OrderedDict((s.key, s) for s in pr_specs)
        for s in base_specs:
            spec_map.setdefault(s.key, s)
        col_specs = list(spec_map.values())

        all_keys = list(OrderedDict.fromkeys(list(pr_rows.keys()) + list(base_rows.keys())))
        md_rows: List[List[str]] = []
        for k in all_keys:
            in_base = k in base_rows
            in_pr = k in pr_rows
            b_vals = base_rows.get(k, {})
            p_vals = pr_rows.get(k, {})

            cells: List[str] = []
            any_changed = False
            for spec in col_specs:
                b_pair = b_vals.get(spec.key, (0.0, None)) if in_base else (0.0, 0.0)
                p_pair = p_vals.get(spec.key, (0.0, None)) if in_pr else (0.0, 0.0)
                cell = format_diff_cell(
                    b_pair[0],
                    p_pair[0],
                    spec.direction,
                    spec.decimals,
                    is_added=(not in_base and in_pr),
                    is_removed=(in_base and not in_pr),
                )
                if not cell and b_pair[1] is not None and p_pair[1] is not None:
                    loc_cell = format_diff_cell(
                        b_pair[1],
                        p_pair[1],
                        spec.direction,
                        spec.decimals,
                    )
                    if loc_cell:
                        cell = f"local: {loc_cell}"
                if cell:
                    any_changed = True
                cells.append(cell)

            if not any_changed:
                continue

            label = format_quartus_hierarchy(k)
            md_rows.append(
                style_row(label, cells, is_added=(not in_base and in_pr), is_removed=(in_base and not in_pr))
            )

        if md_rows:
            headers = ["Entity"] + [s.header for s in col_specs]
            blocks.append(render_table(headers, md_rows))

    return render_section_output(
        blocks,
        "Fitter Resource Utilization by Entity",
        raw_path,
        has_baseline=has_base,
        has_pr=has_pr,
    )


def parse_sta_summary(path: str) -> "OrderedDict[str, Dict[str, float]]":
    rows: "OrderedDict[str, Dict[str, float]]" = OrderedDict()
    current_type: Optional[str] = None
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if line.startswith("Type"):
                _, val = line.split(":", 1)
                current_type = val.strip()
                rows.setdefault(current_type, {})
            elif current_type and (line.startswith("Slack") or line.startswith("TNS")):
                key, val = line.split(":", 1)
                key = key.strip()
                m = re.match(r"^([+-]?[\d,]+(?:\.\d+)?)", val.strip())
                if m:
                    rows[current_type][key] = float(m.group(1).replace(",", ""))
    return rows


def diff_sta_summary(base_path: Optional[str], pr_path: Optional[str]) -> str:
    has_pr = bool(pr_path and os.path.isfile(pr_path))
    has_base = bool(base_path and os.path.isfile(base_path))
    blocks: List[str] = []

    if has_pr and has_base:
        base_rows = parse_sta_summary(base_path)
        pr_rows = parse_sta_summary(pr_path)
        specs = [
            ColSpec("Slack", "Slack (ns)", "higher", 3),
            ColSpec("TNS", "TNS (ns)", "higher", 3),
        ]
        tbl = diff_table_rows(base_rows, pr_rows, specs, key_header="Model / Analysis")
        if tbl:
            blocks.append(tbl)

    return render_section_output(
        blocks, "Timing Analysis Summary", pr_path, has_baseline=has_base, has_pr=has_pr
    )


UTILIZATION_COL_SPECS = [
    ColSpec("Total Cells", "Total Cells", "lower", 0),
    ColSpec("Total Area (um^2)", "Total Area (um^2)", "lower", 2),
    ColSpec("Combinational Cells", "Comb Cells", "lower", 0),
    ColSpec("Combinational Area (um^2)", "Comb Area (um^2)", "lower", 2),
    ColSpec("Sequential Cells", "Seq Cells", "lower", 0),
    ColSpec("Sequential Area (um^2)", "Seq Area (um^2)", "lower", 2),
]


def parse_utilization_csv(path: str) -> "OrderedDict[str, Dict[str, float]]":
    rows: "OrderedDict[str, Dict[str, float]]" = OrderedDict()
    with open(path, "r", encoding="utf-8", errors="replace", newline="") as f:
        reader = csv.DictReader(f)
        for r in reader:
            node = (r.get("Hierarchy Node") or "").strip()
            if not node:
                continue
            vals: Dict[str, float] = {}
            for spec in UTILIZATION_COL_SPECS:
                raw = (r.get(spec.key) or "").strip().replace(",", "")
                if raw:
                    vals[spec.key] = float(raw)
            rows[node] = vals
    return rows


def diff_utilization_csv(
    base_csv: Optional[str],
    pr_csv: Optional[str],
    pr_pretty: Optional[str],
    *,
    title: str,
    key_header: str,
) -> str:
    has_pr = bool(pr_csv and os.path.isfile(pr_csv))
    has_base = bool(base_csv and os.path.isfile(base_csv))
    raw_path = pr_pretty if (pr_pretty and os.path.isfile(pr_pretty)) else pr_csv
    blocks: List[str] = []

    if has_pr and has_base:
        base_rows = parse_utilization_csv(base_csv)
        pr_rows = parse_utilization_csv(pr_csv)
        tbl = diff_table_rows(
            base_rows,
            pr_rows,
            UTILIZATION_COL_SPECS,
            key_header=key_header,
            label_fn=lambda k: f"`{escape_md_cell(k)}`",
        )
        if tbl:
            blocks.append(tbl)

    return render_section_output(
        blocks, title, raw_path, has_baseline=has_base, has_pr=has_pr
    )


def parse_gate_breakdown(
    path: str,
) -> Tuple["OrderedDict[str, Dict[str, float]]", "OrderedDict[str, Dict[str, float]]"]:
    """Parse Yosys or OpenROAD gate_breakdown.txt into (gates_table, inserted_table)."""
    gates: "OrderedDict[str, Dict[str, float]]" = OrderedDict()
    inserted: "OrderedDict[str, Dict[str, float]]" = OrderedDict()
    in_inserted = False

    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            s = line.strip()
            if not s or set(s) <= {"=", "-"}:
                continue
            if s.startswith("Inserted by OpenROAD"):
                in_inserted = True
                continue
            if "|" not in s:
                continue
            parts = [p.strip() for p in s.split("|")]
            if not in_inserted and len(parts) == 4:
                cell_type, cnt_s, area_s, pct_s = parts
                if cell_type == "Cell Type":
                    continue
                try:
                    cnt = float(cnt_s.replace(",", ""))
                    area = float(area_s.replace(",", ""))
                    pct = float(pct_s.rstrip("%").replace(",", ""))
                except ValueError:
                    continue
                gates[cell_type] = {"Count": cnt, "Area": area, "Pct": pct}
            elif in_inserted and len(parts) == 3:
                cat, cnt_s, area_s = parts
                if cat == "Inserted by OpenROAD":
                    continue
                try:
                    cnt = float(cnt_s.replace(",", ""))
                    area = float(area_s.replace(",", ""))
                except ValueError:
                    continue
                inserted[cat] = {"Count": cnt, "Area": area}

    return gates, inserted


def diff_gate_breakdown(
    base_path: Optional[str],
    pr_path: Optional[str],
    *,
    title: str,
) -> str:
    has_pr = bool(pr_path and os.path.isfile(pr_path))
    has_base = bool(base_path and os.path.isfile(base_path))
    blocks: List[str] = []

    if has_pr and has_base:
        base_gates, base_ins = parse_gate_breakdown(base_path)
        pr_gates, pr_ins = parse_gate_breakdown(pr_path)

        gate_specs = [
            ColSpec("Count", "Count", "lower", 0),
            ColSpec("Area", "Total Area (um^2)", "lower", 2),
            ColSpec("Pct", "% Area", "neutral", 2),
        ]

        def gate_label(k: str) -> str:
            if k.startswith("TOTAL"):
                return f"**{escape_md_cell(k)}**"
            return f"`{escape_md_cell(k)}`"

        pin_totals = tuple(
            k for k in ("TOTAL", "TOTAL (logic)") if k in base_gates or k in pr_gates
        )
        gate_tbl = diff_table_rows(
            base_gates,
            pr_gates,
            gate_specs,
            key_header="Cell Type",
            label_fn=gate_label,
            pin_last_keys=pin_totals,
        )
        if gate_tbl:
            blocks.append(gate_tbl)

        if base_ins or pr_ins:
            ins_specs = [
                ColSpec("Count", "Count", "lower", 0),
                ColSpec("Area", "Area (um^2)", "lower", 2),
            ]

            def ins_dir(row_key: str, spec: ColSpec) -> str:
                if row_key.lower() == "filler cells":
                    return "neutral"
                return spec.direction

            ins_tbl = diff_table_rows(
                base_ins,
                pr_ins,
                ins_specs,
                key_header="Inserted by OpenROAD",
                row_direction_override=ins_dir,
            )
            if ins_tbl:
                blocks.append(ins_tbl)

    return render_section_output(
        blocks, title, pr_path, has_baseline=has_base, has_pr=has_pr
    )


PNR_TIMING_DIRECTIONS: Dict[str, str] = {
    "Parasitics": "neutral",
    "Clock period (clk)": "neutral",
    "Setup WNS": "higher",
    "Setup TNS": "higher",
    "Setup violating endpoints": "lower",
    "Hold WNS": "higher",
    "Hold TNS": "higher",
    "Hold violating endpoints": "lower",
    "Min. period (period - setup WNS)": "lower",
    "Est. Fmax": "higher",
    "Clock skew (setup)": "abs_lower",
    "Max slew violations": "lower",
    "Max capacitance violations": "lower",
    "Max fanout violations": "lower",
    "Die area": "lower",
    "Core area": "lower",
    "Std cell area (logic + taps)": "lower",
    "Core utilization": "neutral",
    "Internal": "lower",
    "Switching": "lower",
    "Leakage": "lower",
    "Total": "lower",
}


@dataclass
class TimingMetric:
    category: str
    name: str
    value: Optional[float]
    raw: str
    unit: str
    decimals: int


def parse_pnr_timing(path: str) -> "OrderedDict[Tuple[str, str], TimingMetric]":
    metrics: "OrderedDict[Tuple[str, str], TimingMetric]" = OrderedDict()
    category = "General"
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            s = line.strip()
            if not s or set(s) <= {"=", "-"}:
                continue
            if s.startswith("-- "):
                # e.g. "-- Power (typical corner, 10% input activity) ------"
                sec = s[3:].rstrip("-").strip()
                sec = re.sub(r"\s*\(.*\)$", "", sec).strip()
                category = sec or "General"
                continue
            if ":" not in line or s.startswith("("):
                continue
            key, val = line.split(":", 1)
            key = key.strip()
            val = val.strip()
            m = re.match(r"^([+-]?[\d,]+(?:\.(\d+))?)(?:\s+(.*))?$", val)
            if m:
                num = float(m.group(1).replace(",", ""))
                dec = len(m.group(2)) if m.group(2) else 0
                unit = (m.group(3) or "").strip()
                metrics[(category, key)] = TimingMetric(category, key, num, val, unit, dec)
            else:
                metrics[(category, key)] = TimingMetric(category, key, None, val, "", 0)
    return metrics


def diff_pnr_timing(base_path: Optional[str], pr_path: Optional[str]) -> str:
    has_pr = bool(pr_path and os.path.isfile(pr_path))
    has_base = bool(base_path and os.path.isfile(base_path))
    blocks: List[str] = []

    if has_pr and has_base:
        base_m = parse_pnr_timing(base_path)
        pr_m = parse_pnr_timing(pr_path)
        all_keys = list(OrderedDict.fromkeys(list(pr_m.keys()) + list(base_m.keys())))
        rows: List[List[str]] = []
        for k in all_keys:
            cat, name = k
            in_base = k in base_m
            in_pr = k in pr_m
            bm = base_m.get(k)
            pm = pr_m.get(k)
            unit = (pm.unit if pm and pm.unit else (bm.unit if bm else ""))
            label = f"{escape_md_cell(name)} ({escape_md_cell(unit)})" if unit else escape_md_cell(name)
            direction = PNR_TIMING_DIRECTIONS.get(name, "lower")

            diff_cell = ""
            if (bm is not None and bm.value is not None) or (pm is not None and pm.value is not None):
                b_val = bm.value if bm is not None else None
                p_val = pm.value if pm is not None else None
                if b_val is None or p_val is None:
                    b_raw = bm.raw if bm else "n/a"
                    p_raw = pm.raw if pm else "n/a"
                    if b_raw != p_raw:
                        diff_cell = f"{CIRCLE_NEUTRAL} {b_raw} \u2192 {p_raw}"
                else:
                    dec = max(bm.decimals if bm else 0, pm.decimals if pm else 0)
                    diff_cell = format_diff_cell(
                        b_val,
                        p_val,
                        direction,
                        dec,
                        is_added=(not in_base and in_pr),
                        is_removed=(in_base and not in_pr),
                    )
            else:
                b_raw = bm.raw if bm else "n/a"
                p_raw = pm.raw if pm else "n/a"
                if b_raw != p_raw:
                    diff_cell = f"{CIRCLE_NEUTRAL} {b_raw} \u2192 {p_raw}"

            if diff_cell:
                cat_cell = escape_md_cell(cat)
                if not in_base and in_pr:
                    rows.append([cat_cell, f"{CIRCLE_NEW} {label} *(new)*", diff_cell])
                elif in_base and not in_pr:
                    rows.append([f"~~{cat_cell}~~", f"~~{label}~~", f"~~{diff_cell}~~"])
                else:
                    rows.append([cat_cell, label, diff_cell])

        if rows:
            blocks.append(render_table(["Category", "Metric", "Diff"], rows))

    return render_section_output(
        blocks, "Post-PnR Timing Summary", pr_path, has_baseline=has_base, has_pr=has_pr
    )


COREMARK_DIRECTIONS: Dict[str, str] = {
    "Iterations": "neutral",
    "Timed Cycles": "lower",
    "Instructions Retired": "lower",
    "CPI (Cycles / Instret)": "lower",
    "IPC (Instret / Cycle)": "higher",
    "CoreMark / MHz": "higher",
    "Stall Cycles (timed)": "lower",
    "Flush Cycles (timed)": "lower",
    "Total Sim Cycles": "lower",
    "Total Sim Instret": "lower",
}

COREMARK_SKIP_KEYS = {"ISA Config"}


def parse_coremark_metrics(path: str) -> "OrderedDict[str, Tuple[float, int]]":
    metrics: "OrderedDict[str, Tuple[float, int]]" = OrderedDict()
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            if ":" not in line:
                continue
            key, val = line.split(":", 1)
            key = key.strip()
            val = val.strip()
            if not key or key in COREMARK_SKIP_KEYS:
                continue
            m = re.match(r"^([+-]?[\d,]+(?:\.(\d+))?)", val)
            if not m:
                continue
            num = float(m.group(1).replace(",", ""))
            dec = len(m.group(2)) if m.group(2) else 0
            metrics[key] = (num, dec)
    return metrics


def diff_coremark_metrics(base_path: Optional[str], pr_path: Optional[str]) -> str:
    has_pr = bool(pr_path and os.path.isfile(pr_path))
    has_base = bool(base_path and os.path.isfile(base_path))
    blocks: List[str] = []

    if has_pr and has_base:
        base_m = parse_coremark_metrics(base_path)
        pr_m = parse_coremark_metrics(pr_path)
        all_keys = list(OrderedDict.fromkeys(list(pr_m.keys()) + list(base_m.keys())))
        rows: List[List[str]] = []
        for k in all_keys:
            in_base = k in base_m
            in_pr = k in pr_m
            b_val, b_dec = base_m.get(k, (None, 0))
            p_val, p_dec = pr_m.get(k, (None, 0))
            dec = max(b_dec, p_dec)
            direction = COREMARK_DIRECTIONS.get(k, "lower")
            cell = format_diff_cell(
                b_val,
                p_val,
                direction,
                dec,
                is_added=(not in_base and in_pr),
                is_removed=(in_base and not in_pr),
            )
            if cell:
                rows.append(
                    style_row(
                        escape_md_cell(k),
                        [cell],
                        is_added=(not in_base and in_pr),
                        is_removed=(in_base and not in_pr),
                    )
                )
        if rows:
            blocks.append(render_table(["Metric", "Diff"], rows))

    return render_section_output(
        blocks, "CoreMark Metrics", pr_path, has_baseline=has_base, has_pr=has_pr
    )


EMBENCH_COL_SPECS = [
    ColSpec("Text(B)", "Text (B)", "lower", 0),
    ColSpec("Cycles", "Cycles", "lower", 0),
    ColSpec("Instret", "Instret", "lower", 0),
    ColSpec("CPI", "CPI", "lower", 4),
    ColSpec("IPC", "IPC", "higher", 4),
    ColSpec("Stall%", "Stall (%)", "lower", 2),
    ColSpec("Flush%", "Flush (%)", "lower", 2),
]


def parse_embench_metrics(
    path: str,
) -> Tuple["OrderedDict[str, Optional[str]]", "OrderedDict[str, Dict[str, float]]"]:
    statuses: "OrderedDict[str, Optional[str]]" = OrderedDict()
    rows: "OrderedDict[str, Dict[str, float]]" = OrderedDict()

    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            s = line.strip()
            if (
                not s
                or set(s) <= {"-", "="}
                or s.startswith("ISA Config:")
                or s.startswith("Benchmark ")
            ):
                continue
            toks = s.split()
            name = toks[0]
            try:
                if name == "GEOMEAN" and len(toks) >= 3:
                    statuses[name] = None
                    rows[name] = {
                        "CPI": float(toks[1]),
                        "IPC": float(toks[2]),
                    }
                elif name == "TOTAL/AGG" and len(toks) >= 8:
                    statuses[name] = toks[1]
                    rows[name] = {
                        "Cycles": float(toks[2]),
                        "Instret": float(toks[3]),
                        "CPI": float(toks[4]),
                        "IPC": float(toks[5]),
                        "Stall%": float(toks[6].rstrip("%")),
                        "Flush%": float(toks[7].rstrip("%")),
                    }
                elif len(toks) >= 9:
                    statuses[name] = toks[1]
                    rows[name] = {
                        "Text(B)": float(toks[2]),
                        "Cycles": float(toks[3]),
                        "Instret": float(toks[4]),
                        "CPI": float(toks[5]),
                        "IPC": float(toks[6]),
                        "Stall%": float(toks[7].rstrip("%")),
                        "Flush%": float(toks[8].rstrip("%")),
                    }
            except ValueError:
                continue

    return statuses, rows


def format_embench_status_diff(old_s: Optional[str], new_s: Optional[str]) -> str:
    if old_s == new_s or (old_s is None and new_s is None):
        return ""
    o = old_s or "n/a"
    n = new_s or "n/a"
    circle = CIRCLE_NEUTRAL
    if o != "PASS" and n == "PASS":
        circle = CIRCLE_BETTER
    elif o == "PASS" and n != "PASS":
        circle = CIRCLE_WORSE
    else:
        mo = re.match(r"^(\d+)/(\d+)$", o)
        mn = re.match(r"^(\d+)/(\d+)$", n)
        if mo and mn:
            if int(mn.group(1)) > int(mo.group(1)):
                circle = CIRCLE_BETTER
            elif int(mn.group(1)) < int(mo.group(1)):
                circle = CIRCLE_WORSE
    return f"{circle} {escape_md_cell(o)} \u2192 {escape_md_cell(n)}"


def diff_embench_metrics(base_path: Optional[str], pr_path: Optional[str]) -> str:
    has_pr = bool(pr_path and os.path.isfile(pr_path))
    has_base = bool(base_path and os.path.isfile(base_path))
    blocks: List[str] = []

    if has_pr and has_base:
        base_status, base_rows = parse_embench_metrics(base_path)
        pr_status, pr_rows = parse_embench_metrics(pr_path)
        pin_last = ("TOTAL/AGG", "GEOMEAN")
        all_keys: List[str] = []
        seen = set()
        for src in (pr_rows, base_rows):
            for k in src:
                if k not in seen and k not in pin_last:
                    seen.add(k)
                    all_keys.append(k)
        for k in pin_last:
            if k in pr_rows or k in base_rows:
                all_keys.append(k)

        md_rows: List[List[str]] = []
        for k in all_keys:
            in_base = k in base_rows
            in_pr = k in pr_rows
            b_vals = base_rows.get(k, {})
            p_vals = pr_rows.get(k, {})

            status_cell = format_embench_status_diff(
                base_status.get(k) if in_base else None,
                pr_status.get(k) if in_pr else None,
            )
            cells = [status_cell]
            any_changed = bool(status_cell)
            for spec in EMBENCH_COL_SPECS:
                b_v = b_vals.get(spec.key) if in_base else (0.0 if spec.key in p_vals else None)
                p_v = p_vals.get(spec.key) if in_pr else (0.0 if spec.key in b_vals else None)
                cell = format_diff_cell(
                    b_v,
                    p_v,
                    spec.direction,
                    spec.decimals,
                    is_added=(not in_base and in_pr),
                    is_removed=(in_base and not in_pr),
                )
                if cell:
                    any_changed = True
                cells.append(cell)

            if not any_changed:
                continue

            label = f"**{escape_md_cell(k)}**" if k in pin_last else f"`{escape_md_cell(k)}`"
            md_rows.append(
                style_row(
                    label,
                    cells,
                    is_added=(not in_base and in_pr),
                    is_removed=(in_base and not in_pr),
                )
            )

        if md_rows:
            headers = ["Benchmark", "Status"] + [s.header for s in EMBENCH_COL_SPECS]
            blocks.append(render_table(headers, md_rows))

    return render_section_output(
        blocks, "Embench-IoT Metrics", pr_path, has_baseline=has_base, has_pr=has_pr
    )


ECP5_UTIL_COL_SPECS = [
    ColSpec("LUT4 (TRELLIS_COMB)", "LUT4", "lower", 0),
    ColSpec("FF (TRELLIS_FF)", "FF", "lower", 0),
    ColSpec("BRAM (DP16KD)", "BRAM", "lower", 0),
    ColSpec("DSP (MULT18X18D)", "DSP", "lower", 0),
    ColSpec("IO (TRELLIS_IO)", "IO", "lower", 0),
    ColSpec("Total Cells", "Total Cells", "lower", 0),
]

ECP5_SUMMARY_SKIP_KEYS = {"Device"}


def parse_ecp5_pnr_summary(path: str) -> "OrderedDict[Tuple[str, str], Tuple[float, int]]":
    metrics: "OrderedDict[Tuple[str, str], Tuple[float, int]]" = OrderedDict()
    category = "Device Resource Utilization"
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            s = line.strip()
            if not s or set(s) <= {"=", "-"}:
                continue
            if s.startswith("-- "):
                sec = s[3:].rstrip("-").strip()
                sec = re.sub(r"\s*\(.*\)$", "", sec).strip()
                category = sec or category
                continue
            if ":" not in line:
                continue
            key, val = line.split(":", 1)
            key = key.strip()
            val = val.strip()
            if not key or key in ECP5_SUMMARY_SKIP_KEYS:
                continue
            m = re.match(r"^([+-]?[\d,]+(?:\.(\d+))?)", val)
            if not m:
                continue
            num = float(m.group(1).replace(",", ""))
            dec = len(m.group(2)) if m.group(2) else 0
            metrics[(category, key)] = (num, dec)
    return metrics


def diff_ecp5_pnr_summary(base_path: Optional[str], pr_path: Optional[str]) -> str:
    has_pr = bool(pr_path and os.path.isfile(pr_path))
    has_base = bool(base_path and os.path.isfile(base_path))
    blocks: List[str] = []

    if has_pr and has_base:
        base_m = parse_ecp5_pnr_summary(base_path)
        pr_m = parse_ecp5_pnr_summary(pr_path)
        all_keys = list(OrderedDict.fromkeys(list(pr_m.keys()) + list(base_m.keys())))
        rows: List[List[str]] = []
        for k in all_keys:
            cat, name = k
            in_base = k in base_m
            in_pr = k in pr_m
            b_val, b_dec = base_m.get(k, (None, 0))
            p_val, p_dec = pr_m.get(k, (None, 0))
            dec = max(b_dec, p_dec)
            cell = format_diff_cell(
                b_val,
                p_val,
                "lower",
                dec,
                is_added=(not in_base and in_pr),
                is_removed=(in_base and not in_pr),
            )
            if cell:
                cat_s = escape_md_cell(cat)
                name_s = escape_md_cell(name)
                if not in_base and in_pr:
                    rows.append([cat_s, f"{CIRCLE_NEW} {name_s} *(new)*", cell])
                elif in_base and not in_pr:
                    rows.append([f"~~{cat_s}~~", f"~~{name_s}~~", f"~~{cell}~~"])
                else:
                    rows.append([cat_s, name_s, cell])
        if rows:
            blocks.append(render_table(["Category", "Metric", "Diff"], rows))

    return render_section_output(
        blocks, "ECP5 PnR Summary", pr_path, has_baseline=has_base, has_pr=has_pr
    )


def parse_ecp5_utilization_csv(path: str) -> "OrderedDict[str, Dict[str, float]]":
    rows: "OrderedDict[str, Dict[str, float]]" = OrderedDict()
    with open(path, "r", encoding="utf-8", errors="replace", newline="") as f:
        reader = csv.DictReader(f)
        for r in reader:
            node = (r.get("Hierarchy Node") or "").strip()
            if not node:
                continue
            vals: Dict[str, float] = {}
            for spec in ECP5_UTIL_COL_SPECS:
                raw = (r.get(spec.key) or "").strip().replace(",", "")
                if raw:
                    vals[spec.key] = float(raw)
            rows[node] = vals
    return rows


def diff_ecp5_by_entity(
    base_csv: Optional[str],
    pr_csv: Optional[str],
    pr_pretty: Optional[str],
) -> str:
    has_pr = bool(pr_csv and os.path.isfile(pr_csv))
    has_base = bool(base_csv and os.path.isfile(base_csv))
    raw_path = pr_pretty if (pr_pretty and os.path.isfile(pr_pretty)) else pr_csv
    blocks: List[str] = []

    if has_pr and has_base:
        base_rows = parse_ecp5_utilization_csv(base_csv)
        pr_rows = parse_ecp5_utilization_csv(pr_csv)
        tbl = diff_table_rows(
            base_rows,
            pr_rows,
            ECP5_UTIL_COL_SPECS,
            key_header="Hierarchy / Instance",
            label_fn=lambda k: f"`{escape_md_cell(k)}`",
        )
        if tbl:
            blocks.append(tbl)

    return render_section_output(
        blocks,
        "ECP5 Utilization by Entity",
        raw_path,
        has_baseline=has_base,
        has_pr=has_pr,
    )


ECP5_TIMING_DIRECTIONS: Dict[str, str] = {
    "Target frequency": "neutral",
    "Achieved Fmax": "higher",
    "Setup slack": "higher",
    "Logic delay": "lower",
    "Routing delay": "lower",
    "Total path delay": "lower",
}

ECP5_TIMING_SKIP_KEYS = {"Clock", "From", "To"}


def parse_ecp5_timing(path: str) -> "OrderedDict[Tuple[str, str], TimingMetric]":
    metrics: "OrderedDict[Tuple[str, str], TimingMetric]" = OrderedDict()
    category = "Timing"
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            s = line.strip()
            if not s or set(s) <= {"=", "-"}:
                continue
            if s.startswith("-- "):
                sec = s[3:].rstrip("-").strip()
                category = sec or category
                continue
            if ":" not in line:
                continue
            key, val = line.split(":", 1)
            key = key.strip()
            val = val.strip()
            if not key or key in ECP5_TIMING_SKIP_KEYS:
                continue
            m = re.match(r"^([+-]?[\d,]+(?:\.(\d+))?)(?:\s+([A-Za-z0-9^/%]+))?", val)
            if m:
                num = float(m.group(1).replace(",", ""))
                dec = len(m.group(2)) if m.group(2) else 0
                unit = (m.group(3) or "").strip()
                metrics[(category, key)] = TimingMetric(category, key, num, val, unit, dec)
            else:
                metrics[(category, key)] = TimingMetric(category, key, None, val, "", 0)
    return metrics


def diff_ecp5_timing(base_path: Optional[str], pr_path: Optional[str]) -> str:
    has_pr = bool(pr_path and os.path.isfile(pr_path))
    has_base = bool(base_path and os.path.isfile(base_path))
    blocks: List[str] = []

    if has_pr and has_base:
        base_m = parse_ecp5_timing(base_path)
        pr_m = parse_ecp5_timing(pr_path)
        all_keys = list(OrderedDict.fromkeys(list(pr_m.keys()) + list(base_m.keys())))
        rows: List[List[str]] = []
        for k in all_keys:
            cat, name = k
            in_base = k in base_m
            in_pr = k in pr_m
            bm = base_m.get(k)
            pm = pr_m.get(k)
            unit = (pm.unit if pm and pm.unit else (bm.unit if bm else ""))
            label = f"{escape_md_cell(name)} ({escape_md_cell(unit)})" if unit else escape_md_cell(name)
            direction = ECP5_TIMING_DIRECTIONS.get(name, "lower")

            diff_cell = ""
            if (bm is not None and bm.value is not None) and (pm is not None and pm.value is not None):
                dec = max(bm.decimals, pm.decimals)
                diff_cell = format_diff_cell(bm.value, pm.value, direction, dec)
            else:
                b_raw = bm.raw if bm else "n/a"
                p_raw = pm.raw if pm else "n/a"
                if b_raw != p_raw:
                    if name == "Timing status":
                        diff_cell = format_embench_status_diff(b_raw, p_raw)
                    else:
                        diff_cell = f"{CIRCLE_NEUTRAL} {escape_md_cell(b_raw)} \u2192 {escape_md_cell(p_raw)}"

            if diff_cell:
                cat_s = escape_md_cell(cat)
                if not in_base and in_pr:
                    rows.append([cat_s, f"{CIRCLE_NEW} {label} *(new)*", diff_cell])
                elif in_base and not in_pr:
                    rows.append([f"~~{cat_s}~~", f"~~{label}~~", f"~~{diff_cell}~~"])
                else:
                    rows.append([cat_s, label, diff_cell])

        if rows:
            blocks.append(render_table(["Category", "Metric", "Diff"], rows))

    return render_section_output(
        blocks, "ECP5 Timing Summary", pr_path, has_baseline=has_base, has_pr=has_pr
    )


# ---------------------------------------------------------------------------
# Subcommand handlers
# ---------------------------------------------------------------------------

def write_file(path: str, content: str) -> None:
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


def cmd_de1_soc(args: argparse.Namespace) -> None:
    os.makedirs(args.out_dir, exist_ok=True)

    fit_md = diff_fit_summary(
        os.path.join(args.base_dir, "output_files/utoss-risc-v.fit.summary") if args.base_dir else None,
        os.path.join(args.pr_dir, "output_files/utoss-risc-v.fit.summary"),
    )
    write_file(os.path.join(args.out_dir, "fitter_summary.md"), fit_md)

    entity_md = diff_fitter_by_entity(
        os.path.join(args.base_dir, "metrics/fitter_utilization.csv") if args.base_dir else None,
        os.path.join(args.pr_dir, "metrics/fitter_utilization.csv"),
        os.path.join(args.pr_dir, "metrics/fitter_utilization.pretty.txt"),
    )
    write_file(os.path.join(args.out_dir, "fitter_by_entity.md"), entity_md)

    sta_md = diff_sta_summary(
        os.path.join(args.base_dir, "output_files/utoss-risc-v.sta.summary") if args.base_dir else None,
        os.path.join(args.pr_dir, "output_files/utoss-risc-v.sta.summary"),
    )
    write_file(os.path.join(args.out_dir, "timing_summary.md"), sta_md)


def cmd_ecp5(args: argparse.Namespace) -> None:
    os.makedirs(args.out_dir, exist_ok=True)

    summary_md = diff_ecp5_pnr_summary(
        os.path.join(args.base_dir, "pnr_summary.txt") if args.base_dir else None,
        os.path.join(args.pr_dir, "pnr_summary.txt"),
    )
    write_file(os.path.join(args.out_dir, "pnr_summary.md"), summary_md)

    entity_md = diff_ecp5_by_entity(
        os.path.join(args.base_dir, "pnr_utilization.csv") if args.base_dir else None,
        os.path.join(args.pr_dir, "pnr_utilization.csv"),
        os.path.join(args.pr_dir, "pnr_utilization.pretty.txt"),
    )
    write_file(os.path.join(args.out_dir, "pnr_by_entity.md"), entity_md)

    timing_md = diff_ecp5_timing(
        os.path.join(args.base_dir, "timing_summary.txt") if args.base_dir else None,
        os.path.join(args.pr_dir, "timing_summary.txt"),
    )
    write_file(os.path.join(args.out_dir, "timing_summary.md"), timing_md)


def cmd_hardening(args: argparse.Namespace) -> None:
    os.makedirs(args.out_dir, exist_ok=True)

    synth_util_md = diff_utilization_csv(
        os.path.join(args.base_dir, "metrics/synthesis_utilization.csv") if args.base_dir else None,
        os.path.join(args.pr_dir, "metrics/synthesis_utilization.csv"),
        os.path.join(args.pr_dir, "metrics/synthesis_utilization.pretty.txt"),
        title="Hardening Utilization by Entity",
        key_header="Hierarchy / Module",
    )
    write_file(os.path.join(args.out_dir, "hardening_utilization.md"), synth_util_md)

    synth_gates_md = diff_gate_breakdown(
        os.path.join(args.base_dir, "metrics/gate_breakdown.txt") if args.base_dir else None,
        os.path.join(args.pr_dir, "metrics/gate_breakdown.txt"),
        title="Hardening Gate Breakdown",
    )
    write_file(os.path.join(args.out_dir, "hardening_gate_breakdown.md"), synth_gates_md)

    pnr_util_md = diff_utilization_csv(
        os.path.join(args.base_dir, "metrics/pnr_utilization.csv") if args.base_dir else None,
        os.path.join(args.pr_dir, "metrics/pnr_utilization.csv"),
        os.path.join(args.pr_dir, "metrics/pnr_utilization.pretty.txt"),
        title="Post-PnR Utilization by Hierarchy",
        key_header="Hierarchy / Instance",
    )
    write_file(os.path.join(args.out_dir, "pnr_utilization.md"), pnr_util_md)

    pnr_gates_md = diff_gate_breakdown(
        os.path.join(args.base_dir, "metrics/pnr_gate_breakdown.txt") if args.base_dir else None,
        os.path.join(args.pr_dir, "metrics/pnr_gate_breakdown.txt"),
        title="Post-PnR Gate Breakdown",
    )
    write_file(os.path.join(args.out_dir, "pnr_gate_breakdown.md"), pnr_gates_md)

    pnr_timing_md = diff_pnr_timing(
        os.path.join(args.base_dir, "metrics/pnr_timing.txt") if args.base_dir else None,
        os.path.join(args.pr_dir, "metrics/pnr_timing.txt"),
    )
    write_file(os.path.join(args.out_dir, "pnr_timing.md"), pnr_timing_md)


def cmd_benchmarks(args: argparse.Namespace) -> None:
    os.makedirs(args.out_dir, exist_ok=True)

    coremark_md = diff_coremark_metrics(
        os.path.join(args.base_dir, "coremark_metrics.txt") if args.base_dir else None,
        os.path.join(args.pr_dir, "coremark_metrics.txt"),
    )
    write_file(os.path.join(args.out_dir, "coremark.md"), coremark_md)

    embench_md = diff_embench_metrics(
        os.path.join(args.base_dir, "embench_metrics.txt") if args.base_dir else None,
        os.path.join(args.pr_dir, "embench_metrics.txt"),
    )
    write_file(os.path.join(args.out_dir, "embench.md"), embench_md)


def read_md_or_missing(path: str) -> str:
    if not os.path.isfile(path):
        return "*missing*"
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        return f.read().strip()


def cmd_aggregate(args: argparse.Namespace) -> None:
    artifacts_dir = args.artifacts_dir
    configs = set()
    if os.path.isdir(artifacts_dir):
        for entry in os.listdir(artifacts_dir):
            full = os.path.join(artifacts_dir, entry)
            if not os.path.isdir(full):
                continue
            m = re.match(
                r"^(?:de1-soc-synthesis-metrics-diff|ecp5-synthesis-metrics-diff|hardening-metrics-diff|benchmarks-metrics-diff)-(.+)$",
                entry,
            )
            if m:
                configs.add(m.group(1))

    sorted_configs = sorted(configs)
    lines: List[str] = [
        "## \U0001f4ca Synthesis, Hardening & Benchmark Report Summary Diff",
        "",
        (
            f"Legend: {CIRCLE_BETTER} improved \u00b7 {CIRCLE_WORSE} regressed \u00b7 "
            f"{CIRCLE_NEUTRAL} neutral \u00b7 {CIRCLE_NEW} new row \u00b7 ~~removed row~~ \u2014 "
            "cells show `old \u2192 new (\u0394 / %\u0394)`; unchanged cells and rows are omitted."
        ),
        "",
    ]

    if not sorted_configs:
        lines.append("*No metrics diff artifacts found*")
        lines.append("")
    else:
        for idx, config in enumerate(sorted_configs):
            if idx > 0:
                lines.append("---")
                lines.append("")
            lines.append(f"### `{config}`")
            lines.append("")

            de1_dir = os.path.join(artifacts_dir, f"de1-soc-synthesis-metrics-diff-{config}")
            if os.path.isdir(de1_dir):
                lines.append("#### DE1-SoC Synthesis")
                lines.append("")
                for heading, fname in (
                    ("Fitter Summary", "fitter_summary.md"),
                    ("Fitter Resource Utilization by Entity", "fitter_by_entity.md"),
                    ("Timing Analysis Summary", "timing_summary.md"),
                ):
                    lines.append(f"##### {heading}")
                    lines.append("")
                    lines.append(read_md_or_missing(os.path.join(de1_dir, fname)))
                    lines.append("")

            ecp5_dir = os.path.join(artifacts_dir, f"ecp5-synthesis-metrics-diff-{config}")
            if os.path.isdir(ecp5_dir):
                lines.append("#### ECP5 Synthesis (LFE5U-25F-7BG256I)")
                lines.append("")
                for heading, fname in (
                    ("PnR Summary", "pnr_summary.md"),
                    ("Utilization by Entity", "pnr_by_entity.md"),
                    ("Timing Summary", "timing_summary.md"),
                ):
                    lines.append(f"##### {heading}")
                    lines.append("")
                    lines.append(read_md_or_missing(os.path.join(ecp5_dir, fname)))
                    lines.append("")

            harden_dir = os.path.join(artifacts_dir, f"hardening-metrics-diff-{config}")
            if os.path.isdir(harden_dir):
                lines.append("#### Nangate45 Hardening")
                lines.append("")
                for heading, fname in (
                    ("Utilization by Entity", "hardening_utilization.md"),
                    ("Gate Breakdown", "hardening_gate_breakdown.md"),
                ):
                    lines.append(f"##### {heading}")
                    lines.append("")
                    lines.append(read_md_or_missing(os.path.join(harden_dir, fname)))
                    lines.append("")

                lines.append("#### Nangate45 Place & Route (OpenROAD)")
                lines.append("")
                for heading, fname in (
                    ("Timing, Area & Power (OpenSTA)", "pnr_timing.md"),
                    ("Utilization by Hierarchy", "pnr_utilization.md"),
                    ("Gate Breakdown", "pnr_gate_breakdown.md"),
                ):
                    lines.append(f"##### {heading}")
                    lines.append("")
                    lines.append(read_md_or_missing(os.path.join(harden_dir, fname)))
                    lines.append("")

            bench_dir = os.path.join(artifacts_dir, f"benchmarks-metrics-diff-{config}")
            if os.path.isdir(bench_dir):
                lines.append("#### Benchmarks (CPI / Cycles)")
                lines.append("")
                for heading, fname in (
                    ("CoreMark", "coremark.md"),
                    ("Embench-IoT", "embench.md"),
                ):
                    lines.append(f"##### {heading}")
                    lines.append("")
                    lines.append(read_md_or_missing(os.path.join(bench_dir, fname)))
                    lines.append("")

    lines.append("---")
    lines.append(
        f"*Comparing synthesis, hardening & benchmark results from {args.base_label} vs. {args.head_label}*"
    )
    lines.append("")

    write_file(args.output, "\n".join(lines))


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Generate structured Markdown metrics diff reports.")
    sub = p.add_subparsers(dest="command", required=True)

    p_de1 = sub.add_parser("de1-soc", help="Diff DE1-SoC Quartus reports.")
    p_de1.add_argument("--base-dir", default="", help="Base branch Quartus reports directory.")
    p_de1.add_argument("--pr-dir", required=True, help="PR/current Quartus reports directory.")
    p_de1.add_argument("--out-dir", required=True, help="Output directory for per-report .md files.")
    p_de1.set_defaults(func=cmd_de1_soc)

    p_ecp5 = sub.add_parser("ecp5", help="Diff ECP5 Trellis/nextpnr reports.")
    p_ecp5.add_argument("--base-dir", default="", help="Base branch ECP5 reports directory.")
    p_ecp5.add_argument("--pr-dir", required=True, help="PR/current ECP5 reports directory.")
    p_ecp5.add_argument("--out-dir", required=True, help="Output directory for per-report .md files.")
    p_ecp5.set_defaults(func=cmd_ecp5)

    p_h = sub.add_parser("hardening", help="Diff Nangate45 hardening & PnR reports.")
    p_h.add_argument("--base-dir", default="", help="Base branch hardening reports directory.")
    p_h.add_argument("--pr-dir", required=True, help="PR/current hardening reports directory.")
    p_h.add_argument("--out-dir", required=True, help="Output directory for per-report .md files.")
    p_h.set_defaults(func=cmd_hardening)

    p_b = sub.add_parser("benchmarks", help="Diff CoreMark & Embench-IoT benchmark reports.")
    p_b.add_argument("--base-dir", default="", help="Base branch benchmark reports directory.")
    p_b.add_argument("--pr-dir", required=True, help="PR/current benchmark reports directory.")
    p_b.add_argument("--out-dir", required=True, help="Output directory for per-report .md files.")
    p_b.set_defaults(func=cmd_benchmarks)

    p_agg = sub.add_parser("aggregate", help="Aggregate per-config diff directories into one report.")
    p_agg.add_argument("--artifacts-dir", default="metrics-diff", help="Directory containing per-config diff dirs.")
    p_agg.add_argument("--output", default="comparison.md", help="Combined Markdown output path.")
    p_agg.add_argument("--base-label", default="main branch", help="Label for baseline in footer.")
    p_agg.add_argument("--head-label", default="this PR", help="Label for compared version in footer.")
    p_agg.set_defaults(func=cmd_aggregate)

    return p


def main(argv: Optional[List[str]] = None) -> None:
    parser = build_arg_parser()
    args = parser.parse_args(argv)
    args.func(args)


if __name__ == "__main__":
    main()
