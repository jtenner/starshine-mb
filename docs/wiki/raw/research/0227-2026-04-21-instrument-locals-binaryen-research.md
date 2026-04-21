# Binaryen `instrument-locals` research

- Date: 2026-04-21
- Pass: `instrument-locals`
- Status in Starshine tracker before this note: not yet tracked as its own dossier
- Scope: official Binaryen `version_129` implementation, registration surface, dedicated lit coverage, current-`main` drift, and practical teaching notes for future instrumentation/debugging parity work

## Why this pass, and why now

The canonical process for this campaign started with re-reading:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`

That re-check showed three important things:

1. the tracker no longer has an obvious remaining `none` queue;
2. the user explicitly excluded the long list of passes most recently wiki-ified or already earmarked as closed follow-up targets; and
3. `agent-todo.md` has **no dedicated `instrument-locals` slice**, so this is not a hidden local implementation task disguised as missing wiki bookkeeping.

That means a new dossier needed explicit justification as an upstream-only expansion.

`instrument-locals` meets that bar because it is a real public Binaryen pass registered in `src/passes/pass.cpp`, implemented in a compact dedicated owner file (`src/passes/InstrumentLocals.cpp`), backed by dedicated lit files, and easy to mis-teach as either:

- a generic locals optimizer, or
- a trivial logging pass with no effect-analysis consequences.

Neither simplification is correct.

## What the pass actually is

Beginner summary:

- wrap supported `local.get` uses in imported helper calls that receive `(call id, local id, value)` and return the same value type;
- wrap supported `local.set` / `local.tee` values in imported helper calls that receive `(call id, local id, value)` and return the same value type for the assignment;
- inject the helper imports into the module;
- and explicitly mark the pass as adding effects, which invalidates existing global-effect summaries.

So this pass is best taught as:

- **instrumentation of local traffic through imported logging/interception helpers**
- not a locals cleanup pass
- not an optimization pass
- not a generic trace-all-values pass
- and not a semantics-preserving no-effects annotation trick

## Official sources consulted

Primary implementation and registration sources:

- Binaryen `version_129` `src/passes/InstrumentLocals.cpp`
- Binaryen `version_129` `src/passes/pass.cpp`
- Binaryen `version_129` `src/passes/passes.h`

Dedicated proof surfaces discovered from the repository tree:

- Binaryen `version_129` `test/lit/passes/instrument-locals_all-features_disable-gc.wast`
- Binaryen `version_129` `test/lit/passes/instrument-locals_effects.wast`
- Binaryen `version_129` `test/lit/passes/instrument-locals-eh-legacy.wast`

Supporting helper-name surfaces:

- Binaryen `version_129` `src/shared-constants.h`
- Binaryen `version_129` `src/asmjs/shared-constants.h`

Freshness check:

- current `main` `src/passes/InstrumentLocals.cpp`
- current `main` versions of the three dedicated lit files above

## Key implementation findings

## 1. Public pass identity

`pass.cpp` registers `instrument-locals` with the help text:

- instrument the build with code to intercept all loads and stores

That help text is a little misleading because the pass name is locals-specific while the prose says "loads and stores" in the same wording style as `instrument-memory`.

The actual owner file is unambiguous: this pass intercepts **local reads and writes**.

It is not in the local Starshine optimizer registry and it is not part of the canonical no-DWARF `-O` / `-Os` path.

## 2. Whole-file owner surface is tiny

The entire reviewed contract lives in one dedicated file:

- `InstrumentLocals.cpp`

The file defines:

- helper import names such as `get_i32`, `set_f64`, `get_funcref`, `set_externref`, etc.;
- one `WalkerPass<PostWalker<InstrumentLocals>>` implementation;
- `visitLocalGet`; 
- `visitLocalSet`; 
- `visitModule`; and
- a tiny `addImport(...)` helper that creates `env` imports.

There is no deeper hidden analysis engine here.

## 3. The pass is explicitly effectful

`addsEffects() override { return true; }`

That is not bookkeeping fluff.

The dedicated `instrument-locals_effects.wast` file proves the practical consequence:

- once instrumentation inserts import calls, Binaryen must discard prior global-effects knowledge,
- so later cleanup such as `vacuum` can no longer erase the same code it could erase in a non-instrumented run.

This is one of the most important neighboring-pass interactions in the whole dossier.

## 4. `local.get` instrumentation is a direct wrapper rewrite

For each supported `LocalGet`, Binaryen replaces the original node with:

- `call $get_<type>(call_id, local_index, original_local_get)`

Important details:

- the helper returns the same type as the original local read;
- the original `local.get` becomes the third call operand, so the actual current local value still flows through the helper;
- `call id` and `local id` are both literal `i32.const`s;
- `call id` comes from one shared pass-local counter `id++`.

So the rewritten node is value-preserving only if the imported helper behaves that way; Binaryen deliberately treats the pass as instrumentation with added observable behavior.

## 5. `local.set` instrumentation wraps the assigned value, not the whole instruction

For `LocalSet`, Binaryen does **not** replace the entire node with a helper call.

Instead it rewrites:

- `curr->value = call $set_<type>(call_id, local_index, old_value)`

and leaves the outer `local.set` / `local.tee` shape in place.

That means the assignment still happens through the original local write node, but only after the helper returns the value to store.

This detail explains why the helper signatures all return the stored type.

## 6. The shared `id` counter mixes gets and sets in one postwalk order

The owner file has exactly one counter:

- `Index id = 0;`

Both `visitLocalGet` and `visitLocalSet` increment it.
So call IDs are:

- global to the pass run,
- not per local,
- not per helper kind,
- and not reset per function.

The large all-features lit file shows a monotonic numbering sequence across multiple rewritten operations.

## 7. Type support is intentionally partial

The implementation is much narrower than the helper roster might first suggest.

### Supported `local.get` rewrites

Scalar and feature-gated positives:

- `i32`
- `f32`
- `f64`
- `v128` when SIMD is enabled
- nullable `funcref`
- nullable `externref`

### Supported `local.set` rewrites

- `i32`
- `f32`
- `f64`
- `v128` when SIMD is enabled
- nullable `funcref`
- nullable `externref`
- plus the `LocalSet` hierarchy shape for ordinary sets / tees

### Explicit gaps and bailouts

- `i64` get/set visitors immediately `return; // TODO`
- general reference types hit `WASM_UNREACHABLE("TODO: general reference types")`
- typed function references on sets are explicitly skipped (`FIXME: support typed function references`)
- `Type::unreachable` local-set values return with no instrumentation
- `Pop` payloads are skipped entirely

