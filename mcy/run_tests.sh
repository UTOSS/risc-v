#!/usr/bin/env bash
set -euo pipefail

bash "$SCRIPTS/create_mutated.sh"
root="$PRJDIR/.."


sed -nE 's/^[[:space:]]*module[[:space:]]+([^[:space:](;]+).*/\1/p' mutated.v > modules.txt
sources=()
while IFS= read -r file; do
    module=$(sed -nE 's/^[[:space:]]*module[[:space:]]+([^[:space:](;]+).*/\1/p' "$PRJDIR/$file")
    if ! grep -Fxq -- "$module" modules.txt; then
        sources+=("$PRJDIR/$file")
    fi
done < "$PRJDIR/database/setup/rtl_files.txt"

tests=("$root"/test/*_tb.sv)
if [[ -n "${1:-}" ]]; then
    read -r -a tests <<< "$1"
    for i in "${!tests[@]}"; do
        tests[i]="$root/${tests[i]}"
    done
fi
[[ -f "${tests[0]}" ]] || { echo 'No SystemVerilog testbenches found' >&2; exit 1; }
status=PASS
for file in "${tests[@]}"; do
    [[ -f "$file" ]] || { echo "Unknown testbench: $file" >&2; exit 1; }
    test=$(basename "$file" .sv)
    echo "Running $test"
    verilator --binary --timing --assert -sv -Wno-fatal -DTESTBENCH \
        -I"$root" --top-module "$test" --Mdir "obj_$test" \
        mutated.v "${sources[@]}" "$file"
    if ! timeout 60s "./obj_$test/V$test"; then
        echo "FAILED: $test"
        status=FAIL
    fi
done

if [[ "$status" == FAIL ]] && grep -Fq 'mutate -mode none' input.txt; then
    echo 'The unmodified design failed; fix the baseline before measuring coverage' >&2
    exit 1
fi
printf '1 %s\n' "$status" > output.txt
