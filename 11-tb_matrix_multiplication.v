`timescale 1ns / 1ps

// ============================================================================
// Module Name:  tb_matrix_multiplication
// Description:  Testbench for verifying top-level matrix_multiplication module.
//               Generates clock, active-high reset, and a random initial seed.
// ============================================================================

module tb_matrix_multiplication();

    // ========================================================================
    // Parameter Definitions (Matches DUT Interface)
    // ========================================================================
    parameter DATA_WIDTH  = 4;
    parameter ADDR_WIDTH  = 4;
    parameter DEPTH_WIDTH = 12;

    // Clock Period Configuration (16.67 MHz / 60 ns Period)
    localparam CLK_PERIOD = 60;

    // ========================================================================
    // Testbench Stimulus Registers & Output Wires
    // ========================================================================
    reg                      clk;
    reg                      reset;
    reg  [DATA_WIDTH-1:0]    data_login;
    wire [DATA_WIDTH*2+1:0]  data_out;

    // ========================================================================
    // Device Under Test (DUT) Instantiation
    // ========================================================================
    matrix_multiplication #(
        .DATA_WIDTH    (DATA_WIDTH),
        .ADDR_WIDTH    (ADDR_WIDTH),
        .DEPTH_WIDTH   (DEPTH_WIDTH)
    ) matrix_multiplication_DUT (
        .clk        (clk),
        .reset      (reset),
        .data_login (data_login),
        .data_out   (data_out)
    );

    // ========================================================================
    // Clock Generation Process (Periodic 50% Duty Cycle)
    // ========================================================================
    initial begin 
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // ========================================================================
    // Main Test Stimulus Sequence
    // ========================================================================
    initial begin
        // Initialize Reset and drive a random LFSR initial seed
        reset      = 1'b1;
        data_login = $random % (1 << DATA_WIDTH);
        
        // Hold reset active for one full clock cycle
        #CLK_PERIOD;
        reset      = 1'b0;

        // Run execution through all FSM states
        #2960;

        // Terminate simulation
        $finish;
    end

endmodule
