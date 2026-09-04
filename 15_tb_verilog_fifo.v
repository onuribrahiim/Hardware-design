`timescale 1ns / 1ps

// ============================================================================
// Modul Adi   : tb_fifo
// Tanım       : Senkron FIFO Modülü Doğrulama (Verification) Testbench'i
// Senaryolar  : 
//   - TEST 1: FIFO'yu tamamen doldurma (Normal Yazma)
//   - TEST 2: FIFO doluyken tekrar yazmaya çalışma (Overflow Koruması)
//   - TEST 3: FIFO'yu tamamen boşaltma (Normal Okuma)
//   - TEST 4: FIFO boşken okumaya çalışma (Underflow Koruması)
//   - TEST 5: FIFO boşken aynı anda yazma ve okuma (Bypass / Pass-Through Testi)
//   - TEST 6: FIFO doluyken aynı anda yazma ve okuma (Eşzamanlı İşlem Testi)
// ============================================================================

module tb_fifo();

    // ------------------------------------------------------------------------
    // Parametre Tanımlamaları
    // ------------------------------------------------------------------------
    parameter DATA_WIDTH = 6;                       // Veri genişliği (bit)
    parameter DATA_DEPTH = 16;                      // FIFO derinliği
    parameter DATA_ADDR  = ($clog2(DATA_DEPTH));    // Adres genişliği

    // ------------------------------------------------------------------------
    // Testbench Sinyal Tanımlamaları
    // ------------------------------------------------------------------------
    reg                  clk;                       // Sistem saat sinyali
    reg                  reset;                     // Asenkron reset
    reg                  w_en;                      // Yazma yetki sinyali
    reg                  r_en;                      // Okuma yetki sinyali
    reg  [DATA_WIDTH-1:0] data_in;                  // Giriş verisi
    wire [DATA_WIDTH-1:0] data_out;                 // Çıkış verisi
    wire                 full;                      // Dolu bayrağı
    wire                 empty;                     // Boş bayrağı
    wire                 valid;                     // Bypass geçerlilik bayrağı

    // ------------------------------------------------------------------------
    // DUT (Device Under Test) Bağlantısı
    // ------------------------------------------------------------------------
    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DATA_DEPTH(DATA_DEPTH),
        .DATA_ADDR (DATA_ADDR)
    ) fifo_dut (
        .clk     (clk),
        .reset   (reset),
        .w_en    (w_en),
        .r_en    (r_en),
        .data_in (data_in),
        .data_out(data_out),
        .full    (full),
        .empty   (empty),
        .valid   (valid)
    );

    // ------------------------------------------------------------------------
    // Clock Üretimi (Period = 20ns, Frekans = 50MHz)
    // ------------------------------------------------------------------------
    initial begin
        clk = 1;
        forever #10 clk = ~clk;
    end

    // ------------------------------------------------------------------------
    // Ana Test Senaryoları (Stimulus Driver)
    // ------------------------------------------------------------------------
    initial begin
        // --- BAŞLANGIÇ DURUMU VE RESET ---
        reset   = 1;
        data_in = 0;
        w_en    = 0;
        r_en    = 0;
        
        @(posedge clk);
        reset   = 0; // Reset kaldırıldı, FIFO işlemlere hazır

        // ====================================================================
        // TEST 1: FIFO'yu tamamen doldurma (Normal Yazma)
        // ====================================================================
        $display("----------- TEST1: Normal Yazma (Doldurma) -----------");
        repeat(DATA_DEPTH) begin
            w_en    = 1;
            data_in = $random % (2**DATA_WIDTH);
            
            // $display satırı clock yükselmeden hemen önceki anlık giriş durumunu gösterir
            $display("yazilacak veri=%0d , full=%0d , empty=%0d", data_in, full, empty);
            repeat(1) @(posedge clk);
        end
        w_en = 0;
        repeat(5) @(posedge clk);

        // ====================================================================
        // TEST 2: FIFO doluyken yazmaya çalışma (Overflow Koruması)
        // ====================================================================
        $display("----------- TEST2: Dolu iken Yazdirma -----------");
        repeat(DATA_DEPTH) begin
            w_en    = 1;
            data_in = $random % (2**DATA_WIDTH);
            $display("yazilacak veri=%0d , full=%0d , empty=%0d", data_in, full, empty);
            repeat(1) @(posedge clk);
        end
        w_en = 0;
        repeat(5) @(posedge clk);

        // ====================================================================
        // TEST 3: FIFO'yu tamamen boşaltma (Normal Okuma)
        // ====================================================================
        $display("----------- TEST3: Normal Okuma -----------");
        repeat(DATA_DEPTH) begin
            r_en = 1;
            $display("okunan veri=%0d , full=%0d , empty=%0d", data_out, full, empty);
            repeat(1) @(posedge clk);
        end
        $display("okunan veri=%0d , full=%0d , empty=%0d", data_out, full, empty);  
        r_en = 0;
        repeat(5) @(posedge clk);

        // ====================================================================
        // TEST 4: FIFO boşken okumaya çalışma (Underflow Koruması)
        // ====================================================================
        $display("----------- TEST4: Bos Oldugu Zaman Okuma -----------");             
        repeat(DATA_DEPTH) begin                                    
            r_en = 1;                                                                   
            $display("okunan veri=%0d , full=%0d , empty=%0d", data_out, full, empty);     
            repeat(1) @(posedge clk);                                
        end                                                         
        r_en = 0;                                                   
        repeat(5) @(posedge clk); 

        // ====================================================================
        // TEST 5: FIFO boşken aynı anda hem yazma hem okuma (Bypass Testi)
        // ====================================================================
        // Beklenen Davranış: FIFO boş olduğu için veri bellege yazilmadan 
        // doğrudan data_in -> data_out hattına aktarılmalı (Zero-latency).
        $display("----------- TEST5: Bos iken Hem Okuma Hem Yazma (Bypass) -----------");                
        repeat(DATA_DEPTH) begin
            w_en    = 1;                                                 
            data_in = $random % (2**DATA_WIDTH);  
            r_en    = 1; 
            repeat(1) @(posedge clk);                                          
            $display("yazilan veri=%0d ,okunan veri=%0d , full=%0d , empty=%0d", data_in, data_out, full, empty);                                                        
            repeat(1) @(posedge clk);                            
        end
        w_en = 0;                                                   
        r_en = 0;                                                 
        repeat(5) @(posedge clk); 

        // ====================================================================
        // TEST 6: FIFO doluyken aynı anda hem okuma hem yazma
        // ====================================================================
        // Beklenen Davranış: FIFO tasarım kurgusuna göre doluluk korunur, 
        // okuma gerçekleştiğinde adres kayar.
        $display("----------- TEST6: Dolu iken Hem Okuma Hem Yazma -----------");                                   
        repeat(DATA_DEPTH) begin                                                                            
            w_en    = 1;                                                                            
            data_in = $random % (2**DATA_WIDTH);                                                    
            r_en    = 1;                                                                            
            repeat(1) @(posedge clk);                                                                        
            $display("yazilan veri=%0d ,okunan veri=%0d , full=%0d , empty=%0d", data_in, data_out, full, empty);         
            repeat(1) @(posedge clk);                                                                       
        end                                                                                                 
        w_en = 0;                                                                                           
        r_en = 0;                                                                                           
        repeat(5) @(posedge clk); 
        
        $finish; // Simülasyonu sonlandır
    end

endmodule
