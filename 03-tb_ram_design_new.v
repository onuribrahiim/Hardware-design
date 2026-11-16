//==============================================================================
// File         : tb_ram_design_new.v
// Title        : Parametric Synchronous RAM - Self-Checking Testbench
// Tested Item  : ram_design_new (DUT)
//
// Purpose      : To write different values to 16 addresses of the RAM, then read 
//                them back in an order DIFFERENT from the write order, and 
//                automatically verify that the read value matches the expected value.
//
// Verification : - Expected values come from the testbench, independent of the DUT.
//                - === / !== operators are used for comparison, so X/Z states 
//                  are also caught as errors.
//                - Error count is tracked, and a summary is printed at the end of simulation.
//
// Expected Out : "NO ERROR FOUND" for all 16 reads and "TEST SUCCESSFUL" at the end.
//==============================================================================

`timescale 1ns / 1ps


module tb_ram_design_new();

//------------------------------------------------------------------------------
// Parameters (Must match the values used in the DUT)
//------------------------------------------------------------------------------
parameter DATA_WIDTH  = 8              ;   // Data width: 8 bits (0-255)
parameter ADDR_WIDTH  = 4              ;   // Address width: 4 bits (16 addresses)
parameter DEPTH_WIDTH = 2**(ADDR_WIDTH);   // Memory depth: 2^4 = 16 cells


//------------------------------------------------------------------------------
// Signals
// Testbench drives the DUT inputs -> reg
// Testbench only reads the DUT output -> wire
//------------------------------------------------------------------------------
reg                   clk         ;   // Clock signal
reg                   reset       ;   // Synchronous reset (clears data_out)
reg                   ram_enable  ;   // RAM general enable signal
reg                   write_enable;   // Write enable
reg                   read_enable ;   // Read enable
reg  [DATA_WIDTH-1:0] data_in     ;   // Data to be written
reg  [ADDR_WIDTH-1:0] addr_in     ;   // Read/write address
wire [DATA_WIDTH-1:0] data_out    ;   // Data read from DUT


//------------------------------------------------------------------------------
// DUT Instantiation (ports connected by name)
//------------------------------------------------------------------------------
ram_design_new #(
.DATA_WIDTH  (DATA_WIDTH  ),
.ADDR_WIDTH  (ADDR_WIDTH  ),
.DEPTH_WIDTH (DEPTH_WIDTH )
)ram_design_new_DUT(
.clk         (clk         ),
.reset       (reset       ),
.ram_enable  (ram_enable  ),
.write_enable(write_enable),
.read_enable (read_enable ),
.data_in     (data_in     ),
.addr_in     (addr_in     ),
.data_out    (data_out    )
);


//------------------------------------------------------------------------------
// Counters (module-level, to retain values across tasks)
//------------------------------------------------------------------------------
integer numbero_f_errors ;   // Total error count (increments only when verification fails)
integer error_sequence;      // Read sequence number (increments on every read_name call)


//------------------------------------------------------------------------------
// Clock generation: half period 5 ns -> period 10 ns -> 100 MHz
//------------------------------------------------------------------------------
initial begin
clk=0;                       // If initial value is not set, clk remains X and never toggles
end 

always #5 clk = ~clk;


//------------------------------------------------------------------------------
// Main Test Scenario
//------------------------------------------------------------------------------
initial begin 

// --- Initialization: Drive all inputs to known values (prevent X propagation) ---
reset           =1;
ram_enable      =0;
write_enable    =0;
read_enable     =0;
data_in         =0;
addr_in         =0;
numbero_f_errors=0;          // If counters are not reset, they remain X and never increment
error_sequence  =0;

// --- Reset: Since it is synchronous, keep it active for at least one clock edge ---
repeat(2)@(posedge clk);
reset=0;

// --- Stage 1: Writing ---
// write_name(data, address)
$display(" TEST:WRITE ");
write_name('d12 , 'd5 );   // Address 5  <- 12
write_name('d11 , 'd1 );   // Address 1  <- 11
write_name('d45 , 'd7 );   // Address 7  <- 45
write_name('d10 , 'd3 );   // Address 3  <- 10
write_name('d200, 'd12);   // Address 12 <- 200
write_name('d77 , 'd0 );   // Address 0  <- 77
write_name('d33 , 'd9 );   // Address 9  <- 33
write_name('d150, 'd14);   // Address 14 <- 150
write_name('d99 , 'd2 );   // Address 2  <- 99
write_name('d5  , 'd10);   // Address 10 <- 5
write_name('d255, 'd15);   // Address 15 <- 255
write_name('d64 , 'd4 );   // Address 4  <- 64
write_name('d18 , 'd8 );   // Address 8  <- 18
write_name('d130, 'd13);   // Address 13 <- 130
write_name('d88 , 'd6 );   // Address 6  <- 88
write_name('d21 , 'd11);   // Address 11 <- 21

// --- Wait between write and read stages (separates phases in waveform) ---
repeat(20)@(posedge clk);

// --- Stage 2: Reading and Verification ---
// read_name(address, expected_value)
// Addresses are read sequentially from 0 to 15 (different from the write order):
// Proves that values are stored based on address rather than write order.
$display(" TEST:READ ");
read_name('d0 , 'd77 );   // Expected: 77
read_name('d1 , 'd11 );   // Expected: 11
read_name('d2 , 'd99 );   // Expected: 99
read_name('d3 , 'd10 );   // Expected: 10
read_name('d4 , 'd64 );   // Expected: 64
read_name('d5 , 'd12 );   // Expected: 12
read_name('d6 , 'd88 );   // Expected: 88
read_name('d7 , 'd45 );   // Expected: 45
read_name('d8 , 'd18 );   // Expected: 18
read_name('d9 , 'd33 );   // Expected: 33
read_name('d10, 'd5  );   // Expected: 5
read_name('d11, 'd21 );   // Expected: 21
read_name('d12, 'd200);   // Expected: 200
read_name('d13, 'd130);   // Expected: 130
read_name('d14, 'd150);   // Expected: 150
read_name('d15, 'd255);   // Expected: 255

// --- Result Summary ---
// Decide based on the total error count after all reads are completed.
repeat(10)@(posedge clk);
if(numbero_f_errors==0)begin
$display("---------------------");
$display("----TEST SUCCESSFUL--");
end else begin
$display("---------------------");
$display("TEST FAILED & ERROR COUNT=%d",numbero_f_errors);
end

// Finish simulation (otherwise clock runs infinitely)
$finish;

end




//------------------------------------------------------------------------------
// TASK: write_name
// Writes the given data to the given address.
//   data_in_r : Data to be written
//   addr_in_r : Target address
// Values are held stable for two clock cycles, then enables are disabled.
//------------------------------------------------------------------------------
task write_name(input [DATA_WIDTH-1:0] data_in_r , input [ADDR_WIDTH-1:0] addr_in_r); 
begin
repeat(2)@(posedge clk);

       // Drive inputs: RAM enabled, write enabled, read disabled
       data_in     =data_in_r;
       addr_in     =addr_in_r;
       ram_enable  =1        ;
       write_enable=1        ; 
       read_enable =0        ;
       
// Keep signals stable for two clock cycles so the RAM captures data on the rising edge
repeat(2)@(posedge clk);
       write_enable=0        ;   // Write completed, disable write
       read_enable =0        ;
       $display(" Target Address=%d & Written Data=%d  ",addr_in_r,data_in_r);

end
endtask


//------------------------------------------------------------------------------
// TASK: read_name
// Reads from the given address and compares the read value with the expected value.
//   addr_in_r : Address to be read
//   expected  : Expected value from this address (answer key)
// If an error occurs, the error counter is incremented.
//------------------------------------------------------------------------------
task read_name( input [ADDR_WIDTH-1:0] addr_in_r , input [DATA_WIDTH-1:0] expected); 
begin
repeat(2)@(posedge clk);

       // Drive inputs: RAM enabled, write disabled, read enabled
       addr_in        =addr_in_r            ;
       ram_enable     =1                    ;
       write_enable   =0                    ; 
       read_enable    =1                    ;
       error_sequence = error_sequence + 1  ;   // Count the read sequence number

// Since data_out is registered, read comes with a one-clock delay, wait for two clocks
repeat(2)@(posedge clk);
   write_enable=0        ;
   read_enable =0        ;    

   // Print read and expected values (TRUE/FALSE: === considers X as FALSE)
   $display("expected value=%d & Read Address=%d & Read Value=%d | %s ",expected,addr_in_r,data_out,
   (data_out===expected) ? "TRUE" : "FALSE"  );
        
        // Error check: !== catches X/Z states as errors too
        if(data_out!==expected)begin
        numbero_f_errors=numbero_f_errors+1;                  // Increment counter first
        $display(" ERROR SEQUENCE=%d ",error_sequence   );       // In which read error occurred
        $display(" ERROR COUNT=%d ",numbero_f_errors );       // Total errors so far
        end else  begin
        $display(" NO ERROR FOUND ");
        end

end
endtask
endmodule
