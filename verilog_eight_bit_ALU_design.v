`timescale 1ns / 1ps

/**
 * Modül: mux_4x1_alu
 * Açıklama: Parametrik (varsayılan 8-bit) Verilog ALU tasarımı. 
 *           4 farklı alt modülü (karşılaştırıcı, kare alıcı, toplayıcı, çıkarıcı)
 *           seçim sinyaline (S) göre bir 4x1 MUX üzerinden tek bir çıkışa yönlendirir.
 */
module mux_4x1_alu #(
    parameter W = 8  // Giriş verilerinin bit genişliği
)(
    input [(W-1):0] A, B,              // ALU Giriş Portları
    input [1:0] S,                     // Seçim Sinyali (00: Karşılaştırıcı, 01: Kare Alma, 10: Toplama, 11: Çıkarma)
    output reg [W*2-1:0] alu_sonuc_in  // Genişletilmiş Çıkış Portu (Varsayılan 16-bit)
);

    // =========================================================================
    // 1. Durum (S = 00): Karşılaştırıcı Alt Modülü (deneme_2)
    // =========================================================================
    wire karsilastirici_kablo_1, karsilastirici_kablo_2, karsilastirici_kablo_3;
    wire [(W*2-14):0] karsilastirici_in; // Karşılaştırma sonuçlarını tutan veri bus'ı

    deneme_2 #(
        .W(W)
    ) dut1 (
        .A             (A),                     // A Girişi
        .B             (B),                     // B Girişi
        .A_buyuktur    (karsilastirici_kablo_1), // A > B durumu
        .B_buyuktur    (karsilastirici_kablo_2), // B > A durumu
        .esittir       (karsilastirici_kablo_3)  // A == B durumu
    );

    // Karşılaştırıcı bayraklarını 3-bitlik tek bir otobüste birleştirme
    assign karsilastirici_in = {karsilastirici_kablo_1, karsilastirici_kablo_2, karsilastirici_kablo_3};


    // =========================================================================
    // 2. Durum (S = 01): Kare Alıcı Alt Modülü (tap_modul_8bit_kare_alici)
    // =========================================================================
    wire [(W*2-1):0] kare_alici_kablo;
    wire [(W*2-1):0] kare_alici_in;

    tap_modul_8bit_kare_alici #(
        .W(W)
    ) dut2 (
        .X   (A),                // A sayısının karesi alınır
        .out (kare_alici_kablo)  // Sonuç W*2 genişliğindedir (Örn: 8-bit için 16-bit çıkış)
    );

    assign kare_alici_in = {kare_alici_kablo};


    // =========================================================================
    // 3. Durum (S = 10): Toplayıcı Alt Modülü (alu_toplayici)
    // =========================================================================
    wire [0:0] elde_in = 1'b0;    // Başlangıç elde değeri (Carry-in)
    wire [0:0] elde_out;          // Çıkış elde değeri (Carry-out)
    wire [(W-1):0] toplayici_kablo;
    wire [W:0] toplayici_in;      // Elde biti eklenmiş toplayıcı sonucu

    alu_toplayici #(
        .W(W)
    ) dut3 (
        .x     (A),               // Birinci toplanan
        .y     (B),               // İkinci toplanan
        .c_in  (elde_in),         // Giriş eldesi
        .S     (toplayici_kablo), // Toplam sonucu
        .carry (elde_out)         // Çıkış eldesi
    );

    // Toplam sonucu ile carry bitini birleştirme (W+1 bit)
    assign toplayici_in = {elde_out, toplayici_kablo};


    // =========================================================================
    // 4. Durum (S = 11): Çıkarıcı Alt Modülü (alu_cikarici)
    // =========================================================================
    wire [0:0] borc_in = 1'b0;    // Başlangıç borç değeri (Borrow-in)
    wire [0:0] borc_out;          // Çıkış borç değeri (Borrow-out)
    wire [(W-1):0] cikarici_kablo;
    wire [W:0] cikarici_in;       // Borç biti eklenmiş çıkarma sonucu

    alu_cikarici #(
        .W(W)
    ) dut4 (
        .x     (A),               // Eksilen
        .y     (B),               // Çıkan
        .b_in  (borc_in),         // Giriş borcu
        .d     (cikarici_kablo),  // Fark sonucu
        .b_out (borc_out)         // Çıkış borcu
    );

    // Çıkarma sonucu ile borç bitini birleştirme
    assign cikarici_in = {borc_out, cikarici_kablo};


    // =========================================================================
    // ALU Çıkış Seçici (4x1 Multiplexer Mantığı)
    // =========================================================================
    always @(*) begin
        case (S)
            // S = 00: Karşılaştırma Sonucu
            // Sonuç, ALU bit genişliğine uyması için sıfırlarla genişletilir (Zero-padding)
            2'b00: begin
                alu_sonuc_in = { {(W*2-3){1'b0}}, karsilastirici_in };
            end

            // S = 01: Kare Alma Sonucu
            2'b01: begin
                alu_sonuc_in = {kare_alici_in};
            end

            // S = 10: Toplama Sonucu
            // Sonuç üst bitlerde sıfırlarla tamamlanır (Zero-padding)
            2'b10: begin
                alu_sonuc_in = { {(W-1){1'b0}}, toplayici_in };
            end

            // S = 11: Çıkarma Sonucu
            // İşaretli/Borçlu işlemlerde doğruluğu korumak için işaret genişletmesi (Sign-extension) uygulanır
            2'b11: begin
                alu_sonuc_in = { {(W-1){cikarici_in[W]}}, cikarici_in };
            end

            default: begin
                alu_sonuc_in = {(W*2){1'b0}};
            end
        endcase
    end

endmodule
