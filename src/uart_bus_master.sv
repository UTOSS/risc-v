//protocol:  A: address D: data
//SOF: A5  
//command number(10-13) 
//WRITE32: A5 10 A0 A1 A2 A3 D0 D1 D2 D3 CHK
//READ32:  A5 11 A0 A1 A2 A3 CHK
//RUN: A5 12 CHK   (CHK=0x12)
//HALT: A5 13 CHK   (CHK=0x12)
//R_ACK:90 R_RD:91
module uart_bus_master (
    input  wire  clk
    , input  wire rst
    , input  wire [7:0]  rx_data
    , input  wire rx_valid
    , output wire rx_ready
    , output logic [7:0] tx_data
    , output logic tx_valid
    , input  wire  tx_ready
    , output logic [31:0] bus_addr
    , output logic [31:0] bus_write_data
    , output logic [3:0]  bus_write_enable
    , input  wire [31:0]  bus_read_data
    , output logic hold_core
    , input  logic [31:0] dbg_regs [0:31]
    , input  logic [31:0] dbg_pc
);

    assign rx_ready = (state != STATE_SEND);
	 
    localparam byte SOF  = 8'hA5;
    localparam byte RSOF = 8'h5A;

    localparam byte CMD_WR32 = 8'h10;
    localparam byte CMD_RD32 = 8'h11;
    localparam byte CMD_RUN  = 8'h12;
    localparam byte CMD_HALT = 8'h13;
    localparam byte CMD_RDREG = 8'h14;  
	 

    localparam byte R_ACK = 8'h90;
    localparam byte R_RD  = 8'h91;
    localparam byte R_RDREG   = 8'h92; 

    localparam byte STATUS_OK   = 8'h00;
    localparam byte STATUS_CHK  = 8'h01;
    localparam byte STATUS_BUSY = 8'h02;
    localparam byte STATUS_CMD  = 8'h03;

    typedef enum logic [4:0] {
        STATE_WAIT_SOF = 5'd0
        , STATE_CMD      = 5'd1
        , STATE_A0       = 5'd2
        , STATE_A1       = 5'd3
        , STATE_A2       = 5'd4
        , STATE_A3       = 5'd5
        , STATE_D0       = 5'd6
        , STATE_D1       = 5'd7
        , STATE_D2       = 5'd8
        , STATE_D3       = 5'd9
        , STATE_CHK      = 5'd10
        , STATE_DO_WR    = 5'd11
        , STATE_DO_RD0   = 5'd12
        , STATE_DO_RD1   = 5'd13
        , STATE_SEND     = 5'd14
        , STATE_REG   = 5'd15
    } state_t;

    state_t state;
    logic [4:0] reg_idx;
    logic [7:0]  cmd;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic [7:0]  chk_calc;

    logic [7:0] resp [0:6];
    logic [2:0] resp_len;
    logic [2:0] resp_idx;

    task automatic prepare_ack(input byte status);
        begin
            // 5A 90 STATUS CHK
            resp[0] = RSOF;
            resp[1] = R_ACK;
            resp[2] = status;
            resp[3] = (R_ACK ^ status);
            resp_len = 3'd4;
            resp_idx = 3'd0;
            state = STATE_SEND;
        end
    endtask

    task automatic prepare_rd(input logic [31:0] d);
        begin
            // 5A 91 d0 d1 d2 d3 chk
            resp[0] = RSOF;
            resp[1] = R_RD;
            resp[2] = d[7:0];
            resp[3] = d[15:8];
            resp[4] = d[23:16];
            resp[5] = d[31:24];
            resp[6] = (R_RD ^ d[7:0] ^ d[15:8] ^ d[23:16] ^ d[31:24]);
            resp_len = 3'd7;
            resp_idx = 3'd0;
            state = STATE_SEND;
        end
    endtask

    task automatic prepare_rdreg(input logic [31:0] d);
    begin
        // 5A 92 d0 d1 d2 d3 chk
        resp[0] = RSOF;
        resp[1] = R_RDREG;
        resp[2] = d[7:0];
        resp[3] = d[15:8];
        resp[4] = d[23:16];
        resp[5] = d[31:24];
        resp[6] = (R_RDREG ^ d[7:0] ^ d[15:8] ^ d[23:16] ^ d[31:24]);
        resp_len = 3'd7;
        resp_idx = 3'd0;
        state = STATE_SEND;
    end
    endtask

    always_ff @(posedge clk) begin
        if (rst) begin
            bus_addr  <= 32'd0;
            bus_write_data <= 32'd0;
            bus_write_enable <= 4'b0000;

            tx_data   <= 8'd0;
            tx_valid  <= 1'b0;

            state        <= STATE_WAIT_SOF;
            cmd       <= 8'd0;
            addr      <= 32'd0;
            wdata     <= 32'd0;
            chk_calc  <= 8'd0;

            resp_len  <= 3'd0;
            resp_idx  <= 3'd0;

            hold_core <= 1'b1; 
        end else begin
            bus_write_enable <= 4'b0000;
				
            if (tx_valid && tx_ready) tx_valid <= 1'b0;

            if (state == STATE_SEND) begin
                if (!tx_valid && tx_ready) begin
                    tx_data  <= resp[resp_idx];
                    tx_valid <= 1'b1;
                    if (resp_idx == resp_len-1) begin
                        state <= STATE_WAIT_SOF;
                        resp_idx <= 3'd0;
                    end else begin
                        resp_idx <= resp_idx + 3'd1;
                    end
                end

            end else begin
                case (state)
                    STATE_WAIT_SOF: begin
                        if (rx_valid & rx_ready && rx_data == SOF) state <= STATE_CMD;
                    end

                    STATE_CMD: if (rx_valid & rx_ready) begin
                        cmd      <= rx_data;
                        chk_calc <= rx_data;
                        addr     <= 32'd0;
                        wdata    <= 32'd0;

                        if (rx_data == CMD_RUN || rx_data == CMD_HALT) state <= STATE_CHK;
                            else if (rx_data == CMD_RDREG) state <= STATE_REG;
                        else state <= STATE_A0;
                    end

                    STATE_A0: if (rx_valid & rx_ready) begin 
                                addr[7:0]   <= rx_data; 
                                chk_calc <= chk_calc ^ rx_data; 
                                state <= STATE_A1; 
						  end
						  
                    STATE_A1: if (rx_valid & rx_ready) begin 
                                addr[15:8]  <= rx_data; 
                                chk_calc <= chk_calc ^ rx_data; 
                                state <= STATE_A2; 
						  end
						  
                    STATE_A2: if (rx_valid & rx_ready) begin 
                                addr[23:16] <= rx_data; 
                                chk_calc <= chk_calc ^ rx_data; 
                                state <= STATE_A3; 
					     end
						  
                    STATE_A3: if (rx_valid & rx_ready) begin
                        addr[31:24] <= rx_data;
                        chk_calc    <= chk_calc ^ rx_data;
                        if (cmd == CMD_WR32) state <= STATE_D0;
                        else state <= STATE_CHK; // RD32 no data packet
                    end

                    STATE_D0: if (rx_valid & rx_ready) begin 
                                wdata[7:0]   <= rx_data; 
                                chk_calc <= chk_calc ^ rx_data; 
                                state <= STATE_D1; 
						  end
						  
                    STATE_D1: if (rx_valid & rx_ready) begin 
                                wdata[15:8]  <= rx_data; 
                                chk_calc <= chk_calc ^ rx_data; 
                                state <= STATE_D2; 
						  end
						  
                    STATE_D2: if (rx_valid & rx_ready) begin 
                                wdata[23:16] <= rx_data; 
                                chk_calc <= chk_calc ^ rx_data; 
                                state <= STATE_D3; 
						  end
						  
                    STATE_D3: if (rx_valid & rx_ready) begin 
                                wdata[31:24] <= rx_data; 
                                chk_calc <= chk_calc ^ rx_data; 
                                state <= STATE_CHK; 
						  end

						  STATE_REG: if (rx_valid & rx_ready) begin
                                reg_idx  <= rx_data[4:0];
                                chk_calc <= chk_calc ^ rx_data;
                                state <= STATE_CHK;
						  end

                    STATE_CHK: if (rx_valid & rx_ready) begin
                        if (rx_data != chk_calc) begin
                            prepare_ack(STATUS_CHK);
                        end else begin
                            unique case (cmd)
                                CMD_HALT: begin
                                    hold_core <= 1'b1;
                                    prepare_ack(STATUS_OK);
                                end
                                CMD_RUN: begin
                                    hold_core <= 1'b0;
                                    prepare_ack(STATUS_OK);
                                end
                                CMD_WR32: begin
                                    if (!hold_core) prepare_ack(STATUS_BUSY);
                                    else state <= STATE_DO_WR;
                                end
                                CMD_RD32: begin
                                    if (!hold_core) prepare_ack(STATUS_BUSY);
                                    else state <= STATE_DO_RD0;
                                end
                                CMD_RDREG: begin
                                    prepare_rdreg(dbg_regs[reg_idx]);
                                end
                                default: begin
                                    prepare_ack(STATUS_CMD);
                                end
                            endcase
                        end
                    end

                    STATE_DO_WR: begin
                        bus_addr  <= addr;
                        bus_write_data <= wdata;
                        bus_write_enable <= 4'b1111;  
                        prepare_ack(STATUS_OK);
                    end

                    STATE_DO_RD0: begin
                        bus_addr <= addr;     
                        state <= STATE_DO_RD1;      
                    end

                    STATE_DO_RD1: begin
                        prepare_rd(bus_read_data); 
                    end

                    default: state <= STATE_WAIT_SOF;
                endcase
            end
        end
    end

endmodule

