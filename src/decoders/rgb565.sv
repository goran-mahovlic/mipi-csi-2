module rgb565 (
    input logic [31:0] image_data,
    input logic image_data_enable,
    output logic [31:0] rgb,
    output logic rgb_enable
);

logic [31:0] unpacked_image_data;
assign unpacked_image_data = {image_data[31:24], image_data[23:16], image_data[15:8], image_data[7:0]};

assign rgb[15:0] = {unpacked_image_data[15:11], unpacked_image_data[10:5], unpacked_image_data[4:0]};
assign rgb[31:16] = {unpacked_image_data[31:27], unpacked_image_data[26:21], unpacked_image_data[20:16]};
assign rgb_enable = image_data_enable;

endmodule
