`timescale 1ns / 1ps

// ============================================================================
// Modül Adı    : tb_fsm_carpici
// Açıklama     : FSM tabanlı parametrik çarpıcı modülü için testbench.
// ============================================================================

module tb_new_carpici();

    // ------------------------------------------------------------------------
    // Parametreler ve Sinyal Tanımlamaları
    // ------------------------------------------------------------------------
    parameter DW = 6;                  // Veri genişliği (Data Width)
                      
    reg              clk;              // Saat sinyali
    reg              reset;            // Sistem reset sinyali
    reg  [DW-1:0]    carpilan;         // Giriş 1: Çarpılan sayı
    reg  [DW-1:0]    carpan;           // Giriş 2: Çarpan sayı
    wire [DW*2-1:0]  sonuc;            // Çıkış: Çarpım sonucu

    // ------------------------------------------------------------------------
    // DUT (Device Under Test) - Çarpıcı Modülü Bağlantısı
    // ------------------------------------------------------------------------
    carpici #(
        .DW(DW)
    ) carpici_dut (
        .clk      (clk),
        .reset    (reset),
        .carpilan (carpilan),
        .carpan   (carpan),
        .sonuc    (sonuc)
    );

    // ------------------------------------------------------------------------
    // Saat (Clock) Sinyali Üretimi (Periyot = 20ns)
    // ------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #10 clk = ~clk;       // Her 10ns'de bir clock durum değiştirir
    end

    // ------------------------------------------------------------------------
    // Test Senaryosu ve Uyarım (Stimulus) Bloğu
    // ------------------------------------------------------------------------
    initial begin
        // Başlangıç değerleri ve Sistem Reseti
        reset = 1;
        #20;                          // 20ns boyunca reset'te tut
        reset = 0;                    // Reseti kaldır, sistemi başlat

        // 10 Adet Rastgele Test Verisi İle Doğrulama Döngüsü
        repeat(10) begin
            carpilan = $random % (2**DW);
            carpan   = $random % (2**DW);
            #210;
            $display("carpilan=%d , carpan=%d , sonuc=%d",carpilan,carpan,sonuc);
        end

        // Simülasyonu Sonlandır
        $finish;
    end

endmodule
