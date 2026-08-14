// Zaman ölçeği tanımı: Simülasyon adımı 1ns, hassasiyeti 1ps
`timescale 1ns / 1ps

// ============================================================================
// Modül Adı: new_ram
// Açıklama : Senkron (Clock tetiklemeli) Okuma ve Yazma Özellikli RAM Bellek
// ============================================================================
module new_ram #(
    parameter data_WIDTH     = 4,   // Veri yolu genişliği (Bit cinsinden)
    parameter addr_WIDTH     = 4,   // Adres yolu genişliği (Bit cinsinden)
    parameter derinlik_WIDTH = 16   // Bellek derinliği (Toplam adreslenebilir hücre sayısı)
)(
    // --- Girdi / Çıktı Sinyalleri ---
    input wire [addr_WIDTH-1:0]  addr,         // Okuma/Yazma yapılacak bellek adresi
    input wire [data_WIDTH-1:0]  data_in,      // RAM'e yazılacak girdi verisi
    input wire                   clk,          // Sistem saat sinyali (Clock)
    input wire                   enable,       // RAM genel aktif etme sinyali (Chip Select/Enable)
    input wire                   read_enable,  // Okuma izni sinyali
    input wire                   write_enable, // Yazma izni sinyali
    output wire [data_WIDTH-1:0] data_out      // RAM'den okunan çıktı verisi
);

    // --- Dahili Yazmaçlar (Registers) ve Bellek Dizisi ---
    reg [data_WIDTH-1:0] r_data_out;                   // Okunan veriyi geçici tutan yazmaç
    reg [data_WIDTH-1:0] ram_name [0:derinlik_WIDTH-1]; // RAM belleğinin kendisi (Dizi yapısı)

    // --- Senkron Bellek Mantığı ---
    // Saat sinyalinin her yükselen kenarında (posedge) çalışır
    always @(posedge clk) begin
        if (enable) begin
            // 1. Yazma İşlemi: Yazma izni aktifse gelen veriyi adrese kaydet
            if (write_enable) begin
                ram_name[addr] <= data_in;
            end
            
            // 2. Okuma İşlemi: Okuma izni aktifse adresteki veriyi çıkış yazmacına aktar
            if (read_enable) begin
                r_data_out <= ram_name[addr];
            end
        end
    end

    // Dahili okuma yazmacındaki veriyi sürekli olarak çıkış portuna bağla
    assign data_out = r_data_out;

endmodule                                                               
                                                                               
