#!/usr/bin/env python3
"""
Script to compare FPGA synthesis metrics between two builds.
Parses Quartus .fit.summary and .sta.summary files and generates a comparison report.
"""

import sys
import os
import re
from pathlib import Path


def parse_fit_summary(file_path):
    """
    Parse a Quartus .fit.summary file to extract resource usage information.
    
    Returns a dictionary with resource metrics.
    """
    metrics = {}
    
    if not os.path.exists(file_path):
        return None
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Parse various resource metrics
    # Example patterns from Quartus .fit.summary files
    patterns = {
        'logic_elements': r'Logic elements\s*;\s*([\d,]+)',
        'alm': r'ALM needed\s*\[[^\]]+\]\s*;\s*([\d,]+)',
        'registers': r'Dedicated logic registers\s*;\s*([\d,]+)',
        'memory_bits': r'Total block memory bits\s*;\s*([\d,]+)',
        'dsp_blocks': r'DSP block 9-bit elements\s*;\s*([\d,]+)',
        'pins': r'Total pins\s*;\s*([\d,]+)',
        'plls': r'Total PLLs\s*;\s*([\d,]+)',
    }
    
    for key, pattern in patterns.items():
        match = re.search(pattern, content, re.IGNORECASE)
        if match:
            # Remove commas from numbers
            value_str = match.group(1).replace(',', '')
            try:
                metrics[key] = int(value_str)
            except ValueError:
                metrics[key] = value_str
    
    return metrics


def parse_sta_summary(file_path):
    """
    Parse a Quartus .sta.summary file to extract timing information.
    
    Returns a dictionary with timing metrics.
    """
    metrics = {}
    
    if not os.path.exists(file_path):
        return None
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Parse timing metrics
    # Example patterns from Quartus .sta.summary files
    patterns = {
        'setup_slack': r'Slow 1200mV 85C Model Setup.*?Slack\s*;\s*([-\d.]+)',
        'hold_slack': r'Slow 1200mV 85C Model Hold.*?Slack\s*;\s*([-\d.]+)',
        'recovery_slack': r'Slow 1200mV 85C Model Recovery.*?Slack\s*;\s*([-\d.]+)',
        'removal_slack': r'Slow 1200mV 85C Model Removal.*?Slack\s*;\s*([-\d.]+)',
        'fmax': r'Slow 1200mV 85C Model Fmax.*?;\s*([\d.]+)',
    }
    
    for key, pattern in patterns.items():
        match = re.search(pattern, content, re.IGNORECASE | re.DOTALL)
        if match:
            try:
                metrics[key] = float(match.group(1))
            except ValueError:
                metrics[key] = match.group(1)
    
    return metrics


def format_number_with_sign(value, decimals=2):
    """Format a number with a + or - sign for differences."""
    if value > 0:
        if isinstance(value, int):
            return f"+{value:,}"
        else:
            return f"+{value:.{decimals}f}"
    elif value < 0:
        if isinstance(value, int):
            return f"{value:,}"
        else:
            return f"{value:.{decimals}f}"
    else:
        return "0"


def format_number(value, decimals=2):
    """Format a number for display."""
    if isinstance(value, int):
        return f"{value:,}"
    else:
        return f"{value:.{decimals}f}"


def calculate_diff(base_metrics, pr_metrics):
    """Calculate the difference between base and PR metrics."""
    diff = {}
    
    if base_metrics is None or pr_metrics is None:
        return None
    
    all_keys = set(base_metrics.keys()) | set(pr_metrics.keys())
    
    for key in all_keys:
        base_val = base_metrics.get(key, 0)
        pr_val = pr_metrics.get(key, 0)
        
        # Only calculate diff for numeric values
        if isinstance(base_val, (int, float)) and isinstance(pr_val, (int, float)):
            diff[key] = pr_val - base_val
        else:
            diff[key] = None
    
    return diff


