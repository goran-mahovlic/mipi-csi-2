module raw8 (
    input logic [31:0] image_data,
    input logic image_data_enable,
    output logic [31:0] raw,
    output logic raw_enable
);
assign raw = image_data;
assign raw_enable = image_data_enable;

endmodule
