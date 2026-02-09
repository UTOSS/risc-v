# FPGA Metrics Comparison Script

This script compares FPGA synthesis metrics between two builds by parsing Quartus `.fit.summary` and `.sta.summary` files.

## Usage

```bash
./compare_fpga_metrics.py <base_fit> <pr_fit> <base_sta> <pr_sta>
```

Arguments:
- `base_fit`: Path to the base (main branch) `.fit.summary` file, or "none" if not available
- `pr_fit`: Path to the PR `.fit.summary` file
- `base_sta`: Path to the base (main branch) `.sta.summary` file, or "none" if not available
- `pr_sta`: Path to the PR `.sta.summary` file

## Output

The script outputs a markdown-formatted report comparing:

### Resource Usage
- Logic Elements
- ALMs (Adaptive Logic Modules)
- Registers
- Memory Bits
- DSP Blocks
- Pins
- PLLs (Phase-Locked Loops)

### Timing Analysis
- Setup Slack
- Hold Slack
- Recovery Slack
- Removal Slack
- Fmax (Maximum Frequency)

## Integration with CI

This script is automatically run by the GitHub Actions workflow when a pull request is created or updated. The workflow:

1. Runs synthesis on the PR branch
2. Downloads synthesis reports from the latest main branch build
3. Compares the metrics using this script
4. Posts a comment on the PR with the comparison results

## Example Output

```markdown
## 🔧 FPGA Resource Usage and Timing Report

### 📊 Resource Usage

| Resource | Base (main) | PR | Change |
|----------|-------------|-----|--------|
| Logic Elements | 2,468 | 2,578 | +110 📈 |
| ALMs | 1,234 | 1,289 | +55 📈 |
...

### ⏱️ Timing Analysis

| Metric | Base (main) | PR | Change |
|--------|-------------|-----|--------|
| Setup Slack (ns) | 0.234 | 0.189 | -0.045 ⚠️ |
...
```

Visual indicators:
- 📈 / 📉 : Resource usage increase/decrease
- ✅ : Timing improvement
- ⚠️ : Timing degradation
