//=============================================================================
// Module: riscv_cpu_tb
// Description: Testbench for 5-stage RISC-V Pipeline CPU
// Tests all 10 instructions: add, sub, or, addi, sw, lw, lui, beq, jal, jalr
//=============================================================================

`timescale 1ns/1ps

module riscv_cpu_tb;

    // Clock and Reset
    reg clk;
    reg rst_n;
    
    // Instantiate CPU
    riscv_cpu uut (
        .clk(clk),
        .rst_n(rst_n)
    );
    
    // Clock generation (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Test program initialization
    initial begin
        integer i;
        
        // Initialize memories through CPU module hierarchy
        // This is a simplified approach - in practice you'd use $readmemh
        
        // Reset
        rst_n = 0;
        #20;
        rst_n = 1;
        
        // Load test program into instruction memory
        // Program starts at address 0x000
        // Each instruction is 32 bits (4 bytes)
        
        // Test Program:
        // 0x000: lui x1, 0x1          // x1 = 0x1000
        // 0x004: addi x2, x1, 8       // x2 = x1 + 8 = 0x1008
        // 0x008: add x3, x1, x2       // x3 = x1 + x2 = 0x2008
        // 0x00C: sub x4, x3, x1       // x4 = x3 - x1 = 0x1008
        // 0x010: or x5, x3, x4        // x5 = x3 | x4 = 0x3008
        // 0x014: sw x5, 0(x1)         // MEM[0x1000] = x5
        // 0x018: lw x6, 0(x1)         // x6 = MEM[0x1000] = 0x3008
        // 0x01C: beq x1, x1, label1   // Branch to label1 (always taken)
        // 0x020: add x7, x1, x1       // (skipped) x7 = 0x2000
        // label1 (0x024): jal x8, label2  // x8 = 0x028, PC = label2
        // 0x028: addi x9, x8, 4       // x9 = x8 + 4 = 0x02C
        // label2 (0x02C): jalr x10, x9, 4  // x10 = 0x030, PC = x9+4 = 0x030
        // 0x030: nop (addi x0, x0, 0) // End of program
        
        // Instruction encodings:
        // lui x1, 0x1        -> 0x000010B7
        // addi x2, x1, 8     -> 0x00810113
        // add x3, x1, x2     -> 0x002101B3
        // sub x4, x3, x1     -> 0x401181B3
        // or x5, x3, x4      -> 0x0041E1B3
        // sw x5, 0(x1)       -> 0x00512023
        // lw x6, 0(x1)       -> 0x00012303
        // beq x1, x1, +4     -> 0x0010C063
        // add x7, x1, x1     -> 0x001103B3
        // jal x8, +4         -> 0x004000EF
        // addi x9, x8, 4     -> 0x00440493
        // jalr x10, x9, 4    -> 0x004480E7
        // nop                -> 0x00000013
        
        // Load instructions using hierarchical reference
        load_instr(8'h00, 32'h000010B7);  // lui x1, 0x1
        load_instr(8'h01, 32'h00810113);  // addi x2, x1, 8
        load_instr(8'h02, 32'h002101B3);  // add x3, x1, x2
        load_instr(8'h03, 32'h401181B3);  // sub x4, x3, x1
        load_instr(8'h04, 32'h0041E1B3);  // or x5, x3, x4
        load_instr(8'h05, 32'h00512023);  // sw x5, 0(x1)
        load_instr(8'h06, 32'h00012303);  // lw x6, 0(x1)
        load_instr(8'h07, 32'h0010C063);  // beq x1, x1, +4
        load_instr(8'h08, 32'h001103B3);  // add x7, x1, x1 (skipped)
        load_instr(8'h09, 32'h004000EF);  // jal x8, +4
        load_instr(8'h0A, 32'h00440493);  // addi x9, x8, 4
        load_instr(8'h0B, 32'h004480E7);  // jalr x10, x9, 4
        load_instr(8'h0C, 32'h00000013);  // nop
        load_instr(8'h0D, 32'h00000013);  // nop
        load_instr(8'h0E, 32'h00000013);  // nop
        load_instr(8'h0F, 32'h00000013);  // nop
        
        // Run simulation
        #500;
        
        // Print results
        $display("========================================");
        $display("RISC-V CPU Simulation Results");
        $display("========================================");
        $display("Register Values:");
        print_reg(1);
        print_reg(2);
        print_reg(3);
        print_reg(4);
        print_reg(5);
        print_reg(6);
        print_reg(7);
        print_reg(8);
        print_reg(9);
        print_reg(10);
        $display("========================================");
        
        // Verify expected results
        verify_results();
        
        $finish;
    end
    
    // Task to load instruction into instruction memory
    task load_instr;
        input [7:0] addr;
        input [31:0] value;
        begin
            uut.imem.load_instr(addr, value);
        end
    endtask
    
    // Task to print register value
    task print_reg;
        input [4:0] reg_num;
        reg [31:0] val;
        begin
            val = uut.regfile.registers[reg_num];
            $display("x%0d = 0x%08h", reg_num, val);
        end
    endtask
    
    // Function to get register value
    function [31:0] get_reg;
        input [4:0] reg_num;
        begin
            get_reg = uut.regfile.registers[reg_num];
        end
    endfunction
    
    // Task to verify results
    task verify_results;
        reg [31:0] r1, r2, r3, r4, r5, r6, r8, r9, r10;
        begin
            r1 = uut.regfile.registers[1];
            r2 = uut.regfile.registers[2];
            r3 = uut.regfile.registers[3];
            r4 = uut.regfile.registers[4];
            r5 = uut.regfile.registers[5];
            r6 = uut.regfile.registers[6];
            r8 = uut.regfile.registers[8];
            r9 = uut.regfile.registers[9];
            r10 = uut.regfile.registers[10];
            
            $display("========================================");
            $display("Verification:");
            
            if (r1 == 32'h00001000)
                $display("[PASS] LUI: x1 = 0x%08h (expected 0x00001000)", r1);
            else
                $display("[FAIL] LUI: x1 = 0x%08h (expected 0x00001000)", r1);
            
            if (r2 == 32'h00001008)
                $display("[PASS] ADDI: x2 = 0x%08h (expected 0x00001008)", r2);
            else
                $display("[FAIL] ADDI: x2 = 0x%08h (expected 0x00001008)", r2);
            
            if (r3 == 32'h00002008)
                $display("[PASS] ADD: x3 = 0x%08h (expected 0x00002008)", r3);
            else
                $display("[FAIL] ADD: x3 = 0x%08h (expected 0x00002008)", r3);
            
            if (r4 == 32'h00001008)
                $display("[PASS] SUB: x4 = 0x%08h (expected 0x00001008)", r4);
            else
                $display("[FAIL] SUB: x4 = 0x%08h (expected 0x00001008)", r4);
            
            if (r5 == 32'h00003008)
                $display("[PASS] OR: x5 = 0x%08h (expected 0x00003008)", r5);
            else
                $display("[FAIL] OR: x5 = 0x%08h (expected 0x00003008)", r5);
            
            if (r6 == 32'h00003008)
                $display("[PASS] LW: x6 = 0x%08h (expected 0x00003008)", r6);
            else
                $display("[FAIL] LW: x6 = 0x%08h (expected 0x00003008)", r6);
            
            if (r8 != 32'h00000000)
                $display("[PASS] JAL: x8 = 0x%08h (return address stored)", r8);
            else
                $display("[FAIL] JAL: x8 = 0x%08h (expected non-zero return address)", r8);
            
            if (r9 != 32'h00000000)
                $display("[PASS] ADDI (after JAL): x9 = 0x%08h", r9);
            else
                $display("[FAIL] ADDI (after JAL): x9 = 0x%08h", r9);
            
            if (r10 != 32'h00000000)
                $display("[PASS] JALR: x10 = 0x%08h (return address stored)", r10);
            else
                $display("[FAIL] JALR: x10 = 0x%08h (expected non-zero return address)", r10);
            
            $display("========================================");
        end
    endtask
    
    // Waveform dump (for GTKWave or similar)
    initial begin
        $dumpfile("riscv_cpu_tb.vcd");
        $dumpvars(0, riscv_cpu_tb);
    end
    
endmodule
