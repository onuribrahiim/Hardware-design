`timescale 1ns / 1ps

module tb_fsm_bolme_islemi();

    // Parametre Tanımlaması
    parameter W = 4;

    // Testbench Sinyalleri (DUT Girişleri 'reg', Çıkışları 'wire')
    reg clk;
    reg reset;
    reg [W-1:0] bolunen;
    reg [W-1:0] bolen;
    wire [W-1:0] sonuc;
    wire DURUM;

    // Tasarlanan FSM Modülünün Çağrılması (DUT Instantation)
    fsm_bolme_islemi #(
        .W(W)
    ) fsm_bolme_islemi_dut (
        .clk    (clk    ),
        .reset  (reset  ),
        .bolunen(bolunen),
        .bolen  (bolen  ),
        .sonuc  (sonuc  ),
        .DURUM  (DURUM  )
    );

    // Saat (Clock) Sinyali Üretimi (20ns Periyot - 50 MHz)
    initial begin 
        clk = 0;
        forever #10 clk = ~clk;
    end

    // Test Senaryoları Bloğu
    initial begin
        // Başlangıç Reset Durumu
        reset = 1;
        bolunen = 0;
        bolen = 0;
        #10;
        reset = 0;

        // 10 Defa Rastgele Değerler İle Bölme Testi
        repeat(10) begin
            bolunen = $random % (2**W);
            bolen   = ($random % ((2**W) - 1)) + 1; // Sıfıra bölme hatasını önlemek için 1-15 arası değer
            
            // FSM'in çıkarma adımlarını ve DONE durumunu tamamlaması için bekleme süresi
            #190;
        end

        // Simülasyonu Bitir
        $finish;
    end

endmodule
