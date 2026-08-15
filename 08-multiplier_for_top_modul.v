`timescale 1ns / 1ps

// ============================================================================
// Module Name  : carpici
// Description  : Sequential FSM-based Shift-and-Add Multiplier Module.
//                Calculates product of 'carpilan' and 'carpan' using
//                shift-and-add logic across multiple clock cycles.
// Target Board : FPGA / Generic RTL
// Parameters   : DW - Data Width of the operands (Default: 6)
// ============================================================================

module carpici #(
    parameter DW = 6
)(
    // --- Clock and Control Signals ---
    input  wire              clk,             // System Clock
    input  wire              reset,           // Asynchronous Reset (Active High)
    input  wire              enable_carpici,  // System Enable signal from Top Module (Active High)
    
    // --- Data Input Ports ---
    input  wire [DW-1:0]     carpilan,        // Multiplicand input operand
    input  wire [DW-1:0]     carpan,          // Multiplier input operand
    
    // --- Output Ports ---
    output wire [DW*2-1:0]   sonuc,           // Double-width product result output
    output wire [0:0]        sonuc_hazir      // Handshake signal indicating completion (Active High)
);

    // ------------------------------------------------------------------------
    // Internal Registers and Handshake Signals
    // ------------------------------------------------------------------------
    reg [3:0]      state;         // FSM current state register
    reg [DW*2-1:0] r_carpan;      // Internal register for shifting multiplier operand
    reg [DW*2-1:0] r_carpilan;    // Internal register for shifting multiplicand operand
    reg [DW-4:0]   counter;       // Step counter for bit-by-bit multiplication tracking
    reg [DW*2-1:0] r_sonuc;       // Accumulator register holding the running sum / final product
    reg [0:0]      r_sonuc_hazir; // Internal done flag register

    // ------------------------------------------------------------------------
    // FSM State Encoding
    // ------------------------------------------------------------------------
    localparam start   = 4'b0001; // Initial state: Load registers and clear accumulator
    localparam control = 4'b0010; // Check LSB of multiplier and loop/finish condition
    localparam islem   = 4'b0011; // Accumulate shifted multiplicand to result
    localparam DONE    = 4'b0100; // Final state: Operation complete

    // ------------------------------------------------------------------------
    // Output Continuous Assignments
    // ------------------------------------------------------------------------
    assign sonuc       = r_sonuc;
    assign sonuc_hazir = r_sonuc_hazir;

    // ------------------------------------------------------------------------
    // Sequential Finite State Machine (FSM)
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Asynchronous Reset State Initializations
            r_sonuc       <= 0;
            state         <= start;
            counter       <= 0;
            r_carpan      <= 0;
            r_carpilan    <= 0;
            r_sonuc_hazir <= 0;
        end else if (enable_carpici) begin
            case (state)
                
                // --- START STATE ---
                start: begin
                    r_sonuc       <= 0;
                    counter       <= 0;
                    r_sonuc_hazir <= 0;
                    // Zero-extend inputs to double width (DW*2)
                    r_carpilan    <= {{DW{1'b0}}, carpilan};
                    r_carpan      <= {{DW{1'b0}}, carpan};
                    state         <= control;
                end

                // --- CONTROL STATE ---
                control: begin
                    // Check if all bit positions have been processed
                    if (counter == DW) begin
                        state         <= DONE;
                        r_sonuc_hazir <= 1; // Assert done flag for top module handshake
                    end else if (r_carpan[0]) begin
                        // LSB is 1: Proceed to addition state
                        state         <= islem;
                    end else begin
                        // LSB is 0: Shift operands and increment bit counter without adding
                        r_carpan   <= r_carpan >> 1;
                        r_carpilan <= r_carpilan << 1;
                        counter    <= counter + 1;
                    end
                end

                // --- ISLEM (OPERATION) STATE ---
                islem: begin
                    // Accumulate shifted multiplicand into result register
                    r_sonuc    <= r_carpilan + sonuc;
                    r_carpilan <= r_carpilan << 1;
                    r_carpan   <= r_carpan >> 1;
                    counter    <= counter + 1;
                    state      <= control;
                end

                // --- DONE STATE ---
                DONE: begin
                    state <= start; // Ready for next transaction or loop
                end

                // --- DEFAULT STATE ---
                default: begin
                    state <= start;
                end

            endcase
        end
    end

endmodule
