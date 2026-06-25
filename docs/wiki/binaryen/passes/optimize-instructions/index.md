---
kind: entity
status: supported
last_reviewed: 2026-06-20
sources:
  - ../../../raw/binaryen/2026-04-22-optimize-instructions-primary-sources.md
  - ../../../raw/binaryen/2026-05-05-optimize-instructions-current-main-recheck.md
  - ../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../raw/research/0131-2026-04-20-optimize-instructions-binaryen-research.md
  - ../../../raw/research/0248-2026-04-22-optimize-instructions-primary-sources-and-implementation-followup.md
  - ../../../raw/research/0444-2026-05-05-optimize-instructions-current-main-recheck.md
  - ../../../raw/research/0726-2026-06-19-optimize-instructions-o4z-behavior-inventory.md
  - ../../../raw/research/0727-2026-06-19-optimize-instructions-oi-b-baseline.md
  - ../../../raw/research/0728-2026-06-19-optimize-instructions-oi-c-raw-gates.md
  - ../../../raw/research/0729-2026-06-19-optimize-instructions-oi-d-default-scalars.md
  - ../../../raw/research/0730-2026-06-19-optimize-instructions-oi-e-sign-ext-facts.md
  - ../../../raw/research/0731-2026-06-19-optimize-instructions-oi-f-boolean-select-shells.md
  - ../../../raw/research/0732-2026-06-19-optimize-instructions-oi-g-byte-bulk-memory.md
  - ../../../raw/research/0733-2026-06-19-optimize-instructions-oi-g-wide-memory-fill.md
  - ../../../raw/research/0734-2026-06-19-optimize-instructions-oi-g-eight-byte-fill.md
  - ../../../raw/research/0735-2026-06-19-optimize-instructions-oi-g-local-fill.md
  - ../../../raw/research/0736-2026-06-19-optimize-instructions-oi-g-local-eight-fill.md
  - ../../../raw/research/0737-2026-06-19-optimize-instructions-oi-g-wider-memory-copy.md
  - ../../../raw/research/0738-2026-06-19-optimize-instructions-oi-g-memory-copy-boundaries.md
  - ../../../raw/research/0739-2026-06-19-optimize-instructions-oi-g-memory64-copy.md
  - ../../../raw/research/0740-2026-06-19-optimize-instructions-oi-g-memory64-fill.md
  - ../../../raw/research/0741-2026-06-19-optimize-instructions-oi-g-narrow-store-mask.md
  - ../../../raw/research/0742-2026-06-19-optimize-instructions-oi-g-i64-narrow-store-mask.md
  - ../../../raw/research/0743-2026-06-19-optimize-instructions-oi-g-const-memory-offset.md
  - ../../../raw/research/0744-2026-06-19-optimize-instructions-oi-g-memory64-const-offset.md
  - ../../../raw/research/0745-2026-06-19-optimize-instructions-oi-g-load-call-offset-boundary.md
  - ../../../raw/research/0746-2026-06-19-optimize-instructions-oi-g-commuted-store-mask.md
  - ../../../raw/research/0747-2026-06-19-optimize-instructions-oi-g-const-store-value.md
  - ../../../raw/research/0748-2026-06-19-optimize-instructions-oi-g-byte-fill-const-truncation.md
  - ../../../raw/research/0749-2026-06-19-optimize-instructions-oi-g-pointer-add-boundary.md
  - ../../../raw/research/0815-2026-06-20-optimize-instructions-oi-g-signext-store-boundary.md
  - ../../../raw/research/0816-2026-06-20-optimize-instructions-oi-g-effectful-memory-copy-boundary.md
  - ../../../raw/research/0817-2026-06-20-optimize-instructions-oi-g-signed-load-store-boundary.md
  - ../../../raw/research/0822-2026-06-20-optimize-instructions-oi-g-superset-store-mask.md
  - ../../../raw/research/0750-2026-06-19-optimize-instructions-oi-h-ref-func-call-ref.md
  - ../../../raw/research/0751-2026-06-19-optimize-instructions-oi-h-table-get-call-ref.md
  - ../../../raw/research/0752-2026-06-19-optimize-instructions-oi-h-select-ref-func-call-ref.md
  - ../../../raw/research/0753-2026-06-19-optimize-instructions-oi-h-argument-select-call-ref-boundary.md
  - ../../../raw/research/0754-2026-06-19-optimize-instructions-oi-h-fallthrough-call-ref.md
  - ../../../raw/research/0755-2026-06-20-optimize-instructions-oi-h-argument-select-call-ref-localization.md
  - ../../../raw/research/0756-2026-06-20-optimize-instructions-oi-h-call-ref-boundaries.md
  - ../../../raw/research/0811-2026-06-20-optimize-instructions-oi-h-call-indexed-table-get-boundary.md
  - ../../../raw/research/0757-2026-06-20-optimize-instructions-oi-i-ref-null-basics.md
  - ../../../raw/research/0758-2026-06-20-optimize-instructions-oi-i-ref-as-non-null.md
  - ../../../raw/research/0759-2026-06-20-optimize-instructions-oi-i-known-non-null.md
  - ../../../raw/research/0760-2026-06-20-optimize-instructions-oi-i-ref-as-func.md
  - ../../../raw/research/0761-2026-06-20-optimize-instructions-oi-i-null-ref-test-cast.md
  - ../../../raw/research/0762-2026-06-20-optimize-instructions-oi-i-successful-i31-test-cast.md
  - ../../../raw/research/0763-2026-06-20-optimize-instructions-oi-i-i31-supertype-test-cast.md
  - ../../../raw/research/0764-2026-06-20-optimize-instructions-oi-i-ref-func-test-cast.md
  - ../../../raw/research/0765-2026-06-20-optimize-instructions-oi-i-i31-ref-eq.md
  - ../../../raw/research/0766-2026-06-20-optimize-instructions-oi-i-non-null-local-refs.md
  - ../../../raw/research/0767-2026-06-20-optimize-instructions-oi-i-non-null-local-test-cast.md
  - ../../../raw/research/0768-2026-06-20-optimize-instructions-oi-i-non-null-local-i31-supertype-test-cast.md
  - ../../../raw/research/0769-2026-06-20-optimize-instructions-oi-i-null-nonnull-test-cast-surface.md
  - ../../../raw/research/0770-2026-06-20-optimize-instructions-oi-i-impossible-i31-test-cast.md
  - ../../../raw/research/0771-2026-06-20-optimize-instructions-oi-i-impossible-i31-struct-eq.md
  - ../../../raw/research/0772-2026-06-20-optimize-instructions-oi-i-impossible-struct-array-eq.md
  - ../../../raw/research/0773-2026-06-20-optimize-instructions-oi-i-struct-array-supertype-test-cast.md
  - ../../../raw/research/0774-2026-06-20-optimize-instructions-oi-i-impossible-struct-array-test-cast.md
  - ../../../raw/research/0775-2026-06-20-optimize-instructions-oi-i-self-local-ref-eq.md
  - ../../../raw/research/0776-2026-06-20-optimize-instructions-oi-i-same-local-i31-ref-eq.md
  - ../../../raw/research/0777-2026-06-20-optimize-instructions-oi-i-noop-cast-ref-eq.md
  - ../../../raw/research/0778-2026-06-20-optimize-instructions-oi-i-as-non-null-ref-eq.md
  - ../../../raw/research/0779-2026-06-20-optimize-instructions-oi-i-double-noop-cast-ref-eq.md
  - ../../../raw/research/0780-2026-06-20-optimize-instructions-oi-i-upcast-ref-eq.md
  - ../../../raw/research/0781-2026-06-20-optimize-instructions-oi-i-i31-upcast-ref-eq.md
  - ../../../raw/research/0782-2026-06-20-optimize-instructions-oi-i-nullable-target-miss-test-cast.md
  - ../../../raw/research/0783-2026-06-20-optimize-instructions-oi-i-nullable-target-success-test-cast.md
  - ../../../raw/research/0784-2026-06-20-optimize-instructions-oi-i-nullable-source-non-null-target-miss-test-cast.md
  - ../../../raw/research/0785-2026-06-20-optimize-instructions-oi-i-nullable-source-nullable-target-success-test-cast.md
  - ../../../raw/research/0786-2026-06-20-optimize-instructions-oi-i-nullable-source-nullable-target-i31-success-test-cast.md
  - ../../../raw/research/0787-2026-06-20-optimize-instructions-oi-i-effectful-ref-i31-miss-test-cast.md
  - ../../../raw/research/0788-2026-06-20-optimize-instructions-oi-i-effectful-ref-eq-null.md
  - ../../../raw/research/0789-2026-06-20-optimize-instructions-oi-i-effectful-ref-is-null.md
  - ../../../raw/research/0790-2026-06-20-optimize-instructions-oi-i-effectful-ref-test-success.md
  - ../../../raw/research/0791-2026-06-20-optimize-instructions-oi-i-effectful-impossible-ref-eq.md
  - ../../../raw/research/0792-2026-06-20-optimize-instructions-oi-i-effectful-ref-as-non-null.md
  - ../../../raw/research/0793-2026-06-20-optimize-instructions-oi-i-effectful-known-null-ref-as-non-null.md
  - ../../../raw/research/0794-2026-06-20-optimize-instructions-oi-i-effectful-known-null-ref-test-cast.md
  - ../../../raw/research/0795-2026-06-20-optimize-instructions-oi-i-effectful-known-null-ref-eq.md
  - ../../../raw/research/0796-2026-06-20-optimize-instructions-oi-i-effectful-self-ref-eq.md
  - ../../../raw/research/0797-2026-06-20-optimize-instructions-oi-i-effectful-same-local-ref-i31.md
  - ../../../raw/research/0798-2026-06-20-optimize-instructions-oi-i-effectful-same-local-ref-as-non-null.md
  - ../../../raw/research/0799-2026-06-20-optimize-instructions-oi-i-effectful-same-local-ref-cast.md
  - ../../../raw/research/0800-2026-06-20-optimize-instructions-oi-i-effectful-nullable-source-nullable-target.md
  - ../../../raw/research/0801-2026-06-20-optimize-instructions-oi-i-effectful-nullable-source-non-null-target.md
  - ../../../raw/research/0802-2026-06-20-optimize-instructions-oi-i-effectful-non-null-source-nullable-target.md
  - ../../../raw/research/0803-2026-06-20-optimize-instructions-oi-i-effectful-ref-func-basics.md
  - ../../../raw/research/0804-2026-06-20-optimize-instructions-oi-i-effectful-nullable-i31-supertype.md
  - ../../../raw/research/0805-2026-06-20-optimize-instructions-oi-i-effectful-struct-array-ref-eq.md
  - ../../../raw/research/0806-2026-06-20-optimize-instructions-oi-i-effectful-i31-struct-local-ref-eq.md
  - ../../../raw/research/0807-2026-06-20-optimize-instructions-oi-i-effectful-non-null-source-non-null-target.md
  - ../../../raw/research/0808-2026-06-20-optimize-instructions-oi-i-effectful-non-null-aggregate-ref-is-null.md
  - ../../../raw/research/0809-2026-06-20-optimize-instructions-oi-i-nullable-i31-nonnull-target.md
  - ../../../raw/research/0810-2026-06-20-optimize-instructions-oi-i-known-null-nonnull-target.md
  - ../../../raw/research/0812-2026-06-20-optimize-instructions-oi-i-i31-array-local-ref-eq.md
  - ../../../raw/research/0813-2026-06-20-optimize-instructions-oi-i-same-heap-nonnull-ref-cast.md
  - ../../../raw/research/0814-2026-06-20-optimize-instructions-oi-i-indexed-i31-aggregate-ref-eq.md
  - ../../../raw/research/0818-2026-06-20-optimize-instructions-oi-j-exact-cast-boundary.md
  - ../../../raw/research/0819-2026-06-20-optimize-instructions-oi-j-exact-cast-already-exact.md
  - ../../../raw/research/0820-2026-06-20-optimize-instructions-oi-j-success-only-if-non-null-ref-test.md
  - ../../../raw/research/0821-2026-06-20-optimize-instructions-oi-j-descriptor-cast-boundary.md
  - ../../../raw/research/0823-2026-06-20-optimize-instructions-oi-k-struct-get-new.md
  - ../../../raw/research/0824-2026-06-20-optimize-instructions-oi-k-packed-struct-get-new.md
  - ../../../raw/research/0825-2026-06-20-optimize-instructions-oi-k-array-len-new-fixed.md
  - ../../../raw/research/0826-2026-06-20-optimize-instructions-oi-k-array-get-new-fixed.md
  - ../../../raw/research/0827-2026-06-21-optimize-instructions-oi-k-packed-array-get-new-fixed.md
  - ../../../raw/research/0828-2026-06-21-optimize-instructions-oi-k-struct-new-default.md
  - ../../../raw/research/0829-2026-06-21-optimize-instructions-oi-k-array-new-default-get.md
  - ../../../raw/research/0830-2026-06-21-optimize-instructions-oi-k-array-new-default-len.md
  - ../../../raw/research/0831-2026-06-21-optimize-instructions-oi-k-array-new-len.md
  - ../../../raw/research/0832-2026-06-21-optimize-instructions-oi-k-array-new-get.md
  - ../../../raw/research/0833-2026-06-21-optimize-instructions-oi-k-array-set-fresh.md
  - ../../../raw/research/0834-2026-06-21-optimize-instructions-oi-m-tuple-extract-make.md
  - ../../../raw/research/0811-2026-06-20-optimize-instructions-oi-h-call-indexed-table-get-boundary.md
  - ../../../raw/research/0842-2026-06-25-optimize-instructions-oi-g-extend-load.md
  - ../../../raw/research/0843-2026-06-25-optimize-instructions-oi-h-multivalue-arg-call-ref-boundary.md
  - ../../../raw/research/0844-2026-06-25-optimize-instructions-oi-g-load-memargs.md
  - ../../../raw/research/0845-2026-06-25-optimize-instructions-oi-h-multivalue-arg-return-call-ref-boundary.md
  - ../../../raw/research/0846-2026-06-25-optimize-instructions-oi-m-multiresult-sibling-boundary.md
  - ../../../raw/research/0847-2026-06-25-optimize-instructions-oi-g-local-carried-load-boundary.md
  - ../../../raw/research/0848-2026-06-25-optimize-instructions-oi-m-simplify-locals-neighbor.md
  - ../../../raw/research/0849-2026-06-25-optimize-instructions-oi-g-local-carried-store-boundary.md
  - ../../../raw/research/0850-2026-06-25-optimize-instructions-oi-g-byte-fill-call-raw-gate.md
  - ../../../raw/research/0851-2026-06-25-optimize-instructions-oi-g-reinterpret-store-memargs.md
  - ../../../raw/research/0852-2026-06-25-optimize-instructions-oi-g-wrap-store-memargs.md
  - ../../../raw/research/0854-2026-06-25-optimize-instructions-oi-g-wrap-store-multiuse-boundary.md
  - ../../../raw/research/0856-2026-06-25-optimize-instructions-oi-g-nonconst-load-call-boundary.md
  - ../../../raw/research/0853-2026-06-25-optimize-instructions-oi-m-multiresult-selected-boundary.md
  - ../../../raw/research/0855-2026-06-25-optimize-instructions-oi-m-selected-second-lane-boundary.md
  - ../../../raw/research/0857-2026-06-25-optimize-instructions-oi-m-full-simplify-boundary.md
  - ../../../raw/research/0858-2026-06-25-optimize-instructions-oi-g-parameterized-memory-copy.md
  - ../../../raw/research/0859-2026-06-25-optimize-instructions-oi-m-tuple-optimization-boundary.md
  - ../../../raw/research/0860-2026-06-25-optimize-instructions-oi-g-mixed-parameterized-memory-copy.md
  - ../../../raw/research/0861-2026-06-25-optimize-instructions-oi-g-parameterized-byte-fill.md
  - ../../../raw/research/0862-2026-06-25-optimize-instructions-oi-g-multiparam-bulk-memory.md
  - ../../../raw/research/0863-2026-06-25-optimize-instructions-oi-m-earlier-later-neighbor.md
  - ../../../raw/research/0864-2026-06-25-optimize-instructions-oi-g-global-bulk-memory.md
  - ../../../raw/research/0865-2026-06-25-optimize-instructions-oi-m-trapping-sibling.md
  - ../../../raw/research/0866-2026-06-25-optimize-instructions-oi-g-v128-memory-copy.md
  - ../../../raw/research/0867-2026-06-25-optimize-instructions-oi-m-selected-trapping-lane.md
  - ../../../raw/research/0868-2026-06-25-optimize-instructions-oi-g-v128-zero-memory-fill.md
  - ../../../raw/research/0869-2026-06-25-optimize-instructions-oi-m-selected-trapping-effectful-sibling.md
  - ../../../raw/research/0870-2026-06-25-optimize-instructions-oi-g-v128-nonzero-memory-fill.md
  - ../../../raw/research/0871-2026-06-25-optimize-instructions-oi-m-selected-trapping-earlier-sibling.md
  - ../../../raw/research/0872-2026-06-25-optimize-instructions-oi-g-zero-bulk-effects.md
  - ../../../raw/research/0873-2026-06-25-optimize-instructions-oi-m-selected-trapping-earlier-later-siblings.md
  - ../../../raw/research/0874-2026-06-25-optimize-instructions-oi-g-nonconstant-bulk-effects.md
  - ../../../raw/research/0875-2026-06-25-optimize-instructions-oi-m-selected-trapping-two-later-siblings.md
  - ../../../raw/research/0876-2026-06-25-optimize-instructions-oi-g-local-dynamic-bulk.md
  - ../../../raw/research/0877-2026-06-25-optimize-instructions-oi-m-selected-trapping-two-earlier-siblings.md
  - ../../../raw/research/0878-2026-06-25-optimize-instructions-oi-d-i64-signext-equality-boundary.md
  - ../../../raw/research/0879-2026-06-25-optimize-instructions-oi-m-selected-trapping-two-earlier-one-later.md
  - ../../../raw/research/0880-2026-06-25-optimize-instructions-oi-g-stack-v128-memory-copy.md
  - ../../../raw/research/0881-2026-06-25-optimize-instructions-oi-m-selected-trapping-two-earlier-two-later.md
  - ../../../../../src/passes/optimize_instructions.mbt
  - ../../../../../src/passes/optimize_instructions_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./gc-casts-call_ref-and-trap-sensitive-rewrites.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ../../../raw/binaryen/2026-04-22-optimize-instructions-primary-sources.md
  - ../../../raw/research/0726-2026-06-19-optimize-instructions-o4z-behavior-inventory.md
  - ../../../raw/research/0727-2026-06-19-optimize-instructions-oi-b-baseline.md
  - ../../../raw/research/0728-2026-06-19-optimize-instructions-oi-c-raw-gates.md
  - ../../../raw/research/0729-2026-06-19-optimize-instructions-oi-d-default-scalars.md
  - ../../../raw/research/0730-2026-06-19-optimize-instructions-oi-e-sign-ext-facts.md
  - ../../../raw/research/0731-2026-06-19-optimize-instructions-oi-f-boolean-select-shells.md
  - ../../../raw/research/0732-2026-06-19-optimize-instructions-oi-g-byte-bulk-memory.md
  - ../../../raw/research/0733-2026-06-19-optimize-instructions-oi-g-wide-memory-fill.md
  - ../../../raw/research/0734-2026-06-19-optimize-instructions-oi-g-eight-byte-fill.md
  - ../../../raw/research/0735-2026-06-19-optimize-instructions-oi-g-local-fill.md
  - ../../../raw/research/0736-2026-06-19-optimize-instructions-oi-g-local-eight-fill.md
  - ../../../raw/research/0737-2026-06-19-optimize-instructions-oi-g-wider-memory-copy.md
  - ../../../raw/research/0738-2026-06-19-optimize-instructions-oi-g-memory-copy-boundaries.md
  - ../../../raw/research/0739-2026-06-19-optimize-instructions-oi-g-memory64-copy.md
  - ../../../raw/research/0740-2026-06-19-optimize-instructions-oi-g-memory64-fill.md
  - ../../../raw/research/0741-2026-06-19-optimize-instructions-oi-g-narrow-store-mask.md
  - ../../../raw/research/0742-2026-06-19-optimize-instructions-oi-g-i64-narrow-store-mask.md
  - ../../../raw/research/0743-2026-06-19-optimize-instructions-oi-g-const-memory-offset.md
  - ../../../raw/research/0744-2026-06-19-optimize-instructions-oi-g-memory64-const-offset.md
  - ../../../raw/research/0745-2026-06-19-optimize-instructions-oi-g-load-call-offset-boundary.md
  - ../../../raw/research/0746-2026-06-19-optimize-instructions-oi-g-commuted-store-mask.md
  - ../../../raw/research/0747-2026-06-19-optimize-instructions-oi-g-const-store-value.md
  - ../../../raw/research/0748-2026-06-19-optimize-instructions-oi-g-byte-fill-const-truncation.md
  - ../../../raw/research/0749-2026-06-19-optimize-instructions-oi-g-pointer-add-boundary.md
  - ../../../raw/research/0815-2026-06-20-optimize-instructions-oi-g-signext-store-boundary.md
  - ../../../raw/research/0816-2026-06-20-optimize-instructions-oi-g-effectful-memory-copy-boundary.md
  - ../../../raw/research/0817-2026-06-20-optimize-instructions-oi-g-signed-load-store-boundary.md
  - ../../../raw/research/0822-2026-06-20-optimize-instructions-oi-g-superset-store-mask.md
  - ../../../raw/research/0750-2026-06-19-optimize-instructions-oi-h-ref-func-call-ref.md
  - ../../../raw/research/0751-2026-06-19-optimize-instructions-oi-h-table-get-call-ref.md
  - ../../../raw/research/0752-2026-06-19-optimize-instructions-oi-h-select-ref-func-call-ref.md
  - ../../../raw/research/0753-2026-06-19-optimize-instructions-oi-h-argument-select-call-ref-boundary.md
  - ../../../raw/research/0754-2026-06-19-optimize-instructions-oi-h-fallthrough-call-ref.md
  - ../../../raw/research/0755-2026-06-20-optimize-instructions-oi-h-argument-select-call-ref-localization.md
  - ../../../raw/research/0756-2026-06-20-optimize-instructions-oi-h-call-ref-boundaries.md
  - ../../../raw/research/0811-2026-06-20-optimize-instructions-oi-h-call-indexed-table-get-boundary.md
  - ../../../raw/research/0757-2026-06-20-optimize-instructions-oi-i-ref-null-basics.md
  - ../../../raw/research/0758-2026-06-20-optimize-instructions-oi-i-ref-as-non-null.md
  - ../../../raw/research/0759-2026-06-20-optimize-instructions-oi-i-known-non-null.md
  - ../../../raw/research/0760-2026-06-20-optimize-instructions-oi-i-ref-as-func.md
  - ../../../raw/research/0761-2026-06-20-optimize-instructions-oi-i-null-ref-test-cast.md
  - ../../../raw/research/0762-2026-06-20-optimize-instructions-oi-i-successful-i31-test-cast.md
  - ../../../raw/research/0763-2026-06-20-optimize-instructions-oi-i-i31-supertype-test-cast.md
  - ../../../raw/research/0764-2026-06-20-optimize-instructions-oi-i-ref-func-test-cast.md
  - ../../../raw/research/0765-2026-06-20-optimize-instructions-oi-i-i31-ref-eq.md
  - ../../../raw/research/0766-2026-06-20-optimize-instructions-oi-i-non-null-local-refs.md
  - ../../../raw/research/0767-2026-06-20-optimize-instructions-oi-i-non-null-local-test-cast.md
  - ../../../raw/research/0768-2026-06-20-optimize-instructions-oi-i-non-null-local-i31-supertype-test-cast.md
  - ../../../raw/research/0769-2026-06-20-optimize-instructions-oi-i-null-nonnull-test-cast-surface.md
  - ../../../raw/research/0770-2026-06-20-optimize-instructions-oi-i-impossible-i31-test-cast.md
  - ../../../raw/research/0771-2026-06-20-optimize-instructions-oi-i-impossible-i31-struct-eq.md
  - ../../../raw/research/0772-2026-06-20-optimize-instructions-oi-i-impossible-struct-array-eq.md
  - ../../../raw/research/0773-2026-06-20-optimize-instructions-oi-i-struct-array-supertype-test-cast.md
  - ../../../raw/research/0774-2026-06-20-optimize-instructions-oi-i-impossible-struct-array-test-cast.md
  - ../../../raw/research/0775-2026-06-20-optimize-instructions-oi-i-self-local-ref-eq.md
  - ../../../raw/research/0776-2026-06-20-optimize-instructions-oi-i-same-local-i31-ref-eq.md
  - ../../../raw/research/0777-2026-06-20-optimize-instructions-oi-i-noop-cast-ref-eq.md
  - ../../../raw/research/0778-2026-06-20-optimize-instructions-oi-i-as-non-null-ref-eq.md
  - ../../../raw/research/0779-2026-06-20-optimize-instructions-oi-i-double-noop-cast-ref-eq.md
  - ../../../raw/research/0780-2026-06-20-optimize-instructions-oi-i-upcast-ref-eq.md
  - ../../../raw/research/0781-2026-06-20-optimize-instructions-oi-i-i31-upcast-ref-eq.md
  - ../../../raw/research/0782-2026-06-20-optimize-instructions-oi-i-nullable-target-miss-test-cast.md
  - ../../../raw/research/0783-2026-06-20-optimize-instructions-oi-i-nullable-target-success-test-cast.md
  - ../../../raw/research/0784-2026-06-20-optimize-instructions-oi-i-nullable-source-non-null-target-miss-test-cast.md
  - ../../../raw/research/0785-2026-06-20-optimize-instructions-oi-i-nullable-source-nullable-target-success-test-cast.md
  - ../../../raw/research/0786-2026-06-20-optimize-instructions-oi-i-nullable-source-nullable-target-i31-success-test-cast.md
  - ../../../raw/research/0787-2026-06-20-optimize-instructions-oi-i-effectful-ref-i31-miss-test-cast.md
  - ../../../raw/research/0788-2026-06-20-optimize-instructions-oi-i-effectful-ref-eq-null.md
  - ../../../raw/research/0789-2026-06-20-optimize-instructions-oi-i-effectful-ref-is-null.md
  - ../../../raw/research/0790-2026-06-20-optimize-instructions-oi-i-effectful-ref-test-success.md
  - ../../../raw/research/0791-2026-06-20-optimize-instructions-oi-i-effectful-impossible-ref-eq.md
  - ../../../raw/research/0792-2026-06-20-optimize-instructions-oi-i-effectful-ref-as-non-null.md
  - ../../../raw/research/0793-2026-06-20-optimize-instructions-oi-i-effectful-known-null-ref-as-non-null.md
  - ../../../raw/research/0794-2026-06-20-optimize-instructions-oi-i-effectful-known-null-ref-test-cast.md
  - ../../../raw/research/0795-2026-06-20-optimize-instructions-oi-i-effectful-known-null-ref-eq.md
  - ../../../raw/research/0796-2026-06-20-optimize-instructions-oi-i-effectful-self-ref-eq.md
  - ../../../raw/research/0797-2026-06-20-optimize-instructions-oi-i-effectful-same-local-ref-i31.md
  - ../../../raw/research/0798-2026-06-20-optimize-instructions-oi-i-effectful-same-local-ref-as-non-null.md
  - ../../../raw/research/0799-2026-06-20-optimize-instructions-oi-i-effectful-same-local-ref-cast.md
  - ../../../raw/research/0800-2026-06-20-optimize-instructions-oi-i-effectful-nullable-source-nullable-target.md
  - ../../../raw/research/0801-2026-06-20-optimize-instructions-oi-i-effectful-nullable-source-non-null-target.md
  - ../../../raw/research/0802-2026-06-20-optimize-instructions-oi-i-effectful-non-null-source-nullable-target.md
  - ../../../raw/research/0803-2026-06-20-optimize-instructions-oi-i-effectful-ref-func-basics.md
  - ../../../raw/research/0804-2026-06-20-optimize-instructions-oi-i-effectful-nullable-i31-supertype.md
  - ../../../raw/research/0805-2026-06-20-optimize-instructions-oi-i-effectful-struct-array-ref-eq.md
  - ../../../raw/research/0806-2026-06-20-optimize-instructions-oi-i-effectful-i31-struct-local-ref-eq.md
  - ../../../raw/research/0807-2026-06-20-optimize-instructions-oi-i-effectful-non-null-source-non-null-target.md
  - ../../../raw/research/0808-2026-06-20-optimize-instructions-oi-i-effectful-non-null-aggregate-ref-is-null.md
  - ../../../raw/research/0809-2026-06-20-optimize-instructions-oi-i-nullable-i31-nonnull-target.md
  - ../../../raw/research/0810-2026-06-20-optimize-instructions-oi-i-known-null-nonnull-target.md
  - ../../../raw/research/0812-2026-06-20-optimize-instructions-oi-i-i31-array-local-ref-eq.md
  - ../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../precompute/index.md
  - ../heap-store-optimization/index.md
  - ../vacuum/index.md
