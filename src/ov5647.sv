module ov5647 #(
    parameter int INPUT_CLK_RATE,
    parameter int TARGET_SCL_RATE = 400000,
    // Some ov5647 modules have a different address, change this if yours does
    parameter bit [7:0] ADDRESS = 8'h6c
) (
    input logic clk_in,
    inout wire scl,
    inout wire sda,
    // 0 = Power off
    // 1 = Software standby
    // 2 = Streaming
    input logic [1:0] mode,

    // 0 = 3280x2464
    // 1 = 1920x1080
    // 2 = 1640x1232
    // 3 = 640x480
    input logic [1:0] resolution,
    // 0 = RAW8
    // 1 = RAW10
    input logic format,
    // input logic horizontal_flip,
    // input logic vertical_flip,
    // input logic [7:0] analog_gain,
    // input logic [15:0] digital_gain,
    // input logic [15:0] exposure, // aka integration time

    // Goes high when inputs match sensor state
    // Changing inputs when the sensor isn't ready could put the sensor into an unexpected state
    output logic ready,
    output logic power_enable,
    // ov5647 Model ID did not match
    output logic model_err = 1'b0,
    output logic nack_err = 1'b0
);

logic bus_clear;

logic transfer_start = 1'b0;
logic transfer_continues = 1'b0;
logic [7:0] address;
logic [7:0] data_tx = 8'd0;

logic transfer_ready;
logic interrupt;
logic transaction_complete;
logic nack;
logic [7:0] data_rx;
logic address_err;

i2c_master #(.INPUT_CLK_RATE(INPUT_CLK_RATE), .TARGET_SCL_RATE(TARGET_SCL_RATE)) i2c_master (
    .scl(scl),
    .clk_in(clk_in),
    .bus_clear(bus_clear),
    .sda(sda),
    .address(address),
    .transfer_start(transfer_start),
    .transfer_continues(transfer_continues),
    .data_tx(data_tx),
    .transfer_ready(transfer_ready),
    .interrupt(interrupt),
    .transaction_complete(transaction_complete),
    .nack(nack),
    .data_rx(data_rx),
    .address_err(address_err)
);

logic [15:0] MODEL_ID = 16'h5647;

logic [24:0] PRE_STANDBY [0:2];

