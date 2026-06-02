# 0699 — 2026-06-02 Binaryen late-pipeline package-surface recheck

## Question

Do the external package surfaces that support `docs/wiki/binaryen/passes/late-pipeline-dispatch.md` still show the same lag and contradiction pattern as the earlier 2026-04-18 check?

## Sources checked

- `https://github.com/WebAssembly/binaryen/releases/tag/version_125`
- `https://github.com/WebAssembly/binaryen/blob/main/CHANGELOG.md`
- `https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+refs`
- `https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/refs/heads/main/CHANGELOG.md`
- `https://manpages.debian.org/experimental/binaryen/wasm-opt.1.en.html`
- `https://docs.rs/wasm-opt/latest/wasm_opt/enum.Pass.html`
- `https://docs.rs/wasm-opt/latest/wasm_opt/`
- `https://docs.rs/crate/wasm-opt-sys/latest/source/binaryen/README.md`

## Finding

The 2026-06-02 recheck still sees the same broad picture:

- `version_125` remains the newest public Binaryen release baseline.
- The Debian manpage still exposes a useful lower bound for late-pipeline pass names.
- The docs.rs enum page still omits some later upstream names, while the docs.rs crate overview overclaims completeness.
- The mirrored README excerpt still misspells `RemoveUnusedBrs`.

## Durable update

The living late-pipeline page should keep the package-surface caveat explicit and treat the current docs.rs / Debian / README surfaces as corroboration, not as authoritative completeness evidence. This recheck is a freshness update, not a release-horizon change.
