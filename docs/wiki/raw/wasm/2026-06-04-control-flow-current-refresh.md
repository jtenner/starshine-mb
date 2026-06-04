# Control-Flow Current Refresh

- Capture date: 2026-06-04
- Source family: current WebAssembly Core 3.0 syntax/text/binary/validation pages plus Starshine WAST/core/binary/validator/CFG/fuzz source surfaces
- Purpose: refresh the living WAST control-flow authoring page after the 2026-06-04 reference-call/cast, tail-call, static-harness, and runtime-trap source-routing work. This note does not change Starshine behavior; it clarifies which control facts belong on the ordinary-control page versus the specialized tail-call, exception, reference-branch, and parametric pages.

## Primary sources checked

- WebAssembly Core 3.0 syntax instructions: <https://webassembly.github.io/spec/core/syntax/instructions.html>
- WebAssembly Core 3.0 text instructions: <https://webassembly.github.io/spec/core/text/instructions.html>
- WebAssembly Core 3.0 binary instructions: <https://webassembly.github.io/spec/core/binary/instructions.html>
- WebAssembly Core 3.0 validation instructions: <https://webassembly.github.io/spec/core/valid/instructions.html>
- WebAssembly Core 3.0 execution instructions: <https://webassembly.github.io/spec/core/exec/instructions.html>

## Local Starshine sources checked

- [`src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt)
- [`src/wast/parser.mbt`](../../../../src/wast/parser.mbt)
- [`src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt)
- [`src/wast/module_wast.mbt`](../../../../src/wast/module_wast.mbt)
- [`src/lib/types.mbt`](../../../../src/lib/types.mbt)
- [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt)
- [`src/binary/encode.mbt`](../../../../src/binary/encode.mbt)
- [`src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt)
- [`src/ir/hot_flags.mbt`](../../../../src/ir/hot_flags.mbt)
- [`src/ir/cfg.mbt`](../../../../src/ir/cfg.mbt)
- [`src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt)
- [`src/wast/arbitrary.mbt`](../../../../src/wast/arbitrary.mbt)

## Durable takeaways

1. The current official Core 3.0 sources still use structured-control validation around a label stack: `block`, `loop`, and `if` establish label types; `br`, `br_if`, and `br_table` validate branch payloads against target labels; `return` validates against the current function result type; and `unreachable` makes the continuation stack-polymorphic. This remains the portable owner for ordinary label-depth and branch-payload teaching.
2. `br_table` is still easier to teach from both text and Starshine code as “zero or more table targets plus one default target”; all target labels must accept equivalent payload types. Starshine's [`typecheck_br_table(...)`](../../../../src/validate/typecheck.mbt) keeps this as a target-type equivalence rule after parser/lowerer label resolution.
3. `br_if` is still the main beginner footgun: validation proves the branch payload is present, but the not-taken path continues with that payload still on the stack after only the condition is consumed. Starshine's [`typecheck_br_if(...)`](../../../../src/validate/typecheck.mbt) matches that split.
4. The current local WAST keyword/parser/printer surface includes ordinary structured control plus `return_call*`, `throw*`, and `try_table`, but the living wiki should keep the broad family split navigable: ordinary branch/label mechanics live on `wast/control-flow-authoring.md`; tail-call exact-return and CFG terminator behavior live on `wast/tail-call-authoring.md`; exception tags and `try_table` catches live on `wast/exception-tag-authoring.md`; reference branches (`br_on_*`) live on `wast/reference-instruction-authoring.md`; and `drop` / `select` live on `wast/parametric-instruction-authoring.md`.
5. Starshine's core/binary/validator/generator model is wider than the ordinary-control WAST teaching subset in two directions: it has specialized reference branches as core instructions even though WAST text lacks `br_on_*`, and it has exception/tail-call WAST text that ordinary-control docs should route to focused pages instead of duplicating.
6. For pass and CFG work, branch-like instructions are not interchangeable. Ordinary `br_if` keeps branch payloads on fallthrough; reference branches refine branch and/or fallthrough reference types; tail calls, `throw`, `throw_ref`, and successful `br_table`/`return` are nonfallthrough terminators after their operands validate.

## Starshine implications

- `src/wast/keywords.mbt`, `src/wast/parser.mbt`, and `src/wast/module_wast.mbt` prove the local text split: ordinary `br` / `br_if` / `br_table`, `return_call*`, `throw*`, and `try_table` have keyword/parser/printer coverage; ordinary `br_on_*` remains absent from high-level WAST text.
- `src/lib/types.mbt`, `src/binary/decode.mbt`, and `src/binary/encode.mbt` prove the broader core/binary split: ordinary branch forms, tail calls, exception forms, `try_table`, and reference branches are all real core instructions with byte-level carriers.
- `src/validate/typecheck.mbt` remains the canonical local contract for stack order, label payloads, result typing, bottom values, tail-call exact-return checks, exception payloads, and reference-branch refinements.
- `src/ir/hot_flags.mbt` and `src/ir/cfg.mbt` are the local pass/CFG consumers; wiki control-flow guidance should route CFG edge-kind claims through `docs/wiki/ir2/cfg-contract.md` instead of inferring them from WAST text syntax alone.

## Caveats and supersession

- This note supersedes only stale routing/overview wording in `wast/control-flow-authoring.md`; the older [`2026-05-19` control-flow manifest](2026-05-19-wast-control-flow-sources.md) remains the broad source map for the original WAST control-flow page.
- The focused 2026-06-04 reference-call/cast, tail-call, runtime-trap, and static-harness notes remain the stronger sources for their own specialized families. Do not collapse those details back into this ordinary-control refresh.
- No code or tests changed in this refresh.
