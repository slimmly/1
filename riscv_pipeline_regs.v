//=============================================================================
// Module: riscv_pipeline_regs
// Description: Pipeline registers for 5-stage RISC-V CPU
// Includes: IF/ID, ID/EX, EX/MEM, MEM/WB registers
//=============================================================================

`timescale 1ns/1ps

module riscv_pipeline_regs (
    input wire        clk,
    input wire        rst_n,
    
    // IF/ID stage signals
    input wire [31:0] if_pc,
    input wire [31:0] if_instr,
    input wire        if_valid,
    output reg [31:0] id_pc,
    output reg [31:0] id_instr,
    output reg        id_valid,
    
    // ID/EX stage signals
    input wire [31:0] id_ex_pc,
    input wire [31:0] id_ex_rs1_data,
    input wire [31:0] id_ex_rs2_data,
    input wire [4:0]  id_ex_rs1_addr,
    input wire [4:0]  id_ex_rs2_addr,
    input wire [4:0]  id_ex_rd_addr,
    input wire [31:0] id_ex_imm,
    input wire [31:0] id_ex_instr,
    input wire [10:0] id_ex_ctrl,      // Control signals
    input wire        id_ex_valid,
    output reg [31:0] ex_pc,
    output reg [31:0] ex_rs1_data,
    output reg [31:0] ex_rs2_data,
    output reg [4:0]  ex_rs1_addr,
    output reg [4:0]  ex_rs2_addr,
    output reg [4:0]  ex_rd_addr,
    output reg [31:0] ex_imm,
    output reg [31:0] ex_instr,
    output reg [10:0] ex_ctrl,
    output reg        ex_valid,
    
    // EX/MEM stage signals
    input wire [31:0] ex_mem_alu_result,
    input wire [31:0] ex_mem_rs2_data,
    input wire [4:0]  ex_mem_rd_addr,
    input wire [31:0] ex_mem_pc,
    input wire [10:0] ex_mem_ctrl,
    input wire        ex_mem_valid,
    output reg [31:0] mem_alu_result,
    output reg [31:0] mem_rs2_data,
    output reg [4:0]  mem_rd_addr,
    output reg [31:0] mem_pc,
    output reg [10:0] mem_ctrl,
    output reg        mem_valid,
    
    // MEM/WB stage signals
    input wire [31:0] mem_wb_mem_rdata,
    input wire [31:0] mem_wb_alu_result,
    input wire [4:0]  mem_wb_rd_addr,
    input wire [10:0] mem_wb_ctrl,
    input wire        mem_wb_valid,
    output reg [31:0] wb_mem_rdata,
    output reg [31:0] wb_alu_result,
    output reg [4:0]  wb_rd_addr,
    output reg [10:0] wb_ctrl,
    output reg        wb_valid,
    
    // Stall and flush signals
    input wire        stall_id,      // Stall ID/EX register
    input wire        flush_if,      // Flush IF/ID register
    input wire        flush_id       // Flush ID/EX register
);

    // IF/ID Pipeline Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_pc     <= 32'b0;
            id_instr  <= 32'b0;
            id_valid  <= 1'b0;
        end else if (flush_if) begin
            id_pc     <= 32'b0;
            id_instr  <= 32'b0;
            id_valid  <= 1'b0;
        end else if (!stall_id && if_valid) begin
            id_pc     <= if_pc;
            id_instr  <= if_instr;
            id_valid  <= 1'b1;
        end else if (!stall_id) begin
            id_valid  <= 1'b0;
        end
    end

    // ID/EX Pipeline Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_pc        <= 32'b0;
            ex_rs1_data  <= 32'b0;
            ex_rs2_data  <= 32'b0;
            ex_rs1_addr  <= 5'b0;
            ex_rs2_addr  <= 5'b0;
            ex_rd_addr   <= 5'b0;
            ex_imm       <= 32'b0;
            ex_instr     <= 32'b0;
            ex_ctrl      <= 11'b0;
            ex_valid     <= 1'b0;
        end else if (flush_id) begin
            ex_pc        <= 32'b0;
            ex_rs1_data  <= 32'b0;
            ex_rs2_data  <= 32'b0;
            ex_rs1_addr  <= 5'b0;
            ex_rs2_addr  <= 5'b0;
            ex_rd_addr   <= 5'b0;
            ex_imm       <= 32'b0;
            ex_instr     <= 32'b0;
            ex_ctrl      <= 11'b0;
            ex_valid     <= 1'b0;
        end else if (!stall_id && id_ex_valid) begin
            ex_pc        <= id_ex_pc;
            ex_rs1_data  <= id_ex_rs1_data;
            ex_rs2_data  <= id_ex_rs2_data;
            ex_rs1_addr  <= id_ex_rs1_addr;
            ex_rs2_addr  <= id_ex_rs2_addr;
            ex_rd_addr   <= id_ex_rd_addr;
            ex_imm       <= id_ex_imm;
            ex_instr     <= id_ex_instr;
            ex_ctrl      <= id_ex_ctrl;
            ex_valid     <= 1'b1;
        end else if (!stall_id) begin
            ex_valid     <= 1'b0;
        end
    end

    // EX/MEM Pipeline Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_alu_result <= 32'b0;
            mem_rs2_data   <= 32'b0;
            mem_rd_addr    <= 5'b0;
            mem_pc         <= 32'b0;
            mem_ctrl       <= 11'b0;
            mem_valid      <= 1'b0;
        end else if (ex_mem_valid) begin
            mem_alu_result <= ex_mem_alu_result;
            mem_rs2_data   <= ex_mem_rs2_data;
            mem_rd_addr    <= ex_mem_rd_addr;
            mem_pc         <= ex_mem_pc;
            mem_ctrl       <= ex_mem_ctrl;
            mem_valid      <= 1'b1;
        end else begin
            mem_valid      <= 1'b0;
        end
    end

    // MEM/WB Pipeline Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_mem_rdata  <= 32'b0;
            wb_alu_result <= 32'b0;
            wb_rd_addr    <= 5'b0;
            wb_ctrl       <= 11'b0;
            wb_valid      <= 1'b0;
        end else if (mem_wb_valid) begin
            wb_mem_rdata  <= mem_wb_mem_rdata;
            wb_alu_result <= mem_wb_alu_result;
            wb_rd_addr    <= mem_wb_rd_addr;
            wb_ctrl       <= mem_wb_ctrl;
            wb_valid      <= 1'b1;
        end else begin
            wb_valid      <= 1'b0;
        end
    end

endmodule
