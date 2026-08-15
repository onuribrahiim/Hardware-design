`timescale 1ns / 1ps

// ============================================================================
// Module Name  : tb_top_modul_carpici_lfsr
// Description  : Testbench module for verifying top_modul_carpici_lfsr.
//                Generates system clock, applies initial reset, and drives 
//                random seed values across test execution cycles.
// Target Board : FPGA / Generic RTL Simulation
// Parameters   : DW - Data Width matching the top module (Default: 6)
// ============================================================================

module tb_top_modul_carpici_lfsr();

    // ------------------------------------------------------------------------
    // Parameter & Signal Declarations
    // ------------------------------------------------------------------------
    parameter DW = 6;

    reg              clk;        // System clock signal
    reg              reset;      // Master reset signal (Active High)
    reg  [DW-1:0]    data_login; // Seed input for LFSR initialization
    wire [DW*2-1:0]  data_exit;  // Final product output from Top Module

    // ------------------------------------------------------------------------
    // Device Under Test (DUT) Instantiation
    // ------------------------------------------------------------------------
    top_modul_carpici_lfsr #(
        .DW(DW)
    ) top_modul_carpici_lfsr_dut (
        .clk        (clk),
        .reset      (reset),
        .data_login (data_login),
        .data_exit  (data_exit)
    );

    // ------------------------------------------------------------------------
    // Clock Generator Process (20ns Clock Period)
    // ------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // ------------------------------------------------------------------------
    // Main Test Stimulus Sequence
    // ------------------------------------------------------------------------
    initial begin
        // Assert reset at start
        reset = 1;
        #20;
        reset = 0; // Release reset to start FSM execution

        // Execute 10 consecutive simulation runs
        repeat(10) begin
            data_login = $random % (2**DW); // Drive pseudo-random seed
            #3000;                          // Allow time for complete multiplication loop
        end

        $finish; // Terminate simulation
    end

endmodule
