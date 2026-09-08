`timescale 1ns / 1ps // Zaman birimi: 1ns, Zaman çözünürlüğü: 1ps

module tb_fpip();

    // =========================================================================
    // PARAMETRE VE SİNYAL TANIMLAMALARI
    // =========================================================================
    parameter DATA_WIDTH = 32; // IEEE-754 Tek Hassasiyetli (Single Precision) 32-bit veri genişliği

    // DUT (Design Under Test) Giriş Sinyalleri (Testbench tarafında 'reg' olarak sürülür)
    reg                  clk;
    reg                  reset;
    reg [DATA_WIDTH-1:0] data_1;
    reg [DATA_WIDTH-1:0] data_2;
    reg                  start_sytem;
    reg                  i_add_sub;   // 0: Toplama, 1: Çıkarma işlemi

    // DUT Çıkış Sinyalleri (Testbench tarafında 'wire' olarak izlenir)
    wire [DATA_WIDTH-1:0] data_out;
    wire                  done_signal;

    // =========================================================================
    // TEST EDİLECEK MODÜLÜN (DUT) BAĞLANTISI (INSTANTIATION)
    // =========================================================================
    fpip #(
        .DATA_WIDTH(DATA_WIDTH)
    ) fpip_DUT (
        .clk        (clk        ),
        .reset      (reset      ),
        .data_1     (data_1     ),
        .data_2     (data_2     ),
        .start_sytem(start_sytem),
        .i_add_sub  (i_add_sub  ),
        .data_out   (data_out   ),
        .done_signal(done_signal)
    );

    // =========================================================================
    // SAAT (CLOCK) SİNYALİ ÜRETİMİ
    // =========================================================================
    // 5ns lojik 0, 5ns lojik 1 -> Toplam 10ns periyot (100 MHz frekanslı saat)
    always #5 clk = ~clk;

    // =========================================================================
    // TEST SENARYOLARI (STIMULUS INITIAL BLOCK)
    // =========================================================================
    initial begin
        // --- 1. SİSTEM İLK DEĞER ATAMALARI VE RESET ---
        clk         = 0;
        reset       = 1; // Başlangıçta sistemi reset durumunda tut
        data_1      = 0;
        data_2      = 0;
        start_sytem = 0;
        i_add_sub   = 0;
        
        // 4 saat darbesi boyunca reset uygulandıktan sonra reset kaldırılır
        repeat(4) @(posedge clk);
        reset = 0;

        // --- TEST 1: KAYAN NOKTALI TOPLAMA İŞLEMİ ---
        // Hesaplama: +1.25 + (+1.75) = +3.0
        // data_1 = 1.25 -> 0_01111111_01000000000000000000000 (Sign=0, Exp=127, Mantissa=1.25)
        // data_2 = 1.75 -> 0_01111111_11000000000000000000000 (Sign=0, Exp=127, Mantissa=1.75)
        $display("--------TEST1: TOPLAMA (1.25 + 1.75 = 3.0)--------");
        
        start_sytem = 1;
        data_1      = 32'b00111111101000000000000000000000;
        data_2      = 32'b00111111111000000000000000000000;
        i_add_sub   = 0; // Toplama modu (0)
        
        repeat(4) @(posedge clk);
        start_sytem = 0; // İşlem başlatma sinyali çekilir
        
        wait(done_signal);        // İşlem tamamlama bayrağı beklenir
        repeat(8) @(posedge clk);  // Sonucu gözlemlemek için bekleme süresi

        // --- TEST 2: KAYAN NOKTALI TOPLAMA İŞLEMİ ---
        // Hesaplama: +4.25 + (+5.75) = +10.0
        // başlıkta yazan $display mesajı düzeltildi (TEST2 yapıldı)
        // data_1 = 4.25 -> 0_10000001_00010000000000000000000 (Sign=0, Exp=129)
        // data_2 = 5.75 -> 0_10000001_01110000000000000000000 (Sign=0, Exp=129)
        $display("--------TEST2: TOPLAMA (4.25 + 5.75 = 10.0)--------");
        
        start_sytem = 1;
        data_1      = 32'b01000000100010000000000000000000;
        data_2      = 32'b01000000101110000000000000000000;
        i_add_sub   = 0; // Toplama modu (0)
        
        repeat(4) @(posedge clk);
        start_sytem = 0;
        
        wait(done_signal);
        repeat(4) @(posedge clk);

        // --- TEST 3: KAYAN NOKTALI ÇIKARMA İŞLEMİ ---
        // Hesaplama: (-5.25) - (-5.75) = +0.50
        // başlıkta yazan $display mesajı düzeltildi (TEST3 yapıldı)
        // data_1 = -5.25 -> 1_10000001_01010000000000000000000
        // data_2 = -5.75 -> 1_10000001_01110000000000000000000
        $display("--------TEST3: ÇIKARMA (-5.25 - (-5.75) = 0.50)--------");
        
        start_sytem = 1;
        data_1      = 32'b11000000101010000000000000000000;
        data_2      = 32'b11000000101110000000000000000000;
        i_add_sub   = 1; // Çıkarma modu (1)
        
        repeat(4) @(posedge clk);
        start_sytem = 0;
        
        wait(done_signal);
        repeat(4) @(posedge clk);

        // --- SİMÜLASYONU BİTİR ---
        $display("Tüm test senaryoları tamamlandı.");
        $finish;
    end

endmodule
