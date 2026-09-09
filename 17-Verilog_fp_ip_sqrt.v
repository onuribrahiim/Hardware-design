// ============================================================================
// File Name   : fpip_sqrt.v
// Module Name : fpip_sqrt
// Description : Floating-Point Square Root Wrapper Module
//               This module wraps AMD/Xilinx Floating-Point IP Core (configured
//               for Square Root operation) with a Finite State Machine (FSM)
//               to manage AXI4-Stream handshaking protocols and control signals.
//
// Author      : Halil İbrahim Onur
// Target Board: Nexys A7-100T / Xilinx FPGA
// Standard    : IEEE 754 Single-Precision Floating-Point (32-bit default)
// ============================================================================

`timescale 1ns / 1ps

module fpip_sqrt #(
    parameter DATA_WIDTH = 32  // Floating-point veri genişliği (IEEE-754 Single Precision: 32 bit)
)(
    // --- Sistem Sinyalleri ---
    input  wire                  clk,                 // Sistem Saat Sinyali (System Clock)
    input  wire                  reset,               // Asenkron/Senkron Pozitif Reset Sinyali (Active High Reset)
    
    // --- Kullanıcı Kontrol ve Veri Arayüzü ---
    input  wire                  start_signal,        // Karekök alma işlemini başlatan tetikleme sinyali
    input  wire [DATA_WIDTH-1:0] data_in,             // Karekökü alınacak IEEE-754 formatındaki girdi verisi
    output reg  [DATA_WIDTH-1:0] data_out,            // Hesaplanan karekök sonucu (IEEE-754 Floating Point)
    output reg                  done_finish_signal   // İşlemin tamamlandığını belirten bayrak (1 clock cycle pulse)
);

    // ========================================================================
    // İç Kayıtlar ve Dahili Sinyal Tanımlamaları
    // ========================================================================
    reg  [DATA_WIDTH-1:0] r_data_in;    // Girdi verisini saklayan dahili saklayıcı (Register)
    reg                   a_valid;      // IP Core için AXI4-Stream 'Slave Valid' el sıkışma sinyali
    wire                  a_tready;     // IP Core'dan gelen 'Slave Ready' hazır olma sinyali
    wire                  result_valid; // IP Core'dan gelen 'Master Valid' sonuç geçerli sinyali
    wire [DATA_WIDTH-1:0] result;       // IP Core tarafından üretilen karekök sonucu

    // ========================================================================
    // Floating-Point IP Core Örnekleme (Instantiation)
    // ========================================================================
    // Xilinx Vivado Floating-Point IP Core (Square Root modunda yapılandırılmış)
    floating_point_0 DUT (
        .aclk                  (clk),           // IP Core saat girişi
        .s_axis_a_tvalid       (a_valid),       // Girdi verisinin geçerli olduğunu IP Core'a bildirir
        .s_axis_a_tready       (a_tready),      // IP Core'un veriyi kabule hazır olduğunu bildirir
        .s_axis_a_tdata        (r_data_in),     // İşlenecek 32-bit kayan noktalı veri
        .m_axis_result_tvalid (result_valid),  // IP Core çıkış verisinin geçerli/hazır olduğunu gösterir
        .m_axis_result_tready (1'b1),          // Modül sonuçları almaya her zaman hazır (Constant High)
        .m_axis_result_tdata  (result)         // Hesaplanmış karekök çıktı verisi
    );

    // ========================================================================
    // FSM Durum Kodlamaları (State Encodings)
    // ========================================================================
    reg [1:0] state;

    localparam START = 2'b00;  // Başlangıç ve Tetikleme Bekleme Durumu
    localparam LOAD  = 2'b01;  // Veriyi IP Core'a AXI-Stream Protokolü ile Yükleme Durumu
    localparam WAIT  = 2'b10;  // IP Core Pipelined Hesaplama Bitimini Bekleme Durumu
    localparam DONE  = 2'b11;  // Sonucu Çıkışa Aktarma ve Bitiş Sinyali Üretme Durumu

    // ========================================================================
    // Durum Makinesi Mantığı (FSM Sequential Logic)
    // ========================================================================
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset durumunda tüm iç kayıtları ve çıkışları sıfırla
            state              <= START;
            data_out           <= {DATA_WIDTH{1'b0}};
            done_finish_signal <= 1'b0;
            r_data_in          <= {DATA_WIDTH{1'b0}};
            a_valid            <= 1'b0;
        end else begin
            case (state)
                
                // ------------------------------------------------------------
                // DURUM 0: START (Bekleme & Başlatma)
                // ------------------------------------------------------------
                START: begin
                    r_data_in <= {DATA_WIDTH{1 me b0}};
                    if (start_signal) begin
                        r_data_in <= data_in;       // Giriş verisini saklayıcıya mandalla (Latch)
                        a_valid   <= 1'b1;          // AXI-Stream veri geçerlilik bayrağını kaldır
                        state     <= LOAD;          // Veri yükleme durumuna geç
                    end
                end

                // ------------------------------------------------------------
                // DURUM 1: LOAD (AXI4-Stream El Sıkışma / Handshake)
                // ------------------------------------------------------------
                LOAD: begin
                    // IP Core veriyi kabul ettiğinde (a_tready = 1) valid sinyalini düşür
                    if (a_tready) begin
                        a_valid <= 1'b0;
                    end 
                    
                    // El sıkışma tamamlanıp a_valid 0 olduğunda hesaplama bekleme durumuna geç
                    if (!a_valid) begin
                        state <= WAIT; 
                    end
                end

                // ------------------------------------------------------------
                // DURUM 2: WAIT (Hesaplama Bekleme)
                // ------------------------------------------------------------
                WAIT: begin
                    // IP Core hesaplamayı bitirip sonucu çıkışa verdiğinde (result_valid = 1)
                    if (result_valid) begin
                        data_out           <= result; // Hesaplanmış sonucu çıkışa aktar
                        done_finish_signal <= 1'b1;   // Bitiş sinyalini aktif yap
                        state              <= DONE;   // Bitiş durumuna geç
                    end
                end

                // ------------------------------------------------------------
                // DURUM 3: DONE (Tamamlama ve Sıfırlama)
                // ------------------------------------------------------------
                DONE: begin
                    done_finish_signal <= 1'b0;       // Bitiş bayrağını indir (1 clock pulse süresi)
                    state              <= START;      // Yeni işlem için başa dön
                end

                // ------------------------------------------------------------
                // DEFAULT: Güvenli Durum (Latch-up Önleme)
                // ------------------------------------------------------------
                default: begin
                    state <= DONE;
                end

            endcase
        end
    end

endmodule
