# 0695 — 2026-06-02 inlining current-main recheck

## Question

Did Binaryen current `main` drift from the existing `version_129` inlining / no-inline contract in any teaching-relevant way?

## Sources checked

- `docs/wiki/raw/binaryen/2026-04-23-inlining-primary-sources.md`
- `docs/wiki/raw/binaryen/2026-06-02-inlining-current-main-recheck.md`

## Finding

No teaching-relevant drift was found on the reviewed surfaces.

Observed current-main facts:

- the plain inliner still treats `@metadata.code.inline` as preserved annotation metadata, not as the practical suppression switch
- `Inlining.cpp` still gates full and partial inlining on `noFullInline` and `noPartialInline`
- `NoInline.cpp` still owns the wildcard `no-inline`, `no-full-inline`, and `no-partial-inline` policy passes
- `module-utils.cpp` still copies those flags when cloning functions
- the dedicated inline-hints and no-inline tests still prove the same annotation-vs-policy-vs-clone-survival split

## Durable update

The living inlining dossier pages now point at this recheck so future maintainers can see that the pass was reverified after the earlier 2026-05-23 bridge.
No semantic retcon was required; this is a freshness and reference-hygiene update only.

## Supersession note

This note extends the earlier 2026-05-23 `inlining` source note.
It does not replace the earlier algorithm or implementation-test explanations, which remain the canonical detailed contract pages.
