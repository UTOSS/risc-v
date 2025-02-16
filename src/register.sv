/* Generic register module */

module register #( type DATA_TYPE
                 )
                 ( input  wire      clk
                 , input  wire      en
                 , input  DATA_TYPE data_in
                 , output DATA_TYPE data_out
                 );

  always_ff @(posedge clk) begin
    if (en) begin
      data_out <= data_in;
    end
  end
endmodule
