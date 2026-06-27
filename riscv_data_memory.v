//=============================================================================
// Module: riscv_data_memory
// Description: Data Memory (1KB, addresses 0x400-0x7ff)
// Features: Little Endian storage, synchronous read/write, byte enable
//=============================================================================

`timescale 1ns/1ps

module riscv_data_memory (
    input wire        clk,           // Clock
    input wire        we,            // Write enable
    input wire [31:0] addr,          // Address (byte address)
    input wire [31:0] wd,            // Write data
    input wire [3:0]  be,            // Byte enable (for word write)
    output reg [31:0] rd             // Read data
);

    // 1KB = 256 words (4 bytes each), addresses 0x400-0x7ff
    // Internal word address: 0-255 (maps to 0x400-0x7ff)
    reg [31:0] mem [0:255];
    wire [7:0] word_addr;
    wire [1:0] byte_offset;

    // Convert byte address to word address and byte offset
    assign word_addr   = addr[9:2];
    assign byte_offset = addr[1:0];

    // Synchronous write
    always @(posedge clk) begin
        if (we && word_addr < 256) begin
            // Word write (all bytes enabled)
            if (&be) begin
                mem[word_addr] <= wd;
            end else begin
                // Byte-level write (Little Endian)
                if (be[0]) mem[word_addr][7:0]   <= wd[7:0];
                if (be[1]) mem[word_addr][15:8]  <= wd[15:8];
                if (be[2]) mem[word_addr][23:16] <= wd[23:16];
                if (be[3]) mem[word_addr][31:24] <= wd[31:24];
            end
        end
    end

    // Synchronous read
    always @(posedge clk) begin
        if (word_addr < 256)
            rd <= mem[word_addr];
        else
            rd <= 32'b0;
    end

    // Function to load data (for testbench)
    function void load_data(input [7:0] addr, input [31:0] value);
        mem[addr] = value;
    endfunction
    
    // Make memory accessible for testbench
    function [31:0] get_data(input [7:0] addr);
        get_data = mem[addr];
    endfunction

endmodule
