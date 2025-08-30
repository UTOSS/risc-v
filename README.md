# risc-v
UTOSS' starter multicycle RISC-V core.

## Development

Put new modules into `src/` folder.

### Testbenches

It is important that new functionality is tested to a reasonable extent by using test benches. To
run all existing testbenches use `make run_tb`

To create a new test bench, if you are on Linux use the following command:
```
$ make new_tb name="something"
```

If you are on Windows, create a new testbench file in `test/` folder named `something_tb.sv` (the
`_tb.sv` suffix and extension are necessary for the test suite to recognize this file as a
testbench). Copy the content of `test/tb_template.sv.m4` into your newly-created testbench file and
start writing the test bench.

## Dev environment (onboarding)
New to the project? See [docs/DEV_ENV.md](docs/DEV_ENV.md) for Linux/macOS (Icarus),
Windows via WSL2, and native Windows (ModelSim-Intel, Vivado XSIM).

**Quick start (Icarus):**
```bash
sudo apt update && sudo apt install -y iverilog gtkwave make
./tools/icarus_run.sh test/<existing_tb>.sv
```

**Quick start (ModelSim-Intel):**
```bash
vsim -do scripts\msim_run.do TB=<tb_module>
```

**Quick start (Vivado XSIM):**
```bash
powershell -ExecutionPolicy Bypass -File scripts\xsim_run.ps1 -Tb <tb_module>
```
