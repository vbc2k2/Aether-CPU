`include "../common/aether_pkg.sv"
import aether_pkg::*;

module aether_rename (
    input  logic                     clk_i                                    ,
    input  logic                     rst_ni                                   ,

    // from decoder
    //========================================================================
    input  logic                     decode_valid_i         [RENAME_WIDTH-1:0],
    output logic                     decode_ready_o         [RENAME_WIDTH-1:0],
    input  logic [ARCH_REG_BITS-1:0] decode_rs1_arch_i      [RENAME_WIDTH-1:0],
    input  logic [ARCH_REG_BITS-1:0] decode_rs2_arch_i      [RENAME_WIDTH-1:0],
    input  logic [ARCH_REG_BITS-1:0] decode_rd_arch_i       [RENAME_WIDTH-1:0],
    // signals indicating whether the field is being used or not
    input  logic                     decode_uses_rs1_i      [RENAME_WIDTH-1:0],
    input  logic                     decode_uses_rs2_i      [RENAME_WIDTH-1:0],
    input  logic                     decode_writes_rd_i     [RENAME_WIDTH-1:0],
    //========================================================================

    // to next stage
    //========================================================================
    output logic                     rename_valid_o         [RENAME_WIDTH-1:0],
    input  logic                     rename_ready_i         [RENAME_WIDTH-1:0],
    output logic [PHYS_REG_BITS-1:0] rename_prs1_o          [RENAME_WIDTH-1:0],
    output logic [PHYS_REG_BITS-1:0] rename_prs2_o          [RENAME_WIDTH-1:0],
    output logic [PHYS_REG_BITS-1:0] rename_prd_o           [RENAME_WIDTH-1:0],
    output logic [PHYS_REG_BITS-1:0] rename_old_prd_o       [RENAME_WIDTH-1:0],
    output logic [ARCH_REG_BITS-1:0] rename_rd_arch_o       [RENAME_WIDTH-1:0],
    // signals indicating whether the field is being used or not
    output logic                     rename_uses_rs1_o      [RENAME_WIDTH-1:0],
    output logic                     rename_uses_rs2_o      [RENAME_WIDTH-1:0],
    output logic                     rename_writes_rd_o     [RENAME_WIDTH-1:0],
    //========================================================================

    // free list interface
    //========================================================================
    output logic                     free_list_alloc_req_o  [RENAME_WIDTH-1:0],
    input  logic                     free_list_alloc_ready_i[RENAME_WIDTH-1:0],
    input  logic [PHYS_REG_BITS-1:0] free_list_alloc_prd_i  [RENAME_WIDTH-1:0],
    //========================================================================

    // RAT interface
    //========================================================================
    output logic [ARCH_REG_BITS-1:0] rat_rs1_arch_o         [RENAME_WIDTH-1:0],
    output logic [ARCH_REG_BITS-1:0] rat_rs2_arch_o         [RENAME_WIDTH-1:0],
    output logic [ARCH_REG_BITS-1:0] rat_rd_arch_o          [RENAME_WIDTH-1:0],

    input  logic [PHYS_REG_BITS-1:0] rat_prs1_i             [RENAME_WIDTH-1:0],
    input  logic [PHYS_REG_BITS-1:0] rat_prs2_i             [RENAME_WIDTH-1:0],
    input  logic [PHYS_REG_BITS-1:0] rat_old_prd_i          [RENAME_WIDTH-1:0],

    output logic [PHYS_REG_BITS-1:0] rat_new_prd_o          [RENAME_WIDTH-1:0],
    output logic                     rat_rename_valid_o     [RENAME_WIDTH-1:0]
    //========================================================================

    );

    logic [RENAME_WIDTH-1:0] needs_dest_alloc    ;
    logic [RENAME_WIDTH-1:0] dest_requirement_met;
    logic [RENAME_WIDTH-1:0] rename_fire         ;
    logic [RENAME_WIDTH-1:0] lane_can_issue      ;
    logic [RENAME_WIDTH-1:0] lane_fire_possible  ;
    always_comb begin

        for (int i = 0; i < RENAME_WIDTH; i++) begin
            decode_ready_o[i]     = '0;
            rename_rd_arch_o[i]   = '0;
            rename_prs1_o[i]      = '0;
            rename_prs2_o[i]      = '0;
            rename_prd_o[i]       = '0;
            rename_valid_o[i]     = '0;
            rename_old_prd_o[i]   = '0;
            rename_writes_rd_o[i] = '0;
            rename_uses_rs1_o[i]  = '0;
            rename_uses_rs2_o[i]  = '0;
            
            free_list_alloc_req_o[i] = '0;
            rat_rs1_arch_o[i]        = '0;
            rat_rs2_arch_o[i]        = '0;
            rat_rd_arch_o[i]         = '0;
            rat_new_prd_o[i]         = '0;
            rat_rename_valid_o[i]    = '0;
            lane_can_issue[i]        = '0;
            lane_fire_possible[i]    = '0;
            
            // get source tags from RAT
            // if decode signals are valid, then immediatlely get the source tags from RAT
            if (decode_valid_i[i]) begin
                rename_uses_rs1_o[i] = decode_uses_rs1_i[i];
                if (decode_uses_rs1_i[i]) begin
                    rat_rs1_arch_o[i]    = decode_rs1_arch_i[i];
                    rename_prs1_o[i]     = rat_prs1_i[i]       ;
                end
                rename_uses_rs2_o[i] = decode_uses_rs2_i[i];
                if (decode_uses_rs2_i[i]) begin
                    rat_rs2_arch_o[i]    = decode_rs2_arch_i[i];
                    rename_prs2_o[i]     = rat_prs2_i[i]       ;
                end
            end

            // if destination is tag is required then get new prd from free_list
            // also send the old_prd mapping to that arch_reg to next unit (ROB etc)
            needs_dest_alloc[i]   = decode_valid_i[i] && decode_writes_rd_i[i] && (decode_rd_arch_i[i] != 0);
            rename_writes_rd_o[i] = needs_dest_alloc[i]                                                     ;
            // when we don't need to allocate a prd, dest_requirement_met become high automatically and doesn't wait if free_list is empty
            dest_requirement_met[i] = !needs_dest_alloc[i] || free_list_alloc_ready_i[i]                      ;
            
            lane_fire_possible[i]   = decode_valid_i[i] && dest_requirement_met[i] && rename_ready_i[i]       ;
            if (i == 0) begin
                lane_can_issue[i] = 1'b1;
            end
            else begin
                lane_can_issue[i] = lane_can_issue[i-1] && lane_fire_possible[i-1];
            end

            rename_valid_o[i] = lane_can_issue[i] && dest_requirement_met[i] && decode_valid_i[i];
            decode_ready_o[i] = lane_can_issue[i] && dest_requirement_met[i] && rename_ready_i[i];
            // rename fire is asserted if upstream data is valid and this ordered lane is ready
            rename_fire[i]    = lane_can_issue[i] && lane_fire_possible[i]                       ;
            
            rat_rd_arch_o[i]  = decode_rd_arch_i[i]                                              ;
            if (needs_dest_alloc[i]) begin
                // if prd needs to be assigned for the instruction
                // send the arch_reg addr to spec-RAT, get the old tag
                // send the arch_reg addr to next stage (ROB)
                rename_rd_arch_o[i] = decode_rd_arch_i[i]     ;
                rename_old_prd_o[i] = rat_old_prd_i[i]        ;
                rename_prd_o[i]     = free_list_alloc_prd_i[i];
            end

            if (needs_dest_alloc[i] && rename_fire[i]) begin

                // get the new tag (prd) from free_list
                free_list_alloc_req_o[i] = 1                       ;
                // update spec-RAT with new tag
                rat_rename_valid_o[i]    = '1                      ;
                rat_new_prd_o[i]         = free_list_alloc_prd_i[i];
                
            end

        end
    end

endmodule
