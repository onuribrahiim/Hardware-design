`timescale 1ns / 1ps

// ============================================================================
// Module Name:  matrix_multiplication
// Description:  Top-level Verilog module for automated matrix multiplication.
//               Integrates LFSR pseudo-random data generation, dual-port RAM
//               storage, matrix-ALU processing, and output buffer management.
// ============================================================================

module matrix_multiplication #(
    parameter DATA_WIDTH   = 4,  // Bit-width for matrix data elements
    parameter ADDR_WIDTH   = 4,  // Address bus width for internal RAMs
    parameter DEPTH_WIDTH  = 12  // Depth setting for memory structures
)
(
    input  wire                      clk,         // System Clock
    input  wire                      reset,       // Active-High System Reset
    input  wire [DATA_WIDTH-1:0]     data_login,  // Initial seed / input data for LFSR
    output wire [DATA_WIDTH*2+1:0]   data_out     // Final accumulated result output
);

    // ========================================================================
    // Internal Signals & Submodule Interconnects
    // ========================================================================
    
    // LFSR Controller Signals & Outputs
    reg                     r_reset_LFSR;
    reg                     r_enable_LFSR;
    wire [DATA_WIDTH-1:0]   w_data1;
    wire [DATA_WIDTH-1:0]   w_data2;
    wire                    w_o_ERR; 

    // Internal Dual-Port RAM Control Signals
    reg                     r_enable_new_ram;
    reg                     r_read_enable_new_ram;
    reg                     r_write_enable_new_ram;
    reg  [ADDR_WIDTH-1:0]   r_addr_1_new_ram;
    reg  [ADDR_WIDTH-1:0]   r_addr_2_new_ram;
    wire [DATA_WIDTH-1:0]   w_data_out_1_new_ram;
    wire [DATA_WIDTH-1:0]   w_data_out_2_new_ram;

    // ALU & Accumulation Register
    reg  [DATA_WIDTH*2+1:0] ACC;                    // Hardware Accumulator
    reg  [0:0]              r_S_ALU_matrix;         // ALU Operation Select
    wire [DATA_WIDTH*2+1:0] r_alu_out_ALU_matrix;   // ALU Product Output

    // Output Storage RAM Control Signals
    reg  [DATA_WIDTH*2+1:0] r_i_wdata_ram;
    reg  [ADDR_WIDTH-1:0]   r_i_addr_ram;
    reg                     r_i_enable_ram;
    reg                     r_i_re_ram;
    reg                     r_i_we_ram;

    // FSM Registers and Matrix Indexing Counters
    reg [3:0]            state;
    reg [3:0]            counter;
    reg [ADDR_WIDTH-1:0] k;           // Base offset index for Matrix B
    reg [ADDR_WIDTH-1:0] A_taban;     // Base address pointer for Matrix A
    reg [1:0]            c_index;     // Result memory write pointer

    // ========================================================================
    // FSM State Encoding (Standardized localparam mapping)
    // ========================================================================
    localparam ST_IDLE            = 4'b0000; // Reset state and system clear
    localparam ST_LFSR_INIT       = 4'b0001; // Enable LFSR generation
    localparam ST_RAM_WRITE_INIT  = 4 meb0010; // Populate internal RAM with LFSR data
    localparam ST_PREP_FETCH      = 4'b0011; // Setup read addresses for matrix elements
    localparam ST_FETCH_COMPUTE   = 4'b0100; // Multiply elements and accumulate product
    localparam ST_STORE_RESULT    = 4'b0101; // Commit accumulated sum to output RAM
    localparam ST_UPDATE_INDEX    = 4'b0110; // Advance matrix base row/column pointers
    localparam ST_READ_PREP       = 4'b0111; // Prepare output RAM address for dump
    localparam ST_READ_OUTPUT     = 4'b1000; // Stream matrix result to data_out bus
    localparam ST_RESTART         = 4'b1001; // Loop execution back to initial state

    // ========================================================================
    // Submodule Instantiations
    // ========================================================================

    // Pseudo-random hardware sequence generator
    new_LFSR #(
        .DATA_WIDTH(DATA_WIDTH)
    ) new_LFSR_DUT (
        .clk         (clk),
        .reset       (r_reset_LFSR),
        .enable_lfsr (r_enable_LFSR),
        .data_in     (data_login),
        .data1       (w_data1),
        .data2       (w_data2)
    );

    // Primary internal storage for input matrices
    new_ram #(
        .data_WIDTH     (DATA_WIDTH),  
        .addr_WIDTH     (ADDR_WIDTH),
        .derinlik_WIDTH (DEPTH_WIDTH)
    ) new_ram_DUT (
        .clk          (clk),
        .enable       (r_enable_new_ram),
        .read_enable  (r_read_enable_new_ram),
        .write_enable (r_write_enable_new_ram),
        .addr_1       (r_addr_1_new_ram),
        .addr_2       (r_addr_2_new_ram),
        .data_in_1    (w_data1),
        .data_in_2    (w_data2),
        .data_out_1   (w_data_out_1_new_ram),
        .data_out_2   (w_data_out_2_new_ram)
    );

    // Matrix Multiply-Accumulate ALU unit
    ALU_matrix #(
        .DW(DATA_WIDTH)
    ) ALU_matrix_DUT (
        .data_first  (w_data_out_1_new_ram),
        .data_second (w_data_out_2_new_ram),
        .S           (r_S_ALU_matrix),
        .alu_out     (r_alu_out_ALU_matrix)
    );

    // Final result storage buffer
    RAM_Design #(
        .WIDTH_DATA  (DATA_WIDTH * 2),
        .WIDTH_ADDR  (ADDR_WIDTH),
        .WIDTH_DEPTH (DEPTH_WIDTH)
    ) RAM_Design_DUT (
        .i_clk_ram    (clk),
        .i_wdata_ram  (r_i_wdata_ram),
        .i_addr_ram   (r_i_addr_ram),        
        .i_enable_ram (r_i_enable_ram),
        .i_re_ram     (r_i_re_ram),
        .i_we_ram     (r_i_we_ram),
        .o_rdata_ram  (data_out)
    );

    // ========================================================================
    // Main Finite State Machine & Processing Engine
    // ========================================================================
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state                  <= ST_IDLE;
            counter                <= 0;
                  
            r_reset_LFSR           <= 0;
            r_enable_LFSR          <= 0;
            
            r_enable_new_ram       <= 0;
            r_read_enable_new_ram  <= 0;
            r_write_enable_new_ram <= 0;
            r_addr_1_new_ram       <= 0;
            r_addr_2_new_ram       <= 0;
            
            r_S_ALU_matrix         <= 1'b1;
            
            r_i_addr_ram           <= 0;
            r_i_enable_ram         <= 0;
            r_i_re_ram             <= 0;
            r_i_we_ram             <= 0;
            r_i_wdata_ram          <= 0;
            
            ACC                    <= 0;
            k                      <= 4'd6; // Initial Base Address offset for Matrix B
            A_taban                <= 4'd0; // Initial Base Address pointer for Matrix A
            c_index                <= 2'd0;
            
        end else begin
            case (state)
                
                // ST_IDLE: Clear flags and initialize LFSR module
                ST_IDLE: begin
                    r_enable_LFSR <= 1'b1;
                    r_reset_LFSR  <= 1'b1;
                    state         <= ST_LFSR_INIT;
                end
                
                // ST_LFSR_INIT: De-assert LFSR reset to begin pseudo-random generation
                ST_LFSR_INIT: begin
                    r_enable_LFSR <= 1'b1;
                    r_reset_LFSR  <= 1'b0;
                    state         <= ST_RAM_WRITE_INIT;
                end
                
                // ST_RAM_WRITE_INIT: Stream LFSR data directly into internal RAM
                ST_RAM_WRITE_INIT: begin
                    r_enable_LFSR          <= 1'b1;
                    r_enable_new_ram       <= 1'b1;
                    r_read_enable_new_ram  <= 1'b0;
                    r_write_enable_new_ram <= 1'b1;
                    
                    r_addr_1_new_ram       <= counter;
                    r_addr_2_new_ram       <= counter + 4'd6;
                    
                    if (counter == 4'd5) begin
                        state   <= ST_PREP_FETCH;
                        counter <= 0;
                    end else begin
                        counter <= counter + 1'b1;
                        state   <= ST_RAM_WRITE_INIT;
                    end
                end
                
                // ST_PREP_FETCH: Calculate memory read addresses for matrix dot-product
                ST_PREP_FETCH: begin
                    r_enable_LFSR          <= 1'b0;                 
                    r_enable_new_ram       <= 1'b1;             
                    r_read_enable_new_ram  <= 1'b1;        
                    r_write_enable_new_ram <= 1'b0;    

                    r_addr_1_new_ram       <= A_taban + counter;
                    r_addr_2_new_ram       <= k + (counter * 2); 
                    
                    state                  <= ST_FETCH_COMPUTE;   
                end
                
                // ST_FETCH_COMPUTE: Perform MAC (Multiply-Accumulate) operations
                ST_FETCH_COMPUTE: begin     
                    r_enable_new_ram       <= 1'b1;            
                    r_read_enable_new_ram  <= 1'b1;  
                    r_write_enable_new_ram <= 1'b0;             
                    
                    r_S_ALU_matrix         <= 1'b0;

                    if (counter > 0) begin
                        ACC <= ACC + r_alu_out_ALU_matrix; 
                    end

                    if (counter == 4'd2) begin 
                        state   <= ST_STORE_RESULT; 
                        counter <= 0;                        
                    end else begin                       
                        counter <= counter + 1'b1;  
                        state   <= ST_PREP_FETCH;             
                    end
                end               
                
                // ST_STORE_RESULT: Add last MAC term and write result to output RAM
                ST_STORE_RESULT: begin
                    ACC            <= ACC + r_alu_out_ALU_matrix;
                    r_i_enable_ram <= 1'b1;
                    r_i_we_ram     <= 1'b1;
                    r_i_re_ram     <= 1'b0;
                    r_i_addr_ram   <= c_index;
                    state          <= ST_UPDATE_INDEX;
                end
                
                // ST_UPDATE_INDEX: Toggle column base offsets and manage loop iterations
                ST_UPDATE_INDEX: begin
                    if (k == 4'd6) begin
                        k <= 4'd7;
                    end else begin
                        k       <= 4'd6;
                        A_taban <= A_taban + 4'd3; // Shift to next row in Matrix A
                    end
                    
                    if (c_index == 2'd3) begin
                        r_i_wdata_ram <= ACC;  
                        state         <= ST_READ_PREP;
                    end else begin
                        r_i_wdata_ram <= ACC;
                        c_index       <= c_index + 1'b1;        
                        ACC           <= 0;
                        counter       <= 0;
                        state         <= ST_PREP_FETCH;
                    end
                end
                
                // ST_READ_PREP: Configure output RAM for reading accumulated elements
                ST_READ_PREP: begin
                    r_i_enable_ram <= 1'b1;  
                    r_i_we_ram     <= 1'b0;      
                    r_i_re_ram     <= 1'b1;      
                    r_i_addr_ram   <= counter; 
                    state          <= ST_READ_OUTPUT;
                end 

                // ST_READ_OUTPUT: Iterate through result RAM and stream data
                ST_READ_OUTPUT: begin
                    r_i_enable_ram <= 1'b1;
                    r_i_we_ram     <= 1'b0;
                    r_i_re_ram     <= 1 meb1;
                    
                    if (counter == 4'd3) begin
                        state   <= ST_RESTART;                     
                        counter <= 0; 
                    end else begin
                        counter <= counter + 1'b1;
                        state   <= ST_READ_PREP;
                    end
                end
                
                // ST_RESTART: Loop continuous execution
                ST_RESTART: begin
                    state <= ST_LFSR_INIT;
                end
                
                default: begin
                    state <= ST_IDLE;
                end
                
            endcase
        end
    end    

endmodule
