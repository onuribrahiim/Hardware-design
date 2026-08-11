`timescale 1ns / 1ps
//================================================================================
// Proje Adı   : LFSR & RAM Entegre Hata Kontrol Sistemi (Top Level Module)
// Dosya Adı   : TOP_RAM_LFSR.v
// Açıklama    : LFSR ile üretilen 6-bitlik rastgele verileri RAM belleğe yazar.
//               Daha sonra verileri sırayla bellekten okuyarak MSB tarafındaki 
//               3 biti 'data_control' alt modülü ile denetler. 
//               Bitlerin tamamı '1' ise hata biti (MSB) 1, aksi halde 0 olacak 
//               şekilde {hata, veri} formatında (7-bit) dış dünyaya sunar.
//
// Akış Adımları:
//   1. LFSR'den 16 adet rastgele veri üretilip RAM'e yazılır.
//   2. RAM'deki veriler sırayla okunur.
//   3. 'data_control' modülü ile üst 3 bitin hata analizi yapılır.
//   4. Elde edilen sonuçlar 'o_valid' eşliğinde 'o_data_out' çıkışına aktarılır.
//================================================================================

module TOP_RAM_LFSR #(
    parameter DW        = 6         , // LFSR veri genişliği (6-bit)
    parameter AW        = 4         , // RAM adres genişliği (4-bit -> 16 adres)
    parameter WW        = 7         , // Çıkış kelime genişliği {hata_biti, 6-bit_veri}
    parameter RAM_DEPTH = (2**AW)     // Bellek derinliği (16 kelime)
)(
    // --- Sistem Sinyalleri ---
    input  wire                 i_clk_top   , // Ana sistem saati
    input  wire                 i_reset_top , // Asenkron donanım reset sinyali (Aktif Yüksek)
    
    // --- Sistem Çıkış Sinyalleri ---
    output wire                 o_ok        , // Tüm 16 verinin işlenmesi bitti bildirimi (1 çevrimlik palse)
    output wire                 o_valid     , // o_data_out üzerindeki verinin geçerli olduğu an (1 çevrimlik palse)
    output wire [WW-1:0]        o_data_out    // İşlenmiş nihai veri çıkışı {hata_biti, veri}
);

    //----------------------------------------------------------------------------
    // Dahili Çıkış Yazmaçları ve Bağlantılar (Output Registers & Wires)
    //----------------------------------------------------------------------------
    reg           r_o_ok;
    reg           r_o_valid;
    reg  [WW-1:0] r_o_data_out;

    assign o_ok       = r_o_ok;
    assign o_valid    = r_o_valid;
    assign o_data_out = r_o_data_out;

    //----------------------------------------------------------------------------
    // LFSR Alt Modülü ve Sinyal Tanımlamaları
    //----------------------------------------------------------------------------
    reg           r_reset_lfsr;
    reg           r_en_LFSR;
    reg  [DW-1:0] r_data_LFSR;
    wire [DW-1:0] w_data_LFSR;

    LFSR #(
        .DW_LFSR (DW)
    ) LFSR_DUT (
        .i_clk_LFSR    (i_clk_top   ),
        .i_reset_LFSR  (r_reset_lfsr),
        .i_enable_LFSR (r_en_LFSR   ),
        .i_data_LFSR   (r_data_LFSR ),
        .o_data_LFSR   (w_data_LFSR )
    );

    //----------------------------------------------------------------------------
    // RAM Alt Modülü ve Sinyal Tanımlamaları
    //----------------------------------------------------------------------------
    reg  [WW-1:0] r_wdata_ram;
    reg  [AW-1:0] r_addr_ram;
    reg           r_en_ram;
    reg           r_re_ram;
    reg           r_we_ram;
    wire [WW-1:0] w_rdata_ram;

    RAM_Design #(
        .WIDTH_DATA  (WW       ),
        .WIDTH_ADDR  (AW       ),
        .WIDTH_DEPTH (RAM_DEPTH)
    ) RAM_Design_DUT (
        .i_clk_ram    (i_clk_top  ),
        .i_wdata_ram  (r_wdata_ram),
        .i_addr_ram   (r_addr_ram ),
        .i_enable_ram (r_en_ram   ),
        .i_re_ram     (r_re_ram   ),
        .i_we_ram     (r_we_ram   ),
        .o_rdata_ram  (w_rdata_ram)
    );

    //----------------------------------------------------------------------------
    // Hata Kontrol (data_control) Alt Modülü ve Sinyalleri
    //----------------------------------------------------------------------------
    reg        r_ERR;
    reg [2:0]  r_data_in;
    reg        r_flag;
    wire       w_o_ERR;
    wire       w_o_ERR_done;

    data_control data_control_DUT (
        .clk        (i_clk_top   ),
        .reset      (i_reset_top ),
        .data_in    (r_data_in   ),
        .flag       (r_flag      ),
        .o_ERR      (w_o_ERR     ),
        .o_ERR_done (w_o_ERR_done)
    );

    //----------------------------------------------------------------------------
    // Ana FSM Durum Tanımlamaları (State Encoding & Parameters)
    //----------------------------------------------------------------------------
    localparam BASLA                = 4'd0; // Başlangıç ve LFSR resetleme
    localparam RND_DEGER_AL         = 4'd1; // LFSR değerinin hazırlandığı ara durum
    localparam RAM_YAZ              = 4'd2; // Üretilen verinin RAM'e yazılması
    localparam SONRAKI             = 4'd3; // Yazma sayacının artırılması ve mod kontrolü
    localparam RAM_OKU              = 4'd4; // RAM'den ilgili adresin okunması
    localparam HATA_SORGULAMA_BASLA = 4'd5; // Verinin üst 3 bitinin kontrol modülüne iletilmesi
    localparam HATA_SORGULA         = 4'd6; // Hata analizinin tamamlanmasının beklenmesi
    localparam HATA_YAZ             = 4'd8; // Sonucun o_data_out çıkışına sürülmesi

    localparam SEED = 6'b101010;            // LFSR başlangıç çekirdek (seed) değeri

    reg [3:0]    state;      // FSM mevcut durum yazmacı
    reg [AW-1:0] r_wcounter; // RAM yazma adresi sayacı
    reg [AW-1:0] r_counter;  // RAM okuma adresi sayacı

    //----------------------------------------------------------------------------
    // Ana FSM Mantıksal Bloğu (Sequential State Machine)
    //----------------------------------------------------------------------------
    always @(posedge i_clk_top or posedge i_reset_top) begin
        if (i_reset_top) begin
            // --- Reset Anında Tüm Yazmaçların İlklendirilmesi ---
            state        <= BASLA;
            r_o_ok       <= 1'b0;
            r_o_valid    <= 1'b0;
            r_o_data_out <= {WW{1'b0}};

            r_reset_lfsr <= 1'b0;
            r_en_LFSR    <= 1'b0;
            r_data_LFSR  <= SEED;

            r_wdata_ram  <= {WW{1'b0}};
            r_addr_ram   <= {AW{1'b0}};
            r_en_ram     <= 1'b0;
            r_re_ram     <= 1 me0;
            r_we_ram     <= 1'b0;

            r_ERR        <= 1'b0;
            r_data_in    <= 3'd0;
            r_flag       <= 1'b0;

            r_wcounter   <= {AW{1'b0}};
            r_counter    <= {AW{1'b0}};
        end else begin
            case (state)

                // ===============================================================
                // AŞAMA 1: RAM YAZMA AKIŞI (RAM WRITE PROCESS)
                // ===============================================================
                
                // 1.1 Sistem İlklendirmesi ve LFSR Yükleme
                BASLA : begin
                    r_o_ok       <= 1'b0;
                    r_o_valid    <= 1'b0;
                    r_data_LFSR  <= SEED;
                    r_reset_lfsr <= 1'b1;      // LFSR çekirdeğini (seed) yükle
                    r_en_LFSR    <= 1'b0;
                    r_wcounter   <= {AW{1'b0}};
                    r_counter    <= {AW{1'b0}};
                    state        <= RND_DEGER_AL;
                end

                // 1.2 LFSR Reset İndirme ve RAM Sinyalleri Hazırlığı
                RND_DEGER_AL : begin
                    r_reset_lfsr <= 1'b0;
                    r_en_LFSR    <= 1'b0;
                    r_en_ram     <= 1'b0;
                    r_re_ram     <= 1'b0;
                    r_we_ram     <= 1'b0;
                    state        <= RAM_YAZ;
                end

                // 1.3 Veriyi RAM'e Yazma ve LFSR'yi 1 Adım Kaydırma
                RAM_YAZ : begin
                    r_en_ram    <= 1'b1;
                    r_re_ram    <= 1'b0;
                    r_we_ram    <= 1'b1;
                    r_addr_ram  <= r_wcounter;
                    r_wdata_ram <= {1'b0, w_data_LFSR}; // MSB varsayılan 0 olarak yazılır
                    r_en_LFSR   <= 1'b1;               // Sonraki çevrimde LFSR 1 kaydırılır
                    state       <= SONRAKI;
                end

                // 1.4 Yazma Sayacı Kontrolü ve Okuma Evresine Geçiş Kararı
                SONRAKI : begin
                    r_en_LFSR <= 1'b0;
                    if (r_wcounter == RAM_DEPTH-1) begin
                        // RAM tamamen doldu; yazmayı kapat, adres 0'dan okumayı başlat
                        r_wcounter <= {AW{1'b0}};
                        r_addr_ram <= {AW{1'b0}};
                        r_en_ram   <= 1'b1;
                        r_we_ram   <= 1'b0;
                        r_re_ram   <= 1'b1;            // Okuma önceden başlatılarak BRAM gecikmesi karşılanır
                        state      <= RAM_OKU;
                    end else begin
                        r_en_ram   <= 1'b0;
                        r_we_ram   <= 1'b0;
                        r_re_ram   <= 1'b0;
                        r_wcounter <= r_wcounter + 1'b1;
                        state      <= RND_DEGER_AL;
                    end
                end

                // ===============================================================
                // AŞAMA 2: RAM OKUMA VE HATA KONTROL AKIŞI (READ & CHECK)
                // ===============================================================

                // 2.1 RAM'den Veri Okuma Adımı
                RAM_OKU : begin
                    r_o_valid  <= 1'b0;
                    r_en_ram   <= 1'b1;
                    r_re_ram   <= 1'b1;
                    r_we_ram   <= 1'b0;
                    r_addr_ram <= r_counter;
                    state      <= HATA_SORGULAMA_BASLA;
                end

                // 2.2 Okunan Verinin Üst 3 Bitini Kontrol Modülüne İletme
                HATA_SORGULAMA_BASLA : begin
                    r_data_in <= w_rdata_ram[DW-1:DW-3]; // Verinin [5:3] bitleri alınır
                    r_flag    <= 1'b1;                  // Control modülüne analiz başlama isteği (Request)
                    state     <= HATA_SORGULA;
                end

                // 2.3 Kontrol Modülünün Analizini Bekleme (Handshake Ack)
                HATA_SORGULA : begin
                    if (w_o_ERR_done) begin
                        r_ERR  <= w_o_ERR;   // Hata sonucunu kaydet (1: Hatalı / 0: Temiz)
                        r_flag <= 1'b0;      // Istek sinyalini indir (Request Clear)
                        state  <= HATA_YAZ;
                    end
                end

                // 2.4 Sonucu Dış Çıkışa Aktarma ve Döngü Tamamlama
                HATA_YAZ : begin
                    r_o_data_out <= {r_ERR, w_rdata_ram[DW-1:0]}; // {Hata_Biti, 6-bit Veri}
                    r_o_valid    <= 1'b1;                         // Çıkış verisi geçerli bayrağı

                    if (r_counter == RAM_DEPTH-1) begin
                        // Tüm RAM (16 adres) okundu ve kontrol edildi
                        r_o_ok    <= 1'b1;             // Bitiş bayrağını kaldır
                        r_en_ram  <= 1'b0;
                        r_re_ram  <= 1'b0;
                        r_we_ram  <= 1'b0;
                        r_ERR     <= 1'b0;
                        r_data_in <= 3'd0;
                        r_flag    <= 1'b0;
                        r_counter <= {AW{1'b0}};
                        state     <= BASLA;            // Akışı başa döndür
                    end else begin
                        r_counter  <= r_counter + 1'b1;
                        r_addr_ram <= r_counter + 1'b1; // Bir sonraki adres okumaya hazırlanır
                        state      <= RAM_OKU;
                    end
                end

                // --- Default Durum (Sentezde Kilitlenmeyi Önleme) ---
                default : state <= BASLA;

            endcase
        end
    end

endmodule
