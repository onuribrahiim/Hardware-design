`timescale 1ns / 1ps // Simülasyon zaman birimi (1ns) ve hassasiyeti (1ps)

module tb_RAM_Design();

// ============================================================================
// 1. PARAMETRE TANIMLAMALARI
// ============================================================================
parameter WIDTH_DATA  = 8;                // Veri hattı genişliği (8 bit)
parameter WIDTH_ADDR  = 4;                // Adres hattı genişliği (4 bit)
parameter WIDTH_DEPTH = (2**WIDTH_ADDR);  // Bellek derinliği (2^4 = 16 adres)

// ============================================================================
// 2. SİNYAL TANIMLAMALARI
// ============================================================================
// DUT girişlerine değer süreceğimiz için 'reg' olarak tanımlıyoruz
reg                   i_clk_ram;    // Sistem clock sinyali
reg  [WIDTH_DATA-1:0] i_wdata_ram;  // RAM'e yazılacak veri
reg  [WIDTH_ADDR-1:0] i_addr_ram;   // Okuma/Yazma yapılacak adres
reg                   i_enable_ram; // RAM ana çalışma izni (Chip Enable)
reg                   i_re_ram;     // Okuma izni (Read Enable)
reg                   i_we_ram;     // Yazma izni (Write Enable)

// DUT çıkışını gözlemleyeceğimiz için 'wire' olarak tanımlıyoruz
wire [WIDTH_DATA-1:0] o_rdata_ram;  // RAM'den okunan veri çıkışı

// ============================================================================
// 3. TEST EDİLEN DEVRENİN (DUT) BAĞLANMASI
// ============================================================================
RAM_Design #(
    .WIDTH_DATA (WIDTH_DATA),
    .WIDTH_ADDR (WIDTH_ADDR),
    .WIDTH_DEPTH(WIDTH_DEPTH)
) DUT (
    .i_clk_ram   (i_clk_ram   ),
    .i_wdata_ram (i_wdata_ram ),
    .i_addr_ram  (i_addr_ram  ),
    .i_enable_ram(i_enable_ram),
    .i_re_ram    (i_re_ram    ),
    .i_we_ram    (i_we_ram    ),
    .o_rdata_ram (o_rdata_ram )
);

// ============================================================================
// 4. CLOCK (SAAT) ÜRETİMİ
// ============================================================================
// 10ns periyotlu (100 MHz) sürekli clock sinyali üretimi
initial begin
    i_clk_ram = 1;
    forever #5 i_clk_ram = ~i_clk_ram; // Her 5ns'de bir clock durum değiştirir
end

// ============================================================================
// 5. ANA TEST SENARYOSU
// ============================================================================
initial begin
    // Başlangıç durumunda tüm sinyalleri sıfırla (Reset/Init)
    i_wdata_ram  = 0;
    i_addr_ram   = 0;
    i_enable_ram = 0;
    i_re_ram     = 0;
    i_we_ram     = 0;

    #1000; // Başlangıçta kararlılık için 1000ns bekle

    // --- YAZMA İŞLEMLERİ ---
    // Format: write_name(Yazılacak_Data, Yazılacak_Adres)
    write_name('d12, 'd8);  // 8. adrese 12 verisini yaz
    write_name('d3 , 'd1);  // 1. adrese 3 verisini yaz
    write_name('d9 , 'd15); // 15. adrese 9 verisini yaz

    #100; // Yazma ve okuma işlemleri arasında bekleme

    // --- OKUMA İŞLEMLERİ ---
    // Format: read_name(Okunacak_Adres)
    read_name('d1);  // 1. adresteki veriyi oku (Beklenen çıkış: 3)
    read_name('d8);  // 8. adresteki veriyi oku (Beklenen çıkış: 12)
    read_name('d15); // 15. adresteki veriyi oku (Beklenen çıkış: 9)

    #100; // Son okuma verisinin waveform'da rahat görünmesi için bekleme

    $finish; // Simülasyonu sonlandır
end

// ============================================================================
// 6. YAZMA TASK'I (Write Task)
// ============================================================================
task write_name (
    input [WIDTH_DATA-1:0] i_wdata, // Task'a gelen 1. parametre: Veri
    input [WIDTH_ADDR-1:0] i_waddr  // Task'a gelen 2. parametre: Adres
);
begin
    #5;
    i_wdata_ram  = i_wdata; // Veriyi hatta sür
    i_addr_ram   = i_waddr; // Adresi hatta sür
    i_enable_ram = 1;       // RAM çalışma iznini aç
    i_re_ram     = 0;       // Okumayı kapat
    i_we_ram     = 1;       // Yazmayı aç
    #10;                    // Verinin RAM'e yazılması için 1 clock periyodu bekle
end
endtask

// ============================================================================
// 7. OKUMA TASK'I (Read Task)
// ============================================================================
task read_name (
    input [WIDTH_ADDR-1:0] i_raddr // Task'a gelen parametre: Okunacak Adres
);
begin
    #10;
    i_enable_ram = 1;       // RAM çalışma iznini aç
    i_re_ram     = 1;       // Okumayı aç
    i_we_ram     = 0;       // Yazmayı kapat
    i_addr_ram   = i_raddr; // Okunacak adresi hatta sür
    #10;                    // Verinin çıkışa yansıması için 1 clock periyodu bekle
end
endtask

endmodule
