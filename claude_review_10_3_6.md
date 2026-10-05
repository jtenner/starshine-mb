# Starshine optimizer passes: correctness and mutation review (2026-10-03)

## How this review was done

- **Code reviewed:** `3d46f7e52` (`perf: store scalar CFG edges inline`).
- **Where repros ran:** a separate detached worktree (scratchpad `review-wt/`). Nothing in the main checkout was modified except this file.
- **Binaries:** native release `cmd.exe` and `fuzz.exe`, both built in that worktree.
- **Oracle:** Binaryen `wasm-opt version 133 (version_133)`, at `~/.local/share/mise/installs/github-web-assembly-binaryen/ersion_133/bin/wasm-opt`.
- **How bugs were found:**
  - Two fuzz sweeps over every pass that `bun scripts/pass-fuzz-compare.ts --list-passes` lists, both with `--semantic-oracle node-v2`:
    - **Sweep 1:** default `binaryen-oracle-portable` profile, 400 cases per pass. This profile has no calls, globals, memory or tables.
    - **Sweep 2:** `--gen-valid-profile semantic-optimizer-all`, 250 cases per pass.
  - Hand-written edge-case programs run through `-O1`…`-O4`, `-Os`, `-Oz` and single passes. These covered integer and float folding, trap ordering, GC, and exception handling.
  - Two review sub-agents read the pass sources and confirmed each candidate with a reduced `.wat`, comparing node execution of the original, Starshine and Binaryen.
- **What counts as a finding:** every finding below was reproduced. "Observed" values come from running the modules in node 25 (`WebAssembly.instantiate`), or from `wasm-tools validate --features all`.
- **Classification:** following AGENTS.md, every miscompile below is a **true semantic mismatch**: Binaryen v133 keeps the original behavior, Starshine does not. Every invalid-output finding is a **validation failure**. None of these is a parity gap or a Starshine win.

## Summary

| # | Severity | Pass(es) | Kind |
|---|---|---|---|
| 1 | Critical (infra) | Starshine validator (`src/validate`), so every pass | Accepts invalid stack shapes, so the final-validate safety net misses invalid pass output |
| 2 | High | merge-blocks, vacuum, code-folding, `-O3` (also coalesce-locals, code-pushing, simplify-locals-nonesting, precompute-propagate in fuzzing) | Invalid wasm emitted, exit 0 |
| 3 | High | code-folding | Invalid wasm emitted (tail fold into a typed block) |
| 4 | High | dae2 / dae2-optimizing | Invalid wasm emitted, exit 0; separate internal "invalid rewritten module" aborts |
| 5 | High | dae, dae-optimizing | Miscompile: param read only as a branch value is removed |
| 6 | High | dae | Miscompile: constant param removed without materializing the constant |
| 7 | High | optimize-instructions (via dae-optimizing / inlining-optimizing) | Miscompile: side effect reordered past a later `local.set` |
| 8 | High | simplify-locals, simplify-locals-notee (via inlining-optimizing) | Miscompile: effectful stack values reordered |
| 9 | High | precompute, precompute-propagate | Miscompile: "push op into select arms" peephole applies to the wrong select |
| 10 | High | simplify-globals-optimizing | Miscompile: `if` with an empty `then` always runs its `else` |
| 11 | High | simplify-globals-optimizing | Miscompile: read of a local folded to a value it gets only later |
| 12 | Medium | precompute-propagate, inlining-optimizing, simplify-globals-optimizing | Native abort (exit 134) |
| 13 | Medium | Starshine validator (legacy EH), so every pass | Valid `rethrow` through a block/`if` is rejected and invalid `rethrow` targets are accepted, so all passes refuse common legacy-EH modules |
| 14 | Low | CLI text input | Text parse errors are printed, then exit is 0 and output is still written |
| 15 | High | merge-locals | Miscompile: exceptional edges ignored, so a read is retargeted to a copy that was never written |
| 16 | High | ssa (and any exceptional-edge consumer of `ir/cfg.mbt`) | Miscompile: a throw inside a try body has no edge to its handler |
| 17 | High | ssa, ssa-nomerge (plus ~20 hot-pipeline scanner callers) | Miscompile: legacy `try` is invisible to the instruction scanner, so all reads become default 0 |
| 18 | High | ssa | Miscompile: a `br_if` nested in a `local.set` operand is missed by the root-only CFG |
| 19 | High | ssa-nomerge | Miscompile: a write is renamed but its read is not |
| 20 | High | merge-blocks, remove-unused-brs, dead-code-elimination, simplify-locals(-nostructure), precompute(-propagate), flatten | Miscompile: a nested value block ending in `return` is moved after later statements |
| 21 | High | coalesce-locals, precompute-propagate, optimize-instructions | Miscompile: a nested `br_if` is hoisted ahead of earlier effectful or trapping operands |
| 22 | High | coalesce-locals | Miscompile: a write still visible through `catch_all` is removed |
| 23 | High | flatten | Miscompile: `br_if` value evaluated out of order (stale temp read) |
| 24 | High | dead-code-elimination | Miscompile: `catch_all` edge ignored, so `unreachable` is inserted on a live path |
| 25 | High | remove-unused-brs, code-folding, dead-code-elimination | Invalid wasm (void construct left where a typed value is needed) |
| 26 | Medium | precompute(-propagate), coalesce-locals, remove-unused-brs, flatten, merge-blocks | Abort (exit 134), `Encode(CannotEncodeBottomValType)`, or an undeclared scratch local (caught by final validation) |