---

# `optimize-instructions`

## Role

- `optimize-instructions` is an active implemented **hot pass** in Starshine.
- In upstream Binaryen `version_129`, `optimize-instructions` is a function-parallel post-walk peephole and canonicalization pass.
- The public summary in `pass.cpp` is only `optimizes instruction combinations`.

That summary is true, but it is far too small.

A better beginner summary is:

- Binaryen first canonicalizes many instruction spellings,
- then rewrites arithmetic, boolean, control, memory, `call_ref`, GC-cast, and tuple-adjacent shapes when helper analyses say the rewrite is safe,
- and finally repairs changed types and EH-pop structure before it finishes.

## Why this pass matters

- The canonical no-DWARF `-O` / `-Os` scheduler uses it **twice** in the default function pipeline:
  - once early
  - once late
- The saved generated-artifact `-O4z` audit also saw it at two real top-level Binaryen slots:
  - slot `16`
  - slot `44`
- The saved Binaryen debug log contains `36` `running pass: optimize-instructions` lines in total, so nested optimizing reruns make it much more common than the two visible top-level slots suggest.
- The pass sits directly beside other cleanup and simplification neighbors already tracked in the wiki:
  - `precompute`
  - `heap-store-optimization`
  - `vacuum`
  - `rse`

## Most important durable takeaways