So the helper import roster is broader than the actual rewrite surface: `get_i64` / `set_i64` imports are added, but ordinary `i64` local traffic is still left untouched in the current implementation.

That is a very important beginner-to-intermediate correction.

## 8. `Pop` skipping is deliberate EH compatibility behavior

The `instrument-locals-eh-legacy.wast` file exists almost entirely to prove one small but important rule:

- `local.set $x (pop i32)` should stay untouched.

The source comment explains why:

- `pop` instructions are generated when reading binary and deleted when writing binary,
- so local get/set instrumentation cannot safely wrap them.

This is not a random omission; it is a serialization-boundary safety rule.

## 9. Import injection is module-level and partly unconditional

`visitModule` always adds helper imports for:

- `get_i32`, `get_i64`, `get_f32`, `get_f64`
- `set_i32`, `set_i64`, `set_f32`, `set_f64`

It conditionally adds:

- `get_funcref`, `set_funcref`, `get_externref`, `set_externref` when reference types are enabled
- `get_v128`, `set_v128` when SIMD is enabled

Two notable consequences:

1. the module import surface grows even if some helpers are unused in that exact module after rewriting;
2. `i64` helper imports appear in the transformed module even though the actual local visitors still skip `i64` instrumentation.

The all-features lit file proves exactly that surprising split.

## 10. Imported helper signatures are identity-through-logging style

Every helper has the shape:

- params: `(i32 call_id, i32 local_id, value)`
- result: `value`

