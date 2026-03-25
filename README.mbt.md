# Starshine

MoonBit toolkit for parsing, validating, and rewriting WebAssembly.

For JavaScript/npm usage, see [node/README.md](./node/README.md).

## Install in MoonBit

```json
{
  "deps": {
    "jtenner/starshine": "<pin-or-local-source>"
  }
}
```

## What You Can Do

- Parse and print WAT/WAST.
- Preserve Binaryen-style function annotations in WAT/WAST text and lowered modules.
- Validate modules and enforce wasm typing and section rules.
- Decode and encode WebAssembly binaries.
- Build modules with `lib` constructors and boundary-form helpers.
- Lift function bodies into `HotFunc`, the only owned optimizer body representation, and lower them back to boundary form.
- Mutate `HotFunc` storage through canonical root, node, and child-span helpers.
- Query `HotFunc` structure through canonical node-family, branch, span, and local-metadata helpers.
- Traverse and rewrite `HotFunc` bodies through stable shared walkers with explicit skip/stop control flow.
- Edit top-level and nested structured regions through one `HotRegionRef` splice contract.
- Verify `HotFunc` core and control integrity through structured verifier errors before lowering or later analysis overlays.
- Use CLI and Node wrappers.

## Package Map

| Package | Purpose |
| --- | --- |
| `jtenner/starshine/wast` | Parse and print WAT/WAST text. |
| `jtenner/starshine/wat` | Text-format wasm helpers. |
| `jtenner/starshine/validate` | Validation, type matching, and valid-module generation helpers. |
| `jtenner/starshine/binary` | Binary encoding/decoding + LEB128 helpers. |
| `jtenner/starshine/lib` | Core Wasm types and constructors. |
| `jtenner/starshine/ir` | `HotFunc` hot function IR, architecture contracts, and lift/lower helpers. |
| `jtenner/starshine/passes` | Hot-IR pass registry, pass manager, and preset pipeline orchestration. |
| `jtenner/starshine/cli` | CLI parsing, config, globbing, and flags. |
| `jtenner/starshine/cmd` | Command execution and host adapters. |
| `jtenner/starshine/diff` | Myers diff helpers used by diagnostics and tooling. |
| `jtenner/starshine/fs` | Small filesystem helpers for host-facing code. |
| `jtenner/starshine/fuzz` | Fuzz harness entrypoints and support code. |
| `jtenner/starshine/spec_runner` | WAST spec-harness execution helpers. |
| `jtenner/starshine/validate_trace` | Validation trace entrypoints and fixtures. |

## IR2 Architecture

- `HotFunc` is the only owned optimizer body representation. Boundary decode/encode/validation/debug remain on raw module and expression forms.
- CFG, dominance, liveness, use-def, effects, loop info, and SSA are derived overlays keyed by hot-IR `revision`.
- The canonical architecture rule set lives in [`docs/0059-2026-03-24-ir2-architecture-rules.md`](./docs/0059-2026-03-24-ir2-architecture-rules.md); package-local module ownership rules live in [`src/ir/README.md`](./src/ir/README.md).

