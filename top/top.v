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
//assign ftdi_rxd = wifi_txd;
assign wifi_rxd = ftdi_txd;

assign cam_enable = 1'b1;

wire [30:0] cam_clk_counter;
//cam_data0_counter,cam_data1_counter;
reg [19:0] rgb_data_counter;
reg [18:0] rgb_data_counter_out;

wire cam_clk_p;
wire [1:0] cam_data_p;
wire [1:0] clk;
wire [1:0] data;

ILVDS ILVDS_clk_inst (.A(dsiRX0_clk_dp),.Z(cam_clk_p));
ILVDS ILVDS_data0_inst (.A(dsiRX0_dp[0]),.Z(cam_data_p[0]));
ILVDS ILVDS_data1_inst (.A(dsiRX0_dp[1]),.Z(cam_data_p[1]));

wire [3:0] clks;
wire clk12,clk73;
assign clk12 = clks[0];
assign clk73 = clks[1];

  ecp5pll
  #(
   .in_hz(73000000),
   .out0_hz(12000000), .out0_tol_hz(10000000),
   .out1_hz(73000000), .out1_deg(0), .out1_tol_hz(10000000)
  )
  ecp5pll_inst
  (
    .clk_i(cam_clk_p),
    .clk_o(clks)
  );

wire frame_start,frame_end,line_start,line_end,short_data_enable,interrupt,valid_packet, in_frame, in_line, vsync;
wire image_data_enable;

wire [31:0] image_data;
wire [5:0] image_data_type;
wire [15:0] word_count;
wire [15:0] short_data;
wire payload_frame,payload_enable;

camera #(
   .NUM_LANES(2),
   .ZERO_ACCUMULATOR_WIDTH(3)
)
   camera_i(
    .clock_p(clk73),
    .data_p(cam_data_p),
    .virtual_channel(data),
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
    // The  intention  of  the  Generic  Short  Packet  Data  Types  is  to  provide  a  mechanism  for  including  timing
    // information for the opening/closing of shutters, triggering of flashes, etc within the data stream.
    .generic_short_data_enable(short_data_enable),
    .generic_short_data(short_data),
    .valid_packet(valid_packet),
    .in_line(in_line),
    .in_frame(in_frame)
);

assign led[4] = image_data_enable; //ftdi_rxd; //image_data_enable;

reg [9:0] read_x;
reg [9:0] read_y;
wire [7:0] read_data;
wire [1:0] div;
wire rgb_enable;
wire [31:0] rgb;

rgb565 rgb_i(
    .image_data(image_data),
    .image_data_enable(image_data_enable),
    .rgb(rgb),
    .rgb_enable(rgb_enable)
);

//reg [7:0] buffer[0:307200];
wire [19:0] buffer_counter;

/*
downsample ds_i(
   .pixel_clock(clk73),
   .in_line(in_line),
   .in_frame(in_frame),
   .pixel_data(rgb),
   .data_enable(rgb_enable),

   .read_clock(clk12),
   .read_x(read_x),
   .read_y(read_y),
   .read_q(read_data)
   );
*/

reg buffer_we;
initial buffer_we = 1'b1;

buffer buffer_i(
  .clk(rgb_enable),
  .addr_in(rgb_data_counter),
  .addr_out(rgb_data_counter_out),
  .we(buffer_we),
  .data_out(read_data),
  .data_in(rgb[7:0])
);

reg do_send = 1'b0;
wire uart_busy;
reg uart_write;
reg [12:0] uart_holdoff;
reg [13:0] btn_debounce;
reg btn_reg;
reg [7:0] data_buffer;

uart_tx uart_i (
   .clk(clk12),
   .resetn(1'b1),
   .ser_tx(ftdi_rxd),
   .cfg_divider(12000000/115200),
   .data_we(uart_write),
   .data(read_data), //data_buffer),
   .data_wait(uart_busy)
);

always @(posedge clk12)
begin
	//btn_reg <= btn[0];
        btn_reg <= rgb_data_counter[19];
	if (btn_reg)
		btn_debounce <= 0;
	else if (!&(btn_debounce))
		btn_debounce <= btn_debounce + 1;

	uart_write <= 1'b0;
	if (btn_reg && &btn_debounce && !do_send) begin
		do_send <= 1'b1;
		read_x <= 0;
		read_y <= 0;
	end
		if (uart_busy)
			uart_holdoff <= 0;
		else if (!&(uart_holdoff))
			uart_holdoff <= uart_holdoff + 1'b1;

		if (do_send) begin
                        //buffer_we <= 1'b0;
                        rgb_data_counter_out <= {read_y,read_x};
			if (read_x == 0 && read_y == 480) begin
				do_send <= 1'b0;
			end else begin
				if (&uart_holdoff && !uart_busy && !uart_write) begin
					uart_write <= 1'b1;
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

always @(posedge clk73)
begin
  if( {rgb_enable, last_rgb_enable} == 2'b10)
  begin
      // rising edge detected here
      led[3:0] <= rgb[3:0];
      //if (rgb_data_counter == 307200)
      //    buffer_we <= 1'b0;
      if(rgb_data_counter<524289) 
      begin
          buffer_we <= 1'b0;
          rgb_data_counter = rgb_data_counter + 1'b1;
          if(rgb_data_counter<307200) 
          begin
              buffer_we <= 1'b1;
              //buffer[rgb_data_counter] <= {rgb[7:0]};
              //buffer[rgb_data_counter] <= 8'b111111111
          end
      end
  end
  last_rgb_enable <= rgb_enable;
end

endmodule
