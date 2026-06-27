//=============================================================================
// Module: riscv_register_file
// Description: 32-bit Register File with 32 registers (x0-x31)
// Features: x0 is hardwired to 0, 2 read ports, 1 write port
//=============================================================================

`timescale 1ns/1ps

module riscv_register_file (
    input wire        clk,           // Clock
    input wire        rst_n,         // Active-low reset
    input wire        we,            // Write enable
    input wire [4:0]  rs1,           // Read register 1 address
    input wire [4:0]  rs2,           // Read register 2 address
    input wire [4:0]  rd,            // Write register address
    input wire [31:0] wd,            // Write data
    output reg [31:0] rd1,           // Read data 1
    output reg [31:0] rd2            // Read data 2
);

    // 32 registers, each 32 bits
    reg [31:0] registers [0:31];
    integer i;
    
    // Make registers accessible for testbench
    wire [31:0] register_out [0:31];
    generate
        genvar g;
        for (g = 0; g < 32; g = g + 1) begin
            assign register_out[g] = registers[g];
        end
    endgenerate

    // Initialize registers on reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'b0;
            end
        end else if (we && rd != 5'b0) begin
            // x0 is hardwired to 0, never write to it
            registers[rd] <= wd;
        end
    end

    // Combinational read
    always @(*) begin
        rd1 = registers[rs1];
        rd2 = registers[rs2];
        // x0 always returns 0
        if (rs1 == 5'b0) rd1 = 32'b0;
        if (rs2 == 5'b0) rd2 = 32'b0;
    end

endmodule
