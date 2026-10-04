`timescale 1ns / 1ps

// ============================================================================
// Module Name:  lfsr
// Description:  Linear Feedback Shift Register (LFSR) with custom 32-bit
//               formatting and forbidden state detection.
// ============================================================================

module lfsr (
    input wire         clk,       // System clock
    input wire         reset,     // Active-high asynchronous reset
    input wire [22:0]  fraction,  // Initial seed value for the fraction field
    output reg [31:0]  data_out,  // 32-bit formatted output data
    output reg         o_ERR      // Error flag asserted when forbidden state is hit
);

    // XNOR feedback loop using bits 22 and 17 of data_out
    wire feedback = ~(data_out[22] ^ data_out[17]);

    // Forbidden state constant for the 23-bit LFSR section (all ones)
    localparam FORBIDDEN = 23'h7FFFFF;

    // ------------------------------------------------------------------------
    // Sequential LFSR State Machine & Output Generation
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset state initialization:
            // [31]    : Sign bit (1'b0)
            // [30:23] : Exponent initialized to 126
            // [22:0]  : Fraction field loaded with input seed
            data_out <= {1'b0, 8'd126, fraction};
            o_ERR    <= 1'b0;
        end else begin
            if (data_out[22:0] != FORBIDDEN) begin
                // Shift operation with dynamic exponent update and feedback bit injection
                data_out <= {1'b0, (8'd126 - data_out[12:11]), data_out[21:0], feedback};
                o_ERR    <= 1'b0;
            end else begin
                // Lock detected / Forbidden state reached
                o_ERR    <= 1'b1;
            end
        end
    end

endmodule
