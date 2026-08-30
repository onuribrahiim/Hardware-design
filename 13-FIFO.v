`timescale 1ns / 1ps

// ============================================================================
// Modül Adı    : FIFO (First-In First-Out Buffer)
// Açıklama     : Senkron FIFO bellek modülü. Veri yazma ve okuma işlemlerini
//                dairesel bir pointer ve eleman sayıcı (counter) yapısı ile yönetir.
// ============================================================================

module FIFO #(
    parameter DATA_WIDTH  = 6,  // Veri veri yolu genişliği (bit)
    parameter DEPTH_WIDTH = 16  // FIFO derinliği (toplam eleman sayısı)
)(  
    // Sistem Sinyalleri
    input  wire                  clk,          // Sistem saat sinyali
    input  wire                  reset,        // Asenkron aktif-yüksek reset
    input  wire                  enable_FIFO,  // Modül yetkilendirme sinyali (Enable)
    
    // Kontrol Sinyalleri
    input  wire                  w_en,         // Yazma yetki sinyali (Write Enable)
    input  wire                  r_en,         // Okuma yetki sinyali (Read Enable)
    
    // Veri Giriş / Çıkış Sinyalleri
    input  wire [DATA_WIDTH-1:0] data_in,      // Yazılacak veri girişi
    output wire [DATA_WIDTH-1:0] data_out,     // Okunan veri çıkışı
    
    // Durum (Status) Bayrakları
    output wire                  full,         // FIFO dolu bayrağı
    output wire                  empty         // FIFO boş bayrağı
);

    // ------------------------------------------------------------------------
    // Dahili Yazmaç (Register) ve Bellek Tanımlamaları
    // ------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] r_data_out;
    
    // FIFO bellek dizisi (Depth x Data Width)
    reg [DATA_WIDTH-1:0] fifo_ram [0:DEPTH_WIDTH-1]; 

    // Okuma ve Yazma Pointer'ları (Adres Göstergeleri)
    reg [$clog2(DEPTH_WIDTH)-1:0] r_ptr;
    reg [$clog2(DEPTH_WIDTH)-1:0] w_ptr;
    
    // Eleman Takip Sayıcı (0 ila DEPTH_WIDTH arası değer alabilmesi için +1 bit)
    reg [$clog2(DEPTH_WIDTH):0] counter;

    // ------------------------------------------------------------------------
    // Durum Bayraklarının Mantıksal Atamaları
    // ------------------------------------------------------------------------
    assign full  = (counter == DEPTH_WIDTH);
    assign empty = (counter == 0);

    // ------------------------------------------------------------------------
    // FIFO Kontrol Mantığı (Yazma, Okuma ve Pointer Güncellemeleri)
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_ptr      <= {($clog2(DEPTH_WIDTH)){1'b0}};
            w_ptr      <= {($clog2(DEPTH_WIDTH)){1'b0}};
            counter    <= {($clog2(DEPTH_WIDTH)+1){1'b0}};
            r_data_out <= {DATA_WIDTH{1'b0}};
        end else if (enable_FIFO) begin
            
            // Aynı çevrimde hem okuma hem yazma yapılıyorsa counter değerini korur
            case ({ (w_en && !full), (r_en && !empty) })
                2'b10: counter <= counter + 1'b1; // Sadece Yazma
                2'b01: counter <= counter - 1'b1; // Sadece Okuma
                default: counter <= counter;      // İşlem yok veya Hem Yazma Hem Okuma
            endcase

            // Yazma İşlemi: FIFO dolu değilse ve w_en aktifse veriyi belleğe yaz
            if (w_en && !full) begin
                fifo_ram[w_ptr] <= data_in;
                w_ptr           <= w_ptr + 1'b1; // Pointer otomatik taşma (wrap-around) yapar
            end

            // Okuma İşlemi: FIFO boş değilse ve r_en aktifse veriyi çıkışa aktar
            if (r_en && !empty) begin
                r_data_out <= fifo_ram[r_ptr];
                r_ptr      <= r_ptr + 1'b1;     // Pointer otomatik taşma (wrap-around) yapar
            end

        end
    end

    // Çıkış Ataması
    assign data_out = r_data_out;

endmodule
