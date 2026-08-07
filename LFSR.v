`timescale 1ns / 1ps // Simülasyon zaman birimi (1ns) ve çözünürlüğü (1ps)

// ============================================================================
// Modül İsmi: LFSR (Linear Feedback Shift Register)
// Tanım     : Parametrik Yarı-Rastgele (Pseudo-Random) Sayı Üreticisi
// ============================================================================
module LFSR #(
    parameter DW_LFSR = 6 // LFSR bit genişliği parametresi (Varsayılan: 6-bit)
)
(
    input                  i_clk_LFSR,   // Sistem saat sinyali
    input                  i_reset_LFSR, // Senkron reset ve tohum (seed) yükleme sinyali
    input [DW_LFSR-1:0]    i_data_LFSR,  // Başlangıç tohum değeri (Initial Seed)

    output[DW_LFSR-1:0]    o_data_LFSR   // Üretilen rastgele sayı çıkış portu
);

    // LFSR durumunu tutan iç kaydırmalı kaydedici (Internal Shift Register)
    reg [DW_LFSR-1:0] random_LFSR;

    // İç kaydedicideki güncel değeri sürekli olarak çıkışa aktar
    assign o_data_LFSR = random_LFSR;

    // Yükselen saat kenarında çalışan senkron mantık bloğu
    always @(posedge i_clk_LFSR) begin
        if (i_reset_LFSR) begin
            // Reset durumunda dışarıdan verilen tohum (seed) değerini yükle
            random_LFSR <= i_data_LFSR;
            
            // Kilitlenme (Lockup) Koruması:
            // LFSR mimarisinde tüm bitlerin '0' olması durumu devreyi kilitler (XOR sonucu hep 0 kalır).
            // Eğer girilen tohum değeri '0' ise güvenlik amacıyla tüm bitleri '1' yap.
            if (i_data_LFSR == 0) begin
                random_LFSR <= {DW_LFSR{1'b1}}; 
            end
            
        end else begin
            // Normal Çalışma Durumu:
            // 1. Bitleri 1 pozisyon sola kaydır ([DW_LFSR-2:0]).
            // 2. En sağdaki LSB bitine Tap noktalarının (Bit 4 ve Bit 1) XOR geri besleme sonucunu yaz.
            random_LFSR <= {random_LFSR[DW_LFSR-2:0], (random_LFSR[4] ^ random_LFSR[1])};
        end
    end

endmodule
