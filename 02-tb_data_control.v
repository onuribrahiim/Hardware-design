`timescale 1ns / 1ps

/* ==============================================================================
 * Modül Adı    : tb_data_control
 * Geliştirici  : İbrahim Onur
 * Açıklama     : data_control (FSM) tasarımı için doğrulama katmanı (Testbench).
 *                Rastgele 3 bitlik veri üreterek hatalı durumları (3'b111) 
 *                konsol çıktısı ($display) ve dalga formu üzerinden doğrular.
 * ============================================================================== */

module tb_data_control();

    // Testbench Sürücü Sinyalleri (DUT girişleri reg olarak tanımlanır)
    reg clk;             // 25 MHz (40ns periyot) sistem clock sinyali
    reg reset;           // Asenkron reset sinyali
    reg [2:0] data_in;   // Test için gönderilecek 3 bitlik rastgele veri
    reg flag;            // FSM başlama tetikleyicisi (Start pulse)

    // Testbench İzleme Sinyali (DUT çıkışı wire olarak tanımlanır)
    wire [2:0] o_ERR;    // FSM hata çıkış sonucu

    // Test Edilen Tasarım (Device Under Test - DUT) Bağlantısı
    data_control dut (
        .clk     (clk     ),
        .reset   (reset   ),
        .data_in (data_in ),
        .o_ERR   (o_ERR   ),
        .flag    (flag    )
    );

    // Clock Üreteci: 20ns aralıklarla durum değiştirerek 40ns periyot (25 MHz) oluşturur
    initial begin
        clk = 1;
        forever #20 clk = ~clk;
    end

    // Test Senaryosu ve Uyarım (Stimulus) İşlemleri
    initial begin
        // 1. Durum: Başlangıç koşulları ve Reset uygulaması
        reset = 1;
        #40;
        reset = 0;       // Reset pasife çekildi
        #40;

        // 2. Durum: 24 kez rastgele veri göndererek FSM davranışını test etme döngüsü
        repeat(24) begin
            data_in = $random % 8; // 0 ile 7 arası (3-bit) rastgele değer üretir
            #40;
            
            flag = 1;              // FSM'i tetikle
            #40;
            flag = 0;              // Tetik sinyalini geri çek
            
            #320;                  // FSM'in durumları geçip sonucu üretmesi için bekleme

            // Konsol Çıktısı: Giriş verisi ve dönen hata durumunu Simülasyon Loguna yazdırır
            $display(" data_in=%b , o_ERR=%b ", data_in, o_ERR);
        end

        // Simülasyonu sonlandır
        $finish;
    end

endmodule
