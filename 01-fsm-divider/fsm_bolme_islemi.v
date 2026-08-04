`timescale 1ns / 1ps

module fsm_bolme_islemi #(
    parameter W = 4                     // Veri genişliği (Bit sayısı)
)(
    input wire clk,                     // Saat sinyali
    input wire reset,                   // Reset sinyali (Aktif Yüksek)
    input wire [W-1:0] bolunen,         // Bölünecek sayı girdisi
    input wire [W-1:0] bolen,           // Bölen sayı girdisi
    output wire [W-1:0] sonuc,          // Bölüm sonucu (Bölme işleminin çıktısı)
    output wire DURUM                   // Hata/Durum bayrağı (0: İşlem Başarılı, 1: Tanımsız/Sıfıra Bölme Hatası)
);

    // Dahili saklayıcılar (Register tanımlamaları)
    reg [W-1:0] r_bolen;
    reg [W-1:0] r_bolunen;
    reg r_DURUM;   
    reg [W-2:0] state;                  // FSM durum saklayıcısı

    reg [W-1:0] r_sonuc;                // Bölüm sonucunu tutan saklayıcı
    reg [W-1:0] count;                  // Arka arkaya çıkarma sayacı (Bölüm değerini hesaplar)

    // Çıkış atamaları
    assign sonuc = r_sonuc;
    assign DURUM = r_DURUM;

    // FSM Durum Kodlamaları
    localparam start = 3'b000;          // Başlangıç ve girdi kayıt durumu
    localparam L1    = 3'b001;          // İlk kontrol durumu (Bölen/Bölünen kıyası)
    localparam L2    = 3'b010;          // Çıkarma işlemi ve sayaç artırma
    localparam L3    = 3'b011;          // Döngü devam kontrolü
    localparam DONE  = 3'b100;          // İşlem başarıyla tamamlandı
    localparam ZERO  = 3'b101;          // Bölünen < Bölen durumu (Sonuç = 0)

    // FSM ve Mantıksal İşlem Bloğu
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= start;             // Reset durumunda başlangıca dön
        end else begin
            case (state)
                
                // --- BAŞLANGIÇ DURUMU ---
                start: begin
                    r_bolunen <= bolunen;   // Girdileri dahili saklayıcılara al
                    r_bolen   <= bolen;
                    r_sonuc   <= 0;         // Sonucu sıfırla
                    count     <= 0;         // Çıkarma sayacını sıfırla
                    r_DURUM   <= 0;         // DURUM = 0: İşlem normal devam ediyor
                    state     <= L1;
                end
                
                // --- İLK KONTROL DURUMU ---
                L1: begin
                    if (r_bolunen >= r_bolen) begin
                        state <= L2;        // Bölünen büyükse çıkarma döngüsüne gir
                    end else begin
                        state <= ZERO;      // Bölünen küçükse sonuç 0'dır, ZERO durumuna git
                    end
                end
                
                // --- ÇIKARMA İŞLEMİ DURUMU ---
                L2: begin
                    r_bolunen <= r_bolunen - r_bolen; // Art arda çıkarma
                    count     <= count + 1;           // Bölüm değerini artır
                    state     <= L3;     
                end
                
                // --- DÖNGÜ KONTROL DURUMU ---
                L3: begin
                    if (r_bolunen >= r_bolen) begin
                        state <= L2;        // Çıkarmaya devam et
                    end else begin
                        state <= DONE;      // Çıkarma bitti, tamamlandı durumuna geç
                    end
                end
                
                // --- TAMAMLANDI DURUMU (Bölünen >= Bölen İse) ---
                DONE: begin
                    r_sonuc <= count;       // Hesaplanan bölümü çıkışa aktar
                    r_DURUM <= 0;           // DURUM = 0: İşlem başarıyla tamamlandı
                    state   <= start;       // Başlangıca dön
                end 
                
                // --- BÖLÜNEN < BÖLEN DURUMU ---
                ZERO: begin  
                    r_sonuc <= 0;           // Bölünen küçük olduğu için sonuç doğrudan 0
                    r_DURUM <= 0;           // DURUM = 0: İşlem başarılı (Hata değil)
                    state   <= start;       // Başlangıca dön
                end
                
                // --- VARSAYILAN DURUM ---
                default: begin
                    state <= start;
                end
                
            endcase
        end
    end

endmodule
