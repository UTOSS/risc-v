`timescale 1ns/1ps

interface core_uvm_if(input logic clk);
  logic reset;
  logic mem_load;
  logic rf_load;
  logic [31:0] mem_words [0:1023];
  logic [31:0] rf_seed [0:31];
  logic reg_write;
  logic [4:0] reg_addr;
  logic [31:0] reg_data;
  logic [31:0] dmem_address;
  logic [3:0] dmem_write_enable;
  logic [31:0] dmem_write_data;
  logic mepc_write_enable;
  logic [31:0] mepc_write_data;
  logic mcause_write_enable;
  logic [31:0] mcause_write_data;
  logic [1:0] pc_src;
  logic [31:0] mtvec_read_data;
  logic [31:0] pc_next;
  logic [31:0] sentinel;
endinterface


package ecall_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Full-core reusable event types and program transaction mirror PyUVM/core.
  typedef struct packed {
    logic [4:0] rd;
    logic [31:0] data;
  } register_write_t;

  typedef struct packed {
    logic [31:0] address;
    logic [3:0] mask;
    logic [31:0] data;
  } memory_write_t;

  typedef struct packed {
    logic epc_enable;
    logic [31:0] epc;
    logic cause_enable;
    logic [31:0] cause;
    logic [1:0] pc_src;
    logic [31:0] mtvec;
    logic [31:0] pc_next;
  } trap_event_t;

  class core_program_item extends uvm_sequence_item;
    bit [31:0] words[0:1023];
    bit [1023:0] word_valid;
    bit [31:0] seed_regs[0:31];
    bit [31:0] seed_valid;
    register_write_t expected_writes[0:4];
    trap_event_t expected_traps[0:0];
    int unsigned expected_write_count;
    int unsigned expected_trap_count;
    int unsigned completion_rd;
    bit [31:0] completion_data;
    int unsigned timeout_cycles;
    int unsigned drain_cycles;
    bit completed;
    int unsigned elapsed_cycles;
    bit [31:0] handler;
    bit [31:0] ecall_pc;
    int unsigned mode;

    `uvm_object_utils(core_program_item)
    function new(string name = "core_program_item");
      super.new(name);
      expected_write_count = 0;
      expected_trap_count = 0;
      completion_rd = 31;
      completion_data = 1;
      timeout_cycles = 160;
      drain_cycles = 12;
      completed = 0;
      elapsed_cycles = 0;
      word_valid = '0;
      seed_valid = '0;
    endfunction

    function void put_word(int unsigned index, bit [31:0] value);
      if (index >= 1024) `uvm_fatal("BAD_PROGRAM", "program word outside 1K memory")
      words[index] = value;
      word_valid[index] = 1'b1;
    endfunction

    function void add_expected_write(int unsigned rd, bit [31:0] data);
      expected_writes[expected_write_count].rd = rd[4:0];
      expected_writes[expected_write_count].data = data;
      expected_write_count++;
    endfunction

    function void add_seed_reg(int unsigned rd, bit [31:0] data);
      if (rd == 0 || rd >= 32) `uvm_fatal("BAD_SEED", "seed register must be x1..x31")
      seed_regs[rd] = data;
      seed_valid[rd] = 1'b1;
    endfunction
  endclass

  class core_program_sequencer extends uvm_sequencer #(core_program_item);
    `uvm_component_utils(core_program_sequencer)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass

  class core_program_sequence extends uvm_sequence #(core_program_item);
    `uvm_object_utils(core_program_sequence)
    core_program_item program_item;
    function new(string name = "core_program_sequence");
      super.new(name);
    endfunction
    task body();
      start_item(program_item);
      finish_item(program_item);
    endtask
  endclass

  class core_program_driver extends uvm_driver #(core_program_item);
    `uvm_component_utils(core_program_driver)
    virtual core_uvm_if vif;
    uvm_analysis_port #(core_program_item) ap;
    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual core_uvm_if)::get(this, "", "core_vif", vif))
        `uvm_fatal("NOVIF", "core_uvm_if was not configured")
    endfunction
    task run_phase(uvm_phase phase);
      core_program_item item;
      int remaining;
      forever begin
        seq_item_port.get_next_item(item);
        @(negedge vif.clk);
        vif.reset <= 1'b1;
        for (int i = 0; i < 1024; i++)
          vif.mem_words[i] <= item.word_valid[i] ? item.words[i] : 32'h0000_0013;
        for (int i = 0; i < 32; i++)
          vif.rf_seed[i] <= item.seed_valid[i] ? item.seed_regs[i] : 32'b0;
        vif.mem_load <= 1'b1;
        vif.rf_load <= 1'b0;
        @(negedge vif.clk);
        #1ps;
        vif.mem_load <= 1'b0;
        repeat (8) @(posedge vif.clk);
        @(negedge vif.clk);
        #1ps;
        vif.reset <= 1'b0;
        vif.rf_load <= 1'b1;
        @(negedge vif.clk);
        #1ps;
        vif.rf_load <= 1'b0;
        ap.write(item);

        remaining = -1;
        for (int cycle = 0; cycle < item.timeout_cycles + item.drain_cycles; cycle++) begin
          @(negedge vif.clk);
          #1ps;
          item.elapsed_cycles = cycle + 1;
          if (remaining >= 0) begin
            remaining--;
            if (remaining == 0) break;
          end else if (vif.reg_write && vif.reg_addr == item.completion_rd &&
                       vif.reg_data == item.completion_data) begin
            item.completed = 1'b1;
            remaining = item.drain_cycles;
          end else if (cycle + 1 >= item.timeout_cycles) begin
            break;
          end
        end
        #1ns;
        seq_item_port.item_done();
      end
    endtask
  endclass

  class register_write_monitor extends uvm_monitor;
    `uvm_component_utils(register_write_monitor)
    virtual core_uvm_if vif;
    uvm_analysis_port #(register_write_t) ap;
    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual core_uvm_if)::get(this, "", "core_vif", vif))
        `uvm_fatal("NOVIF", "core_uvm_if was not configured")
    endfunction
    task run_phase(uvm_phase phase);
      register_write_t event_item;
      forever begin
        @(negedge vif.clk);
        #1ps;
        if (!vif.reset && vif.reg_write && vif.reg_addr != 0) begin
          event_item.rd = vif.reg_addr;
          event_item.data = vif.reg_data;
          ap.write(event_item);
        end
      end
    endtask
  endclass

  class memory_write_monitor extends uvm_monitor;
    `uvm_component_utils(memory_write_monitor)
    virtual core_uvm_if vif;
    uvm_analysis_port #(memory_write_t) ap;
    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual core_uvm_if)::get(this, "", "core_vif", vif))
        `uvm_fatal("NOVIF", "core_uvm_if was not configured")
    endfunction
    task run_phase(uvm_phase phase);
      memory_write_t event_item;
      forever begin
        @(negedge vif.clk);
        #1ps;
        if (!vif.reset && vif.dmem_write_enable != 0) begin
          event_item.address = vif.dmem_address;
          event_item.mask = vif.dmem_write_enable;
          event_item.data = vif.dmem_write_data;
          ap.write(event_item);
        end
      end
    endtask
  endclass

  class trap_monitor extends uvm_monitor;
    `uvm_component_utils(trap_monitor)
    virtual core_uvm_if vif;
    uvm_analysis_port #(trap_event_t) ap;
    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual core_uvm_if)::get(this, "", "core_vif", vif))
        `uvm_fatal("NOVIF", "core_uvm_if was not configured")
    endfunction
    task run_phase(uvm_phase phase);
      trap_event_t event_item;
      forever begin
        @(negedge vif.clk);
        #1ps;
        if (!vif.reset && (vif.mepc_write_enable || vif.mcause_write_enable || vif.pc_src == 2)) begin
          event_item.epc_enable = vif.mepc_write_enable;
          event_item.epc = vif.mepc_write_data;
          event_item.cause_enable = vif.mcause_write_enable;
          event_item.cause = vif.mcause_write_data;
          event_item.pc_src = vif.pc_src;
          event_item.mtvec = vif.mtvec_read_data;
          event_item.pc_next = vif.pc_next;
          ap.write(event_item);
        end
      end
    endtask
  endclass

  class ecall_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(ecall_scoreboard)
    uvm_tlm_analysis_fifo #(core_program_item) program_fifo;
    uvm_tlm_analysis_fifo #(register_write_t) writes_fifo;
    uvm_tlm_analysis_fifo #(memory_write_t) stores_fifo;
    uvm_tlm_analysis_fifo #(trap_event_t) traps_fifo;
    virtual core_uvm_if vif;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      program_fifo = new("program", this);
      writes_fifo = new("writes", this);
      stores_fifo = new("stores", this);
      traps_fifo = new("traps", this);
      if (!uvm_config_db#(virtual core_uvm_if)::get(this, "", "core_vif", vif))
        `uvm_fatal("NOVIF", "core_uvm_if was not configured")
    endfunction
    function void check_phase(uvm_phase phase);
      core_program_item program_item;
      core_program_item extra_program;
      register_write_t wr;
      memory_write_t store;
      trap_event_t trap;
      int write_index = 0;
      int store_count = 0;
      int trap_index = 0;
      if (!program_fifo.try_get(program_item))
        `uvm_fatal("NO_PROGRAM", "program driver did not publish a program")
      if (program_fifo.try_get(extra_program))
        `uvm_fatal("PROGRAM_COUNT", "expected exactly one program")
      if (!program_item.completed)
        `uvm_error("TIMEOUT", $sformatf("completion timeout after %0d cycles; handler=%08h", program_item.elapsed_cycles, program_item.handler))
      while (writes_fifo.try_get(wr)) begin
        if (write_index >= program_item.expected_write_count)
          `uvm_error("EXTRA_WRITE", $sformatf("unexpected register write x%0d=%08h", wr.rd, wr.data))
        else if (wr !== program_item.expected_writes[write_index])
          `uvm_error("WRITE_MISMATCH", $sformatf("write %0d expected %p got %p", write_index, program_item.expected_writes[write_index], wr))
        write_index++;
      end
      if (write_index != program_item.expected_write_count)
        `uvm_error("MISSING_WRITE", $sformatf("expected %0d register writes, observed %0d", program_item.expected_write_count, write_index))
      while (stores_fifo.try_get(store)) begin
        store_count++;
        `uvm_error("STORE", $sformatf("unexpected store address=%08h mask=%x data=%08h", store.address, store.mask, store.data))
      end
      while (traps_fifo.try_get(trap)) begin
        if (trap_index >= program_item.expected_trap_count)
          `uvm_error("EXTRA_TRAP", $sformatf("unexpected trap event %p", trap))
        else if (trap !== program_item.expected_traps[trap_index])
          `uvm_error("TRAP_MISMATCH", $sformatf("trap %0d expected %p got %p", trap_index, program_item.expected_traps[trap_index], trap))
        trap_index++;
      end
      if (trap_index != program_item.expected_trap_count)
        `uvm_error("MISSING_TRAP", $sformatf("expected %0d trap events, observed %0d", program_item.expected_trap_count, trap_index))
      if (vif.sentinel !== 32'ha5a5_5a5a)
        `uvm_error("SENTINEL", $sformatf("wrong-path store changed sentinel to %08h", vif.sentinel))
      if (uvm_report_server::get_server().get_severity_count(UVM_ERROR) != 0)
        $fatal(1, "ECALL scoreboard failed; see UVM errors above");
      `uvm_info("ECALL_PASS", "program results, trap events, flush side effects and completion match", UVM_LOW)
    endfunction
  endclass

  class ecall_env extends uvm_env;
    `uvm_component_utils(ecall_env)
    core_program_sequencer sequencer;
    core_program_driver driver;
    register_write_monitor writes;
    memory_write_monitor stores;
    trap_monitor traps;
    ecall_scoreboard scoreboard;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sequencer = core_program_sequencer::type_id::create("sequencer", this);
      driver = core_program_driver::type_id::create("driver", this);
      writes = register_write_monitor::type_id::create("writes", this);
      stores = memory_write_monitor::type_id::create("stores", this);
      traps = trap_monitor::type_id::create("traps", this);
      scoreboard = ecall_scoreboard::type_id::create("scoreboard", this);
    endfunction
    function void connect_phase(uvm_phase phase);
      driver.seq_item_port.connect(sequencer.seq_item_export);
      driver.ap.connect(scoreboard.program_fifo.analysis_export);
      writes.ap.connect(scoreboard.writes_fifo.analysis_export);
      stores.ap.connect(scoreboard.stores_fifo.analysis_export);
      traps.ap.connect(scoreboard.traps_fifo.analysis_export);
    endfunction
  endclass

  class ecall_program_factory;
    static function bit [31:0] encode_addi(int rd, int rs1, int imm);
      return ((imm & 'hfff) << 20) | (rs1 << 15) | (rd << 7) | 'h13;
    endfunction
    static function bit [31:0] encode_csr(int address, int rd, int funct3, int rs1);
      return (address << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | 'h73;
    endfunction
    static function bit [31:0] encode_sw(int rs2, int rs1, int offset);
      bit [11:0] imm;
      imm = offset;
      return (imm[11:5] << 25) | (rs2 << 20) | (rs1 << 15) | (2 << 12) | (imm[4:0] << 7) | 'h23;
    endfunction
    static function bit [31:0] encode_jal(int rd, int offset);
      bit [20:0] imm;
      imm = offset;
      return (imm[20] << 31) | (imm[10:1] << 21) | (imm[11] << 20) |
             (imm[19:12] << 12) | (rd << 7) | 'h6f;
    endfunction

    static function core_program_item create(int mode, int padding = 8, bit [31:0] handler = 'h100);
      core_program_item p = core_program_item::type_id::create("program");
      bit [31:0] code[0:24];
      int n = 0;
      p.mode = mode;
      p.handler = handler;
      p.put_word('h300 / 4, 'ha5a5_5a5a);
      code[n++] = 'h0000_0013; code[n++] = 'h0000_0013; code[n++] = 'h0000_0013;
      code[n++] = encode_addi(1, 0, handler);
      code[n++] = encode_csr('h305, 0, 1, 1);
      repeat (padding) code[n++] = 'h0000_0013;
      code[n++] = encode_addi(5, 0, 'h55);
      p.ecall_pc = n * 4;
      p.add_expected_write(1, handler);
      p.add_expected_write(5, 'h55);
      case (mode)
        0: begin // ECALL trap
          code[n++] = 'h0000_0073;
          code[n++] = encode_sw(5, 0, 'h300);
          code[n++] = encode_addi(6, 0, 'h66);
          code[n++] = encode_csr('h341, 0, 1, 5);
          code[n++] = 'h0000_006f;
          p.expected_traps[0] = '{1'b1, p.ecall_pc, 1'b1, 32'd11, 2'd2, handler, handler};
          p.expected_trap_count = 1;
          p.add_expected_write(10, p.ecall_pc);
          p.add_expected_write(11, 11);
          p.add_expected_write(31, 1);
        end
        1: begin // Taken jump discards ECALL and following side effects
          code[n++] = encode_jal(0, 16);
          code[n++] = 'h0000_0073;
          code[n++] = encode_sw(5, 0, 'h300);
          code[n++] = encode_addi(6, 0, 'h66);
          code[n++] = encode_addi(31, 0, 1);
          code[n++] = 'h0000_006f;
          p.add_expected_write(31, 1);
        end
        2: begin // Legal CSR with an unimplemented address is not an ECALL
          code[n++] = encode_csr(0, 7, 2, 0);
          code[n++] = encode_addi(31, 0, 1);
          code[n++] = 'h0000_006f;
          p.add_expected_write(7, 0);
          p.add_expected_write(31, 1);
        end
        default: `uvm_fatal("BAD_MODE", "unsupported ECALL program mode")
      endcase
      if (n * 4 >= handler || handler >= 'h300 - 32)
        `uvm_fatal("BAD_HANDLER", "program/handler overlaps or handler overlaps sentinel")
      for (int i = 0; i < n; i++) p.put_word(i, code[i]);
      p.put_word(handler / 4 + 0, encode_csr('h341, 10, 2, 0));
      p.put_word(handler / 4 + 1, encode_csr('h342, 11, 2, 0));
      p.put_word(handler / 4 + 2, encode_addi(31, 0, 1));
      p.put_word(handler / 4 + 3, 'h0000_006f);
      return p;
    endfunction
  endclass

  class ecall_test_base extends uvm_test;
    `uvm_component_utils(ecall_test_base)
    ecall_env env;
    virtual core_uvm_if vif;
    int unsigned mode = 0;
    int unsigned padding = 8;
    bit [31:0] handler = 'h100;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual core_uvm_if)::get(this, "", "core_vif", vif))
        `uvm_fatal("NOVIF", "core_uvm_if was not configured")
      env = ecall_env::type_id::create("env", this);
    endfunction
    task run_phase(uvm_phase phase);
      core_program_item item;
      core_program_sequence seq;
      phase.raise_objection(this);
      vif.reset = 1'b1;
      repeat (2) @(posedge vif.clk);
      item = ecall_program_factory::create(mode, padding, handler);
      `uvm_info("ECALL_TEST", $sformatf("mode=%0d site=%08h handler=%08h", mode, item.ecall_pc, handler), UVM_LOW)
      seq = core_program_sequence::type_id::create("program_sequence");
      seq.program_item = item;
      seq.start(env.sequencer);
      phase.drop_objection(this);
    endtask
  endclass

  class ecall_smoke_test extends ecall_test_base;
    `uvm_component_utils(ecall_smoke_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
  endclass

  class ecall_relocated_test extends ecall_test_base;
    `uvm_component_utils(ecall_relocated_test)
    function new(string name, uvm_component parent); super.new(name, parent); padding = 13; handler = 'h180; endfunction
  endclass

  class ecall_wrong_path_test extends ecall_test_base;
    `uvm_component_utils(ecall_wrong_path_test)
    function new(string name, uvm_component parent); super.new(name, parent); mode = 1; endfunction
  endclass

  class ecall_decode_negative_test extends ecall_test_base;
    `uvm_component_utils(ecall_decode_negative_test)
    function new(string name, uvm_component parent); super.new(name, parent); mode = 2; endfunction
  endclass
endpackage

module core_uvm_top;
  import uvm_pkg::*;
  import ecall_uvm_pkg::*;
  logic clk = 1'b0;
  always #5ns clk = ~clk;
  core_uvm_if core_bus(clk);
  top core_dut (.clk(clk), .reset(core_bus.reset));
  assign core_bus.reg_write = core_dut.core.u_decode_stage.RegFile.regWrite;
  assign core_bus.reg_addr = core_dut.core.u_decode_stage.RegFile.Addr3;
  assign core_bus.reg_data = core_dut.core.u_decode_stage.RegFile.dataIn;
  assign core_bus.dmem_address = core_dut.d_bus.address;
  assign core_bus.dmem_write_enable = core_dut.d_bus.write_enable;
  assign core_bus.dmem_write_data = core_dut.d_bus.write_data;
  assign core_bus.mepc_write_enable = core_dut.core.mepc_hw_request.write_enable;
  assign core_bus.mepc_write_data = core_dut.core.mepc_hw_request.write_data;
  assign core_bus.mcause_write_enable = core_dut.core.mcause_hw_request.write_enable;
  assign core_bus.mcause_write_data = core_dut.core.mcause_hw_request.write_data;
  assign core_bus.pc_src = core_dut.core.u_execute_stage.pc_src;
  assign core_bus.mtvec_read_data = core_dut.core.mtvec_hw_request.read_data;
  assign core_bus.pc_next = core_dut.core.u_fetch_stage.pc_next;
  assign core_bus.sentinel = core_dut.u_memory.M['h300 / 4];
  always @(negedge clk) begin
    if (core_bus.mem_load)
      for (int i = 0; i < 1024; i++) core_dut.u_memory.M[i] = core_bus.mem_words[i];
    if (core_bus.rf_load)
      for (int i = 1; i < 32; i++) core_dut.core.u_decode_stage.RegFile.RFMem[i] = core_bus.rf_seed[i];
  end
  initial begin
    core_bus.reset = 1'b1;
    core_bus.mem_load = 1'b0;
    core_bus.rf_load = 1'b0;
    uvm_config_db#(virtual core_uvm_if)::set(null, "*", "core_vif", core_bus);
    run_test();
  end
endmodule
