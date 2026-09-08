`timescale 1ns / 1ps

// ============================================================================
// Modül Adı    : fpip (Floating-Point IP Controller)
// Açıklama     : Xilinx Floating-Point IP çekirdeği ile 32-bit IEEE-754
//                toplama ve çıkarma işlemlerini AXI4-Stream el sıkışma (handshake)
//                protokolu kullanarak FSM üzerinden yöneten kontrolcü modülü.
// ============================================================================

module fpip #(
    parameter DATA_WIDTH = 32  // Veri genişliği (32-bit Tek Duyarlıklı / Single Precision Float)
)
(
    // --- Sistem Sinyalleri ---
    input wire                  clk         , // Sistem saat sinyali
    input wire                  reset       , // Asenkron aktif-yüksek reset sinyali

    // --- Giriş Veri ve Kontrol Sinyalleri ---
    input wire [DATA_WIDTH-1:0] data_1      , // 1. Operand (IEEE-754 Float32 formatında)
    input wire [DATA_WIDTH-1:0] data_2      , // 2. Operand (IEEE-754 Float32 formatında)
    input wire                  start_sytem , // İşlemi başlatan tetikleme sinyali (1 saat vuruşluk pulse)
    input wire                  i_add_sub   , // İşlem türü seçimi: 0 = Toplama (+), 1 = Çıkarma (-)

    // --- Çıkış Sinyalleri ---
    output reg [DATA_WIDTH-1:0] data_out    , // Hesaplanan IEEE-754 Float32 sonuç verisi
    output reg                  done_signal   // İşlemin tamamlandığını belirten bayrak sinyali
);

    // ========================================================================
    // İç Yazmaçlar (Registers) ve Teller (Wires)
    // ========================================================================
    reg [DATA_WIDTH-1:0] r_data_1, r_data_2; // Giriş verilerini saklayan iç yazmaçlar
    reg                  r_i_add_sub;       // İşlem komutunu saklayan iç yazmaç

    // AXI4-Stream Giriş Kanalları için Valid (Geçerli) Yazmaçları (Master -> Slave)
    reg  a_valid, b_valid, op_valid;

    // AXI4-Stream Giriş Kanalları için Ready (Hazır) Telleri (Slave -> Master)
    wire a_tready, b_tready, op_tready;

    // AXI4-Stream Çıkış Kanalı Sinyalleri (IP -> Master)
    wire result_valid;                 // IP Core'un geçerli sonuç ürettiğini gösteren sinyal
    wire [DATA_WIDTH-1:0] result;      // IP Core'dan çıkan ham sonuç verisi

    // ========================================================================
    // Xilinx Floating-Point IP Core Örnekleme (Instantiation)
    // ========================================================================
    floating_point_0 fp_ip (
        .aclk                   (clk                ), // Ortak saat sinyali

        // --- A Kanalı (1. Operand AXI-Stream Girişi) ---
        .s_axis_a_tvalid        (a_valid            ), // A verisinin geçerli olduğunu bildiren sinyal
        .s_axis_a_tready        (a_tready           ), // IP Core'un A verisini almaya hazır olduğunu belirten sinyal
        .s_axis_a_tdata         (r_data_1           ), // A verisi bus hattı

        // --- B Kanalı (2. Operand AXI-Stream Girişi) ---
        .s_axis_b_tvalid        (b_valid            ), // B verisinin geçerli olduğunu bildiren sinyal
        .s_axis_b_tready        (b_tready           ), // IP Core'un B verisini almaya hazır olduğunu belirten sinyal
        .s_axis_b_tdata         (r_data_2           ), // B verisi bus hattı

        // --- İşlem Kodu Kanalı (Operation AXI-Stream Girişi) ---
        .s_axis_operation_tvalid(op_valid           ), // İşlem kodunun geçerli olduğunu bildiren sinyal
        .s_axis_operation_tready(op_tready          ), // IP Core'un işlem kodunu almaya hazır olduğunu belirten sinyal
        .s_axis_operation_tdata ({7'd0,r_i_add_sub} ), // İşlem kodu: LSB (0. bit) 0=Toplama, 1=Çıkarma

        // --- Sonuç Kanalı (Result AXI-Stream Çıkışı) ---
        .m_axis_result_tvalid   (result_valid       ), // IP Core'un geçerli sonuç ürettiğini bildiren sinyal
        .m_axis_result_tready   (1'b1               ), // Çıkış hattının her zaman veri kabul etmeye hazır olduğunu bildirir
        .m_axis_result_tdata    (result             )  // Üretilen 32-bit kayan noktalı sonuç verisi
    );

    // ========================================================================
    // FSM (Sonlu Durum Makinesi) Durum Tanımlamaları
    // ========================================================================
    reg [1:0] state;

    localparam START = 2'b00; // Boşta (Idle) duruma geçiş ve tetikleme bekleme durumu
    localparam LOAD  = 2'b01; // AXI-Stream verilerini IP Core'a aktarma ve el sıkışma durumu
    localparam WAIT  = 2'b10; // IP Core'un hesaplamayı bitirmesini (pipelining) bekleme durumu
    localparam DONE  = 2'b11; // Sonucu çıkışa kilitleme ve bitiş sinyalini üretme durumu

    // ========================================================================
    // FSM Kontrol Mantığı (Senkron Saat ve Asenkron Reset)
    // ========================================================================
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset anında tüm iç yazmaçlar ve çıkışlar güvenli varsayılan değerlerine sıfırlanır
            r_data_1    <= 0;
            r_data_2    <= 0;
            r_i_add_sub <= 0;
            a_valid     <= 0;
            b_valid     <= 0;
            op_valid    <= 0;
            data_out    <= 0;
            done_signal <= 0;
            state       <= START;
        end else begin
            case (state)

                // ------------------------------------------------------------
                // DURUM 0: START (Başlangıç / Bekleme)
                // ------------------------------------------------------------
                START : begin
                    r_data_1 <= 0;
                    r_data_2 <= 0;

                    // Dış dünyadan tetikleme sinyali geldiğinde veriler yazmaçlara kilitlenir
                    if (start_sytem) begin
                        r_data_1    <= data_1;
                        r_data_2    <= data_2;
                        r_i_add_sub <= i_add_sub;

                        // AXI kanallarında veri aktarımını başlatmak için VALID sinyalleri 1 yapılır
                        a_valid     <= 1;
                        b_valid     <= 1;
                        op_valid    <= 1;

                        state       <= LOAD; // Veri yükleme durumuna geç
                    end
                end 

                // ------------------------------------------------------------
                // DURUM 1: LOAD (AXI4-Stream El Sıkışma / Handshake)
                // ------------------------------------------------------------
                LOAD : begin
                    // Her bir kanal için IP Core READY = 1 yaptığında el sıkışma gerçekleşir.
                    // El sıkışması tamamlanan kanalın VALID sinyali 0'a çekilerek kapatılır.
                    if (a_tready) begin
                        a_valid <= 0;
                    end
                    if (b_tready) begin
                        b_valid <= 0;
                    end
                    if (op_tready) begin
                        op_valid <= 0;
                    end

                    // 3 kanalın da VALID sinyali 0 olduysa (yani tüm veriler IP tarafından alındıysa)
                    // FSM kilitlenme (deadlock) yaşamadan güvenle WAIT durumuna geçer.
                    if (!a_valid && !b_valid && !op_valid)
                        state <= WAIT;
                end

                // ------------------------------------------------------------
                // DURUM 2: WAIT (IP Core Sonuç Bekleme)
                // ------------------------------------------------------------
                WAIT : begin
                    // IP Core boru hattı (pipeline) gecikmesini tamamlayıp sonucu hazırladığında
                    // m_axis_result_tvalid (result_valid) sinyalini 1 yapar.
                    if (result_valid) begin
                        data_out    <= result; // Hesaplanan sonucu çıkış yazmacına kaydet
                        done_signal <= 1;      // Dış dünyaya işlemin bittiğini haber ver
                        state       <= DONE;   // Tamamlandı durumuna geç
                    end
                end

                // ------------------------------------------------------------
                // DURUM 3: DONE (Tamamlandı ve Sıfırlama)
                // ------------------------------------------------------------
                DONE : begin
                    done_signal <= 0;    // Bitiş sinyali 1 saat vuruşundan sonra indirilir (pulse)
                    state       <= START; // Yeni bir işlem almak üzere başa dön
                end

                // ------------------------------------------------------------
                // DEFAULT (Beklenmeyen Durum Güvenliği)
                // ------------------------------------------------------------
                default : begin
                    state <= DONE; // Hatalı bir duruma düşülürse güvenli olarak bitişe yönlendir
                end

            endcase
        end
    end

endmodule