Examples:

- `get_i32 : (i32, i32, i32) -> i32`
- `set_f64 : (i32, i32, f64) -> f64`
- `get_funcref : (i32, i32, funcref) -> funcref`

`addImport(...)` creates them as `env` imports using `Builder::makeFunction(...)`.

So Binaryen's contract here is not hardcoded logging text output; it is imported helper interception with a fixed ABI.

## What the dedicated lit files prove

## `instrument-locals_all-features_disable-gc.wast`

This is the main shape/proof file.
It shows:

- helper type declarations and import injection;
- scalar positive families;
- nullable `funcref` and `externref` positives when GC is disabled but reference types stay available;
- SIMD `v128` positives;
- shared call-id sequencing;
- and the surprising current `i64` gap, where helper imports exist but raw `local.get $y` traffic remains unwrapped.

## `instrument-locals_effects.wast`

This is the semantic-neighbor proof file.
It shows:

- `generate-global-effects` + `instrument-locals` + `vacuum` cannot optimize the same way as a non-instrumenting run,
- because this pass adds imported calls and therefore invalidates existing effect knowledge.

It is the clearest official proof that `addsEffects() == true` has real downstream consequences.

## `instrument-locals-eh-legacy.wast`

This is the narrow EH regression file.
It proves:

- `pop` payloads under legacy EH catches are left alone.

## Current-`main` drift

A 2026-04-21 spot check found:

- `src/passes/InstrumentLocals.cpp` identical on `version_129` and current `main`
- `instrument-locals_all-features_disable-gc.wast` identical on `version_129` and current `main`
- `instrument-locals_effects.wast` identical on `version_129` and current `main`
- `instrument-locals-eh-legacy.wast` identical on `version_129` and current `main`

So the reviewed release contract is currently stable on the inspected surfaces.

## Practical conclusions for the living wiki

The most important durable teaching points are:

- `instrument-locals` is a real public Binaryen pass, but it is upstream-only in this repo today;
- it is a small postwalk rewrite pass plus helper-import injection, not a locals optimizer;
- it intentionally adds observable import-call effects and must be taught as effectful;
- it supports only a narrow type subset today;
- the helper roster is broader than the actual rewrite surface, especially for `i64`;
- and the official proof surface is tiny but strong: one broad mixed-shape file, one effects interaction file, and one `pop` / EH safety file.

## Files to add / update in the living wiki

Planned living pages:

- `docs/wiki/binaryen/passes/instrument-locals/index.md`
- `docs/wiki/binaryen/passes/instrument-locals/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/instrument-locals/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/instrument-locals/unsupported-types-effects-and-import-roster.md`
- `docs/wiki/binaryen/passes/instrument-locals/wat-shapes.md`

Shared catalogs to update:

- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Explicit note about `agent-todo.md`

`agent-todo.md` has **no dedicated `instrument-locals` slice** today.
That should be stated explicitly in the landing page and preserved in the tracker note so future threads do not assume there is hidden local scheduler or implementation work already queued for this pass.

## Source links

- Binaryen `version_129` `src/passes/InstrumentLocals.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/InstrumentLocals.cpp>
- Binaryen `version_129` `src/passes/pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` `src/passes/passes.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- Binaryen `version_129` `test/lit/passes/instrument-locals_all-features_disable-gc.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-locals_all-features_disable-gc.wast>
- Binaryen `version_129` `test/lit/passes/instrument-locals_effects.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-locals_effects.wast>
- Binaryen `version_129` `test/lit/passes/instrument-locals-eh-legacy.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-locals-eh-legacy.wast>
- Binaryen current `main` `src/passes/InstrumentLocals.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/InstrumentLocals.cpp>
- Binaryen current `main` `test/lit/passes/instrument-locals_all-features_disable-gc.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-locals_all-features_disable-gc.wast>
- Binaryen current `main` `test/lit/passes/instrument-locals_effects.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-locals_effects.wast>
- Binaryen current `main` `test/lit/passes/instrument-locals-eh-legacy.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-locals-eh-legacy.wast>
