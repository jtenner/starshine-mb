---
kind: research
status: current
last_reviewed: 2026-07-19
sources:
  - ../binaryen/2026-04-24-dae-optimizing-primary-sources.md
  - ../../binaryen/passes/dae-optimizing/binaryen-strategy.md
  - ../../binaryen/passes/dae-optimizing/signature-updates-and-nested-reruns.md
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/validate/validate.mbt
  - ./1650-2026-07-18-daeo-broad-boundary-and-uniform-constant-parity.md
---

# DAEO block fallthrough validation and local cleanup

## Scope

This slice repairs the definite-initialization-sensitive local-cleanup family left open by note `1650`, strengthens structured branch validation, and refreshes the Binaryen-v131 fixed artifact. It does not weaken candidate-context batch validation, per-definition rollback, nested selected-definition validation, strict final-convergence profitability, or plain-DAE separation.

The fixed input remains:

- `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`
- `3,204,405` bytes
- `13,162` defined functions
- `21` imported functions

The note-`1650` endpoint was valid and idempotent at raw/canonical `3,134,699` / `3,194,547`, but broad local cleanup rolled back `364` unique definitions across three waves after fallback `simplify-locals` candidates failed definite initialization. Its canonical gross-positive ledger was `2,927` functions totaling `+65,036` bytes.

## Root cause

The fallback cleanup counted `local.get` instructions only while the current structured instruction appeared able to fall through. Its private fallthrough classifier treated a typed block as nonfallthrough whenever the block's lexical tail ended in `br`, `return`, `throw`, or `unreachable`.

That rule was incomplete. A nested branch can target the block's own label, complete the block with its declared result, and continue into later instructions even when the block's lexical tail escapes an outer label. In the reduced family:

1. a nested block-local branch completes an outer typed block;
2. a later `local.set` initializes a local from that block result;
3. later work reads the local;
4. the old counter stopped at the typed block and reported zero reads;
5. fallback cleanup replaced the required `local.set` with `drop`;
6. validation then reported `uninitialized local`.

The fixed-artifact Func `115` / defined Func `94` reproduced the failure as `uninitialized local: 9` before compaction and `uninitialized local: 5` after local remapping.

## Red-first repair

Two pass-manager regressions now cover the owner:

- `simplify-locals lowered cleanup counts reads after block-local branch exits` proves the later read remains visible when a nested branch completes the typed block;
- `simplify-locals lowered cleanup preserves non-defaultable initialization after block-local branch exits` uses a non-nullable GC local and validates the complete module.

The cleanup counter now reuses the existing branch-aware raw fallthrough analysis instead of maintaining a weaker private structured-control approximation. That analysis recognizes normal fallthrough and nested branches to the current block label.

A focused replay over the post-rebase collapsed refresh measured:

- `3,698` changed-signature definitions considered;
- `1,383` definitions with removed locals;
- `1,118` fallback-cleanup removals;
- `3,698` accepted definitions;
- `0` rejected definitions;
- defined Func `94` no longer rejected.

This is a targeted repair, not permission to bypass validation. Every candidate still goes through shared-module-context batch validation and later selected-definition validation.

## Validator hardening

The first full artifact after only the cleanup repair exposed a second safety owner. It produced raw `3,114,958`, but external validation rejected absolute Func `8208` / defined Func `8187`: an outer `i32` result block could also complete through an inner block-local branch carrying a reference result. Starshine's validator accepted the invalid shape because unconditional `br` recorded only the terminal escape, not the reachable target depth needed when another control path continued.

A red validator test now covers an inner block-local reference branch that makes an outer `i32` result mismatch reachable. Unconditional `br` now records its reachable escape label just like `br_if`, `br_table`, and the reference-branch instructions. The structured merge can therefore distinguish:

- a branch consumed by the current block label;
- a branch escaping to a parent label;
- a normal fallthrough result;
- alternate paths that make the current block result observable.

The stronger validator immediately rejects the diagnostic invalid artifact at Func `8208` with `type mismatch`. It also exposed twelve pre-existing test fixtures that were invalid under external WebAssembly validation because a branch-completed wrapper lacked a required trailing result or a `return` lacked its operand. Those fixtures were repaired forward with the missing branch payload, trailing local read, fallthrough value, or return operand; no behavior test was disabled.

In the final trace, defined Func `8187` reaches nested cleanup but is retained as `accepted=false`, while valid sibling cleanup remains admitted.

## Current fixed-artifact evidence

Artifact:

