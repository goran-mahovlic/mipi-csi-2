module rgb565 (
	image_data,
	image_data_enable,
	rgb,
	rgb_enable
);
	input wire [31:0] image_data;
	input wire image_data_enable;
	output wire [31:0] rgb;
	output wire rgb_enable;
	wire [31:0] unpacked_image_data;
	assign unpacked_image_data = {image_data[24+:8], image_data[16+:8], image_data[8+:8], image_data[0+:8]};
	assign rgb[0+:16] = {unpacked_image_data[15:11], unpacked_image_data[10:5], unpacked_image_data[4:0]};
	assign rgb[16+:16] = {unpacked_image_data[31:27], unpacked_image_data[26:21], unpacked_image_data[20:16]};
	assign rgb_enable = image_data_enable;
endmodule