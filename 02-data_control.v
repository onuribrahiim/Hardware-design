`timescale 1ns / 1ps
//================================================================================
// Proje Adı   : Veri Hata Kontrol Modülü (Data Control Module)
// Dosya Adı   : data_control.v
// Açıklama    : 3-bitlik giriş verisini (data_in) bit bit döndürerek (shift/rotate)
//               tüm bitlerinin '1' olup olmadığını (3'b111 durumu) denetleyen FSM.
//               Üst modülle (TOP) Request/Acknowledge (flag / o_ERR_done) el
//               sıkışma protokolü ile haberleşir.
//================================================================================

module data_control (
    input  wire       clk,         // Sistem saati
    input  wire       reset,       // Asenkron donanım reset sinyali (Aktif Yüksek)
    input  wire [2:0] data_in,     // Kontrol edilecek 3-bitlik veri
    input  wire       flag,        // Üst modülden gelen işlem başlatma isteği (Request)
    
    output reg        o_ERR,       // Hata bayrağı (1: Tüm bitler 1 / 0: Hata yok)
    output wire       o_ERR_done   // İşlem bitti/hazır bayrağı (Acknowledge)
);

    //----------------------------------------------------------------------------
    // Dahili Yazmaçlar ve Bağlantılar (Internal Registers & Wires)
    //----------------------------------------------------------------------------
    reg [2:0] data_shift;  // Giriş verisinin ilk durumunu saklayan yazmaç
    reg [2:0] temp;        // Bit döndürme (rotate) işlemleri için geçici yazmaç
    reg [2:0] state;       // FSM mevcut durum yazmacı
    reg       r_ERR_done;  // İşlem bitti sinyalini tutan iç yazmaç
    reg       d_in;        // O anki kontrol edilen bit (temp[2])

    // Sürekli Atama (Continuous Assignment)
    assign o_ERR_done = r_ERR_done;

    //----------------------------------------------------------------------------
    // FSM Durum Tanımlamaları (State Encoding)
    //----------------------------------------------------------------------------
    localparam START = 3'd0;  // Başlangıç ve Istek (flag) bekleme durumu
    localparam S0    = 3'd1;  // 1. Bit kaydırma/hazırlık adımı
    localparam S1    = 3'd2;  // 1. Bit kontrol adımı
    localparam S2    = 3'd3;  // 2. Bit kaydırma adımı
    localparam S3    = 3'd4;  // 2. Bit kontrol adımı
    localparam S4    = 3'd5;  // 3. Bit kaydırma adımı
    localparam S5    = 3'd6;  // 3. Bit kontrol ve Hata Karar adımı
    localparam DONE  = 3'd7;  // Tamamlandı/El sıkışma bekleme durumu

    // Combinational MUX: Kontrol edilecek biti daima temp yazmacının MSB'sinden al
    always @(*) begin
        d_in = temp[2];
    end

    //----------------------------------------------------------------------------
    // FSM Mantıksal Bloğu (Sequential Logic)
    //----------------------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state      <= START;
            o_ERR      <= 1'b0;
            data_shift <= 3'd0;
            temp       <= 3'd0;
            r_ERR_done <= 1'b0;
        end else begin
            case (state)

                // --- 1. Başlangıç Durumu ---
                START : begin
                    o_ERR      <= 1'b0;
                    r_ERR_done <= 1'b0;
                    data_shift <= data_in; // Giriş verisini mandalla (latch)
                    if (flag)
                        state  <= S0;      // Istek geldiğinde seriyi başlat
                end

                // --- 2. Birinci Bit Kontrolü (data_shift[1]) ---
                S0 : begin
                    // Dairesel sola kaydırma (Rotate Left)
                    temp  <= {data_shift[1:0], data_shift[2]};
                    state <= S1;
                end
                
                S1 : begin
                    if (d_in) begin
                        state <= S2; // 1. bit '1' ise 2. biti kontrole geç
                    end else begin
                        // Bit '0' ise 3'b111 olamaz, erken çıkış yap (Hata Yok)
                        o_ERR      <= 1'b0;
                        r_ERR_done <= 1'b1;
                        state      <= DONE;
                    end
                end

                // --- 3. İkinci Bit Kontrolü (data_shift[0]) ---
                S2 : begin
                    temp  <= {temp[1:0], temp[2]};
                    state <= S3;
                end
                
                S3 : begin
                    if (d_in) begin
                        state <= S4; // 2. bit de '1' ise son biti kontrole geç
                    end else begin
                        // Bit '0' ise erken çıkış yap (Hata Yok)
                        o_ERR      <= 1'b0;
                        r_ERR_done <= 1'b1;
                        state      <= DONE;
                    end
                end

                // --- 4. Üçüncü Bit Kontrolü ve Karar (data_shift[2]) ---
                S4 : begin
                    temp  <= {temp[1:0], temp[2]};
                    state <= S5;
                end
                
                S5 : begin
                    // 3 bitin üçü de 1 ise d_in=1 olur ve o_ERR=1 basılır
                    o_ERR      <= d_in;   
                    r_ERR_done <= 1'b1;
                    state      <= DONE;
                end

                // --- 5. El Sıkışma (Handshake) Bekleme Durumu ---
                // Üst modül flag sinyalini sıfırlayana kadar sonucu tutar.
                DONE : begin
                    r_ERR_done <= 1'b1; // İşlem tamamlandı bildirimi
                    if (!flag) begin
                        // Üst modül isteği indirdiğinde (ack alındığında) sıfırla
                        r_ERR_done <= 1'b0;
                        data_shift <= 3'd0;
                        temp       <= 3'd0;
                        state      <= START;
                    end
                end

                // --- Default Durum (Kilitlenmeyi Önleme) ---
                default : begin
                    state      <= START;
                    o_ERR      <= 1'b0;
                    r_ERR_done <= 1'b0;
                end

            endcase
        end
    end

endmodule
