`include "../../src/rename/aether_free_list.sv"
import aether_pkg::*;

module aether_free_list_tb;

    logic                     clk_i                          ;
    logic                     rst_ni                         ;

    logic                     alloc_req_i [WRITE_PORTS-1:0]  ;
    logic                     alloc_ready_o [WRITE_PORTS-1:0];
    logic [PHYS_REG_BITS-1:0] alloc_prd_o [WRITE_PORTS-1:0]  ;

    logic                     free_valid_i [WRITE_PORTS-1:0] ;
    logic [PHYS_REG_BITS-1:0] free_prd_i [WRITE_PORTS-1:0]   ;

    int unsigned error_count;

    always #5 clk_i = ~clk_i;

    aether_free_list dut (
        .clk_i         (clk_i),
        .rst_ni        (rst_ni),
        .alloc_req_i   (alloc_req_i),
        .alloc_ready_o (alloc_ready_o),
        .alloc_prd_o   (alloc_prd_o),
        .free_valid_i  (free_valid_i),
        .free_prd_i    (free_prd_i)
    );

    task automatic clear_inputs();
        for (int i = 0; i < WRITE_PORTS; i++) begin
            alloc_req_i[i]  = 1'b0;
            free_valid_i[i] = 1'b0;
            free_prd_i[i]   = '0  ;
        end
    endtask

    task automatic check_bit(input string name, input logic actual, input logic expected);
        if (actual !== expected) begin
            $display("ERROR: %s expected=%0b actual=%0b", name, expected, actual);
            error_count++;
        end
    endtask

    task automatic check_prd(
    input string name, input logic [PHYS_REG_BITS-1:0] actual, input logic [PHYS_REG_BITS-1:0] expected);
        if (actual !== expected) begin
            $display("ERROR: %s expected=p%0d actual=p%0d", name, expected, actual);
            error_count++;
        end
    endtask

    initial begin
        clk_i       = 1'b0;
        rst_ni      = 1'b0;
        error_count = 0   ;
        clear_inputs();

        repeat (2) @(posedge clk_i);
        rst_ni = 1'b1;
        @(negedge clk_i);

        // Test 1: reset state. With no requests, both ports see the same first candidate.
        check_bit("test1 ready0 after reset", alloc_ready_o[0], 1'b1);
        check_prd("test1 prd0 after reset", alloc_prd_o[0], PHYS_REG_BITS'(ARCH_REGS));
        check_bit("test1 ready1 after reset", alloc_ready_o[1], 1'b1);
        check_prd("test1 prd1 after reset", alloc_prd_o[1], PHYS_REG_BITS'(ARCH_REGS));

        // Test 2: single allocation consumes p32, so next candidate becomes p33.
        alloc_req_i[0] = 1'b1;
        #1;
        check_bit("test2 ready0 before alloc", alloc_ready_o[0], 1'b1);
        check_prd("test2 prd0 before alloc", alloc_prd_o[0], PHYS_REG_BITS'(ARCH_REGS));
        @(posedge clk_i);
        @(negedge clk_i);
        alloc_req_i[0] = 1'b0;
        #1;
        check_prd("test2 next prd after alloc", alloc_prd_o[0], PHYS_REG_BITS'(ARCH_REGS + 1));

        // Test 3: dual allocation hands out unique physical registers.
        alloc_req_i[0] = 1'b1;
        alloc_req_i[1] = 1'b1;
        #1;
        check_prd("test3 prd0 before dual alloc", alloc_prd_o[0], PHYS_REG_BITS'(ARCH_REGS + 1));
        check_prd("test3 prd1 before dual alloc", alloc_prd_o[1], PHYS_REG_BITS'(ARCH_REGS + 2));
        if (alloc_prd_o[0] === alloc_prd_o[1]) begin
            $display("ERROR: test3 duplicate allocation p%0d", alloc_prd_o[0]);
            error_count++;
        end
        @(posedge clk_i);
        @(negedge clk_i);
        clear_inputs();
        #1;
        check_prd("test3 next prd after dual alloc", alloc_prd_o[0], PHYS_REG_BITS'(ARCH_REGS + 3));

        // Test 4: freeing p32 makes it the lowest available candidate again.
        free_valid_i[0] = 1'b1                     ;
        free_prd_i[0]   = PHYS_REG_BITS'(ARCH_REGS);
        #1;
        check_prd("test4 prd with same-cycle free visible", alloc_prd_o[0], PHYS_REG_BITS'(ARCH_REGS));
        @(posedge clk_i);
        @(negedge clk_i);
        clear_inputs();
        #1;
        check_prd("test4 prd after free commits", alloc_prd_o[0], PHYS_REG_BITS'(ARCH_REGS));

        // Test 5: freeing p0 is ignored; allocator must never return p0.
        free_valid_i[0] = 1'b1;
        free_prd_i[0]   = '0  ;
        #1;
        if (alloc_prd_o[0] === '0 || alloc_prd_o[1] === '0) begin
            $display("ERROR: test5 allocator returned p0");
            error_count++;
        end
        @(posedge clk_i);
        @(negedge clk_i);
        clear_inputs();
        #1;
        if (alloc_prd_o[0] === '0 || alloc_prd_o[1] === '0) begin
            $display("ERROR: test5 allocator returned p0 after p0 free");
            error_count++;
        end

        if (error_count == 0) begin
            $display("All aether_free_list tests passed");
        end else begin
            $display("aether_free_list tests failed: %0d error(s)", error_count);
        end

        $finish;
    end

endmodule
