//=============================================================================
// Module: riscv_instruction_memory
// Description: Instruction Memory (1KB, addresses 0x000-0x3ff)
// Features: Little Endian storage, read-only during execution
//=============================================================================

`timescale 1ns/1ps

module riscv_instruction_memory (
    input wire [31:0] addr,          // Address (byte-aligned)
    output reg [31:0] instr          // Instruction output
);

    // 1KB = 256 words (4 bytes each)
    reg [31:0] memory [0:255];

    // Initialize with some default instructions (can be overridden in testbench)
    initial begin
        // Default: all zeros (nop-like)
        integer i;
        for (i = 0; i < 256; i = i + 1)
            memory[i] <= 32'b0;
    end

    // Read instruction (addr[9:2] selects word, since addr is byte-aligned)
    always @(*) begin
        if (addr[31:10] == 22'b0)  // Valid address range
            instr = memory[addr[9:2]];
        else
            instr = 32'b0;
    end

    // Task for testbench to load instructions
    task load_instruction;
        input [9:0] word_addr;
        input [31:0] data;
        begin
            memory[word_addr] = data;
        end
    endtask

endmodule
