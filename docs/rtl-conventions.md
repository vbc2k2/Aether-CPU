# Aether RTL Conventions

## Purpose

This document defines the RTL style and signal conventions for Aether. The goal
is to make modules easy to connect, review, test, and extend as the core grows
from a simple RV32I implementation into an out-of-order CPU.

These conventions are part of the design contract. New RTL should follow them
unless there is a documented reason not to.

## Design Principles

1. Pipeline boundaries use ready/valid handshakes.
2. Payloads crossing module boundaries are packed structs.
3. Ports use explicit direction suffixes.
4. Sequential state uses `_q` and next-state logic uses `_d`.
5. Redirects, memory accesses, and commit traces use stable packet types.
6. Parameters describe size and capacity, not behavior changes.
7. Modules communicate through ports only; no module reaches into another
   module's internals.
8. Verification-facing interfaces are treated as public contracts.

## File And Module Naming

Use one primary module per file.

```text
rtl/common/aether_pkg.sv
rtl/frontend/aether_fetch.sv
rtl/decode/aether_decode.sv
rtl/execute/aether_alu.sv
rtl/core/aether_core.sv
```

Module names should match file names:

```systemverilog
module aether_fetch;
module aether_decode;
module aether_core;
```

Shared types, enums, constants, and structs should live in
`rtl/common/aether_pkg.sv`.

## Port Naming

All module ports must use `_i` for inputs and `_o` for outputs.

```systemverilog
input  logic clk_i,
input  logic rst_ni,

input  logic in_valid_i,
output logic in_ready_o,

output logic out_valid_o,
input  logic out_ready_i
```

Use active-low reset named `rst_ni`.

Common suffixes:

| Suffix | Meaning |
| --- | --- |
| `_i` | Module input |
| `_o` | Module output |
| `_q` | Registered/current value |
| `_d` | Next combinational value |
| `_e` | Enum type |
| `_t` | Struct or typedef type |
| `_req` | Request payload |
| `_rsp` | Response payload |
| `_idx` | Index into an array or queue |
| `_addr` | Byte address unless documented otherwise |
| `_mask` | Byte or bit mask |
| `_we` | Write enable |

Avoid ambiguous names such as `data`, `enable`, `flag`, or `state` at module
boundaries. Qualify them with the block or protocol role.

## Ready/Valid Handshake

All pipeline stage boundaries use ready/valid.

```text
transfer = valid && ready
```

Producer rule:

- When `valid_o` is high and `ready_i` is low, the producer must hold the
  payload stable.

Consumer rule:

- The consumer may only consume a payload when `valid_i && ready_o` is true.

Recommended local naming:

```systemverilog
logic in_fire;
logic out_fire;

assign in_fire  = in_valid_i  && in_ready_o;
assign out_fire = out_valid_o && out_ready_i;
```

Do not use valid-only pipeline transfers between major blocks. Valid-only links
make stalling and backpressure ambiguous.

## Pipeline Boundary Pattern

Use a packed struct for payload and separate ready/valid signals for flow
control.

```systemverilog
input  logic       in_valid_i,
output logic       in_ready_o,
input  fetch_pkt_t in_pkt_i,

output logic       out_valid_o,
input  logic       out_ready_i,
output decode_pkt_t out_pkt_o
```

Preferred boundary names:

```text
fetch_decode_valid
fetch_decode_ready
fetch_decode_pkt

decode_rename_valid
decode_rename_ready
decode_rename_pkt

execute_wb_valid
execute_wb_ready
execute_wb_pkt
```

Do not pass many loose wires across a stage boundary when they describe one
transaction.

## Register And Combinational Style

Use `_q` for registered state and `_d` for next-state values.

```systemverilog
logic [31:0] pc_q;
logic [31:0] pc_d;

always_comb begin
  pc_d = pc_q;

  if (redirect_valid_i) begin
    pc_d = redirect_pkt_i.target_pc;
  end else if (fetch_fire) begin
    pc_d = pc_q + 32'd4;
  end
end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    pc_q <= RESET_PC;
  end else begin
    pc_q <= pc_d;
  end
end
```

Rules:

- Use `always_comb` for combinational logic.
- Use `always_ff` for sequential logic.
- Assign default values at the top of each `always_comb`.
- Do not infer latches.
- Do not mix blocking and nonblocking assignment in the same sequential block.
- Use nonblocking assignments in `always_ff`.

## Package Types

The common package should define architectural constants and shared payload
types.

