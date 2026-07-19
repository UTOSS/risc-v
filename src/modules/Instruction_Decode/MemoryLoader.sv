`include "src/timescale.svh"
`include "src/headers/types.svh"

module MemoryLoader
( input  data_t memory_data

/* verilator lint_off UNUSEDSIGNAL */
, input  addr_t memory_address
/* verilator lint_on UNUSEDSIGNAL */

, input  logic [2:0]  funct3
, output data_t mem_load_result
);

    logic [1:0] byteindex;
    assign byteindex = memory_address[1:0];

    /* verilator lint_off WIDTHTRUNC */     //this entire block was commented out - reverted
    typedef enum logic [1:0]
    { BYTE = 2'b00
    , HALF = 2'b01
    , WORD = 2'b10
    } transfersize_t;
    /* verilator lint_on WIDTHTRUNC */

    logic signed_mode;
    /* verilator lint_off WIDTHTRUNC */
    assign signed_mode = ~funct3[2]; // reverted from "(funct3[2] == 1'b0);"
    /* verilator lint_on WIDTHTRUNC */

    always @(*) // cannot use always_comb yet: https://github.com/steveicarus/iverilog/issues/734
        case (funct3[1:0])
            BYTE: begin
                case (byteindex)
                    2'd0: begin
                        mem_load_result = {{24{signed_mode & memory_data[7]}}, memory_data[7:0]};
                    end
                    2'd1: begin
                        mem_load_result = {{24{signed_mode & memory_data[15]}}, memory_data[15:8]};
                    end
                    2'd2: begin
                        mem_load_result = {{24{signed_mode & memory_data[23]}}, memory_data[23:16]};
                    end
                    2'd3: begin
                        mem_load_result = {{24{signed_mode & memory_data[31]}}, memory_data[31:24]};
                    end
                    default: begin
                        mem_load_result = 32'hxxxxxxxx;
                    end
                endcase
            end
            HALF: begin
                case (byteindex)
                    2'd0: begin
                        mem_load_result = {{16{signed_mode & memory_data[15]}}, memory_data[15:0]};
                    end
                    2'd2: begin
                        mem_load_result = {{16{signed_mode & memory_data[31]}}, memory_data[31:16]};
                    end
                    default: begin
                        mem_load_result = 32'hxxxxxxxx;
                    end
                endcase
            end
            WORD: begin
                case (byteindex)
                    2'd0: begin
                        mem_load_result = memory_data;
                    end
                    default: begin
                        mem_load_result = 32'hxxxxxxxx;
                    end
                endcase
            end
            default: begin
                mem_load_result = 32'hxxxxxxxx;
            end
        endcase
endmodule