- Binaryen `optimize-instructions` is **not** just constant folding.
- Binaryen `optimize-instructions` is **not** just integer arithmetic peepholes.
- The real `version_129` pass combines:
  1. local bit/sign-extension prescan
  2. canonicalization of compares and commutative shapes
  3. arithmetic, boolean, and ternary-shell cleanup
  4. memory and bulk-memory simplification
  5. `call_ref` target cleanup
  6. GC cast, null-trap, and constructor/default rewrites
  7. deferred `ReFinalize`, final cleanup, and EH-pop repair
- Current Starshine implements a real but narrower HOT subset centered on integer, boolean, control, and writeback-safety cleanup.
- The earlier generated-artifact failures in slots `16` and `44` are now retired.
  - The durable explanation is still that those failures were HOT-lowering / writeback issues, not a still-open pass-local corruption family.

## Beginner warning: what the name hides

The easy wrong mental model is:

- `optimize-instructions` is just `eqz`, compare-to-zero, and a few arithmetic identities

The safer mental model is:

- Binaryen uses the pass as a broad instruction-shape canonicalizer,
- then exploits the canonical form across arithmetic, boolean, memory, `call_ref`, and GC/reference-typed surfaces,
- while preserving effect order, trap behavior, and type validity.

That difference matters a lot for future parity work.

## What the pass sounds like versus what it actually does

What it sounds like:

- a small math peephole pass

What it actually is in `version_129`:

- a large function-parallel AST post-walk with local bit/sign-extension scanning, iterative canonicalization, arithmetic and ternary peepholes, memory and bulk-memory cleanup, `call_ref` directization, GC cast/trap logic, and deferred refinalization plus EH repair.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the actual Binaryen `version_129` implementation, helper dependencies, scheduler placement, main phases, and why the public name undersells the pass.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Compact source-confirmed owner-file and lit-test map for the pass, including the exact split between `OptimizeInstructions.cpp`, registration files, helper headers, and the distributed dedicated lit surface.
- [`./gc-casts-call_ref-and-trap-sensitive-rewrites.md`](./gc-casts-call_ref-and-trap-sensitive-rewrites.md)
  - Focused guide to the easiest part of the pass to underestimate: null-trap reasoning, cast removal limits, descriptor/exactness handling, `call_ref` lowering, and unshared GC atomic rewrites.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog covering positive, negative, bailout, control, memory, GC, `call_ref`, tuple, and metadata-sensitive rewrite families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  - Current Starshine strategy overview for the implemented HOT subset, with exact registry, dispatcher, owner-file, test, and CLI replay code locations.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Exact MoonBit helper and code-map companion for the implemented HOT subset, plus the major upstream Binaryen behaviors the repo still does not model.
- [`../../../raw/binaryen/2026-04-22-optimize-instructions-primary-sources.md`](../../../raw/binaryen/2026-04-22-optimize-instructions-primary-sources.md)
  - Immutable capture of the official Binaryen release, source, and lit-test URLs re-checked for this dossier on 2026-04-22.
