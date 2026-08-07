`timescale 1ns / 1ps // Simülasyon zaman birimi (1ns) ve çözünürlüğü (1ps)

// ============================================================================
// Modül İsmi: tb_LFSR (Testbench for Linear Feedback Shift Register)
// Tanım     : LFSR modülünün işlevsel doğrulama ve zamanlama simülasyon testi
// ============================================================================
module tb_LFSR();

// ============================================================================
// 1. PARAMETRE TANIMLAMALARI
// ============================================================================
parameter DW_LFSR = 6; // Test edilecek LFSR bit genişliği (6-bit)

// ============================================================================
// 2. SİNYAL TANIMLAMALARI
// ============================================================================
// DUT girişlerine değer sürmek için 'reg' tanımlamaları
reg                   i_clk_LFSR;   // Testbench saat sinyali
reg                   i_reset_LFSR; // Reset ve tohum yükleme kontrol sinyali
reg  [DW_LFSR-1:0]    i_data_LFSR;  // Yüklenecek rastgele tohum (seed) değeri

// DUT çıkışını izlemek için 'wire' tanımlaması
wire [DW_LFSR-1:0]    o_data_LFSR;  // Üretilen yarı-rastgele sayı dizilimi çıkışı

// ============================================================================
// 3. TEST EDİLEN DEVRENİN (DUT) BAĞLANMASI
// ============================================================================
LFSR #(
    .DW_LFSR(DW_LFSR)
) DUT ( 
    .i_clk_LFSR   (i_clk_LFSR  ),
    .i_reset_LFSR (i_reset_LFSR),
    .i_data_LFSR  (i_data_LFSR ),
    .o_data_LFSR  (o_data_LFSR )
);

// ============================================================================
// 4. CLOCK (SAAT) ÜRETİMİ
// ============================================================================
// 30ns periyotlu (Her 15ns'de bir evrilen) saat sinyali üretimi
initial begin
    i_clk_LFSR = 0;
    forever #15 i_clk_LFSR = ~i_clk_LFSR;
end

// ============================================================================
// 5. ANA TEST SENARYOSU
// ============================================================================
initial begin
    // --- BAŞLANGIÇ / RESET EVRESİ ---
    i_reset_LFSR = 1;
    
    // SystemVerilog $random fonksiyonu ile 0-63 (2^6 - 1) arasında dinamik tohum üretimi
    i_data_LFSR  = $random % (2**DW_LFSR);
    
    #20; // Tohumun devreboyunca oturması için 20ns bekle

    // --- DÖNGÜ VE RASTGELE SAYI ÜRETİM EVRESİ ---
    i_reset_LFSR = 0; // Reset kaldırılır, LFSR kaydırmaya ve XOR üretimine başlar

    #1000; // Ardışık durum geçişlerini ve periyodu gözlemlemek için 1000ns koştur

    $finish; // Simülasyonu sonlandır
end

endmodule
