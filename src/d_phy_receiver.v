module d_phy_receiver (
	clock_p,
	data_p,
	reset,
	data,
	enable
);
	parameter signed [31:0] ZERO_ACCUMULATOR_WIDTH = 3;
	input wire clock_p;
	input wire data_p;
	input wire reset;
	output wire [7:0] data;
	output wire enable;
	reg dataout_h = 1'd0;
	reg dataout_l = 1'd0;
	always @(posedge clock_p) dataout_h <= data_p;
	always @(negedge clock_p) dataout_l <= data_p;
	reg [8:0] internal_data = 9'd0;
	always @(posedge clock_p) internal_data <= {dataout_l, dataout_h, internal_data[8:2]};
	localparam [1:0] STATE_UNKNOWN = 2'd0;
	localparam [1:0] STATE_SYNC_IN_PHASE = 2'd1;
	localparam [1:0] STATE_SYNC_OUT_OF_PHASE = 2'd2;
	reg [1:0] state = STATE_UNKNOWN;
	assign data = (state == STATE_SYNC_IN_PHASE ? internal_data[7:0] : (state == STATE_SYNC_OUT_OF_PHASE ? internal_data[8:1] : 8'bxxxxxxxx));
	reg [1:0] counter = 2'd0;
	assign enable = (state != STATE_UNKNOWN) && (counter == 2'd0);
	function automatic signed [ZERO_ACCUMULATOR_WIDTH - 1:0] sv2v_cast_740FE_signed;
		input reg signed [ZERO_ACCUMULATOR_WIDTH - 1:0] inp;
		sv2v_cast_740FE_signed = inp;
	endfunction
	reg [ZERO_ACCUMULATOR_WIDTH - 1:0] zero_accumulator = sv2v_cast_740FE_signed(0);
	always @(posedge clock_p)
		if (internal_data[1] || internal_data[0])
			zero_accumulator <= sv2v_cast_740FE_signed(0);
		else if ((zero_accumulator + 1'd1) == sv2v_cast_740FE_signed(0))
			zero_accumulator <= zero_accumulator;
		else
			zero_accumulator <= zero_accumulator + 1'd1;
	always @(posedge clock_p)
		if (reset) begin
			state <= STATE_UNKNOWN;
			counter <= 2'bxx;
		end
		else if (state == STATE_UNKNOWN) begin
			if ((internal_data == 9'b101110000) && ((zero_accumulator + 1'd1) == sv2v_cast_740FE_signed(0))) begin
				state <= STATE_SYNC_OUT_OF_PHASE;
				counter <= 2'd3;
			end
			else if ((internal_data[7:0] == 8'b10111000) && ((zero_accumulator + 1'd1) == sv2v_cast_740FE_signed(0))) begin
				state <= STATE_SYNC_IN_PHASE;
				counter <= 2'd3;
			end
			else begin
				state <= STATE_UNKNOWN;
				counter <= 2'bxx;
			end
		end
		else begin
			state <= state;
			counter <= counter - 2'd1;
		end
endmodule