// `include "../../common/aether_pkg.sv"
// import aether_pkg::*;

//------------------
//  REGFILE
//  Read ports  : 4
//  Write ports : 2
//------------------

module aether_phys_regfile (
    input  logic                     clk_i                         ,
    input  logic                     rst_ni                        ,

    // read port(s)
    input  logic [PHYS_REG_BITS-1:0] read_addr_i[READ_PORTS-1:0]   ,
    output logic          [XLEN-1:0] read_data_o[READ_PORTS-1:0]   ,

    // write port(s)
    input  logic [PHYS_REG_BITS-1:0] write_addr_i[WRITE_PORTS-1:0] ,
    input  logic                     write_valid_i[WRITE_PORTS-1:0],
    input  logic          [XLEN-1:0] write_data_i[WRITE_PORTS-1:0] ,

    output logic                     duplicate_write_error_o
    );

    // Physical register file
    reg [XLEN-1:0] phys_reg_q [PHYS_REGS-1:0];

    // combinational reads
    always_comb begin
        for (int i = 0; i < READ_PORTS; i++) begin
            if (read_addr_i[i] == 0)
                read_data_o[i] = 0;
            else begin
                read_data_o[i] = phys_reg_q[read_addr_i[i]];
                for (int j = 0; j < WRITE_PORTS; j++) begin
                    if (write_valid_i[j] && (write_addr_i[j] == read_addr_i[i])) begin
                        read_data_o[i] = write_data_i[j];
                        break;
                    end
                end
            end
        end
    end

    // synchronous writes

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            for (int k = 1; k < PHYS_REGS; k++) begin
                phys_reg_q[k]               <= 0;
            end
        end else begin
            for (int l = 0; l < WRITE_PORTS; l++) begin
                if (write_valid_i[l] && (write_addr_i[l] != 0)) begin
                    phys_reg_q[write_addr_i[l]] <= write_data_i[l];
                end
            end
        end
    end

    always_comb begin
        duplicate_write_error_o = 0;
        for (int i = 0; i < WRITE_PORTS; i ++) begin
            for (int j = i+1; j < WRITE_PORTS; j++) begin
                if (write_valid_i[i] && write_valid_i[j] && (write_addr_i[i] == write_addr_i[j]) && write_addr_i[i] != 0) begin
                    duplicate_write_error_o = 1;
                    break;
                end
            end
        end
    end

    endmodule