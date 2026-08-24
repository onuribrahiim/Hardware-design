`timescale 1ns / 1ps

// ============================================================================
// Module Name:  ALU_matrix
// Description:  Matrix Arithmetic Logic Unit (ALU). 
//               Performs selectable element-wise addition or multiplication 
//               between two vector/matrix data streams.
// ============================================================================

module ALU_matrix #(
    parameter DW = 4  // Data Bit-Width (Default set to 4 to align with top-level)
)
(
    input  wire [DW-1:0]      data_first,   // First matrix element operand
    input  wire [DW-1:0]      data_second,  // Second matrix element operand
    input  wire               S,            // Operation Select: 1 = Addition, 0 = Multiplication
    output reg  [DW*2+1:0]    alu_out       // Formatted ALU result output (Includes overflow headroom)
);

    // ========================================================================
    // Internal Signals & Interconnects
    // ========================================================================
    
    // Adder Submodule Wires
    wire          w_c_in = 1'b0;            // Initial carry-in forced to logic 0
    wire [DW-1:0] w_S;                      // Sum output bits from adder
    wire          w_carry;                  // Carry-out bit from adder
    wire [DW:0]   toplayici_out;            // Combined adder output (Carry + Sum)

    // Multiplier Submodule Wires
    wire [DW*2-1:0] w_sonuc;                // Full product result from multiplier
    wire [DW*2-1:0] sonuc_out;              // Buffered multiplier output bus

    // ========================================================================
    // Adder Submodule Instantiation
    // ========================================================================
    alu_toplayici #(
        .W(DW)
    ) alu_toplayici_dut (
        .x     (data_first),
        .y     (data_second),
        .c_in  (w_c_in),
        .S     (w_S),
        .carry (w_carry)
    );

    // Concatenate carry and sum bits into a single bus
    assign toplayici_out = {w_carry, w_S};

    // ========================================================================
    // Multiplier Submodule Instantiation
    // ========================================================================
    carpici_alu #(
        .WIDTH(DW)
    ) carpici_alu_dut (
        .A     (data_first),
        .B     (data_second),
        .sonuc (w_sonuc)
    );

    assign sonuc_out = w_sonuc;

    // ========================================================================
    // Output Multiplexer Logic (Combinational Block)
    // ========================================================================
    always @(*) begin
        if (S == 1'b1) begin
            // Select Adder output and zero-extend to match output width (DW*2+2 bits)
            alu_out = {{(DW+1){1'b0}}, toplayici_out};
        end else begin
            // Select Multiplier output and zero-extend to match output width (DW*2+2 bits)
            alu_out = {2'b00, sonuc_out};
        end
    end

endmodule
