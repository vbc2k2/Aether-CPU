  package aether_pkg;

  parameter XLEN          = 32               ;

  parameter READ_PORTS    = 4                ;
  parameter WRITE_PORTS   = 2                ;

  parameter PHYS_REGS     = 64               ;
  parameter PHYS_REG_BITS = $clog2(PHYS_REGS);

  endpackage