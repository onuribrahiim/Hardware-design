`timescale 1ns / 1ps

// ============================================================================
// Module Name  : top_modul_carpici_lfsr
// Description  : Top-level System Controller. Integrates a Dual LFSR generator
//                and an FSM-based sequential multiplier. Coordinates pseudo-random
//                data generation, data freezing, handshake signaling, and result
//                latching via a central master State Machine.
// Target Board : FPGA / Generic RTL
// Parameters   : DW - Data Width for operands (Default: 6)
// ============================================================================

module top_modul_carpici_lfsr #(
    parameter DW = 6
)(
    // --- System Control Inputs ---
    input  wire              clk,        // System Clock
    input  wire              reset,      // Master Asynchronous Reset (Active High)
    
    // --- Data Input / Output Ports ---
    input  wire [DW-1:0]     data_login, // Seed input for LFSR initialization
    output wire [DW*2-1:0]   data_exit   // Latched double-width final multiplication output
);

    // ------------------------------------------------------------------------
    // Internal Wires and Registers
    // ------------------------------------------------------------------------
    wire [DW-1:0]   r_data1;          // Pseudo-random operand 1 from LFSR
    wire [DW-1:0]   r_data2;          // Pseudo-random operand 2 from LFSR
    wire [0:0]      r_ERR;            // LFSR error status flag
    reg             r_reset;          // Internal reset pulse for LFSR
    reg             r_enable_lfsr;    // Enable control signal for LFSR module
    
    reg             r_enable_carpici; // Enable control signal for multiplier module
    reg             r_rst_carpici;    // Internal reset pulse for multiplier
    wire            reg_sonuc_hazir;  // Multiplier completion flag (Handshake input)
    reg  [DW*2-1:0] data_latch;       // Output register holding the stable product
    wire [DW*2-1:0] r_data_exit;      // Raw result output from multiplier DUT

    // Continuous assignment to drive output port from internal latched register
    assign data_exit = data_latch;

    // ------------------------------------------------------------------------
    // Sub-module Instantiation 1: LFSR Generator (new_LFSR)
    // ------------------------------------------------------------------------
    new_LFSR #(
        .DATA_WIDTH(DW)
    ) new_LFSR_DUT (
        .clk         (clk),
        .reset       (r_reset),
        .enable_lfsr (r_enable_lfsr),
        .data_in     (data_login),
        .data1       (r_data1),
        .data2       (r_data2),
        .o_ERR       (r_ERR)
    );

    // ------------------------------------------------------------------------
    // Sub-module Instantiation 2: Sequential Multiplier (carpici)
    // ------------------------------------------------------------------------
    carpici #(
        .DW(DW)
    ) carpici_DUT (
        .clk             (clk),
        .reset           (r_rst_carpici),
        .enable_carpici  (r_enable_carpici),
        .carpilan        (r_data1),
        .carpan          (r_data2),
        .sonuc           (r_data_exit),
        .sonuc_hazir     (reg_sonuc_hazir)
    );

    // ------------------------------------------------------------------------
    // Master FSM State Definitions
    // ------------------------------------------------------------------------
    reg [2:0] state;
    
    localparam start                 = 3'b000; // Initialize LFSR seed reset
    localparam data_lfsr             = 3'b001; // Generate next pseudo-random pair
    localparam data_carpici_kontrol  = 3'b010; // Freeze LFSR data & issue multiplier reset
    localparam data_carpici          = 3'b011; // Wait for multiplication completion
    localparam DONE                  = 3'b100; // Complete transaction & cycle back

    // ------------------------------------------------------------------------
    // Master State Machine Sequential Logic
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Master Reset Condition: Clear output latch and all internal control signals
            data_latch       <= 0;
            r_rst_carpici    <= 0;
            r_reset          <= 0;
            r_enable_lfsr    <= 0;
            r_enable_carpici <= 0;
            state            <= start;
        end else begin
            case (state)
                
                // --- STATE 0: START ---
                start: begin
                    r_enable_lfsr <= 1;
                    r_reset       <= 1; // Assert pulse to load seed into LFSR
                    state         <= data_lfsr;
                end

                // --- STATE 1: DATA LFSR ---
                data_lfsr: begin
                    r_enable_lfsr <= 1;
                    r_reset       <= 0; // De-assert LFSR reset to start shifting
                    state         <= data_carpici_kontrol;
                end

                // --- STATE 2: DATA CARPICI KONTROL ---
                data_carpici_kontrol: begin
                    r_enable_lfsr    <= 0; // Freeze LFSR outputs (Data stability)
                    r_rst_carpici    <= 1; // Issue 1-cycle reset pulse to multiplier FSM
                    r_enable_carpici <= 1; // Enable multiplier execution
                    state            <= data_carpici;
                end

                // --- STATE 3: DATA CARPICI ---
                data_carpici: begin
                    r_rst_carpici <= 0; // Clear multiplier reset
                    
                    // Handshake check: Wait for multiplier ready flag
                    if (reg_sonuc_hazir) begin
                        data_latch       <= r_data_exit; // Capture stable product
                        r_enable_carpici <= 0;           // Disable multiplier
                        state            <= DONE;
                    end else begin
                        state            <= data_carpici; // Hold state until ready
                    end
                end

                // --- STATE 4: DONE ---
                DONE: begin
                    state <= data_lfsr; // Loop back for continuous streaming execution
                end

                // --- DEFAULT STATE ---
                default: begin
                    state <= start;
                end

            caseend
        end
    end

endmodule
