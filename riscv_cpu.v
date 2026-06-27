//=============================================================================
// Module: riscv_cpu
// Description: 32-bit RISC-V 5-stage Pipeline CPU
// Supports 10 instructions: add, sub, or, addi, sw, lw, lui, beq, jal, jalr
// Features: Data forwarding, Control hazard handling
//=============================================================================

`timescale 1ns/1ps

module riscv_cpu (
    input wire clk,
    input wire rst_n
);

    // Instruction opcodes
    localparam OP_LUI    = 7'b0110111;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_OPIMM  = 7'b0010011;
    localparam OP_OP     = 7'b0110011;

    // Pipeline registers
    // IF/ID
    reg [31:0] if_id_instr;
    reg [31:0] if_id_pc;
    wire if_id_stall, if_id_flush;
    
    // ID/EX
    reg [31:0] id_ex_instr;
    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_rd1, id_ex_rd2;
    reg [4:0]  id_ex_rs1, id_ex_rs2, id_ex_rd;
    reg [31:0] id_ex_imm;
    reg        id_ex_reg_write, id_ex_mem_read, id_ex_mem_write, id_ex_mem_to_reg;
    reg [2:0]  id_ex_alu_op;
    reg        id_ex_jump, id_ex_branch;
    
    // EX/MEM
    reg [31:0] ex_mem_alu_result;
    reg [31:0] ex_mem_rd2;
    reg [4:0]  ex_mem_rd;
    reg        ex_mem_reg_write, ex_mem_mem_read, ex_mem_mem_write, ex_mem_mem_to_reg;
    reg        ex_mem_jump, ex_mem_branch;
    reg [31:0] ex_mem_pc;
    
    // MEM/WB
    reg [31:0] mem_wb_mem_data;
    reg [31:0] mem_wb_alu_result;
    reg [4:0]  mem_wb_rd;
    reg        mem_wb_reg_write, mem_wb_mem_to_reg;

    // PC
    reg [31:0] pc;
    wire [31:0] pc_next;
    wire pc_jump, pc_branch;
    reg [31:0] jump_target;
    wire [31:0] branch_target;

    // Hazard signals
    wire data_hazard, load_use_hazard;
    wire control_hazard;
    wire [31:0] forward_a, forward_b;

    // Instruction memory (simplified - just a register for now)
    reg [31:0] instr_mem [0:255];  // 256 instructions = 1KB
    wire [31:0] fetched_instr;
    
    // Data memory
    reg [7:0] data_mem [0:255];  // 256 bytes = 256B (simplified)
    wire [31:0] mem_data_out;
    reg mem_read_en, mem_write_en;
    reg [31:0] mem_addr, mem_data_in;
    reg [3:0]  mem_byte_enable;

    // Control signals from instruction decode
    wire ctrl_reg_write, ctrl_alu_src, ctrl_mem_read, ctrl_mem_write;
    wire ctrl_mem_to_reg, ctrl_pc_src, ctrl_jump, ctrl_branch;
    wire [2:0] ctrl_alu_op;

    //=========================================================================
    // IF Stage: Instruction Fetch
    //=========================================================================
    assign fetched_instr = if_id_flush ? 32'b0 : instr_mem[pc[9:2]];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= 32'b0;
        else if (!if_id_stall) begin
            if (pc_jump || pc_branch)
                pc <= pc_next;
            else
                pc <= pc + 32'd4;
        end
    end
    
    // Branch target calculation
    assign branch_target = if_id_pc + {{19{id_ex_imm[31]}}, id_ex_imm[31:1], 1'b0};
    
    // PC next logic
    assign pc_next = pc_jump ? jump_target : (pc_branch ? branch_target : pc + 32'd4);
    assign pc_jump = ex_mem_jump | mem_wb_reg_write & (mem_wb_rd != 5'b0) & ex_mem_jump;
    assign pc_branch = control_hazard;

    // IF/ID pipeline register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_instr <= 32'b0;
            if_id_pc <= 32'b0;
        end else if (if_id_flush) begin
            if_id_instr <= 32'b0;
            if_id_pc <= if_id_pc;
        end else if (!if_id_stall) begin
            if_id_instr <= fetched_instr;
            if_id_pc <= pc;
        end
    end

    //=========================================================================
    // ID Stage: Instruction Decode
    //=========================================================================
    wire [6:0] id_opcode = if_id_instr[6:0];
    wire [4:0] id_rs1 = if_id_instr[19:15];
    wire [4:0] id_rs2 = if_id_instr[24:20];
    wire [4:0] id_rd = if_id_instr[11:7];
    wire [2:0] id_funct3 = if_id_instr[14:12];
    wire [6:0] id_funct7 = if_id_instr[31:25];
    
    // Immediate generation
    wire [31:0] id_imm;
    generate_immediate u_imm_gen (
        .instr(if_id_instr),
        .opcode(id_opcode),
        .imm(id_imm)
    );

    // Register file read
    riscv_register_file u_regfile (
        .clk(clk),
        .rst_n(rst_n),
        .we(id_ex_reg_write && !data_hazard),
        .rs1(id_rs1),
        .rs2(id_rs2),
        .rd(id_ex_rd),
        .wd(mem_wb_reg_write ? (mem_wb_mem_to_reg ? mem_wb_mem_data : mem_wb_alu_result) : 32'b0),
        .rd1(id_ex_rd1),
        .rd2(id_ex_rd2)
    );

    // Control unit
    riscv_control_unit u_control (
        .opcode(id_opcode),
        .funct3(id_funct3),
        .funct7(id_funct7),
        .reg_write(id_ex_reg_write),
        .alu_src(ctrl_alu_src),
        .alu_op(ctrl_alu_op),
        .mem_read(id_ex_mem_read),
        .mem_write(id_ex_mem_write),
        .mem_to_reg(id_ex_mem_to_reg),
        .pc_src(ctrl_pc_src),
        .jump(id_ex_jump),
        .branch(id_ex_branch)
    );

    // Forwarding logic
    assign forward_a = (ex_mem_reg_write && ex_mem_rd != 5'b0 && ex_mem_rd == id_ex_rs1) ? ex_mem_alu_result :
                       (mem_wb_reg_write && mem_wb_rd != 5'b0 && mem_wb_rd == id_ex_rs1) ? 
                           (mem_wb_mem_to_reg ? mem_wb_mem_data : mem_wb_alu_result) : id_ex_rd1;
    
    assign forward_b = (ex_mem_reg_write && ex_mem_rd != 5'b0 && ex_mem_rd == id_ex_rs2) ? ex_mem_alu_result :
                       (mem_wb_reg_write && mem_wb_rd != 5'b0 && mem_wb_rd == id_ex_rs2) ? 
                           (mem_wb_mem_to_reg ? mem_wb_mem_data : mem_wb_alu_result) : id_ex_rd2;

    // Hazard detection
    assign data_hazard = (id_ex_rs1 != 5'b0 && id_ex_rs1 == ex_mem_rd && ex_mem_reg_write) ||
                         (id_ex_rs2 != 5'b0 && id_ex_rs2 == ex_mem_rd && ex_mem_reg_write);
    
    assign load_use_hazard = id_ex_mem_read && (
        (id_ex_rs1 != 5'b0 && id_ex_rs1 == ex_mem_rd && ex_mem_reg_write) ||
        (id_ex_rs2 != 5'b0 && id_ex_rs2 == ex_mem_rd && ex_mem_reg_write));
    
    assign if_id_stall = load_use_hazard;
    assign if_id_flush = control_hazard;
    assign control_hazard = id_ex_branch;

    // ID/EX pipeline register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex_instr <= 32'b0;
            id_ex_pc <= 32'b0;
            id_ex_rd1 <= 32'b0;
            id_ex_rd2 <= 32'b0;
            id_ex_rs1 <= 5'b0;
            id_ex_rs2 <= 5'b0;
            id_ex_rd <= 5'b0;
            id_ex_imm <= 32'b0;
            id_ex_reg_write <= 1'b0;
            id_ex_mem_read <= 1'b0;
            id_ex_mem_write <= 1'b0;
            id_ex_mem_to_reg <= 1'b0;
            id_ex_alu_op <= 3'b0;
            id_ex_jump <= 1'b0;
            id_ex_branch <= 1'b0;
        end else if (if_id_flush) begin
            id_ex_instr <= 32'b0;
            id_ex_reg_write <= 1'b0;
            id_ex_mem_write <= 1'b0;
            id_ex_branch <= 1'b0;
            id_ex_jump <= 1'b0;
        end else if (!if_id_stall) begin
            id_ex_instr <= if_id_instr;
            id_ex_pc <= if_id_pc;
            id_ex_rd1 <= forward_a;
            id_ex_rd2 <= forward_b;
            id_ex_rs1 <= id_rs1;
            id_ex_rs2 <= id_rs2;
            id_ex_rd <= id_rd;
            id_ex_imm <= id_imm;
            id_ex_reg_write <= ctrl_reg_write;
            id_ex_mem_read <= ctrl_mem_read;
            id_ex_mem_write <= ctrl_mem_write;
            id_ex_mem_to_reg <= ctrl_mem_to_reg;
            id_ex_alu_op <= ctrl_alu_op;
            id_ex_jump <= ctrl_jump;
            id_ex_branch <= ctrl_pc_src;
        end
    end

    //=========================================================================
    // EX Stage: Execute
    //=========================================================================
    wire [31:0] alu_input_b = id_ex_alu_src ? id_ex_imm : id_ex_rd2;
    wire [31:0] alu_result;
    wire alu_zero;
    
    riscv_alu u_alu (
        .a(id_ex_rd1),
        .b(alu_input_b),
        .alu_op(id_ex_alu_op),
        .result(alu_result),
        .zero(alu_zero)
    );

    // Jump target calculation
    always @(*) begin
        case (id_ex_instr[6:0])
            OP_JAL:  jump_target = id_ex_pc + id_ex_imm;
            OP_JALR: jump_target = (id_ex_rd1 + id_ex_imm) & ~32'b1;
            default: jump_target = id_ex_pc + id_ex_imm;
        endcase
    end

    // EX/MEM pipeline register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_alu_result <= 32'b0;
            ex_mem_rd2 <= 32'b0;
            ex_mem_rd <= 5'b0;
            ex_mem_reg_write <= 1'b0;
            ex_mem_mem_read <= 1'b0;
            ex_mem_mem_write <= 1'b0;
            ex_mem_mem_to_reg <= 1'b0;
            ex_mem_jump <= 1'b0;
            ex_mem_branch <= 1'b0;
            ex_mem_pc <= 32'b0;
        end else begin
            ex_mem_alu_result <= alu_result;
            ex_mem_rd2 <= id_ex_rd2;
            ex_mem_rd <= id_ex_rd;
            ex_mem_reg_write <= id_ex_reg_write;
            ex_mem_mem_read <= id_ex_mem_read;
            ex_mem_mem_write <= id_ex_mem_write;
            ex_mem_mem_to_reg <= id_ex_mem_to_reg;
            ex_mem_jump <= id_ex_jump;
            ex_mem_branch <= id_ex_branch;
            ex_mem_pc <= id_ex_pc;
        end
    end

    //=========================================================================
    // MEM Stage: Memory Access
    //=========================================================================
    // Data memory access
    assign mem_addr = ex_mem_alu_result;
    assign mem_data_in = ex_mem_rd2;
    assign mem_read_en = ex_mem_mem_read;
    assign mem_write_en = ex_mem_mem_write;
    
    // Simple byte-addressable memory with little-endian
    always @(posedge clk) begin
        if (mem_write_en) begin
            data_mem[mem_addr[7:0]] <= mem_data_in[7:0];
            data_mem[mem_addr[7:0]+1] <= mem_data_in[15:8];
            data_mem[mem_addr[7:0]+2] <= mem_data_in[23:16];
            data_mem[mem_addr[7:0]+3] <= mem_data_in[31:24];
        end
    end
    
    assign mem_wb_mem_data = {data_mem[mem_addr[7:0]+3], data_mem[mem_addr[7:0]+2], 
                               data_mem[mem_addr[7:0]+1], data_mem[mem_addr[7:0]]};

    // MEM/WB pipeline register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_mem_data <= 32'b0;
            mem_wb_alu_result <= 32'b0;
            mem_wb_rd <= 5'b0;
            mem_wb_reg_write <= 1'b0;
            mem_wb_mem_to_reg <= 1'b0;
        end else begin
            mem_wb_mem_data <= mem_wb_mem_data;
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_rd <= ex_mem_rd;
            mem_wb_reg_write <= ex_mem_reg_write;
            mem_wb_mem_to_reg <= ex_mem_mem_to_reg;
        end
    end

    //=========================================================================
    // WB Stage: Write Back
    //=========================================================================
    // Write back is handled in the register file

endmodule

//=============================================================================
// Module: generate_immediate
// Description: Generate immediate values for different instruction types
//=============================================================================

module generate_immediate (
    input wire [31:0] instr,
    input wire [6:0]  opcode,
    output reg [31:0] imm
);

    localparam OP_LUI    = 7'b0110111;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_OPIMM  = 7'b0010011;

    always @(*) begin
        case (opcode)
            OP_LUI:
                imm = {instr[31:12], 12'b0};  // U-type
            
            OP_JAL: begin
                // J-type: imm[20|10:1|11|19:12]
                imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
            end
            
            OP_JALR, OP_LOAD, OP_OPIMM: begin
                // I-type: imm[11:0]
                imm = {{20{instr[31]}}, instr[31:20]};
            end
            
            OP_BRANCH: begin
                // B-type: imm[12|10:5|4|11|31]
                imm = {{19{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
            end
            
            OP_STORE: begin
                // S-type: imm[11:5|4:0]
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            end
            
            default:
                imm = 32'b0;
        endcase
    end

endmodule
