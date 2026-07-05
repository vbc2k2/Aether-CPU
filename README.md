# Aether CPU

Aether is a RISC-V CPU project built as an architecture experimentation
framework. The first target is a small, correct, synthesizable out-of-order
core with clean plugin boundaries for branch prediction, memory hierarchy,
issue logic, and execution units.

The project is intentionally scoped around correctness first:

- Use stable RTL interfaces for replaceable microarchitecture blocks.
- Use parameters for capacity and sizing, not for changing behavior.
- Use existing open-source verification tools instead of building a large
  custom verification environment from scratch.
- Keep every milestone runnable in CI.

## Initial Documents

- [Aether v0 Spec](docs/aether-v0-spec.md)
- [RTL Conventions](docs/rtl-conventions.md)
- [Verification Plan](docs/verification-plan.md)

## v0 Target

- ISA: RV32I first, then RV32IM, then optional RV64IM.
- Privilege: machine-mode bare-metal first.
- Memory: flat physical memory first, no MMU in v0.
- Pipeline: simple out-of-order integer core, one instruction retired per
  cycle initially.
- Verification: architectural tests, riscv-dv generated programs, Spike
  comparison, RVFI/riscv-formal where practical, and cocotb unit tests.

## Non-Goals For v0

- Linux boot.
- Full RV64GC.
- Floating point.
- Vector extension.
- Sophisticated cache coherence.
- A custom UVM environment.
