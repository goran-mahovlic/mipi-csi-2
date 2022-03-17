module camera #(
    parameter int NUM_LANES = 2,
    // Gives the underlying d_phy_receivers resistance to noise by expecting 0s before a sync sequence
    parameter int ZERO_ACCUMULATOR_WIDTH = 2,
    parameter [1:0] VC = 2'b00,                // MIPI CSI-2 "virtual channel"
    parameter [5:0] FS_DT = 6'h00,             // Frame start data type
    parameter [5:0] FE_DT = 6'h01,             // Frame end data type
    parameter [5:0] VIDEO_DT = 6'h2B           // Video payload data type (6'h2A = 8-bit raw, 6'h2B = 10-bit raw, 6'h2C = 12-bit raw)
) (
    input logic clock_p,
    input logic [NUM_LANES-1:0] data_p,
    // Corresponding virtual channel for the image data
    output logic [1:0] virtual_channel,
    // Total number of words in the current packet
    output logic [15:0] word_count,

    output logic interrupt,

    // See Section 12 for how this should be parsed
    //output logic [7:0] image_data [3:0], // = '{8'd0, 8'd0, 8'd0, 8'd0},
    output logic [31:0] image_data,
    output logic [5:0] image_data_type,
    // Whether there is output data ready
    output logic image_data_enable,

    output logic frame_start,
    output logic frame_end,
    output logic line_start,
    output logic line_end,

    // The  intention  of  the  Generic  Short  Packet  Data  Types  is  to  provide  a  mechanism  for  including  timing 
    // information for the opening/closing of shutters, triggering of flashes, etc within the data stream.
    output logic generic_short_data_enable,
    output logic [15:0] generic_short_data,
    output logic valid_packet,

    output logic  vsync,
    output logic in_frame,
    output logic in_line,

    output payload_frame,
    output payload_enable
);

logic [NUM_LANES-1:0] reset = NUM_LANES'(0);
logic [8*NUM_LANES-1:0] data;                 // [NUM_LANES-1:0];
logic [NUM_LANES-1:0] enable;

wire video_data;

genvar i;
generate
    for (i = 0; i < NUM_LANES; i++)
    begin: lane_receivers
        d_phy_receiver #(.ZERO_ACCUMULATOR_WIDTH(ZERO_ACCUMULATOR_WIDTH)) d_phy_receiver (
            .clock_p(clock_p),
            .data_p(data_p[i]),
            .reset(reset[i]),
            .data(data[7+8*i:8*i]),
            .enable(enable[i])
        );
    end
endgenerate

//logic [7:0] packet_header [3:0]; //'{8'd0, 8'd0, 8'd0, 8'd0};
logic [31:0] packet_header;

assign virtual_channel = packet_header[7:6];
logic [5:0] data_type;
assign data_type = packet_header[5:0];
assign image_data_type = data_type;

assign frame_start = data_type == 6'd0;
assign frame_end = data_type == 6'd1;
assign line_start = data_type == 6'd2;
assign line_end = data_type == 6'd3;
assign video_data = data_type == VIDEO_DT;
assign generic_short_data_enable = data_type >= 6'd8 && data_type <= 6'hF && reset[0];
assign generic_short_data = word_count;

wire expected_ecc,is_hdr;

assign is_hdr = image_data_enable;

csi_header_ecc ecc_i (
         .data(packet_header[23:0]),
         .ecc(expected_ecc)
        );

assign valid_packet = (virtual_channel == VC) && (frame_start || frame_end || video_data) && (header_ecc == expected_ecc);

assign word_count = {packet_header[23:8]}; // Recall: LSB first
logic [7:0] header_ecc;
assign header_ecc = packet_header[31:24];

logic [2:0] header_index = 3'd0;
logic [16:0] word_counter = 17'd0;
logic [1:0] data_index = 2'd0;

logic already_triggered = 1'd0;
// Count off multiples of four
// Shouldn't be the first byte
assign image_data_enable = data_type >= 6'h18 && data_type <= 6'h2F && data_index == 2'd0 && word_counter != 17'd0 && word_counter <= word_count && !already_triggered;
always_ff @(posedge clock_p) begin
    already_triggered = already_triggered ? enable == NUM_LANES'(0) : image_data_enable;
    if (frame_start)
          in_frame <= 1'b1;
    else if (frame_end)
          in_frame <= 1'b0;
    else if (line_start)
          in_line <= 1'b1;
    else if (line_end)
          in_line <= 1'b0;
    vsync <= (frame_start && valid_packet);
    // payload_frame <= (state == 3'b010);
       payload_enable <= payload_frame && image_data_enable;
    end

assign interrupt = image_data_enable || (reset[0] && data_type <= 6'hF);

integer j;
always_ff @(posedge clock_p)
begin
    //vsync <= (data_type == FS_DT && valid_packet);
    //if (data_type == FS_DT && valid_packet)
    //      in_frame <= 1'b1;
    //else if (data_type == FE_DT && valid_packet)
    //      in_frame <= 1'b0;

    //if (is_hdr && data_type == VIDEO_DT && valid_packet)
    //      in_line <= 1'b1;
    //else if (state != 3'b010 && state != 3'b001)
    //      in_line <= 1'b0;

    // Lane reception
    for (j = 0; j < NUM_LANES; j++)
    begin
        if (enable[j]) // Receive byte
        begin
            `ifdef MODEL_TECH
                $display("Receiving on lane %d", 3'(j + 1));
            `endif
            if (header_index < 3'd4) // Packet header
            begin
                packet_header[7+8*header_index:8*header_index] <= data[7+8*j:8*j];
                
                header_index = header_index + 1'd1;
            end
            else // Long packet receive
            begin
                // Image data (YUV, RGB, RAW)
                if (data_type >= 6'h18 && data_type <= 6'h2F && word_counter < word_count)
                begin
                    //
                    image_data[7+8*data_index:8*data_index] <= data[7+8*j:8*j];  //data[7+8*i:8*i]
                    data_index = data_index + 2'd1; // Wrap-around 4 byte counter
                    payload_frame = 1'b1;
                end
                // Footer
                else
                begin
                  payload_frame = 1'b0;
                end
                word_counter = word_counter + 17'd1;
            end
        end
    end

    // Lane resetting
    for (j = 0; j < NUM_LANES; j++)
    begin
        if (enable != NUM_LANES'(0))
        begin
            if (data_type <= 6'h0F && header_index + 3'(j) >= 3'd4 && !reset[j]) // Reset on short packet end
            begin
                `ifdef MODEL_TECH
                    $display("Resetting lane %d", 3'(j + 1));
                `endif
                reset[j] <= 1'b1;
            end
            else if (header_index + 3'(j) >= 3'd4 && header_index + word_counter + 17'(j) >= 17'(word_count) + 17'd2 + 3'd4 && !reset[j]) // Reset on long packet end
            begin
                `ifdef MODEL_TECH
                    $display("Resetting lane %d", 3'(j + 1));
                `endif
                reset[j] <= 1'b1;
            end
        end
    end
    // Synchronous state reset (next clock)
    // The remaining lanes are in a sticky reset state where they remain reset until the first lane also resets
    if (reset[0]) // Know the entire state is gone for sure if the first lane resets
    begin
        header_index = 3'd0;
        word_counter = 17'd0;
        data_index = 2'd0;
        reset <= NUM_LANES'(0);
        //vsync <= 0;
        //in_frame <= 0;
        //in_line <= 0;
    end
end

endmodule
