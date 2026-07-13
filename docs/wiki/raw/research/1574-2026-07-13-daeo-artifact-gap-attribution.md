# DAEO current-artifact size-gap attribution

Date: 2026-07-13

## Scope

This investigation attributes the valid but size-losing direct `dae-optimizing` output recorded by research note `1573`. It uses the same stripped wasm-gc input and retained Binaryen output, plus temporary uncommitted scheduler/core probes. No probe implementation was retained: the worktree was restored before this note was filed.

## Baseline

Input and retained outputs:

- input `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`: `3204405` bytes;
- current committed Starshine direct output `.tmp/daeo-scheduled-current-artifact-20260713/starshine-direct-recgroup-final.wasm`: `3201580` bytes;
- Binaryen direct output `.tmp/daeo-scheduled-current-artifact-20260713/binaryen-direct-daeo.wasm`: `3177421` bytes;
- raw gap: Starshine `+24159` bytes;
- canonical gap: Starshine `3278806` versus Binaryen `3262456`, or `+16350` bytes;
- canonical WAT gap: Starshine `179309098` versus Binaryen `178975283`, or `+333815` bytes;
- baseline Starshine pass-local `3327.318ms`; Binaryen pass-local `8083.49ms`.

A section parser over the canonical wasm isolates the net canonical gap:

| section | Starshine | Binaryen | Starshine delta |
|---|---:|---:|---:|
| type payload | `75339` | `78167` | `-2828` |
| function payload | `25327` | `25369` | `-42` |
| code payload | `2991167` | `2971947` | `+19220` |
| net module | `3278806` | `3262456` | `+16350` |

The code-section loss is therefore larger than the net module loss; Starshine's smaller type/function payloads offset `2870` bytes of it.

## Exact touched-set evidence

A temporary trace-only diagnostic identified `22`, not `23`, touched defined functions in the final committed behavior:

```text
[2,5,16,20,25,36,37,38,41,42,50,51,67,237,383,1754,1755,5212,8337,11555,11587,13161]
```

This corrects the `touched=23` wording in note `1573`; the retained final trace itself already says `touched=22`.

The largest inspected touched-function text delta is defined Func `41`:

- Starshine canonical WAT: `5236` lines / `144043` bytes;
- Binaryen canonical WAT: `3632` lines / `95571` bytes;
- delta: `+1604` lines / `+48472` WAT bytes;
- raw function-body payload: Starshine `7476` versus Binaryen `5397`, or `+2079` bytes.

The signature chain also exposes concrete Binaryen behavior still missed by the committed artifact output:

- Func `37`: Starshine keeps three params; Binaryen keeps two and refines the second to an exact reference;
- Func `38`: Starshine keeps three params; Binaryen keeps two and refines the second to an exact reference;
- Func `41`: Starshine keeps the nullable third param; Binaryen removes it and refines the second param to an exact reference;
- Func `11555`: Starshine keeps two `i32` params; Binaryen keeps one;
- Func `11587`: Starshine keeps three params; Binaryen keeps two;
- Func `164`, reached through Func `39`: Binaryen removes all ten null/default wrapper params and folds the body from `224` canonical-WAT lines to `34`; committed Starshine does not reach that candidate under the bounded large-module schedule.

These are core candidate/refinement/convergence differences, not merely encoder drift.

## Controlled nested-cleanup probe

A temporary scheduler probe removed the coarse `>8 touched` skip, filtered the existing oversized-function hazard (`locals > 128` or instructions `> 1000`), and also filtered nondefaultable-local functions after an unrestricted attempt produced invalid output. The valid probe output is:

- `.tmp/daeo-scheduled-current-artifact-20260713/starshine-direct-filtered2.wasm`;
- raw `3201586`, which is `+6` bytes versus committed Starshine;
- canonical `3278785`, which is `-21` bytes versus committed Starshine;
- canonical WAT `179308172`, which is `-926` bytes versus committed Starshine;
- pass-local `8435.761ms`, about `1.04x` Binaryen and still inside the repository `<=2x` ratio target.

Agent judgment: the skipped touched replay explains only `21/16350` canonical bytes (`0.13%`) of the baseline gap and worsens raw size by `6` bytes. It is not the principal owner and is not independently a signable Starshine win.

The unrestricted nondefaultable-local probe is explicitly rejected. It emitted `.tmp/daeo-scheduled-current-artifact-20260713/starshine-direct-filtered3.wasm`, which `wasm-tools validate --features all` rejected at absolute Func `258` with `uninitialized local: 10`. A preceding attempt also failed Starshine final validation at absolute Func `71`. Therefore the existing local-safety boundary cannot simply be deleted.

## Controlled core-convergence probes

### Fixed core cap `8 -> 64`

A temporary fixed-loop cap of `64` reached defined Func `164` at iteration `18`, but is not viable:

- output `.tmp/daeo-scheduled-current-artifact-20260713/starshine-direct-core64.wasm`;
- raw `3201935`, `+355` versus committed Starshine;
- canonical `3278370`, `-436` versus committed Starshine;
- canonical WAT `179297537`, `-11561` versus committed Starshine;
- pass-local `72787.434ms`, about `9.0x` Binaryen and far outside the repository target.

The output remained valid, but the broad repeated whole-module scan is both raw-size-losing and prohibitively slow. Increasing the fixed-loop cap is rejected.

### Large-module low-forwarded revisit, cap `16`

A second temporary probe enabled the existing first-`4096` low-forwarded-constant revisit on the large artifact with a bound of `16`. It reached Func `164` at revisit iteration `1`, proving that candidate starvation can be fixed without waiting for fixed-loop iteration `18`, but the current repeated-scan implementation is still too expensive:

- output `.tmp/daeo-scheduled-current-artifact-20260713/starshine-direct-lowrevisit16.wasm`;
- raw `3201644`, `+64` versus committed Starshine;
- canonical `3278550`, `-256` versus committed Starshine;
- canonical WAT `179304877`, `-4221` versus committed Starshine;
- pass-local `18322.992ms`, about `2.27x` Binaryen and outside the repository target.

This probe is also rejected as a landing candidate.

## Attribution and next implementation shape

Agent judgment:

1. The old `large-touched-set` nested skip is not the main artifact owner. Safe touched replay closes only `21` canonical bytes and adds `6` raw bytes.
2. The dominant inspected behavior gap is bounded large-module core scheduling/refinement: low exact/default candidates such as Func `164`, plus the downstream exact-reference and removable-parameter chain through Funcs `39`, `37`, `38`, and `41`.
3. Repeated whole-module rescans are not acceptable. Both the `64` fixed-loop and `16` low-revisit probes miss pass-local performance, and both increase raw bytes before the full Binaryen-shaped cleanup converges.
4. The next safe implementation should build a bounded candidate worklist from current direct-caller facts, process multiple low candidates per fact snapshot, refresh only affected facts, and preserve the current large-function/nondefaultable-local safety boundaries. It should then run only the cleanup needed to consume the resulting constant/default debris, rather than enabling every nested pass indiscriminately on unsafe functions.
5. Func `164` is the first concrete target because the efficient low-revisit probe reaches it immediately and Binaryen's result is source-contract-shaped: remove ten uniform null/default params, fold the wrapper body, refine the exact result, and then propagate that refinement through Funcs `39`, `37`, `38`, and `41`.

## Validation and status

- The committed source was restored after every probe; no experimental behavior remains in the worktree.
- The earlier full four-lane direct matrix from note `1573` remains current because no behavior was retained.
- No `.mbti` change was produced.
- DAEO remains active. The artifact gap is now more precisely attributed, but it is not closed and must not be described as a Starshine win.
