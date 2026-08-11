`timescale 1ns / 1ps



module tb_fsm_bolme_islemi();
parameter W=4;
reg clk                ;
reg reset              ;
reg flag;
reg [W-1:0] bolunen    ;
reg [W-1:0] bolen      ;
wire [W-1:0] sonuc     ;
wire [W-1:0] kalan     ;
wire   DURUM    ;

fsm_bolme_islemi #(
.W(W)
) fsm_bolme_islemi_dut(
.clk    (clk    ),
.reset  (reset  ),
.flag(flag),
.bolunen(bolunen),
.bolen  (bolen  ),
.sonuc  (sonuc  ),
.kalan (kalan) ,
.DURUM  (DURUM  )
);

initial begin 
clk=0;

forever #10 clk=~clk;
end

initial begin
reset=1;
flag=0;
#25;
reset=0;
#5;
repeat(10)begin

bolunen=$random %(2**W);
bolen= $random %(2**W);
flag=1;
#20;
flag=0;
#200;

$display(" bolunen=%b , bolen=%b ,kalan=%b, sonuc=%b " , bolunen , bolen ,kalan, sonuc);

end
$finish;
end
endmodule

