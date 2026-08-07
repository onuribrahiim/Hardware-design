`timescale 1ns / 1ps                                                           
                                                                               
                                                                               
                                                                               
module RAM_Design #(                                                           
parameter WIDTH_DATA = 8,                // veri genisligi                     
parameter WIDTH_ADDR = 4,                // adres genisligi                    
parameter WIDTH_DEPTH = (2**WIDTH_ADDR)  // ram derinlik genisligi             
)                                                                              
(                                                                              
input                  i_clk_ram,                                              
input [WIDTH_DATA-1:0] i_wdata_ram, // ram ' e yazılacak veri                  
input [WIDTH_ADDR-1:0] i_addr_ram,  // ram ' e yazılıcak adres                 
                                                                               
input                  i_enable_ram,    // ram calismasi icin izin giris       
input                  i_re_ram,        // enable for read                     
input                  i_we_ram,       // enable for write                     
                                                                               
output reg [WIDTH_DATA-1:0] o_rdata_ram  //  read for exit                     
 );                                                                            
                                                                               
reg [WIDTH_DATA-1:0] ram_name [0:WIDTH_DEPTH-1] ;                              
                                                                               
always@(posedge i_clk_ram)begin                                                
  if(i_enable_ram)begin  // to make ready for operation                        
     if(i_we_ram)begin                                                         
        ram_name[i_addr_ram] <= i_wdata_ram;  // İceri Kayit Etme              
     end                                                                       
                                                                               
     if(i_re_ram)begin                                                         
                                                                               
        o_rdata_ram <= ram_name[i_addr_ram];  // Dışarıya Okuma                
     end                                                                       
  end                                                                          
end                                                                            
endmodule                                                                      
                                                                               
