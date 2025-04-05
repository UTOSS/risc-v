module mux #( parameter INPUT_WIDTH
            , parameter INPUT_COUNT
            )
            ( input  wire [$clog2(INPUT_COUNT)-1:0] sel
            , input  wire [INPUT_WIDTH-1:0]         in  [INPUT_COUNT-1:0]
            , output wire [INPUT_WIDTH-1:0]         out
            );
  assign out = in[sel];
endmodule
