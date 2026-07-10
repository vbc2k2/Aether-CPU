`include "../common/aether_pkg.sv"
import aether_pkg::*;

//------------------
//  FREELIST
//------------------

module aether_free_list (

    input  logic                     clk_i                          ,
    input  logic                     rst_ni                         ,
    input  logic                     alloc_req_i  [RENAME_WIDTH-1:0],
    output logic                     alloc_ready_o[RENAME_WIDTH-1:0],
    output logic [PHYS_REG_BITS-1:0] alloc_prd_o  [RENAME_WIDTH-1:0],

    input  logic                     free_valid_i [COMMIT_WIDTH-1:0],
    input  logic [PHYS_REG_BITS-1:0] free_prd_i   [COMMIT_WIDTH-1:0]

    );

    // main free list, updated synchronously
    logic [PHYS_REGS-1:0] free_list_array;
    // temperory list updated combinationally
    logic [PHYS_REGS-1:0] free_list_next ;

    // prd allocation
    // p0 is never freed/allocated
    // frees are applied before allocations
    // for each port we assign a non-busy prd by least index first

    always_comb begin
        free_list_next = free_list_array;
        
        // free prd at commit
        for (int i = 0; i < COMMIT_WIDTH; i++) begin
            if (free_valid_i[i] && (free_prd_i[i] != 0)) begin
                free_list_next[free_prd_i[i]] = 0;
            end
        end

        // allocate prd at rename
        for (int i = 0; i < RENAME_WIDTH; i++) begin
            alloc_prd_o[i]   = 0;
            alloc_ready_o[i] = 0;
            
            for (int j = 1; j < PHYS_REGS; j++) begin
                if (free_list_next[j] == 0) begin
                    alloc_prd_o[i]    = PHYS_REG_BITS'(j);
                    alloc_ready_o[i]  = 1                ;
                    if (alloc_req_i[i] && alloc_ready_o[i]) begin
                        free_list_next[j] = 1;
                    end
                    break;
                end
            end
        end
    end

    // on reset : p0-p31 busy, p32-p63 free

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            free_list_array <= {{FREE_REGS{1'b0}}, {ARCH_REGS{1'b1}}};
        end
        else begin
            free_list_array <= free_list_next;
        end
    end

endmodule