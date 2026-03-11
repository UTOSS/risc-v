/* Generic register module */
`timescale 1ns/1ps


module register #( type DATA_TYPE )
  ( input  wire      clk
  , input  wire      reset
  , input  wire      en
  , input  wire [31:0] data_in
  , output reg [31:0] data_out
  );

  always @(posedge clk) begin
    if (reset) begin
      data_out <= 32'b0;
    end
    else
    if (en) begin
      data_out <= data_in;
    end
  end
endmodule
