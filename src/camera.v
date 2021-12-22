module camera (
	clock_p,
	data_p,
	virtual_channel,
	word_count,
	interrupt,
	image_data,
	image_data_type,
	image_data_enable,
	frame_start,
	frame_end,
	line_start,
	line_end,
	generic_short_data_enable,
	generic_short_data,
        valid_packet,
        video_data,
        in_frame,
        in_line
);
	parameter signed [31:0] NUM_LANES = 2;
	parameter signed [31:0] ZERO_ACCUMULATOR_WIDTH = 3;
        parameter signed [1:0] VC = 2'b00;
        parameter [5:0] VIDEO_DT = 6'h2B;
	input wire clock_p;
	input wire [NUM_LANES - 1:0] data_p;
	output wire [1:0] virtual_channel;
	output wire [15:0] word_count;
	output wire interrupt;
	output reg [31:0] image_data = 32'h00000000;
	output wire [5:0] image_data_type;
	output wire image_data_enable;
	output wire frame_start;
	output wire frame_end;
	output wire line_start;
	output wire line_end;
        output wire valid_packet;
        output wire video_data;
        output wire in_frame;
        output wire in_line;
	output wire generic_short_data_enable;
	output wire [15:0] generic_short_data;
	function automatic signed [NUM_LANES - 1:0] sv2v_cast_F4A11_signed;
		input reg signed [NUM_LANES - 1:0] inp;
		sv2v_cast_F4A11_signed = inp;
	endfunction
	reg [NUM_LANES - 1:0] reset = sv2v_cast_F4A11_signed(0);
	wire [7:0] data [NUM_LANES - 1:0];
	wire [NUM_LANES - 1:0] enable;
        wire [7:0] expected_ecc;

        csi_header_ecc ecc_i (
            .data(packet_header[23:0]),
            .ecc(expected_ecc)
        );

        assign valid_packet = (virtual_channel == VC) && (frame_start || frame_end || video_data) && (header_ecc == expected_ecc);

	genvar i;
	generate
		for (i = 0; i < NUM_LANES; i = i + 1) begin : lane_receivers
			d_phy_receiver #(.ZERO_ACCUMULATOR_WIDTH(ZERO_ACCUMULATOR_WIDTH)) d_phy_receiver(
				.clock_p(clock_p),
				.data_p(data_p[i]),
				.reset(reset[i]),
				.data(data[i]),
				.enable(enable[i])
			);
		end
	endgenerate
	reg [31:0] packet_header = 32'h00000000;
	assign virtual_channel = packet_header[7-:2];
	wire [5:0] data_type;
	assign data_type = packet_header[5-:6];
	assign image_data_type = data_type;
	assign frame_start = data_type == 6'd0;
	assign frame_end = data_type == 6'd1;
	assign line_start = data_type == 6'd2;
	assign line_end = data_type == 6'd3;
        assign video_data = data_type == VIDEO_DT;
	assign generic_short_data_enable = ((data_type >= 6'd8) && (data_type <= 6'h0f)) && reset[0];
	assign generic_short_data = word_count;
	assign word_count = {packet_header[16+:8], packet_header[8+:8]};
	wire [7:0] header_ecc;
	assign header_ecc = packet_header[24+:8];
	reg [2:0] header_index = 3'd0;
	reg [16:0] word_counter = 17'd0;
	reg [1:0] data_index = 2'd0;
	reg already_triggered = 1'd0;
	assign image_data_enable = (((((data_type >= 6'h18) && (data_type <= 6'h2f)) && (data_index == 2'd0)) && (word_counter != 17'd0)) && (word_counter <= word_count)) && !already_triggered;
	always @(posedge clock_p) already_triggered = (already_triggered ? enable == sv2v_cast_F4A11_signed(0) : image_data_enable);
	assign interrupt = image_data_enable || (reset[0] && (data_type <= 6'h0f));
	integer j;
	function automatic signed [2:0] sv2v_cast_3_signed;
		input reg signed [2:0] inp;
		sv2v_cast_3_signed = inp;
	endfunction
	function automatic signed [16:0] sv2v_cast_17_signed;
		input reg signed [16:0] inp;
		sv2v_cast_17_signed = inp;
	endfunction
	function automatic [16:0] sv2v_cast_17;
		input reg [16:0] inp;
		sv2v_cast_17 = inp;
	endfunction


always @(posedge clock_p) begin
    if (frame_start)
          in_frame <= 1'b1;
    else if (frame_end)
          in_frame <= 1'b0;
    else if (line_start)
          in_line <= 1'b1;
    else if (line_end)
          in_line <= 1'b0;
    end



	always @(posedge clock_p) begin
		for (j = 0; j < NUM_LANES; j = j + 1)
			if (enable[j])
				if (header_index < 3'd4) begin
					packet_header[header_index * 8+:8] <= data[j];
					header_index = header_index + 1'd1;
				end
				else begin
					if (((data_type >= 6'h18) && (data_type <= 6'h2f)) && (word_counter < word_count)) begin
						image_data[data_index * 8+:8] <= data[j];
						data_index = data_index + 2'd1;
					end
					word_counter = word_counter + 17'd1;
				end
		for (j = 0; j < NUM_LANES; j = j + 1)
			if (enable != sv2v_cast_F4A11_signed(0))
				if (((data_type <= 6'h0f) && ((header_index + sv2v_cast_3_signed(j)) >= 3'd4)) && !reset[j])
					reset[j] <= 1'b1;
				else if ((((header_index + sv2v_cast_3_signed(j)) >= 3'd4) && (((header_index + word_counter) + sv2v_cast_17_signed(j)) >= (sv2v_cast_17(word_count) + (17'd2 + 3'd4)))) && !reset[j])
					reset[j] <= 1'b1;
		if (reset[0]) begin
			header_index = 3'd0;
			word_counter = 17'd0;
			data_index = 2'd0;
			reset <= sv2v_cast_F4A11_signed(0);
		end
	end
endmodule