```systemverilog
package aether_pkg;
  parameter int unsigned XLEN = 32;
  parameter int unsigned ARCH_REGS = 32;
  parameter int unsigned PHYS_REGS = 64;

  localparam int unsigned ARCH_REG_BITS = 5;
  localparam int unsigned PHYS_REG_BITS = $clog2(PHYS_REGS);

  typedef enum logic [4:0] {
    ALU_ADD,
    ALU_SUB,
    ALU_AND,
    ALU_OR,
    ALU_XOR,
    ALU_SLL,
    ALU_SRL,
    ALU_SRA,
    ALU_SLT,
    ALU_SLTU
  } alu_op_e;
endpackage
```

Import the package explicitly in modules:

```systemverilog
import aether_pkg::*;
```

## Core Packet Types

### Fetch Packet

The fetch packet carries the instruction and prediction metadata. The initial
implementation may only use `pc` and `insn`, but the packet is shaped so a
branch predictor can be added later.

```systemverilog
typedef struct packed {
  logic [XLEN-1:0] pc;
  logic [31:0]     insn;
  logic [XLEN-1:0] predicted_next_pc;
  logic            prediction_valid;
  logic [15:0]     prediction_meta;
  logic            fetch_fault;
} fetch_pkt_t;
```

### Decode Micro-Op

Decode should translate instruction bits into a normalized micro-op. Later
stages should use this type instead of repeatedly decoding raw instruction
fields.

```systemverilog
typedef struct packed {
  logic [XLEN-1:0] pc;
  logic [31:0]     insn;

  logic [4:0]      rs1;
  logic [4:0]      rs2;
  logic [4:0]      rd;
  logic [XLEN-1:0] imm;

  alu_op_e         alu_op;

  logic            uses_rs1;
  logic            uses_rs2;
  logic            writes_rd;

  logic            is_alu;
  logic            is_load;
  logic            is_store;
  logic            is_branch;
  logic            is_jump;
  logic            is_system;
  logic            illegal;
} uop_t;
```

Out-of-order fields should be added when rename is introduced:

```systemverilog
logic [PHYS_REG_BITS-1:0] prs1;
logic [PHYS_REG_BITS-1:0] prs2;
logic [PHYS_REG_BITS-1:0] prd;
logic [PHYS_REG_BITS-1:0] old_prd;
logic [ROB_IDX_BITS-1:0]  rob_idx;
```

Do not make decode depend on the physical register file or ROB.

### Redirect Packet

All frontend redirects use one packet. Avoid separate one-off wires for branch
mispredict, jump, exception, and trap redirects.

```systemverilog
typedef enum logic [2:0] {
  REDIRECT_BRANCH,
  REDIRECT_JALR,
  REDIRECT_EXCEPTION,
  REDIRECT_TRAP_RETURN
} redirect_reason_e;

typedef struct packed {
  logic [XLEN-1:0]       target_pc;
  redirect_reason_e      reason;
} redirect_pkt_t;
```

Boundary:

```systemverilog
input logic          redirect_valid_i,
input redirect_pkt_t redirect_pkt_i
```

Redirects have priority over normal fetch progression.

### Memory Request And Response

Use request/response channels for memory even when the first memory model is
single-cycle.

```systemverilog
typedef enum logic [1:0] {
  MEM_SIZE_BYTE,
  MEM_SIZE_HALF,
  MEM_SIZE_WORD
} mem_size_e;

typedef struct packed {
  logic [XLEN-1:0] addr;
  logic [XLEN-1:0] wdata;
  logic            write;
  mem_size_e       size;
  logic [3:0]      wmask;
} mem_req_t;

typedef struct packed {
  logic [XLEN-1:0] rdata;
  logic            fault;
} mem_rsp_t;
```

Request channel:

```systemverilog
output logic     dmem_req_valid_o,
input  logic     dmem_req_ready_i,
output mem_req_t dmem_req_o
```

Response channel:

```systemverilog
input  logic     dmem_rsp_valid_i,
output logic     dmem_rsp_ready_o,
input  mem_rsp_t dmem_rsp_i
```

Do not assume memory response is combinational at the CPU boundary. The test
memory may be simple, but the CPU interface should allow latency.

### Commit Packet

The commit packet is a verification contract. Keep it stable.

```systemverilog
typedef struct packed {
  logic [63:0]     cycle;
  logic            valid;
  logic [XLEN-1:0] pc;
  logic [31:0]     insn;

  logic [4:0]      rd_addr;
  logic [XLEN-1:0] rd_wdata;
  logic            rd_write;

  logic [XLEN-1:0] mem_addr;
  logic [3:0]      mem_rmask;
  logic [3:0]      mem_wmask;
  logic [XLEN-1:0] mem_rdata;
  logic [XLEN-1:0] mem_wdata;

  logic            trap;
  logic [XLEN-1:0] cause;
} commit_pkt_t;
```

