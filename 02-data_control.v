`timescale 1ns / 1ps

/* ==============================================================================
 * Modül Adı    : data_control
 * Geliştirici  : İbrahim Onur
 * Açıklama     : Bu modül, 3 bitlik giriş verisini (data_in) dairesel kaydırma 
 *                (circular shift) yöntemiyle kontrol eder. Gelen verinin tüm 
 *                bitlerinin '1' (3'b111) olup olmadığını denetleyen bir 
 *                Sonlu Durum Makinesi (FSM) içerir. Tüm bitler '1' ise 
 *                hata çıkışı (o_ERR) aktif edilir.
 * ============================================================================== */

module data_control(
    input clk,               // Sistem saat sinyali
    input reset,             // Asenkron reset sinyali (Aktif yüksek)
    input [2:0] data_in,     // Kontrol edilecek 3-bitlik giriş verisi
    input wire flag,         // FSM'i başlatan tetikleyici/kontrol bayrağı
    
    output reg [2:0] o_ERR   // Hata çıkış sinyali (Hedef durum sağlandığında 3'b001 olur)
);

    // İç sinyaller ve register tanımlamaları
    reg d_in;                // Kontrol edilen anlık bit (MSB)
    reg [2:0] data_shift;    // Giriş verisinin tutulduğu register
    reg [2:0] state;         // FSM durum register'ı
    reg [2:0] temp;          // Kaydırma işlemlerinin yapıldığı geçici register

    // FSM Durumları (State Encoding)
    localparam start = 3'd0; // Başlangıç ve veri alma durumu
    localparam S0    = 3'd1; // İlk kaydırma işlemi
    localparam S1    = 3'd2; // 1. bitin kontrolü
    localparam S2    = 3'd3; // İkinci kaydırma işlemi
    localparam S3    = 3'd4; // 2. bitin kontrolü
    localparam S4    = 3'd5; // Üçüncü kaydırma işlemi
    localparam S5    = 3'd6; // 3. bitin kontrolü ve hata ataması
    localparam IDLE  = 3'd7; // Bekleme/Sıfırlama durumu

    // Kombinezonal Blok: d_in her zaman temp register'ının en anlamlı bitini (MSB) okur
    always @(*) begin
        d_in = temp[2];
    end

    // Ardışıl Blok: FSM ve senkron/asenkron atamalar
    always @(posedge clk or posedge reset) begin
        
        // Asenkron Reset Bloğu
        if (reset) begin
            state      <= start; // State 0'a çekilir (start)
            o_ERR      <= 0;
            data_shift <= 0;
            d_in       <= 0;
            temp       <= 0;
        end 
        
        // FSM İşleyiş Bloğu
        else begin
            case (state)
                
                // Başlangıç: Veriyi kaydırma register'ına al ve bayrağı bekle
                start: begin
                    data_shift <= data_in;
                    if (flag)
                        state <= S0;
                end
                
                // S0: İlk dairesel sola kaydırma (circular left shift) işlemi
                S0: begin
                    temp  <= {data_shift[1:0], data_shift[2]};
                    state <= S1;
                end
                
                // S1: 1. Bit Kontrolü
                S1: begin
                    if (d_in == 1'b1) begin
                        state <= S2; // Bit '1' ise kontrol etmeye devam et
                    end else begin
                        o_ERR <= 0;
                        state <= IDLE; // Bit '0' ise kontrolü iptal et
                    end
                end
                
                // S2: İkinci dairesel sola kaydırma işlemi
                S2: begin
                    temp  <= {temp[1:0], temp[2]};
                    state <= S3;
                end
                
                // S3: 2. Bit Kontrolü
                S3: begin
                    if (d_in == 1'b1) begin
                        state <= S4; // Bit '1' ise devam et
                    end else begin
                        o_ERR <= 0;
                        state <= IDLE;
                    end
                end
                
                // S4: Üçüncü dairesel sola kaydırma işlemi
                S4: begin
                    temp  <= {temp[1:0], temp[2]};
                    state <= S5;
                end
                
                // S5: 3. Bit Kontrolü ve Sonuç
                S5: begin
                    if (d_in == 1'b1) begin
                        o_ERR <= 1;    // Tüm bitler '1' çıktı, hata (ERR) sinyalini yak
                        state <= IDLE;
                    end else begin
                        o_ERR <= 0;
                        state <= IDLE;
                    end
                end
                
                // IDLE: Döngüyü başa sar
                IDLE: begin
                    state <= start;
                end
                
                // Default: Güvenlik amaçlı (istenmeyen bir duruma girilirse başa dön)
                default: begin
                    state <= start;
                    o_ERR <= 0;
                end
                
            endcase
        end
    end

endmodule
