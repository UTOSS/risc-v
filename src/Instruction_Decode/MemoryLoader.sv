module MemoryLoader (
    input  logic [31:0] memory_data,
    input  logic [31:0] memory_address,
    input  logic [2:0]  funct3,
    output logic [31:0] mem_load_result
);

    logic [1:0] byteindex;
    assign byteindex = memory_address[1:0];

    always_comb begin
        case (funct3)
            3'b000: begin // lb
                case (byteindex)
                    2'd0: mem_load_result = {{24{memory_data[7]}},  memory_data[7:0]};
                    2'd1: mem_load_result = {{24{memory_data[15]}}, memory_data[15:8]};
                    2'd2: mem_load_result = {{24{memory_data[23]}}, memory_data[23:16]};
                    2'd3: mem_load_result = {{24{memory_data[31]}}, memory_data[31:24]};
                    default: mem_load_result = 32'hX;
                endcase
            end

            3'b001: begin // lh
                case (byteindex)
                    2'd0: mem_load_result = {{16{memory_data[15]}}, memory_data[15:0]};
                    2'd1: mem_load_result = {{16{memory_data[23]}}, memory_data[23:8]};
                    2'd2: mem_load_result = {{16{memory_data[31]}}, memory_data[31:16]};
                    default: mem_load_result = 32'hX;
                endcase
            end

            3'b010: mem_load_result = memory_data; // lw

            3'b100: begin // lbu
                case (byteindex)
                    2'd0: mem_load_result = {24'b0, memory_data[7:0]};
                    2'd1: mem_load_result = {24'b0, memory_data[15:8]};
                    2'd2: mem_load_result = {24'b0, memory_data[23:16]};
                    2'd3: mem_load_result = {24'b0, memory_data[31:24]};
                    default: mem_load_result = 32'hX;
                endcase
            end

            3'b101: begin // lhu
                case (byteindex)
                    2'd0: mem_load_result = {16'b0, memory_data[15:0]};
                    2'd1: mem_load_result = {16'b0, memory_data[23:8]};
                    2'd2: mem_load_result = {16'b0, memory_data[31:16]};
                    default: mem_load_result = 32'hX;
                endcase
            end

            default: mem_load_result = 32'hX;
        endcase
    end

endmodule
