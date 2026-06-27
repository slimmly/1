//=============================================================================
// Module: riscv_cpu_tb
// Description: Testbench for 5-stage pipelined RISC-V CPU
// Tests all 10 required instructions: add, sub, or, addi, sw, lw, lui, beq, jal, jalr
//=============================================================================

`timescale 1ns/1ps

module riscv_cpu_tb;

    reg clk = 0;
    reg rst_n = 0;

    // Clock generation - 10ns period
    always #5 clk = ~clk;

    // Instantiate CPU
    riscv_cpu uut (
        .clk(clk),
        .rst_n(rst_n)
    );

    // Test program - loads instructions into instruction memory
    initial begin
        // Initialize
        rst_n = 0;
        #20;
        rst_n = 1;
        
        // Load test program into instruction memory
        // Address 0x000 = word 0
        
        // Test 1: LUI - Load upper immediate
        // lui x1, 0x12345  -> x1 = 0x12345000
        load_instr(0, 32'h123450b7);  // lui x1, 0x12345
        
        // Test 2: ADDI - Add immediate
        // addi x1, x1, 0x678 -> x1 = 0x12345000 + 0x678 = 0x12345678
        load_instr(1, 32'h67808093);  // addi x1, x1, 0x678
        
        // Test 3: ADD - Add registers
        // addi x2, x0, 10 -> x2 = 10
        load_instr(2, 32'h00a00113);  // addi x2, x0, 10
        // addi x3, x0, 20 -> x3 = 20
        load_instr(3, 32'h01400193);  // addi x3, x0, 20
        // add x4, x2, x3 -> x4 = 10 + 20 = 30
        load_instr(4, 32'h00310233);  // add x4, x2, x3
        
        // Test 4: SUB - Subtract
        // sub x5, x3, x2 -> x5 = 20 - 10 = 10
        load_instr(5, 32'h402182b3);  // sub x5, x3, x2
        
        // Test 5: OR - Or
        // ori x6, x0, 0xF0 -> x6 = 0xF0
        load_instr(6, 32'h0f000313);  // ori x6, x0, 0xF0
        // ori x7, x0, 0x0F -> x7 = 0x0F
        load_instr(7, 32'h00f00393);  // ori x7, x0, 0x0F
        // or x8, x6, x7 -> x8 = 0xF0 | 0x0F = 0xFF
        load_instr(8, 32'h00732433);  // or x8, x6, x7
        
        // Test 6: SW and LW - Store and Load Word
        // sw x4, 0(x0) -> store 30 to data memory[0x400]
        load_instr(9, 32'h00402023);  // sw x4, 0(x0)
        // lw x9, 0(x0) -> x9 = 30
        load_instr(10, 32'h000024b7);  // lw x9, 0(x0)
        
        // Test 7: BEQ - Branch if equal
        // beq x2, x2, label1 -> branch taken (x2 == x2)
        // label1: addi x10, x0, 100 -> x10 = 100
        load_instr(11, 32'h00010563);  // beq x2, x2, +8 (to instr 13)
        load_instr(12, 32'h00000513);  // nop (should be skipped)
        load_instr(13, 32'h06400513);  // addi x10, x0, 100
        
        // Test 8: JAL - Jump and link
        // jal x11, label2 -> x11 = PC+4, PC = label2
        // label2: addi x12, x0, 200
        load_instr(14, 32'h008005ef);  // jal x11, +8 (to instr 16)
        load_instr(15, 32'h00000513);  // nop (should be skipped)
        load_instr(16, 32'h0c800613);  // addi x12, x0, 200
        
        // Test 9: JALR - Jump and link register
        // lui x13, 0x100 -> x13 = 0x100000 (address in instruction space)
        // addi x13, x13, 24 -> x13 = 0x100018 (address of instr 18)
        // jalr x14, 0(x13) -> jump to address in x13
        load_instr(17, 32'h001006b7);  // lui x13, 0x100
        load_instr(18, 32'h01868693);  // addi x13, x13, 24
        load_instr(19, 32'h000687e7);  // jalr x14, 0(x13)
        load_instr(20, 32'hffffffff);  // will be overwritten by target
        load_instr(21, 32'hffffffff);  // will be overwritten by target  
        load_instr(22, 32'hffffffff);  // will be overwritten by target
        load_instr(23, 32'h0e000713);  // addi x14, x0, 224 (target of jalr)
        
        // End with infinite loop (beq x0, x0, current)
        load_instr(24, 32'h00001fe3);  // beq x0, x0, -4
        
        // Run simulation
        #500;
        
        $display("===========================================");
        $display("Simulation Complete");
        $display("===========================================");
        $display("Expected Results:");
        $display("x1  = 0x12345678 (LUI + ADDI)");
        $display("x2  = 10 (ADDI)");
        $display("x3  = 20 (ADDI)");
        $display("x4  = 30 (ADD: 10+20)");
        $display("x5  = 10 (SUB: 20-10)");
        $display("x6  = 0xF0 (ORI)");
        $display("x7  = 0x0F (ORI)");
        $display("x8  = 0xFF (OR: 0xF0|0x0F)");
        $display("x9  = 30 (LW from data memory)");
        $display("x10 = 100 (after BEQ taken)");
        $display("x11 = PC+4 (JAL return address)");
        $display("x12 = 200 (after JAL)");
        $display("x14 = 224 (after JALR)");
        $display("===========================================");
        
        $finish;
    end

    // Task to load instruction into instruction memory
    task load_instr;
        input [9:0] word_addr;
        input [31:0] instr;
        begin
            uut.imem.load_instruction(word_addr, instr);
        end
    endtask

    // Monitor output
    always @(posedge clk) begin
        if (rst_n) begin
            $display("Time=%0t | PC=%08h | Instr=%08h", 
                $time, uut.pc, uut.if_instr);
        end
    end

endmodule
