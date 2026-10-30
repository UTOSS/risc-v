[options]
size M4__MCY_SIZE
ifelse(M4__MCY_SEED, `', `# Let MCY choose a random seed.', `seed M4__MCY_SEED')
tags COVERED UNCOVERED
# Only mutate modules from src/, excluding the simulation wrapper and memory.
select A:mcy_target=1

[setup]
set -e
# Find all RTL files
find ../src -type f \( -name '*.sv' -o -name '*.v' \) | sort > database/setup/rtl_files.txt

for file in ${MCY_FILES:-}; do
    grep -Fxq -- "../$file" database/setup/rtl_files.txt
done

# Mark selected source modules without changing their source filenames.
: > database/setup/targets.ys
while IFS= read -r file; do
    if [[ -z "${MCY_FILES:-}" || " $MCY_FILES " == *" ${file#../} "* ]]; then
        # Yosys treats literal slashes as selection separators; ? matches each slash.
        pattern=$(printf '%s' "$file" | tr '/' '?')
        printf 'setattr -mod -set mcy_target 1 A:src=%s:*\n' "$pattern" >> database/setup/targets.ys
    fi
done < database/setup/rtl_files.txt

[script]
plugin -i slang
read_slang -I.. --single-unit --keep-hierarchy -DTESTBENCH -DUTOSS_RISCV_HARDENING --top M4__MCY_TOP -f database/setup/rtl_files.txt ../envs/simulation/top.sv ../envs/simulation/memory.sv
script database/setup/targets.ys
# Tests access internal state; retain instances even though top has no outputs.
setattr -set keep 1 */c:*
prep -top M4__MCY_TOP

[files]
# add all source sv files
esyscmd(`find src -type f \( -name "*.sv" -o -name "*.v" -o -name "*.svh" \) | sort | sed "s|^|../|"')dnl
../envs/simulation/top.sv
../envs/simulation/memory.sv

[logic]
if result("regression") == "FAIL":
    tag("COVERED")
else:
    tag("UNCOVERED")

[report]
if tags("COVERED") + tags("UNCOVERED"):
    print("Coverage: %.2f%%" % (100.0 * tags("COVERED") / (tags("COVERED") + tags("UNCOVERED"))))

[test regression]
expect PASS FAIL
run bash "$PRJDIR/run_tests.sh" "M4__MCY_TESTS"
