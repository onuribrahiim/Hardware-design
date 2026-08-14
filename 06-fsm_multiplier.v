`timescale 1ns / 1ps

// ============================================================================
// Modül Adı    : carpici
// Yazar        : Halil İbrahim Onur
// Açıklama     : FSM (Sonlu Durum Makinesi) tabanlı, Kaydır ve Topla (Shift-and-Add) 
//                algoritması ile çalışan parametrik ardışıl (sequential) çarpma donanımı.
// ============================================================================

module carpici #(
    parameter DW = 6 // Veri Genişliği (Data Width)
)(
    input  wire              clk,      // Sistem Saat Sinyali
    input  wire              reset,    // Asenkron Reset Sinyali (Active-High)
    input  wire [DW-1:0]     carpilan, // Çarpılan Giriş Verisi (Multiplicand)
    input  wire [DW-1:0]     carpan,   // Çarpan Giriş Verisi (Multiplier)
    output wire [DW*2-1:0]   sonuc     // Çarpım Sonucu Çıkışı (Product Output)
);

    // ------------------------------------------------------------------------
    // Dahili Yazmaçlar (Internal Registers)
    // ------------------------------------------------------------------------
    reg [3:0]        state;       // FSM Mevcut Durum Yazmacı
    reg [DW*2-1:0]   r_carpan;    // Sağa kaydırma işlemi için genişletilmiş çarpan
    reg [DW*2-1:0]   r_carpilan;  // Sola kaydırma işlemi için genişletilmiş çarpılan
    reg [DW-4:0]     counter;     // Adım sayacı (İşlenen bit sayısını takip eder)
    reg [DW*2-1:0]   r_sonuc;     // Ara ve nihai çarpım sonucunu tutan akümülatör

    // ------------------------------------------------------------------------
    // FSM Durum Tanımlamaları (State Localparams)
    // ------------------------------------------------------------------------
    localparam start   = 4'b0001; // Başlangıç / Veri yükleme durumu
    localparam control = 4'b0010; // Bit ve döngü kontrol durumu
    localparam islem   = 4'b0011; // Toplama ve kaydırma adımı
    localparam DONE    = 4'b0100; // İşlem tamamlandı durumu

    // Çıkış bağlantısı
    assign sonuc = r_sonuc;

    // ------------------------------------------------------------------------
    // FSM ve Mantıksal İşlem Bloğu (Sequential Always Block)
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset durumunda tüm dahili yazmaçlar sıfırlanır ve FSM 'start'a geçer
            r_sonuc    <= 0;
            state      <= start;
            counter    <= 0;
            r_carpan   <= 0;
            r_carpilan <= 0;
        end else begin
            case (state)
                
                // 1. BAŞLANGIÇ DURUMU: Giriş verileri hizalanır ve yazmaçlara yüklenir
                start: begin
                    r_sonuc    <= 0;
                    counter    <= 0;
                    r_carpilan <= {{DW{1'b0}}, carpilan}; // Sıfır uzatması (Zero extension)
                    r_carpan   <= {{DW{1 me{1'b0}}, carpan};   // Sıfır uzatması (Zero extension)
                    state      <= control;
                end   
                
                // 2. KONTROL DURUMU: Bütün bitler işlendi mi veya LSB '1' mi kontrolü
                control: begin
                    if (counter == DW) begin
                        state <= DONE; // Tüm bitler işlendiyse bitişe git
                    end else if (r_carpan[0]) begin
                        state <= islem; // LSB 1 ise toplama aşamasına geç
                    end else begin
                        // LSB 0 ise toplama yapmadan kaydır ve bir sonraki bite geç
                        r_carpan   <= r_carpan >> 1;
                        r_carpilan <= r_carpilan << 1;
                        counter    <= counter + 1;
                    end
                end
                
                // 3. İŞLEM DURUMU: Akümülatöre ekleme ve kaydırma işlemi
                islem: begin
                    r_sonuc    <= r_sonuc + r_carpilan; // Çarpılanı mevcut sonuca ekle
                    r_carpilan <= r_carpilan << 1;      // Çarpılanı sola kaydır
                    r_carpan   <= r_carpan >> 1;        // Çarpanı sağa kaydır
                    counter    <= counter + 1;          // Adım sayacını artır
                    state      <= control;              // Tekrar kontrol durumuna dön
                end
                
                // 4. BİTİŞ DURUMU: Sonuç hazır, yeni işlem için başlangıca dönülür
                DONE: begin
                    state <= start;
                end
                
                // DEFAULT DURUM: Tanımsız durumlara karşı güvenli başlangıç
                default: begin
                    state <= start;
                end

            endcase
        end  
    end

endmodule
