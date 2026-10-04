`timescale 1ns / 1ps 

module tb_lfsr();
    parameter DATA_WIDTH = 32; 

    // --- Signal Declarations ---
    reg                    clk;      // System clock signal
    reg                    reset;    // Active-high reset signal
    reg  [DATA_WIDTH-10:0] fraction; // Initial seed value for LFSR
    wire [DATA_WIDTH-1:0]  data_out; // Pseudo-random generated output data
    wire                   o_ERR;    // Error flag for forbidden state detection

    // --- Device Under Test (DUT) Instantiation ---
    lfsr LFSR_DUT (
        .clk      (clk),
        .reset    (reset),
        .fraction (fraction),
        .data_out (data_out),
        .o_ERR    (o_ERR)
    );

    // --- Clock Generation (10ns period) ---
    initial clk = 0;
    always #5 clk = ~clk;

    // --- Test Scenarios ---
    initial begin
        // ------------- TEST 1: Normal Operation with Random Seed -------------
        $display("------TEST1-------");
        reset    = 1;          // Assert reset to load new seed into LFSR
        fraction = $random;    // Generate random initial seed
        $display("Input Seed = %h", fraction);

        @(posedge clk);
        repeat(70) begin
            reset = 0;         // De-assert reset to allow shift operations
            $display("Random Data = %h | ERROR = %d", data_out, o_ERR);
            @(posedge clk);
        end

        repeat(6) @(posedge clk);

        // ------------- TEST 2: Forbidden State Detection -------------
        $display("------TEST2-------");
        reset    = 1;
        fraction = 23'h7FFFFF; // Apply forbidden seed to trigger error flag
        $display("Input Seed = %h", fraction);

        @(posedge clk);
        repeat(3) begin
            reset = 0;
            @(posedge clk);
            $display("Random Data = %h | ERROR = %d", data_out, o_ERR);
            @(posedge clk);
        end

        $finish; // End of simulation
    end 
endmodule
