# 0069 - Pick Load Signs

## Scope

- Completed active hot IR port for `pick-load-signs` (shipped in 2026-03-26/27).
  This document records the implemented behavior and the remaining follow-up validation notes.
- Keep the implementation narrowly faithful to Binaryen’s load-sign selection behavior on the default no-DWARF path.
- Prioritize correctness parity first, then runtime parity against `bun scripts/self-optimize-compare.ts`.

## Binaryen Behavior Under the Path

The Binaryen path documented for the artifact runs `pick-load-signs` in the early function phase for optimize level >= 2.

- The pass chooses a smaller (or canonical) load opcode for integer locals that are:
  - produced by a narrow integer load (`i32.load8_*`, `i32.load16_*`, `i64.load8_*`, `i64.load16_*`, `i64.load32_*`)
  - later used in a way that proves a chosen signedness extension semantics.
- It rewrites all candidate producers for the same local consistently.
- It avoids changes when usage context is mixed, ambiguous, or width-unsafe.

## Eligible Rewrite Surface

- Load instructions considered for candidates:
  - `i32.load8_s`, `i32.load8_u`
  - `i32.load16_s`, `i32.load16_u`
  - `i64.load8_s`, `i64.load8_u`
  - `i64.load16_s`, `i64.load16_u`
  - `i64.load32_s`, `i64.load32_u`
- Producer form:
  - a `local.set` whose child is exactly one of the above load nodes.
  - `local.tee` is intentionally excluded.
- Target local type:
  - `i32` load candidates track extension width in `[8,16]` bits.
  - `i64` load candidates track extension width in `[8,16,32]` bits.

## Extension-Usage Detection

- Extension usage is collected from every `local.get` node that reads the tracked local.
- A usage contributes to either signed or unsigned evidence when `local.get` is in one of these exact parent patterns:
  1. **Direct unary extend**
     - `i32.extend8_s`, `i32.extend16_s`, `i64.extend8_s`, `i64.extend16_s`, `i64.extend32_s`, `i64.extend_i32_s`
     - `i64.extend_i32_u`
  2. **Mask-to-zero pattern**
     - `i32.and` / `i64.and` with a constant mask that contains only low bits:
       - constant form `((1 << n) - 1)`, `n > 0`
     - `n` defines required zero-extension width.
  3. **Shift pair pattern**
     - `(x << b)` where inner and right-shift constants are equal:
       - unsigned: `i32.shr_u` or `i64.shr_u`
       - signed: `i32.shr_s` or `i64.shr_s`
     - extension width is `bitwidth - b`, where bitwidth is 32/64.
     - the same local must be `x`.
- Both parent and grandparent are checked because load results may be folded into a second unary/binary parent.
- `local.get` positions that are not recognized by these rules do not contribute signedness evidence.

## Decision Rules for a Local

For each local that has at least one candidate load producer:

1. Let:
  - `signed_usages`, `unsigned_usages`
  - `signed_bits`, `unsigned_bits`
  - `total_usages`
2. Candidate is rewritable only if:
  - `signed_usages + unsigned_usages == total_usages`
  - all signed usages use the same bitwidth (`signed_bits`) when nonzero
  - all unsigned usages use the same bitwidth (`unsigned_bits`) when nonzero
  - target load bitwidth equals usage-reported bitwidth for the winning signedness.
3. Rewritten signedness:
  - if both signs present: signed wins on tie (`2 * signed_usages >= unsigned_usages`)
  - if only one sign family appears: that family wins
  - else no rewrite.
4. If the computed target signedness differs from the current load opcode, all producers of that local use the new opcode.

## Hot-IR Porting Design

- Build-use-def information per function.
- Enumerate candidate load producers by scanning live nodes and selecting `LocalSet` of qualifying load opcode family.
- For each candidate local:
  - fetch all `local.read` nodes (`node_use_def.local_read_nodes`),
  - inspect parent and grandparent of each `local.get` (via `node_use_sites`) for extension patterns.
- Track per-local usage stats and choose target signedness with the rule above.
- Perform one pass over roots and nodes in the lifted function:
  - when a candidate `LocalSet` contains a target-rewrite load op:
    - allocate a new exact instruction payload with switched load opcode and same memarg (`imm0`)
    - create a replacement node and call `pass_replace_node`.
- Replacements must run through pass APIs so analyses cache invalidation remains consistent.

## Correctness Guardrails

- Never rewrite if usage context cannot prove a single width per sign family.
- Never rewrite mixed-sign usage that does not obey usage-width consistency.
- If any usage is unrecognized (neither sign nor zero extension pattern), keep current signedness.
- Keep module skip behavior: if module has no memory (defined/imported), skip pass execution.
- Preserve all existing control-flow behavior by only mutating exact opcode payload inside equivalent load child.

## Integration Status

- Completed: `pick_load_signs.mbt` + `pick_load_signs_test.mbt` landed.
- Completed: descriptors added via `pick_load_signs_descriptor()` and `pick_load_signs_summary()`.
- Completed: `pick-load-signs` is registered as hot in `src/passes/optimize.mbt` and placed in `optimize`/`shrink` after `optimize-instructions`.
- Completed: `src/passes/pass_manager.mbt` now routes `pick-load-signs` through `hot_pass_run` with module-memory fast-skip.
- Completed: registry/preset tests were updated to reflect active pass availability.

## Validation Plan

- Focused pass tests:
  - dominance tie and preference behavior
  - non-extension usage blocks rewrite
  - mixed-width/sign invalidation cases
  - grandparent shift patterns for zero-sign extension
  - local.tee exclusion
  - all candidates mapped to same local rewrite together
  - idempotence
  - module memory fast-skip + imported-memory availability case
- Required checks before signoff:
  - `moon info && moon fmt`
  - targeted pass tests (`pick_load_signs_test.mbt`)
  - full `moon test`
- Canonical parity check:
  - `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --pick-load-signs`
  - target: canonical/WAT parity + at least ~50% runtime compared to Binaryen in this pass slot.
