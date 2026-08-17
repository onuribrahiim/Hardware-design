`timescale 1ns / 1ps

// =========================================================================
// Testbench: tb_memory_multiplication
// Description: Verification environment for the LFSR, Dual RAM, and Multiplier top module.
// =========================================================================

module tb_memory_multiplication();

// =========================================================================
// Parameter Definitions & Testbench Signals
// =========================================================================
parameter data_WIDTH =6      ;
parameter addr_WIDTH =4      ;
parameter derinlik_WIDTH=16  ;

reg                     clk         ;
reg                     reset       ;
reg                     memory_enable;
reg  [data_WIDTH-1:0]   data_login  ;
wire [data_WIDTH*2-1:0] data_exit   ;

// =========================================================================
// Device Under Test (DUT) Instantiation
// =========================================================================
memory_multiplication #(
.data_WIDTH    (data_WIDTH    ),
.addr_WIDTH    (addr_WIDTH    ),
.derinlik_WIDTH(derinlik_WIDTH)
) memory_multiplication_DUT (
.clk       (clk       ),
.reset     (reset     ),
.memory_enable(memory_enable),
.data_login(data_login),
.data_exit (data_exit )
);

// =========================================================================
// Clock Generation (50 MHz Clock Frequency / 20ns Period)
// =========================================================================
initial begin
clk=0;
forever #10 clk=~clk;
end

// =========================================================================
// Test Stimulus & Sequence Execution
// =========================================================================
initial begin
// Apply active-high reset and initialize input signals
reset=1;
data_login=0;
memory_enable=0;
#20;

// De-assert reset and feed a pseudo-random initial seed value to the LFSR
reset=0;
data_login=$random %(2**data_WIDTH);

// Delay allowing full FSM pipeline execution:
// 1. LFSR pseudo-random generation
// 2. Sequential RAM write loop
// 3. Pre-fetch and handshake-driven multiplication loop
#5000;

// Pulse memory_enable to trigger re-execution from the DONE state
memory_enable=1;
#20;

// End simulation execution
$finish;
end
endmodule
