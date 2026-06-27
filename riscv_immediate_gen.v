//=============================================================================
// Module: riscv_immediate_gen
// Description: Immediate generator for RISC-V instructions
// Supports: I-type, S-type, B-type, U-type, J-type immediates
//=============================================================================

`timescale 1ns/1ps

module riscv_immediate_gen (
    input wire [31:0] instr,         // Instruction
    input wire [2:0]  imm_type,      // Immediate type: 0=I, 1=S, 2=B, 3=U, 4=J
    output reg [31:0] imm            // Generated immediate (sign-extended)
);

    // Immediate type codes
    localparam IMM_I = 3'b000;
    localparam IMM_S = 3'b001;
    localparam IMM_B = 3'b010;
    localparam IMM_U = 3'b011;
    localparam IMM_J = 3'b100;

    always @(*) begin
        case (imm_type)
            // I-type: imm[11:0] = instr[31:20]
            IMM_I: imm = {{20{instr[31]}}, instr[31:20]};

            // S-type: imm[11:0] = {instr[31:25], instr[11:7]}
            IMM_S: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};

            // B-type: imm[12:0] = {instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}
            IMM_B: imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};

            // U-type: imm[31:12] = instr[31:12], imm[11:0] = 12'b0
            IMM_U: imm = {instr[31:12], 12'b0};

            // J-type: imm[20:0] = {instr[31], instr[19:12], instr[20], instr[30:21], 1'b0}
            IMM_J: imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

            default: imm = 32'b0;
        endcase
    end

endmodule
