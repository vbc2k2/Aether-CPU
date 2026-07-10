  package aether_pkg;

  parameter XLEN          = 32                   ;

  parameter READ_PORTS    = 4                    ;
  parameter WRITE_PORTS   = 2                    ;

  parameter PHYS_REGS     = 64                   ;
  parameter PHYS_REG_BITS = $clog2(PHYS_REGS)    ;
  parameter ARCH_REGS     = 32                   ;
  parameter ARCH_REG_BITS = $clog2(ARCH_REGS)    ;
  parameter FREE_REGS     = PHYS_REGS - ARCH_REGS;
  parameter FREE_IDX_BITS = $clog2(FREE_REGS)    ;

  parameter RENAME_WIDTH  = 1                    ;
  parameter COMMIT_WIDTH  = 1                    ;

  endpackage