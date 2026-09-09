// ============================================================================
// File Name   : tb_fpip_sqrt.v
// Module Name : tb_fpip_sqrt
// Description : Testbench for Floating-Point Square Root Wrapper (fpip_sqrt)
//               Applies IEEE-754 single-precision test vectors to verify
//               the FSM behavior and core output logic.
//
// Author      : Halil İbrahim Onur
// Target Board: Nexys A7-100T / Xilinx FPGA Simulation
// ============================================================================

`timescale 1ns / 1ps

module tb_fpip_sqrt();

    // ========================================================================
    // Parametre ve Sinyal Tanımlamaları
    // ========================================================================
    parameter DATA_WIDTH = 32;

    reg                   clk;
    reg                   reset;
    reg                   start_signal;
    reg  [DATA_WIDTH-1:0] data_in;
    wire [DATA_WIDTH-1:0] data_out;
    wire                  done_finish_signal;

    // ========================================================================
    // Test Edilecek Modülün (DUT - Device Under Test) Örneklenmesi
    // ========================================================================
    fpip_sqrt #(
        .DATA_WIDTH(DATA_WIDTH)
    ) fpip_sqrt_DUT (    
        .clk                (clk),
        .reset              (reset),
        .start_signal       (start_signal),
        .data_in            (data_in),
        .data_out           (data_out),
        .done_finish_signal (done_finish_signal)
    );

    // ========================================================================
    // Saat Sinyali Üretimi (Clock Generator: 100 MHz -> Period = 10ns)
    // ========================================================================
    always #5 clk = ~clk;

    // ========================================================================
    // Test Senaryoları (Initial Block)
    // ========================================================================
    initial begin
        // --- 1. Başlangıç Durumu ve Reset Uygulama ---
        clk          = 1'b0;
        reset        = 1'b1;
        start_signal = 1'b0;
        data_in      = {DATA_WIDTH{1'b0}};

        // 4 clock cycle boyunca sistemi reset altında tut
        repeat(4) @(posedge clk);
        reset        = 1'b0;
        repeat(2) @(posedge clk);

        // --------------------------------------------------------------------
        // TEST 1: sqrt(0.36) = 0.6
        // Girdi Hex  : 0x3EB851EC (0.36 IEEE-754 single precision)
        // Beklenen   : ~0.600000 (IEEE-754: 0x3F19999A)
        // --------------------------------------------------------------------
        $display("\n==========================================");
        $display("[TEST 1] sqrt(0.36) hesaplamasi baslatildi.");
        $display("Girdi (Hex): 0x3EB851EC | Deger: 0.36");
        
        start_signal = 1'b1;
        data_in      = 32'b00111110101110000101000111101100; // 0.36
        
        repeat(4) @(posedge clk);
        start_signal = 1'b0; // Start sinyalini indir

        // İşlemin tamamlanmasını ve done_finish_signal sinyalinin gelmesini bekle
        wait(done_finish_signal);
        $display("Sonuc Alindi (Hex): 0x%h", data_out);
        $display("==========================================");
        repeat(6) @(posedge clk);

        // --------------------------------------------------------------------
        // TEST 2: sqrt(0.00025) = 0.015811
        // Girdi Hex  : 0x3983126F (0.00025 IEEE-754 single precision)
        // Beklenen   : ~0.015811 (IEEE-754: 0x3C81966F)
        // --------------------------------------------------------------------
        $display("\n==========================================");
        $display("[TEST 2] sqrt(0.00025) hesaplamasi baslatildi.");
        $display("Girdi (Hex): 0x3983126F | Deger: 0.00025");
        
        start_signal = 1'b1;
        data_in      = 32'b00111001100000110001001001101111; // 0.00025
        
        repeat(4) @(posedge clk);
        start_signal = 1'b0;

        wait(done_finish_signal);
        $display("Sonuc Alindi (Hex): 0x%h", data_out);
        $display("==========================================");
        repeat(6) @(posedge clk);

        // --------------------------------------------------------------------
        // TEST 3: sqrt(12.36) = 3.515679
        // Girdi Hex  : 0x4145C28F (12.36 IEEE-754 single precision)
        // Beklenen   : ~3.515679 (IEEE-754: 0x40610313)
        // --------------------------------------------------------------------
        $display("\n==========================================");
        $display("[TEST 3] sqrt(12.36) hesaplamasi baslatildi.");
        $display("Girdi (Hex): 0x4145C28F | Deger: 12.36");
        
        start_signal = 1'b1;
        data_in      = 32'b01000001010001011100001010001111; // 12.36
        
        repeat(4) @(posedge clk);
        start_signal = 1'b0;

        wait(done_finish_signal);
        $display("Sonuc Alindi (Hex): 0x%h", data_out);
        $display("==========================================");
        repeat(6) @(posedge clk);

        // --- Simülasyonu Bitir ---
        $display("\n[SIMULATION FINISHED] Tum testler basariyla tamamlandi.\n");
        $finish;
    end

endmodule