initial begin
    PRE_STANDBY[0] = {1'b1, 16'h300a, MODEL_ID[15:8]};   // Read module_model_id high
    PRE_STANDBY[1] = {1'b1, 16'h300b, MODEL_ID[7:0]};    // Read module_model_id low
    PRE_STANDBY[2] = {1'b0, 16'h0100, 8'd0};             // mode_select <= standby
end

logic [24:0] PRE_STREAM [0:88];

initial begin
    PRE_STREAM[0] =   {1'b0, 16'h3034, 8'h08}; // PLL ctrl0: mipi 10 bit mode
    PRE_STREAM[1] =   {1'b0, 16'h3035, 8'h41}; // SC common PLL ctrl1:  system_clk_div by 4, scale_divider_mipi by 1
    PRE_STREAM[2] =   {1'b0, 16'h3036, 8'h46}; // PLL multiplier: times 70
    PRE_STREAM[3] =   {1'b0, 16'h303c, 8'h11}; // PLLS ctrl2: plls_cp 1, plls_sys_div by 1
    PRE_STREAM[4] =   {1'b0, 16'h3106, 8'hf5}; // SRB ctrl: pll_sclk / 4, enable sclk to arbiter
    PRE_STREAM[5] =   {1'b0, 16'h3821, 8'h07}; // Timing TC: r_mirror_isp, r_mirror_snr, r_hbin
    PRE_STREAM[6] =   {1'b0, 16'h3820, 8'h41}; // Timing TC: r_vbin, 1 unknown setting
    PRE_STREAM[7] =   {1'b0, 16'h3827, 8'hec}; // Debug mode
    PRE_STREAM[8] =   {1'b0, 16'h370c, 8'h0f}; // ???
    PRE_STREAM[9] =   {1'b0, 16'h3612, 8'h59}; // ???
    PRE_STREAM[10] =   {1'b0, 16'h3618, 8'h00}; // ???
    PRE_STREAM[11] =   {1'b0, 16'h5000, 8'h06}; // Black/white pixel cancellation
    PRE_STREAM[12] =   {1'b0, 16'h5001, 8'h01}; // Auto-white balance
    PRE_STREAM[13] =   {1'b0, 16'h5002, 8'h41}; // Auto-white balance gain, Win enable
    PRE_STREAM[14] =   {1'b0, 16'h5003, 8'h08}; // Buffer enable
    PRE_STREAM[15] =   {1'b0, 16'h5a00, 8'h08}; // Unused bit set, not sure why
    PRE_STREAM[16] =   {1'b0, 16'h3000, 8'h00}; // ???
    PRE_STREAM[17] =   {1'b0, 16'h3001, 8'h00}; // ???
    PRE_STREAM[18] =   {1'b0, 16'h3002, 8'h00}; // ???
    PRE_STREAM[19] =   {1'b0, 16'h3016, 8'h08}; // Mipi enable
    PRE_STREAM[20] =   {1'b0, 16'h3017, 8'he0}; // pgm_vcm = 11, pgm_lptx = 10
    PRE_STREAM[21] =   {1'b0, 16'h3018, 8'h44}; // Mipi two lane, mipi enable
    PRE_STREAM[22] =   {1'b0, 16'h301c, 8'hf8}; // ???
    PRE_STREAM[23] =   {1'b0, 16'h301d, 8'hf0}; // ???
    PRE_STREAM[24] =   {1'b0, 16'h3a18, 8'h00}; // aec gain ceiling = 248
    PRE_STREAM[25] =   {1'b0, 16'h3a19, 8'hf8}; // ctd.
    PRE_STREAM[26] =   {1'b0, 16'h3c01, 8'h80}; // 50/60 Hz detection
    PRE_STREAM[27] =   {1'b0, 16'h3b07, 8'h0c}; // exposure time
    PRE_STREAM[28] =   {1'b0, 16'h380c, 8'h07}; // total horizontal size = 1896
    PRE_STREAM[29] =   {1'b0, 16'h380d, 8'h68}; // ctd.
    PRE_STREAM[30] =   {1'b0, 16'h380e, 8'h03}; // total vertical size = 984
    PRE_STREAM[31] =   {1'b0, 16'h380f, 8'hd8}; // ctd.
    PRE_STREAM[32] =   {1'b0, 16'h3814, 8'h31}; // horizontal subsample odd increase number = 1, horizontal subsample even increase number = 3
    PRE_STREAM[33] =   {1'b0, 16'h3815, 8'h31}; // vertical subsample odd increase number = 1, vertical subsample even increase number = 3
    PRE_STREAM[34] =   {1'b0, 16'h3708, 8'h64}; // ???
    PRE_STREAM[35] =   {1'b0, 16'h3709, 8'h52}; // ???
    PRE_STREAM[36] =   {1'b0, 16'h3808, 8'h02}; // x output size = 640
    PRE_STREAM[37] =   {1'b0, 16'h3809, 8'h80}; // ctd.
    PRE_STREAM[38] =   {1'b0, 16'h380a, 8'h01}; // y output size = 480
    PRE_STREAM[39] =   {1'b0, 16'h380b, 8'he0}; // ctd.
    PRE_STREAM[40] =   {1'b0, 16'h3800, 8'h00}; // x addr start = 0
    PRE_STREAM[41] =   {1'b0, 16'h3801, 8'h00}; // ctd.
    PRE_STREAM[42] =   {1'b0, 16'h3802, 8'h00}; // y addr start = 0
    PRE_STREAM[43] =   {1'b0, 16'h3803, 8'h00}; // ctd.
    PRE_STREAM[44] =   {1'b0, 16'h3804, 8'h0a}; // x addr end = 2623
    PRE_STREAM[45] =   {1'b0, 16'h3805, 8'h3f}; // ctd.
    PRE_STREAM[46] =   {1'b0, 16'h3806, 8'h07}; // y addr end = 1953
    PRE_STREAM[47] =   {1'b0, 16'h3807, 8'ha1}; // ctd.
    PRE_STREAM[48] =   {1'b0, 16'h3811, 8'h08}; // ISP horizontal offset = 8
    PRE_STREAM[49] =   {1'b0, 16'h3813, 8'h02}; // ISP vertical offset = 2
    PRE_STREAM[50] =   {1'b0, 16'h3630, 8'h2e};
    PRE_STREAM[51] =   {1'b0, 16'h3632, 8'he2};
    PRE_STREAM[52] =   {1'b0, 16'h3633, 8'h23};
    PRE_STREAM[53] =   {1'b0, 16'h3634, 8'h44};
    PRE_STREAM[54] =   {1'b0, 16'h3636, 8'h06};
    PRE_STREAM[55] =   {1'b0, 16'h3620, 8'h64};
    PRE_STREAM[56] =   {1'b0, 16'h3621, 8'he0};
    PRE_STREAM[57] =   {1'b0, 16'h3600, 8'h37};
    PRE_STREAM[58] =   {1'b0, 16'h3704, 8'ha0};
    PRE_STREAM[59] =   {1'b0, 16'h3703, 8'h5a};
    PRE_STREAM[60] =   {1'b0, 16'h3715, 8'h78};
    PRE_STREAM[61] =   {1'b0, 16'h3717, 8'h01};
    PRE_STREAM[62] =   {1'b0, 16'h3731, 8'h02};
    PRE_STREAM[63] =   {1'b0, 16'h370b, 8'h60};
    PRE_STREAM[64] =   {1'b0, 16'h3705, 8'h1a};
    PRE_STREAM[65] =   {1'b0, 16'h3f05, 8'h02};
    PRE_STREAM[66] =   {1'b0, 16'h3f06, 8'h10};
    PRE_STREAM[67] =   {1'b0, 16'h3f01, 8'h0a};
    PRE_STREAM[68] =   {1'b0, 16'h3a08, 8'h01}; // b50_step = 295
    PRE_STREAM[69] =   {1'b0, 16'h3a09, 8'h27}; // ctd.
    PRE_STREAM[70] =   {1'b0, 16'h3a0a, 8'h00}; // b60_step = 246
    PRE_STREAM[71] =   {1'b0, 16'h3a0b, 8'hf6}; // ctd.
    PRE_STREAM[72] =   {1'b0, 16'h3a0d, 8'h04}; // b60_max = 4
    PRE_STREAM[73] =   {1'b0, 16'h3a0e, 8'h03}; // b50_max = 3
    PRE_STREAM[74] =   {1'b0, 16'h3a0f, 8'h58}; // WPT stable range high limit
    PRE_STREAM[75] =   {1'b0, 16'h3a10, 8'h50}; // BPT stable range low limit
    PRE_STREAM[76] =   {1'b0, 16'h3a1b, 8'h58}; // WPT2 stable range high limit
    PRE_STREAM[77] =   {1'b0, 16'h3a1e, 8'h50}; // BPT2 stable range low limit
    PRE_STREAM[78] =   {1'b0, 16'h3a11, 8'h60}; // High VPT
    PRE_STREAM[79] =   {1'b0, 16'h3a1f, 8'h28}; // Low VPT
    PRE_STREAM[80] =   {1'b0, 16'h4001, 8'h02}; // Start line = 2
    PRE_STREAM[81] =   {1'b0, 16'h4004, 8'h02}; // blc line num = 2
    PRE_STREAM[82] =   {1'b0, 16'h4000, 8'h09}; // adc11bit mode, blc enable
    PRE_STREAM[83] =   {1'b0, 16'h4837, 8'h24}; // PCLK_PERIOD
    PRE_STREAM[84] =   {1'b0, 16'h4050, 8'h6e}; // BLC max
    PRE_STREAM[85] =   {1'b0, 16'h4051, 8'h8f}; // BLC stable range
//    PRE_STREAM[86] =   {1'b0, 16'h503d, 8'b00000000}; // test pattern control
    PRE_STREAM[86] =   {1'b0, 16'h503d, 8'h90}; // test pattern control
    PRE_STREAM[87] =   {1'b0, 16'h4800, 8'b00000100}; // MIPI ctrl
    PRE_STREAM[88] =   {1'b0, 16'h0100, 8'h01};
end

logic [24:0] POST_STREAM [0:0];

initial begin
    POST_STREAM[0] = {1'b0, 16'h0100, 8'h00}; // Send to standby
end

// 0 = Off
// 1 = Pre-Standby
// 2 = Standby
// 3 = Pre-Stream
// 4 = Stream
// 5 = Modify Stream
// 6 = Post Stream (shutting down)
// 7 = Error
logic [2:0] sensor_state = 3'd0;

logic [7:0] rom_counter = 8'd0;
logic [1:0] byte_counter = 2'd0;

// Uninit, Standby, or Stream
assign ready = sensor_state == 3'd0 || sensor_state == 3'd2 || sensor_state == 3'd4;

assign power_enable = sensor_state != 3'd0;

logic [7:0] rom_end;
assign rom_end = sensor_state == 3'd1 ? 8'd2 : sensor_state == 3'd3 ? 8'd88 : sensor_state == 3'd6 ? 8'd0 : 8'd0;

logic [24:0] current_rom;
assign current_rom = sensor_state == 3'd1 ? PRE_STANDBY[rom_counter] : sensor_state == 3'd3 ? PRE_STREAM[rom_counter] : sensor_state == 3'd6 ? POST_STREAM[rom_counter] : 25'd0;

always @(posedge clk_in)
begin
    case (sensor_state)
        3'd0: begin 
			if (mode != 2'd0)
				sensor_state <= 3'd1;
        end
        3'd1, 3'd3, 3'd6: begin
			if (interrupt || transfer_ready)
			begin
				if (interrupt && (address_err || (!address[0] && nack))) // Catch write nacks
				begin
					transfer_start <= 1'b0;
					transfer_continues <= 1'b0;
					byte_counter <= 2'd0;
					rom_counter <= 8'd0;
					nack_err <= 1'd1;
					//sensor_state <= 3'd7;
				end
				else if (transfer_ready && byte_counter == 2'd0) // Write address MSB
				begin
					transfer_start <= 1'd1;
					transfer_continues <= 1'd1;
					address <= {ADDRESS[7:1], 1'b0};
					data_tx <= current_rom[23:16];
					byte_counter <= 2'd1;
				end
				else if (interrupt && byte_counter == 2'd1) // Write address LSB
				begin
					transfer_start <= 1'd0;
					transfer_continues <= !current_rom[24];
					data_tx <= current_rom[15:8];
					byte_counter <= 2'd2;
				end
				else if (interrupt && byte_counter == 2'd2) // Write/Read register
				begin
					transfer_start <= current_rom[24];
					transfer_continues <= 1'd0;
					if (current_rom[24])
						address <= {ADDRESS[7:1], 1'b1};
					data_tx <= current_rom[7:0];
					byte_counter <= 2'd3;
				end
				else if (interrupt && byte_counter == 2'd3) // Readback
				begin
					transfer_start <= 1'd0;
					transfer_continues <= 1'd0;
					byte_counter <= 2'd0;

					if (current_rom[24] && current_rom[7:0] != data_rx) // Read did not match expected
					begin
						rom_counter <= 8'd0;
						if (sensor_state == 3'd1) // was a model error
							model_err <= 1'd1;
						sensor_state <= 3'd7;
					end
					else if (rom_counter == rom_end) // This was the last operation
					begin
						rom_counter <= 8'd0;
						if (sensor_state == 3'd5)
							sensor_state <= 3'd4; // Modifications complete
						else if (sensor_state == 3'd6)
							sensor_state <= mode == 2'd1 ? 3'd2 : 3'd0; // Either go to standby or power off
						else
							sensor_state <= sensor_state + 1'd1; // Pre-standby and Pre-stream
					end
					else
						rom_counter <= rom_counter + 1'd1;
				end
			end
        end
        3'd2: begin
            if (mode == 2'd0)
                sensor_state <= 3'd0;
            else if (mode == 2'd2)
                sensor_state <= 3'd3;
            else
                sensor_state <= 3'd2;
        end
		3'd4: begin
			if (mode != 2'd2)
				sensor_state <= 3'd6;
			else
				sensor_state <= 3'd4;
		end
		3'd5: begin // Not entered, modify support still WIP
		end
        3'd7: begin
            if (mode == 2'd0)
            begin
                model_err <= 1'd0;
                nack_err <= 1'd0;
                sensor_state <= 3'd0;
            end
        end
    endcase
end

endmodule