- [`../../../raw/binaryen/2026-05-05-optimize-instructions-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-optimize-instructions-current-main-recheck.md)
  - Immutable capture of the 2026-05-05 current-main spot check for the same contract surfaces.
- [`../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md`](../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md)
  - `[O4Z-AUDIT-OI-A]` `version_130` source/lit matrix mapping upstream visitor and lit families to current Starshine coverage, explicit boundaries, and follow-up slice owners.

## Freshness and provenance note

Current durable answer:

- the detailed prose still mostly teaches from the reviewed `version_129` dossier because that is where the original deep read was filed
- the release-gating O4z audit now uses the 2026-06-19 `version_130` source/lit matrix as the current local-oracle owner map for implementation slices
- the `version_130` matrix re-anchors `OptimizeInstructions.cpp`, registration, helper headers, and the dedicated `optimize-instructions*` lit roster, and it did not find a reason to collapse the existing OI backlog: Starshine remains an active HOT subset, not full upstream parity
- future implementation slices should cite the 2026-06-19 matrix for ownership and the older `version_129` pages for explanatory strategy until those pages are fully rewritten around `version_130`

That is a `version_130` release-oracle matrix, not a live current-`main` drift audit beyond the release tag.

## Current O4z audit inventory

The 2026-06-19 behavior inventory [`../../../raw/research/0726-2026-06-19-optimize-instructions-o4z-behavior-inventory.md`](../../../raw/research/0726-2026-06-19-optimize-instructions-o4z-behavior-inventory.md) keeps `[O4Z-AUDIT-OI]` open. The same-day `version_130` matrix [`../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md`](../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md) completes `[O4Z-AUDIT-OI-A]` by mapping upstream visitor and lit families to current Starshine coverage, explicit boundaries, or follow-up slice owners. The OI-B baseline [`../../../raw/research/0727-2026-06-19-optimize-instructions-oi-b-baseline.md`](../../../raw/research/0727-2026-06-19-optimize-instructions-oi-b-baseline.md) captured direct and saved O4z slot evidence: the direct 1000-case lane hit the default failure ceiling after `54/1000` compared cases with `27` raw mismatches classified as scalar/default canonicalization parity gaps and `1` Binaryen/tool command failure, while the targeted native slot16 and slot44 saved replay filters each passed `2` tests. OI-C through OI-F covered raw-gate trace accountability, default scalar parity, first sign-extension facts, and boolean/select shell cleanup. The first twenty-two OI-G slices add size-`1`/`2`/`4`/`8` `memory.copy` exact load/store lowering, constant/local-value `memory.fill` lowering for selected sizes, memory64 fixture/typechecker coverage, narrow stored-value mask/truncation cleanup including a documented superset-mask Starshine-win shape, memory32/memory64 constant-pointer static-offset folding, explicit `memory.copy` and `load-call-optimize-instructions-noop` boundaries, size-1 constant fill low-byte truncation, nonconstant pointer-add offset, sign-extension-before-store, effectful-memory-copy, and signed-load-before-store boundary classifications. The first OI-K slice [`../../../raw/research/0823-2026-06-20-optimize-instructions-oi-k-struct-get-new.md`](../../../raw/research/0823-2026-06-20-optimize-instructions-oi-k-struct-get-new.md) covers pure `struct.get(struct.new(...))` field forwarding and locks effectful sibling fields as a localizing boundary. The first eight OI-H sub-slices cover direct `ref.func` targets to direct `call` / `return_call`, `table.get` targets to `call_indirect` / `return_call_indirect`, zero-argument select-of-direct-`ref.func` targets to direct-call `if` arms, the superseded argument-bearing select localization boundary, zero-argument fallthrough-known block targets to dropped-target plus direct-call forms, positive single-result argument select localization, boundary negatives for mixed select arms plus argument-bearing fallthrough-known targets, and the call-indexed `table.get` boundary. The first OI-I sub-slice [`../../../raw/research/0757-2026-06-20-optimize-instructions-oi-i-ref-null-basics.md`](../../../raw/research/0757-2026-06-20-optimize-instructions-oi-i-ref-null-basics.md) adds local null-reference basics: `ref.is_null(ref.null)` to `i32.const 1`, `ref.eq(x, null)` / `ref.eq(null, x)` to `ref.is_null(x)`, and `ref.eq(null, null)` to `i32.const 1`. The second OI-I sub-slice [`../../../raw/research/0758-2026-06-20-optimize-instructions-oi-i-ref-as-non-null.md`](../../../raw/research/0758-2026-06-20-optimize-instructions-oi-i-ref-as-non-null.md) adds first `ref.as_non_null` basics: `ref.as_non_null(ref.null)` to `unreachable`, `ref.as_non_null(ref.i31(x))` to `ref.i31(x)`, plus exact `ref.cast(unreachable)` validity repair for stacked cast shapes. The third OI-I sub-slice [`../../../raw/research/0759-2026-06-20-optimize-instructions-oi-i-known-non-null.md`](../../../raw/research/0759-2026-06-20-optimize-instructions-oi-i-known-non-null.md) adds local known-non-null constructor proofs: `ref.is_null(ref.i31)` and `ref.is_null(ref.func)` fold to `i32.const 0`, null equality against `ref.i31` folds to `i32.const 0`, and the validator now accepts non-null `ref.is_null` operands. The fourth and fifth OI-I slices add `ref.as_non_null(ref.func)` elision and nullable null-operand `ref.test` / `ref.cast` basics; the sixth OI-I slice [`../../../raw/research/0762-2026-06-20-optimize-instructions-oi-i-successful-i31-test-cast.md`](../../../raw/research/0762-2026-06-20-optimize-instructions-oi-i-successful-i31-test-cast.md) folds exact successful `ref.test (ref i31)` / `ref.cast (ref i31)` forms fed by local `ref.i31` constructors; the seventh widens that local-i31 proof to `eq` and `any` targets; the eighth [`../../../raw/research/0764-2026-06-20-optimize-instructions-oi-i-ref-func-test-cast.md`](../../../raw/research/0764-2026-06-20-optimize-instructions-oi-i-ref-func-test-cast.md) folds exact successful `ref.test (ref func)` / `ref.cast (ref func)` forms fed by local `ref.func` constructors; the ninth folds literal `ref.i31` equality; the tenth adds declared non-null local proofs for `ref.is_null`, `ref.as_non_null`, and null equality; and the eleventh [`../../../raw/research/0767-2026-06-20-optimize-instructions-oi-i-non-null-local-test-cast.md`](../../../raw/research/0767-2026-06-20-optimize-instructions-oi-i-non-null-local-test-cast.md) adds exact declared non-null local `ref.test` / `ref.cast` same-heap folds. The remaining active backlog starts with any further source-backed OI-G load/store work, any further source-backed OI-H known-target shapes, remaining reference/cast/descriptor/null-trap families, GC non-atomic and atomic rewrites, tuple extraction, and final direct/O4z closeout.

## Current maintenance rule

- Treat this folder as the canonical home for future `optimize-instructions` parity and scheduler research.
- Use Binaryen `version_130` as the release-gating O4z source/lit matrix for new implementation slices; use the older `version_129` dossier prose as historical explanatory material until fully refreshed.
- Keep the Binaryen strategy page and the Starshine strategy page in sync whenever the in-tree implementation grows beyond the current integer / boolean / control-focused HOT subset.
- Keep the landing page honest about the ordered-artifact story:
  - slot `16` is retired
  - slot `44` is retired
  - the remaining work is documentation depth, parity breadth, and runtime honesty, not an open hard-corruption witness

## Sources

- [`../../../raw/binaryen/2026-04-22-optimize-instructions-primary-sources.md`](../../../raw/binaryen/2026-04-22-optimize-instructions-primary-sources.md)
- [`../../../raw/research/0131-2026-04-20-optimize-instructions-binaryen-research.md`](../../../raw/research/0131-2026-04-20-optimize-instructions-binaryen-research.md)
- [`../../../raw/research/0248-2026-04-22-optimize-instructions-primary-sources-and-implementation-followup.md`](../../../raw/research/0248-2026-04-22-optimize-instructions-primary-sources-and-implementation-followup.md)
- [`../../../../../src/passes/optimize_instructions.mbt`](../../../../../src/passes/optimize_instructions.mbt)
- [`../../../../../src/passes/optimize_instructions_test.mbt`](../../../../../src/passes/optimize_instructions_test.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../tracker.md`](../tracker.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`](../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md) preserves the saved generated-artifact `-O4z` slot, summary, and Binaryen debug-log facts; older `.artifacts` paths are replay identifiers, not durable wiki source links.
- [`../../../raw/research/0726-2026-06-19-optimize-instructions-o4z-behavior-inventory.md`](../../../raw/research/0726-2026-06-19-optimize-instructions-o4z-behavior-inventory.md) records the current OI behavior-gap inventory and `[O4Z-AUDIT-OI-A]` through `[O4Z-AUDIT-OI-N]` backlog split.
- [`../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md`](../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md) completes `[O4Z-AUDIT-OI-A]` with the `version_130` source/lit matrix and slice ownership map.
- [`../../../raw/research/0727-2026-06-19-optimize-instructions-oi-b-baseline.md`](../../../raw/research/0727-2026-06-19-optimize-instructions-oi-b-baseline.md) completes `[O4Z-AUDIT-OI-B]` with direct compare-pass and saved O4z slot16/slot44 replay evidence before behavior changes.
- [`../../../raw/research/0728-2026-06-19-optimize-instructions-oi-c-raw-gates.md`](../../../raw/research/0728-2026-06-19-optimize-instructions-oi-c-raw-gates.md) completes `[O4Z-AUDIT-OI-C]` with raw no-op gate trace coverage, structured gate ordering repair, and outside-gate public cleanup evidence.
- [`../../../raw/research/0729-2026-06-19-optimize-instructions-oi-d-default-scalars.md`](../../../raw/research/0729-2026-06-19-optimize-instructions-oi-d-default-scalars.md) completes `[O4Z-AUDIT-OI-D]` with default scalar arithmetic, float spelling, wrap-constant, and relational canonicalization coverage plus direct 10000 compare evidence.
- [`../../../raw/research/0730-2026-06-19-optimize-instructions-oi-e-sign-ext-facts.md`](../../../raw/research/0730-2026-06-19-optimize-instructions-oi-e-sign-ext-facts.md) completes `[O4Z-AUDIT-OI-E]` with the first local scanner-style sign-extension facts, redundant sign-extension removal, shift-pair sign-extension idiom rewrites, focused tests, and direct 10000 compare evidence.
- [`../../../raw/research/0731-2026-06-19-optimize-instructions-oi-f-boolean-select-shells.md`](../../../raw/research/0731-2026-06-19-optimize-instructions-oi-f-boolean-select-shells.md) completes `[O4Z-AUDIT-OI-F]` with boolean/select/ternary shell classification, constant-condition `select` cleanup, focused effect/trap negatives, branch-hint/no-fold option boundaries, and direct 10000 compare evidence.
- [`../../../raw/research/0732-2026-06-19-optimize-instructions-oi-g-byte-bulk-memory.md`](../../../raw/research/0732-2026-06-19-optimize-instructions-oi-g-byte-bulk-memory.md) records the first `[O4Z-AUDIT-OI-G]` byte bulk-memory sub-slice for size-1 `memory.copy` and `memory.fill` plus zero-size trap-mode boundary evidence.
- [`../../../raw/research/0750-2026-06-19-optimize-instructions-oi-h-ref-func-call-ref.md`](../../../raw/research/0750-2026-06-19-optimize-instructions-oi-h-ref-func-call-ref.md) records the first `[O4Z-AUDIT-OI-H]` `call_ref` sub-slice: direct `ref.func` targets under `call_ref` and `return_call_ref` now directize to `call` and `return_call`.
- [`../../../raw/research/0751-2026-06-19-optimize-instructions-oi-h-table-get-call-ref.md`](../../../raw/research/0751-2026-06-19-optimize-instructions-oi-h-table-get-call-ref.md) records the second `[O4Z-AUDIT-OI-H]` `call_ref` sub-slice: `table.get` targets under `call_ref` and `return_call_ref` now lower to `call_indirect` and `return_call_indirect`.
- [`../../../raw/research/0752-2026-06-19-optimize-instructions-oi-h-select-ref-func-call-ref.md`](../../../raw/research/0752-2026-06-19-optimize-instructions-oi-h-select-ref-func-call-ref.md) records the third `[O4Z-AUDIT-OI-H]` `call_ref` sub-slice: zero-argument typed `select` targets whose arms are direct `ref.func`s now lower to an `if` with direct `call` / `return_call` arms; fallthrough-known and positive argument-bearing select-known-target lowering remained open at that point.
- [`../../../raw/research/0753-2026-06-19-optimize-instructions-oi-h-argument-select-call-ref-boundary.md`](../../../raw/research/0753-2026-06-19-optimize-instructions-oi-h-argument-select-call-ref-boundary.md) records the fourth `[O4Z-AUDIT-OI-H]` `call_ref` sub-slice: argument-bearing select-of-`ref.func` targets were an explicit fail-closed boundary until Starshine had Binaryen-style argument localization.
- [`../../../raw/research/0754-2026-06-19-optimize-instructions-oi-h-fallthrough-call-ref.md`](../../../raw/research/0754-2026-06-19-optimize-instructions-oi-h-fallthrough-call-ref.md) records the fifth `[O4Z-AUDIT-OI-H]` `call_ref` sub-slice: zero-argument fallthrough-known block targets now lower to a dropped target expression plus direct `call` / `return_call`, preserving target-side effects.
- [`../../../raw/research/0755-2026-06-20-optimize-instructions-oi-h-argument-select-call-ref-localization.md`](../../../raw/research/0755-2026-06-20-optimize-instructions-oi-h-argument-select-call-ref-localization.md) records the sixth `[O4Z-AUDIT-OI-H]` `call_ref` sub-slice: argument-bearing select-of-`ref.func` targets now localize single-result call arguments before lowering to direct-call `if` arms.
- [`../../../raw/research/0756-2026-06-20-optimize-instructions-oi-h-call-ref-boundaries.md`](../../../raw/research/0756-2026-06-20-optimize-instructions-oi-h-call-ref-boundaries.md) records the seventh `[O4Z-AUDIT-OI-H]` `call_ref` boundary sub-slice: mixed select arms remain intentionally kept unchanged, while the older argument-bearing fallthrough-known boundary is superseded by the 2026-06-24 localization implementation.
- [`../../../raw/research/0811-2026-06-20-optimize-instructions-oi-h-call-indexed-table-get-boundary.md`](../../../raw/research/0811-2026-06-20-optimize-instructions-oi-h-call-indexed-table-get-boundary.md) records the earlier eighth `[O4Z-AUDIT-OI-H]` `call_ref` boundary sub-slice; the exact call-indexed `table.get` shape with a no-param one-result index call and pure local/constant call arguments is now superseded by the 2026-06-24 implementation, while broader effectful/localizing table-index forms remain open.
- The 2026-06-24 argument fallthrough localization sub-slice extends `[O4Z-AUDIT-OI-H]`: fallthrough-known block targets with single-result already-evaluated call arguments now store those arguments to temps, drop the target expression for effects, then reload the temps for direct `call` / `return_call`, matching Binaryen `version_130` for `.tmp/oi-h-argument-fallthrough-call-ref-probe.wat`.
- [`../../../raw/research/0843-2026-06-25-optimize-instructions-oi-h-multivalue-arg-call-ref-boundary.md`](../../../raw/research/0843-2026-06-25-optimize-instructions-oi-h-multivalue-arg-call-ref-boundary.md) records a current `[O4Z-AUDIT-OI-H]` boundary: Binaryen localizes a multi-result argument producer through tuple scratch and scalar locals before select-of-`ref.func` directization, while Starshine keeps the shape unchanged until a safe multivalue argument localization helper exists.
- [`../../../raw/research/0757-2026-06-20-optimize-instructions-oi-i-ref-null-basics.md`](../../../raw/research/0757-2026-06-20-optimize-instructions-oi-i-ref-null-basics.md) records the first `[O4Z-AUDIT-OI-I]` reference-null sub-slice: `ref.is_null(ref.null)` and null-operand `ref.eq` rewrites now cover the local null equality/test basics while broader casts and exactness-sensitive behavior remain open.
- [`../../../raw/research/0758-2026-06-20-optimize-instructions-oi-i-ref-as-non-null.md`](../../../raw/research/0758-2026-06-20-optimize-instructions-oi-i-ref-as-non-null.md) records the second `[O4Z-AUDIT-OI-I]` reference sub-slice: first `ref.as_non_null` null/known-`i31` cleanup and exact `ref.cast(unreachable)` validity repair are covered while broader casts, tests, and descriptor/exactness-sensitive behavior remain open.
- [`../../../raw/research/0759-2026-06-20-optimize-instructions-oi-i-known-non-null.md`](../../../raw/research/0759-2026-06-20-optimize-instructions-oi-i-known-non-null.md) records the third `[O4Z-AUDIT-OI-I]` reference sub-slice: known-non-null `ref.i31` / `ref.func` null tests and `ref.i31` null equality now fold to `i32.const 0`, with the supporting `ref.is_null` typechecker correction.
- [`../../../raw/research/0760-2026-06-20-optimize-instructions-oi-i-ref-as-func.md`](../../../raw/research/0760-2026-06-20-optimize-instructions-oi-i-ref-as-func.md) records the fourth `[O4Z-AUDIT-OI-I]` reference sub-slice: `ref.as_non_null(ref.func f)` now reuses the local known-non-null constructor proof and rewrites to `ref.func f` while arbitrary cast/test/type proofs remain open.
- [`../../../raw/research/0761-2026-06-20-optimize-instructions-oi-i-null-ref-test-cast.md`](../../../raw/research/0761-2026-06-20-optimize-instructions-oi-i-null-ref-test-cast.md) records the fifth `[O4Z-AUDIT-OI-I]` reference sub-slice: nullable null-operand `ref.test` folds to `i32.const 1` and nullable null-operand `ref.cast` rewrites to the null child; non-null cast/test fixture coverage is now separately locked by `0769`.
- [`../../../raw/research/0762-2026-06-20-optimize-instructions-oi-i-successful-i31-test-cast.md`](../../../raw/research/0762-2026-06-20-optimize-instructions-oi-i-successful-i31-test-cast.md) records the sixth `[O4Z-AUDIT-OI-I]` reference sub-slice: exact successful `ref.test (ref i31)` and `ref.cast (ref i31)` forms fed by local `ref.i31` constructors now fold while broader successful cast/test proofs remain open.
- [`../../../raw/research/0763-2026-06-20-optimize-instructions-oi-i-i31-supertype-test-cast.md`](../../../raw/research/0763-2026-06-20-optimize-instructions-oi-i-i31-supertype-test-cast.md) records the seventh `[O4Z-AUDIT-OI-I]` reference sub-slice: successful local-`ref.i31` cast/test folds now cover absolute target supertypes `eq` and `any` as well as exact `i31`.
- [`../../../raw/research/0764-2026-06-20-optimize-instructions-oi-i-ref-func-test-cast.md`](../../../raw/research/0764-2026-06-20-optimize-instructions-oi-i-ref-func-test-cast.md) records the eighth `[O4Z-AUDIT-OI-I]` reference sub-slice: exact successful `ref.test (ref func)` and `ref.cast (ref func)` forms fed by local `ref.func` constructors now fold while target supertypes and broader cast/test proofs remain open.
- [`../../../raw/research/0765-2026-06-20-optimize-instructions-oi-i-i31-ref-eq.md`](../../../raw/research/0765-2026-06-20-optimize-instructions-oi-i-i31-ref-eq.md) records the ninth `[O4Z-AUDIT-OI-I]` reference sub-slice: `ref.eq` between immediate `ref.i31(i32.const)` operands now folds to `i32.const 1` for equal payloads and `i32.const 0` for unequal payloads, while broader reference identity proofs remain open.
- [`../../../raw/research/0766-2026-06-20-optimize-instructions-oi-i-non-null-local-refs.md`](../../../raw/research/0766-2026-06-20-optimize-instructions-oi-i-non-null-local-refs.md) records the tenth `[O4Z-AUDIT-OI-I]` reference sub-slice: declared non-null `local.get` refs now feed `ref.is_null`, `ref.as_non_null`, and null-equality folds through local type metadata, while nullable-local and broader flow-sensitive proofs remain open.
- [`../../../raw/research/0767-2026-06-20-optimize-instructions-oi-i-non-null-local-test-cast.md`](../../../raw/research/0767-2026-06-20-optimize-instructions-oi-i-non-null-local-test-cast.md) records the eleventh `[O4Z-AUDIT-OI-I]` reference sub-slice: exact same-heap declared non-null local `ref.test` / `ref.cast` proofs now fold through local type metadata.
- [`../../../raw/research/0768-2026-06-20-optimize-instructions-oi-i-non-null-local-i31-supertype-test-cast.md`](../../../raw/research/0768-2026-06-20-optimize-instructions-oi-i-non-null-local-i31-supertype-test-cast.md) records the twelfth `[O4Z-AUDIT-OI-I]` reference sub-slice: declared non-null `(ref i31)` locals now prove successful `ref.test` / `ref.cast` for absolute `eq` / `any` target supertypes.
- [`../../../raw/research/0769-2026-06-20-optimize-instructions-oi-i-null-nonnull-test-cast-surface.md`](../../../raw/research/0769-2026-06-20-optimize-instructions-oi-i-null-nonnull-test-cast-surface.md) records the thirteenth `[O4Z-AUDIT-OI-I]` coverage/type-surface sub-slice: non-null null-operand `ref.test` now has validating direct-core coverage for folding to `i32.const 0`, and non-null null-operand `ref.cast` has validating direct-core coverage for rewriting to `unreachable`.
- [`../../../raw/research/0770-2026-06-20-optimize-instructions-oi-i-impossible-i31-test-cast.md`](../../../raw/research/0770-2026-06-20-optimize-instructions-oi-i-impossible-i31-test-cast.md) records the fourteenth `[O4Z-AUDIT-OI-I]` reference sub-slice: ordinary `ref.test` / `ref.cast` validation now accepts disjoint `eq`-hierarchy sibling heap types, and local `ref.i31` values tested or cast against `struct` / `array` / indexed heap targets fold to `i32.const 0` or `unreachable`.
- [`../../../raw/research/0771-2026-06-20-optimize-instructions-oi-i-impossible-i31-struct-eq.md`](../../../raw/research/0771-2026-06-20-optimize-instructions-oi-i-impossible-i31-struct-eq.md) records the fifteenth `[O4Z-AUDIT-OI-I]` reference sub-slice: `ref.eq` now folds to `i32.const 0` when a definitely non-null local `i31` value is compared with a local whose declared heap cannot be `i31`, such as a nullable struct local.
- [`../../../raw/research/0772-2026-06-20-optimize-instructions-oi-i-impossible-struct-array-eq.md`](../../../raw/research/0772-2026-06-20-optimize-instructions-oi-i-impossible-struct-array-eq.md) records the sixteenth `[O4Z-AUDIT-OI-I]` reference sub-slice: `ref.eq` now folds to `i32.const 0` for absolute local `struct` / `array` heap pairs when at least one operand is declared non-null, while nullable-both equality remains unchanged because both operands can be null.
- [`../../../raw/research/0773-2026-06-20-optimize-instructions-oi-i-struct-array-supertype-test-cast.md`](../../../raw/research/0773-2026-06-20-optimize-instructions-oi-i-struct-array-supertype-test-cast.md) records the seventeenth `[O4Z-AUDIT-OI-I]` reference sub-slice: declared non-null absolute `struct` / `array` locals now prove successful `ref.test` / `ref.cast` for absolute target supertypes `eq` and `any`, while broader subtype, nullable-local, descriptor, exactness, TNH, and IIT facts remain open.
- [`../../../raw/research/0774-2026-06-20-optimize-instructions-oi-i-impossible-struct-array-test-cast.md`](../../../raw/research/0774-2026-06-20-optimize-instructions-oi-i-impossible-struct-array-test-cast.md) records the eighteenth `[O4Z-AUDIT-OI-I]` reference sub-slice: declared non-null absolute `struct` / `array` locals now prove failed `ref.test` / `ref.cast` against the other absolute aggregate sibling, while nullable-local, indexed/defined heap, arbitrary subtype-lattice, descriptor, exactness, TNH, and IIT facts remain open.
- [`../../../raw/research/0775-2026-06-20-optimize-instructions-oi-i-self-local-ref-eq.md`](../../../raw/research/0775-2026-06-20-optimize-instructions-oi-i-self-local-ref-eq.md) records the nineteenth `[O4Z-AUDIT-OI-I]` reference sub-slice: direct `ref.eq(local.get N, local.get N)` now folds to `i32.const 1` for nullable and non-null local refs, while broader SSA identity and flow-sensitive equality proofs remain open.
- [`../../../raw/research/0776-2026-06-20-optimize-instructions-oi-i-same-local-i31-ref-eq.md`](../../../raw/research/0776-2026-06-20-optimize-instructions-oi-i-same-local-i31-ref-eq.md) records the twentieth `[O4Z-AUDIT-OI-I]` reference sub-slice: direct `ref.eq(ref.i31(local.get N), ref.i31(local.get N))` now folds to `i32.const 1`, while broader SSA identity, flow-sensitive i31 value analysis, and non-local equality proofs remain open.
- [`../../../raw/research/0777-2026-06-20-optimize-instructions-oi-i-noop-cast-ref-eq.md`](../../../raw/research/0777-2026-06-20-optimize-instructions-oi-i-noop-cast-ref-eq.md) records the twenty-first `[O4Z-AUDIT-OI-I]` reference sub-slice: direct same-local `ref.eq` now folds through an immediate nullable no-op `ref.cast` whose target heap exactly matches the local declaration, while arbitrary cast skipping, non-null cast trap removal, descriptor/exactness/TNH/IIT behavior, and broader flow-sensitive equality proofs remain open.
- [`../../../raw/research/0778-2026-06-20-optimize-instructions-oi-i-as-non-null-ref-eq.md`](../../../raw/research/0778-2026-06-20-optimize-instructions-oi-i-as-non-null-ref-eq.md) records the twenty-second `[O4Z-AUDIT-OI-I]` reference sub-slice: direct same-local nullable `ref.as_non_null(local.get)` equality now folds to one preserved null-trapping check plus `i32.const 1`.
- [`../../../raw/research/0779-2026-06-20-optimize-instructions-oi-i-double-noop-cast-ref-eq.md`](../../../raw/research/0779-2026-06-20-optimize-instructions-oi-i-double-noop-cast-ref-eq.md) records the twenty-third `[O4Z-AUDIT-OI-I]` coverage sub-slice: both-operands nullable no-op `ref.cast(local.get)` equality is locked by direct-core coverage.
- [`../../../raw/research/0780-2026-06-20-optimize-instructions-oi-i-upcast-ref-eq.md`](../../../raw/research/0780-2026-06-20-optimize-instructions-oi-i-upcast-ref-eq.md) records the twenty-fourth `[O4Z-AUDIT-OI-I]` reference sub-slice: same-local equality now folds through immediate nullable absolute-heap upcast `ref.cast(local.get)` operands, currently using the existing absolute `struct` / `array` supertype helper.
- [`../../../raw/research/0786-2026-06-20-optimize-instructions-oi-i-nullable-source-nullable-target-i31-success-test-cast.md`](../../../raw/research/0786-2026-06-20-optimize-instructions-oi-i-nullable-source-nullable-target-i31-success-test-cast.md) records the thirtieth `[O4Z-AUDIT-OI-I]` coverage sub-slice: nullable-source, nullable-target `ref.test` / `ref.cast` success on declared nullable absolute `i31` locals is now locked by direct-core coverage.
- [`../../../raw/research/0787-2026-06-20-optimize-instructions-oi-i-effectful-ref-i31-miss-test-cast.md`](../../../raw/research/0787-2026-06-20-optimize-instructions-oi-i-effectful-ref-i31-miss-test-cast.md) records the thirty-first `[O4Z-AUDIT-OI-I]` reference sub-slice: immediate `ref.i31` known-miss `ref.test` / `ref.cast` rewrites now preserve effectful operands as `drop(operand)` before `i32.const 0` or `unreachable`.
- [`../../../raw/research/0788-2026-06-20-optimize-instructions-oi-i-effectful-ref-eq-null.md`](../../../raw/research/0788-2026-06-20-optimize-instructions-oi-i-effectful-ref-eq-null.md) records the thirty-second `[O4Z-AUDIT-OI-I]` reference sub-slice: immediate `ref.i31` null-equality miss rewrites now preserve effectful operands as `drop(operand)` before `i32.const 0`.
- [`../../../raw/research/0789-2026-06-20-optimize-instructions-oi-i-effectful-ref-is-null.md`](../../../raw/research/0789-2026-06-20-optimize-instructions-oi-i-effectful-ref-is-null.md) records the thirty-third `[O4Z-AUDIT-OI-I]` reference sub-slice: known-non-null `ref.is_null` folds now preserve effectful immediate `ref.i31` operands as `drop(operand)` before `i32.const 0`.
- [`../../../raw/research/0790-2026-06-20-optimize-instructions-oi-i-effectful-ref-test-success.md`](../../../raw/research/0790-2026-06-20-optimize-instructions-oi-i-effectful-ref-test-success.md) records the thirty-fourth `[O4Z-AUDIT-OI-I]` reference sub-slice: definitely-successful `ref.test` folds now preserve effectful immediate `ref.i31` operands as `drop(operand)` before `i32.const 1`, while successful `ref.cast` keeps the effectful operand.
- [`../../../raw/research/0791-2026-06-20-optimize-instructions-oi-i-effectful-impossible-ref-eq.md`](../../../raw/research/0791-2026-06-20-optimize-instructions-oi-i-effectful-impossible-ref-eq.md) records the thirty-fifth `[O4Z-AUDIT-OI-I]` reference sub-slice: represented impossible `ref.eq` folds now preserve effectful immediate `ref.i31` operands as `drop(operand)` before `i32.const 0`.
- [`../../../raw/research/0792-2026-06-20-optimize-instructions-oi-i-effectful-ref-as-non-null.md`](../../../raw/research/0792-2026-06-20-optimize-instructions-oi-i-effectful-ref-as-non-null.md) records the thirty-sixth `[O4Z-AUDIT-OI-I]` coverage sub-slice: `ref.as_non_null(ref.i31(call $effect))` cleanup preserves the effectful `ref.i31(call $effect)` operand while removing the redundant assertion.
- [`../../../raw/research/0793-2026-06-20-optimize-instructions-oi-i-effectful-known-null-ref-as-non-null.md`](../../../raw/research/0793-2026-06-20-optimize-instructions-oi-i-effectful-known-null-ref-as-non-null.md) records the thirty-seventh `[O4Z-AUDIT-OI-I]` coverage sub-slice: known-null `ref.as_non_null` cleanup preserves an already-evaluated `drop(call $effect)` prefix before the folded `unreachable`.
- [`../../../raw/research/0794-2026-06-20-optimize-instructions-oi-i-effectful-known-null-ref-test-cast.md`](../../../raw/research/0794-2026-06-20-optimize-instructions-oi-i-effectful-known-null-ref-test-cast.md) records the thirty-eighth `[O4Z-AUDIT-OI-I]` coverage sub-slice: known-null non-null-target `ref.test` / `ref.cast` cleanup preserves an already-evaluated `drop(call $effect)` prefix before `i32.const 0` / `unreachable`.
- [`../../../raw/research/0795-2026-06-20-optimize-instructions-oi-i-effectful-known-null-ref-eq.md`](../../../raw/research/0795-2026-06-20-optimize-instructions-oi-i-effectful-known-null-ref-eq.md) records the thirty-ninth `[O4Z-AUDIT-OI-I]` coverage sub-slice: known-null `ref.eq` cleanup preserves an already-evaluated `drop(call $effect)` prefix before `i32.const 1` or `i32.const 0` folds.
- [`../../../raw/research/0796-2026-06-20-optimize-instructions-oi-i-effectful-self-ref-eq.md`](../../../raw/research/0796-2026-06-20-optimize-instructions-oi-i-effectful-self-ref-eq.md) records the fortieth `[O4Z-AUDIT-OI-I]` coverage sub-slice: direct same-local `ref.eq` cleanup preserves an already-evaluated `drop(call $effect)` prefix before `i32.const 1` folds.
- [`../../../raw/research/0797-2026-06-20-optimize-instructions-oi-i-effectful-same-local-ref-i31.md`](../../../raw/research/0797-2026-06-20-optimize-instructions-oi-i-effectful-same-local-ref-i31.md) records the forty-first `[O4Z-AUDIT-OI-I]` coverage sub-slice: same-local `ref.i31(local.get)` equality cleanup preserves an already-evaluated `drop(call $effect)` prefix before `i32.const 1` folds.
- [`../../../raw/research/0803-2026-06-20-optimize-instructions-oi-i-effectful-ref-func-basics.md`](../../../raw/research/0803-2026-06-20-optimize-instructions-oi-i-effectful-ref-func-basics.md) records the forty-seventh `[O4Z-AUDIT-OI-I]` coverage sub-slice: exact `ref.func` reference basics preserve an already-evaluated `drop(call $effect)` prefix while folding/removing `ref.test`, `ref.cast`, `ref.is_null`, and `ref.as_non_null` suffixes.
- [`../../../raw/research/0804-2026-06-20-optimize-instructions-oi-i-effectful-nullable-i31-supertype.md`](../../../raw/research/0804-2026-06-20-optimize-instructions-oi-i-effectful-nullable-i31-supertype.md) records the forty-eighth `[O4Z-AUDIT-OI-I]` coverage sub-slice: nullable-source nullable-target `i31`→`eq` supertype `ref.test` / `ref.cast` cleanup preserves an already-evaluated `drop(call $effect)` prefix.
- [`../../../raw/research/0805-2026-06-20-optimize-instructions-oi-i-effectful-struct-array-ref-eq.md`](../../../raw/research/0805-2026-06-20-optimize-instructions-oi-i-effectful-struct-array-ref-eq.md) records the forty-ninth `[O4Z-AUDIT-OI-I]` coverage sub-slice: impossible `ref.eq` between absolute aggregate sibling locals with at least one non-null operand preserves an already-evaluated `drop(call $effect)` prefix before folding to `i32.const 0`.
- [`../../../raw/research/0806-2026-06-20-optimize-instructions-oi-i-effectful-i31-struct-local-ref-eq.md`](../../../raw/research/0806-2026-06-20-optimize-instructions-oi-i-effectful-i31-struct-local-ref-eq.md) records the fiftieth `[O4Z-AUDIT-OI-I]` coverage sub-slice: impossible `ref.eq` between a declared non-null `i31` local and a nullable struct local preserves an already-evaluated `drop(call $effect)` prefix before folding to `i32.const 0`.
- [`../../../raw/research/0807-2026-06-20-optimize-instructions-oi-i-effectful-non-null-source-non-null-target.md`](../../../raw/research/0807-2026-06-20-optimize-instructions-oi-i-effectful-non-null-source-non-null-target.md) records the fifty-first `[O4Z-AUDIT-OI-I]` coverage sub-slice: non-null-source, non-null-target aggregate `ref.test` / `ref.cast` success and sibling-miss folds preserve an already-evaluated `drop(call $effect)` prefix.
- [`../../../raw/research/0808-2026-06-20-optimize-instructions-oi-i-effectful-non-null-aggregate-ref-is-null.md`](../../../raw/research/0808-2026-06-20-optimize-instructions-oi-i-effectful-non-null-aggregate-ref-is-null.md) records the fifty-second `[O4Z-AUDIT-OI-I]` coverage sub-slice: declared non-null aggregate `ref.is_null` folds preserve an already-evaluated `drop(call $effect)` prefix before `i32.const 0`.
- [`../../../raw/research/0809-2026-06-20-optimize-instructions-oi-i-nullable-i31-nonnull-target.md`](../../../raw/research/0809-2026-06-20-optimize-instructions-oi-i-nullable-i31-nonnull-target.md) records the fifty-third `[O4Z-AUDIT-OI-I]` implementation sub-slice: nullable `(ref null i31)` locals tested or cast against non-null aggregate targets now fold to `i32.const 0` / `unreachable` while preserving already-evaluated effect prefixes.
- [`../../../raw/research/0810-2026-06-20-optimize-instructions-oi-i-known-null-nonnull-target.md`](../../../raw/research/0810-2026-06-20-optimize-instructions-oi-i-known-null-nonnull-target.md) records the fifty-fourth `[O4Z-AUDIT-OI-I]` coverage sub-slice: known-null operands tested or cast against non-null targets fold to `i32.const 0` / `unreachable` while preserving already-evaluated effect prefixes.
- [`../../../raw/research/0812-2026-06-20-optimize-instructions-oi-i-i31-array-local-ref-eq.md`](../../../raw/research/0812-2026-06-20-optimize-instructions-oi-i-i31-array-local-ref-eq.md) records the fifty-fifth `[O4Z-AUDIT-OI-I]` coverage sub-slice: impossible `ref.eq` between declared non-null `i31` locals and nullable array locals preserves an already-evaluated `drop(call $effect)` prefix before folding to `i32.const 0`.
- [`../../../raw/research/0813-2026-06-20-optimize-instructions-oi-i-same-heap-nonnull-ref-cast.md`](../../../raw/research/0813-2026-06-20-optimize-instructions-oi-i-same-heap-nonnull-ref-cast.md) records the fifty-sixth `[O4Z-AUDIT-OI-I]` implementation sub-slice: unknown nullable exact-heap non-null `ref.cast` now lowers to `ref.as_non_null`, preserving operand effects and the null trap while keeping narrowing heap-check casts as `ref.cast`.
- [`../../../raw/research/0814-2026-06-20-optimize-instructions-oi-i-indexed-i31-aggregate-ref-eq.md`](../../../raw/research/0814-2026-06-20-optimize-instructions-oi-i-indexed-i31-aggregate-ref-eq.md) records the fifty-seventh `[O4Z-AUDIT-OI-I]` coverage sub-slice: indexed/defined struct and array locals are explicitly covered for impossible equality with definitely non-null `i31` references, including effect-prefix preservation before folding to `i32.const 0`.
- [`../../../raw/research/0818-2026-06-20-optimize-instructions-oi-j-exact-cast-boundary.md`](../../../raw/research/0818-2026-06-20-optimize-instructions-oi-j-exact-cast-boundary.md) records the first `[O4Z-AUDIT-OI-J]` exactness sub-slice: Starshine now preserves exact `ref.cast` checks when the operand has an inexact same-heap local type, matching Binaryen `version_130` and preventing invalid exact-result rewrites.
- [`../../../raw/research/0819-2026-06-20-optimize-instructions-oi-j-exact-cast-already-exact.md`](../../../raw/research/0819-2026-06-20-optimize-instructions-oi-j-exact-cast-already-exact.md) records the second `[O4Z-AUDIT-OI-J]` exactness sub-slice: already-exact same-heap operands are covered for redundant exact `ref.cast` cleanup, including nullable-to-non-null exact casts becoming `ref.as_non_null` to keep the null trap.
- [`../../../raw/research/0820-2026-06-20-optimize-instructions-oi-j-success-only-if-non-null-ref-test.md`](../../../raw/research/0820-2026-06-20-optimize-instructions-oi-j-success-only-if-non-null-ref-test.md) records the third `[O4Z-AUDIT-OI-J]` sub-slice: nullable-source / non-null-target `ref.test` now lowers to `i32.eqz(ref.is_null(x))`, preserving effectful operands while removing the redundant heap test.
- [`../../../raw/research/0821-2026-06-20-optimize-instructions-oi-j-descriptor-cast-boundary.md`](../../../raw/research/0821-2026-06-20-optimize-instructions-oi-j-descriptor-cast-boundary.md) records the fourth `[O4Z-AUDIT-OI-J]` boundary sub-slice: Binaryen keeps official two-operand descriptor equality casts, while Starshine locks the local legacy unary `ref.cast_desc_eq` surface as fail-closed and documents the HOT descriptor-operand representation blocker.
- [`../../../raw/research/0822-2026-06-20-optimize-instructions-oi-g-superset-store-mask.md`](../../../raw/research/0822-2026-06-20-optimize-instructions-oi-g-superset-store-mask.md) records the twenty-second `[O4Z-AUDIT-OI-G]` sub-slice: Binaryen `version_130` keeps superset low-bit masks before narrow stores, while Starshine locks the existing smaller output shape that removes those masks when all bits written by the store are preserved.
- [`../../../raw/research/0837-2026-06-23-optimize-instructions-oi-g-wrap-store.md`](../../../raw/research/0837-2026-06-23-optimize-instructions-oi-g-wrap-store.md) records the twenty-third `[O4Z-AUDIT-OI-G]` sub-slice: Starshine now widens `i32.store8` / `i32.store16` / `i32.store` of a direct one-use `i32.wrap_i64` operand to `i64.store8` / `i64.store16` / `i64.store32` of the original i64 operand, dropping the wrap, while keeping the reverse `i64.extend_i32_*` direction and multi-use wraps as boundaries.
- [`../../../raw/research/0838-2026-06-23-optimize-instructions-oi-d-identity-binary.md`](../../../raw/research/0838-2026-06-23-optimize-instructions-oi-d-identity-binary.md) extends the completed `[O4Z-AUDIT-OI-D]` default-scalar surface: Starshine now folds identity binary operands (`or`/`xor`/`add`/`shl`/`shr_u`/`shr_s` with `0`, `and` with `-1`, `mul` with `1`, and `sub` with a `0` right operand, i32 and i64) to the other operand, matching Binaryen `version_130` direct `--optimize-instructions`, while keeping `sub(0, x)`.
- [`../../../raw/research/0839-2026-06-23-optimize-instructions-oi-d-absorbing-binary.md`](../../../raw/research/0839-2026-06-23-optimize-instructions-oi-d-absorbing-binary.md) extends the OI-D binary-operand surface: Starshine now folds zero-absorbing `mul`/`and` with a `0` operand and signed `rem` with divisor `-1` (i32 and i64) to `0` when the non-constant operand is side-effect-free, while keeping effectful `mul`/`and`/`rem_s` forms.
- [`../../../raw/research/0841-2026-06-23-optimize-instructions-oi-d-nested-shift-or-float.md`](../../../raw/research/0841-2026-06-23-optimize-instructions-oi-d-nested-shift-or-float.md) extends OI-D with nested constant shift/rotate combining, all-ones `or` absorbing with effect-preserving `drop`, and float mul/div-by-`-1` plus div-by-`1` spelling rewrites matching Binaryen `version_130` without fast-math float `0`/`1` identity folding.
- A 2026-06-25 OI-D slice extends the direct sign-extension range surface in [`../../../../../src/passes/optimize_instructions.mbt`](../../../../../src/passes/optimize_instructions.mbt): `i32.eq` / `i32.ne` on direct `i32.extend8_s` or `i32.extend16_s` values compared with constants outside the signed lane range now fold, preserving effectful inputs before the folded constant. The living log records the Binaryen probe and focused red-first evidence.
- A 2026-06-25 OI-G slice extends direct load/store cleanup in [`../../../../../src/passes/optimize_instructions.mbt`](../../../../../src/passes/optimize_instructions.mbt): one-use full-width load children under `f32.reinterpret_i32`, `f64.reinterpret_i64`, `i32.reinterpret_f32`, and `i64.reinterpret_f64` now rewrite to representation loads (`f32.load`, `f64.load`, `i32.load`, `i64.load`) matching Binaryen `version_130`. The living log records the Binaryen probe and red-first focused evidence.
- [`../../../raw/research/0842-2026-06-25-optimize-instructions-oi-g-extend-load.md`](../../../raw/research/0842-2026-06-25-optimize-instructions-oi-g-extend-load.md) extends `[O4Z-AUDIT-OI-G]` load-result cleanup: one-use i32 loads under `i64.extend_i32_u` / `i64.extend_i32_s` now rewrite to matching i64 representation loads when the loaded-value semantics are identical.
- [`../../../raw/research/0844-2026-06-25-optimize-instructions-oi-g-load-memargs.md`](../../../raw/research/0844-2026-06-25-optimize-instructions-oi-g-load-memargs.md) locks the memarg-preservation detail for OI-G representation-load rewrites: replacement `f32.load`, `i64.load32_u`, and `i64.load16_s` operations keep the source load offset and alignment.
- [`../../../raw/research/0860-2026-06-25-optimize-instructions-oi-g-mixed-parameterized-memory-copy.md`](../../../raw/research/0860-2026-06-25-optimize-instructions-oi-g-mixed-parameterized-memory-copy.md) extends the OI-G stack-carried tiny-copy raw-gate escape: each address operand may now independently be a pure/local constant or no-param direct call, or a pure argument followed by a one-param direct call, before the existing HOT load/store lowering runs.
- [`../../../raw/research/0861-2026-06-25-optimize-instructions-oi-g-parameterized-byte-fill.md`](../../../raw/research/0861-2026-06-25-optimize-instructions-oi-g-parameterized-byte-fill.md) extends the OI-G stack-carried byte-fill raw-gate escape to the matching one-pure-argument direct-call destination/value operands, while keeping wider call-backed fills as documented Binaryen keep-spelling boundaries.
- [`../../../raw/research/0864-2026-06-25-optimize-instructions-oi-g-global-bulk-memory.md`](../../../raw/research/0864-2026-06-25-optimize-instructions-oi-g-global-bulk-memory.md) extends the OI-G tiny bulk-memory raw-gate escape to `global.get` operands used directly or as direct-call arguments, with the order-safety proof kept bulk-memory-specific rather than applying to commutative stack-call binops.
- [`../../../raw/research/0847-2026-06-25-optimize-instructions-oi-g-local-carried-load-boundary.md`](../../../raw/research/0847-2026-06-25-optimize-instructions-oi-g-local-carried-load-boundary.md) records that local-carried/shared load-result spellings are a source-backed OI-G boundary: Binaryen keeps the probed `local.tee(i32.load)` plus reinterpret/extend forms, matching Starshine's direct one-use load-child guard.
- [`../../../raw/research/0849-2026-06-25-optimize-instructions-oi-g-local-carried-store-boundary.md`](../../../raw/research/0849-2026-06-25-optimize-instructions-oi-g-local-carried-store-boundary.md) records the analogous local-carried/shared reinterpret-store boundary: Binaryen keeps the probed `local.tee(f32.reinterpret_i32(...))` and `local.set`/`local.get` forms before `f32.store`, matching Starshine's direct one-use stored-value guard.
- [`../../../raw/research/0845-2026-06-25-optimize-instructions-oi-h-multivalue-arg-return-call-ref-boundary.md`](../../../raw/research/0845-2026-06-25-optimize-instructions-oi-h-multivalue-arg-return-call-ref-boundary.md) extends the OI-H multi-result argument select-of-`ref.func` boundary to `return_call_ref`: Binaryen lowers through tuple scratch plus scalar locals, while Starshine keeps the tail-call form until tuple-scratch localization is implemented.
- [`../../../raw/research/0846-2026-06-25-optimize-instructions-oi-m-multiresult-sibling-boundary.md`](../../../raw/research/0846-2026-06-25-optimize-instructions-oi-m-multiresult-sibling-boundary.md) records an OI-M tuple boundary: Binaryen localizes a multi-result non-selected tuple sibling through tuple scratch and scalar drops, while Starshine keeps the direct-HOT tuple spelling until a safe multi-result sibling localizer exists.
- [`../../../raw/research/0848-2026-06-25-optimize-instructions-oi-m-simplify-locals-neighbor.md`](../../../raw/research/0848-2026-06-25-optimize-instructions-oi-m-simplify-locals-neighbor.md) adds first OI-M local-cleanup neighbor coverage: the covered single-result effectful-sibling tuple localization remains a temp-local/effect-drop block after `simplify-locals-nostructure`, matching the Binaryen `version_130` probe without closing tuple-scratch or broader tuple-neighbor parity.
- [`../../../raw/research/0865-2026-06-25-optimize-instructions-oi-m-trapping-sibling.md`](../../../raw/research/0865-2026-06-25-optimize-instructions-oi-m-trapping-sibling.md) locks trap preservation for the covered one-use tuple extraction localizer: earlier and later non-selected `i32.load` siblings remain dropped effects around the selected lane instead of being treated as pure tuple debris.
- [`../../../raw/research/0866-2026-06-25-optimize-instructions-oi-g-v128-memory-copy.md`](../../../raw/research/0866-2026-06-25-optimize-instructions-oi-g-v128-memory-copy.md) extends OI-G exact constant-size `memory.copy` lowering to size `16`, matching Binaryen's `v128.load` / `v128.store` one-load/one-store shape and updating the tiny bulk-memory raw gate accordingly.
- [`../../../raw/research/0880-2026-06-25-optimize-instructions-oi-g-stack-v128-memory-copy.md`](../../../raw/research/0880-2026-06-25-optimize-instructions-oi-g-stack-v128-memory-copy.md) adds public-pipeline status coverage for that same size-16 `memory.copy` lane when destination and source are no-parameter direct calls; Starshine reaches `v128.load` / `v128.store` without the stack-carried-effect raw skip and preserves destination-before-source call order.
- [`../../../raw/research/0867-2026-06-25-optimize-instructions-oi-m-selected-trapping-lane.md`](../../../raw/research/0867-2026-06-25-optimize-instructions-oi-m-selected-trapping-lane.md) adds OI-M selected-lane trap coverage: a selected `i32.load` child of one-use `tuple.extract(tuple.make(...))` remains the returned load rather than being omitted as tuple debris.
- [`../../../raw/research/0868-2026-06-25-optimize-instructions-oi-g-v128-zero-memory-fill.md`](../../../raw/research/0868-2026-06-25-optimize-instructions-oi-g-v128-zero-memory-fill.md) extends OI-G exact constant-size `memory.fill` lowering to the size-16 zero-fill subset, matching Binaryen's `v128.const 0` / `v128.store` shape; its temporary nonzero repeated-byte boundary is superseded by the next OI-G slice.
- [`../../../raw/research/0869-2026-06-25-optimize-instructions-oi-m-selected-trapping-effectful-sibling.md`](../../../raw/research/0869-2026-06-25-optimize-instructions-oi-m-selected-trapping-effectful-sibling.md) adds OI-M coverage for the selected trapping tuple lane when a later sibling has effects; Starshine stores the exact selected `i32.load`, drops the sibling call, and reloads the selected temp.
- [`../../../raw/research/0870-2026-06-25-optimize-instructions-oi-g-v128-nonzero-memory-fill.md`](../../../raw/research/0870-2026-06-25-optimize-instructions-oi-g-v128-nonzero-memory-fill.md) completes OI-G constant size-16 repeated-byte `memory.fill` lowering by materializing arbitrary constant low bytes as repeated-byte `v128.const` values before `v128.store`.
- [`../../../raw/research/0871-2026-06-25-optimize-instructions-oi-m-selected-trapping-earlier-sibling.md`](../../../raw/research/0871-2026-06-25-optimize-instructions-oi-m-selected-trapping-earlier-sibling.md) adds OI-M coverage for a selected trapping tuple lane after an earlier effectful sibling; Starshine preserves `drop(call)` before the exact selected `i32.load`.
- [`../../../raw/research/0872-2026-06-25-optimize-instructions-oi-g-zero-bulk-effects.md`](../../../raw/research/0872-2026-06-25-optimize-instructions-oi-g-zero-bulk-effects.md) records the effectful zero-size bulk-memory boundary: Binaryen and Starshine keep zero-size `memory.copy` / `memory.fill` with call operands instead of dropping operand effects.
- [`../../../raw/research/0873-2026-06-25-optimize-instructions-oi-m-selected-trapping-earlier-later-siblings.md`](../../../raw/research/0873-2026-06-25-optimize-instructions-oi-m-selected-trapping-earlier-later-siblings.md) adds OI-M coverage for a selected trapping tuple lane with both earlier and later effectful siblings; Starshine preserves the same drop/store/drop/reload order as Binaryen's tuple-scratch shape.
- [`../../../raw/research/0874-2026-06-25-optimize-instructions-oi-g-nonconstant-bulk-effects.md`](../../../raw/research/0874-2026-06-25-optimize-instructions-oi-g-nonconstant-bulk-effects.md) records the effectful dynamic-size bulk-memory boundary: Binaryen and Starshine keep `memory.copy` / `memory.fill` with call-backed size operands instead of guessing exact tiny lowering.
- [`../../../raw/research/0875-2026-06-25-optimize-instructions-oi-m-selected-trapping-two-later-siblings.md`](../../../raw/research/0875-2026-06-25-optimize-instructions-oi-m-selected-trapping-two-later-siblings.md) adds OI-M coverage for a selected trapping tuple lane with an earlier effectful sibling and two later effectful siblings; Starshine preserves the same drop/store/drop/drop/reload order as Binaryen's tuple-scratch shape.
- [`../../../raw/research/0876-2026-06-25-optimize-instructions-oi-g-local-dynamic-bulk.md`](../../../raw/research/0876-2026-06-25-optimize-instructions-oi-g-local-dynamic-bulk.md) records the local dynamic-size bulk-memory boundary: Binaryen and Starshine keep `memory.copy` / `memory.fill` with nonconstant local size operands instead of guessing exact tiny lowering.
- [`../../../raw/research/0877-2026-06-25-optimize-instructions-oi-m-selected-trapping-two-earlier-siblings.md`](../../../raw/research/0877-2026-06-25-optimize-instructions-oi-m-selected-trapping-two-earlier-siblings.md) adds OI-M coverage for a selected trapping tuple lane after two earlier effectful siblings; Starshine preserves both earlier drops before the exact selected load.
- [`../../../raw/research/0879-2026-06-25-optimize-instructions-oi-m-selected-trapping-two-earlier-one-later.md`](../../../raw/research/0879-2026-06-25-optimize-instructions-oi-m-selected-trapping-two-earlier-one-later.md) adds OI-M coverage for a selected trapping tuple lane with two earlier effectful siblings and one later effectful sibling; Starshine preserves two earlier drops, the selected temp store, the later drop, and the final reload.
- [`../../../raw/research/0881-2026-06-25-optimize-instructions-oi-m-selected-trapping-two-earlier-two-later.md`](../../../raw/research/0881-2026-06-25-optimize-instructions-oi-m-selected-trapping-two-earlier-two-later.md) extends that selected trapping tuple coverage to two earlier plus two later effectful siblings, preserving the same drop/drop/store/drop/drop/reload order as Binaryen's tuple-scratch shape.
- [`../../../raw/research/0823-2026-06-20-optimize-instructions-oi-k-struct-get-new.md`](../../../raw/research/0823-2026-06-20-optimize-instructions-oi-k-struct-get-new.md) records the first `[O4Z-AUDIT-OI-K]` sub-slice: Starshine now forwards pure `struct.get` operations over matching `struct.new` constructors and keeps effectful sibling-field cases unchanged until a safe localizing lowering can preserve those effects.
- [`../../../raw/research/0824-2026-06-20-optimize-instructions-oi-k-packed-struct-get-new.md`](../../../raw/research/0824-2026-06-20-optimize-instructions-oi-k-packed-struct-get-new.md) records the second `[O4Z-AUDIT-OI-K]` sub-slice: Starshine now forwards pure packed `struct.get_s` / `struct.get_u` operations over matching `struct.new` constructors, preserving signedness with constants, sign-extension, or masks.
- [`../../../raw/research/0825-2026-06-20-optimize-instructions-oi-k-array-len-new-fixed.md`](../../../raw/research/0825-2026-06-20-optimize-instructions-oi-k-array-len-new-fixed.md) records the third `[O4Z-AUDIT-OI-K]` sub-slice: Starshine now folds pure one-use `array.len(array.new_fixed(...))` to the fixed length while keeping effectful element operands unchanged.
- [`../../../raw/research/0826-2026-06-20-optimize-instructions-oi-k-array-get-new-fixed.md`](../../../raw/research/0826-2026-06-20-optimize-instructions-oi-k-array-get-new-fixed.md) records the fourth `[O4Z-AUDIT-OI-K]` sub-slice: Starshine now forwards constant-index plain `array.get` over matching one-use `array.new_fixed` elements and folds constant out-of-bounds indexes to `unreachable`, while keeping effectful sibling-element cases unchanged until safe localization exists.
- [`../../../raw/research/0827-2026-06-21-optimize-instructions-oi-k-packed-array-get-new-fixed.md`](../../../raw/research/0827-2026-06-21-optimize-instructions-oi-k-packed-array-get-new-fixed.md) records the fifth `[O4Z-AUDIT-OI-K]` sub-slice: Starshine now forwards constant-index packed `array.get_s` / `array.get_u` over matching one-use `array.new_fixed` elements, preserving signedness through constants, sign-extension, or masks, while keeping dynamic indexes and effectful sibling-element cases unchanged until safe localization exists.
- [`../../../raw/research/0828-2026-06-21-optimize-instructions-oi-k-struct-new-default.md`](../../../raw/research/0828-2026-06-21-optimize-instructions-oi-k-struct-new-default.md) records the sixth `[O4Z-AUDIT-OI-K]` sub-slice: Starshine now folds direct one-use plain and packed `struct.get(struct.new_default ...)` field reads to WebAssembly default values, while keeping descriptor default constructors and broader array/default/atomic/localization work open.
- [`../../../raw/research/0829-2026-06-21-optimize-instructions-oi-k-array-new-default-get.md`](../../../raw/research/0829-2026-06-21-optimize-instructions-oi-k-array-new-default-get.md) records the seventh `[O4Z-AUDIT-OI-K]` sub-slice: Starshine now folds direct one-use constant-length/index plain and packed `array.get(array.new_default ...)` reads to zero/default values or `unreachable` for out-of-bounds, while keeping dynamic lengths/indexes and broader array/default/localization work open.
- [`../../../raw/research/0830-2026-06-21-optimize-instructions-oi-k-array-new-default-len.md`](../../../raw/research/0830-2026-06-21-optimize-instructions-oi-k-array-new-default-len.md) records the eighth `[O4Z-AUDIT-OI-K]` sub-slice: Starshine now folds direct one-use small non-negative constant-length `array.len(array.new_default ...)` to the length constant, while keeping dynamic, negative, and huge non-negative lengths unchanged to preserve allocation traps.
- [`../../../raw/research/0831-2026-06-21-optimize-instructions-oi-k-array-new-len.md`](../../../raw/research/0831-2026-06-21-optimize-instructions-oi-k-array-new-len.md) records the ninth `[O4Z-AUDIT-OI-K]` sub-slice: Starshine now folds direct one-use `array.len(array.new ...)` to the bounded constant length when both the repeated value and length are `i32.const`, while keeping nonconstant/effectful repeated values and trap-preserving length boundaries unchanged.
- [`../../../raw/research/0832-2026-06-21-optimize-instructions-oi-k-array-new-get.md`](../../../raw/research/0832-2026-06-21-optimize-instructions-oi-k-array-new-get.md) records the tenth `[O4Z-AUDIT-OI-K]` sub-slice: Starshine now forwards constant-index plain and packed `array.get(array.new ...)` repeated values for small constant lengths, preserves effectful selected values, folds pure out-of-bounds reads to `unreachable`, and keeps dynamic indexes plus effectful out-of-bounds localization open.
- [`../../../raw/research/0833-2026-06-21-optimize-instructions-oi-k-array-set-fresh.md`](../../../raw/research/0833-2026-06-21-optimize-instructions-oi-k-array-set-fresh.md) records the eleventh `[O4Z-AUDIT-OI-K]` sub-slice: Starshine now removes pure constant-index `array.set` operations targeting direct one-use fresh `array.new_fixed` or small constant-length `array.new_default` arrays, folding pure out-of-bounds writes to `unreachable` while keeping dynamic indexes and effectful value/sibling localization open.
- [`../../../raw/research/0835-2026-06-23-optimize-instructions-oi-k-array-set-new.md`](../../../raw/research/0835-2026-06-23-optimize-instructions-oi-k-array-set-new.md) records the twelfth `[O4Z-AUDIT-OI-K]` sub-slice: Starshine now removes pure constant-index `array.set` operations targeting direct one-use fresh `array.new(value, len)` repeated-value arrays, folding pure out-of-bounds writes to `unreachable` while keeping effectful set-value/repeated-value operands and dynamic/huge lengths as explicit localizing/trap boundaries.
- [`../../../raw/research/0836-2026-06-23-optimize-instructions-oi-k-array-fill-copy-boundary.md`](../../../raw/research/0836-2026-06-23-optimize-instructions-oi-k-array-fill-copy-boundary.md) records a `[O4Z-AUDIT-OI-K]` boundary classification: Binaryen `optimize-instructions` (direct and O4z-style) does not fold fresh-array `array.fill` / `array.copy`, so Starshine keeping them is correct OI parity rather than a gap; a named/commented direct-core boundary test locks the classification.
- [`../../../raw/research/0834-2026-06-21-optimize-instructions-oi-m-tuple-extract-make.md`](../../../raw/research/0834-2026-06-21-optimize-instructions-oi-m-tuple-extract-make.md) records the first `[O4Z-AUDIT-OI-M]` sub-slice; Starshine now forwards one-use `tuple.extract(tuple.make(...))` when every non-selected tuple child is side-effect-free and localizes the selected lane for the covered single-result effectful-sibling cases. Additional 2026-06-24 focused coverage locks earlier-plus-later effectful sibling ordering (`drop` earlier effect, `local.set` selected lane, `drop` later effect, reload selected value). A 2026-06-25 boundary slice locks local-carried / direct-HOT multi-use tuple extraction as keep-spelling, matching the probed Binaryen `version_130` shape; broader tuple tee/drop reconstruction remains open.
- [`../../../raw/research/0733-2026-06-19-optimize-instructions-oi-g-wide-memory-fill.md`](../../../raw/research/0733-2026-06-19-optimize-instructions-oi-g-wide-memory-fill.md) records the second `[O4Z-AUDIT-OI-G]` sub-slice for constant-value size-2 and size-4 `memory.fill` lowering and nonconstant wider-fill boundary evidence.
- [`../../../raw/research/0734-2026-06-19-optimize-instructions-oi-g-eight-byte-fill.md`](../../../raw/research/0734-2026-06-19-optimize-instructions-oi-g-eight-byte-fill.md) records the third `[O4Z-AUDIT-OI-G]` sub-slice for constant-value size-8 `memory.fill` lowering to repeated-byte `i64.store` while keeping nonconstant wider fills open.
- [`../../../raw/research/0735-2026-06-19-optimize-instructions-oi-g-local-fill.md`](../../../raw/research/0735-2026-06-19-optimize-instructions-oi-g-local-fill.md) records the fourth `[O4Z-AUDIT-OI-G]` sub-slice for local.get value size-2 and size-4 `memory.fill` lowering through low-byte mask and repeat multiply expressions while keeping effectful values and nonconstant size-8 fills open.
- [`../../../raw/research/0736-2026-06-19-optimize-instructions-oi-g-local-eight-fill.md`](../../../raw/research/0736-2026-06-19-optimize-instructions-oi-g-local-eight-fill.md) records the fifth `[O4Z-AUDIT-OI-G]` sub-slice for local.get value size-8 `memory.fill` lowering through low-byte mask, `i64.extend_i32_u`, and repeated-byte `i64.mul`; a 2026-06-25 boundary refresh locks direct-call and computed `i32.add` wider fill values as keep-spelling forms matching Binaryen `version_130`.
- [`../../../raw/research/0737-2026-06-19-optimize-instructions-oi-g-wider-memory-copy.md`](../../../raw/research/0737-2026-06-19-optimize-instructions-oi-g-wider-memory-copy.md) records the sixth `[O4Z-AUDIT-OI-G]` sub-slice for constant-size `2`/`4`/`8` `memory.copy` lowering to exact load/store pairs while preserving overlap and trap safety; [`../../../raw/research/0866-2026-06-25-optimize-instructions-oi-g-v128-memory-copy.md`](../../../raw/research/0866-2026-06-25-optimize-instructions-oi-g-v128-memory-copy.md) extends the same one-load/one-store proof to size `16` using `v128.load` / `v128.store`.
- [`../../../raw/research/0738-2026-06-19-optimize-instructions-oi-g-memory-copy-boundaries.md`](../../../raw/research/0738-2026-06-19-optimize-instructions-oi-g-memory-copy-boundaries.md) records the seventh `[O4Z-AUDIT-OI-G]` boundary sub-slice for intentionally keeping zero-size and nonconstant-size `memory.copy` unchanged without trap-relaxed mode support or an exact-size proof; its old size-16 boundary is superseded by the v128 lowering slice above.
- [`../../../raw/research/0739-2026-06-19-optimize-instructions-oi-g-memory64-copy.md`](../../../raw/research/0739-2026-06-19-optimize-instructions-oi-g-memory64-copy.md) records the eighth `[O4Z-AUDIT-OI-G]` sub-slice for direct-core memory64 `memory.copy` fixtures that prove i64 address preservation for size-1 and size-8 exact lowering plus oversized/nonconstant memory64 length boundaries.
- [`../../../raw/research/0740-2026-06-19-optimize-instructions-oi-g-memory64-fill.md`](../../../raw/research/0740-2026-06-19-optimize-instructions-oi-g-memory64-fill.md) records the ninth `[O4Z-AUDIT-OI-G]` sub-slice: validator/typechecker memory64 `memory.fill` length acceptance plus direct-core OI fixtures proving size-1 and size-8 fill lowering preserves `i64` destination operands.
- [`../../../raw/research/0741-2026-06-19-optimize-instructions-oi-g-narrow-store-mask.md`](../../../raw/research/0741-2026-06-19-optimize-instructions-oi-g-narrow-store-mask.md) records the tenth `[O4Z-AUDIT-OI-G]` sub-slice: a narrow `optimizeStoredValue` subset that drops redundant `i32.and` masks before `i32.store8` / `i32.store16` when all written low bits are preserved, plus focused value-changing-mask boundaries.
- [`../../../raw/research/0742-2026-06-19-optimize-instructions-oi-g-i64-narrow-store-mask.md`](../../../raw/research/0742-2026-06-19-optimize-instructions-oi-g-i64-narrow-store-mask.md) records the eleventh `[O4Z-AUDIT-OI-G]` sub-slice: a Starshine-win generalization that drops redundant `i64.and` masks before `i64.store8` / `i64.store16` / `i64.store32` when all written low bits are preserved, while explicitly documenting that Binaryen `version_130` keeps those exact i64 masks.
- [`../../../raw/research/0743-2026-06-19-optimize-instructions-oi-g-const-memory-offset.md`](../../../raw/research/0743-2026-06-19-optimize-instructions-oi-g-const-memory-offset.md) records the twelfth `[O4Z-AUDIT-OI-G]` sub-slice: the source-backed `optimizeMemoryAccess` constant-pointer static-offset fold for memory32 loads/stores, plus the Binaryen-style positive-`i32` range boundary.
- [`../../../raw/research/0744-2026-06-19-optimize-instructions-oi-g-memory64-const-offset.md`](../../../raw/research/0744-2026-06-19-optimize-instructions-oi-g-memory64-const-offset.md) records the thirteenth `[O4Z-AUDIT-OI-G]` sub-slice: the memory64 extension of constant-pointer static-offset folding for scalar loads/stores, using direct-core fixtures and Binaryen's unsigned `u64` no-wrap boundary.
- [`../../../raw/research/0745-2026-06-19-optimize-instructions-oi-g-load-call-offset-boundary.md`](../../../raw/research/0745-2026-06-19-optimize-instructions-oi-g-load-call-offset-boundary.md) records the fourteenth `[O4Z-AUDIT-OI-G]` sub-slice: an explicit fail-closed `load-call-optimize-instructions-noop` decision for scalar load constant-offset folding. Binaryen folds the mixed load/call fixture, but Starshine keeps the public pipeline raw gate until a broader safe escape proof exists.
- [`../../../raw/research/0746-2026-06-19-optimize-instructions-oi-g-commuted-store-mask.md`](../../../raw/research/0746-2026-06-19-optimize-instructions-oi-g-commuted-store-mask.md) records the fifteenth `[O4Z-AUDIT-OI-G]` sub-slice: redundant narrow-store mask cleanup now accepts the constant mask on either side of the `and`, matching Binaryen for the `i32.store8` / `i32.store16` cases and preserving the documented Starshine-win `i64` generalization.
- [`../../../raw/research/0747-2026-06-19-optimize-instructions-oi-g-const-store-value.md`](../../../raw/research/0747-2026-06-19-optimize-instructions-oi-g-const-store-value.md) records the sixteenth `[O4Z-AUDIT-OI-G]` sub-slice: constant stored values are truncated before `i32.store8` / `i32.store16` and `i64.store8` / `i64.store16` / `i64.store32`, matching Binaryen-observable `optimizeStoredValue` behavior for the covered constants.
- [`../../../raw/research/0748-2026-06-19-optimize-instructions-oi-g-byte-fill-const-truncation.md`](../../../raw/research/0748-2026-06-19-optimize-instructions-oi-g-byte-fill-const-truncation.md) records the seventeenth `[O4Z-AUDIT-OI-G]` sub-slice: size-1 constant `memory.fill` lowering now canonicalizes oversized values to their low byte before materializing `i32.store8`, matching Binaryen-observable `optimizeMemoryFill` spelling for the covered constants.
- [`../../../raw/research/0749-2026-06-19-optimize-instructions-oi-g-pointer-add-boundary.md`](../../../raw/research/0749-2026-06-19-optimize-instructions-oi-g-pointer-add-boundary.md) records the eighteenth `[O4Z-AUDIT-OI-G]` sub-slice: a source-backed boundary decision that nonconstant pointer-add address forms such as `local.get + const` are not claimed as `optimize-instructions`-owned load/store offset canonicalization under Binaryen `version_130`; Starshine keeps the tested forms unchanged.
- [`../../../raw/research/0815-2026-06-20-optimize-instructions-oi-g-signext-store-boundary.md`](../../../raw/research/0815-2026-06-20-optimize-instructions-oi-g-signext-store-boundary.md) records the nineteenth `[O4Z-AUDIT-OI-G]` boundary sub-slice: Binaryen `version_130` canonicalizes sign-extension shift pairs before narrow stores to explicit sign-extension opcodes but does not drop those opcodes, so Starshine locks the same keep-spelling boundary rather than treating sign-extension-before-store removal as an OI-owned gap.
- [`../../../raw/research/0816-2026-06-20-optimize-instructions-oi-g-effectful-memory-copy-boundary.md`](../../../raw/research/0816-2026-06-20-optimize-instructions-oi-g-effectful-memory-copy-boundary.md) records the twentieth `[O4Z-AUDIT-OI-G]` boundary sub-slice: Binaryen `version_130` lowers stack-carried effectful-call size-1/8 `memory.copy` operands to load/store forms, while Starshine keeps the same shapes behind `stack-carried-effect-optimize-instructions-noop` until a localizing/HOT lowering can prove call-result preservation without reordering.
- [`../../../raw/research/0817-2026-06-20-optimize-instructions-oi-g-signed-load-store-boundary.md`](../../../raw/research/0817-2026-06-20-optimize-instructions-oi-g-signed-load-store-boundary.md) records the twenty-first `[O4Z-AUDIT-OI-G]` boundary sub-slice: Binaryen `version_130` keeps signed loads before matching narrow stores, so Starshine locks those exact signed-load-before-store spellings as non-gaps.
