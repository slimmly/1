//=============================================================================
// Module: riscv_control_unit
// Description: Control Unit for RISC-V CPU
// Generates control signals for all pipeline stages based on opcode and funct3/funct7
//=============================================================================

`timescale 1ns/1ps

module riscv_control_unit (
    input wire [6:0]  opcode,        // Instruction opcode
    input wire [2:0]  funct3,        // Function code 3
    input wire [6:0]  funct7,        // Function code 7
    // Main control signals
    output reg        reg_write,     // Register write enable
    output reg        alu_src,       // ALU source select (0: reg, 1: imm)
    output reg [3:0]  alu_op,        // ALU operation
    output reg        mem_read,      // Memory read enable
    output reg        mem_write,     // Memory write enable
    output reg        mem_to_reg,    // Memory to register (0: ALU, 1: memory)
    output reg        pc_src,        // PC source (0: PC+4, 1: branch target)
    output reg        jump,          // Jump signal (for jal/jalr)
    output reg        branch,        // Branch signal (for beq/bne)
    output reg [1:0]  imm_src,       // Immediate source selector
    output wire       zero_flag_en   // Enable zero flag for branch
);

    // Opcode definitions
    localparam OP_LUI    = 7'b0110111;
    localparam OP_AUIPC  = 7'b0010111;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_OPIMM  = 7'b0010011;
    localparam OP_OP     = 7'b0110011;

    // Funct3 definitions
    localparam F3_ADD_SUB = 3'b000;
    localparam F3_SLL     = 3'b001;
    localparam F3_SLT     = 3'b010;
    localparam F3_SLTU    = 3'b011;
    localparam F3_XOR     = 3'b100;
    localparam F3_SR      = 3'b101;
    localparam F3_OR      = 3'b110;
    localparam F3_AND     = 3'b111;
    localparam F3_BEQ     = 3'b000;
    localparam F3_BNE     = 3'b001;
    localparam F3_LB      = 3'b000;
    localparam F3_LH      = 3'b001;
    localparam F3_LW      = 3'b010;
    localparam F3_SB      = 3'b000;
    localparam F3_SH      = 3'b001;
    localparam F3_SW      = 3'b010;

    // ALU operation codes (must match riscv_alu.v)
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLT  = 4'b0101;
    localparam ALU_SLTU = 4'b0110;
    localparam ALU_SLL  = 4'b0111;
    localparam ALU_SRL  = 4'b1000;
    localparam ALU_SRA  = 4'b1001;
    localparam ALU_PASS = 4'b1010;

    assign zero_flag_en = branch;

    always @(*) begin
        // Default values
        reg_write   = 1'b0;
        alu_src     = 1'b0;
        alu_op      = ALU_ADD;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        mem_to_reg  = 1'b0;
        pc_src      = 1'b0;
        jump        = 1'b0;
        branch      = 1'b0;
        imm_src     = 2'b00;

        case (opcode)
            OP_LUI: begin
                // LUI: rd = imm[31:12] << 12
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                alu_op     = ALU_PASS;
                imm_src    = 2'b11;  // U-type immediate
            end

            OP_JAL: begin
                // JAL: rd = PC+4, PC = PC + imm
                reg_write  = 1'b1;
                jump       = 1'b1;
                pc_src     = 1'b1;
                imm_src    = 2'b10;  // J-type immediate
            end

            OP_JALR: begin
                // JALR: rd = PC+4, PC = (rs1 + imm) & ~1
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                alu_op     = ALU_ADD;
                jump       = 1'b1;
                pc_src     = 1'b1;
                imm_src    = 2'b00;  // I-type immediate
            end

            OP_BRANCH: begin
                // BEQ: if (rs1 == rs2) PC = PC + imm
                branch     = 1'b1;
                alu_src    = 1'b0;
                alu_op     = ALU_SUB;
                pc_src     = 1'b1;
                imm_src    = 2'b01;  // B-type immediate
                // pc_src is actually controlled by branch condition
            end

            OP_LOAD: begin
                // LW: rd = MEM[rs1 + imm]
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                alu_op     = ALU_ADD;
                mem_read   = 1'b1;
                mem_to_reg = 1'b1;
                imm_src    = 2'b00;  // I-type immediate
            end

            OP_STORE: begin
                // SW: MEM[rs1 + imm] = rs2
                alu_src    = 1'b1;
                alu_op     = ALU_ADD;
                mem_write  = 1'b1;
                imm_src    = 2'b01;  // S-type immediate
            end

            OP_OPIMM: begin
                // Immediate arithmetic/logic operations
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                imm_src    = 2'b00;  // I-type immediate
                case (funct3)
                    F3_ADD_SUB: alu_op = ALU_ADD;
                    F3_XOR:     alu_op = ALU_XOR;
                    F3_OR:      alu_op = ALU_OR;
                    F3_AND:     alu_op = ALU_AND;
                    F3_SLT:     alu_op = ALU_SLT;
                    F3_SLTU:    alu_op = ALU_SLTU;
                    default:    alu_op = ALU_ADD;
                endcase
            end

            OP_OP: begin
                // Register-register arithmetic/logic operations
                reg_write  = 1'b1;
                alu_src    = 1'b0;
                imm_src    = 2'b00;
                case (funct3)
                    F3_ADD_SUB: begin
                        if (funct7 == 7'b0000000)
                            alu_op = ALU_ADD;
                        else if (funct7 == 7'b0100000)
                            alu_op = ALU_SUB;
                        else
                            alu_op = ALU_ADD;
                    end
                    F3_SLL:     alu_op = ALU_SLL;
                    F3_SLT:     alu_op = ALU_SLT;
                    F3_SLTU:    alu_op = ALU_SLTU;
                    F3_XOR:     alu_op = ALU_XOR;
                    F3_SR: begin
                        if (funct7 == 7'b0000000)
                            alu_op = ALU_SRL;
                        else if (funct7 == 7'b0100000)
                            alu_op = ALU_SRA;
                        else
                            alu_op = ALU_SRL;
                    end
                    F3_OR:      alu_op = ALU_OR;
                    F3_AND:     alu_op = ALU_AND;
                    default:    alu_op = ALU_ADD;
                endcase
            end

            default: begin
                // Unknown instruction - do nothing
            end
        endcase
    end

endmodule