<!-- README_API_VERIFY src/ir/pkg.generated.mbti -->
```mbti
pub fn hot_node_count(HotFunc) -> Int
pub fn hot_child_storage_count(HotFunc) -> Int
pub fn hot_root_storage_count(HotFunc) -> Int
pub fn hot_body_result_type(HotFunc) -> Int
pub fn hot_body_result_type_set(HotFunc, Int) -> Unit
pub fn hot_node_is_live(HotFunc, Int) -> Bool
pub fn hot_debug_dump_core(HotFunc) -> String
pub fn hot_default_flags_for_op(HotOp) -> UInt
pub fn hot_node_flags(HotFunc, Int) -> UInt
pub fn hot_node_has_flag(HotFunc, Int, UInt) -> Bool
pub fn hot_is_control_node(HotFunc, Int) -> Bool
pub fn hot_is_terminator_node(HotFunc, Int) -> Bool
pub fn hot_has_side_effect(HotFunc, Int) -> Bool
pub fn hot_may_trap(HotFunc, Int) -> Bool
pub fn hot_is_branch(HotFunc, Int) -> Bool
pub fn hot_has_exceptional_succ(HotFunc, Int) -> Bool
pub fn hot_node_may_throw_exception(HotFunc, Int) -> Bool
pub fn hot_type_intern_void(HotFunc) -> Int
pub fn hot_type_intern_value(HotFunc, @lib.ValType) -> Int
pub fn hot_type_intern_block_result(HotFunc, @lib.BlockType) -> Int
pub fn hot_type_intern_results(HotFunc, Array[@lib.ValType]) -> Int
pub fn hot_type_get(HotFunc, Int) -> HotTypeInfo
pub fn hot_type_result_arity(HotFunc, Int) -> Int
pub fn hot_type_is_void(HotFunc, Int) -> Bool
pub fn hot_type_results(HotFunc, Int) -> Array[@lib.ValType]
pub fn hot_param_count(HotFunc) -> Int
pub fn hot_local_count(HotFunc) -> Int
pub fn hot_local_type(HotFunc, Int) -> @lib.ValType?
pub fn hot_label_alloc(HotFunc, HotLabelKind, Int, Int, Int) -> Int
pub fn hot_label_get(HotFunc, Int) -> HotLabelInfo
pub fn hot_label_owner(HotFunc, Int) -> Int
pub fn hot_label_kind(HotFunc, Int) -> HotLabelKind
pub fn hot_label_result_type(HotFunc, Int) -> Int
pub fn hot_label_branch_arity(HotFunc, Int) -> Int
pub fn hot_control_node_label(HotFunc, Int) -> Int
pub fn hot_control_region_slot_info(HotOp) -> Array[HotControlRegionSlotInfo]
pub fn hot_alloc_const(HotFunc, HotConstPayload) -> Int
pub fn hot_const_get(HotFunc, Int) -> HotConstPayload
pub fn hot_alloc_memarg(HotFunc, HotMemArg) -> Int
pub fn hot_memarg_get(HotFunc, Int) -> HotMemArg
pub fn hot_alloc_branch_table(HotFunc, HotBranchTable) -> Int
pub fn hot_branch_table_targets(HotFunc, Int) -> Array[Int]
pub fn hot_branch_table_default_target(HotFunc, Int) -> Int
pub fn hot_alloc_catch_info(HotFunc, HotCatchInfo) -> Int
pub fn hot_catch_info_get(HotFunc, Int) -> HotCatchInfo
pub fn hot_alloc_call_sig(HotFunc, HotCallSig) -> Int
pub fn hot_call_sig_get(HotFunc, Int) -> HotCallSig
pub fn hot_side_table_kind_for_op(HotOp) -> HotSideTableKind?
pub fn hot_build_node(HotFunc, HotOp, Int, imm0? : Int, imm1? : Int, children? : Array[Int]) -> Int
pub fn hot_build_const_i32(HotFunc, @lib.I32) -> Int
pub fn hot_build_local_get(HotFunc, Int) -> Int
pub fn hot_build_br_if(HotFunc, Int, Int, values? : Array[Int]) -> Int
pub fn hot_build_call_indirect(HotFunc, @lib.TypeIdx, @lib.TableIdx, Array[@lib.ValType], Array[Int], Int) -> Int
pub fn hot_build_load(HotFunc, @lib.ValType, @lib.MemArg, Int) -> Int
pub fn hot_build_block(HotFunc, @lib.BlockType, Array[Int]) -> Int
pub fn hot_build_if(HotFunc, @lib.BlockType, Int, Array[Int], else_body? : Array[Int]?) -> Int
pub fn hot_build_try_table(HotFunc, @lib.BlockType, Array[HotCatchArm], Array[Int], catch_list_body? : Array[Int]) -> Int
pub fn hot_build_drop(HotFunc, Int) -> Int
pub fn hot_build_unreachable(HotFunc) -> Int
pub fn hot_build_return(HotFunc, Array[Int]) -> Int
pub fn hot_alloc_child_span(HotFunc, Int) -> Int
pub fn hot_replace_child_span(HotFunc, Int, Array[Int]) -> Array[Int]
pub fn hot_delete_node(HotFunc, Int) -> Unit
pub fn hot_root_append(HotFunc, Int) -> Unit
pub fn hot_root_insert(HotFunc, Int, Int) -> Unit
pub fn hot_root_remove(HotFunc, Int) -> Int
pub fn hot_root_splice(HotFunc, Int, Int, Array[Int]) -> Array[Int]
pub fn hot_revision_bump(HotFunc) -> Unit
pub fn hot_node_kind_is_control(HotFunc, Int) -> Bool
pub fn hot_node_kind_is_call(HotFunc, Int) -> Bool
pub fn hot_node_type(HotFunc, Int) -> Int
pub fn hot_node_result_arity(HotFunc, Int) -> Int
pub fn hot_branch_target(HotFunc, Int) -> Int?
pub fn hot_branch_table_targets_for_node(HotFunc, Int) -> Array[Int]
pub fn hot_root_span(HotFunc) -> Array[Int]
pub fn hot_child_span(HotFunc, Int) -> Array[Int]
pub fn hot_local_param_count(HotFunc) -> Int
pub fn hot_local_body_count(HotFunc) -> Int
pub fn hot_node_is_deleted(HotFunc, Int) -> Bool
pub fn hot_revision_current(HotFunc) -> Int
pub fn hot_pass_requires(HotPassDescriptor) -> Array[HotAnalysis]
pub fn hot_pass_invalidates(HotPassDescriptor) -> Array[HotAnalysis]
pub fn HotAnalysis::cfg() -> Self
pub fn HotPassDescriptor::new(String, requires? : Array[HotAnalysis], invalidates? : Array[HotAnalysis]) -> Self
```

