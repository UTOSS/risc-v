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

`endif
