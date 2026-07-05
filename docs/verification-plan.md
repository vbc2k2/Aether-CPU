# Verification Plan

## Strategy

Do not build a large custom verification environment first. Aether should
orchestrate existing open-source tools and only add project-specific glue where
needed.

The verification stack is:

```text
lint
  -> unit tests
  -> smoke assembly tests
  -> RISC-V architectural tests
  -> riscv-dv random programs
  -> Spike comparison
  -> riscv-formal / RVFI checks
  -> performance benchmarks
```

Each layer catches a different class of bug.

## Tools

| Tool | Role |
| --- | --- |
| Verilator | Fast RTL simulation |
| cocotb | Python unit tests for RTL modules |
| Verible | SystemVerilog lint and formatting |
| RISC-V Architectural Tests | ISA certification-style assembly tests |
| riscv-dv | Random RISC-V instruction generation |
| Spike | Golden ISA reference model |
| riscv-formal | Formal checks through RVFI |
| SymbiYosys | Open-source formal engine flow |
| GitHub Actions | CI regression orchestration |

## Commit Trace Contract

Aether must emit one architectural commit record for every retired instruction:

```text
cycle
hart
valid
pc
insn
rd_addr
rd_wdata
mem_addr
mem_rmask
mem_wmask
mem_rdata
mem_wdata
trap
cause
```

This trace is the backbone of differential testing. Keep it stable even if the
internal CPU changes.

## Spike Comparison

The first comparison mode should be end-of-test architectural state:

1. Run ELF on Aether.
2. Run the same ELF on Spike.
3. Compare integer registers and expected memory signature.

After that works, add commit-by-commit comparison:

1. Aether emits commit trace.
2. Spike or a small ISS wrapper emits expected commit trace.
3. The checker reports the first mismatch.

A useful failure should say:

```text
first mismatch cycle: 4218
pc: 0x80001234
instruction: 0x003282b3
expected x5: 0x00000018
actual x5:   0x00000022
rob entry: 17
physical rd: p41
```

## riscv-dv Use

Use riscv-dv as the random program generator, not as a reason to build a full
UVM environment.

Initial configuration:

- ISA: RV32I
- Privilege: machine mode
- No virtual memory
- No interrupts
- No debug mode
- Small programs first

Regression levels:

| Level | When | Count |
| --- | --- | --- |
| smoke | every commit | 10 generated tests |
| PR | before merge | 100 generated tests |
| nightly | scheduled | 10,000 generated tests |
| release | milestone tag | 100,000 generated tests |

Add `M`, `C`, interrupts, and virtual memory only when the core supports them.

## RISC-V Architectural Tests

Run architectural tests before large random regressions. They are not enough by
themselves, but they give fast confidence that basic ISA behavior is correct.

Initial suites:

- RV32I integer instructions
- Misaligned access behavior once traps exist
- CSR subset once CSRs exist

## riscv-formal And RVFI

Add RVFI signals at commit as early as possible, even if only a subset is wired
at first.

Recommended approach:

1. Add `rvfi_if` next to the normal commit trace.
2. Gate it with a synthesis parameter such as `ENABLE_RVFI`.
3. Start with RV32I ALU instructions.
4. Add branches, loads, stores, and traps after the basic flow is stable.

The RTL should not depend on RVFI being enabled for normal operation.

## Unit Tests

Use cocotb for module-level testing.

Required unit tests:

- Free list allocation, free, wraparound, and empty/full behavior.
- Rename map checkpoint and restore.
- ROB allocate, complete, commit, flush, and exception handling.
- Issue queue wakeup and select.
- Branch predictor predict/update behavior.
- LSU ordering and byte-enable behavior.

Unit tests should run before full-core simulation because they isolate bugs
faster.

## CI Gates

Every pull request should run:

1. Verible lint.
2. Verilator compile.
3. cocotb unit tests.
4. Handwritten smoke assembly tests.
5. Architectural test subset.
6. Small riscv-dv random regression.

Nightly CI should run:

1. Full architectural test subset for supported ISA.
2. Larger riscv-dv regression.
3. Formal checks for the supported RVFI subset.
4. Performance benchmark smoke set.

## Coverage And Metrics

Track correctness and architecture metrics separately.

Correctness:

- Tests passed.
- First failing seed.
- First mismatch PC.
- Instruction coverage from riscv-dv.
- Formal pass/fail by instruction group.

Architecture:

- IPC.
- Branch accuracy.
- Branch MPKI.
- L1 miss rate after caches exist.
- ROB occupancy.
- Issue queue occupancy.
- Stall reason breakdown.
- Flush count.

The metrics format should be machine-readable JSON so a dashboard can be added
later without changing simulation.

## External References

- riscv-dv: https://github.com/chipsalliance/riscv-dv
- RISC-V Architectural Tests: https://github.com/riscv/riscv-arch-test
- Spike: https://github.com/riscv-software-src/riscv-isa-sim
- riscv-formal: https://github.com/SymbioticEDA/riscv-formal
- Verilator: https://github.com/verilator/verilator
- cocotb: https://github.com/cocotb/cocotb
- Verible: https://github.com/chipsalliance/verible
- SymbiYosys: https://github.com/YosysHQ/sby
