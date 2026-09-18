`timescale 1ns / 1ps // Simülasyon zaman birimi (1ns) ve çözünürlüğü (1ps)

// ============================================================================
// Modül İsmi: ALU_DESING
// Tanım     : Parametrik Üst Seviye Aritmetik Mantık Birimi (ALU Top-Level)
// Açıklama  : Alt modülleri (Çarpan, Karşılaştırıcı, Toplayıcı, Çıkarıcı) 
//             örnekleyerek (instantiation) 2-bitlik 'S' seçim sinyaline göre 
//             ilgili aritmetik/mantıksal işlemin sonucunu 'data_out' çıkışına sürer.
// ============================================================================
module ALU_DESING #(
    parameter DATA_WIDTH = 8 // Giriş verilerinin bit genişliği (Varsayılan: 8-bit)
)(
    input  wire [DATA_WIDTH-1:0]   A,        // 1. İşlenen (Operand A)
    input  wire [DATA_WIDTH-1:0]   B,        // 2. İşlenen (Operand B)
    input  wire [1:0]              S,        // Fonksiyon Seçim Sinyali (Operation Select)
    output reg                     ERR_done, // Hata / Geçersiz Durum Bayrağı (Error Flag)
    output wire [DATA_WIDTH*2-1:0] data_out  // ALU Çıkışı (Girişin 2 katı genişlikte, 16-bit)
);

    // Dışarıya sürülecek nihayi ALU sonucunu tutan iç register
    reg [DATA_WIDTH*2-1:0] r_data_out;
    assign data_out = r_data_out;


    // ========================================================================
    // 1. BOOTH MULTIPLIER (Çarpma Birimi)
    // ========================================================================
    wire [DATA_WIDTH*2-1:0] booth_multiplier_ALU_out;    
    wire [DATA_WIDTH*2-1:0] booth_multiplier_ALU_in;  
      
    // Booth Çarpanı Modül Örneklemesi (DUT_1)
    // NOT: 'B' portuna 'A' verilerek kare alma işlemi konfigüre edilmiştir.
    booth_multiplier_ALU #(                         
        .DATA_WIDTH(DATA_WIDTH)                        
    ) DUT_1 (                                       
        .A   (A),                       
        .B   (A), // B girişine A bağlandığı için A^2 hesaplar                       
        .out (booth_multiplier_ALU_out)                        
    );               

    assign booth_multiplier_ALU_in = {booth_multiplier_ALU_out};


    // ========================================================================
    // 2. COMPARATOR (Karşılaştırıcı Birimi)
    // ========================================================================
    wire       comparator_wire_1; // A > B durumu
    wire       comparator_wire_2; // A == B durumu
    wire       comparator_wire_3; // A < B durumu
    wire [2:0] comparator_in;

    // Karşılaştırıcı Modül Örneklemesi (DUT_2)
    comparator_ALU #(
        .DATA_WIDTH(DATA_WIDTH)  
    ) DUT_2 (
        .A           (A),
        .B           (B),            
        .A_greater_B (comparator_wire_1),
        .A_equal_B   (comparator_wire_2),
        .A_less_B    (comparator_wire_3)
    );

    // Karşılaştırma sonuçlarını 3-bitlik vektörde birleştir: {A>B, A==B, A<B}
    assign comparator_in = {comparator_wire_1, comparator_wire_2, comparator_wire_3};


    // ========================================================================
    // 3. ADDER (Toplayıcı Birimi)
    // ========================================================================
    wire [DATA_WIDTH-1:0] adder_out;       // Toplam sonucu (8-bit)
    wire                  adder_carry_out; // Elde biti (Carry Out)
    wire [DATA_WIDTH:0]   adder_ALU_in;    // Elde ile birleştirilmiş toplam (9-bit)

    // Toplayıcı Modül Örneklemesi (DUT_3)
    adder_ALU #(
        .DATA_WIDTH(DATA_WIDTH) 
    ) DUT_3 (
        .A         (A),
        .B         (B),
        .carry_in  (1'b0),            // Başlangıç elde girişi sıfır
        .out       (adder_out),
        .carry_out (adder_carry_out)
    );

    // Elde biti ile toplam sonucunu birleştir (9-bit veri)
    assign adder_ALU_in = {adder_carry_out, adder_out};


    // ========================================================================
    // 4. SUBTRACTOR (Çıkarıcı Birimi)
    // ========================================================================
    wire [DATA_WIDTH-1:0] alu_cikarici_d;     // Fark sonucu (Difference)
    wire                  alu_cikarici_b_out; // Borç biti (Borrow Out)
    wire [DATA_WIDTH:0]   alu_cikarici_in;    // Borç biti ile birleştirilmiş fark

    // Çıkarıcı Modül Örneklemesi (DUT_4)
    alu_cikarici #(
        .W(DATA_WIDTH) 
    ) DUT_4 (
        .x     (A),
        .y     (B),
        .b_in  (1'b0),               // Başlangıç borç girişi sıfır
        .d     (alu_cikarici_d),
        .b_out (alu_cikarici_b_out)
    );

    assign alu_cikarici_in = {alu_cikarici_b_out, alu_cikarici_d};


    // ========================================================================
    // 5. ALU ÇIKIŞ ÇOKLAMLAYICI (Output Multiplexer Block)
    // ========================================================================
    // 'S' seçim sinyaline göre hesaplanan sonuçlardan birini 16-bitlik çıkışa yönlendirir.
    always @(*) begin
        ERR_done = 0; // Varsayılan durum: Hata yok

        case (S)
            // S = 00: Çarpma İşlemi Sonucu (Booth Multiplier)
            2'b00 : begin
                r_data_out = {booth_multiplier_ALU_in};
            end
            
            // S = 01: Karşılaştırma Sonucu (3-bitlik sonucu 16-bite tamamlama)
            2'b01 : begin
                r_data_out = {13'd0, comparator_in};      
            end  
            
            // S = 10: Toplama İşlemi Sonucu (9-bitlik sonucu 16-bite tamamlama)
            2 meb10 : begin
                r_data_out = {7'd0, adder_ALU_in};    
            end 
            
            // S = 11: Çıkarma İşlemi Sonucu (İşaret Uzatımı / Sign Extension)
            2'b11 : begin
                // MSB bitini (işaret biti) 8 defa çoğaltarak 16-bitlik işaretli sayı genişletmesi yapar
                r_data_out = {{DATA_WIDTH{alu_cikarici_d[DATA_WIDTH-1]}}, alu_cikarici_d};
            end 
            
            // Geçersiz Durum Koruması
            default : begin
                r_data_out = 0;
                ERR_done   = 1; // Hata bayrağını aktif et
            end                         
        endcase
    end

endmodule
