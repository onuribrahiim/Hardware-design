// Zaman ölçeği tanımı: Simülasyon adımı 1ns, hassasiyeti 1ps
`timescale 1ns / 1ps

// ============================================================================
// Modül Adı: tb_new_ram
// Açıklama : new_ram modülü için Testbench (Test Çevresi)
// ============================================================================
module tb_new_ram();

    // --- Parametre Tanımlamaları ---
    parameter data_WIDTH     = 4;   // Veri genişliği (4-bit)
    parameter addr_WIDTH     = 4;   // Adres genişliği (4-bit)
    parameter derinlik_WIDTH = 16;  // Bellek derinliği (16 eleman)

    // --- Testbench Sinyalleri ---
    // DUT (Device Under Test) girdileri için 'reg', çıktıları için 'wire' kullanılır
    reg  [addr_WIDTH-1:0] addr;         // Adres sinyali
    reg  [data_WIDTH-1:0] data_in;      // RAM'e gönderilecek veri
    reg                   clk;          // Saat sinyali
    reg                   enable;       // RAM aktif etme sinyali
    reg                   read_enable;  // Okuma izni sinyali
    reg                   write_enable; // Yazma izni sinyali
    wire [data_WIDTH-1:0] data_out;     // RAM'den okunan veri

    // --- Test Edilecek Modülün Çağrılması (DUT Instantiation) ---
    new_ram #(
        .data_WIDTH     (data_WIDTH     ),
        .addr_WIDTH     (addr_WIDTH     ),
        .derinlik_WIDTH (derinlik_WIDTH )
    ) RAM_DUT (
        .addr         (addr        ),
        .data_in      (data_in     ),
        .clk          (clk         ),
        .enable       (enable      ),
        .read_enable  (read_enable ),
        .write_enable (write_enable),
        .data_out     (data_out    )
    );

    // --- Saat Sinyali Üretimi (Clock Generation) ---
    // Periyot = 20ns (10ns LO, 10ns HI) -> 50 MHz Frekans
    initial begin 
        clk = 1;
        forever #10 clk = ~clk; // Her 10ns'de bir saat sinyalini tersle
    end

    // --- Ana Test Senaryosu (Main Stimulus) ---
    initial begin
        // 1. Başlangıç Değerlerinin Atanması (Reset Durumu)
        addr         = 0;
        data_in      = 0;
        enable       = 0;
        read_enable  = 0;
        write_enable = 0;

        #10; // 10ns bekle

        // 2. Yazma İşlemleri
        // write_name(veri, adres)
        write_name('d12, 'd5);  // Adres 5'e  12 verisini yaz
        write_name('d11, 'd1);  // Adres 1'e  11 verisini yaz
        write_name('d7 , 'd7);  // Adres 7'ye  7 verisini yaz
        write_name('d10, 'd3);  // Adres 3'e  10 verisini yaz
        
        #200; // Yazma ve okuma arasında 200ns bekleme süresi

        // 3. Okuma İşlemleri
        // read_name(adres)
        read_name('d7);         // Adres 7'deki veriyi oku (Beklenen: 7)
        read_name('d5);         // Adres 5'teki veriyi oku (Beklenen: 12)
        read_name('d3);         // Adres 3'teki veriyi oku (Beklenen: 10)
        read_name('d1);         // Adres 1'deki veriyi oku (Beklenen: 11)
        
        #200; // Simülasyonu sonlandırmadan önce 200ns bekle
        $finish; // Simülasyonu bitir
    end

    // ========================================================================
    // YAZMA GÖREVİ (Write Task)
    // Belirtilen adrese istenen veriyi yazmak için kullanılır
    // ========================================================================
    task write_name(input [data_WIDTH-1:0] data_in_r, input [addr_WIDTH-1:0] addr_r);
    begin
        #10;
        addr         = addr_r;    
        data_in      = data_in_r;            
        enable       = 1;     
        read_enable  = 0;
        write_enable = 1;
        #10;
        $display("YAZILDI -> addr=%d, data_in=%d", addr_r, data_in_r);
    end
    endtask

    // ========================================================================
    // OKUMA GÖREVİ (Read Task)
    // Belirtilen adresteki veriyi okumak için kullanılır
    // ========================================================================
    task read_name(input [addr_WIDTH-1:0] addr_r);     
    begin                                                                     
        #10;                                                                  
        addr         = addr_r;                                                
        enable       = 1;                                                     
        read_enable  = 1;                                                     
        write_enable = 0;                                                     
        #10;  
        $display("OKUNDU  -> addr=%d, data_out=%d", addr_r, data_out);                                                                                                          
    end                                                                       
    endtask                                                               

endmodule