- `.tmp/daeo-block-fallthrough-validator-fix-v131-20260719/starshine.raw.wasm`
- artifact-driving native binary SHA-256 `61538f9aca02f0d789fb5ececb612e386908b2832004970e291c107880fad1dd`
- raw SHA-256 `383c246cc84ffb3ceb8092da1fb653f582707033d331706e4bbbafaca1f6c426`
- canonical SHA-256 `45249b232610d4603dc2ea3a4d9fc36f6f8235a475693bd4f997069d8001ddcb`
- raw size `3,114,606`
- canonical size `3,172,896`
- wall time `1,241s`
- pass timer `1,239,983,329us`
- second invocation `11s`, byte-identical

Binaryen v131 reference remains:

- explicit oracle/canonicalizer `.tmp/binaryen-v131-download/binaryen-version_131/bin/wasm-opt`, reporting `wasm-opt version 131`, SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`;
- raw `3,176,505`, SHA-256 `b480c6db68326353022553ee3753869aed19ebcd8b1075f742818319f5475ade`;
- canonical `3,261,396`, SHA-256 `98283f73d69e4bcab17df75f9370b6c0d3720a196d4e0b7f6bfa44d0e0ca7566`

Current module deltas:

| measure | Starshine delta |
|---|---:|
| raw module | `-61,899` |
| canonical module | `-88,500` |
| canonical type section | `-776` |
| canonical function section | `-1` |
| canonical element section | `-2` |
| canonical code section | `-87,721` |

Canonical function-body ledger:

- `2,930` Starshine-larger bodies totaling `+56,460` bytes;
- `2,578` Starshine-smaller bodies totaling `-144,178` bytes;
- `7,654` equal bodies;
- net body-payload delta `-87,718` bytes;
- the code-section delta differs by `-3` because body-size LEB encodings also change.

Relative to note `1650`, the current endpoint improves:

- raw module by `20,093` bytes;
- canonical module by `21,651` bytes;
- canonical gross-positive bodies by `8,576` bytes;
- Func `41` by `545` bytes (`+1,540 -> +995`);
- Func `7919` by `298` bytes (`+688 -> +390`);
- Func `7007` by `284` bytes (`+664 -> +380`);
- Func `6377` by `227` bytes (`+663 -> +436`);
- Func `2385` by `319` bytes (`+590 -> +271`);
- Func `8187` by `319` bytes (`+375 -> +56`);
- Func `5582` by `293` bytes (`+347 -> +54`);
- Func `8185` by `373` bytes (`+305 -> -68`).

The current top canonical-positive bodies are:

1. Func `41` `+995`
2. Func `7556` `+656`
3. Func `9639` `+492`
4. Func `1247` `+465`
5. Func `6377` `+436`
6. Func `1111` `+435`
7. Func `7919` `+390`
8. Func `7007` `+380`
9. Func `7957` `+349`
10. Func `5525` `+299`
11. Func `1458` `+286`
12. Func `6122` `+285`
13. Func `1815` `+271`
14. Func `2385` `+271`
15. Func `4921` `+268`
16. Func `122` `+266`
17. Func `7534` `+235`
18. Func `998` `+231`
19. Func `307` `+228`
20. Func `904` `+217`

This is a substantial Starshine module-size win, but direct output parity remains open because every `+56,460` gross-positive body byte still requires closure or a measured Starshine benefit.

## Canonical remap ledger

Canonicalization now worsens `704` raw differentials by `+4,922` bytes. `75` functions cross from raw parity-or-better to canonical-positive, totaling `+341` canonical bytes. The largest crossings remain:

- Func `6450`: raw `-1`, canonical `+56`;
- Func `3222`: raw `-2`, canonical `+31`;
- Func `6133`: raw `-13`, canonical `+24`;
- Func `5336`: raw `0`, canonical `+16`;
- Func `6358`: raw `-1`, canonical `+11`.

The remap ledger improves slightly from note `1650`, but it remains a separate open output-parity owner.

## Runtime and trace ledger

The final trace records:

- `7,840` broad changed-boundary events;
- `3,812` local-cleanup definitions;
- zero broad local-cleanup rollback/reject events;
- `87` all-changed `remove-unused-brs` markers;
- `847` nested-total timer events;
- `322` large uniform-constant revisits;
- final convergence `3,114,711 -> 3,114,606`.

Runtime remains independently red:

- total DAEO pass timer `1,239,983,329us`;
- nested cleanup `942,589,624us`;
- post-cleanup core `16,707,498us`;
- fixed-loop aggregate `21,528,069us`.

The validator and local-cleanup repairs improve output but do not close scheduler performance. Pass-local time is about `44.565s` slower than note `1650`.

## Generated v131 renewal

Current targeted lane:

- `.tmp/pass-fuzz-daeo-post-rejected-loop-revert-v131-1024-20260719`
- seed `0x5eed`
- `1,024/1,024` compared
- `695` normalized matches
- `329` normalized differences
- zero validation, property, generator, or command failures
- Binaryen cache `1,024/0`

All `329` differences remain byte-identical to the previous generated lane and raw-smaller for Starshine:

- computed-effects: `83 * -20 = -1,660`;
- forwarded-suffix: `57 * -7 = -399`;
- immutable-field: `71 * -11 = -781`;
- table-effects: `58 * -6 = -348`;
- touched-caller: `60`, aggregate `-830`;
- total `-4,018` raw bytes.

This renews the targeted generated family matrix only. It does not replace the required regular `100000`, dedicated `10000`, wasm-smith `10000`, and random-all `10000` semantic matrix.

## Validation

Current green checks:

- `moon fmt` completed with unrelated `moon.mod` drift restored;
- `moon info` passed with warnings only;
- pass-manager white-box `295/295`;
- focused DAEO `348/348`;
- validator `176/176`;
- full Moon `9,495/9,495`;
- targeted generated compare `1,024/1,024`;
- raw/canonical Starshine and Binaryen outputs validate with `wasm-tools validate --features all`;
- direct second invocation is byte-identical;
- the final formatted/commented native rebuild has SHA-256 `1692cf34c541a95279d05dae91a20f7e79add719cdd2064c80a6687cabd1d0a9` and reproduces the same byte-identical fixed point;
- the post-rejected-loop-experiment rebuild has SHA-256 `dec3910f173d6b37c9dd423d413234af107ee399029923b5520031227d4b596e` and also reproduces that fixed point byte-for-byte;
- `git diff --check` is clean.

The invalid intermediate `.tmp/daeo-block-fallthrough-fix-v131-20260719` is diagnostic-only and must not be used as positive evidence.

## Rejected loop-aware coalescing follow-up

A follow-up experiment widened `coalesce-locals` from the exact loop copy/unread-local fallback to a branch-aware loop liveness graph. The first artifact probes exposed why this cannot be admitted as a generic widening yet: Starshine's selected-function validator accepted candidates that `wasm-tools validate --features all` rejected for definite initialization, including absolute Func `8109` with `uninitialized local: 2`. Adding a nondefaultable-local barrier made the standalone probe `.tmp/daeo-loop-aware-coalesce-probe5-20260719/coalesced.wasm` externally valid and reduced the current DAEO output by `42,505` bytes, from `3,114,606` to `3,072,101`, but required `469s` for the standalone pass.

The integrated DAEO experiment `.tmp/daeo-loop-aware-coalesce-v131-20260719` was also externally valid, but regressed every admission metric that matters for this slice:

- raw `3,115,038`, or `+432` versus the current accepted artifact;
- canonical `3,173,702`, or `+806`;
- canonical gross-positive bodies `+57,376`, or `+916`;
- Func `41` `+1,030`, or `+35`;
- pass timer `2,034,484,152us`, or `+794,500,823us`;
- nested cleanup `1,556,860,063us`, or `+614,270,439us`;
- `703` remap increases totaling `+4,655`, a small remap improvement that does not offset the body-size and runtime regressions.

The accompanying `1024`-case generated lane `.tmp/pass-fuzz-daeo-loop-aware-coalesce-v131-1024-20260719` remained byte-identical to the accepted generated lane (`695` matches, `329` raw Starshine wins totaling `-4,018`, zero failures), so it did not expose a compensating behavior gain. The widening, deep-clone/retention experiment, and forward expectations were reverted. The accepted `3,114,606` / `3,172,896` artifact remains authoritative; future loop coloring needs exact definite-initialization state, per-family profitability, and a scheduler that does not add hundreds of seconds.

## Remaining work

1. Reduce the `+56,460` canonical gross-positive body ledger, beginning with Funcs `41`, `7556`, `9639`, `1247`, `6377`, `1111`, `7919`, and `7007`.
2. Continue the full Func-`41` structured coloring/liveness reduction from the new `+995` baseline.
3. Reduce or source-backedly classify the `704` remap increases and `75` canonical-positive crossings.
4. Profile the additional accepted nested cleanup by pass/batch and reduce the `942.590s` nested owner without weakening validation.
5. Run the complete post-change four-lane semantic matrix.
6. Renew plain `dae` / `dae2` separately against Binaryen v131.
7. Continue recursive/shared type, multivalue, typed-control, GC refinement, tail-call, and escape breadth.
8. Return to late-HSO public optimize/shrink/O4z performance after direct DAEO parity and runtime improve.
