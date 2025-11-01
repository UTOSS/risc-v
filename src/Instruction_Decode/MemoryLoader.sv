module MemoryLoader
  ( input  data_t memory_data
  , input  addr_t memory_address
  , input  logic [2:0]  funct3
  , output data_t mem_load_result
  );

    integer byteindex;
    assign byteindex = memory_address[1:0];

    always_comb
        case (funct3)
            3'b000: // lb
                case (byteindex)
                    2'd0: mem_load_result = {{24{memory_data[7]}} , memory_data[7:0]};
                    2'd1: mem_load_result = {{24{memory_data[15]}}, memory_data[15:8]};
                    2'd2: mem_load_result = {{24{memory_data[23]}}, memory_data[23:16]};
                    2'd3: mem_load_result = {{24{memory_data[31]}}, memory_data[31:24]};
                    default: mem_load_result = 32'hX;
                endcase

            3'b001: // lh
                case (byteindex)
                    2'd0: mem_load_result = {{16{memory_data[15]}}, memory_data[15:0]};
                    2'd1: mem_load_result = {{16{memory_data[23]}}, memory_data[23:8]};
                    2'd2: mem_load_result = {{16{memory_data[31]}}, memory_data[31:16]};
                    default: mem_load_result = 32'hX;
                endcase

            3'b010: mem_load_result = memory_data; // lw

            3'b100: // lbu
                case (byteindex)
                    2'd0: mem_load_result = {24'b0, memory_data[7:0]};
                    2'd1: mem_load_result = {24'b0, memory_data[15:8]};
                    2'd2: mem_load_result = {24'b0, memory_data[23:16]};
                    2'd3: mem_load_result = {24'b0, memory_data[31:24]};
                    default: mem_load_result = 32'hX;
                endcase

            3'b101: // lhu
                case (byteindex)
                    2'd0: mem_load_result = {16'b0, memory_data[15:0]};
                    2'd1: mem_load_result = {16'b0, memory_data[23:8]};
                    2'd2: mem_load_result = {16'b0, memory_data[31:16]};
                    default: mem_load_result = 32'hX;
                endcase

            default: mem_load_result = 32'hX;
        endcase

endmodule
