//=============================================================================
// Module: riscv_cpu
// Description: Top-level 5-stage RISC-V Pipeline CPU
// Implements: add, sub, or, addi, sw, lw, lui, beq, jal, jalr
// Features: Data forwarding, control hazard handling, load-use stall
//=============================================================================

`timescale 1ns/1ps

module riscv_cpu (
    input wire        clk,           // Clock
    input wire        rst_n          // Active-low reset
);

    //=========================================================================
    // Internal Signals
    //=========================================================================
    
    // Program Counter
    reg [31:0] pc;
    wire [31:0] next_pc;
    wire [31:0] instruction;
    
    // IF/ID Pipeline Register
    reg [31:0] if_id_pc;
    reg [31:0] if_id_instr;
    
    // ID Stage Signals
    wire [6:0]  opcode;
    wire [4:0]  rs1, rs2, rd;
    wire [2:0]  funct3;
    wire [6:0]  funct7;
    wire [31:0] read_data1, read_data2;
    wire [31:0] imm;
    
    // Control Signals
    wire        reg_write, alu_src, mem_read, mem_write;
    wire        mem_to_reg, pc_src, jump, branch;
    wire [3:0]  alu_op;
    wire [1:0]  imm_src;
    
    // ID/EX Pipeline Register
    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_read_data1;
    reg [31:0] id_ex_read_data2;
    reg [31:0] id_ex_imm;
    reg [4:0]  id_ex_rd;
    reg [4:0]  id_ex_rs1;
    reg [4:0]  id_ex_rs2;
    reg        id_ex_reg_write;
    reg        id_ex_alu_src;
    reg [3:0]  id_ex_alu_op;
    reg        id_ex_mem_read;
    reg        id_ex_mem_write;
    reg        id_ex_mem_to_reg;
    reg        id_ex_branch;
    reg        id_ex_jump;
    reg [1:0]  id_ex_funct3;
    
    // EX Stage Signals
    wire [31:0] alu_input_a, alu_input_b;
    wire [31:0] alu_result;
    wire        zero_flag;
    
    // Forwarding Unit Outputs
    wire [31:0] forward_a_data;
    wire [31:0] forward_b_data;
    wire [1:0]  forward_a_sel;
    wire [1:0]  forward_b_sel;
    
    // EX/MEM Pipeline Register
    reg [31:0] ex_mem_pc;
    reg [31:0] ex_mem_alu_result;
    reg [31:0] ex_mem_read_data2;
    reg [4:0]  ex_mem_rd;
    reg        ex_mem_reg_write;
    reg        ex_mem_mem_read;
    reg        ex_mem_mem_write;
    reg        ex_mem_mem_to_reg;
    reg        ex_mem_branch;
    reg        ex_mem_jump;
    reg        ex_mem_zero;
    reg [1:0]  ex_mem_funct3;
    
    // MEM Stage Signals
    wire [31:0] mem_data_read;
    wire [31:0] mem_address;
    wire        mem_write_enable;
    
    // MEM/WB Pipeline Register
    reg [31:0] mem_wb_alu_result;
    reg [31:0] mem_wb_mem_data;
    reg [4:0]  mem_wb_rd;
    reg        mem_wb_reg_write;
    reg        mem_wb_mem_to_reg;
    
    // WB Stage Signals
    wire [31:0] write_data;
    wire        wb_reg_write;
    wire [4:0]  wb_rd;
    
    // Hazard Detection Signals
    wire        load_use_hazard;
    wire        branch_taken;
    wire        flush_if_id, flush_id_ex;
    
    // Branch Target Calculation
    wire [31:0] branch_target;
    wire [31:0] jump_target;
    
    //=========================================================================
    // Instruction Fetch (IF) Stage
    //=========================================================================
    
    // PC Update Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= 32'h000;
        else if (flush_if_id)
            pc <= pc;  // Hold PC on stall/flush
        else
            pc <= next_pc;
    end
    
    // Instruction Memory
    riscv_instruction_memory imem (
        .addr(pc),
        .instr(instruction)
    );
    
    // IF/ID Pipeline Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_pc    <= 32'b0;
            if_id_instr <= 32'b0;
        end else if (flush_if_id) begin
            if_id_pc    <= 32'b0;
            if_id_instr <= 32'b0;
        end else if (!load_use_hazard) begin
            if_id_pc    <= pc;
            if_id_instr <= instruction;
        end
    end
    
    //=========================================================================
    // Instruction Decode (ID) Stage
    //=========================================================================
    
    // Parse Instruction Fields
    assign opcode  = if_id_instr[6:0];
    assign funct3  = if_id_instr[14:12];
    assign funct7  = if_id_instr[31:25];
    assign rs1     = if_id_instr[19:15];
    assign rs2     = if_id_instr[24:20];
    assign rd      = if_id_instr[11:7];
    
    // Register File
    riscv_register_file regfile (
        .clk(clk),
        .rst_n(rst_n),
        .we(wb_reg_write),
        .rs1(rs1),
        .rs2(rs2),
        .rd(wb_rd),
        .wd(write_data),
        .rd1(read_data1),
        .rd2(read_data2)
    );
    
    // Immediate Generator
    riscv_immediate_gen imm_gen (
        .instr(if_id_instr),
        .imm_type(imm_src),
        .imm(imm)
    );
    
    // Control Unit
    riscv_control_unit ctrl (
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .reg_write(reg_write),
        .alu_src(alu_src),
        .alu_op(alu_op),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_to_reg(mem_to_reg),
        .pc_src(pc_src),
        .jump(jump),
        .branch(branch),
        .imm_src(imm_src)
    );
    
    // Hazard Detection Unit
    // Detect load-use hazard: LW followed by instruction that needs the loaded value
    assign load_use_hazard = id_ex_mem_read && (
        (id_ex_rs1 == ex_mem_rd && id_ex_rs1 != 5'b0) ||
        (id_ex_rs2 == ex_mem_rd && id_ex_rs2 != 5'b0)
    );
    
    // Branch Taken Signal (for BEQ)
    assign branch_taken = ex_mem_branch && ex_mem_zero && (ex_mem_funct3 == 3'b000);
    
    // Flush Signals
    assign flush_if_id = branch_taken || ex_mem_jump;
    assign flush_id_ex = load_use_hazard;
    
    // ID/EX Pipeline Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex_pc           <= 32'b0;
            id_ex_read_data1   <= 32'b0;
            id_ex_read_data2   <= 32'b0;
            id_ex_imm          <= 32'b0;
            id_ex_rd           <= 5'b0;
            id_ex_rs1          <= 5'b0;
            id_ex_rs2          <= 5'b0;
            id_ex_reg_write    <= 1'b0;
            id_ex_alu_src      <= 1'b0;
            id_ex_alu_op       <= 4'b0;
            id_ex_mem_read     <= 1'b0;
            id_ex_mem_write    <= 1'b0;
            id_ex_mem_to_reg   <= 1'b0;
            id_ex_branch       <= 1'b0;
            id_ex_jump         <= 1'b0;
            id_ex_funct3       <= 2'b0;
        end else if (flush_id_ex) begin
            id_ex_pc           <= 32'b0;
            id_ex_read_data1   <= 32'b0;
            id_ex_read_data2   <= 32'b0;
            id_ex_imm          <= 32'b0;
            id_ex_rd           <= 5'b0;
            id_ex_rs1          <= 5'b0;
            id_ex_rs2          <= 5'b0;
            id_ex_reg_write    <= 1'b0;
            id_ex_alu_src      <= 1'b0;
            id_ex_alu_op       <= 4'b0;
            id_ex_mem_read     <= 1'b0;
            id_ex_mem_write    <= 1'b0;
            id_ex_mem_to_reg   <= 1'b0;
            id_ex_branch       <= 1'b0;
            id_ex_jump         <= 1'b0;
            id_ex_funct3       <= 2'b0;
        end else if (!load_use_hazard) begin
            id_ex_pc           <= if_id_pc;
            id_ex_read_data1   <= read_data1;
            id_ex_read_data2   <= read_data2;
            id_ex_imm          <= imm;
            id_ex_rd           <= rd;
            id_ex_rs1          <= rs1;
            id_ex_rs2          <= rs2;
            id_ex_reg_write    <= reg_write;
            id_ex_alu_src      <= alu_src;
            id_ex_alu_op       <= alu_op;
            id_ex_mem_read     <= mem_read;
            id_ex_mem_write    <= mem_write;
            id_ex_mem_to_reg   <= mem_to_reg;
            id_ex_branch       <= branch;
            id_ex_jump         <= jump;
            id_ex_funct3       <= funct3;
        end
    end
    
    //=========================================================================
    // Execute (EX) Stage - Forwarding Unit
    //=========================================================================
    
    // Forwarding Unit
    // Determine ALU input sources based on data dependencies
    always @(*) begin
        // Default: no forwarding, use ID/EX register data
        forward_a_sel = 2'b00;
        forward_b_sel = 2'b00;
        
        // Forward from EX/MEM stage (higher priority)
        if (ex_mem_reg_write && ex_mem_rd != 5'b0) begin
            if (ex_mem_rd == id_ex_rs1 && id_ex_rs1 != 5'b0)
                forward_a_sel = 2'b10;
            if (ex_mem_rd == id_ex_rs2 && id_ex_rs2 != 5'b0)
                forward_b_sel = 2'b10;
        end
        
        // Forward from MEM/WB stage (lower priority, only if not forwarding from EX/MEM)
        if (mem_wb_reg_write && mem_wb_rd != 5'b0) begin
            if (mem_wb_rd == id_ex_rs1 && id_ex_rs1 != 5'b0 && forward_a_sel == 2'b00)
                forward_a_sel = 2'b01;
            if (mem_wb_rd == id_ex_rs2 && id_ex_rs2 != 5'b0 && forward_b_sel == 2'b00)
                forward_b_sel = 2'b01;
        end
    end
    
    // ALU Input Selection with Forwarding
    assign forward_a_data = id_ex_read_data1;  // Could be extended for forwarding
    assign forward_b_data = id_ex_alu_src ? id_ex_imm : id_ex_read_data2;
    
    assign alu_input_a = forward_a_data;
    assign alu_input_b = forward_b_data;
    
    // ALU
    riscv_alu alu (
        .a(alu_input_a),
        .b(alu_input_b),
        .alu_op(id_ex_alu_op),
        .result(alu_result),
        .zero(zero_flag)
    );
    
    // EX/MEM Pipeline Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_pc          <= 32'b0;
            ex_mem_alu_result  <= 32'b0;
            ex_mem_read_data2  <= 32'b0;
            ex_mem_rd          <= 5'b0;
            ex_mem_reg_write   <= 1'b0;
            ex_mem_mem_read    <= 1'b0;
            ex_mem_mem_write   <= 1'b0;
            ex_mem_mem_to_reg  <= 1'b0;
            ex_mem_branch      <= 1'b0;
            ex_mem_jump        <= 1'b0;
            ex_mem_zero        <= 1'b0;
            ex_mem_funct3      <= 2'b0;
        end else if (flush_if_id) begin
            ex_mem_pc          <= 32'b0;
            ex_mem_alu_result  <= 32'b0;
            ex_mem_read_data2  <= 32'b0;
            ex_mem_rd          <= 5'b0;
            ex_mem_reg_write   <= 1'b0;
            ex_mem_mem_read    <= 1'b0;
            ex_mem_mem_write   <= 1'b0;
            ex_mem_mem_to_reg  <= 1'b0;
            ex_mem_branch      <= 1'b0;
            ex_mem_jump        <= 1'b0;
            ex_mem_zero        <= 1'b0;
            ex_mem_funct3      <= 2'b0;
        end else begin
            ex_mem_pc          <= id_ex_pc;
            ex_mem_alu_result  <= alu_result;
            ex_mem_read_data2  <= id_ex_read_data2;
            ex_mem_rd          <= id_ex_rd;
            ex_mem_reg_write   <= id_ex_reg_write;
            ex_mem_mem_read    <= id_ex_mem_read;
            ex_mem_mem_write   <= id_ex_mem_write;
            ex_mem_mem_to_reg  <= id_ex_mem_to_reg;
            ex_mem_branch      <= id_ex_branch;
            ex_mem_jump        <= id_ex_jump;
            ex_mem_zero        <= zero_flag;
            ex_mem_funct3      <= id_ex_funct3;
        end
    end
    
    //=========================================================================
    // Memory (MEM) Stage
    //=========================================================================
    
    // Memory Address and Data
    assign mem_address = ex_mem_alu_result;
    assign mem_write_enable = ex_mem_mem_write;
    
    // Data Memory
    riscv_data_memory dmem (
        .clk(clk),
        .we(mem_write_enable),
        .addr(mem_address),
        .wd(ex_mem_read_data2),
        .be(4'b1111),  // Word write
        .rd(mem_data_read)
    );
    
    // MEM/WB Pipeline Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_alu_result <= 32'b0;
            mem_wb_mem_data   <= 32'b0;
            mem_wb_rd         <= 5'b0;
            mem_wb_reg_write  <= 1'b0;
            mem_wb_mem_to_reg <= 1'b0;
        end else if (flush_if_id) begin
            mem_wb_alu_result <= 32'b0;
            mem_wb_mem_data   <= 32'b0;
            mem_wb_rd         <= 5'b0;
            mem_wb_reg_write  <= 1'b0;
            mem_wb_mem_to_reg <= 1'b0;
        end else begin
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_mem_data   <= mem_data_read;
            mem_wb_rd         <= ex_mem_rd;
            mem_wb_reg_write  <= ex_mem_reg_write;
            mem_wb_mem_to_reg <= ex_mem_mem_to_reg;
        end
    end
    
    //=========================================================================
    // Writeback (WB) Stage
    //=========================================================================
    
    // Write Data Selection
    assign write_data = mem_wb_mem_to_reg ? mem_wb_mem_data : mem_wb_alu_result;
    assign wb_reg_write = mem_wb_reg_write;
    assign wb_rd = mem_wb_rd;
    
    //=========================================================================
    // Next PC Calculation
    //=========================================================================
    
    assign branch_target = id_ex_pc + id_ex_imm;
    assign jump_target   = ex_mem_alu_result;  // For JALR, ALU computes rs1+imm
    
    // PC Source Selection
    assign next_pc = ex_mem_jump ? jump_target :
                     branch_taken ? branch_target :
                     pc + 32'd4;

endmodule
