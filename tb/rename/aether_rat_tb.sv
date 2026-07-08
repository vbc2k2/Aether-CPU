`include "../../src/rename/aether_rat.sv"
import aether_pkg::*;

module aether_rat_tb;

    logic                     clk_i                              ;
    logic                     rst_ni                             ;

    logic [ARCH_REG_BITS-1:0] rs1_arch_i [RENAME_WIDTH-1:0]      ;
    logic [ARCH_REG_BITS-1:0] rs2_arch_i [RENAME_WIDTH-1:0]      ;
    logic [ARCH_REG_BITS-1:0] rd_arch_i [RENAME_WIDTH-1:0]       ;

    logic [PHYS_REG_BITS-1:0] prs1_o [RENAME_WIDTH-1:0]          ;
    logic [PHYS_REG_BITS-1:0] prs2_o [RENAME_WIDTH-1:0]          ;
    logic [PHYS_REG_BITS-1:0] old_prd_o [RENAME_WIDTH-1:0]       ;

    logic [PHYS_REG_BITS-1:0] new_prd_i [RENAME_WIDTH-1:0]       ;
    logic                     rename_valid_i [RENAME_WIDTH-1:0]  ;

    logic                     commit_valid_i [RENAME_WIDTH-1:0]  ;
    logic [ARCH_REG_BITS-1:0] commit_arch_rd_i [RENAME_WIDTH-1:0];
    logic [PHYS_REG_BITS-1:0] commit_prd_i [RENAME_WIDTH-1:0]    ;
    logic                     restore_valid_i                    ;

    int unsigned error_count;

    always #5 clk_i = ~clk_i;

    aether_rat dut (
        .clk_i            (clk_i),
        .rst_ni           (rst_ni),
        .rs1_arch_i       (rs1_arch_i),
        .rs2_arch_i       (rs2_arch_i),
        .rd_arch_i        (rd_arch_i),
        .prs1_o           (prs1_o),
        .prs2_o           (prs2_o),
        .old_prd_o        (old_prd_o),
        .new_prd_i        (new_prd_i),
        .rename_valid_i   (rename_valid_i),
        .commit_valid_i   (commit_valid_i),
        .commit_arch_rd_i (commit_arch_rd_i),
        .commit_prd_i     (commit_prd_i),
        .restore_valid_i  (restore_valid_i)
    );

    task automatic clear_inputs();
        for (int i = 0; i < RENAME_WIDTH; i++) begin
            rs1_arch_i[i]       = '0  ;
            rs2_arch_i[i]       = '0  ;
            rd_arch_i[i]        = '0  ;
            new_prd_i[i]        = '0  ;
            rename_valid_i[i]   = 1'b0;
            commit_valid_i[i]   = 1'b0;
            commit_arch_rd_i[i] = '0  ;
            commit_prd_i[i]     = '0  ;
        end
        restore_valid_i = 1'b0;
    endtask

    task automatic check_preg(
        input string name,
        input logic [PHYS_REG_BITS-1:0] actual,
        input logic [PHYS_REG_BITS-1:0] expected
    );
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

        // Test 1: reset maps xN to pN.
        rs1_arch_i[0] = ARCH_REG_BITS'(1);
        rs2_arch_i[0] = ARCH_REG_BITS'(2);
        rd_arch_i[0]  = ARCH_REG_BITS'(3);
        #1;
        check_preg("test1 prs1 reset x1", prs1_o[0], PHYS_REG_BITS'(1));
        check_preg("test1 prs2 reset x2", prs2_o[0], PHYS_REG_BITS'(2));
        check_preg("test1 old prd reset x3", old_prd_o[0], PHYS_REG_BITS'(3));

        // Test 2: rename x5 to p40. Same-cycle old_prd remains old p5.
        rs1_arch_i[0]     = ARCH_REG_BITS'(1) ;
        rs2_arch_i[0]     = ARCH_REG_BITS'(2) ;
        rd_arch_i[0]      = ARCH_REG_BITS'(5) ;
        new_prd_i[0]      = PHYS_REG_BITS'(40);
        rename_valid_i[0] = 1'b1              ;
        #1;
        check_preg("test2 old prd before rename commit", old_prd_o[0], PHYS_REG_BITS'(5));
        @(posedge clk_i);
        @(negedge clk_i);
        rename_valid_i[0] = 1'b0             ;
        rs1_arch_i[0]     = ARCH_REG_BITS'(5);
        rs2_arch_i[0]     = ARCH_REG_BITS'(0);
        rd_arch_i[0]      = ARCH_REG_BITS'(5);
        #1;
        check_preg("test2 prs1 after rename x5", prs1_o[0], PHYS_REG_BITS'(40));
        check_preg("test2 old prd after rename x5", old_prd_o[0], PHYS_REG_BITS'(40));

        // Test 3: rename to x0 is ignored.
        rd_arch_i[0]      = ARCH_REG_BITS'(0) ;
        new_prd_i[0]      = PHYS_REG_BITS'(41);
        rename_valid_i[0] = 1'b1              ;
        #1;
        check_preg("test3 old prd x0", old_prd_o[0], PHYS_REG_BITS'(0));
        @(posedge clk_i);
        @(negedge clk_i);
        rename_valid_i[0] = 1'b0             ;
        rs1_arch_i[0]     = ARCH_REG_BITS'(0);
        #1;
        check_preg("test3 x0 still maps p0", prs1_o[0], PHYS_REG_BITS'(0));

        // Test 4: commit updates retirement RAT, but speculative RAT can move ahead.
        commit_valid_i[0]   = 1'b1              ;
        commit_arch_rd_i[0] = ARCH_REG_BITS'(5) ;
        commit_prd_i[0]     = PHYS_REG_BITS'(40);
        rd_arch_i[0]        = ARCH_REG_BITS'(5) ;
        new_prd_i[0]        = PHYS_REG_BITS'(42);
        rename_valid_i[0]   = 1'b1              ;
        @(posedge clk_i);
        @(negedge clk_i);
        commit_valid_i[0] = 1'b0             ;
        rename_valid_i[0] = 1'b0             ;
        rs1_arch_i[0]     = ARCH_REG_BITS'(5);
        rd_arch_i[0]      = ARCH_REG_BITS'(5);
        #1;
        check_preg("test4 spec rat moved x5 to p42", prs1_o[0], PHYS_REG_BITS'(42));

        // Test 5: restore copies retirement RAT into speculative RAT.
        restore_valid_i = 1'b1;
        @(posedge clk_i);
        @(negedge clk_i);
        restore_valid_i = 1'b0;
        #1;
        check_preg("test5 restore x5 to committed p40", prs1_o[0], PHYS_REG_BITS'(40));
        check_preg("test5 old prd after restore x5", old_prd_o[0], PHYS_REG_BITS'(40));

        // Test 6: same-cycle commit is included in restore through retire_rat_d policy.
        commit_valid_i[0]   = 1'b1              ;
        commit_arch_rd_i[0] = ARCH_REG_BITS'(6) ;
        commit_prd_i[0]     = PHYS_REG_BITS'(43);
        restore_valid_i     = 1'b1              ;
        @(posedge clk_i);
        @(negedge clk_i);
        clear_inputs();
        rs1_arch_i[0] = ARCH_REG_BITS'(6);
        rd_arch_i[0]  = ARCH_REG_BITS'(6);
        #1;
        check_preg("test6 same-cycle commit included in restore", prs1_o[0], PHYS_REG_BITS'(43));

        if (error_count == 0) begin
            $display("All aether_rat tests passed");
        end else begin
            $display("aether_rat tests failed: %0d error(s)", error_count);
        end

        $finish;
    end

endmodule
