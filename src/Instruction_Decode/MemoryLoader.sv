`include "src/types.svh"

module MemoryLoader
( input  data_t memory_data

/* verilator lint_off UNUSEDSIGNAL */
, input  addr_t memory_address
/* verilator lint_off UNUSEDSIGNAL */

, input  logic [2:0]  funct3
, input  logic [31:0] dataB
, output data_t mem_load_result
, output logic [3:0] MemWriteByteAddress
, output logic [31:0] __tmp_MemData
);

    logic [1:0] byteindex;
    assign byteindex = memory_address[1:0];

//    typedef enum logic [1:0]
//    { BYTE = 2'b00
//   , HALF = 2'b01
//    , WORD = 2'b10
//    } transfersize_t;

    logic signed_mode;
    assign signed_mode = (funct3[2] == 1'b0);

    always @(*) // cannot use always_comb yet: https://github.com/steveicarus/iverilog/issues/734
        case (funct3)
            3'b000: begin
                __tmp_MemData = { dataB[7:0], dataB[7:0], dataB[7:0], dataB[7:0] };
                case (byteindex)
                    2'd0: begin
                        mem_load_result = {{24{signed_mode & memory_data[7]}}, memory_data[7:0]};
                        MemWriteByteAddress = 4'b0001;
                    end
                    2'd1: begin
                        mem_load_result = {{24{signed_mode & memory_data[15]}}, memory_data[15:8]};
                        MemWriteByteAddress = 4'b0010;
                    end
                    2'd2: begin
                        mem_load_result = {{24{signed_mode & memory_data[23]}}, memory_data[23:16]};
                        MemWriteByteAddress = 4'b0100;
                    end
                    2'd3: begin
                        mem_load_result = {{24{signed_mode & memory_data[31]}}, memory_data[31:24]};
                        MemWriteByteAddress = 4'b1000;
                    end
                    default: begin
                        mem_load_result = 32'hxxxxxxxx;
                        MemWriteByteAddress = 4'bxxxx;
                    end
                endcase
            end
            3'b001: begin
                __tmp_MemData = { dataB[15:0], dataB[15:0] };
                case (byteindex[1])
                    1'b0: begin
                        mem_load_result = {{16{signed_mode & memory_data[15]}}, memory_data[15:0]};
                        MemWriteByteAddress = 4'b0011;
                    end
                    1'b1: begin
                        mem_load_result = {{16{signed_mode & memory_data[31]}}, memory_data[31:16]};
                        MemWriteByteAddress = 4'b1100;
                    end
                    default: begin
                        mem_load_result = 32'hxxxxxxxx;
                        MemWriteByteAddress = 4'bxxxx;
                    end
                endcase
            end
            3'b101: begin // LHU (unsigned halfword)
                __tmp_MemData = { dataB[15:0], dataB[15:0] };
                case (byteindex[1])
                    1'b0: begin
                        mem_load_result = {16'b0, memory_data[15:0]};  // ZERO extend
                        MemWriteByteAddress = 4'b0011;
                    end
                    1'b1: begin
                        mem_load_result = {16'b0, memory_data[31:16]};
                        MemWriteByteAddress = 4'b1100;
                    end
                    default: begin
                        mem_load_result = 32'hxxxxxxxx;
                        MemWriteByteAddress = 4'bxxxx;
                    end
                endcase
            end
            3'b010: begin // LW
                __tmp_MemData = dataB;
                mem_load_result = memory_data;
                MemWriteByteAddress = 4'b1111;
            end
            3'b100: begin // LBU (unsigned byte)
                __tmp_MemData = { dataB[7:0], dataB[7:0], dataB[7:0], dataB[7:0] };
                case (byteindex)
                    2'd0: mem_load_result = {24'b0, memory_data[7:0]};
                    2'd1: mem_load_result = {24'b0, memory_data[15:8]};
                    2'd2: mem_load_result = {24'b0, memory_data[23:16]};
                    2'd3: mem_load_result = {24'b0, memory_data[31:24]};
                    default: mem_load_result = 32'hxxxxxxxx;
                endcase
                MemWriteByteAddress = 4'b0000;  // Don't care for load
            end
            default: begin
                __tmp_MemData = 32'hxxxxxxxx;
                mem_load_result = 32'hxxxxxxxx;
                MemWriteByteAddress = 4'bxxxx;
            end
        endcase
endmodule

