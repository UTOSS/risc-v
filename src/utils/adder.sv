/* generic adder module */

`include "src/utils.svh"

module adder #( parameter WIDTH
              )
              ( input  wire             clk
              , input  wire             en
              , input  wire [WIDTH-1:0] lhs
              , input  wire [WIDTH-1:0] rhs
              , output reg  [WIDTH-1:0] out
              );

  always @(posedge clk) begin
    if (en) begin
      out <= lhs + rhs;
    end
  end
endmodule
