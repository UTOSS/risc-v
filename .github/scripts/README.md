# GitHub Actions Scripts

This directory contains scripts used by GitHub Actions workflows.

## fpga_metrics_comment/

Scripts for the `fpga_metrics_comment` CI job that compares FPGA synthesis metrics between the main branch and pull requests.

### Active Scripts

- **`compare_metrics_diff.sh`** - Generates a diff-based comparison report of Quartus synthesis results
- **`post_comment.js`** - Posts/updates PR comments with the comparison report

### Legacy Scripts (for future enhancement)

- **`compare_fpga_metrics.py`** - Semantic parsing of synthesis metrics (not currently used)
- **`compare_metrics.sh`** - Old comparison script (replaced by `compare_metrics_diff.sh`)

## How It Works

1. The CI runs synthesis on the PR branch and uploads `.fit.summary` and `.sta.summary` files as artifacts
2. The workflow downloads artifacts from the latest main branch synthesis
3. `compare_metrics_diff.sh` generates a unified diff between the two versions
4. `post_comment.js` posts or updates a PR comment with the diff

## Example Output

```markdown
## 🔧 FPGA Synthesis Report

### 📊 Fitter Summary (.fit.summary)

```diff
@@ -5,7 +5,7 @@
 Family : Cyclone V
 Device : 5CSEMA5F31C6
-Total registers : 1255
+Total registers : 1300
```

### ⏱️ Timing Analysis Summary (.sta.summary)

*No changes detected*

---
*Comparing synthesis results from [main branch run](https://github.com/UTOSS/risc-v/actions/runs/12345) vs. this PR*
```

