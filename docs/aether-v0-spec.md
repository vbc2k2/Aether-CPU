# Aether v0 Spec

## Goal

Aether v0 is the smallest useful CPU that proves the project is serious:

1. It runs real RISC-V bare-metal ELF tests.
2. It passes architectural correctness checks.
3. It has a real out-of-order backend.
4. It exposes stable interfaces where researchers can swap policies.
5. It produces enough traces and metrics to debug failures quickly.


## First ISA Target

Start with `RV32I`, machine-mode only.

Add extensions in this order:

1. `RV32I`
2. `RV32IM`
3. `RV32IMC`
4. Optional `RV64IM`


## v0 Microarchitecture

| Block | v0 Choice |
| --- | --- |
| Fetch width | 1 instruction/cycle |
| Decode width | 1 instruction/cycle |
| Rename width | 1 instruction/cycle |
| Dispatch width | 1 instruction/cycle |
| Issue width | 2 instructions/cycle |
| Commit width | 1 instruction/cycle |
| ROB | 32 entries |
| Integer physical registers | 64 |
| Load/store queue | 8 loads, 8 stores |
| Branch predictor | Static not-taken first, then bimodal |
| I-cache | Direct request into instruction memory first |
| D-cache | Direct request into data memory first |
| Memory model | Single-cycle or fixed-latency SRAM model first |
| Exceptions | Illegal instruction, load/store misalign, ecall |
| Interrupts | Not in v0 |
| MMU | Not in v0 |

This is intentionally modest.

## Pipeline

The v0 pipeline should be:

```text
fetch
  -> decode
  -> rename
  -> dispatch
  -> issue
  -> execute
  -> writeback
  -> commit
```

### Fetch

Responsibilities:

- Maintain program counter.
- Ask branch predictor for next PC.
- Fetch instruction word.
- Attach prediction metadata to the instruction.
- Redirect on branch mispredict, exception, or trap.

Stable interfaces:

- `branch_predictor_if`
- `fetch_redirect_if`
- `imem_if`

### Decode

Responsibilities:

- Decode RV32I instruction fields.
- Produce a normalized micro-op.
- Detect unsupported or illegal instructions.

Stable interface:

- `decode_uop_t`

The rest of the CPU should not repeatedly decode instruction bits.

### Rename

Responsibilities:

- Map architectural registers to physical registers.
- Allocate destination physical registers.
- Track stale physical registers for commit-time free.
- Checkpoint rename state for branches.

Stable interfaces:

- `rename_map_if`
- `free_list_if`
- `branch_checkpoint_if`

### Dispatch

Responsibilities:

- Allocate ROB entry.
- Allocate issue queue entry.
- Allocate load/store queue entry when needed.
- Stall cleanly when any required structure is full.

### Issue

Responsibilities:

- Wake up operands on writeback.
- Select ready operations.
- Send operations to compatible execution units.

Stable interface:

- `issue_queue_if`

The first implementation should be a simple unordered ready-first queue.
Oldest-first can come after correctness is stable.

### Execute

Execution unit classes:

- Integer ALU
- Branch unit
- Load/store address unit
- Multiplier later
- Divider later

Stable interface:

- `execution_unit_if`

Every execution unit should accept a micro-op and eventually return a result,
exception status, and wakeup tag.

### Load/Store

v0 should support:

- Byte, halfword, word loads.
- Byte, halfword, word stores.
- Store-to-load forwarding only after the basic LSU works.
- Conservative ordering first.

Stable interfaces:

- `lsq_if`
- `dmem_if`

### Commit

Responsibilities:

- Retire in program order.
- Update architectural state.
- Free stale physical registers.
- Handle exceptions and redirects.
- Emit architectural commit trace.
- Emit RVFI fields when formal is enabled.

Stable interface:

- `commit_if`

Commit is the most important debug boundary in the project. Treat it as a
public contract.

## Core Interfaces

Keep the number of replaceable interfaces small:

| Interface | Purpose |
| --- | --- |
| `branch_predictor_if` | Predict and update control flow |
| `btb_if` | Target prediction |
| `decode_uop_t` | Common decoded instruction format |
| `rename_map_if` | Architectural to physical register map |
| `free_list_if` | Physical register allocation |
| `rob_if` | In-order retirement and recovery |
| `issue_queue_if` | Scheduling policy |
| `execution_unit_if` | ALU, branch, multiply, divide units |
| `lsq_if` | Load/store ordering |
| `cache_if` | Cache request/response |
| `prefetcher_if` | Optional memory prefetch policy |
| `commit_trace_if` | Architectural comparison trace |
| `rvfi_if` | Formal verification interface |

Do not create a plugin point until there are at least two real implementations
or a clear research reason.

## Parameter Rules

Good parameters describe capacity:

- `XLEN`
- `ROB_ENTRIES`
- `ISSUE_WIDTH`
- `COMMIT_WIDTH`
- `PHYS_REGS`
- `IQ_ENTRIES`
- `LSQ_ENTRIES`
- `BTB_ENTRIES`

Avoid behavior parameters:

- `USE_GSHARE`
- `USE_TAGE`
- `USE_MAGIC_ROB`
- `USE_ALT_ISSUE`

Behavior changes should be separate modules implementing the same interface.

## Directory Layout

```text
aether-cpu/
  docs/
  rtl/
    core/
    frontend/
      predictors/
    decode/
    rename/
    backend/
      issue/
      execute/
      rob/
      lsu/
    memory/
    common/
    verification/
  tb/
    verilator/
    cocotb/
    formal/
  tools/
    aetherctl/
  tests/
    asm/
    smoke/
  third_party/
```

Use `third_party/` only for pinned external code or git submodules. Generated
build output should never live in source directories.

## Definition Of Done For v0

Aether v0 is done when:

- `RV32I` architectural tests pass.
- At least 10,000 riscv-dv generated programs pass against Spike.
- Basic riscv-formal checks pass for implemented instructions or an explicit
  RVFI bring-up subset is documented.
- cocotb unit tests cover ROB, rename map, free list, branch recovery, and LSU.
- Verilator simulation can run ELF binaries and emit commit traces.
- CI runs lint, smoke tests, architectural tests, and a small random regression.
- Documentation explains how to add one branch predictor and one issue policy.
