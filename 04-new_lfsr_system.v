`timescale 1ns / 1ps

// ============================================================================
// Module Name  : new_lfsr_system
// Description  : 8-Bit Maximal-Length Linear Feedback Shift Register (LFSR)
//                - Polynomial  : x^8 + x^6 + x^5 + x^4 + 1 (Period: 255 cycles)
//                - Architecture: Idle-by-default (resets to 0 to save dynamic power)
//                - Protection  : Rejects 0-seed loading to prevent invalid states
// ============================================================================

module new_lfsr_system (
    input  wire        clk         , // System clock
    input  wire        reset       , // Active-low asynchronous reset
    input  wire        lfsr_enable , // Module enable control signal
    input  wire        load_enable , // Synchronous seed load enable
    input  wire  [7:0] data_in     , // 8-bit initial seed input
    output wire  [7:0] data_out    , // 8-bit pseudo-random output
    output wire        completed     // High when full 255-cycle sequence finishes
);

    // ------------------------------------------------------------------------
    // Internal Registers & Wires
    // ------------------------------------------------------------------------
    reg  [7:0] r_data_out; // Current LFSR shift register state
    reg  [7:0] counter   ; // 8-bit cycle counter tracking sequence progress

    // XOR feedback bit derived from maximal-length polynomial taps
    wire feedback_bit = r_data_out[7] ^ r_data_out[5] ^ r_data_out[4] ^ r_data_out[3];

    // Combinational flag asserted upon reaching the maximum sequence length (255)
    assign completed = (counter == (2**8) - 1);

    // ------------------------------------------------------------------------
    // Sequential Logic
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            // Initialize in idle state (0) to avoid unnecessary switching power
            r_data_out <= 8'd0;
            counter    <= 8'd0;
        end 
        else if (lfsr_enable) begin
            // Zero-seed guard: Load seed only if data_in is non-zero
            if (load_enable && (data_in != 8'd0)) begin
                r_data_out <= data_in;
                counter    <= 8'd0;
            end 
            // Shift left and insert feedback bit until full period is completed
            else if (!completed) begin
                r_data_out <= {r_data_out[6:0], feedback_bit};
                counter    <= counter + 1'b1;
            end
        end
    end

    // Drive output port from internal state register
    assign data_out = r_data_out;

endmodule
