module buffer(
  input clk,
  input [18:0] addr_in,
  input [18:0] addr_out,
  input we,
  output reg [7:0] data_out,
  input reg [7:0] data_in
);

reg [7:0] buffer[0:307200];

  always @(posedge clk) begin
          if(we)
              buffer[addr_in] <= data_in;
          else
	      data_out <= buffer[addr_out];
  end
endmodule
