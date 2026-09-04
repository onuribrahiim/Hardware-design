`timescale 1ns / 1ps

// ============================================================================
// Modul Adi   : fifo
// Tanım       : Senkron (Single-Clock) FIFO Tasarımı
// Mimarisi    : Bypass / First-Word Fall-Through (FWFT) Destekli
// Ozellikler  :
//   - FIFO bosken ayni anda hem yazma hem okuma istegi gelirse (w_en=1, r_en=1),
//     veri bellege yazilmadan dogrudan cikisa aktarilir (Zero-Latency Bypass).
//   - counter tabanli doluluk (full/empty) takibi yapilir.
// ============================================================================

module fifo #(
    parameter DATA_WIDTH = 6,                        // Veri genisligi (bit)
    parameter DATA_DEPTH = 16,                       // FIFO derinligi (eleman sayisi)
    parameter DATA_ADDR  = ($clog2(DATA_DEPTH))      // Adres veri genisligi
)(
    input  wire                  clk,                // Sistem saat sinyali
    input  wire                  reset,              // Asenkron reset sinyali (Active High)
    input  wire                  w_en,               // Yazma yetki sinyali (Write Enable)
    input  wire                  r_en,               // Okuma yetki sinyali (Read Enable)
    input  wire [DATA_WIDTH-1:0] data_in,            // Giriş verisi
    output wire [DATA_WIDTH-1:0] data_out,           // Çıkış verisi
    output wire                  full,               // FIFO tam dolu bayrağı
    output wire                  empty,              // FIFO tamamen boş bayrağı
    output wire                  valid               // Bypass durumunu belirten gecerlilik bayragi
);

    // ------------------------------------------------------------------------
    // Ic Kayitlar (Registers) ve Bellek Yapisi
    // ------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] r_data_out;                 // Bellekten okunan veriyi tutan cikis kaydi
    reg [DATA_WIDTH-1:0] fifo_name [0:DATA_DEPTH-1]; // FIFO bellek dizisi (RAM)
    reg [DATA_ADDR-1 :0] wr_ptr;                     // Yazma adres göstergesi (Write Pointer)
    reg [DATA_ADDR-1 :0] rd_ptr;                     // Okuma adres göstergesi (Read Pointer)
    reg [DATA_ADDR   :0] counter;                    // FIFO'daki aktif eleman sayaci

    // ------------------------------------------------------------------------
    // Durum Bayraklari ve Mantiksal Cikis Atamalari
    // ------------------------------------------------------------------------
    assign full  = (counter == DATA_DEPTH);          // Eleman sayisi max kapasiteye ulastiginda dolu
    assign empty = (counter == 0);                   // Eleman sayisi 0 oldugunda bos

    // CRITICAL LOGIC (Bypass Mantigi):
    // FIFO BOS iken ayni anda hem YAZMA hem OKUMA istegi gelirse;
    // valid = 1 olur ve gelen veri bellegi bypass ederek dogrudan cikisa yonlendirilir.
    assign valid = (w_en && r_en && empty);

    // ------------------------------------------------------------------------
    // Ana Ardışıl Mantık (Sequential Logic)
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset aninda tum pointer'lar, sayac ve cikis sifirlanir
            wr_ptr     <= 0;
            rd_ptr     <= 0;
            counter    <= 0;
            r_data_out <= 0;
        end else begin

            // --- 1. ELEMAN SAYACI YÖNETİMİ ---
            case ({w_en, r_en})
                2'b10: begin // Sadece Yazma
                    if (!full)
                        counter <= counter + 1'b1;
                end
                2'b01: begin // Sadece Okuma
                    if (!empty)
                        counter <= counter - 1'b1;
                end
                default: begin
                    // 2'b00 (Islem yok) veya 2'b11 (Ayni anda okuma/yazma):
                    // Bos iken bypass yapildiginda veya doluyken/aradayken 
                    // ayni anda yazip okundugunda eleman sayisi DEĞİŞMEZ.
                    counter <= counter;
                end
            endcase

            // --- 2. BELLEĞE YAZMA İŞLEMİ ---
            // FIFO dolu degilse VE (valid=1 olan bypass durumu yoksa) belleğe yazilir.
            // valid=1 iken veri bellege yazilmaz, doğrudan dışarıya aktarılır.
            if (w_en && !full && !valid) begin
                fifo_name[wr_ptr] <= data_in;
                wr_ptr            <= wr_ptr + 1'b1;
            end

            // --- 3. BELLEKTEN OKUMA İŞLEMİ ---
            // FIFO bos degilse gelen okuma istegiyle bellekten okuma yapilir.
            if (r_en && !empty) begin
                r_data_out <= fifo_name[rd_ptr];
                rd_ptr     <= rd_ptr + 1'b1;
            end
        end
    end

    // ------------------------------------------------------------------------
    // Çıkış MUX'ı (Combinational Output Selection)
    // ------------------------------------------------------------------------
    // valid = 1 ise (Sistem bosken ayni anda yazma+okuma verilse) gelen veriyi (data_in) 
    // hic saat darbesi beklemeden kombinazyonel olarak doğrudan çıkışa sürer.
    // Diger durumlarda bellekten okunan veriyi (r_data_out) çıkışa verir.
    assign data_out = valid ? data_in : r_data_out;

endmodule
