/* verilator lint_off TIMESCALEMOD */
`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/interfaces/mem_bus.svh"

module embench_tb
  #( parameter int unsigned MEM_WORDS = 262144 // 1 MB (power of 2)
   , parameter addr_t       BOOT_ADDR = 32'h0000_0000
   );

  localparam int unsigned SIZE_W = $clog2(MEM_WORDS);

  localparam addr_t MMIO_BASE       = 32'h1000_0000;
  localparam addr_t MMIO_PUTCHAR    = 32'h1000_0000;
  localparam addr_t MMIO_BENCH_CTRL = 32'h1000_0004;
  localparam addr_t MMIO_EXIT       = 32'h1000_0008;
  localparam addr_t MMIO_CYCLE_LO   = 32'h1000_0010;
  localparam addr_t MMIO_CYCLE_HI   = 32'h1000_0014;
  localparam addr_t MMIO_INSTRET_LO = 32'h1000_0018;
  localparam addr_t MMIO_INSTRET_HI = 32'h1000_001C;

  logic clk;
  logic reset;

  mem_bus i_bus();
  mem_bus d_bus();

  /* verilator lint_off UNUSEDSIGNAL */
  wire unused_ibus = &{1'b0, i_bus.write_data, i_bus.write_enable};
  /* verilator lint_on UNUSEDSIGNAL */

  utoss_riscv
    #( .BOOT_ADDR ( BOOT_ADDR ) )
    uut
    ( .clk   ( clk            )
    , .reset ( reset          )
    , .i_bus ( i_bus.consumer )
    , .d_bus ( d_bus.consumer )
    );

  // Dual-port synchronous RAM (matching envs/simulation/memory.sv timing)
  reg [31:0] M [0:MEM_WORDS - 1];

  addr_t i_base_addr;
  addr_t d_base_addr;
  logic  d_is_mmio;

  assign i_base_addr = i_bus.address - BOOT_ADDR;
  assign d_base_addr = d_bus.address - BOOT_ADDR;
  assign d_is_mmio   = (d_bus.address[31:16] == MMIO_BASE[31:16]);

  /* verilator lint_off UNUSEDSIGNAL */
  wire unused_addr = &{ 1'b0
                      , i_base_addr[31:SIZE_W + 2], i_base_addr[1:0]
                      , d_base_addr[31:SIZE_W + 2], d_base_addr[1:0]
                      };
  /* verilator lint_on UNUSEDSIGNAL */

  // Global & timed-region performance counters
  longint unsigned total_cycles;
  longint unsigned total_instret;

  logic            bench_active;
  longint unsigned bench_cycles;
  longint unsigned bench_instret;
  longint unsigned bench_stall_cycles;
  longint unsigned bench_flush_cycles;

  logic            sim_done;
  int              sim_exit_code;

  // Every valid non-bubble instruction reaching WB has pc_plus_4 != 0
  // (all reset/flush/stall bubbles zero the pipeline register).
  wire instr_retired = (uut.mem_to_wb_reg.pc_plus_4 != 32'h0000_0000);
  wire any_stall     = uut.stall_f || uut.stall_d || uut.stall_e;
  wire any_flush     = uut.flush_d || uut.flush_e;

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  // Synchronous instruction/data memory + MMIO
  always @(posedge clk) begin
    i_bus.read_data <= M[i_base_addr[SIZE_W + 1:2]];

    if (d_is_mmio) begin
      case (d_bus.address)
        MMIO_CYCLE_LO:   d_bus.read_data <= total_cycles[31:0];
        MMIO_CYCLE_HI:   d_bus.read_data <= total_cycles[63:32];
        MMIO_INSTRET_LO: d_bus.read_data <= total_instret[31:0];
        MMIO_INSTRET_HI: d_bus.read_data <= total_instret[63:32];
        default:         d_bus.read_data <= 32'h0000_0000;
      endcase
    end else begin
      d_bus.read_data <= M[d_base_addr[SIZE_W + 1:2]];
      if (d_bus.write_enable[0]) M[d_base_addr[SIZE_W + 1:2]][ 7: 0] <= d_bus.write_data[ 7: 0];
      if (d_bus.write_enable[1]) M[d_base_addr[SIZE_W + 1:2]][15: 8] <= d_bus.write_data[15: 8];
      if (d_bus.write_enable[2]) M[d_base_addr[SIZE_W + 1:2]][23:16] <= d_bus.write_data[23:16];
      if (d_bus.write_enable[3]) M[d_base_addr[SIZE_W + 1:2]][31:24] <= d_bus.write_data[31:24];
    end
  end

  // Performance counters and MMIO write side-effects
  always @(posedge clk) begin
    if (reset) begin
      total_cycles       <= 64'd0;
      total_instret      <= 64'd0;
      bench_active       <= 1'b0;
      bench_cycles       <= 64'd0;
      bench_instret      <= 64'd0;
      bench_stall_cycles <= 64'd0;
      bench_flush_cycles <= 64'd0;
      sim_done           <= 1'b0;
      sim_exit_code      <= 0;
    end else begin
      total_cycles <= total_cycles + 64'd1;
      if (instr_retired) begin
        total_instret <= total_instret + 64'd1;
      end

      if (bench_active) begin
        bench_cycles <= bench_cycles + 64'd1;
        if (instr_retired) begin
          bench_instret <= bench_instret + 64'd1;
        end
        if (any_stall) begin
          bench_stall_cycles <= bench_stall_cycles + 64'd1;
        end else if (any_flush) begin
          bench_flush_cycles <= bench_flush_cycles + 64'd1;
        end
      end

      if (d_is_mmio && (|d_bus.write_enable)) begin
        case (d_bus.address)
          MMIO_PUTCHAR: begin
            $write("%c", d_bus.write_data[7:0]);
            $fflush();
          end
          MMIO_BENCH_CTRL: begin
            if (d_bus.write_data != 32'd0) begin
              bench_active       <= 1'b1;
              bench_cycles       <= 64'd0;
              bench_instret      <= 64'd0;
              bench_stall_cycles <= 64'd0;
              bench_flush_cycles <= 64'd0;
            end else begin
              bench_active <= 1'b0;
            end
          end
          MMIO_EXIT: begin
            sim_done      <= 1'b1;
            sim_exit_code <= int'(d_bus.write_data);
          end
          default: ;
        endcase
      end
    end
  end

  initial begin
    string           mem_file;
    string           vcd_path;
    string           bench_name;
    longint unsigned max_cycles;
    real             cpi;
    real             ipc;

    for (int i = 0; i < MEM_WORDS; i = i + 1) begin
      M[i] = 32'h0000_0000;
    end

    if (!$value$plusargs("MEM=%s", mem_file)) begin
      $fatal(1, "ERROR: +MEM=<path> plusarg is required.");
    end
    $readmemh(mem_file, M);

    if ($value$plusargs("VCD_PATH=%s", vcd_path)) begin
      $dumpfile(vcd_path);
      $dumpvars(0, embench_tb);
    end

    if (!$value$plusargs("MAX_CYCLES=%d", max_cycles)) begin
      max_cycles = 64'd200000000;
    end
    if (!$value$plusargs("BENCH=%s", bench_name)) begin
      bench_name = "unknown";
    end

    reset = 1'b1;
    @(posedge clk);
    #1;
    reset = 1'b0;

    while (!sim_done && (total_cycles < max_cycles)) begin
      @(posedge clk);
      #1;
    end

    if (!sim_done) begin
      $display("EMBENCH_RESULT bench=%s status=TIMEOUT cycles=%0d instret=%0d cpi=0.0000 ipc=0.0000 stall_cycles=%0d flush_cycles=%0d exit_code=-1",
               bench_name, bench_cycles, bench_instret, bench_stall_cycles, bench_flush_cycles);
      $fatal(1, "Embench benchmark '%s' timed out after %0d cycles.", bench_name, total_cycles);
    end

    cpi = (bench_instret > 0) ? (real'(bench_cycles) / real'(bench_instret)) : 0.0;
    ipc = (bench_cycles  > 0) ? (real'(bench_instret) / real'(bench_cycles)) : 0.0;

    $display("EMBENCH_RESULT bench=%s status=%s cycles=%0d instret=%0d cpi=%0.4f ipc=%0.4f stall_cycles=%0d flush_cycles=%0d exit_code=%0d",
             bench_name,
             (sim_exit_code == 0) ? "PASS" : "FAIL",
             bench_cycles,
             bench_instret,
             cpi,
             ipc,
             bench_stall_cycles,
             bench_flush_cycles,
             sim_exit_code);

    if (sim_exit_code != 0) begin
      $fatal(1, "Embench benchmark '%s' failed verification (exit_code=%0d).", bench_name, sim_exit_code);
    end

    $finish;
  end

endmodule
