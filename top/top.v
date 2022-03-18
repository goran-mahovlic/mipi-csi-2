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
)
 ov5647_0_i(
  .clk_in(clk_25mhz),
  .scl(cam_scl),
  .sda(cam_sda),
  .mode(mode),
  .resolution(3),
  .format(1)
);

ov5647 #(
   .INPUT_CLK_RATE(25000000),
   .TARGET_SCL_RATE(400000)
)
   ov5647_1_i(
    .clk_in(clk_25mhz),
    .scl(gpio_scl),
    .sda(gpio_sda),
    .mode(mode),
    .resolution(3),
    .format(1)
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
wire [1:0] rgb888_enable;
wire [31:0] rgb;

assign rgb_enable = rgb888_enable[1];

raw8 raw8_i(
    .image_data(image_data),
    .image_data_enable(image_data_enable),
    .raw(rgb),
    .raw_enable(rgb_enable)
);

/* Not implemented
rgb565 rgb565_i(
    .image_data(image_data),
    .image_data_enable(image_data_enable),
    .rgb(rgb),
    .rgb_enable(rgb_enable)
);
*/

/* Not implemented
rgb888 rgb888_i(
    .clock_p(cam0_clk_p),
    .clock_n(~cam0_clk_p),
    .image_data(image_data),
    .image_data_enable(image_data_enable),
    .rgb(rgb),
    .rgb_enable(rgb_enable)
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

reg last_rgb_enable;
wire [7:5] value;
reg savePic = 1'b1;
reg startupDelay = 1'b0;
reg [31:0] startupCounter;

always @(posedge pixel_clock)
begin
    if(!savePic && !buffer_we) begin
        rgb_data_counter_out <= (((y * 640) - 640) + x);
        color <= { read_data[7:3], 3'b000 ,read_data[7:3], 3'b000 ,read_data[7:3], 3'b000 };
    end
    else begin
        color <= 24'hffffff;
    end
end

always @(posedge pixel_clock)
begin

 if( ({rgb_enable, last_rgb_enable} == 2'b10) && startupDelay && in_line && in_frame)
   begin

      if(frame_start)
          rgb_data_counter <= 1'b0;

      rgb_data_counter <= rgb_data_counter + 1'b1;

      if(rgb_data_counter<153600 && savePic) // 640x480 - save only once
      begin
          write_data <= rgb;
      end
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
end

always @(posedge cam0_clk_p)
begin
    if(startupCounter[20] && frame_end)
        startupDelay <= 1'b1;
    counter0 <= counter0 + 1'b1;
end

always @(posedge cam1_clk_p)
begin
    counter1 <= counter1 + 1'b1;
end

assign led[7:0] = counter0[25:18];

endmodule
