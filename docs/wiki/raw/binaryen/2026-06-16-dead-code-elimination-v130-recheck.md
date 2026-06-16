# Binaryen DCE v130 recheck

- Date: 2026-06-16
- Target: Binaryen `version_130` / `wasm-opt version 130 (version_130)`
- Local snapshots compared:
  - `.tmp/dce-v130-check/version_129/`
  - `.tmp/dce-v130-check/version_130/`

## Result

`version_130` does not change the `dce` pass contract relative to the previously reviewed `version_129` files.

Byte-identical between `version_129` and `version_130`:

- `src/passes/DeadCodeElimination.cpp`
- `test/lit/passes/dce_all-features.wast`
- `test/lit/passes/dce_vacuum_remove-unused-names.wast`
- `test/lit/passes/dce-eh.wast`
- `test/lit/passes/dce-eh-legacy.wast`
- `test/lit/passes/dce-stack-switching.wast`

`src/passes/pass.cpp` differs between the two snapshots, but the inspected diff does not change the `dce` registration or the pass contract. The visible differences are unrelated registry additions/typos and optimization-pipeline `closedWorld` to `worldMode` spelling changes.

## Commands

```sh
for f in \
  src/passes/DeadCodeElimination.cpp \
  src/passes/pass.cpp \
  test/lit/passes/dce_all-features.wast \
  test/lit/passes/dce_vacuum_remove-unused-names.wast \
  test/lit/passes/dce-eh.wast \
  test/lit/passes/dce-eh-legacy.wast \
  test/lit/passes/dce-stack-switching.wast; do
  if diff -q ".tmp/dce-v130-check/version_129/$f" ".tmp/dce-v130-check/version_130/$f" >/dev/null; then
    echo "same $f"
  else
    echo "diff $f"
  fi
done
```

Output:

```text
same src/passes/DeadCodeElimination.cpp
diff src/passes/pass.cpp
same test/lit/passes/dce_all-features.wast
same test/lit/passes/dce_vacuum_remove-unused-names.wast
same test/lit/passes/dce-eh.wast
same test/lit/passes/dce-eh-legacy.wast
same test/lit/passes/dce-stack-switching.wast
```

`pass.cpp` DCE registration check:

```sh
diff -u .tmp/dce-v130-check/version_129/src/passes/pass.cpp \
  .tmp/dce-v130-check/version_130/src/passes/pass.cpp | grep -C3 -i 'dead-code\|dce' || true
```

This produced no `dce` registration delta beyond diff headers.

## Reopening note

Future DCE audit work should cite `version_130` as the current source oracle. The older `version_129` research remains historically useful because the core DCE implementation and representative DCE lit files are byte-identical across these two local snapshots.
