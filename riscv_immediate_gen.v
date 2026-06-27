//=============================================================================
// Module: riscv_immediate_gen
// Description: Immediate Generator for RISC-V CPU
// Supports I-type, S-type, B-type, U-type, J-type immediates
//=============================================================================

`timescale 1ns/1ps

module riscv_immediate_gen (
    input wire [31:0] instr,         // Instruction
    input wire [1:0]  imm_type,      // Immediate type selector
    output reg [31:0] imm            // Generated immediate
);

    // Immediate type selectors (must match control unit)
    localparam IMM_I = 2'b00;
    localparam IMM_S = 2'b01;
    localparam IMM_J = 2'b10;
    localparam IMM_U = 2'b11;

    always @(*) begin
        case (imm_type)
            IMM_I: begin
                // I-type: imm[11:0] = instr[31:20]
                imm = {{20{instr[31]}}, instr[31:20]};
            end

            IMM_S: begin
                // S-type: imm[11:0] = {instr[31:25], instr[11:7]}
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            end

            IMM_B: begin
                // B-type: imm[12:1] = {instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}
                // Note: This case is handled by IMM_S in control (same bit positions)
                // But we need to handle the sign extension differently
                imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
            end

            IMM_J: begin
                // J-type: imm[20:1] = {instr[31], instr[19:12], instr[20], instr[30:21], 1'b0}
                imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
            end

            IMM_U: begin
                // U-type: imm[31:12] = instr[31:12]
                imm = {instr[31:12], 12'b0};
            end

            default: begin
                imm = 32'b0;
            end
        endcase
    end

endmodule
