/* generic adder module */

`include "utils.svh"

module adder #( type WIDTH
              )
              ( input  wire             clk
              , input  wire             en
              , input  wire [WIDTH-1:0] lhs
              , input  wire [WIDTH-1:0] rhs
              , output wire [WIDTH-1:0] out
              );

  always_ff @(posedge clk) begin
    if (en) begin
      out <= lhs + rhs;
    end
  end
endmodule
