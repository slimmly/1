//=============================================================================
// Module: riscv_pipeline_regs
// Description: Pipeline Registers for 5-stage RISC-V CPU
// Includes: IF/ID, ID/EX, EX/MEM, MEM/WB registers
//=============================================================================

`timescale 1ns/1ps

module riscv_pipeline_regs (
    input wire        clk,
    input wire        rst_n,
    
    // IF/ID Register
    input wire [31:0] if_id_pc_in,
    input wire [31:0] if_id_instr_in,
    output reg [31:0] if_id_pc_out,
    output reg [31:0] if_id_instr_out,
    
    // ID/EX Register
    input wire [31:0] id_ex_pc_in,
    input wire [31:0] id_ex_rs1_data_in,
    input wire [31:0] id_ex_rs2_data_in,
    input wire [31:0] id_ex_imm_in,
    input wire [4:0]  id_ex_rd_in,
    input wire [4:0]  id_ex_rs1_in,
    input wire [4:0]  id_ex_rs2_in,
    input wire        id_ex_reg_write_in,
    input wire        id_ex_alu_src_in,
    input wire [3:0]  id_ex_alu_op_in,
    input wire        id_ex_mem_read_in,
    input wire        id_ex_mem_write_in,
    input wire        id_ex_mem_to_reg_in,
    input wire        id_ex_branch_in,
    input wire        id_ex_jump_in,
    input wire [1:0]  id_ex_funct3_in,
    output reg [31:0] id_ex_pc_out,
    output reg [31:0] id_ex_rs1_data_out,
    output reg [31:0] id_ex_rs2_data_out,
    output reg [31:0] id_ex_imm_out,
    output reg [4:0]  id_ex_rd_out,
    output reg [4:0]  id_ex_rs1_out,
    output reg [4:0]  id_ex_rs2_out,
    output reg        id_ex_reg_write_out,
    output reg        id_ex_alu_src_out,
    output reg [3:0]  id_ex_alu_op_out,
    output reg        id_ex_mem_read_out,
    output reg        id_ex_mem_write_out,
    output reg        id_ex_mem_to_reg_out,
    output reg        id_ex_branch_out,
    output reg        id_ex_jump_out,
    output reg [1:0]  id_ex_funct3_out,
    
    // EX/MEM Register
    input wire [31:0] ex_mem_pc_in,
    input wire [31:0] ex_mem_alu_result_in,
    input wire [31:0] ex_mem_rs2_data_in,
    input wire [4:0]  ex_mem_rd_in,
    input wire        ex_mem_reg_write_in,
    input wire        ex_mem_mem_read_in,
    input wire        ex_mem_mem_write_in,
    input wire        ex_mem_mem_to_reg_in,
    input wire        ex_mem_branch_in,
    input wire        ex_mem_jump_in,
    input wire        ex_mem_zero_in,
    input wire [1:0]  ex_mem_funct3_in,
    output reg [31:0] ex_mem_pc_out,
    output reg [31:0] ex_mem_alu_result_out,
    output reg [31:0] ex_mem_rs2_data_out,
    output reg [4:0]  ex_mem_rd_out,
    output reg        ex_mem_reg_write_out,
    output reg        ex_mem_mem_read_out,
    output reg        ex_mem_mem_write_out,
    output reg        ex_mem_mem_to_reg_out,
    output reg        ex_mem_branch_out,
    output reg        ex_mem_jump_out,
    output reg        ex_mem_zero_out,
    output reg [1:0]  ex_mem_funct3_out,
    
    // MEM/WB Register
    input wire [31:0] mem_wb_alu_result_in,
    input wire [31:0] mem_wb_mem_data_in,
    input wire [4:0]  mem_wb_rd_in,
    input wire        mem_wb_reg_write_in,
    input wire        mem_wb_mem_to_reg_in,
    output reg [31:0] mem_wb_alu_result_out,
    output reg [31:0] mem_wb_mem_data_out,
    output reg [4:0]  mem_wb_rd_out,
    output reg        mem_wb_reg_write_out,
    output reg        mem_wb_mem_to_reg_out,
    
    // Control signals for flushing
    input wire        flush_if_id,
    input wire        flush_id_ex,
    input wire        flush_ex_mem,
    input wire        flush_mem_wb
);

    // IF/ID Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_pc_out   <= 32'b0;
            if_id_instr_out <= 32'b0;
        end else if (flush_if_id) begin
            if_id_pc_out   <= 32'b0;
            if_id_instr_out <= 32'b0;
        end else begin
            if_id_pc_out   <= if_id_pc_in;
            if_id_instr_out <= if_id_instr_in;
        end
    end

    // ID/EX Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex_pc_out          <= 32'b0;
            id_ex_rs1_data_out    <= 32'b0;
            id_ex_rs2_data_out    <= 32'b0;
            id_ex_imm_out         <= 32'b0;
            id_ex_rd_out          <= 5'b0;
            id_ex_rs1_out         <= 5'b0;
            id_ex_rs2_out         <= 5'b0;
            id_ex_reg_write_out   <= 1'b0;
            id_ex_alu_src_out     <= 1'b0;
            id_ex_alu_op_out      <= 4'b0;
            id_ex_mem_read_out    <= 1'b0;
            id_ex_mem_write_out   <= 1'b0;
            id_ex_mem_to_reg_out  <= 1'b0;
            id_ex_branch_out      <= 1'b0;
            id_ex_jump_out        <= 1'b0;
            id_ex_funct3_out      <= 2'b0;
        end else if (flush_id_ex) begin
            id_ex_pc_out          <= 32'b0;
            id_ex_rs1_data_out    <= 32'b0;
            id_ex_rs2_data_out    <= 32'b0;
            id_ex_imm_out         <= 32'b0;
            id_ex_rd_out          <= 5'b0;
            id_ex_rs1_out         <= 5'b0;
            id_ex_rs2_out         <= 5'b0;
            id_ex_reg_write_out   <= 1'b0;
            id_ex_alu_src_out     <= 1'b0;
            id_ex_alu_op_out      <= 4'b0;
            id_ex_mem_read_out    <= 1'b0;
            id_ex_mem_write_out   <= 1'b0;
            id_ex_mem_to_reg_out  <= 1'b0;
            id_ex_branch_out      <= 1'b0;
            id_ex_jump_out        <= 1'b0;
            id_ex_funct3_out      <= 2'b0;
        end else begin
            id_ex_pc_out          <= id_ex_pc_in;
            id_ex_rs1_data_out    <= id_ex_rs1_data_in;
            id_ex_rs2_data_out    <= id_ex_rs2_data_in;
            id_ex_imm_out         <= id_ex_imm_in;
            id_ex_rd_out          <= id_ex_rd_in;
            id_ex_rs1_out         <= id_ex_rs1_in;
            id_ex_rs2_out         <= id_ex_rs2_in;
            id_ex_reg_write_out   <= id_ex_reg_write_in;
            id_ex_alu_src_out     <= id_ex_alu_src_in;
            id_ex_alu_op_out      <= id_ex_alu_op_in;
            id_ex_mem_read_out    <= id_ex_mem_read_in;
            id_ex_mem_write_out   <= id_ex_mem_write_in;
            id_ex_mem_to_reg_out  <= id_ex_mem_to_reg_in;
            id_ex_branch_out      <= id_ex_branch_in;
            id_ex_jump_out        <= id_ex_jump_in;
            id_ex_funct3_out      <= id_ex_funct3_in;
        end
    end

    // EX/MEM Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_pc_out         <= 32'b0;
            ex_mem_alu_result_out <= 32'b0;
            ex_mem_rs2_data_out   <= 32'b0;
            ex_mem_rd_out         <= 5'b0;
            ex_mem_reg_write_out  <= 1'b0;
            ex_mem_mem_read_out   <= 1'b0;
            ex_mem_mem_write_out  <= 1'b0;
            ex_mem_mem_to_reg_out <= 1'b0;
            ex_mem_branch_out     <= 1'b0;
            ex_mem_jump_out       <= 1'b0;
            ex_mem_zero_out       <= 1'b0;
            ex_mem_funct3_out     <= 2'b0;
        end else if (flush_ex_mem) begin
            ex_mem_pc_out         <= 32'b0;
            ex_mem_alu_result_out <= 32'b0;
            ex_mem_rs2_data_out   <= 32'b0;
            ex_mem_rd_out         <= 5'b0;
            ex_mem_reg_write_out  <= 1'b0;
            ex_mem_mem_read_out   <= 1'b0;
            ex_mem_mem_write_out  <= 1'b0;
            ex_mem_mem_to_reg_out <= 1'b0;
            ex_mem_branch_out     <= 1'b0;
            ex_mem_jump_out       <= 1'b0;
            ex_mem_zero_out       <= 1'b0;
            ex_mem_funct3_out     <= 2'b0;
        end else begin
            ex_mem_pc_out         <= ex_mem_pc_in;
            ex_mem_alu_result_out <= ex_mem_alu_result_in;
            ex_mem_rs2_data_out   <= ex_mem_rs2_data_in;
            ex_mem_rd_out         <= ex_mem_rd_in;
            ex_mem_reg_write_out  <= ex_mem_reg_write_in;
            ex_mem_mem_read_out   <= ex_mem_mem_read_in;
            ex_mem_mem_write_out  <= ex_mem_mem_write_in;
            ex_mem_mem_to_reg_out <= ex_mem_mem_to_reg_in;
            ex_mem_branch_out     <= ex_mem_branch_in;
            ex_mem_jump_out       <= ex_mem_jump_in;
            ex_mem_zero_out       <= ex_mem_zero_in;
            ex_mem_funct3_out     <= ex_mem_funct3_in;
        end
    end

    // MEM/WB Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_alu_result_out  <= 32'b0;
            mem_wb_mem_data_out    <= 32'b0;
            mem_wb_rd_out          <= 5'b0;
            mem_wb_reg_write_out   <= 1'b0;
            mem_wb_mem_to_reg_out  <= 1'b0;
        end else if (flush_mem_wb) begin
            mem_wb_alu_result_out  <= 32'b0;
            mem_wb_mem_data_out    <= 32'b0;
            mem_wb_rd_out          <= 5'b0;
            mem_wb_reg_write_out   <= 1'b0;
            mem_wb_mem_to_reg_out  <= 1'b0;
        end else begin
            mem_wb_alu_result_out  <= mem_wb_alu_result_in;
            mem_wb_mem_data_out    <= mem_wb_mem_data_in;
            mem_wb_rd_out          <= mem_wb_rd_in;
            mem_wb_reg_write_out   <= mem_wb_reg_write_in;
            mem_wb_mem_to_reg_out  <= mem_wb_mem_to_reg_in;
        end
    end

endmodule
