`timescale 1ns / 1ps // Zaman ölçeği: 1ns simülasyon birimi / 1ps çözünürlük

module tb_new_LFSR();
parameter DATA_WIDTH =6; // Veri genişliği (6-bit = 2^6 - 1 = 63 adımlık Maximal Length periyodu)

// --- Sinyal Tanımlamaları ---
reg                     clk                     ; // Saat sinyali
reg                     reset                   ; // Reset sinyali
reg  [DATA_WIDTH-1:0] data_in  ; // Başlangıç değeri (Seed)
wire  [DATA_WIDTH-1:0] data     ; // LFSR'den üretilen rastgele sayı
wire [0:0] o_ERR                ; // Kilitlenme / Hata bayrağı

// --- Test Edilecek Modülün (DUT) Çağrılması ---
new_LFSR #(
.DATA_WIDTH(DATA_WIDTH)
)LFSR_DUT(
.clk    (clk    ),
.reset  (reset  ),
.data_in(data_in),
.data   (data   ),
.o_ERR  (o_ERR  )
);

// --- Saat Sinyali Üreteci (Periyot = 20ns) ---
initial begin 
clk=1;
forever #10 clk=~clk; // Her 10ns'de bir saat durum değiştirir
end

// --- Test Senaryosu ---
initial begin
reset=1; // Reset aktif: LFSR'ye Seed yükleme durumu
data_in=$random %(2**DATA_WIDTH); // Matris/RAM doldurmak için 0-63 arası rastgele Seed seçimi
#20; // 1 clock periyodu bekle
$display("data_in=%d",data_in); // Yüklenen Seed değerini ekrana bas
reset=0; // Reset kaldırılır, LFSR kendi içinde kaydırmaya başlar

// Maximal Length Testi: 6-bit LFSR en fazla 63 adımlık tekrarsız dizi üretir.
// repeat(70) ile hem 63 adımlık dizilimi hem de başa dönüş periyodunu doğruluyoruz.
repeat(70)begin
#20; // Her saat darbesinde bekle
$display("data=%d",data); // Üretilen psödo-rastgele veriyi ekrana bas
end
$finish; // Simülasyonu bitir
end
endmodule
