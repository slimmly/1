//=============================================================================
// Module: riscv_instruction_memory
// Description: Instruction Memory (1KB, addresses 0x000-0x3ff)
// Features: Little Endian storage, synchronous read
//=============================================================================

`timescale 1ns/1ps

module riscv_instruction_memory (
    input wire [31:0] addr,          // Address (byte address)
    output reg [31:0] instr          // Instruction output
);

    // 1KB = 256 words (4 bytes each), 8-bit address for word access
    reg [31:0] mem [0:255];
    wire [7:0] word_addr;

    // Convert byte address to word address
    assign word_addr = addr[9:2];

    // Synchronous read
    always @(*) begin
        if (word_addr < 256)
            instr = mem[word_addr];
        else
            instr = 32'b0;
    end

    // Function to load instruction (for testbench)
    function void load_instr(input [7:0] addr, input [31:0] value);
        mem[addr] = value;
    endfunction
    
    // Make memory accessible for testbench
    function [31:0] get_instr(input [7:0] addr);
        get_instr = mem[addr];
    endfunction

endmodule
