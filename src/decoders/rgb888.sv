module rgb888 (
    input logic clock_p,
    input logic clock_n,
    input logic [31:0] image_data,
    input logic image_data_enable,
    output logic [47:0] rgb,
    output logic [1:0] rgb_enable
);

//     Fifo    Memory Order
// 0 = BGRB -> BRGB
// 1 = GRBG -> GBRG
// 2 = RBGR -> RGBR
logic [1:0] state = 2'd0;

logic [31:0] last_upper_image_data;

assign rgb_enable[0] = image_data_enable;
assign rgb_enable[1] = image_data_enable && state == 2'd2;

assign rgb[23:0] = state == 2'd0 ? {image_data[23:16], image_data[15:8], image_data[7:0]}
                 : state == 2'd1 ? {image_data[15:8], image_data[7:0], last_upper_image_data[31:24]}
                 : state == 2'd2 ? {image_data[7:0], last_upper_image_data[31:24], last_upper_image_data[23:16]} 
                 : 0;


assign rgb[47:24] = {image_data[31:24], image_data[23:16], image_data[15:8]};

always @(posedge clock_p or posedge clock_n)
begin
    if (image_data_enable)
    begin
        state <= state == 2'd2 ? 2'd0 : state + 2'd1;
        last_upper_image_data <= image_data[31:16];
    end
end

endmodule
