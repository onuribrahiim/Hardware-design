`timescale 1ns / 1ps

module fpip_control #(
parameter DATA_WIDTH  = 32             , 
parameter ADDR_WIDTH  = 4              ,  // ram adres parametresi
parameter WIDTH_DEPTH = (2**ADDR_WIDTH)
)(


input  wire                  clk             ,
input  wire                  reset           ,
input  wire [22:0]           fraction        ,  // lfsr giriş değeri
output reg                   finish_signal   ,  // bitiş sinyali 
output reg                   data_ip0        ,  // o ve 1 durumu için reg ifadesi 
output reg                   data_ip1        ,  // o ve 1 durumu için reg ifadesi 
output reg                   hs_control0     ,  // durum analizi için bitiş sinyali
output reg                   hs_control1     ,  // durum analizi için bitiş sinyali
output reg                   sytem_full      ,
output reg  [DATA_WIDTH-1:0] data_out
   
);

// top modul desing item
localparam GREATER    = 32'h3dcccccd; //0.1
localparam LESS       = 32'h3f666666; //0.9
// top modul desing item



//------LFSR--İNSTANTİATE----------

reg                   lfsr_reset         ;
reg                   enable_lfsr        ;
wire [DATA_WIDTH-1:0] lfsr_data_out      ;
wire                  lfsr_done_signal   ;

lfsr #(
.DATA_WIDTH(DATA_WIDTH)
)lfsr_DUT(
.clk         (clk             ),
.reset       (lfsr_reset      ),
.fraction    (fraction        ),  // This is floating point number 
.enable      (enable_lfsr     ),
.data_out    (lfsr_data_out   ),
.done_signal (lfsr_done_signal)
 );

//---COMPARE---LESSS--İNSTANTİATE----



reg [DATA_WIDTH-1:0] s_data_in0;  // ip giriş verisi 32 bit olmalı
reg                  a_tvalid0 ;
reg                  b_tvalid0 ;

wire                 a_tready0 ;
wire                 b_tready0 ;
wire                 rs_tvalid0;
wire   [7:0]         result0   ;   // 0 1 sinyali 



floating_point_0  floating_point_0_DUT(
.aclk                (clk            ),
.s_axis_a_tvalid     (a_tvalid0      ),
.s_axis_a_tready     (a_tready0      ),
.s_axis_a_tdata      (s_data_in0     ),
.s_axis_b_tvalid     (b_tvalid0      ),
.s_axis_b_tready     (b_tready0      ),
.s_axis_b_tdata      (LESS           ),
.m_axis_result_tvalid(rs_tvalid0     ),
.m_axis_result_tready(1'b1           ),
.m_axis_result_tdata (result0        )      //Is the entered data less than 0.9?
);


//---COMPARE---GREATER--İNSTANTİATE----

reg  [DATA_WIDTH-1:0] s_data_in1;  // ip giriş verisi 32 bit olmalı
reg                   a_tvalid1 ;
reg                   b_tvalid1 ;

wire                  a_tready1 ;
wire                  b_tready1 ;
wire                  rs_tvalid1;
wire  [7:0]           result1   ;       // 0 1 sinyali 

floating_point_1  floating_point_1_DUT(
.aclk                (clk           ),
.s_axis_a_tvalid     (a_tvalid1     ),
.s_axis_a_tready     (a_tready1     ),
.s_axis_a_tdata      (s_data_in1    ),
.s_axis_b_tvalid     (b_tvalid1     ),
.s_axis_b_tready     (b_tready1     ),
.s_axis_b_tdata      (GREATER       ),
.m_axis_result_tvalid(rs_tvalid1    ),
.m_axis_result_tready(1'b1          ),
.m_axis_result_tdata (result1       )      //Is the entered data greater than 0.1?
);


reg  [ADDR_WIDTH-1:0] ram_addr     ;
reg                   ram_enable   ;
reg                   r_i_re_ram   ;
reg                   r_i_we_ram   ;
wire [DATA_WIDTH-1:0] r_o_rdata_ram;

RAM_Design #(
.WIDTH_DATA (DATA_WIDTH ),
.WIDTH_ADDR (ADDR_WIDTH ),
.WIDTH_DEPTH(WIDTH_DEPTH)
)RAM_Design_DUT(
.i_clk_ram   (clk          ),
.i_wdata_ram (s_data_in0   ),  // ikiside aynı sayı oldugu için bu kısıma 1 adet yazılması yeterli!!!
.i_addr_ram  (ram_addr     ),           
.i_enable_ram(ram_enable   ),
.i_re_ram    (r_i_re_ram   ),
.i_we_ram    (r_i_we_ram   ),
.o_rdata_ram (r_o_rdata_ram)
);



reg [3:0           ] state  ;
reg [ADDR_WIDTH-1:0] counter;

localparam START               = 4'b0000 ;
localparam LFSR_ENABLE         = 4'b0001 ;
localparam IP_CONTROL          = 4'b0010 ;
localparam HANDSHAKE_IP        = 4'b0011 ;
localparam SITUATION_ANALYSIS  = 4'b0100 ;
localparam CLEAR               = 4'b0101 ; 
localparam WRITING_PREPARATION = 4'b0110 ;
localparam WRITE_RAM           = 4'b0111 ;
localparam READ_PREPARATION    = 4'b1000 ;
localparam READ_RAM            = 4'b1001 ; 
localparam READ_RESULT         = 4'b1010 ;  
localparam IDLE                = 4'b1011 ;



always@(posedge clk or posedge reset)begin

    if(reset)begin                 // sistem ilk açıldığında X ve Z değerleri vermesin diye
                                   // reset kısmında reg ifadelerimizi "0" durumuna çekiyoruz .
       finish_signal<=0;
       data_ip0     <=0;
       data_ip1     <=0;
       hs_control0  <=0;
       hs_control1  <=0;
       data_out     <=0;
       
       lfsr_reset   <=0;
       enable_lfsr  <=0;
       
       s_data_in0   <=0;
       a_tvalid0    <=0;
       b_tvalid0    <=0;
       
       s_data_in1   <=0;
       a_tvalid1    <=0;
       b_tvalid1    <=0;
       
       ram_addr     <=0;
       ram_enable   <=0;
       r_i_re_ram   <=0;
       r_i_we_ram   <=0;
       sytem_full   <=0;
       
       state        <=0;
       counter      <=0;
   
        
      end else begin
      
      case(state)
      
      START : begin
      lfsr_reset   <=1; 
      enable_lfsr  <=0;                // lfsr resetlenir.
      state        <=LFSR_ENABLE;      
      end
      
      LFSR_ENABLE : begin
      lfsr_reset   <=0;
      enable_lfsr  <=1;              // lfsr çalışır duruma geçirilir.
      state        <=IP_CONTROL;
      end 
      
      IP_CONTROL : begin
      if(lfsr_done_signal)begin  // lfsr modülünde değer üretilir ise done sinyali 1 olur.
      enable_lfsr  <=0;          //  ip girişlerine üretilen random değer atandı!!
      
      s_data_in0<=lfsr_data_out;
      s_data_in1<=lfsr_data_out;
      
      a_tvalid0    <=1;
      b_tvalid0    <=1;
      
      a_tvalid1    <=1;
      b_tvalid1    <=1;
      
      state<=HANDSHAKE_IP;
      end
      end
      
      HANDSHAKE_IP : begin          // bu kısımda gecikmenin önüne geçtik !!!
      
       if (a_tready0)begin
           a_tvalid0 <= 0;
       end
       if(b_tready0)begin
           b_tvalid0 <= 0; 
       end                               // işlemlerin 1 clk cycle sonra olma durumlarını 
                                         // arka plana atma  / değerlendir her tasarımda
       if (a_tready1 ) begin
           a_tvalid1 <= 0;
       end
       if(b_tready1)begin
           b_tvalid1 <= 0;
       end
       if ((!a_tvalid0 || a_tready0)     && (!b_tvalid0 || b_tready0)     // clk gecikmesini engelledik!!
           && (!a_tvalid1 || a_tready1)  && (!b_tvalid1 || b_tready1))
           state<= SITUATION_ANALYSIS;
      end 
      
      
      SITUATION_ANALYSIS : begin
        if(rs_tvalid0) begin           // wire 
        data_ip0   <=result0       ;   // wire çıkışlarının reg ıfadede tutunmasın 0 ve 1 durumu 
        hs_control0<=1             ;
        end
        
        if(rs_tvalid1)begin            // wire
        data_ip1   <=result1       ; 
        hs_control1<=1             ;
        end
        
        if((rs_tvalid0 || hs_control0) 
        && (rs_tvalid1 || hs_control1))begin
        state      <=CLEAR         ;
        end
      end
      
      
      CLEAR : begin
      hs_control0 <=0                   ;
      hs_control1 <=0                   ;
      state       <=WRITING_PREPARATION ;
      end
      
      
 WRITING_PREPARATION : begin
      if (data_ip0 && data_ip1) begin
          ram_addr   <= counter    ; 
          ram_enable <= 1          ;
          r_i_we_ram <= 1          ; 
          data_ip0   <= 0          ;
          data_ip1   <= 0          ;
          state      <= WRITE_RAM  ;
      end else begin 
          data_ip0   <= 0          ;
          data_ip1   <= 0          ;
          state      <= LFSR_ENABLE;
      end
      end 
                
 WRITE_RAM : begin  
         if (counter == WIDTH_DEPTH-1) begin
             ram_addr   <= 0               ;
             ram_enable <= 0               ;
             r_i_we_ram <= 0               ;
             counter    <= 0               ;
             state      <= READ_PREPARATION;
         end else begin
             ram_enable <= 0               ;
             r_i_we_ram <= 0               ;
             counter    <= counter +1      ;
             state      <= LFSR_ENABLE     ;
         end   
         end
       
      READ_PREPARATION : begin  
      ram_addr     <=counter       ; 
      ram_enable   <=1             ;        
      r_i_re_ram   <=1             ;        
      data_out     <=r_o_rdata_ram ;
      state        <=READ_RAM      ;
      end 
            
      READ_RAM : begin       
      if(counter==WIDTH_DEPTH-1)begin
      ram_enable   <=0               ;
      r_i_re_ram   <=0               ; 
      counter      <=0               ;
      state        <=READ_RESULT     ;
      end else begin
      counter      <=counter + 1     ; 
      state        <=READ_PREPARATION;
      end
      end 
      
      READ_RESULT : begin
      data_out     <=r_o_rdata_ram ;
      finish_signal<=1             ;
      sytem_full   <=1             ;
      state        <=IDLE          ;
      end
      
      IDLE : begin
      if(!sytem_full)begin                 //  " Restarting / looping if RAM fills up "
      finish_signal<=0             ;
      state        <=START         ;
      end
      end
      
      default : begin
      state         <=START        ;
      end 
      
      endcase
      end 
      end
endmodule
