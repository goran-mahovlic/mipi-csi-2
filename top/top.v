module top(input clk_25mhz,
                   input cam_sda,
                   input cam_scl,
                   input gpio_sda, 
                   input gpio_scl,
                   output [6:0] nc,
                   input ftdi_txd, wifi_txd,
                   output ftdi_rxd, wifi_rxd,
                   output ftdi_txden,
                   input cam_enable_gpio,
                   output cam_enable,
		   input dsiRX0_clk_dp, 
                   input [1:0] dsiRX0_dp, 
                   input clk_dp,clk_dn, 
                   //input [1:0] dsiRX0_dn,
		   output [4:0]led,
		   input [1:0]btn,
                   input [1:0]data_dp,input [1:0]data_dn,
                   output [7:6]gpdi_dp,output [7:6]gpdi_dn
		   );

assign nc[0] = clk_dp;
assign nc[1] = clk_dn;
assign nc[2] = cam_scl;
assign nc[3] = cam_sda;
assign nc[4] = gpio_scl;
assign nc[5] = gpio_sda;
assign nc[6] = cam_enable;

assign gpdi_dp[7] = data_dn[1];
assign gpdi_dn[7] = data_dp[1];
assign gpdi_dp[6] = data_dn[0];
assign gpdi_dn[6] = data_dp[0];

assign ftdi_txden = 1'b1;
//assign ftdi_rxd = wifi_txd; // pass to ESP32
assign wifi_rxd = ftdi_txd;

assign cam_enable = 1'b1; 

reg [19:0] rgb_data_counter = 0;
reg [19:0] rgb_data_counter_out = 0;

wire cam_clk_p;
wire [1:0] cam_data_p;
wire [1:0] clk;
wire [1:0] virtual_ch_data;

ILVDS ILVDS_clk_inst (.A(dsiRX0_clk_dp),.Z(cam_clk_p));
ILVDS ILVDS_data0_inst (.A(dsiRX0_dp[0]),.Z(cam_data_p[0]));
ILVDS ILVDS_data1_inst (.A(dsiRX0_dp[1]),.Z(cam_data_p[1]));

wire [3:0] clks;
wire clk9,clk73,clk18;
assign clk9 = clks[1];
assign clk73 = clks[2];
assign clk18 = clks[0];

  ecp5pll
  #(
   .in_hz(73000000),
   .out0_hz(18250000), .out0_tol_hz(0),
   .out1_hz(9125000), .out1_deg(0), .out1_tol_hz(0),
   .out2_hz(73000000), .out2_tol_hz(0)
  )
  ecp5pll_inst
  (
    .clk_i(cam_clk_p),
    .clk_o(clks)
  );

wire frame_start,frame_end,line_start,line_end, in_frame, in_line;
wire short_data_enable,interrupt,valid_packet;
wire image_data_enable;

wire [31:0] image_data;
wire [5:0] image_data_type;
wire [15:0] word_count;
wire [15:0] short_data;

camera #(
   .NUM_LANES(2),
   .ZERO_ACCUMULATOR_WIDTH(3)
)
   camera_i(
    .clock_p(clk73),
    .data_p(cam_data_p),
    .virtual_channel(virtual_ch_data),
    // Total number of words in the current packet
    .word_count(word_count),
    .interrupt(interrupt),
    .image_data(image_data),
    .image_data_type(image_data_type),
    // Whether there is output data ready
    .image_data_enable(image_data_enable),
    .frame_start(frame_start),
    .frame_end(frame_end),
    .line_start(line_start),
    .line_end(line_end),
    .generic_short_data_enable(short_data_enable),
    .generic_short_data(short_data),
    .valid_packet(valid_packet),
    .in_line(in_line),
    .in_frame(in_frame)
);

reg [9:0] read_x;
reg [9:0] read_y;
wire [7:0] read_data;
reg [7:0] write_data;
wire rgb_enable;
wire [31:0] rgb;

rgb565 rgb_i(
    .image_data(image_data),
    .image_data_enable(image_data_enable),
    .rgb(rgb),
    .rgb_enable(rgb_enable)
);

/*
// Not used
downsample ds_i(
   .pixel_clock(clk73),
   .in_line(in_line),
   .in_frame(in_frame),
   .pixel_data(rgb),
   .data_enable(rgb_enable),

   .read_clock(clk9),
   .read_x(read_x),
   .read_y(read_y),
   .read_q(read_data)
   );
*/

reg buffer_we;
initial buffer_we = 1'b1;

buffer buffer_i(
  .clk(clk73),
  .addr_in(rgb_data_counter),
  .addr_out(rgb_data_counter_out),
  .we(buffer_we),
  .data_out(read_data),
  .data_in(write_data)
);


reg do_send = 1'b0;
wire uart_busy;
reg uart_write;
reg [12:0] uart_holdoff;
reg [13:0] btn_debounce;
reg btn_reg;
reg [7:0] data_buffer;

uart_tx uart_i (
   .clk(clk73),
   .resetn(1'b1),
   .ser_tx(ftdi_rxd),
   .cfg_divider(73000000/115200),
   .data_we(uart_write),
   .data(read_data),
   .data_wait(uart_busy)
);

reg sendPicture = 1'b1;

always @(posedge clk9)
begin
	//btn_reg <= btn[0];
        btn_reg <= (rgb_data_counter[19] && sendPicture);
	if (btn_reg)
		btn_debounce <= 0;
	else if (!&(btn_debounce))
		btn_debounce <= btn_debounce + 1;

	uart_write <= 1'b0;
	if (btn_reg && &btn_debounce && !do_send) begin
                sendPicture <= 1'b0;
		do_send <= 1'b1;
                buffer_we <= 1'b0;
		read_x <= 0;
		read_y <= 0;
	end
		if (uart_busy)
			uart_holdoff <= 0;
		else if (!&(uart_holdoff))
			uart_holdoff <= uart_holdoff + 1'b1;

		if (do_send) begin
			if (read_x == 0 && read_y == 480) begin
				do_send <= 1'b0;
			end else begin
				if (&uart_holdoff && !uart_busy && !uart_write) begin
					uart_write <= 1'b1;
                                        rgb_data_counter_out <= rgb_data_counter_out + 1'b1;
					if (read_x == 639) begin
						read_y <= read_y + 1'b1;
						read_x <= 0;
					end else begin
						read_x <= read_x + 1'b1;
					end
                                        
				end
			end
		end
	end

reg last_rgb_enable;
wire [7:5] value;
reg savePic = 1'b1;

always @(posedge clk73)
begin
  if( {rgb_enable, last_rgb_enable} == 2'b10)
  begin
      rgb_data_counter <= rgb_data_counter + 1'b1;
      led[4:0] <= rgb[4:0];

      if(rgb_data_counter<307200 && savePic) // 640x480 - save only once
      begin
          write_data <= rgb[7:0];
      end
      else
        savePic <= 1'b0;
   end
  last_rgb_enable <= rgb_enable;
end

endmodule
