`timescale 1ns / 1ps

// =============================================================================
// Proje Adı    : verilog-lfsr-fifo-error-detection
// Modül Adı    : cryp_key_control
// Proje Amacı  : LFSR (Linear Feedback Shift Register) modülü ile 6-bitlik rastgele 
//                veriler üretilip FIFO tampon belleğe yazılır. 
//                
// Hata Kontrolü Ve Bit Birleştirme Mantığı:
//                FIFO'dan okunan her 6-bitlik verinin;
//                  - Üst 3 biti (MSB tarafı: data[5:3]) -> 1. Data Control modülünde
//                  - Alt 3 biti (LSB tarafı: data[2:0]) -> 2. Data Control modülünde
//                paralel olarak incelenir. 
//                
//                Eğer MSB grubundaki bitlerin HEPSİ '1' (3'b111) VEYA LSB grubundaki 
//                bitlerin HEPSİ '1' (3'b111) ise bir HATA (Error = 1) üretilir.
//                
//                Üretilen bu 1-bitlik hata sonucu (r_o_ERR_DC1 || r_o_ERR_DC2), 
//                6-bitlik orijinal verinin en soluna (MSB tarafına) eklenerek 
//                7-bitlik paket ([HATA_BITI, DATA_6BIT]) halinde RAM'e yazılır.
// =============================================================================

module cryp_key_control #(
    parameter WIDTH_DATA  = 6              , // İşlenecek temel veri genişliği (6-bit)
    parameter WIDTH_ADDR  = 4              , // Bellek adres genişliği (4-bit -> 16 adres)
    parameter WIDTH_DEPTH = (2**WIDTH_ADDR)  // FIFO ve RAM derinliği (16 eleman)
)(
    input  wire                  clk       , // Sistem saat sinyali (Clock)
    input  wire                  reset     , // Senkron/Donanımsal genel reset sinyali
    input  wire [WIDTH_DATA-1:0] data_login, // LFSR modülüne yüklenen başlangıç (seed) verisi
    output wire [WIDTH_DATA:0]   data_exit   // RAM'den okunan 7-bitlik veri çıkışı ([6]=ERR, [5:0]=DATA)
);

    // Modül içi sabit genişlik tanımlamaları
    localparam DATA_CNT_WIDTH = 3;           // Data Control modüllerine giden alt/üst veri dilim genişliği (3-bit)
    localparam DATA_RAM_WIDTH = 7;           // RAM'e yazılacak toplam veri genişliği (1-bit ERR + 6-bit DATA)

    // =========================================================================
    // 1. LFSR BİLEŞENİ VE SİNYAL TANIMLARI
    // =========================================================================
    reg                   r_i_reset_LFSR ;   // LFSR iç reset sinyali
    reg                   r_i_enable_LFSR;   // LFSR çalışma izin sinyali
    wire [WIDTH_DATA-1:0] w_o_data_LFSR  ;   // LFSR tarafından üretilen 6-bit rastgele veri hattı

    // LFSR Modülü Örneklemesi
    LFSR #(
        .DW_LFSR(WIDTH_DATA)                 // LFSR bit genişliği parametresi aktarımı (6-bit)
    ) LFSR_DUT (
        .i_clk_LFSR   (clk            ),     // Sistem saat sinyali bağlantısı
        .i_reset_LFSR (r_i_reset_LFSR ),     // LFSR reset bağlantısı
        .i_enable_LFSR(r_i_enable_LFSR),     // LFSR enable bağlantısı
        .i_data_LFSR  (data_login     ),     // Başlangıç seed verisi girişi
        .o_data_LFSR  (w_o_data_LFSR  )      // Üretilen rastgele veri çıkışı
    );

    // =========================================================================
    // 2. FIFO BİLEŞENİ VE SİNYAL TANIMLARI
    // =========================================================================
    reg [WIDTH_ADDR:0]    enable_w       ;   // FIFO'ya yazılan eleman sayısını takip eden sayaç
    reg [WIDTH_ADDR:0]    enable_r       ;   // FIFO'dan okunan eleman sayısını takip eden sayaç
    reg                   r_enable_FIFO  ;   // FIFO ana modül çalışma izin sinyali
    reg                   r_reset_FIFO   ;   // FIFO reset sinyali
    reg                   r_w_en_FIFO    ;   // FIFO yazma yetki sinyali (Write Enable)
    reg                   r_r_en_FIFO    ;   // FIFO okuma yetki sinyali (Read Enable)
    wire [WIDTH_DATA-1:0] w_data_out_FIFO;   // FIFO'dan okunan 6-bit veri hattı
    wire                  w_full_FIFO    ;   // FIFO dolu bayrağı çıkışı
    wire                  w_empty_FIFO   ;   // FIFO boş bayrağı çıkışı

    // FIFO Tampon Bellek Örneklemesi
    FIFO #(
        .DATA_WIDTH (WIDTH_DATA ),           // FIFO veri genişliği (6-bit)
        .DEPTH_WIDTH(WIDTH_DEPTH)            // FIFO derinliği (16)
    ) FIFO_DUT (
        .clk        (clk            ),       // Ortak saat sinyali
        .reset      (r_reset_FIFO   ),       // FIFO reset bağlantısı
        .w_en       (r_w_en_FIFO    ),       // Yazma yetkisi
        .r_en       (r_r_en_FIFO    ),       // Okuma yetkisi
        .enable_FIFO(r_enable_FIFO  ),       // FIFO aktif sinyali
        .data_in    (w_o_data_LFSR  ),       // LFSR'den gelen veri yazma portuna bağlanıyor
        .data_out   (w_data_out_FIFO),       // FIFO okuma çıkışı
        .full       (w_full_FIFO    ),       // Dolu durumu göstergesi
        .empty      (w_empty_FIFO   )        // Boş durumu göstergesi
    );

    // =========================================================================
    // 3. DATA CONTROL (HATA DENETİM) BİLEŞENLERİ VE SİNYAL TANIMLARI
    // =========================================================================
    reg  r_reset_DC       ;                  // Data Control modülleri genel reset sinyali
    reg  r_flag_DC        ;                  // Hata kontrol başlatma tetikleme bayrağı
    reg  r_enable_DC      ;                  // Data Control modülleri çalışma izin sinyali
    wire r_o_ERR_DC1      ;                  // 1. DC Modülü hata tespit bayrağı (MSB Grubu)
    wire r_o_ERR_done_DC1 ;                  // 1. DC Modülü işlem tamamlandı bayrağı

    // 1. Data Control Örneklemesi: FIFO çıkışındaki 6-bit verinin ÜST 3-bitini (MSB: [5:3]) denetler.
    // Eğer [5:3] bitlerinin hepsi '1' ise r_o_ERR_DC1 = 1 olur.
    data_control #(
        .DATA_WIDTH(DATA_CNT_WIDTH)          // 3-bit veri genişliği
    ) data_control_DUT1 (
        .clk        (clk                                       ),
        .reset      (r_reset_DC                                ),
        .enable     (r_enable_DC                               ),
        .data_in    (w_data_out_FIFO[WIDTH_DATA-1:WIDTH_DATA-3]), // Verinin MSB 3 biti [5:3]
        .flag       (r_flag_DC                                 ),
        .o_ERR      (r_o_ERR_DC1                               ), // MSB Hata çıkışı
        .o_ERR_done (r_o_ERR_done_DC1                          )
    );

    wire r_o_ERR_DC2      ;                  // 2. DC Modülü hata tespit bayrağı (LSB Grubu)
    wire r_o_ERR_done_DC2 ;                  // 2. DC Modülü işlem tamamlandı bayrağı

    // 2. Data Control Örneklemesi: FIFO çıkışındaki 6-bit verinin ALT 3-bitini (LSB: [2:0]) denetler.
    // Eğer [2:0] bitlerinin hepsi '1' ise r_o_ERR_DC2 = 1 olur.
    data_control #(
        .DATA_WIDTH(DATA_CNT_WIDTH)          // 3-bit veri genişliği
    ) data_control_DUT2 (
        .clk        (clk                  ),
        .reset      (r_reset_DC           ),
        .enable     (r_enable_DC          ),
        .data_in    (w_data_out_FIFO[2:0] ), // Verinin LSB 3 biti [2:0]
        .flag       (r_flag_DC            ),
        .o_ERR      (r_o_ERR_DC2          ), // LSB Hata çıkışı
        .o_ERR_done (r_o_ERR_done_DC2     )
    );

    // =========================================================================
    // 4. RAM BİLEŞENİ VE SİNYAL TANIMLARI
    // =========================================================================
    reg [WIDTH_DATA:0]   r_i_wdata_ram ;     // RAM'e yazılacak 7-bit veri register'ı ([ERR_BIT, DATA_6BIT])
    reg [WIDTH_ADDR-1:0] r_i_addr_ram  ;     // RAM adres yolu register'ı (4-bit)
    reg                  r_i_enable_ram;     // RAM çalışma izin sinyali
    reg                  r_i_re_ram    ;     // RAM okuma yetki sinyali (Read Enable)
    reg                  r_i_we_ram    ;     // RAM yazma yetki sinyali (Write Enable)

    // RAM Bellek Modülü Örneklemesi
    RAM_Design #(
        .WIDTH_DATA (DATA_RAM_WIDTH),        // 7-bit genişlik (1-bit Hata + 6-bit Veri)
        .WIDTH_ADDR (WIDTH_ADDR    ),        // 4-bit adres
        .WIDTH_DEPTH(WIDTH_DEPTH   )         // 16 derinlik
    ) RAM_Design_DUT (
        .i_clk_ram   (clk           ),
        .i_wdata_ram (r_i_wdata_ram ),       // Hata biti eklenmiş 7-bit veri yazılır
        .i_addr_ram  (r_i_addr_ram  ),
        .i_enable_ram(r_i_enable_ram),
        .i_re_ram    (r_i_re_ram    ),
        .i_we_ram    (r_i_we_ram    ),
        .o_rdata_ram (data_exit     )        // RAM okuma çıkışı (Top modül çıkışına yönlendirilir)
    );

    // =========================================================================
    // 5. ANA SONLU DURUM MAKİNESİ (FSM)
    // =========================================================================
    reg [2:0] state ;                        // FSM durum register'ı (3-bit)

    // FSM Durum Kodlamaları (State Encoding) - Profesyonel Adlandırma Mimari Standartları
    localparam ST_RESET         = 3'b000;    // 0: Başlangıç ve genel donanım reseti
    localparam ST_LFSR_INIT     = 3'b001;    // 1: LFSR başlatma ve FIFO'ya geçiş hazırlığı
    localparam ST_FIFO_WRITE    = 3'b010;    // 2: LFSR verilerinin FIFO belleğe yazılması (16 Eleman)
    localparam ST_PREPARE_CHECK = 3'b011;    // 3: FIFO yazmasının bitimi ve DC bloklarının resetlenmesi
    localparam ST_DC_ENABLE     = 3'b100;    // 4: Data Control ve RAM yazma modunun aktif edilmesi
    localparam ST_PROCESS_WRITE = 3'b101;    // 5: Hata denetimi, bit birleştirme ve RAM'e yazma işlemi
    localparam ST_SHUTDOWN      = 3'b110;    // 6: İşlem sonu yetki sinyallerinin kapatılması
    localparam ST_DONE          = 3'b111;    // 7: Tamamlandı durumu (Başa dönülür)

    // FSM Ardışıl Mantık (Sequential Logic) Bloğu
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // -----------------------------------------------------------------
            // Donanımsal Reset Durumu: Tüm iç register'lar ve sinyaller sıfırlanır
            // -----------------------------------------------------------------
            r_i_reset_LFSR  <= 1'b0;
            r_i_enable_LFSR <= 1'b0;
            
            enable_w        <= {(WIDTH_ADDR+1){1'b0}};
            enable_r        <= {(WIDTH_ADDR+1){1'b0}};
            r_enable_FIFO   <= 1'b0;
            r_reset_FIFO    <= 1'b0;
            r_w_en_FIFO     <= 1'b0;
            r_r_en_FIFO     <= 1'b0;
            
            r_reset_DC      <= 1'b0;
            r_flag_DC       <= 1'b0;
            r_enable_DC     <= 1'b0;
            
            r_i_wdata_ram   <= {(WIDTH_DATA+1){1'b0}};
            r_i_addr_ram    <= {WIDTH_ADDR{1'b0}};
            r_i_enable_ram  <= 1'b0;
            r_i_re_ram      <= 1'b0;
            r_i_we_ram      <= 1'b0;
            
            state           <= ST_RESET;
        end else begin
            case (state)
            
                // -------------------------------------------------------------
                // ST_RESET: LFSR ve FIFO modüllerine reset sinyali verilir
                // -------------------------------------------------------------
                ST_RESET : begin
                    r_i_reset_LFSR  <= 1'b1; // LFSR reset aşaması
                    r_i_enable_LFSR <= 1'b0;
                    r_enable_FIFO   <= 1'b0;
                    r_reset_FIFO    <= 1'b1; // FIFO reset aşaması
                    state           <= ST_LFSR_INIT;
                end
                
                // -------------------------------------------------------------
                // ST_LFSR_INIT: LFSR ve FIFO aktif edilir, LFSR'den FIFO'ya geçiş başlar
                // -------------------------------------------------------------
                ST_LFSR_INIT : begin
                    r_i_reset_LFSR  <= 1'b0;
                    r_i_enable_LFSR <= 1'b1;
                    r_enable_FIFO   <= 1'b1; // LFSR'den FIFO'ya geçiş aşaması
                    r_reset_FIFO    <= 1'b0;
                    r_w_en_FIFO     <= 1'b1;
                    state           <= ST_FIFO_WRITE;
                end
                
                // -------------------------------------------------------------
                // ST_FIFO_WRITE: LFSR tarafından üretilen veriler FIFO'ya yazılır
                // -------------------------------------------------------------
                ST_FIFO_WRITE : begin
                    r_w_en_FIFO <= 1'b1;
                    if (enable_w == WIDTH_DEPTH-1) begin
                        state           <= ST_PREPARE_CHECK;
                        enable_w        <= {(WIDTH_ADDR+1){1'b0}}; 
                        r_w_en_FIFO     <= 1'b0;
                        r_i_enable_LFSR <= 1'b0; // FIFO'ya değer yazılması tamamlandı
                    end else begin
                        enable_w <= enable_w + 1'b1;
                        state    <= ST_FIFO_WRITE;
                    end
                end
                
                // -------------------------------------------------------------
                // ST_PREPARE_CHECK: DC modülleri resetlenir, FIFO okuması açılır
                // -------------------------------------------------------------
                ST_PREPARE_CHECK : begin
                    r_reset_DC  <= 1'b1;     // Data Control modülleri resetlenir
                    r_enable_DC <= 1'b0;
                    r_r_en_FIFO <= 1'b1;     // FIFO ilk elemanı okumak için hazırlanır
                    state       <= ST_DC_ENABLE;
                end

                // -------------------------------------------------------------
                // ST_DC_ENABLE: DC modülleri ve RAM yazma modu aktif edilir
                // -------------------------------------------------------------
                ST_DC_ENABLE : begin
                    r_r_en_FIFO    <= 1'b0;
                    r_reset_DC     <= 1'b0;
                    r_enable_DC    <= 1'b1;  // DC modülleri aktif
                    r_i_enable_ram <= 1'b1;  // RAM yazma yetkileri verilir
                    r_i_re_ram     <= 1'b0;
                    r_i_we_ram     <= 1'b1;
                    state          <= ST_PROCESS_WRITE;
                end
                
                // -------------------------------------------------------------
                // ST_PROCESS_WRITE: Hata denetimi yapılır. MSB (DC1) veya LSB (DC2) 
                //                   tarafında 3'b111 yakalanırsa hata biti '1' yapılır.
                //                   Hata biti verinin MSB tarafına eklenerek 7-bit halinde RAM'e yazılır.
                // -------------------------------------------------------------
                ST_PROCESS_WRITE : begin
                    r_r_en_FIFO <= 1'b0;  
                    
                    // DC denetim bloklarına flag tetiklemesi yönetimi
                    if (r_o_ERR_done_DC1 == 1'b0 && r_o_ERR_done_DC2 == 1'b0) begin                 
                        r_flag_DC <= 1'b1;
                    end else if (r_o_ERR_done_DC1 == 1'b1 && r_o_ERR_done_DC2 == 1'b1) begin
                        r_flag_DC <= 1'b0;
                    end
                    
                    // Her iki denetim bloğu da (MSB ve LSB) analizini tamamladığında
                    if (r_o_ERR_done_DC1 == 1'b1 && r_o_ERR_done_DC2 == 1'b1) begin 
                        r_r_en_FIFO <= 1'b1; // FIFO'dan sıradaki veriyi çekmek için okuma tetiklenir
                        
                        // Hata Biti Ataması ve Bit Birleştirme: 
                        // MSB (DC1) veya LSB (DC2) 3'b111 tespit etmişse '1' üretilir.
                        // {HATA_BITI, FIFO_VERISI} -> [6] biti ERR, [5:0] bitleri Orijinal Veri.
                        r_i_wdata_ram <= {r_o_ERR_DC1 || r_o_ERR_DC2, w_data_out_FIFO}; 
                        
                        if (enable_r == WIDTH_DEPTH-1) begin 
                            state        <= ST_SHUTDOWN;              
                            enable_r     <= {(WIDTH_ADDR+1){1'b0}}; 
                            r_i_addr_ram <= r_i_addr_ram + 1'b1; // Son eleman yazılırken adres arttırılır                  
                        end else begin 
                            // Adres Güncelleme: 0. elemandan sonra sırasıyla adres kaydırılır
                            if (enable_r > 0) begin  
                                r_i_addr_ram <= r_i_addr_ram + 1'b1; 
                            end else begin
                                r_i_addr_ram <= {WIDTH_ADDR{1'b0}};
                            end                           
                            enable_r <= enable_r + 1'b1;          
                            state    <= ST_DC_ENABLE;            // Bir sonraki FIFO elemanı için DC hazırlık durumuna geçilir
                        end 
                    end                       
                end 

                // -------------------------------------------------------------
                // ST_SHUTDOWN: İşlem tamamlandığında tüm modüllerin enable sinyalleri kapatılır
                // -------------------------------------------------------------
                ST_SHUTDOWN : begin
                    r_enable_FIFO  <= 1'b0;
                    r_w_en_FIFO    <= 1'b0;
                    r_r_en_FIFO    <= 1'b0;
                    r_enable_DC    <= 1'b0;
                    r_i_enable_ram <= 1'b0;
                    r_i_we_ram     <= 1'b0;
                    state          <= ST_DONE;
                end    
 
                // -------------------------------------------------------------
                // ST_DONE: Akış sonlanır, tekrar başlangıç durumuna döner
                // -------------------------------------------------------------
                ST_DONE : begin  
                    state <= ST_RESET;   
                end  
                
                // Tanımlanmamış durumlarda güvenli reset'e dönüş
                default : begin
                    state <= ST_RESET;  
                end
                            
            endcase
        end
    end

endmodule