Every retired instruction should emit exactly one valid commit packet. Squashed
or speculative instructions must not emit commit packets.

## Fetch Unit Interface

The first fetch unit should be simple but should already use expandable
interfaces.

```systemverilog
module aether_fetch import aether_pkg::*; (
  input  logic        clk_i,
  input  logic        rst_ni,

  output logic        imem_req_valid_o,
  input  logic        imem_req_ready_i,
  output mem_req_t    imem_req_o,

  input  logic        imem_rsp_valid_i,
  output logic        imem_rsp_ready_o,
  input  mem_rsp_t    imem_rsp_i,

  input  logic        redirect_valid_i,
  input  redirect_pkt_t redirect_pkt_i,

  output logic        fetch_valid_o,
  input  logic        fetch_ready_i,
  output fetch_pkt_t  fetch_pkt_o
);
```

Initial behavior:

- Reset PC to `RESET_PC`.
- Request instruction at current PC.
- Produce `fetch_pkt_t` when instruction response arrives.
- Set `predicted_next_pc = pc + 4`.
- Update PC to `pc + 4` after successful fetch transfer.
- If redirect arrives, discard pending sequential path and set PC to redirect
  target.

Future behavior:

- Replace `pc + 4` with branch prediction.
- Fill `prediction_meta`.
- Update predictor on commit or branch resolution.

## Stall And Flush Rules

Use backpressure for stalls:

```text
downstream not ready -> ready low -> upstream holds payload
```

Use redirects for control-flow recovery:

```text
branch/jump/trap redirect -> redirect_valid + redirect_pkt
```

A flush should invalidate younger in-flight work. It should not be encoded as
random ready/valid behavior. If a stage needs explicit flush input, name it:

```systemverilog
input logic flush_i
```

Flush semantics must be documented in that module.

## Parameters

Allowed parameters describe capacity:

```systemverilog
parameter int unsigned XLEN = 32;
parameter int unsigned ROB_ENTRIES = 32;
parameter int unsigned ISSUE_WIDTH = 2;
parameter int unsigned PHYS_REGS = 64;
```

Avoid behavior parameters:

```systemverilog
parameter bit USE_TAGE = 1'b0;       // avoid
parameter bit USE_GSHARE = 1'b1;     // avoid
parameter bit USE_ALT_ROB = 1'b0;    // avoid
```

Behavior variants should be separate modules implementing the same interface.

## Reset Policy

Use asynchronous active-low reset for state:

```systemverilog
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    valid_q <= 1'b0;
  end else begin
    valid_q <= valid_d;
  end
end
```

Reset all valid bits, architectural control state, and pointers. Large memories
do not need full reset unless correctness depends on initial contents.

## Constants And Literal Widths

Use sized literals.

```systemverilog
pc_d = pc_q + 32'd4;
valid_d = 1'b0;
```

Prefer package constants over repeated numeric literals:

```systemverilog
localparam logic [XLEN-1:0] RESET_PC = 32'h8000_0000;
```

## Assertions

Add local assertions for protocol assumptions and invariants.

Examples:

```systemverilog
// Payload must be stable while stalled.
assert property (@(posedge clk_i) disable iff (!rst_ni)
  out_valid_o && !out_ready_i |=> out_valid_o);

// x0 must never be allocated a physical destination through normal rename.
assert property (@(posedge clk_i) disable iff (!rst_ni)
  rename_fire && uop_i.writes_rd && (uop_i.rd == 5'd0) |-> !allocate_prd);
```

Assertions should explain intent. Do not add broad assertions that are not
owned by the local module.

## Review Checklist

Before merging new RTL, check:

- All ports use `_i` or `_o`.
- All registered state uses `_q`; next-state uses `_d`.
- Stage boundaries use ready/valid.
- Payloads crossing modules are packed structs.
- Producer holds payload stable while stalled.
- Reset behavior is explicit.
- No latches are inferred.
- No behavior-changing parameters were added.
- Redirect and memory behavior follow the shared packet definitions.
- Commit-visible behavior is testable through `commit_pkt_t`.

## Initial Rule For Aether v0

The first implementation can be simple. The interfaces should not be casual.

Build the boring path first:

```text
fetch -> decode -> execute -> commit trace
```

But use packetized ready/valid boundaries so the same design can later become:

```text
fetch -> decode -> rename -> dispatch -> issue -> execute -> writeback -> commit
```
