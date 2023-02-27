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

// Select cam 0 or 1
reg cam0 = 1'b1;

reg [19:0] rgb_data_counter = 0;
reg [19:0] rgb_data_counter_out = 0;

wire cam0_clk_p, cam1_clk_p, clk73_cam0,clk73_cam1, clk25;

wire [3:0] clks_0, clks_1;

assign clk73_cam0 = clks_0[1];
assign clk73_cam1 = clks_1[1];
assign clk25 = clk_25mhz;//clks_0[0];

wire [1:0] cam0_data_p, cam1_data_p;

reg [32:0] counter0, counter1;

wire [1:0] mode = 2;

wire [31:0] image_data_current_cam;

wire [9:0] x, y;
reg [23:0] color;
wire pixel_clock, buffer_clock_cam0, buffer_clock_cam1;

reg buffer_we_cam0, buffer_we_cam1;

initial buffer_we_cam0 = 1'b1;
initial buffer_we_cam1 = 1'b0;

reg [9:0] read_x;
reg [9:0] read_y;
wire [23:0] read_data_cam0,read_data_cam1;
reg [23:0] write_data_cam0, write_data_cam1;
wire [31:0] rgb_current_cam;
reg last_rgb_enable;
wire [7:5] value;
reg savePic = 1'b1;
reg startupDelay = 1'b0;
reg [31:0] startupCounter;

wire image_data_enable_current_cam, frame_end_current_cam, frame_start_current_cam;
wire rgb_enable_current_cam;

ILVDS ILVDS_cam0_clk_inst (.A(dsiRX0_clk_dp),.Z(cam0_clk_p));
ILVDS ILVDS_cam0_data0_inst (.A(dsiRX0_dp[0]),.Z(cam0_data_p[0]));
ILVDS ILVDS_cam0_data1_inst (.A(dsiRX0_dp[1]),.Z(cam0_data_p[1]));

ILVDS ILVDS_cam1_clk_inst (.A(dsiRX1_clk_dp),.Z(cam1_clk_p));
ILVDS ILVDS_cam1_data0_inst (.A(dsiRX1_dp[0]),.Z(cam1_data_p[0]));
ILVDS ILVDS_cam1_data1_inst (.A(dsiRX1_dp[1]),.Z(cam1_data_p[1]));

wire [1:0] data_p_current_cam;

assign buffer_clock_cam0 = buffer_we_cam0 ?  clk73_cam0 : clk25;
assign buffer_clock_cam1 = buffer_we_cam1 ?  clk73_cam1 : clk25;
assign pixel_clock = cam0 ? clk73_cam0 : clk73_cam1;
assign data_p_current_cam = cam0 ? cam0_data_p : cam1_data_p;

ecp5pll
#(
.in_hz(75000000),
.out0_hz(25000000), .out0_tol_hz(0),
.out1_hz(75000000), .out1_deg(0), .out1_tol_hz(0)
)
ecp5pll_0_inst
(
.clk_i(cam0_clk_p),
.clk_o(clks_0)
);

ecp5pll
#(
.in_hz(75000000),
.out0_hz(25000000), .out0_tol_hz(0),
.out1_hz(75000000), .out1_deg(0), .out1_tol_hz(0)
)
ecp5pll_1_inst
(
.clk_i(cam1_clk_p),
.clk_o(clks_1)
);

ov5647 #(
   .INPUT_CLK_RATE(25000000),
   .TARGET_SCL_RATE(400000)
)
 ov5647_0_i(
  .clk_in(clk25),
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
    .clk_in(clk25),
    .scl(gpio_scl),
    .sda(gpio_sda),
    .mode(mode),
    .resolution(3),
    .format(1)
);

hdmi_video hdmi_video
(
    .clk_25mhz(clk25),
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
   camera_current_cam(
    .clock_p(pixel_clock),
    .data_p(data_p_current_cam),
    .image_data(image_data_current_cam),
    .image_data_enable(image_data_enable_current_cam),
    .frame_start(frame_start_current_cam),
    .frame_end(frame_end_current_cam)
);

raw8 raw8_cam(
    .image_data(image_data_current_cam),
    .image_data_enable(image_data_enable_current_cam),
    .raw(rgb_current_cam),
    .raw_enable(rgb_enable_current_cam)
);

buffer buffer_cam0(
  .clk(buffer_clock_cam0),
  .addr_in(rgb_data_counter),
  .addr_out(rgb_data_counter_out),
  .we(buffer_we_cam0),
  .data_out(read_data_cam0),
  .data_in(write_data_cam0)
);

buffer buffer_cam1(
  .clk(buffer_clock_cam1),
  .addr_in(rgb_data_counter-307200),
  .addr_out(rgb_data_counter_out),
  .we(buffer_we_cam1),
  .data_out(read_data_cam1),
  .data_in(write_data_cam1)
);

always @(posedge clk25)
begin
    if(!buffer_we_cam0) begin
        rgb_data_counter_out <= (((y * 640) - 640) + x);
        color <= { read_data_cam0[7:3], 3'b000 ,read_data_cam0[7:3], 3'b000 ,read_data_cam0[7:3], 3'b000 };
    end
    else if(!buffer_we_cam1) begin
        rgb_data_counter_out <= (((y * 640) - 640) + x);
        color <= { read_data_cam1[7:3], 3'b000 ,read_data_cam1[7:3], 3'b000 ,read_data_cam1[7:3], 3'b000 };
    end    
    else begin
        color <= 24'hffffff;
    end
end

always @(posedge pixel_clock)
begin

 if( ({rgb_enable_current_cam, last_rgb_enable} == 2'b10))
   begin
      if(frame_start_current_cam)
          rgb_data_counter <= 1'b0;

      rgb_data_counter <= rgb_data_counter + 1'b1;

      if(rgb_data_counter<307200) // 640x480 CAM0
      begin
          write_data_cam0 <= rgb_current_cam;
      end
      else if(rgb_data_counter==307200) // 640x480 CAM0
      begin
          last_rgb_enable <= 0;
          frame_start_current_cam <= 0;
          cam0 <= 1'b0;
          buffer_we_cam0 <= 1'b0;
          buffer_we_cam1 <= 1'b1;          
      end              
      else if(rgb_data_counter>307200 && rgb_data_counter<614400) // 640x480 - CAM1
      begin
          write_data_cam1 <= rgb_current_cam;
      end
      else if(rgb_data_counter == 614400) // 640x480 - CAM1
      begin
          cam0 <= 1'b1;
          buffer_we_cam0 <= 1'b1;
          buffer_we_cam1 <= 1'b0;
          frame_start_current_cam <= 0; 
          rgb_data_counter <= 0;
          last_rgb_enable <= 0;
      end
      else begin
          cam0 <= 1'b1;
          buffer_we_cam0 <= 1'b1;
          buffer_we_cam1 <= 1'b0;       
      end
   end
  last_rgb_enable <= image_data_enable_current_cam;
end

always @(posedge buffer_clock_cam0)
begin
    counter1 <= counter1 + 1'b1;
end

assign led[7:0] = 8'b0; //counter0[26:19];
endmodule


/* Not implemented
rgb565 rgb565_i(
    .image_data(image_data),
    .image_data_enable(image_data_enable_current_cam),
    .rgb(rgb),
    .rgb_enable(rgb_enable)
);
*/

/* Not implemented
rgb888 rgb888_i(
    .clock_p(cam0_clk_p),
    .clock_n(~cam0_clk_p),
    .image_data(image_data),
    .image_data_enable(image_data_enable_current_cam),
    .rgb(rgb),
    .rgb_enable(rgb_enable)
);
*/
