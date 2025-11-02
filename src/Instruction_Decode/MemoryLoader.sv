`include "src/types.svh"

module MemoryLoader (
    input  data_t memory_data, 
    input  addr_t memory_address, 
    input  logic [2:0]  funct3, 
    input  logic [31:0] dataB, 
    output data_t mem_load_result, 
    output logic [3:0] MemWriteByteAddress, 
    output logic [31:0] __tmp_MemData
);

    integer byteindex;
    assign byteindex = memory_address[1:0];

    always_comb 
        case (funct3) 
            3'b000: begin // lb & sb
                case (byteindex)
                    2'd0: begin
                        mem_load_result = {{24{memory_data[7]}},  memory_data[7:0]};
                        MemWriteByteAddress = 4'b0001;
                        __tmp_MemData = {24'b0, dataB[7:0]};
                    end
                    2'd1: begin
                        mem_load_result = {{24{memory_data[15]}}, memory_data[15:8]};
                        MemWriteByteAddress = 4'b0010;
                        __tmp_MemData = {16'b0, dataB[7:0], 8'b0};
                    end
                    2'd2: begin
                        mem_load_result = {{24{memory_data[23]}}, memory_data[23:16]};
                        MemWriteByteAddress = 4'b0100;
                        __tmp_MemData = {8'b0, dataB[7:0], 16'b0};
                    end
                    2'd3: begin
                        mem_load_result = {{24{memory_data[31]}}, memory_data[31:24]};
                        MemWriteByteAddress = 4'b1000;
                        __tmp_MemData = {dataB[7:0], 24'b0};
                    end
                    default: begin
                        mem_load_result = 32'hX;
                        MemWriteByteAddress = 4'bx;
                        __tmp_MemData = 32'bx;
                    end
                endcase
            end

            3'b001: begin // lh & sh
                case (byteindex)
                    2'd0: begin
                        mem_load_result = {{16{memory_data[15]}}, memory_data[15:0]};
                        MemWriteByteAddress = 4'b0011;
                        __tmp_MemData = {16'b0, dataB[15:0]};
                    end
/*                    2'd1: begin
                        mem_load_result = {{16{memory_data[23]}}, memory_data[23:8]};
                        MemWriteByteAddress = 4'b0110;
                        __tmp_MemData = {8'b0, dataB[15:0], 8'b0};
                    end*/
                    // skip unaligned halfword access
                    2'd2: begin
                        mem_load_result = {{16{memory_data[31]}}, memory_data[31:16]};
                        MemWriteByteAddress = 4'b1100;
                        __tmp_MemData = {dataB[15:0], 16'b0};
                    end
                    default: begin
                        mem_load_result = 32'hX;
                        MemWriteByteAddress = 4'bX;
                        __tmp_MemData = 32'bX;
                    end
                endcase
            end

            3'b010: begin
                mem_load_result = memory_data; // lw
                MemWriteByteAddress = 4'b1111; //sw
                __tmp_MemData = dataB;
              end
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

            default: begin
                mem_load_result = 32'hX;
                MemWriteByteAddress = 4'b0000;
                __tmp_MemData = 31'bx;
            end
        endcase
    

endmodule
