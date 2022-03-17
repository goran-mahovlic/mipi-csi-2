module i2c_core (
	scl,
	clk_in,
	bus_clear,
	sda,
	transfer_start,
	transfer_continues,
	mode,
	data_tx,
	transfer_ready,
	interrupt,
	transaction_complete,
	nack,
	data_rx,
	start_err,
	arbitration_err
);
	parameter signed [31:0] INPUT_CLK_RATE = 0;
	parameter signed [31:0] TARGET_SCL_RATE = 0;
	parameter [0:0] CLOCK_STRETCHING = 0;
	parameter [0:0] MULTI_MASTER = 0;
	parameter signed [31:0] SLOWEST_DEVICE_RATE = 0;
	parameter [0:0] FORCE_PUSH_PULL = 0;
	inout wire scl;
	input wire clk_in;
	output wire bus_clear;
	inout wire sda;
	input wire transfer_start;
	input wire transfer_continues;
	input wire mode;
	input wire [7:0] data_tx;
	output wire transfer_ready;
	output reg interrupt = 1'b0;
	output reg transaction_complete;
	output wire nack;
	output wire [7:0] data_rx;
	output reg start_err = 1'd0;
	output reg arbitration_err = 1'b0;
	localparam signed [31:0] MODE = ($unsigned(TARGET_SCL_RATE) <= 100000 ? 0 : ($unsigned(TARGET_SCL_RATE) <= 400000 ? 1 : ($unsigned(TARGET_SCL_RATE) <= 1000000 ? 2 : -1)));
	localparam signed [31:0] COUNTER_WIDTH = $clog2(($unsigned(INPUT_CLK_RATE) - 1) / $unsigned(TARGET_SCL_RATE));
	function automatic [COUNTER_WIDTH - 1:0] sv2v_cast_7C9AA;
		input reg [COUNTER_WIDTH - 1:0] inp;
		sv2v_cast_7C9AA = inp;
	endfunction
	localparam [COUNTER_WIDTH - 1:0] COUNTER_END = sv2v_cast_7C9AA(($unsigned(INPUT_CLK_RATE) - 1) / $unsigned(TARGET_SCL_RATE));
	function automatic [(COUNTER_WIDTH >= 0 ? COUNTER_WIDTH + 1 : 1 - COUNTER_WIDTH) - 1:0] sv2v_cast_80FF4;
		input reg [(COUNTER_WIDTH >= 0 ? COUNTER_WIDTH + 1 : 1 - COUNTER_WIDTH) - 1:0] inp;
		sv2v_cast_80FF4 = inp;
	endfunction
	function automatic [((COUNTER_WIDTH + 1) >= 0 ? COUNTER_WIDTH + 2 : 1 - (COUNTER_WIDTH + 1)) - 1:0] sv2v_cast_D4D89;
		input reg [((COUNTER_WIDTH + 1) >= 0 ? COUNTER_WIDTH + 2 : 1 - (COUNTER_WIDTH + 1)) - 1:0] inp;
		sv2v_cast_D4D89 = inp;
	endfunction
	localparam [COUNTER_WIDTH - 1:0] COUNTER_HIGH = sv2v_cast_7C9AA((MODE == 0 ? (sv2v_cast_80FF4(COUNTER_END) + 1) / 2 : ((sv2v_cast_D4D89(COUNTER_END) + 1) * 2) / 3));
	localparam [COUNTER_WIDTH - 1:0] COUNTER_RISE = (((($unsigned(INPUT_CLK_RATE) - 1) / 1.0E9) * $unsigned((MODE == 0 ? 1000 : (MODE == 1 ? 300 : (MODE == 2 ? 120 : 0))))) + 1);
	localparam signed [31:0] WAIT_WIDTH = $clog2(($unsigned(INPUT_CLK_RATE) - 1) / $unsigned(SLOWEST_DEVICE_RATE));
	function automatic [WAIT_WIDTH - 1:0] sv2v_cast_6F5C8;
		input reg [WAIT_WIDTH - 1:0] inp;
		sv2v_cast_6F5C8 = inp;
	endfunction
	localparam [WAIT_WIDTH - 1:0] WAIT_END = sv2v_cast_6F5C8(($unsigned(INPUT_CLK_RATE) - 1) / $unsigned(SLOWEST_DEVICE_RATE));
	wire [COUNTER_WIDTH - 1:0] counter;
	function automatic signed [COUNTER_WIDTH - 1:0] sv2v_cast_7C9AA_signed;
		input reg signed [COUNTER_WIDTH - 1:0] inp;
		sv2v_cast_7C9AA_signed = inp;
	endfunction
	reg [COUNTER_WIDTH - 1:0] countdown = sv2v_cast_7C9AA_signed(0);
	reg [3:0] transaction_progress = 4'd0;
	wire release_line;
	assign release_line = ((transaction_progress == 4'd0) && (counter == COUNTER_HIGH)) || (countdown > 0);
	clock #(
		.COUNTER_WIDTH(COUNTER_WIDTH),
		.COUNTER_END(COUNTER_END),
		.COUNTER_HIGH(COUNTER_HIGH),
		.COUNTER_RISE(COUNTER_RISE),
		.MULTI_MASTER(MULTI_MASTER),
		.CLOCK_STRETCHING(CLOCK_STRETCHING),
		.WAIT_WIDTH(WAIT_WIDTH),
		.WAIT_END(WAIT_END),
		.PUSH_PULL((!CLOCK_STRETCHING && !MULTI_MASTER) && FORCE_PUSH_PULL)
	) clock(
		.scl(scl),
		.clk_in(clk_in),
		.release_line(release_line),
		.bus_clear(bus_clear),
		.counter(counter)
	);
	reg sda_internal = 1'b1;
	assign sda = (sda_internal ? 1'bz : 1'b0);
	localparam real TLOW_MIN = (MODE == 0 ? 4.7 : (MODE == 1 ? 1.3 : (MODE == 2 ? 0.5 : 0)));
	localparam real THIGH_MIN = (MODE == 0 ? 4.0 : (MODE == 1 ? 0.6 : (MODE == 2 ? 0.26 : 0)));
	localparam [COUNTER_WIDTH - 1:0] COUNTER_SETUP_REPEATED_START = (($unsigned(INPUT_CLK_RATE) / 1.0E6) * TLOW_MIN);
	localparam [COUNTER_WIDTH - 1:0] COUNTER_BUS_FREE = COUNTER_SETUP_REPEATED_START;
	localparam [COUNTER_WIDTH - 1:0] COUNTER_HOLD_REPEATED_START = (($unsigned(INPUT_CLK_RATE) / 1.0E6) * THIGH_MIN);
	localparam [COUNTER_WIDTH - 1:0] COUNTER_SETUP_STOP = COUNTER_HOLD_REPEATED_START;
	localparam [COUNTER_WIDTH - 1:0] COUNTER_TRANSMIT = sv2v_cast_7C9AA(COUNTER_HIGH / 2);
	localparam [COUNTER_WIDTH - 1:0] COUNTER_RECEIVE = sv2v_cast_7C9AA(COUNTER_HIGH + COUNTER_RISE);
	reg latched_mode;
	reg [7:0] latched_data;
	reg latched_transfer_continues;
	assign data_rx = latched_data;
	reg busy = 1'b0;
	assign transfer_ready = ((counter == COUNTER_HIGH) && !busy) && (countdown == 0);
	reg last_sda = 1'b1;
	always @(posedge clk_in) last_sda <= sda;
	wire start_by_a_master;
	wire stop_by_a_master;
	assign start_by_a_master = (last_sda && !sda) && scl;
	assign stop_by_a_master = (!last_sda && sda) && scl;
	assign nack = sda;
	always @(posedge clk_in) begin
		start_err = (MULTI_MASTER && start_by_a_master) && !((transaction_progress == 4'd0) || (((transaction_progress == 4'd11) && transfer_start) && (counter == COUNTER_RECEIVE)));
		arbitration_err = MULTI_MASTER && ((((((counter == COUNTER_RECEIVE) && (transaction_progress >= 4'd2)) && (transaction_progress < 4'd10)) && !latched_mode) && (sda != latched_data[4'd9 - transaction_progress])) && !start_err);
		transaction_complete = (((counter == (COUNTER_RECEIVE - 2)) && (transaction_progress == ((COUNTER_RECEIVE - 2) == COUNTER_TRANSMIT ? 4'd9 : 4'd10))) && !start_err) && !arbitration_err;
		interrupt = (start_err || arbitration_err) || transaction_complete;
		if (start_err || arbitration_err) begin
			sda_internal <= 1'b1;
			transaction_progress <= 4'd0;
			countdown <= sv2v_cast_7C9AA_signed(0);
			busy <= 1'b1;
		end
		else if (countdown != sv2v_cast_7C9AA_signed(0))
			countdown <= countdown - 1'b1;
		else if (((transaction_progress == 4'd0) && !(transfer_start && (counter == COUNTER_HIGH))) && MULTI_MASTER)
			busy <= (busy ? !stop_by_a_master : start_by_a_master);
		else if (counter == COUNTER_HIGH) begin
			if (((transaction_progress == 4'd0) || (transaction_progress == 4'd11)) && transfer_start) begin
				if (transaction_progress == 4'd0)
					transaction_progress <= 4'd1;
				latched_mode <= mode;
				latched_data <= data_tx;
				latched_transfer_continues <= transfer_continues;
			end
			if (transaction_progress == 4'd11)
				if (transfer_start && (COUNTER_SETUP_REPEATED_START > (COUNTER_RECEIVE - COUNTER_HIGH)))
					countdown <= COUNTER_SETUP_REPEATED_START - (COUNTER_RECEIVE - COUNTER_HIGH);
				else if (COUNTER_SETUP_STOP > (COUNTER_RECEIVE - COUNTER_HIGH))
					countdown <= COUNTER_SETUP_STOP - (COUNTER_RECEIVE - COUNTER_HIGH);
		end
		else if (counter == COUNTER_RECEIVE) begin
			if (transaction_progress == 4'd0)
				sda_internal <= 1'b1;
			else if (((transaction_progress == 4'd1) || (transaction_progress == 4'd11)) && transfer_start) begin
				transaction_progress <= 4'd1;
				sda_internal <= 1'b0;
				if ((transaction_progress == 4'd11) && (COUNTER_HOLD_REPEATED_START > (COUNTER_END - COUNTER_RECEIVE)))
					countdown <= COUNTER_HOLD_REPEATED_START - (COUNTER_END - COUNTER_RECEIVE);
				busy <= 1'b1;
			end
			else if (((transaction_progress >= 4'd2) && (transaction_progress < 4'd10)) && latched_mode) begin
				latched_data[4'd9 - transaction_progress] <= sda;
				sda_internal <= 1'b1;
			end
			else if (((transaction_progress == 4'd10) && latched_transfer_continues) && (mode || !nack)) begin
				transaction_progress <= 4'd1;
				latched_mode <= mode;
				latched_data <= data_tx;
				latched_transfer_continues <= transfer_continues;
			end
			else if ((transaction_progress == 4'd11) && !transfer_start) begin
				sda_internal <= 1'b1;
				transaction_progress <= 4'd0;
				if (COUNTER_BUS_FREE > (COUNTER_END - COUNTER_RECEIVE))
					countdown <= COUNTER_BUS_FREE - (COUNTER_END - COUNTER_RECEIVE);
				busy <= 1'b0;
			end
		end
		else if ((counter == COUNTER_TRANSMIT) && (transaction_progress != 4'd0)) begin
			transaction_progress <= transaction_progress + 4'd1;
			if (transaction_progress < 4'd9) begin
				if (!latched_mode)
					sda_internal <= latched_data[4'd8 - transaction_progress];
				else
					sda_internal <= 1'b1;
			end
			else if (transaction_progress == 4'd9)
				sda_internal <= (latched_mode ? !transfer_continues : 1'b1);
			else if (transaction_progress == 4'd10)
				sda_internal <= transfer_start;
		end
	end
endmodule
