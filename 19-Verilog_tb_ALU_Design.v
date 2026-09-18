`timescale 1ns / 1ps // Simülasyon zaman birimi (1ns) ve çözünürlüğü (1ps)

// ============================================================================
// Modül İsmi: tb_ALU_DESING
// Tanım     : ALU_DESING top-level modülü için yazılmış testbench dosyası.
// ============================================================================
module tb_ALU_DESING();

parameter DATA_WIDTH=8; // Test edilecek veri genişliği parametresi

// DUT girişlerine değer sürmek için yazmaç (reg) tanımlamaları
reg [DATA_WIDTH-1:0] A       ;
reg [DATA_WIDTH-1:0] B       ;
reg [1:0]            S       ;

// DUT çıkışlarını okumak için tel (wire) tanımlamaları
wire ERR_done;
wire [DATA_WIDTH*2-1:0] data_out;

// Test Edilen Devrenin (DUT) Bağlanması (Instantiation)
ALU_DESING #(
.DATA_WIDTH(DATA_WIDTH)
)ALU_DESING_DUT(
.A        (A        ),
.B        (B        ),
.S        (S        ),
.ERR_done (ERR_done ),
.data_out (data_out )
);

// Ana Test Blokları ve Uyaran (Stimulus) Üretimi
initial begin

//  TEST 1: Booth Çarpan Modunun Test Edilmesi (S = 2'b00)
$display("--------TEST1---------");
repeat(10)begin
A=$random & (2**(DATA_WIDTH-1)-1); // Taşmayı önlemek için pozitif 7-bitlik rastgele sayı üretimi
B=$random & (2**(DATA_WIDTH-1)-1);
S=2'b00;                           // Seçim sinyali: Çarpma
#10;                               // Kombinezonal devrenin oturması için 10ns bekleme
$display(" A=%d | B=%d | Sonuç=%d | islem durumu=booth_multiplier",A , B ,data_out);
end
#10;

//  TEST 2: Karşılaştırıcı Modunun Test Edilmesi (S = 2'b01)    
$display("--------TEST2---------"); 
repeat(10)begin             
A=$random & (2**(DATA_WIDTH-1)-1);
B=$random & (2**(DATA_WIDTH-1)-1);
S=2'b01;                           // Seçim sinyali: Karşılaştırma
#10;
$display(" A=%d | B=%d | Sonuç=%b | islem durumu=comparator",A , B , data_out); 
end                 
#10;                                                

//  TEST 3: Toplayıcı Modunun Test Edilmesi (S = 2'b10)  
$display("--------TEST3---------");  
repeat(10)begin              
A=$random & (2**(DATA_WIDTH-1)-1);
B=$random & (2**(DATA_WIDTH-1)-1);
S=2'b10;                           // Seçim sinyali: Toplama
#10; 
$display(" A=%d | B=%d | Sonuç=%d | islem durumu=adder",A , B , data_out); 
end                                                
#10;                                                

//  TEST 4: Çıkarıcı Modunun Test Edilmesi (S = 2'b11) 
$display("--------TEST4---------"); 
repeat(10)begin                
A=$random &(2**(DATA_WIDTH-1)-1);
B=$random &(2**(DATA_WIDTH-1)-1);
S=2'b11;                           // Seçim sinyali: Çıkarma
#10; 
// $signed fonksiyonu ile 2's complement formatındaki negatif sonuçlar doğru biçimde gösterilir
$display(" A=%d | B=%d | Sonuç=%d | islem durumu=subtractor",A , B , $signed(data_out));
end                                                 
#10;                                                 
                                                    
$finish; // Simülasyonu sonlandır
end
endmodule
