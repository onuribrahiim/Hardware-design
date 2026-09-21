`timescale 1ns / 1ps

/**
 * Module: tb_multiplier
 * Description: Testbench for verifying the parametric combinational multiplier module.
 *              Generates random test vectors and compares DUT output against expected product.
 */
module tb_multiplier();

    // Parameter definition matching DUT
    parameter DATA_WIDTH = 6;

    // Testbench signals
    reg  [DATA_WIDTH-1:0]   A;                 // Multiplier stimulus
    reg  [DATA_WIDTH-1:0]   B;                 // Multiplicand stimulus
    reg                     multiplier_enable; // Enable signal
    wire [DATA_WIDTH*2-1:0] data_out;          // DUT result output

    wire [DATA_WIDTH*2-1:0] expected;          // Golden reference calculation

    // Golden Reference: Behavioral multiplication used to verify DUT correctness
    assign expected = A * B;

    // Instantiate Design Under Test (DUT)
    multiplier #(
        .DATA_WIDTH(DATA_WIDTH)
    ) multiplier_DUT (
        .A                (A),
        .B                (B),
        .multiplier_enable(multiplier_enable),
        .data_out         (data_out)
    );

    // Main Test Stimulus Process
    initial begin
        // Step 1: Initialize signals with enable disabled
        multiplier_enable = 0;
        A = 0;
        B = 0;
        $display("Initial State | A=%d | B=%d | Result=%d", A, B, data_out);
        
        #20;

        // Step 2: Enable the multiplier
        multiplier_enable = 1;

        // Step 3: Run randomized test cases across input range
        repeat (2**DATA_WIDTH) begin
            // Generate masked random inputs within DATA_WIDTH limits
            A = $random & ((1 << DATA_WIDTH) - 1);
            B = $random & ((1 << DATA_WIDTH) - 1);
            
            #10; // Wait for combinational propagation

            // Step 4: Validate output against expected result
            if (data_out == expected) begin
                $display("PASS | A=%d | B=%d | Expected=%d | Result=%d", A, B, expected, data_out);
            end else begin
                $display("FAIL | A=%d | B=%d | THESE VALUES DO NOT PRODUCING CORRECT RESULT | Expected=%d | Result=%d", A, B, expected, data_out);
            end
        end     

        // Step 5: End simulation execution
        $finish;     
    end         

endmodule
