`ifndef TEST__UTILS_SVH
`define TEST__UTILS_SVH

`define SETUP_VCD_DUMP(module_name)                                     \
  initial begin                                                         \
    string vcd_path;                                                    \
    string vcd_filename;                                                \
                                                                        \
    if ($test$plusargs("VCD_PATH")) begin                               \
      if ($value$plusargs("VCD_PATH=%s", vcd_path) == 0) begin          \
        $display("VCD_PATH not set, not dumping VCD");                  \
      end                                                               \
                                                                        \
      vcd_filename = $sformatf("%s/%s.vcd", vcd_path, `"module_name`"); \
                                                                        \
      $dumpfile(vcd_filename);                                          \
      $dumpvars(0, module_name);                                        \
    end                                                                 \
  end

// This needs to be on one line or the line number in the error message
// will be off by one.
`define assert_equal(actual, expected) assert (expected == actual) else $fatal(1, "Expected `%0h`, got `%0h`", expected, actual);

`include "src/headers/utils.svh"

`endif
