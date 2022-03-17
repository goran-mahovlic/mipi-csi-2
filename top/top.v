module top(input clk_25mhz,
                   inout cam_sda,
                   inout cam_scl,
                   inout gpio_sda,
                   inout gpio_scl,
                   input ftdi_txd, wifi_txd,
                   output ftdi_rxd, wifi_rxd,
                   output ftdi_txden,
                   output cam_enable,
		   input dsiRX0_clk_dp, 
                   input dsiRX1_clk_dp,
                   input [1:0] dsiRX0_dp,
                   input [1:0] dsiRX1_dp,
		   output [7:0]led,
		   input [2:0]btn,
                   output [3:0]gpdi_dp, output [3:0]gpdi_dn
		   );

assign ftdi_txden = 1'b1;
assign ftdi_rxd = wifi_txd; // pass to ESP32
assign wifi_rxd = ftdi_txd;

assign cam_enable = 1'b1; 

//assign gpio_sda = cam_sda;
//assign gpio_scl = cam_scl;

reg [19:0] rgb_data_counter = 0;
reg [19:0] rgb_data_counter_out = 0;

wire cam0_clk_p, cam1_clk_p;
wire [1:0] cam0_data_p, cam1_data_p;
wire [1:0] clk;
wire [1:0] virtual_ch_data;
reg [32:0] counter0;
reg [32:0] counter1;

ILVDS ILVDS_cam0_clk_inst (.A(dsiRX0_clk_dp),.Z(cam0_clk_p));
ILVDS ILVDS_cam0_data0_inst (.A(dsiRX0_dp[0]),.Z(cam0_data_p[0]));
ILVDS ILVDS_cam0_data1_inst (.A(dsiRX0_dp[1]),.Z(cam0_data_p[1]));

ILVDS ILVDS_cam1_clk_inst (.A(dsiRX1_clk_dp),.Z(cam1_clk_p));
ILVDS ILVDS_cam1_data0_inst (.A(dsiRX1_dp[0]),.Z(cam1_data_p[0]));
ILVDS ILVDS_cam1_data1_inst (.A(dsiRX1_dp[1]),.Z(cam1_data_p[1]));

//assign led[0] = cam_sda;
//assign led[1] = cam_scl;

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
    .clk_i(cam0_clk_p),
    .clk_o(clks)
  );

wire [1:0] mode = 2;

ov5647 #(
   .INPUT_CLK_RATE(25000000),
   .TARGET_SCL_RATE(400000)
   //.ADDRESS(54)
)
 ov5647_0_i(
  .clk_in(clk_25mhz),
  .scl(cam_scl),
  .sda(cam_sda),
  .mode(mode),
  .resolution(3),
  .format(1)
//  .sensor_state(led[2:0])
  //.ready(led[4]),
  //.power_enable(led[5]),
  //.model_err(led[5])
 // .nack_err(led[5])
);

ov5647 #(
   .INPUT_CLK_RATE(25000000),
   .TARGET_SCL_RATE(400000)
//   .ADDRESS(54)
)
   ov5647_1_i(
    .clk_in(clk_25mhz),
    .scl(gpio_scl),
    .sda(gpio_sda),
    .mode(mode),
    .resolution(3),
    .format(1)
//    .model_err(led[0])
//    .ready(led[2]),
//    .power_enable(led[3])
);

wire frame_start,frame_end,line_start,line_end, in_frame, in_line;
wire short_data_enable,interrupt,valid_packet;
wire image_data_enable;

wire [31:0] image_data;
wire [5:0] image_data_type;
wire [15:0] word_count;
wire [15:0] short_data;

wire [9:0] x;
wire [9:0] y;
reg [23:0] color;

wire pixel_clock;

assign pixel_clock = savePic ? clk73 : clk_25mhz;

hdmi_video hdmi_video
(
    .clk_25mhz(clk_25mhz),
    .x(x),
    .y(y),
    .color(color),
    .gpdi_dp(gpdi_dp[3:0]),
    .gpdi_dn(gpdi_dn[3:0])	
);

