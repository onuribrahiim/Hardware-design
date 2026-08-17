`timescale 1ns / 1ps

module memory_multiplication #(
parameter data_WIDTH     =6,
          addr_WIDTH     =4,
          derinlik_WIDTH=16   
)(
input wire                 clk          ,
input wire                 reset        ,
input wire                 memory_enable,
input wire  [data_WIDTH-1:0]   data_login  ,
output wire [data_WIDTH*2-1:0] data_exit 
);

// =========================================================================
// LFSR Module Signals & Instantiation (Pseudo-Random Generation)
// =========================================================================
reg                   r_reset_LFSR   ;
reg                   r_enable_LFSR ;
wire [data_WIDTH-1:0] r_data1_LFSR   ;
wire [data_WIDTH-1:0] r_data2_LFSR   ;
wire                  r_o_ERR        ;  

new_LFSR #(
.DATA_WIDTH(data_WIDTH)
)new_LFSR_DUT(
.clk        (clk           ),
.reset      (r_reset_LFSR  ),
.enable_lfsr(r_enable_LFSR),
.data_in    (data_login    ),
.data1      (r_data1_LFSR  ),
.data2      (r_data2_LFSR  ),
.o_ERR      (r_o_ERR       )
);

// =========================================================================
// RAM1 Module Signals & Instantiation (Stores LFSR Data1)
// =========================================================================
reg  [addr_WIDTH-1:0] r_addr_RAM1     ;
reg                   r_enable_RAM1   ;
reg                   read_enable_RAM1;  
reg                   write_enableRAM1;
wire [data_WIDTH-1:0] r_data_out_RAM1;

new_ram #(
.data_WIDTH    (data_WIDTH    ),
.addr_WIDTH    (addr_WIDTH    ),
.derinlik_WIDTH(derinlik_WIDTH)
)new_ram_DUT1(
.addr        (r_addr_RAM1     ),
.data_in     (r_data1_LFSR    ),
.clk         (clk             ),
.enable      (r_enable_RAM1   ),
.read_enable (read_enable_RAM1),
.write_enable(write_enableRAM1),
.data_out    (r_data_out_RAM1 )
);

// =========================================================================
// RAM2 Module Signals & Instantiation (Stores LFSR Data2)
// =========================================================================
reg  [addr_WIDTH-1:0] r_addr_RAM2     ;
reg                   r_enable_RAM2   ;
reg                   read_enable_RAM2;  
reg                   write_enableRAM2;
wire [data_WIDTH-1:0] r_data_out_RAM2 ;

new_ram #(
.data_WIDTH    (data_WIDTH    ),
.addr_WIDTH    (addr_WIDTH    ),
.derinlik_WIDTH(derinlik_WIDTH)
)new_ram_DUT2(
.addr        (r_addr_RAM2     ),
.data_in     (r_data2_LFSR    ),
.clk         (clk             ),
.enable      (r_enable_RAM2   ),
.read_enable (read_enable_RAM2),
.write_enable(write_enableRAM2),
.data_out    (r_data_out_RAM2 )
);

// =========================================================================
// Multiplier Module Signals & Output Latch
// =========================================================================
reg                     r_reset_carpici ;
reg                     r_enable_carpici;
reg  [data_WIDTH*2-1:0] data_latch      ;
wire [data_WIDTH*2-1:0] r_sonuc_carpici ;
wire [0:0]              r_sonuc_hazir   ;

assign data_exit = data_latch;

carpici #(
.DW(data_WIDTH)
)carpici_DUT(
.clk           (clk             ),
.reset         (r_reset_carpici ),
.enable_carpici(r_enable_carpici),
.carpilan      (r_data_out_RAM1 ),
.carpan        (r_data_out_RAM2 ),
.sonuc         (r_sonuc_carpici ),
.sonuc_hazir   (r_sonuc_hazir   )
);

// =========================================================================
// FSM State Encoding & Counter
// =========================================================================
reg [2:0] state ;
localparam start                = 3'b000;
localparam data_lfsr            = 3'b001;
localparam ram_write            = 3'b010;
localparam clear                = 3'b011;
localparam data_carpici_kontrol = 3'b100; // Pre-fetch state to mask RAM read latency
localparam data_carpici         = 3'b101; // Multiplier execution & Handshake state
localparam DONE                 = 3'b110;

reg [derinlik_WIDTH-1:0] counter ;

// =========================================================================
// Main Control FSM Block
// =========================================================================
always@(posedge clk or posedge reset)begin
   if(reset)begin
      state<=start;
      r_reset_LFSR  <=0;
      r_enable_LFSR <=0;
      
      r_addr_RAM1     <=0;
      r_enable_RAM1   <=0;
      read_enable_RAM1<=0;
      write_enableRAM1<=0;
      
      r_addr_RAM2     <=0;
      r_enable_RAM2   <=0;
      read_enable_RAM2<=0;
      write_enableRAM2<=0;
      
      r_reset_carpici <=0;
      r_enable_carpici<=0;
      data_latch      <=0;
      counter<=0;
    
   end else begin
   case(state)
   
   // --- Initial LFSR Reset State ---
   start : begin
   r_enable_LFSR<=1;
   r_reset_LFSR<=1;
   counter<=0;
   state<=data_lfsr;
   end
   
   // --- RAM Write Setup State ---
   // Assert write_enable 1 clock cycle early to account for non-blocking (<=) assignment delay.
   // This guarantees write enable is high when entering ram_write at counter = 0.
   data_lfsr : begin
   r_enable_LFSR<=1;
   r_reset_LFSR<=0;
   r_enable_RAM1<=1;   
   r_enable_RAM2<=1;   
                       
   write_enableRAM1<=1;
   write_enableRAM2<=1;
                       
   read_enable_RAM1<=0; 
   read_enable_RAM2<=0;
   state<=ram_write;
   
   end
   
   // --- Sequential RAM Write Loop ---
   // Streams LFSR outputs into RAM addresses continuously on every clock cycle.
   ram_write : begin
   r_enable_LFSR<=1;
   r_enable_RAM1<=1;
   r_enable_RAM2<=1;
   
   write_enableRAM1<=1;
   write_enableRAM2<=1;
   
   read_enable_RAM1<=0;
   read_enable_RAM2<=0;
   
   r_addr_RAM1<=counter;
   r_addr_RAM2<=counter;
   
   if(counter==derinlik_WIDTH-1)begin
    state<=clear;
    counter<=0; // Reset counter for the upcoming read phase
   end else begin 
    counter<=counter+1;
    state<=ram_write;
   end
   end
   
   // --- Mode Transition & Signal De-assertion ---
   // Clear write signals and reset addresses when switching from write to read operation.
   clear : begin
    r_enable_LFSR    <= 0;
    r_enable_RAM1    <= 1;
    r_enable_RAM2    <= 1;
    write_enableRAM1 <= 0;
    write_enableRAM2 <= 0;
    read_enable_RAM1<=0;
    read_enable_RAM2<=0;
    r_addr_RAM1<=0;
    r_addr_RAM2<=0;
    state<=data_carpici_kontrol;
   
   end
   
   // --- Pre-Fetch State (RAM Read Latency Masking) ---
   // Drives RAM address 1 clock cycle early to absorb synchronous memory read latency.
   // Multiplier remains disabled/reset during this cycle.
   data_carpici_kontrol : begin
    r_enable_LFSR<=0; 
    r_enable_RAM1<=1;
    r_enable_RAM2<=1;
   
    write_enableRAM1<=0;
    write_enableRAM2<=0;
    
    read_enable_RAM1<=1;
    read_enable_RAM2<=1;

    r_enable_carpici<=0;
    r_reset_carpici<=1; // Reset multiplier state for the new operation
    
    r_addr_RAM1<=counter; // Pre-fetch address for current iteration
    r_addr_RAM2<=counter;
    
    state<=data_carpici;
    
    end
   
   // --- Multiplier Execution & Handshake State ---
   // RAM output data is now valid on this cycle.
   // Multiplier is enabled, and counter freezes until 'r_sonuc_hazir' asserts completion.
   data_carpici : begin
    r_enable_LFSR<=0; 
    r_enable_RAM1<=1;
    r_enable_RAM2<=1;
   
    write_enableRAM1<=0;
    write_enableRAM2<=0;
    
    read_enable_RAM1<=1;
    read_enable_RAM2<=1;
    
    r_enable_carpici<=1;
    r_reset_carpici<=0;
    
    // Handshake check: Latch calculated result and increment counter only on valid ready signal.
    if(r_sonuc_hazir) begin
         data_latch<=r_sonuc_carpici;
    
       if(counter==derinlik_WIDTH-1) begin
       r_enable_carpici<=0;
       r_enable_RAM1<=0;
       r_enable_RAM2<=0;
       counter<=0;
       state<=DONE;
    end else begin
    counter<=counter+1;
    state<=data_carpici_kontrol; // Return to pre-fetch state for next memory address
    end
    end
   end
   
   // --- Execution Complete State ---
   DONE : begin
   if(memory_enable)
   state<=data_lfsr;
   
   end
   
   default : begin
   
   state<=start;
   
   end    
 endcase  
   end
end
endmodule
