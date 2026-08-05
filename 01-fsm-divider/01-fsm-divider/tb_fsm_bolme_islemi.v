`timescale 1ns / 1ps

// ============================================================================
// Module Name: tb_fsm_bolme_islemi
// Description: Testbench for verifying FSM Division Unit with Random Inputs
// ============================================================================

module tb_fsm_bolme_islemi();

    // Parametric Bit-Width Configuration
    parameter W = 4;

    // Testbench Stimulus and Verification Signals
    reg          clk;
    reg          reset;
    reg          flag;
    reg  [W-1:0] bolunen;
    reg  [W-1:0] bolen;
    wire [W-1:0] sonuc;
    wire         DURUM;

    // Device Under Test (DUT) Instantiation
    fsm_bolme_islemi #(
        .W(W)
    ) fsm_bolme_islemi_dut (
        .clk    (clk),
        .reset  (reset),
        .flag   (flag),
        .bolunen(bolunen),
        .bolen  (bolen),
        .sonuc  (sonuc),
        .DURUM  (DURUM)
    );

    // Clock Generation Process (50 MHz, 20ns Clock Period)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // Stimulus Generation Block
    initial begin
        // Initial Signal States
        reset = 1;
        flag  = 0;
        bolunen = 0;
        bolen   = 0;

        // Apply Reset for 25ns
        #25;
        reset = 0;

        // Loop through 10 Random Test Vectors
        repeat(10) begin
            // Generate Random Unsigned Inputs (Range: 0 to 2^W - 1)
            bolunen = $random % (2**W);
            bolen   = $random % (2**W);

            #5;
            flag = 1;  // Assert trigger pulse to FSM
            #20;
            flag = 0;  // De-assert trigger pulse

            // Wait 200ns to allow FSM state transitions and subtraction loops to complete
            #200;
        end

        // End Simulation
        $finish;
    end

endmodule