def generate_markdown_report(base_fit, pr_fit, base_sta, pr_sta):
    """Generate a markdown report comparing the metrics."""
    
    lines = []
    lines.append("## 🔧 FPGA Resource Usage and Timing Report")
    lines.append("")
    
    # Resource usage section
    if base_fit and pr_fit:
        fit_diff = calculate_diff(base_fit, pr_fit)
        
        lines.append("### 📊 Resource Usage")
        lines.append("")
        lines.append("| Resource | Base (main) | PR | Change |")
        lines.append("|----------|-------------|-----|--------|")
        
        # Define the order and display names for resources
        resource_order = [
            ('logic_elements', 'Logic Elements'),
            ('alm', 'ALMs'),
            ('registers', 'Registers'),
            ('memory_bits', 'Memory Bits'),
            ('dsp_blocks', 'DSP Blocks'),
            ('pins', 'Pins'),
            ('plls', 'PLLs'),
        ]
        
        for key, display_name in resource_order:
            if key in base_fit or key in pr_fit:
                base_val = base_fit.get(key, 'N/A')
                pr_val = pr_fit.get(key, 'N/A')
                
                if fit_diff and key in fit_diff and fit_diff[key] is not None:
                    diff_val = fit_diff[key]
                    if diff_val == 0:
                        change_str = "—"
                    else:
                        change_str = format_number_with_sign(diff_val)
                        # Add visual indicators
                        if diff_val > 0:
                            change_str += " 📈"
                        else:
                            change_str += " 📉"
                else:
                    change_str = "—"
                
                base_str = format_number(base_val) if isinstance(base_val, (int, float)) else base_val
                pr_str = format_number(pr_val) if isinstance(pr_val, (int, float)) else pr_val
                
                lines.append(f"| {display_name} | {base_str} | {pr_str} | {change_str} |")
        
        lines.append("")
    elif pr_fit:
        lines.append("### 📊 Resource Usage")
        lines.append("")
        lines.append("*No baseline data available from main branch for comparison.*")
        lines.append("")
        lines.append("| Resource | PR |")
        lines.append("|----------|-----|")
        
        resource_order = [
            ('logic_elements', 'Logic Elements'),
            ('alm', 'ALMs'),
            ('registers', 'Registers'),
            ('memory_bits', 'Memory Bits'),
            ('dsp_blocks', 'DSP Blocks'),
            ('pins', 'Pins'),
            ('plls', 'PLLs'),
        ]
        
        for key, display_name in resource_order:
            if key in pr_fit:
                pr_val = pr_fit[key]
                pr_str = format_number(pr_val) if isinstance(pr_val, (int, float)) else pr_val
                lines.append(f"| {display_name} | {pr_str} |")
        
        lines.append("")
    
    # Timing section
    if base_sta and pr_sta:
        sta_diff = calculate_diff(base_sta, pr_sta)
        
        lines.append("### ⏱️ Timing Analysis")
        lines.append("")
        lines.append("| Metric | Base (main) | PR | Change |")
        lines.append("|--------|-------------|-----|--------|")
        
        timing_order = [
            ('setup_slack', 'Setup Slack (ns)'),
            ('hold_slack', 'Hold Slack (ns)'),
            ('recovery_slack', 'Recovery Slack (ns)'),
            ('removal_slack', 'Removal Slack (ns)'),
            ('fmax', 'Fmax (MHz)'),
        ]
        
        for key, display_name in timing_order:
            if key in base_sta or key in pr_sta:
                base_val = base_sta.get(key, 'N/A')
                pr_val = pr_sta.get(key, 'N/A')
                
                if sta_diff and key in sta_diff and sta_diff[key] is not None:
                    diff_val = sta_diff[key]
                    if diff_val == 0:
                        change_str = "—"
                    else:
                        change_str = format_number_with_sign(diff_val, decimals=3)
                        # For timing, positive slack change is good, negative is bad
                        # For Fmax, positive is good
                        if 'slack' in key:
                            if diff_val > 0:
                                change_str += " ✅"
                            elif diff_val < 0:
                                change_str += " ⚠️"
                        elif key == 'fmax':
                            if diff_val > 0:
                                change_str += " ✅"
                            elif diff_val < 0:
                                change_str += " ⚠️"
                else:
                    change_str = "—"
                
                base_str = format_number(base_val, decimals=3) if isinstance(base_val, (int, float)) else base_val
                pr_str = format_number(pr_val, decimals=3) if isinstance(pr_val, (int, float)) else pr_val
                
                lines.append(f"| {display_name} | {base_str} | {pr_str} | {change_str} |")
        
        lines.append("")
    elif pr_sta:
        lines.append("### ⏱️ Timing Analysis")
        lines.append("")
        lines.append("*No baseline data available from main branch for comparison.*")
        lines.append("")
        lines.append("| Metric | PR |")
        lines.append("|--------|-----|")
        
        timing_order = [
            ('setup_slack', 'Setup Slack (ns)'),
            ('hold_slack', 'Hold Slack (ns)'),
            ('recovery_slack', 'Recovery Slack (ns)'),
            ('removal_slack', 'Removal Slack (ns)'),
            ('fmax', 'Fmax (MHz)'),
        ]
        
        for key, display_name in timing_order:
            if key in pr_sta:
                pr_val = pr_sta[key]
                pr_str = format_number(pr_val, decimals=3) if isinstance(pr_val, (int, float)) else pr_val
                lines.append(f"| {display_name} | {pr_str} |")
        
        lines.append("")
    
    lines.append("---")
    lines.append("*This report compares FPGA synthesis results between the main branch and this PR.*")
    
    return "\n".join(lines)


def main():
    if len(sys.argv) != 5:
        print("Usage: compare_fpga_metrics.py <base_fit> <pr_fit> <base_sta> <pr_sta>")
        sys.exit(1)
    
    base_fit_path = sys.argv[1]
    pr_fit_path = sys.argv[2]
    base_sta_path = sys.argv[3]
    pr_sta_path = sys.argv[4]
    
    # Parse files
    base_fit = parse_fit_summary(base_fit_path) if base_fit_path != "none" else None
    pr_fit = parse_fit_summary(pr_fit_path) if pr_fit_path != "none" else None
    base_sta = parse_sta_summary(base_sta_path) if base_sta_path != "none" else None
    pr_sta = parse_sta_summary(pr_sta_path) if pr_sta_path != "none" else None
    
    # Generate report
    report = generate_markdown_report(base_fit, pr_fit, base_sta, pr_sta)
    print(report)


if __name__ == "__main__":
    main()
