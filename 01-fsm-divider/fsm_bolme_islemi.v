`timescale 1ns / 1ps
//================================================================================
// Proje Adı   : FSM Tabanlı Ardışık Bölme Modülü (Sequential Divider)
// Dosya Adı   : fsm_bolme_islemi.v
// Açıklama    : Parametrik bit genişliğine (W) sahip, çıkarma yöntemiyle 
//               bölüm (quotient) ve kalan (remainder) hesabını gerçekleştiren 
//               Sonlu Durum Makinesi (FSM).
//================================================================================

module fsm_bolme_islemi #(
    parameter W = 4  // İşlenecek verilerin bit genişliği (default: 4-bit)
)(
    // --- Sistem Sinyalleri ---
    input  wire         clk,      // Sistem saati
    input  wire         reset,    // Asenkron donanım reset sinyali (Aktif Yüksek)
    input  wire         flag,     // Bölme işlemini başlatan tetikleme sinyali (Start Flag)

    // --- Giriş Verileri ---
    input  wire [W-1:0] bolunen,  // Bölünen sayı (Dividend)
    input  wire [W-1:0] bolen,    // Bölen sayı (Divisor)

    // --- Çıkış Verileri ---
    output wire [W-1:0] sonuc,    // Bölüm sonucu (Quotient)
    output wire [W-1:0] kalan,    // Bölme işleminden kalan (Remainder)
    output wire         DURUM     // Hata/Sıfıra Bölme durum bayrağı (Error/Invalid Flag)
);

    //----------------------------------------------------------------------------
    // Dahili Yazmaçlar ve Bağlantılar (Internal Registers & Wires)
    //----------------------------------------------------------------------------
    reg [W-1:0] r_bolen;      // Saklanan bölen değeri
    reg [W-1:0] r_bolunen;    // Çıkarma işlemleri sırasında güncellenen bölünen
    reg         r_DURUM;      // Hata durumunu tutan yazmaç
    reg [2:0]   state;        // FSM mevcut durum yazmacı
    reg [W-1:0] r_sonuc;      // Bölüm sonucunu tutan yazmaç
    reg [W-1:0] count;        // Kaç kez çıkarma yapıldığını sayan yazmaç (Bölüm)
    reg [W-1:0] r_kalan;      // Kalan değerini tutan yazmaç

    // Sürekli Atamalar (Continuous Assignments)
    assign kalan = r_kalan;
    assign sonuc = r_sonuc;
    assign DURUM = r_DURUM;

    //----------------------------------------------------------------------------
    // FSM Durum Tanımlamaları (State Encoding)
    //----------------------------------------------------------------------------
    localparam start = 3'b000;  // Değişkenlerin ilklendirilmesi (Initialization)
    localparam L1    = 3'b001;  // Bölünebilirlik ve 0'a bölme kontrolü
    localparam L2    = 3'b010;  // Çıkarma adımı ve sayaç artırma
    localparam L3    = 3'b011;  // Döngü kontrol adımı
    localparam DONE  = 3'b100;  // Başarılı bitiş ve sonuçların kaydedilmesi
    localparam IDLE  = 3'b101;  // Yeni tetikleme bekleniyor
    localparam out   = 3'b110;  // Hata durumu (Örn: 0'a bölme hatası)

    //----------------------------------------------------------------------------
    // FSM ve Mantıksal Blok (Sequential Logic)
    //----------------------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= start;
        end else begin
            case (state)
                
                // --- 1. Başlangıç Durumu ---
                start: begin
                    r_bolunen <= bolunen;
                    r_bolen   <= bolen;
                    r_kalan   <= {W{1'b0}};
                    r_sonuc   <= {W{1'b0}};
                    count     <= {W{1 me0}};
                    r_DURUM   <= 1'b0;
                    state     <= L1;
                end
                
                // --- 2. Kontrol Durumu ---
                // Bölen 0 değilse ve bölünen büyük/eşitse çıkarma döngüsüne girer.
                L1: begin
                    if (r_bolunen >= r_bolen && r_bolen != 0) begin
                        state <= L2;
                    end else begin
                        state <= out; // Hata veya yetersiz bölünen durumu
                    end
                end
                
                // --- 3. Çıkarma İşlemi ---
                L2: begin
                    r_bolunen <= r_bolunen - r_bolen;
                    count     <= count + 1'b1;
                    state     <= L3;     
                end
                
                // --- 4. Döngü Karar Adımı ---
                L3: begin
                    if (r_bolunen >= r_bolen) begin
                        state <= L2;   // Çıkarmaya devam et
                    end else begin
                        state <= DONE; // Çıkarma bitti, kalan elde edildi
                    end
                end
                
                // --- 5. Hata Çıkış Durumu ---
                out: begin  
                    r_DURUM <= 1'b1;   // Hata bayrağını kaldır
                    state   <= IDLE;
                end
                
                // --- 6. Başarılı Tamamlanma ---
                DONE: begin
                    r_kalan <= r_bolunen; // Kalan değer ataması
                    r_sonuc <= count;     // Elde edilen bölüm ataması
                    state   <= IDLE;
                end 
                
                // --- 7. Boşta/Bekleme Durumu ---
                IDLE: begin 
                    if (flag)
                        state <= start;  // Yeni işlem tetiklendi
                end
                
                // --- Default Durum (Kilitlenmeyi Önleme) ---
                default: begin
                    state <= start;
                end
                
            endcase
        end
    end

endmodule
