`include "../common/aether_pkg.sv"
import aether_pkg::*;

module aether_rat (
    input  logic                     clk_i                              ,
    input  logic                     rst_ni                             ,
    input  logic [ARCH_REG_BITS-1:0] rs1_arch_i [RENAME_WIDTH-1:0]      ,
    input  logic [ARCH_REG_BITS-1:0] rs2_arch_i [RENAME_WIDTH-1:0]      ,
    input  logic [ARCH_REG_BITS-1:0] rd_arch_i  [RENAME_WIDTH-1:0]      ,

    output logic [PHYS_REG_BITS-1:0] prs1_o     [RENAME_WIDTH-1:0]      ,
    output logic [PHYS_REG_BITS-1:0] prs2_o     [RENAME_WIDTH-1:0]      ,
    output logic [PHYS_REG_BITS-1:0] old_prd_o  [RENAME_WIDTH-1:0]      ,

    input  logic [PHYS_REG_BITS-1:0] new_prd_i  [RENAME_WIDTH-1:0]      ,
    input  logic                     rename_valid_i  [RENAME_WIDTH-1:0] ,

    input  logic                     commit_valid_i [RENAME_WIDTH-1:0]  ,
    input  logic [ARCH_REG_BITS-1:0] commit_arch_rd_i [RENAME_WIDTH-1:0],
    input  logic [PHYS_REG_BITS-1:0] commit_prd_i [RENAME_WIDTH-1:0]    ,
    input  logic                     restore_valid_i


    );

    logic [PHYS_REG_BITS-1:0] spec_rat_q [ARCH_REGS-1:0]  ;
    logic [PHYS_REG_BITS-1:0] retire_rat_q [ARCH_REGS-1:0];

    logic [PHYS_REG_BITS-1:0] spec_rat_d [ARCH_REGS-1:0]  ;
    logic [PHYS_REG_BITS-1:0] retire_rat_d [ARCH_REGS-1:0];

    always_comb begin
        for (int i = 0; i < ARCH_REGS; i++) begin
            spec_rat_d[i]   = spec_rat_q[i]  ;
            retire_rat_d[i] = retire_rat_q[i];
        end

        // Rename update
        for (int i = 0; i < RENAME_WIDTH; i++) begin
            prs1_o[i]    = spec_rat_d[rs1_arch_i[i]];
            prs2_o[i]    = spec_rat_d[rs2_arch_i[i]];
            old_prd_o[i] = spec_rat_d[rd_arch_i[i]] ;
            if (rename_valid_i[i] && rd_arch_i[i] != 0) begin
                spec_rat_d[rd_arch_i[i]] = new_prd_i[i];
            end
        end

        // commit update
        for (int i = 0; i < RENAME_WIDTH; i++) begin
            if (commit_valid_i[i] && commit_arch_rd_i[i] != 0) begin
                retire_rat_d[commit_arch_rd_i[i]] = commit_prd_i[i];
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            for (int i = 0; i < ARCH_REGS; i++) begin
                spec_rat_q[i]   <= PHYS_REG_BITS'(i);
                retire_rat_q[i] <= PHYS_REG_BITS'(i);
            end
        end
        else begin
            if (restore_valid_i) begin
                for (int i = 0; i < ARCH_REGS; i++) begin
                    spec_rat_q[i]   <= retire_rat_d[i];
                end
            end
            else begin
                for (int i = 0; i < ARCH_REGS; i++) begin
                    spec_rat_q[i]   <= spec_rat_d[i]  ;
                    retire_rat_q[i] <= retire_rat_d[i];
                end
            end
        end
    end

endmodule