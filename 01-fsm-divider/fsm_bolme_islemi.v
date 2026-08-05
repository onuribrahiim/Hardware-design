`timescale 1ns / 1ps

// ============================================================================
// Module Name: fsm_bolme_islemi
// Description: Parametric Division Algorithm using Sequential Subtraction FSM
// Param W    : Data bit-width for dividend, divisor, and quotient
// ============================================================================

module fsm_bolme_islemi #(
    parameter W = 4                     // Default bit-width set to 4 bits
)(
    input  wire         clk,            // System Clock
    input  wire         reset,          // Active-High Asynchronous Reset
    input  wire         flag,           // Trigger signal to restart processing from IDLE
    input  wire [W-1:0] bolunen,        // Dividend input operand
    input  wire [W-1:0] bolen,          // Divisor input operand
    output wire [W-1:0] sonuc,          // Calculated Quotient output
    output wire         DURUM           // Error Status Flag (1: Division by Zero or Undefined)
);

    // Internal Registers
    reg [W-1:0] r_bolen;                // Latched divisor register
    reg [W-1:0] r_bolunen;              // Working register for dividend / remainder
    reg         r_DURUM;                // Internal register for DURUM flag
    reg [W-2:0] state;                  // State machine register
    reg [W-1:0] r_sonuc;                // Quotient register holding final output
    reg [W-1:0] count;                  // Iterative subtraction counter (Quotient accumulator)

    // Continuous Assignments to map internal registers to output ports
    assign sonuc = r_sonuc;
    assign DURUM = r_DURUM;

    // FSM State Encoding Definition (3-bit state codes)
    localparam start = 3'b000;          // Initialize and sample inputs
    localparam L1    = 3'b001;          // Initial validity check (Dividend >= Divisor)
    localparam L2    = 3'b010;          // Subtraction step: remainder = remainder - divisor
    localparam L3    = 3'b011;          // Loop condition evaluation check
    localparam DONE  = 3'b100;          // Normal completion: assign quotient
    localparam IDLE  = 3'b101;          // Idle / Wait state for next operation
    localparam out   = 3 meb110;         // Fault / Out-of-bounds state handling
    // Note: State 'out' code 3'b110 sets r_DURUM high

    // Synchronous FSM Control Block with Asynchronous Reset
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= start;
        end else begin
            case (state)
                
                // STATE 0: Sample input signals and set default internal counts
                start: begin
                    r_bolunen <= bolunen;
                    r_bolen   <= bolen;
                    r_sonuc   <= 0;
                    count     <= 0;
                    r_DURUM   <= 0;
                    state     <= L1;
                end
                
                // STATE 1: Check if the dividend is immediately smaller than the divisor
                L1: begin
                    if (r_bolunen >= r_bolen) begin
                        state <= L2;
                    end else begin
                        state <= out;   // Skip computation if dividend < divisor
                    end
                end
                
                // STATE 2: Perform iterative subtraction and increment step counter
                L2: begin
                    r_bolunen <= r_bolunen - r_bolen;
                    count     <= count + 1;
                    state     <= L3;     
                end
                
                // STATE 3: Check if further subtraction loops are possible
                L3: begin
                    if (r_bolunen >= r_bolen) begin
                        state <= L2;   // Continue subtraction loop
                    end else begin
                        state <= DONE; // Exit loop, division complete
                    end
                end
                
                // STATE 4: Finalize normal division result
                DONE: begin
                    r_sonuc <= count;
                    state   <= IDLE;
                end 
                
                // STATE 6: Set flag for special/out-of-bound edge cases
                out: begin  
                    r_DURUM <= 1;      
                    state   <= IDLE;
                end
                
                // STATE 5: Standby state - wait for external trigger signal 'flag'
                IDLE: begin 
                    if (flag)
                        state <= start; 
                end
                
                // Safety Recovery Default State
                default: begin
                    state <= start;
                end
                
            endcase
        end
    end

endmodule
