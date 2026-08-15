`timescale 1ns / 1ps

// ============================================================================
// Module Name  : new_LFSR
// Description  : Dual Linear Feedback Shift Register (LFSR) Generator
//                Produces two pseudo-random data streams (data1, data2)
//                with zero-state error detection and enable control.
// Target Board : FPGA / Generic RTL
// Parameters   : DATA_WIDTH - Bit width of the LFSR registers (Default: 6)
// ============================================================================

module new_LFSR #(
    parameter DATA_WIDTH = 6
)(
    // --- Clock and Control Signals ---
    input  wire                  clk,         // System Clock
    input  wire                  reset,       // Asynchronous Reset (Active High)
    input  wire                  enable_lfsr, // Enable control signal from Top Module (Active High)
    
    // --- Data Input / Output Ports ---
    input  wire [DATA_WIDTH-1:0] data_in,     // Initial seed value loaded during reset
    output reg  [DATA_WIDTH-1:0] data1,       // Pseudo-random Data Stream 1
    output reg  [DATA_WIDTH-1:0] data2,       // Pseudo-random Data Stream 2
    output reg  [0:0]            o_ERR        // Zero-state Lockup Error Flag (Active High)
);

    // ------------------------------------------------------------------------
    // Feedback Polynomial Taps (XOR Operations for Pseudo-Random Sequence)
    // ------------------------------------------------------------------------
    wire [0:0] feedback1 = data1[DATA_WIDTH-1] ^ data1[DATA_WIDTH-6];
    wire [0:0] feedback2 = data2[DATA_WIDTH-1] ^ data2[DATA_WIDTH-4];

    // ------------------------------------------------------------------------
    // LFSR Sequential Logic & State Updates
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        // Top module enable check: System operates only when enable_lfsr is High
        if (enable_lfsr) begin 
            if (reset) begin
                // Seed loading on reset
                data1 <= data_in;
                data2 <= data_in;
                o_ERR <= 0;
            end else begin
                // Zero-state protection: LFSR registers must be non-zero to shift
                if (data1 != 0 && data2 != 0) begin
                    // Right shift operation with polynomial feedback insertion at MSB
                    data1 <= {feedback1, data1[DATA_WIDTH-1:1]};
                    data2 <= {feedback2, data2[DATA_WIDTH-1:1]};
                    o_ERR <= 0;
                end else begin
                    // Raise error flag if registers fall into invalid zero state (lockup prevention)
                    o_ERR <= 1;
                end
            end
        end
        // Note: When enable_lfsr is Low, registers retain their current values (data hold)
    end

endmodule
