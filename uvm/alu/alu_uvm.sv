`timescale 1ns/1ps

interface alu_if(input logic clk);
  logic [31:0] a;
  logic [31:0] b;
  logic [3:0] control;
  logic [31:0] result;
  logic zero;
  logic valid;
endinterface


package alu_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  class alu_item extends uvm_sequence_item;
    rand bit [31:0] a;
    rand bit [31:0] b;
    rand bit [3:0] control;
    bit [31:0] result;
    bit zero;

    `uvm_object_utils(alu_item)

    function new(string name = "alu_item");
      super.new(name);
    endfunction
  endclass

  class alu_sequencer extends uvm_sequencer #(alu_item);
    `uvm_component_utils(alu_sequencer)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass

  class alu_smoke_sequence extends uvm_sequence #(alu_item);
    `uvm_object_utils(alu_smoke_sequence)
    function new(string name = "alu_smoke_sequence");
      super.new(name);
    endfunction

    task send(bit [31:0] a, bit [31:0] b, bit [3:0] control);
      alu_item item = alu_item::type_id::create("item");
      start_item(item);
      item.a = a;
      item.b = b;
      item.control = control;
      finish_item(item);
    endtask

    task body();
      // Controls: ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND.
      for (int unsigned op = 0; op < 10; op++)
        send(32'h0, 32'h0, op[3:0]);
      send(32'hffff_ffff, 32'h1, 4'h0);
      send(32'h8000_0000, 32'h1, 4'h1);
      send(32'h8000_0000, 32'h1, 4'h7);
      send(32'h8000_0000, 32'h1, 4'h3);
      send(32'hffff_ffff, 32'h1, 4'h4);
      send(32'h1234_5678, 32'h4, 4'h2);
      send(32'h8000_0000, 32'h4, 4'h6);
    endtask
  endclass

  class alu_driver extends uvm_driver #(alu_item);
    `uvm_component_utils(alu_driver)
    virtual alu_if vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual alu_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "alu_if was not configured")
    endfunction

    task run_phase(uvm_phase phase);
      alu_item req;
      vif.valid <= 1'b0;
      forever begin
        seq_item_port.get_next_item(req);
        @(negedge vif.clk);
        vif.a <= req.a;
        vif.b <= req.b;
        vif.control <= req.control;
        vif.valid <= 1'b1;
        @(posedge vif.clk);
        seq_item_port.item_done();
      end
    endtask
  endclass

  class alu_monitor extends uvm_monitor;
    `uvm_component_utils(alu_monitor)
    virtual alu_if vif;
    uvm_analysis_port #(alu_item) ap;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual alu_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "alu_if was not configured")
    endfunction

    task run_phase(uvm_phase phase);
      alu_item observed;
      forever begin
        @(posedge vif.clk);
        #1ps;
        if (vif.valid) begin
          observed = alu_item::type_id::create("observed");
          observed.a = vif.a;
          observed.b = vif.b;
          observed.control = vif.control;
          observed.result = vif.result;
          observed.zero = vif.zero;
          ap.write(observed);
        end
      end
    endtask
  endclass

  class alu_scoreboard extends uvm_subscriber #(alu_item);
    `uvm_component_utils(alu_scoreboard)
    int unsigned checked;
    int unsigned errors;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      checked = 0;
      errors = 0;
    endfunction

    function bit [31:0] predict(alu_item item);
      case (item.control)
        4'h0: return item.a + item.b;
        4'h1: return item.a - item.b;
        4'h2: return item.a << item.b[4:0];
        4'h3: return ($signed(item.a) < $signed(item.b)) ? 32'd1 : 32'd0;
        4'h4: return (item.a < item.b) ? 32'd1 : 32'd0;
        4'h5: return item.a ^ item.b;
        4'h6: return item.a >> item.b[4:0];
        4'h7: return $signed(item.a) >>> item.b[4:0];
        4'h8: return item.a | item.b;
        4'h9: return item.a & item.b;
        default: return 32'd0;
      endcase
    endfunction

    function void write(alu_item item);
      bit [31:0] expected;
      expected = predict(item);
      checked++;
      if (item.result !== expected) begin
        errors++;
        `uvm_error("ALU_MISMATCH", $sformatf("op=%0h a=%08h b=%08h expected=%08h got=%08h", item.control, item.a, item.b, expected, item.result))
      end
      if (item.zero !== (expected == 0)) begin
        errors++;
        `uvm_error("ZERO_MISMATCH", $sformatf("expected zero=%0b got=%0b", (expected == 0), item.zero))
      end
    endfunction

    function void check_phase(uvm_phase phase);
      if (errors != 0) $fatal(1, "ALU scoreboard found %0d mismatch(es)", errors);
    endfunction
  endclass

  class alu_coverage extends uvm_subscriber #(alu_item);
    `uvm_component_utils(alu_coverage)
    int unsigned control_bins[10];
    int unsigned zero_cases;
    int unsigned nonzero_cases;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      foreach (control_bins[i]) control_bins[i] = 0;
      zero_cases = 0;
      nonzero_cases = 0;
    endfunction

    function void write(alu_item item);
      if (item.control < 10) control_bins[item.control]++;
      if (item.result == 0) zero_cases++;
      else nonzero_cases++;
    endfunction
  endclass

  class alu_agent extends uvm_agent;
    `uvm_component_utils(alu_agent)
    alu_sequencer sequencer;
    alu_driver driver;
    alu_monitor monitor;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sequencer = alu_sequencer::type_id::create("sequencer", this);
      driver = alu_driver::type_id::create("driver", this);
      monitor = alu_monitor::type_id::create("monitor", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
  endclass

  class alu_env extends uvm_env;
    `uvm_component_utils(alu_env)
    alu_agent agent;
    alu_scoreboard scoreboard;
    alu_coverage coverage;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agent = alu_agent::type_id::create("agent", this);
      scoreboard = alu_scoreboard::type_id::create("scoreboard", this);
      coverage = alu_coverage::type_id::create("coverage", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      agent.monitor.ap.connect(scoreboard.analysis_export);
      agent.monitor.ap.connect(coverage.analysis_export);
    endfunction
  endclass

  class alu_smoke_test extends uvm_test;
    `uvm_component_utils(alu_smoke_test)
    alu_env env;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = alu_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
      alu_smoke_sequence seq;
      phase.raise_objection(this);
      seq = alu_smoke_sequence::type_id::create("seq");
      seq.start(env.agent.sequencer);
      #1ns;
      if (env.scoreboard.checked != 17)
        `uvm_fatal("COUNT", $sformatf("expected 17 ALU samples, checked %0d", env.scoreboard.checked))
      phase.drop_objection(this);
    endtask
  endclass


endpackage

module alu_uvm_top;
  import uvm_pkg::*;
  import alu_uvm_pkg::*;
  logic clk = 1'b0;
  always #5ns clk = ~clk;
  alu_if bus(clk);
  ALU dut (
    .a(bus.a), .b(bus.b), .alu_control(bus.control),
    .out(bus.result), .zeroE(bus.zero)
  );
  initial begin
    bus.a = '0; bus.b = '0; bus.control = '0; bus.valid = 1'b0;
    uvm_config_db#(virtual alu_if)::set(null, "*", "vif", bus);
    run_test();
  end
endmodule
