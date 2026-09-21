`timescale 1ns / 1ps

/**
 * Module: multiplier
 * Description: Combinational Shift-and-Add Multiplier with parametric data width.
 */
module multiplier #(
    parameter DATA_WIDTH = 6                  // Bit width of the input operands
)(
    input  wire [DATA_WIDTH-1:0]   A,         // Multiplier input
    input  wire [DATA_WIDTH-1:0]   B,         // Multiplicand input
    input  wire                    multiplier_enable, // Enable signal for multiplication
    output wire [DATA_WIDTH*2-1:0] data_out   // Product output (2 * DATA_WIDTH wide)
);

    // Internal register to calculate the multiplication result
    reg [DATA_WIDTH*2-1:0] r_data_out;         

    integer i; // Loop index variable

    // Combinational logic block
    always @(*) begin
        r_data_out = 0; // Initialize result to zero to avoid latch synthesis
        
        if (multiplier_enable) begin
            // Shift-and-Add algorithm implementation
            for (i = 0; i < DATA_WIDTH; i = i + 1) begin
                if (B[i] == 1'b1) begin
                    // If current bit of B is 1, shift A by 'i' positions and add to accumulative result
                    r_data_out = r_data_out + (A << i);
                end
            end
        end
    end

    // Assign internal result register to output wire
    assign data_out = r_data_out;

endmodule