camera #(
   .NUM_LANES(2),
   .ZERO_ACCUMULATOR_WIDTH(3)
)
   camera_i(
    .clock_p(pixel_clock),
    .data_p(cam0_data_p),
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
wire [23:0] read_data;
reg [23:0] write_data;
wire rgb_enable;
wire [31:0] rgb;
/*
raw8 raw8_i(


);
*/
/*
rgb565 rgb_i(
    .image_data(image_data),
    .image_data_enable(image_data_enable),
    .rgb(rgb),
    .rgb_enable(rgb_enable)
);
*/

/*
// Not used
downsample ds_i(
   .pixel_clock(pixel_clock),
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
  .clk(pixel_clock),
  .addr_in(rgb_data_counter),
  .addr_out(rgb_data_counter_out),
  .we(buffer_we),
  .data_out(read_data),
  .data_in(write_data)
);

/*
reg do_send = 1'b0;
wire uart_busy;
reg uart_write;
reg [12:0] uart_holdoff;
reg [13:0] btn_debounce;
reg btn_reg;

uart_tx uart_i (
   .clk(clk73),
   .resetn(1'b1),
   .ser_tx(ftdi_rxd),
   .cfg_divider(73000000/115200),
   .data_we(uart_write),
   .data(read_data),
   .data_wait(uart_busy)
);

reg sendPicture = 1'b0;

always @(posedge clk9)
begin
//	btn_reg <= btn[0];
//      btn_reg <= (sendPicture);
//	if (btn_reg)
//		btn_debounce <= 0;
//	else if (!&(btn_debounce))
//		btn_debounce <= btn_debounce + 1;

	uart_write <= 1'b0;
	if (!savePic && !do_send) begin
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
			if (read_x == 0 && read_y == 240) begin
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
*/

reg last_rgb_enable;
wire [7:5] value;
reg savePic = 1'b1;
reg startupDelay = 1'b0;
reg [31:0] startupCounter;

//  assign red_d[7:0] = in_color[23:16];
//  assign green_d[7:0] = in_color[15:8];
//  assign blue_d[7:0] = in_color[7:0];
//  111 111 11

always @(posedge pixel_clock)
begin
    if(!savePic && !buffer_we) begin
        rgb_data_counter_out <= (((y * 640) - 640) + x);
        color <= { read_data[7:5] , 5'b00000 , read_data[4:2] , 5'b00000 , read_data[1:0] , 6'b000000 };
    end
    else begin
        color <= 24'hffffff;
    end
end

always @(posedge pixel_clock)
begin

  if( ({image_data_enable, last_rgb_enable} == 2'b10) && startupDelay )
  begin

      if(frame_start)
          rgb_data_counter <= 1'b0;

      rgb_data_counter <= rgb_data_counter + 1'b1;

      //led[7:0] <= rgb[7:0];

      if(rgb_data_counter<153600 && savePic) // 640x480 - save only once
      begin
          //write_data <= { image_data[29] , image_data[28] , image_data[27] , image_data[23] , image_data[22] , image_data[21] , image_data[17], image_data[16] };  // read_data[7:5] , 5'b0 , read_data[4:2] , 5'b0 , read_data[1:0] , 6'b0
          //write_data <= { image_data[31:29] , image_data[23:21], image_data[15:14] } ; //rgb[20] , rgb[19] }; 
          write_data <= { image_data[23:21] , image_data[2:0] , image_data[14:13] }; // image_data[15:3], image_data[7:6] };
      end //rgb[29] , rgb[28] , rgb[27]        g -- rgb[7:5], 19, 16   29:27 == 14 15     0?
      // 23:21
      else begin
          savePic <= 1'b0;
          buffer_we <= 1'b0;
      end
   end
  last_rgb_enable <= image_data_enable;
end

always @(posedge image_data_enable)
begin
    startupCounter <= startupCounter + 1'b1;
    if(startupCounter[20])
        startupDelay <= 1'b1;
end

always @(posedge cam0_clk_p)
begin
    counter0 <= counter0 + 1'b1;
//    if(counter0[26])
//     mode <= 2'b01;
//    if(counter0[27])
//     mode <= 2'b10;
end

always @(posedge cam1_clk_p)
begin
    counter1 <= counter1 + 1'b1;
end

//assign led[7:6] = counter0[25:24];
//assign led[1:0] = counter1[25:24];
assign led[7:3] = 5'b00000;
//assign led[4] = 1'b0;
//assign led[3] = 1'b0;
//assign led[2] = 1'b0;
//assign led[1] = 1'b0;
//assign led[0] = 1'b0;
//assign led[2:1] = mode;

endmodule
