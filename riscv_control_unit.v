//=============================================================================
// Module: riscv_control_unit
// Description: Control Unit for RISC-V CPU - Only supports 10 required instructions
// Instructions: add, sub, or, addi, sw, lw, lui, beq, jal, jalr
//=============================================================================

`timescale 1ns/1ps

module riscv_control_unit (
    input wire [6:0]  opcode,        // Instruction opcode
    input wire [2:0]  funct3,        // Function code 3
    input wire [6:0]  funct7,        // Function code 7
    // Main control signals
    output reg        reg_write,     // Register write enable
    output reg        alu_src,       // ALU source select (0: reg, 1: imm)
    output reg [2:0]  alu_op,        // ALU operation: 0=ADD, 1=SUB, 2=OR
    output reg        mem_read,      // Memory read enable
    output reg        mem_write,     // Memory write enable
    output reg        mem_to_reg,    // Memory to register (0: ALU, 1: memory)
    output reg        pc_src,        // PC source (0: PC+4, 1: branch/jump target)
    output reg        jump,          // Jump signal (for jal/jalr)
    output reg        branch         // Branch signal (for beq)
);

    // Opcode definitions - only for 10 required instructions
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_OPIMM  = 7'b0010011;
    localparam OP_LUI    = 7'b0110111;
    localparam OP_OP     = 7'b0110011;

    // Funct3 definitions
    localparam F3_ADD_SUB = 3'b000;
    localparam F3_OR      = 3'b110;
    localparam F3_LW      = 3'b010;
    localparam F3_SW      = 3'b010;
    localparam F3_BEQ     = 3'b000;

    always @(*) begin
        // Default values
        reg_write   = 1'b0;
        alu_src     = 1'b0;
        alu_op      = 3'b000;  // ADD
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        mem_to_reg  = 1'b0;
        pc_src      = 1'b0;
        jump        = 1'b0;
        branch      = 1'b0;

        case (opcode)
            OP_LUI: begin
                // lui rd, imm - load upper immediate
                reg_write   = 1'b1;
                alu_src     = 1'b1;
                alu_op      = 3'b000;  // ADD (actually just pass imm)
                mem_to_reg  = 1'b0;
            end
            
            OP_OP: begin
                // R-type: add, sub, or
                reg_write   = 1'b1;
                alu_src     = 1'b0;
                case (funct3)
                    F3_ADD_SUB: begin
                        if (funct7 == 7'b0000000)
                            alu_op = 3'b000;  // add
                        else
                            alu_op = 3'b001;  // sub
                    end
                    F3_OR: begin
                        alu_op = 3'b010;  // or
                    end
                    default: begin
                        alu_op = 3'b000;
                    end
                endcase
            end
            
            OP_OPIMM: begin
                // I-type: addi
                reg_write   = 1'b1;
                alu_src     = 1'b1;
                alu_op      = 3'b000;  // addi
            end
            
            OP_LOAD: begin
                // lw rd, offset(rs1)
                reg_write   = 1'b1;
                alu_src     = 1'b1;
                alu_op      = 3'b000;  // ADD (calculate address)
                mem_read    = 1'b1;
                mem_to_reg  = 1'b1;
            end
            
            OP_STORE: begin
                // sw rs2, offset(rs1)
                alu_src     = 1'b1;
                alu_op      = 3'b000;  // ADD (calculate address)
                mem_write   = 1'b1;
            end
            
            OP_BRANCH: begin
                // beq rs1, rs2, offset
                branch      = 1'b1;
                alu_op      = 3'b001;  // SUB (compare by subtraction)
                if (funct3 != F3_BEQ)
                    branch = 1'b0;
            end
            
            OP_JAL: begin
                // jal rd, offset
                reg_write   = 1'b1;
                jump        = 1'b1;
                pc_src      = 1'b1;
            end
            
            OP_JALR: begin
                // jalr rd, offset(rs1)
                reg_write   = 1'b1;
                alu_src     = 1'b1;
                alu_op      = 3'b000;  // ADD (calculate target)
                jump        = 1'b1;
                pc_src      = 1'b1;
            end
            
            default: begin
                // Unknown instruction - do nothing
            end
        endcase
    end

endmodule