## Quick Example

```mbt
using @binary { encode_module }
using @validate { validate_module }
using @wast { wast_to_binary_module }

fn parse_validate_encode(source : String) -> Bool {
  let mod = match wast_to_binary_module(source, filename="input.wat") {
    Ok(mod) => mod
    Err(_) => return false
  }

  match validate_module(mod) {
    Ok(()) => ()
    Err(_) => return false
  }

  match encode_module(mod) {
    Ok(_) => true
    Err(_) => false
  }
}
```

## Pipeline Note

- `--optimize`, `--shrink`, `--vacuum`, `--dead-code-elimination`, `--optimize-instructions`, and `--simplify-locals` now route through the real IR2 hot-pass pipeline in `jtenner/starshine/passes`.
- The current public registry is intentionally small while pass migration is in progress: the active hot passes are `vacuum`, `dead-code-elimination`, `optimize-instructions`, and `simplify-locals`, and both presets now expand to that implemented batch-1 sequence.
- The registry now keeps explicit `boundary-only` and `removed` mappings for legacy names so planning and diagnostics stay explicit while help output remains limited to the active pass surface.
- The pass-manager contract is `lift -> verify -> run passes -> verify -> lower -> validate`, with per-function hot-IR verification and final module validation.
- Pass authors now have shared migration helpers for analysis requests, mutation/invalidation, and pipeline-backed WAT fixtures in `jtenner/starshine/passes`.
- Programmatic pipeline callers can now attach an opt-in hot perf session to collect stable phase timings, allocation/build counters, validation checkpoints, and lightweight hot-func / CFG debug dumps during IR2 work.
- The deleted `ModulePass` compatibility shim is gone; CLI tooling and the fuzz harness now use the same real pass-name arrays and registry-backed diagnostics as the hot pipeline itself.

## Prerequisites

- [bun](https://bun.sh) (for project scripts in `package.json`)
- [MoonBit toolchain (`moon`)](https://www.moonbitlang.com/docs/zh/getting-started/installing-moonbit/) (for building and testing MoonBit packages)
- Optional: [Node.js](https://nodejs.org/) if you also run `node/` package tooling

Install script dependencies after installing `bun` and `moon` (run from repo root):

```bash
bun install
```

## Build, Test, and Fuzz

Run the full project checks (same as CI defaults):

```bash
bun validate full --profile ci --target wasm-gc
```

Run the minimum local quality gate used by this repo:

```bash
moon info
moon fmt
moon test
```

Run fuzzing with default settings (suite/profile/seed/target):

```bash
bun fuzz run
```

Useful variant commands:

```bash
bun fuzz run --suite <suite> --profile <profile> --seed <seed> --target <target>
bun fuzz run --profile <profile> --suite <suite> --output jsonl
bun fuzz run --suite=<suite> --profile=<profile> --seed=<seed> --target=<target> --output=<text|jsonl>
bun fuzz run --list-suites
bun fuzz run --list-profiles
bun fuzz run --help
bun validate coverage
bun validate readme-api-sync
```
