`timescale 1ns / 1ps // Zaman ölçeği: 1ns simülasyon adımı / 1ps hassasiyet

module new_LFSR #(
parameter DATA_WIDTH =6 // Parametrik veri genişliği (Varsayılan: 6 bit)
)
(
input wire                    clk       , // Saat sinyali
input wire                    reset     , // Asenkron reset sinyali (Active-High)
input wire [DATA_WIDTH-1:0]  data_in    , // Dışarıdan verilen başlangıç değeri (Seed)
output reg [DATA_WIDTH-1:0]  data       , // Üretilen psödo-rastgele sayı çıkışı
output reg [0:0]              o_ERR        // Sıfır/Kilitlenme hata bayrağı (Active-High)

);

// Geri besleme (Feedback) hesabı: En üst bit (MSB) ile en alt bit (LSB) XOR'lanarak yeni bit üretilir
wire [0:0] feedback = data[DATA_WIDTH-1] ^  data[DATA_WIDTH-6] ;


    // Saat veya Reset'in yükselen kenarında tetiklenen ardışıl (sequential) mantık bloğu
    always @(posedge clk or posedge reset) begin
           if(reset)begin
             data<=data_in; // Reset anında dışarıdan verilen Seed verisini kaydırmalı yazmaca yükle
             o_ERR<=0;      // Reset anında hata bayrağını temizle
           end else begin
           if(data!=0)begin
           // Veri sıfırdan farklıysa: Yeni feedback bitini başa ekle ve veriyi 1 bit sağa kaydır
           data<={feedback,data[DATA_WIDTH-1:1]};
           o_ERR<=0; // Sistem normal çalıştığı sürece hata bayrağı pasif
           end else begin
            o_ERR<=1; // Veri sıfıra düşerse (kilitlenme durumu) hata bayrağını aktif yap
           end
           end
    end


endmodule
