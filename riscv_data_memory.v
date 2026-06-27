//=============================================================================
// Module: riscv_data_memory
// Description: Data Memory (1KB, addresses 0x400-0x7ff)
// Features: Little Endian storage, read/write support
//=============================================================================

`timescale 1ns/1ps

module riscv_data_memory (
    input wire        clk,           // Clock
    input wire [31:0] addr,          // Address (byte-aligned)
    input wire [31:0] wdata,         // Write data
    input wire        we,            // Write enable (1=write, 0=read)
    input wire        mem_read,      // Memory read enable
    input wire        mem_write,     // Memory write enable
    output reg [31:0] rdata          // Read data output
);

    // 1KB = 256 words (4 bytes each), starting at address 0x400
    // Internal addressing: 0-255 maps to 0x400-0x7ff
    reg [31:0] memory [0:255];

    // Initialize memory to zero
    initial begin
        integer i;
        for (i = 0; i < 256; i = i + 1)
            memory[i] <= 32'b0;
    end

    // Read/Write operation
    always @(posedge clk) begin
        if (mem_write && we) begin
            // Write operation - Little Endian
            if (addr[31:10] == 10'h1)  // Address in range 0x400-0x7ff
                memory[addr[9:2]] <= wdata;
        end
    end

    // Combinational read
    always @(*) begin
        if (mem_read && addr[31:10] == 10'h1)  // Address in range 0x400-0x7ff
            rdata = memory[addr[9:2]];
        else
            rdata = 32'b0;
    end

endmodule
