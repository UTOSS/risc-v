module mux (
  input  wire [31:0] input1,
  input  wire [31:0] input0,
  input  wire        sel,
  output wire [31:0] out
);
  assign out = sel ? input1 : input0;
endmodule

