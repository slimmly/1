//=============================================================================
// Module: riscv_alu
// Description: 32-bit ALU for RISC-V CPU - Only supports the 10 required instructions
// Operations: ADD, SUB, OR
//=============================================================================

`timescale 1ns/1ps

module riscv_alu (
    input wire [31:0] a,           // First operand
    input wire [31:0] b,           // Second operand
    input wire [2:0]  alu_op,      // ALU operation code: 0=ADD, 1=SUB, 2=OR
    output reg [31:0] result,      // ALU result
    output wire       zero         // Zero flag (result == 0)
);

    // ALU operation codes - only for the 10 required instructions
    localparam ALU_ADD  = 3'b000;
    localparam ALU_SUB  = 3'b001;
    localparam ALU_OR   = 3'b010;

    assign zero = (result == 32'b0);

    always @(*) begin
        case (alu_op)
            ALU_ADD:  result = a + b;
            ALU_SUB:  result = a - b;
            ALU_OR:   result = a | b;
            default:  result = a + b;
        endcase
    end

endmodule
