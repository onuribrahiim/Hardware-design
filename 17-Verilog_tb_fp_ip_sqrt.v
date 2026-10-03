`timescale 1ns / 1ps

/**
 * @file tb_fpip_sqrt.v
 * @brief Testbench for Floating-Point Square Root IP Core (IEEE-754 Single Precision)
 * @details Validates test cases including standard positive values, zero edge case,
 *          and invalid operations such as square root of a negative floating-point number.
 */

module tb_fpip_sqrt ();

    //--------------------------------------------------------------------------
    // Parameters & Signals Declaration
    //--------------------------------------------------------------------------
    parameter DATA_WIDTH = 32;

    reg                  clk;
    reg                  reset;
    reg                  start_system;
    reg [DATA_WIDTH-1:0] data_in;
    
    wire [DATA_WIDTH-1:0] data_out;
    wire                  out_done;

    //--------------------------------------------------------------------------
    // Device Under Test (DUT) Instantiation
    //--------------------------------------------------------------------------
    fpip_sqrt #(
        .DATA_WIDTH(DATA_WIDTH)
    ) fpip_sqrt_DUT (
        .clk          (clk          ),
        .reset        (reset        ),
        .start_system (start_system ),
        .data_in      (data_in      ),
        .data_out     (data_out     ),
        .out_done     (out_done     )
    );

    //--------------------------------------------------------------------------
    // Clock Generation (50 MHz -> 20ns period)
    //--------------------------------------------------------------------------
    always #10 clk = ~clk; 

    //--------------------------------------------------------------------------
    // Watchdog Timer (Timeout Guard)
    //--------------------------------------------------------------------------
    initial begin
        #500000;
        $display("[ERROR] Watchdog timeout reached! Simulation terminated.");
        $finish;
    end 

    //--------------------------------------------------------------------------
    // Test Stimulus & Verification
    //--------------------------------------------------------------------------
    initial begin
        // System Initialization
        data_in      = 32'h0;
        reset        = 1'b1;
        clk          = 1'b0;
        start_system = 1'b0;

        // Apply Reset
        repeat(2) @(posedge clk);
        reset = 1'b0;

        //======================================================================
        // TEST 1: sqrt(0.25) = 0.5
        // IEEE-754: 0.25 -> 0x3E800000 | 0.5 -> 0x3F000000
        //======================================================================
        $display("\n------- TEST 1 -------");
        $display("Calculating sqrt(0.25)... Expected Result = 0.5");
        
        data_in      = 32'h3e800000;
        start_system = 1'b1;
        wait(out_done);
        @(posedge clk);
        start_system = 1'b0;

        $display("Input = %h | Output = %h | Expected = 3f000000 | Status: %s",
                 data_in, data_out, (data_out == 32'h3f000000) ? "PASS" : "FAIL");
        
        repeat(6) @(posedge clk);

        //======================================================================
        // TEST 2: sqrt(0.36) = 0.6
        // IEEE-754: 0.36 -> 0x3EB851EC | 0.6 -> 0x3F19999A
        //======================================================================
        $display("\n------- TEST 2 -------");
        $display("Calculating sqrt(0.36)... Expected Result = 0.6");
        
        data_in      = 32'h3eb851ec;
        start_system = 1'b1;
        wait(out_done);
        @(posedge clk);
        start_system = 1'b0;

        $display("Input = %h | Output = %h | Expected = 3f19999a | Status: %s",
                 data_in, data_out, (data_out == 32'h3f19999a) ? "PASS" : "FAIL");
        
        repeat(6) @(posedge clk);

        //======================================================================
        // TEST 3: sqrt(0.1296) = 0.36
        // IEEE-754: 0.1296 -> 0x3E04B5DD | 0.36 -> 0x3EB851EC
        //======================================================================
        $display("\n------- TEST 3 -------");
        $display("Calculating sqrt(0.1296)... Expected Result = 0.36");
        
        data_in      = 32'h3e04b5dd;
        start_system = 1'b1;
        wait(out_done);
        @(posedge clk);
        start_system = 1'b0;

        $display("Input = %h | Output = %h | Expected = 3eb851ec | Status: %s",
                 data_in, data_out, (data_out == 32'h3eb851ec) ? "PASS" : "FAIL");
        
        repeat(6) @(posedge clk);

        //======================================================================
        // TEST 4: Edge Case - sqrt(0.0) = 0.0
        // IEEE-754: 0.0 -> 0x00000000
        //======================================================================
        $display("\n------- TEST 4 -------");
        $display("Calculating sqrt(0.0)... Expected Result = 0.0");
        
        data_in      = 32'h00000000;
        start_system = 1'b1;
        wait(out_done);
        @(posedge clk);
        start_system = 1'b0;

        $display("Input = %h | Output = %h | Expected = 00000000 | Status: %s",
                 data_in, data_out, (data_out == 32'h00000000) ? "PASS" : "FAIL");
        
        repeat(6) @(posedge clk);

        //======================================================================
        // TEST 5: Invalid Operation - sqrt(-0.81)
        // IEEE-754 Input: -0.81 -> 0xBF4F5C29
        // IEEE-754 Expected Output: NaN (Quiet NaN) -> 0x7FC00000
        //======================================================================
        $display("\n------- TEST 5 -------");
        $display("Calculating sqrt(-0.81)... Expected Result = NaN (Quiet NaN)");
        
        data_in      = 32'hbf4f5c29;
        start_system = 1'b1;
        wait(out_done);
        @(posedge clk);
        start_system = 1'b0;

        $display("Input = %h | Output = %h | Expected = 7fc00000 | Status: %s",
                 data_in, data_out, (data_out == 32'h7fc00000) ? "PASS" : "FAIL");
        
        repeat(6) @(posedge clk);

        // Finish Simulation
        $display("\n[INFO] All test vectors executed successfully.");
        $finish;
    end

endmodule