Sweep 1 found **no** semantic mismatches and no validation failures in any of its 67 passes; its profile does not exercise calls or globals. Sweep 2's richer profile surfaced the validation failures in #2–#4. The miscompiles #5–#11 and #15–#24 were found by targeted review and by the sub-agents' own generators, which are heavy on calls, globals and exception handling.

**Patterns behind most of these:**

- **Exception edges** are ignored or incomplete in `ir/cfg.mbt`, in `local_graph_build`, and in the hot-pipeline scanner's legacy `try` support (#15–#17, #22, #24).
- **Nested control flow inside operands** (`br_if`, value blocks ending in `return`) is moved across sibling operands or later statements (#5, #6, #18, #20, #21, #23).
- **Stack-form code** (values carried across statements, sets placed between push and consumer) is reordered or loses its `drop`s (#2, #4, #7, #8).
- **A validator** that is not strict enough after unreachable code (#1) lets the invalid-output bugs reach disk.

**Concurrent edits note:** the main checkout was clean at the start of this review. During the review, someone else (not this review) modified `src/validate/typecheck.mbt`, `src/cmd/cmd.mbt`, `src/passes/dead_argument_elimination2.mbt` and `agent-todo.md`, and added `src/validate/tc_*_wbtest.mbt` files (mtimes 00:45–02:01). All results here are against the clean commit `3d46f7e52` in the separate worktree. Re-check #1 and #13 against those in-flight validator edits.

---

## 1. The Starshine validator accepts invalid code after unreachable/polymorphic regions (critical, infra)

Starshine's final validation does not reject outputs that wasm-tools and the spec reject. Every "Starshine emits invalid wasm" finding below (#2, #3, #4) exits **0**, and `cmd.exe --validate <bad.wasm>` also exits 0 with no diagnostic.

```sh
cmd.exe --code-folding ub.wasm -o ub.o.wasm   # exit 0
wasm-tools validate ub.o.wasm                 # type mismatch: expected i32 but nothing on stack
cmd.exe --validate ub.o.wasm -o /dev/null     # exit 0, no error
```

Invalid shapes it accepts:

- **Missing result value.** `block (result i32) (block ... br_table 1 1 ... unreachable ...) end`, where the inner void block is the last thing in a typed block. Once the inner `block` ends, the stack is no longer polymorphic, so the outer block is missing its `i32`.
- **Leftover value.** `block (result funcref) ... end` left undropped at the end of a void function, when the block body ends in `unreachable`.
- **Wrong operand type.** `type mismatch: expected f32, found i32` after polymorphic code (#4).

**Why it matters:** the validator seems to let unreachability escape a structured block that no branch targets. The `validate_module(candidate).is_ok()` checks in passes, and the CLI's `final module validate`, then pass invalid modules. That hides every lowering bug in this family. AGENTS.md requires "every transform must produce a valid wasm module", but this repo's own gate cannot enforce it.

**Fix direction:** in `src/validate/typecheck.mbt`, end-of-block handling must reset the outer frame to the block's declared results. It must never carry the inner frame's `unreachable` flag outward. Add red tests that use the outputs from #2 and #3 as fixtures.

## 2. Values carried across statements after `unreachable` get the wrong `drop`s: invalid output from several passes and `-O3` (high)

Minimal input (`mbmin.wat`; valid per wasm-tools and Binaryen):

```wat
(module
  (table 1 funcref)
  (func (export "f")
    i32.const 0
    i32.const 0
    table.get 0
    i32.const 0
    table.fill 0
    block (result v128)
      unreachable
    end
    f32.const 2.5
    block
    end
    drop
    drop
    block (result funcref)
      block
        ref.null func
        i32.const 0
        br_table 1 1
      end
      unreachable
    end
    drop))
```

| Pass | wasm-tools validation of Starshine output |
|---|---|
| `--merge-blocks` | **invalid** (`values remaining on stack at end of block`) |
| `--vacuum` | **invalid** |
| `--code-folding` | **invalid** |
| `-O3` | **invalid**, exit 0 |
| `-O1`, coalesce-locals, code-pushing, simplify-locals-nonesting, precompute-propagate, remove-unused-brs, reorder-locals | valid on this reduced input |

- **Binaryen:** `wasm-opt -all -O3` on the same input gives valid output.
- **`--merge-blocks` output:** `... unreachable f32.const 2.5 drop block (result nullfuncref) ref.null nofunc i32.const 0 br_table 0 0 end`. Two `drop`s were removed: the one for the v128 value and the trailing one. A void function now ends with a `nullfuncref` on the stack.
- **`-O3` output:** keeps `block (result v128) unreachable end drop`, then leaves the final `block (result funcref) ... end` undropped.

**Root cause (likely):** lifting or lowering of stack-carried values, meaning values pushed in one "statement" and dropped several statements later, when the producer is an unreachable-typed block. The `drop` that consumes the carried value is matched to the wrong producer, or deleted as dead when the producer becomes `unreachable`.

**Fuzz evidence:** sweep 2 (`semantic-optimizer-all`, 250 cases per pass) had Starshine validation-failure counts of:

| Pass | Failures |
|---|---|
| code-folding | 241 |
| simplify-locals-nonesting | 183 |
| code-pushing | 130 |
| merge-blocks | 119 |
| coalesce-locals | 91 |
| precompute-propagate | 91 |

This family accounts for most of them. The artifacts are under `review-wt/.tmp/rv-sweep2/<pass>/failures/`.

## 3. code-folding emits invalid wasm when it folds a branch-table tail into a typed block (high)

```wat
(module
  (func (export "f") (param i32) (result i32)
    (block (result i32)
      (block
        (br_table 1 1 (i32.const 243) (local.get 0))
        (unreachable))
      (unreachable))))
```

`cmd.exe --code-folding` output (exit 0):

```
block (result i32)
  block
    i32.const 243
    local.get 0
    br_table 1 1
    unreachable
    i32.const 243      ;; invented
    drop
  end
end                    ;; outer block now lacks its i32, and the trailing `unreachable` is gone
```

- `wasm-tools validate` reports `type mismatch: expected i32 but nothing on stack`.
- Every other pass tested, and `-O1`/`-O3`, keep this input valid. Only code-folding breaks it.
- The same happens with a `drop (block (result funcref) ...)` variant.
- The fold seems to treat the outer block's trailing `unreachable` as a foldable tail shared with the `br_table` arm. It moves a copy of the branch value into the inner block and deletes the outer `unreachable`, which was what made the outer block validate.

## 4. dae2 / dae2-optimizing emit invalid wasm, or abort with "invalid rewritten module" (high)

- **Reproducer:** `d93r.wat` (185 lines; copy in the scratchpad, reduced from sweep-2 case 93). It is valid per wasm-tools.
- **Command:** `cmd.exe --dae2 d93r.wasm -o out.wasm` exits 0.
- **Result:** `wasm-tools validate` fails in func 4 with `type mismatch: expected f32, found i32`. The rewritten function ends `... local.get 0 drop i32.const 0 end return_call 4`: an `i32.const 0` was left where the removed f32 argument used to be.
- **What the input contains:** several `return_call`s followed by dead code, and stack values carried across statements. This is the same carried-value family as #2.

**Fail-closed variants:** cases 53, 94, 126 and 177 in sweep 2 abort with `dae2: invalid rewritten module: func[1]: function body result type mismatch: expected stack=[F64] actual stack=[I32]`. These fail closed (no bad output), but they are still rewrite bugs that the internal check happens to catch.

---

## 5. DAE removes a param whose only read is a branch value (high, miscompile)

- **Passes:** `--dae`, `--dae-optimizing`.
- **Where:** `src/passes/dead_argument_elimination.mbt`, in the "param unread" analysis.

```wat
(module
 (global $g (mut i32) (i32.const 1))
 (func (export "f") (result i32) (call $callee (global.get $g)))
 (func $callee (param i32) (result i32)
  (block $C (result i32) (br $C (local.get 0)))
  (local.set 0 (i32.const 5))))
```

| | `f()` |
|---|---|
| Original | 1 |
| wasm-opt v133 `--dae` | 1 |
| Starshine `--dae` | **0** |

- **What Starshine does:** it removes the param and turns it into a zero-initialized local.
- **Same bug with other branch forms:** `br_if` value (`agentB/e2.wat`), `br_table` value (`e3.wat`), and arithmetic on the branch result (`e5.wat`).
- **Inputs that come out correct:** a plain read followed by a write, and a branch-value read with no later write.
- **Why it is wrong:** the analysis seems to treat a `local.get` that is a `br`/`br_if`/`br_table` *value operand* as not reading the param when a later `local.set` exists. The value leaves through the branch, so the entry value is observable.
- **Frequency:** in the sub-agent's random generator, 7 of 40 seeds failed `--dae`.

## 6. DAE removes a constant param without putting the constant back (high, miscompile)

```wat
(module
 (global $g (mut i32) (i32.const 1))
 (func (export "f") (result i32) (drop (call $callee (i32.const 127))) (global.get $g))
 (func $callee (param i32) (result i32)
   (global.set $g (if (result i32) (global.get $g)
       (then (local.tee 0 (local.get 0))) (else (i32.const 0))))
   (block $B (result i32) (br_if $B (i32.const 0) (i32.const 0)))))
```

| | `f()` |
|---|---|
| Original | 127 |
| wasm-opt v133 | 127 |
| Starshine `--dae` | **0** |

- **Output:** the param becomes `(local i32)`, and no `local.set 0 (i32.const 127)` is inserted.
- **What is needed to trigger it:** both the self-tee in the `if` arm and the unrelated `br_if`-with-value block. Removing either one gives correct output. This points at the same branch-value modeling defect as #5, now on the constant-argument path.

## 7. optimize-instructions moves a side effect past a later `local.set` in stack-form code (high, miscompile)

```wat
(module
 (import "env" "log" (func $log (param i32)))
 (func $se (param i32) (result i32) (call $log (local.get 0)) (i32.const 0))
 (func (export "f") (result i32) (local i32)
    i32.const 1
    call $se
    i32.const 0
    i32.and
    i32.const 5
    i32.const 0
    i32.const 2
    call $se
    i32.const 0
    select
    local.set 0
    i32.add))
```

- **Observed:** original and Binaryen log `1, 2`. Starshine `--optimize-instructions` logs **`2, 1`**.
- **Output:** `i32.const 2 call $se local.set 0 i32.const 1 call $se drop i32.const 0 i32.const 5 i32.add`.
- **What goes wrong:** the `X & 0 → (drop X; 0)` rewrite is placed after the `select … local.set` statement that sits between X's push and its consumer.
- **Reach:** `--dae-optimizing` and `--inlining-optimizing` produce this stack shape themselves:
  - `agentB/o9.wat` under `--dae-optimizing` logs `2, 1, 2` instead of `1, 2, 2`.
  - Fuzz seed 83 under `--inlining-optimizing` ends with the wrong final global value.

## 8. simplify-locals reorders effectful values left on the stack (high, miscompile)

```wat
(module
 (import "env" "log" (func $log (param i32)))
 (func $se (param i32) (result i32) (call $log (local.get 0)) (local.get 0))
 (func (export "f") (result i32) (local i32 i32)
   i32.const 1
   call $se
   i32.const 2
   call $se
   local.set 1
   local.set 0
   local.get 1
   local.get 0
   i32.sub))
```

- **Observed:** original and Binaryen log `1, 2`. Starshine `--simplify-locals` (and `-notee`) logs **`2, 1`**. Output: `i32.const 2 call 1 i32.const 1 call 1 i32.sub`.
- **What goes wrong:** both sets are sunk into their gets, so the two calls now run in get order rather than push order. A set whose value was pushed *before* another pending effectful value must not be sunk past it.
- **Why this matters:** `--inlining` emits exactly `…; local.set 1; local.set 0` for multi-argument calls. Any inlined call with two or more side-effecting arguments is therefore miscompiled under `--inlining-optimizing`. `agentB/inl2.wat` shows this: `(call $order (call $se 1) (call $se 2))` logs `2, 1`.

## 9. precompute's "push an op into the select arms" peephole applies to the wrong select (high, miscompile)

- **Passes:** `--precompute`, `--precompute-propagate`.
- **Where:** `src/passes/precompute.mbt`:
  - `precompute_raw_try_partial_select_unary_tail` (~7263) assumes `out[base+2]` is the select condition, but never checks that it is a single zero-input producer.
  - `precompute_raw_try_partial_select_tail` (~7296, binary op) has the same flaw.
  - `precompute_raw_try_partial_select_condition_tail` (~7220) has the same unchecked shape (`out[base+4]`).

```wat
(module
 (global $g (mut i32) (i32.const 65535))
 (global $z (mut i32) (i32.const 0))
 (func (export "u") (result i32)
   (i32.eqz (select (i32.const 288) (global.get $g) (select (i32.const 5) (i32.const 0) (i32.const 1)))))
 (func (export "bl") (result i32)
   (i32.add (select (global.get $g) (global.get $z) (select (global.get $z) (i32.const 10) (i32.const 20))) (i32.const 1))))
```

| Function | Original / wasm-opt | Starshine `--precompute` |
|---|---|---|
| `u` | 0 | **288** |
| `bl` | 1 | **0** |

- **Output for `u`:** `288 g 5 1 0 select select`. The `eqz` was applied to the arms of the *inner* (condition) select.
- **Fix direction:** the stack-pattern matcher must check that each matched slot is one complete, zero-input expression, or work on the tree form.

## 10. simplify-globals-optimizing makes an `if` with an empty `then` always run its `else` (high, miscompile)

```wat
(module
 (import "env" "log" (func $log (param i32)))
 (global $g5 (mut i32) (i32.const -1))
 (global $p (mut i32) (i32.const 1))
 (func $w (global.set $p (i32.const 0)))
 (func (export "f")
  (if (block $B (result i32)
        (drop (br_if $B
          (block $C (result i32) (drop (br_if $C (i32.const 3) (global.get $g5))) (i32.const 0))
          (global.get $p)))
        (i32.const 0))
   (then)
   (else (call $log (i32.const 0))))))
```

- **Observed:** original and Binaryen do not log. Starshine `--simplify-globals-optimizing` reduces the body to `i32.const 0 call $log` and **logs 0**.
- **Correct value:** the condition is 3, so the empty `then` arm runs.
- **What is needed to trigger it:** `$g5` must be constant-propagated. Writing `(then (nop))` instead of an empty `then`, or propagating `$g5` in the source by hand, makes it correct.

## 11. simplify-globals-optimizing folds a local read to a value written later (high, miscompile)

- **Reproducer:** `agentB/r73.wat`.
- **Shape:** `(i32.shr_u (local.tee 1 (local.get 2)) (block … (loop (local.set 2 (i32.const 0)) …)))`, inside an `i32.store8` address.
- **Observed:** original and Binaryen store at address 3. Starshine reduces the function to `i32.const 0 i32.const 0 i32.store8`, so it stores at address 0 and leaves address 3 untouched.
- **Why it is wrong:** `local.get 2` runs *before* the loop's `local.set 2 0`, but its value is folded as 0.
- **What is needed to trigger it:** a write to a global (`$fuel`) that equals the global's init value, which enables the same-init-dead-set cleanup.

## 12. Native abort (exit 134) in precompute-propagate and friends (medium, crash)

```wat
(module
 (func $f3 (result i32) (local i32) (local i32)
  (local.tee 1 (block $B (result i32)
    (drop (br_if $B (if (result i32) (i32.const 0) (then (i32.const 0)) (else (i32.const 0))) (i32.const 0)))
    (i32.const 0)))))
```

- `cmd.exe --precompute-propagate cr3.wasm -o out.wasm` gives `Aborted (core dumped)`, exit 134, with no diagnostic.
- The same shape aborts `--inlining-optimizing` (seed 21) and `--simplify-globals-optimizing` (seeds 44, 48, 69); the repros are under `agentB/red*.wat`.

## 13. Legacy-EH `rethrow` depth is validated against the count of enclosing catches, not the label index (medium)

- **Where:** `src/validate/typecheck.mbt:1533` (`typecheck_rethrow`), together with `legacy_catch_depth` (incremented only per catch body at ~1693). It compares the raw label index to the number of enclosing catch bodies. The spec requires the label at that index to *be* a catch label, where the index counts all enclosing labels.

**Valid module, rejected** (accepted by Binaryen v133, wasm-tools and V8; returns 1000 in node):

```wat
(try (result i32)
  (do (throw $t (local.get $x)))
  (catch $t (drop) (try (result i32) (do (rethrow 1)) (catch_all (i32.const 1000))))
  (catch_all (i32.const 1)))
```

Also rejected: `(catch_all (if (local.get $x) (then (rethrow 1))) …)`. That is the standard shape of C++/Emscripten legacy-EH output.

**Every pass** fails on such input with `final module validate: ... invalid legacy rethrow catch depth`, including `-O1`/`-O3`, flatten, merge-blocks, simplify-locals, inlining-optimizing and remove-unused-names (`rt4.wat`).

**Invalid module, accepted:** `(catch_all (if (local.get $x) (then (rethrow 0))) …)`. Here label 0 is the `if`, not a catch. Binaryen and wasm-tools reject it. `cmd.exe -O3` writes it out unchanged with exit 0, and `cmd.exe --validate` accepts it.

**Pass-level consequence:** the IR effectively treats `rethrow`'s immediate as a catch depth. Any pass that adds or removes a block or `if` between a catch and a nested `rethrow` would emit a wrong immediate, and the validator would not notice. I did not find a pass that does this on inputs Starshine currently accepts, because the bug above blocks those inputs. Once the validator is fixed, merge-blocks, remove-unused-names, vacuum, code-pushing and flatten need audit and tests for rethrow index adjustment.

## 14. CLI: text-input parse errors still exit 0 and write output (low)

- **Input:** `rt3.wat`, an invalid `rethrow 0` inside an `if`.
- **What happens:** `cmd.exe -O3 rt3.wat -o out.wasm` prints two parse errors (Starshine's own `invalid rethrow depth` and a fallback `unknown operator or unexpected token`). It still exits **0** and writes `out.wasm`, which is invalid per wasm-tools.
- **Same family:** the sub-agent saw `cmd.exe --intrinsic-lowering il.wat` fail with `DecodeAt(InvalidCompType, 8, 25)`, while the same module as `.wasm` works. The text→binary path appears to mis-encode a typed function-reference param.

**Related validator false positive (sub-agent A, `agentA/rt1.wat`):** values left on the polymorphic stack after `br` inside a void `if` are reported as a stack underflow at a following `select`. This makes every pass, even `--reorder-locals` or `--untee`, refuse that valid input. A legacy `rethrow 3` targeting an outer catch from an inner `do` is also rejected (`agentA/red_ss13.wat`, same root cause as #13).

---

## 15. merge-locals ignores exception flow (high, miscompile)

- **Where:** `src/passes/merge_locals.mbt:838,846` builds both its before and after graphs with `@ir.local_graph_build`, which leaves out exceptional edges (`ir/local_graph.mbt:1241`, `include_exceptional=false`). Its own check after rewriting therefore has the same blind spot.

```wat
(module (import "env" "log" (func $log (param i32) (result i32))) (tag $t (param i32))
 (func $thr (param i32) (if (local.get 0) (then (throw $t (i32.const 42)))))
 (func (export "b") (param $p i32) (result i32) (local $x i32) (local $y i32)
  (local.set $x (call $log (i32.const 1)))
  (block $h (try_table (catch_all $h)
    (call $thr (local.get $p))
    (local.set $y (local.get $x))))
  (local.get $x)))
```

- **Observed:** with `log` returning its argument, `b(1)` gives original 1, Binaryen 1, Starshine **0**. The final read was retargeted to `$y`, which is never written when `$thr` throws. Verified again in this review.

## 16. The CFG has no exceptional edge from a throwing instruction inside a try body (high, miscompile)

- **Where:** `ir/cfg.mbt` around lines 884–1015 adds the handler edge only from the block *before* the `try`/`try_table`. Writes made inside the body before a throwing call therefore never reach the catch path in `local_graph_build_full_flow` (`ssa.mbt:736`, `pass_manager.mbt:32256`).

```wat
(module (tag $t (param i32))
 (func $thr (param i32) (if (local.get 0) (then (throw $t (i32.const 42)))))
 (func (export "c") (param $p i32) (result i32) (local $x i32)
  (local.set $x (i32.const 1))
  (block $h (try_table (catch_all $h)
    (local.set $x (i32.const 3))
    (call $thr (local.get $p))
    (local.set $x (i32.const 2))))
  (local.get $x)))
```

- **Observed:** `--ssa`, `c(1)`: original 3, Binaryen 3, Starshine **1**.

## 17. The hot-pipeline instruction scanner skips legacy `try`, so reads become constant 0 (high, miscompile)

- **Where:** `run_hot_pipeline_instr_scan_impl` (`pass_manager.mbt` ~2893–3009) recurses into Block, Loop, If and TryTable but has no `@lib.Try` arm. It reports `has_writes=false`, and the `default-local-reads-no-write-fallback` path (~32140–32185) then replaces every local read with its default value. `ssa_full_raw_rewrite_body` (`ssa.mbt:503`) also has no `Try` arm.

```wat
(module (tag $t (param i32))
 (func $thr (param i32) (if (local.get 0) (then (throw $t (i32.const 42)))))
 (func (export "a") (param $p i32) (result i32) (local $x i32)
  (try (do (call $thr (local.get $p)) (local.set $x (i32.const 7))) (catch_all))
  (local.get $x)))
```

- **Observed:** `--ssa` and `--ssa-nomerge`, `a(0)` (the path with no throw): original 7, Binaryen 7, Starshine **0**. Verified again in this review.
- **Wider exposure:** the scanner has about 20 callers. Its `has_branches`, `may_fallthrough` and DCE-candidate summaries are wrong for any function that contains legacy `try`.

## 18. ssa misses a `br_if` nested inside a `local.set` operand (high, miscompile)

- **Where:** `ssa.mbt:735` and `pass_manager.mbt:32256–32259` call `cfg_build` without `expand_operand_control=true`. The comment at `precompute.mbt:11606` already says the root-only graph misses this case.

```wat
(module (func (export "f") (param $p i32) (result i32) (local $x i32)
  (local.set $x (i32.const 5))
  (drop (block $v (result i32)
    (local.set $x (if (result i32) (local.get $p)
      (then (br_if $v (i32.const 0) (i32.const 1))) (else (i32.const 0))))
    (i32.const 0)))
  (local.get $x)))
```

- **Observed:** `f(1)`: original 5, Binaryen 5, Starshine **0**. It reads a fresh local that is never written.

## 19. ssa-nomerge renames a write but not its read (high, miscompile; root cause not located)

```wat
(module (import "env" "log" (func $log (param i32) (result i32))) (memory 1)
 (func $f (param $p i32) (result i32) (local $x i32)
  (drop (call $log (i32.const 0)))
  (block $b (local.set $x (if (result i32) (i32.const 1)
     (then (local.get $p)) (else (i32.load (i32.const 0))))))
  (drop (call $log (i32.const 0)))
  (local.get $x))
 (func (export "m") (param $p i32) (result i32) (call $f (local.get $p))))
```

- **Observed:** `m(5)`: original 5, Binaryen 5, Starshine **0**. The output has `local.set 2` but `local.get 1`.
- **Path taken:** the trace shows `structured-local-writes`, in `ssa_nomerge_run` (`ssa_nomerge.mbt:850`) followed by `@ir.ssa_destroy_into_hot`.

## 20. A nested value block that always returns is moved after later statements (high, miscompile; several passes)

```wat
(module (global $g (mut i32) (i32.const 0)) (memory 1)
 (func $f (param $p i32) (result i32)
  (i32.store8 (i32.const 0) (i32.and (block (result i32) (return (i32.const 0))) (i32.const 0)))
  (global.set $g (local.get $p)) (i32.const 0))
 (func (export "m") (param $p i32) (result i32) (i32.add (call $f (local.get $p)) (global.get $g))))
```

- **Observed:** `m(5)`: original 0, Binaryen 0. Starshine returns **5** under `--remove-unused-brs` (verified again), `--dead-code-elimination` and `--merge-blocks`. The `return` is deleted or moved, so the dead `global.set` runs.
- **Variants:**
  - `(drop (i32.add 0 (i32.or (block (result i32) (return 0)) 0))) (drop (call $log 1))` makes merge-blocks and DCE call `log(1)`, which the original never does.
  - `agentA/sl5.wat` makes simplify-locals and simplify-locals-nostructure hoist a call above the `return`.
- **Suspected shared cause:** how a nested typed block that never falls through is lifted and re-emitted. `merge_blocks.mbt:172-180` notes that HOT can place values after the terminator.

## 21. A nested `br_if` is hoisted ahead of earlier side-effecting or trapping operands (high, miscompile)

Coalesce-locals (`agentA/co8.wat`):

```wat
(module (func (export "f") (param $p i32) (result i32) (local $a i32) (local $b i32)
  (if $o (i32.eqz (i32.const 0))
   (then (br_table $o $o (block $v (result i32)
      (local.set $a (select (local.tee $b (local.get $p))
                            (br_if $v (i32.const 0) (local.get $p)) (i32.const 0)))
      (i32.const 0))))
   (else (loop $L)))
  (local.get $b)))
```

- **Observed:** `f(5)`: original 5, Binaryen 5, Starshine **0**. The earlier `local.tee $b` is skipped when the hoisted `br_if` is taken. Verified again in this review.
- **Tell-tale output:** `br_if …; local.set N; drop; local.get N`.
- **Same pattern in precompute-propagate** (`agentA/pp4.wat`): a `i32.rem_u … 0` trap ordered before a taken `br_if` disappears. The original traps; Starshine returns 0.
- **Same pattern in optimize-instructions:** `(drop (i32.add (call $log 1) (br_if $v 0 (local.get $p))))` inside a value block loses the `log(1)` call.

## 22. coalesce-locals removes a write that is still visible through `catch_all` (high, miscompile)

```wat
(module (tag $t)
 (func $thr (param i32) (if (local.get 0) (then (throw $t))))
 (func (export "f") (result i32) (local $unused i32) (local $x i32)
  (loop $L (if (i32.const 0) (then) (else (local.set $x (i32.const 77)))))
  (block $h (try_table (catch_all $h)
    (call $thr (if (result i32) (i32.const 0) (then (i32.const 0)) (else (i32.const 3))))
    (local.set $x (i32.const 0))))
  (local.get $x)))
```

- **Observed:** original 77, Binaryen 77, Starshine **0**. The output contains `i32.const 77; drop`.
- It needs the loop and the extra leading local to trigger, which suggests a raw fast path in `coalesce_locals.mbt`.

## 23. flatten evaluates a `br_if` value in the wrong order (high, miscompile)

```wat
(module (memory 1)
 (func (export "f") (result i32) (local $x i32) (local $q i64)
  (i64.store (i32.const 0) (i64.const -1))
  (local.set $x (block $v (result i32)
    (local.set $q (i64.load8_s (i32.const 0)))
    (br_if $v (i32.wrap_i64 (local.get $q)) (i32.const 0))))
  (local.get $x)))
```

- **Observed:** original -1, Binaryen -1, Starshine **0**. A stale temp is pushed before it is set.
- **Variant:** `(call $log (br_if $v (local.get $p) (i32.const 0)))` makes Starshine log 0 instead of `$p`.
- **Suspected location:** `flatten.mbt` `FlattenScalarBrIfFlowEntry` / `flatten_rewrite_scalar_br_if_flow_sites`.

## 24. dead-code-elimination ignores a `catch_all` edge and inserts `unreachable` (high, miscompile)

```wat
(module (tag $t)
 (func $thr (param i32) (if (local.get 0) (then (throw $t))))
 (func (export "f") (result i32) (local $x i32)
  (local.set $x (block $h (result i32)
    (try_table (block $h2 (try_table (catch_all $h2)
        (call $thr (i32.const 1)) (return (i32.const 5)))))
    (i32.const 9)))
  (i32.add (local.get $x) (i32.const 100))))
```

- **Observed:** original 109, Binaryen `--dce` 109. Starshine **traps** (`unreachable`).

## 25. Invalid wasm: a void construct is left where a typed value is required (high)

**remove-unused-brs:**

```wat
(module (func (export "f") (result i32)
  (if $outer (i32.const 0) (then)
   (else (if (block (result i32) (br_table $outer $outer (i32.const 0))) (then))))
  (i32.const 7)))
```

- **Output:** `block (result i32) { block { i32.const 0; drop; br 2 } }`.
- **Rejected by:** wasm-tools ("expected i32 but nothing on stack") and V8 ("expected 1 elements on the stack for fallthru"). Verified again in this review.
- **Frequency:** this was sub-agent A's most frequent fuzz hit, about 3% of its random modules.

**code-folding** (in the same family as #3):

```wat
(module (global $g (mut i32) (i32.const 0))
 (func (export "f") (result i32)
  (global.set $g (block $v (result i32) (block $b
     (return (if (result i32) (i32.const 0) (then (i32.const 0)) (else (i32.const 0)))))))
  (i32.const 1)))
```

- **Note:** build the input with wasm-opt, which adds the trailing `unreachable`.
- **Output:** a void `if` is the last item in `block (result i32)`, and the trailing `unreachable` is gone.

**dead-code-elimination:**

```wat
(module (func (export "f") (result i32) (local $x i32)
  (try_table (local.set $x (block (result i32) (return (i32.const 5)))))
  (i32.const 0)))
```

- **Output:** the `local.set` is removed, but its `block (result i32)` value stays inside a void `try_table`.
- **Rejected by:** wasm-tools and V8 (`agentA/dce1.wat` fails to compile in node, verified again). Binaryen's output is valid.

## 26. Crashes and self-detected invalid rewrites (medium)

- **`--precompute` / `--precompute-propagate`:** SIGABRT (exit 134) with no message on `agentA/pc1.wat`. The trigger is a `br_table` on an `if`, followed by a nested `br_if` with a value inside a `local.set` operand. This is related to #12.
- **`--coalesce-locals`:** fails with `Encode(CannotEncodeBottomValType)` on `agentA/enc1.wat`. The trigger is a loop whose `br_if` condition is `(block (result i32) (br_table …))`, followed by a select over a reinterpreted load. remove-unused-brs and flatten hit the same encode failure on other seeds.
- **`--merge-blocks` with legacy `try`:** uses a scratch local it never declares (`invalid local index`). Final validation catches this, so no output is written.

---

## Checked with no bug found

- **Sweep 1** (400 cases per pass, `binaryen-oracle-portable`, node-v2 three-way): 0 semantic mismatches and 0 validation failures across all 67 listed passes.
  - The large mismatch counts for coalesce-locals, constraint-analysis, dae2*, flatten, DFE and global-refining are shape or parity differences only. All of them were semantic-match. They were not classified further.
  - `global-type-optimization` and `i64-to-i32-lowering` were Binaryen command failures in both sweeps. The harness probably needs closed-world or flatten prerequisites for them.
- **Sweep 2:** `semantic-optimizer-all`, 250 cases per pass. Apart from the families above, no semantic mismatches were found.
  - The `blocked-starshine-runtime` outcomes in remove-unused-brs, redundant-set-elimination and DFE were all `starshine-tool-resource-uncertainty` (timeouts).
  - make-shared-objects validation failures are wasm-tools not decoding `ref.i31_shared` (already known). Its 3 `starshine-correctness-failure` / `starshine-runtime-or-interface-failure` cases (27, 122, 221) were **not triaged**.
- **Hand probes with no divergence:** 50 integer and float edge functions under `-O1/-O3/-Oz`, optimize-instructions, precompute, constraint-analysis and flatten+precompute-propagate. Values included INT_MIN div/rem, shift ≥ width, -0.0/NaN min/max/copysign, load offset wrap, extend/wrap, and `memory.grow` ordering.
  - GC heap2local / HSO / optimize-casts / local-subtyping / `-O*` (aliasing, escapes, casts, `ref.eq`).
  - EH try_table/catch, delegate, and a loop with catch_all retry.
  - constraint-analysis stale-binding attempts.
  - global-effects `resume` → `call` rewrite: read only, looks sound.
  - duplicate-import-elimination: read only. The default mode never merges.
  - type-group-cleanup: read only.
- **Sub-agent A also found nothing in:**
  - simplify-locals load/store/global/call/trap sinking.
  - rse, code-pushing, local-cse, vacuum, untee and reorder-locals around try_table.
  - tuple-optimization with multivalue.
  - `return_call` inside try_table.
  - pick-load-signs and avoid-reinterprets sign/width cases.
  - optimize-casts and local-subtyping.
- **Sub-agent B also found nothing in:** memory-packing, remove-unused-module-elements, directize, once-reduction, i64-to-i32-lowering saturating conversions, reorder-globals, DFE, merge-similar-functions, heap2local, HSO, GTO/GSI/global-refining, tail-call, inlining (early returns, `return_call`, EH), and default `-O`/`-O3` on 60 statement-level seeds.

## Repro artifacts

The scratchpad is not in the repo: `/tmp/claude-1000/-home-jtenner-Projects-starshine-mb/a8e71dfe-5a31-4612-9f80-2d4ae7c6b768/scratchpad/`.

| Path | Contents |
|---|---|
| `mbmin.wat`, `ub.wat`, `d93r.wat` | Reduced repros for #2, #3, #4 |
| `me/` | Hand probes, `run.sh` (Starshine vs Binaryen vs original), reducers `red.py` / `red2.py` |
| `agentB/` | Repros for #5–#12, with random generators `gen.py` / `gen2.py` and the reducer `reduce.py` |
| `agentA/` | Repros for #15–#26 (`t.sh <file.wat> <pass> '[[args]…]'` compares original, Starshine and Binaryen in node), with differential fuzzer `fuzz.py` / `gen*.py` and reducer `reduce.py` |
| `review-wt/.tmp/rv-sweep/`, `review-wt/.tmp/rv-sweep2/` | Full sweep outputs (`summary.txt`, per-pass `cases.jsonl`, failure bundles) |
