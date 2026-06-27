//=============================================================================
// Module: riscv_cpu
// Description: Top-level 5-stage pipelined RISC-V CPU
// Supports only 10 required instructions: add, sub, or, addi, sw, lw, lui, beq, jal, jalr
// Features: Data forwarding, control hazard handling, load-use stall
//=============================================================================

`timescale 1ns/1ps

module riscv_cpu (
    input wire        clk,           // Clock
    input wire        rst_n          // Active-low reset
);

    // Instruction opcodes
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_OPIMM  = 7'b0010011;
    localparam OP_LUI    = 7'b0110111;
    localparam OP_OP     = 7'b0110011;

    // Immediate types
    localparam IMM_I = 3'b000;
    localparam IMM_S = 3'b001;
    localparam IMM_B = 3'b010;
    localparam IMM_U = 3'b011;
    localparam IMM_J = 3'b100;

    // Pipeline registers and internal signals
    wire [31:0] pc;
    wire [31:0] if_instr;
    wire        if_valid;
    
    wire [31:0] id_pc, id_instr;
    wire        id_valid;
    
    wire [31:0] ex_pc, ex_rs1_data, ex_rs2_data, ex_imm, ex_instr;
    wire [4:0]  ex_rs1_addr, ex_rs2_addr, ex_rd_addr;
    wire [10:0] ex_ctrl;
    wire        ex_valid;
    
    wire [31:0] mem_alu_result, mem_rs2_data, mem_pc;
    wire [4:0]  mem_rd_addr;
    wire [10:0] mem_ctrl;
    wire        mem_valid;
    
    wire [31:0] wb_mem_rdata, wb_alu_result;
    wire [4:0]  wb_rd_addr;
    wire [10:0] wb_ctrl;
    wire        wb_valid;

    // Control signals (packed as [10:0]: {jump, branch, pc_src, mem_to_reg, mem_write, mem_read, alu_src, reg_write})
    wire        reg_write, alu_src, mem_read, mem_write, mem_to_reg, pc_src, jump, branch;
    wire [2:0]  alu_op;
    wire [2:0]  imm_type;
    
    // Forwarding and hazard signals
    wire        stall_id, flush_if, flush_id;
    wire [31:0] ex_fwd_rs1, ex_fwd_rs2;
    wire        ex_zero;
    
    // ALU and memory signals
    wire [31:0] alu_result;
    wire [31:0] mem_wdata, mem_rdata;

    //=========================================================================
    // Stage 0: Instruction Fetch (IF)
    //=========================================================================
    wire [31:0] next_pc;
    wire [31:0] branch_target;
    wire [31:0] jump_target;
    
    assign next_pc = pc + 32'd4;
    
    // Calculate branch target (PC + immediate)
    assign branch_target = pc + ex_imm;
    
    // Calculate jump target based on instruction type
    wire [31:0] jalr_target;
    assign jalr_target = ex_rs1_data + ex_imm;
    assign jump_target = (id_instr[6:0] == OP_JALR) ? jalr_target : (pc + ex_imm);

    // PC update logic
    reg [31:0] pc_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc_reg <= 32'h000;
        else if (flush_if)
            pc_reg <= pc_reg;  // Hold PC during flush
        else if (jump || (branch && ex_zero))
            pc_reg <= jump_target;
        else
            pc_reg <= next_pc;
    end
    
    assign pc = pc_reg;
    assign if_valid = 1'b1;

    // Instruction memory
    riscv_instruction_memory imem (
        .addr(pc),
        .instr(if_instr)
    );

    //=========================================================================
    // Pipeline Registers
    //=========================================================================
    // Control signal packing: [10:0] = {jump, branch, pc_src, mem_to_reg, mem_write, mem_read, alu_src, reg_write}
    wire [10:0] id_ctrl;
    assign id_ctrl = {jump, branch, pc_src, mem_to_reg, mem_write, mem_read, alu_src, reg_write};
    
    // Decode immediate type based on opcode
    reg [2:0] id_imm_type;
    always @(*) begin
        case (id_instr[6:0])
            OP_OPIMM, OP_JALR, OP_LOAD: id_imm_type = IMM_I;
            OP_STORE:                   id_imm_type = IMM_S;
            OP_BRANCH:                  id_imm_type = IMM_B;
            OP_LUI:                     id_imm_type = IMM_U;
            OP_JAL:                     id_imm_type = IMM_J;
            default:                    id_imm_type = IMM_I;
        endcase
    end

    riscv_pipeline_regs pipeline_regs (
        .clk(clk),
        .rst_n(rst_n),
        // IF/ID
        .if_pc(pc),
        .if_instr(if_instr),
        .if_valid(if_valid),
        .id_pc(id_pc),
        .id_instr(id_instr),
        .id_valid(id_valid),
        // ID/EX
        .id_ex_pc(id_pc),
        .id_ex_rs1_data(ex_fwd_rs1),
        .id_ex_rs2_data(ex_fwd_rs2),
        .id_ex_rs1_addr(id_instr[19:15]),
        .id_ex_rs2_addr(id_instr[24:20]),
        .id_ex_rd_addr(id_instr[11:7]),
        .id_ex_imm(ex_imm),
        .id_ex_instr(id_instr),
        .id_ex_ctrl(id_ctrl),
        .id_ex_valid(id_valid),
        .ex_pc(ex_pc),
        .ex_rs1_data(ex_rs1_data),
        .ex_rs2_data(ex_rs2_data),
        .ex_rs1_addr(ex_rs1_addr),
        .ex_rs2_addr(ex_rs2_addr),
        .ex_rd_addr(ex_rd_addr),
        .ex_imm(ex_imm),
        .ex_instr(ex_instr),
        .ex_ctrl(ex_ctrl),
        .ex_valid(ex_valid),
        // EX/MEM
        .ex_mem_alu_result(alu_result),
        .ex_mem_rs2_data(ex_rs2_data),
        .ex_mem_rd_addr(ex_rd_addr),
        .ex_mem_pc(ex_pc),
        .ex_mem_ctrl(ex_ctrl),
        .ex_mem_valid(ex_valid),
        .mem_alu_result(mem_alu_result),
        .mem_rs2_data(mem_rs2_data),
        .mem_rd_addr(mem_rd_addr),
        .mem_pc(mem_pc),
        .mem_ctrl(mem_ctrl),
        .mem_valid(mem_valid),
        // MEM/WB
        .mem_wb_mem_rdata(mem_rdata),
        .mem_wb_alu_result(mem_alu_result),
        .mem_wb_rd_addr(mem_rd_addr),
        .mem_wb_ctrl(mem_ctrl),
        .mem_wb_valid(mem_valid),
        .wb_mem_rdata(wb_mem_rdata),
        .wb_alu_result(wb_alu_result),
        .wb_rd_addr(wb_rd_addr),
        .wb_ctrl(wb_ctrl),
        .wb_valid(wb_valid),
        // Stall and flush
        .stall_id(stall_id),
        .flush_if(flush_if),
        .flush_id(flush_id)
    );

    //=========================================================================
    // Stage 1: Instruction Decode (ID)
    //=========================================================================
    wire [31:0] rs1_data_raw, rs2_data_raw;
    wire [4:0]  id_rs1_addr, id_rs2_addr, id_rd_addr;
    
    assign id_rs1_addr = id_instr[19:15];
    assign id_rs2_addr = id_instr[24:20];
    assign id_rd_addr  = id_instr[11:7];

    // Register file
    riscv_register_file regfile (
        .clk(clk),
        .rst_n(rst_n),
        .we(wb_valid && wb_ctrl[0]),  // reg_write
        .rs1(id_rs1_addr),
        .rs2(id_rs2_addr),
        .rd(wb_rd_addr),
        .wd(wb_ctrl[3] ? wb_mem_rdata : wb_alu_result),  // mem_to_reg select
        .rd1(rs1_data_raw),
        .rd2(rs2_data_raw)
    );

    // Control unit
    riscv_control_unit ctrl_unit (
        .opcode(id_instr[6:0]),
        .funct3(id_instr[14:12]),
        .funct7(id_instr[31:25]),
        .reg_write(reg_write),
        .alu_src(alu_src),
        .alu_op(alu_op),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_to_reg(mem_to_reg),
        .pc_src(pc_src),
        .jump(jump),
        .branch(branch)
    );

    // Immediate generator
    riscv_immediate_gen imm_gen (
        .instr(id_instr),
        .imm_type(id_imm_type),
        .imm(ex_imm)
    );

    //=========================================================================
    // Forwarding Unit and Hazard Detection
    //=========================================================================
    // Unpack control signals
    wire ex_mem_jump, ex_mem_branch, ex_mem_pc_src, ex_mem_mem_to_reg, ex_mem_mem_write;
    wire ex_mem_mem_read, ex_mem_alu_src, ex_mem_reg_write;
    wire mem_wb_jump, mem_wb_branch, mem_wb_pc_src, mem_wb_mem_to_reg, mem_wb_mem_write;
    wire mem_wb_mem_read, mem_wb_alu_src, mem_wb_reg_write;
    
    assign {ex_mem_jump, ex_mem_branch, ex_mem_pc_src, ex_mem_mem_to_reg, ex_mem_mem_write, ex_mem_mem_read, ex_mem_alu_src, ex_mem_reg_write} = ex_ctrl;
    assign {mem_wb_jump, mem_wb_branch, mem_wb_pc_src, mem_wb_mem_to_reg, mem_wb_mem_write, mem_wb_mem_read, mem_wb_alu_src, mem_wb_reg_write} = wb_ctrl;

    // Forwarding logic
    wire fwd_ex_rs1, fwd_ex_rs2, fwd_mem_rs1, fwd_mem_rs2;
    
    // Forward from EX stage
    assign fwd_ex_rs1 = ex_valid && ex_mem_reg_write && (ex_rd_addr != 5'b0) && (ex_rd_addr == ex_rs1_addr);
    assign fwd_ex_rs2 = ex_valid && ex_mem_reg_write && (ex_rd_addr != 5'b0) && (ex_rd_addr == ex_rs2_addr);
    
    // Forward from MEM stage
    assign fwd_mem_rs1 = mem_valid && mem_wb_reg_write && (mem_rd_addr != 5'b0) && (mem_rd_addr == ex_rs1_addr);
    assign fwd_mem_rs2 = mem_valid && mem_wb_reg_write && (mem_rd_addr != 5'b0) && (mem_rd_addr == ex_rs2_addr);

    // Select forwarded data
    assign ex_fwd_rs1 = fwd_ex_rs1 ? alu_result : (fwd_mem_rs1 ? (mem_wb_mem_to_reg ? mem_rdata : mem_alu_result) : rs1_data_raw);
    assign ex_fwd_rs2 = fwd_ex_rs2 ? alu_result : (fwd_mem_rs2 ? (mem_wb_mem_to_reg ? mem_rdata : mem_alu_result) : rs2_data_raw);

    // Load-use hazard detection
    wire load_use_hazard;
    assign load_use_hazard = ex_valid && ex_mem_mem_read && 
                            ((ex_rd_addr == id_rs1_addr) || (ex_rd_addr == id_rs2_addr));

    assign stall_id = load_use_hazard;
    assign flush_id = load_use_hazard;
    assign flush_if = load_use_hazard || jump || (branch && ex_zero);

    //=========================================================================
    // Stage 2: Execute (EX)
    //=========================================================================
    wire [31:0] alu_a, alu_b;
    
    // ALU input selection
    assign alu_a = ex_rs1_data;
    assign alu_b = ex_ctrl[2] ? ex_imm : ex_rs2_data;  // alu_src

    // ALU
    riscv_alu alu (
        .a(alu_a),
        .b(alu_b),
        .alu_op(ex_ctrl[7:5]),  // alu_op
        .result(alu_result),
        .zero(ex_zero)
    );

    //=========================================================================
    // Stage 3: Memory (MEM)
    //=========================================================================
    assign mem_wdata = mem_rs2_data;
    
    // Data memory
    riscv_data_memory dmem (
        .clk(clk),
        .addr(32'h400 + mem_alu_result[9:0]),
        .wdata(mem_wdata),
        .we(mem_ctrl[4]),  // mem_write
        .mem_read(mem_ctrl[3]),
        .mem_write(mem_ctrl[4]),
        .rdata(mem_rdata)
    );

    //=========================================================================
    // Stage 4: Write Back (WB)
    //=========================================================================
    // Write back is handled in the pipeline register to register file

endmodule
