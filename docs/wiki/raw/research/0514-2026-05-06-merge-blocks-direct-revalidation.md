# 0514 - 2026-05-06 - `merge-blocks` direct revalidation

## Scope

This note closes the `merge-blocks` portion of the 2026-05-06 direct-pass revalidation backlog and refreshes the standing [`MB]003` maintenance evidence.

Inputs reviewed:

- `agent-todo.md` (`[AUD]002`, `[MB]003`)
- `docs/wiki/binaryen/passes/merge-blocks/index.md`
- `docs/wiki/binaryen/passes/merge-blocks/starshine-strategy.md`
- `docs/wiki/binaryen/passes/merge-blocks/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/raw/research/0513-2026-05-06-starshine-pass-audit.md`

## Validation commands

All commands were run on 2026-05-06 from the repo root.

```sh
moon update
moon info
moon fmt
moon test
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass merge-blocks --out-dir .tmp/pass-fuzz-merge-blocks --keep-going-after-command-failures --max-failures 200
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --merge-blocks
```

`moon update` was needed before Moon commands and the first compare rerun because the local registry clone was missing `moonbitlang/x`.

## Results

### Moon signoff

- `moon info`: completed with existing warnings only.
- `moon fmt`: completed, no work to do.
- `moon test`: `2798` tests passed, `0` failed.

### Direct pass-fuzz compare

Artifact directory: `.tmp/pass-fuzz-merge-blocks`

- requested cases: `10000`
- compared cases: `9975`
- normalized matches: `9975`
- mismatches: `0`
- validation failures: `0`
- generator failures: `0`
- command failures: `25`
- generator split: `4975` wasm-smith, `5000` gen-valid
- command-failure classes:
  - `binaryen-rec-group-zero`: `22`
  - `binaryen-bad-section-size`: `1`
  - `binaryen-table-index-out-of-range`: `1`
  - `binaryen-invalid-tag-index`: `1`

The command failures are Binaryen/tool command failures in wasm-smith lanes, not Starshine/Binaryen normalized-output mismatches. `gen-valid` completed all `5000` generated cases.

### Debug artifact direct compare

Command:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --merge-blocks
```

Result directory: `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1234180`

- canonical wasm equal: no
- normalized WAT text equal: no
- normalized WAT equal: yes
- canonical function compare equal: yes
- Starshine runtime: `1550.287 ms`
- Binaryen runtime: `1936.777 ms`
- Starshine pass runtime: `214.434 ms`
- Binaryen pass runtime: `1526.350 ms`
- Starshine at least as fast: yes
- Starshine pass at least as fast: yes

## Backlog decision

`merge-blocks` now has fresh post-fuzzer-change direct parity evidence and debug-artifact canonical-function evidence. Remove `merge-blocks` from `[AUD]002` and prune `[MB]003`; no active direct Starshine-side `merge-blocks` bug remains in the backlog. Future ordered-prefix work can still re-open a new item if neighboring late cleanup passes expose new drift.
