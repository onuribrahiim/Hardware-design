`timescale 1ns / 1ps

// ============================================================================
// Module Name:  dual_port_RAM
// Description:  Synchronous Dual-Port RAM supporting independent read and 
//               write operations on two ports with a common clock.
// ============================================================================

module dual_port_RAM #(
    parameter WIDTH_DATA  = 6,               // Width of data bus in bits
    parameter WIDTH_ADDR  = 4,               // Width of address bus in bits
    parameter WIDTH_DEPTH = (2**WIDTH_ADDR)  // RAM depth calculated from address width
)(
    // Global Clock and Control Signals
    input wire                  i_clk_ram,    // Clock signal
    input wire                  enable,       // Memory global enable signal

    // ------------------ PORT 1 INTERFACE ------------------
    input wire [WIDTH_DATA-1:0] i_wdata_ram1, // Port 1 Write Data
    input wire [WIDTH_ADDR-1:0] i_addr_ram1,  // Port 1 Address
    input wire                  i_re_ram1,    // Port 1 Read Enable
    input wire                  i_we_ram1,    // Port 1 Write Enable
    output reg [WIDTH_DATA-1:0] o_rdata_ram1, // Port 1 Read Data

    // ------------------ PORT 2 INTERFACE ------------------
    input wire [WIDTH_DATA-1:0] i_wdata_ram2, // Port 2 Write Data
    input wire [WIDTH_ADDR-1:0] i_addr_ram2,  // Port 2 Address
    input wire                  i_re_ram2,    // Port 2 Read Enable
    input wire                  i_we_ram2,    // Port 2 Write Enable
    output reg [WIDTH_DATA-1:0] o_rdata_ram2  // Port 2 Read Data
);

    // Memory Array Definition
    reg [WIDTH_DATA-1:0] dual_port_RAM [WIDTH_DEPTH-1:0];

    // ------------------------------------------------------------------------
    // PORT 1: Synchronous Write and Read Operations
    // ------------------------------------------------------------------------
    always @(posedge i_clk_ram) begin
        if (enable) begin
            if (i_we_ram1) begin
                dual_port_RAM[i_addr_ram1] <= i_wdata_ram1; // Write operation
            end
            
            if (i_re_ram1) begin
                o_rdata_ram1 <= dual_port_RAM[i_addr_ram1]; // Read operation
            end
        end
    end 
   
    // ------------------------------------------------------------------------
    // PORT 2: Synchronous Write and Read Operations
    // ------------------------------------------------------------------------
    always @(posedge i_clk_ram) begin
        if (enable) begin
            if (i_we_ram2) begin
                dual_port_RAM[i_addr_ram2] <= i_wdata_ram2; // Write operation
            end
            
            if (i_re_ram2) begin
                o_rdata_ram2 <= dual_port_RAM[i_addr_ram2]; // Read operation
            end
        end
    end 
endmodule
