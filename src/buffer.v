module buffer(
  input clk,
  input [19:0] addr_in,
  input [19:0] addr_out,
  input we,
  output reg [7:0] data_out,
  input reg [7:0] data_in
);

//reg [31:0] buffer[0:153600]; // 45F - only one cam buffer 320x640
reg [31:0] buffer[0:307200]; // 85F one cam buffer 640x480
//reg [31:0] buffer[0:614400]; // 85F two cam buffer

  always @(posedge clk) begin
          if(we)
              buffer[addr_in] <= data_in;
          else
	      data_out <= buffer[addr_out];
  end
endmodule
