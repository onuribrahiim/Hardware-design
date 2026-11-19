`timescale 1ns / 1ps

// ============================================================================
// Testbench Name : tb_new_lfsr_system
// Description    : Self-Checking Verification Environment for 8-Bit LFSR
//                  - Test Case 1 : Maximal-length (255-cycle) sequence check
//                                  against a behavioral golden model.
//                  - Test Case 2 : Zero-seed guard / lock-up verification
//                                  (ensures 0-seed is rejected and stays idle).
//                  - Watchdog    : Timeout guard preventing infinite loops.
// ============================================================================

module tb_new_lfsr_system();

    // ------------------------------------------------------------------------
    // DUT Interface Signals
    // ------------------------------------------------------------------------
    reg        clk          ;
    reg        reset        ;
    reg        lfsr_enable  ;
    reg        load_enable  ;
    reg  [7:0] data_in      ;
    wire [7:0] data_out     ;
    wire       completed    ;
    
    // ------------------------------------------------------------------------
    // Verification & Golden Model Variables
    // ------------------------------------------------------------------------
    reg [7:0] self_checking; // Behavioral reference model register
    reg [7:0] fail_counter ; // Tracks locked-up (0) cycles in negative test
    reg [7:0] done_counter ; // Tracks matched cycles in functional test
    
    // ------------------------------------------------------------------------
    // Device Under Test (DUT) Instantiation
    // ------------------------------------------------------------------------
    new_lfsr_system new_lfsr_sytem_DUT (
        .clk        (clk         ),
        .reset      (reset       ),
        .lfsr_enable(lfsr_enable ),
        .load_enable(load_enable ),
        .data_in    (data_in     ),
        .data_out   (data_out    ),
        .completed  (completed   )
    );
    
    // ------------------------------------------------------------------------
    // Clock Generation (100 MHz -> 10 ns Period)
    // ------------------------------------------------------------------------
    always #5 clk = ~clk;
    
    // ------------------------------------------------------------------------
    // Watchdog Timeout Guard
    // ------------------------------------------------------------------------
    initial begin
        #100000;    
        $display("------ TESTBENCH WATCHDOG ALARM ------");                          
        $display("FAIL: Simulation timeout, 'completed' flag did not assert!");
        $finish;                              
    end
    
    // ------------------------------------------------------------------------
    // Main Stimulus & Self-Checking Sequence
    // ------------------------------------------------------------------------
    initial begin
        // 1. Initial Reset & Signal Initialization
        data_in      = 0;
        clk          = 0;
        reset        = 0;
        lfsr_enable  = 0;
        load_enable  = 0;
        fail_counter = 0;
        done_counter = 0;
        repeat(2) @(posedge clk) #1;

        // ====================================================================
        // TEST CASE 1: Valid Non-Zero Seed & Full 255-Cycle Verification
        // ====================================================================
        reset       = 1;
        lfsr_enable = 1;
        load_enable = 1;
        data_in     = $random(2**8);
        
        // Constraint: Ensure initial seed is non-zero for normal operation test
        while (data_in === 0) begin
            data_in = $random(2**8);
        end
        @(posedge clk) #1;

        $display("------------ TEST 1: FUNCTIONAL SEQUENCE CHECK ------------");
        self_checking = data_in;
        reset         = 1;
        lfsr_enable   = 1;
        load_enable   = 0;

        // Monitor every cycle until 'completed' flag asserts
        while (!completed) begin
            @(posedge clk) #1;
            
            // Update behavioral golden model
            self_checking = {self_checking[6:0], self_checking[7] ^ self_checking[5] ^ 
                             self_checking[4] ^ self_checking[3]};
            
            $display("Cycle=%d | Seed Input=%d | Expected Value=%d | Actual Output=%d",
                     new_lfsr_sytem_DUT.counter, data_in, self_checking, data_out);
            $display("%s", (data_out === self_checking) ? "Transaction Successful" : "Transaction Failed");   
            
            if (data_out !== self_checking) begin
                $display("ERROR DETECTED at Cycle=%d", new_lfsr_sytem_DUT.counter);
            end
            if (data_out === self_checking) begin
                done_counter = done_counter + 1;
            end
        end

        if (done_counter === 255) begin
            $display("------ PASS: LFSR GENERATED MAXIMAL SEQUENCE (255 VALUES) ------");
        end
        
        // ====================================================================
        // TEST CASE 2: Negative Test - Zero-Seed Rejection (Lock-Up Check)
        // ====================================================================
        $display("------------ TEST 2: ZERO-SEED GUARD CHECK ------------");
        data_in      = 0;
        reset        = 0;
        lfsr_enable  = 0;
        load_enable  = 0;
        fail_counter = 0;
        repeat(2) @(posedge clk) #1;

        // Attempt to load forbidden 0-seed
        reset       = 1;
        lfsr_enable = 1;
        load_enable = 1;
        data_in     = 'd0;
        @(posedge clk) #1;

        self_checking = data_in;
        reset         = 1;
        lfsr_enable   = 1;
        load_enable   = 0;

        // Verify DUT rejects 0-seed and remains safely in idle (0) state
        while (!completed) begin 
            @(posedge clk) #1;
            self_checking = {self_checking[6:0], self_checking[7] ^ self_checking[5] ^ 
                             self_checking[4] ^ self_checking[3]};
            
            $display("Cycle=%d | Seed Input=%d | Expected Value=%d | Actual Output=%d",
                     new_lfsr_sytem_DUT.counter, data_in, self_checking, data_out);
            $display("%s", (data_out === self_checking) ? "Transaction Successful" : "Transaction Failed");
            
            if (data_out === 0) begin
                fail_counter = fail_counter + 1;
            end  
        end

        if (fail_counter === 254) begin
            $display("Locked-Up (Zero) Cycles Count=%d", fail_counter);
            $display("----- FORBIDDEN ZERO-SEED DETECTED: OUTPUT REMAINED AT 0 -----");
            $display("------------- PASS: ZERO-SEED GUARD VERIFIED -------------");
        end

        $finish;
    end

endmodule
