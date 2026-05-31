///|
pub enum GenInvalidSeedMode {
  RandomValidSeed
  MinimalValidSeed
} derive(Eq, Debug)

///|
pub enum GenInvalidNamedSeedProfile {
  NaturalSeedProfile
  CoverageForcedSeedProfile
  SmallNaturalSeedProfile
  SmallCoverageForcedSeedProfile
  ReproSeedProfile
  MinimalSeedProfile
  RichSeedProfile
} derive(Eq, Debug)

///|
pub fn gen_invalid_seed_mode_name(mode : GenInvalidSeedMode) -> String {
  match mode {
    RandomValidSeed => "random-valid"
    MinimalValidSeed => "minimal-valid"
  }
}

///|
pub fn gen_invalid_named_seed_profile_name(
  profile : GenInvalidNamedSeedProfile,
) -> String {
  match profile {
    NaturalSeedProfile => "natural"
    CoverageForcedSeedProfile => "coverage-forced"
    SmallNaturalSeedProfile => "small-natural"
    SmallCoverageForcedSeedProfile => "small-coverage-forced"
    ReproSeedProfile => "repro"
    MinimalSeedProfile => "minimal"
    RichSeedProfile => "rich"
  }
}

///|
pub struct GenInvalidAstParams {
  strategy : ValidateInvalidAstStrategyId
  seed_mode : GenInvalidSeedMode
  seed_profile : GenInvalidNamedSeedProfile?
  generator_config : GenValidConfig
  require_strategy_prereqs : Bool
} derive(Eq, Debug)

///|
pub fn gen_invalid_coverage_seed_generator_config() -> GenValidConfig {
  GenValidConfig::for_profile(MutationSeedRichProfile)
}

///|
pub fn GenInvalidAstParams::new(
  strategy : ValidateInvalidAstStrategyId,
  seed_mode? : GenInvalidSeedMode = RandomValidSeed,
  generator_config? : GenValidConfig = gen_invalid_coverage_seed_generator_config(),
  require_strategy_prereqs? : Bool = true,
) -> GenInvalidAstParams {
  {
    strategy,
    seed_mode,
    seed_profile: None,
    generator_config,
    require_strategy_prereqs,
  }
}

///|
pub fn GenInvalidAstParams::natural_seed(
  strategy : ValidateInvalidAstStrategyId,
  generator_config? : GenValidConfig = GenValidConfig::natural_default(),
  require_strategy_prereqs? : Bool = true,
) -> GenInvalidAstParams {
  {
    strategy,
    seed_mode: RandomValidSeed,
    seed_profile: Some(NaturalSeedProfile),
    generator_config,
    require_strategy_prereqs,
  }
}

///|
pub fn GenInvalidAstParams::coverage_forced_seed(
  strategy : ValidateInvalidAstStrategyId,
  generator_config? : GenValidConfig = gen_invalid_coverage_seed_generator_config(),
  require_strategy_prereqs? : Bool = true,
) -> GenInvalidAstParams {
  {
    strategy,
    seed_mode: RandomValidSeed,
    seed_profile: Some(CoverageForcedSeedProfile),
    generator_config,
    require_strategy_prereqs,
  }
}

///|
pub fn GenInvalidAstParams::small_natural_seed(
  strategy : ValidateInvalidAstStrategyId,
  generator_config? : GenValidConfig = GenValidConfig::natural_default(),
  require_strategy_prereqs? : Bool = true,
) -> GenInvalidAstParams {
  {
    strategy,
    seed_mode: RandomValidSeed,
    seed_profile: Some(SmallNaturalSeedProfile),
    generator_config: gen_invalid_small_gen_valid_config(generator_config),
    require_strategy_prereqs,
  }
}

///|
pub fn GenInvalidAstParams::small_coverage_forced_seed(
  strategy : ValidateInvalidAstStrategyId,
  generator_config? : GenValidConfig = gen_invalid_coverage_seed_generator_config(),
  require_strategy_prereqs? : Bool = true,
) -> GenInvalidAstParams {
  {
    strategy,
    seed_mode: RandomValidSeed,
    seed_profile: Some(SmallCoverageForcedSeedProfile),
    generator_config: gen_invalid_small_gen_valid_config(generator_config),
    require_strategy_prereqs,
  }
}

///|
pub fn GenInvalidAstParams::repro_seed(
  strategy : ValidateInvalidAstStrategyId,
  generator_config? : GenValidConfig = gen_invalid_coverage_seed_generator_config(),
  require_strategy_prereqs? : Bool = true,
) -> GenInvalidAstParams {
  {
    strategy,
    seed_mode: RandomValidSeed,
    seed_profile: Some(ReproSeedProfile),
    generator_config: gen_invalid_small_gen_valid_config(generator_config),
    require_strategy_prereqs,
  }
}

///|
pub fn GenInvalidAstParams::minimal_seed(
  strategy : ValidateInvalidAstStrategyId,
  generator_config? : GenValidConfig = gen_invalid_coverage_seed_generator_config(),
  require_strategy_prereqs? : Bool = true,
) -> GenInvalidAstParams {
  {
    strategy,
    seed_mode: MinimalValidSeed,
    seed_profile: Some(MinimalSeedProfile),
    generator_config,
    require_strategy_prereqs,
  }
}

///|
pub fn GenInvalidAstParams::rich_seed(
  strategy : ValidateInvalidAstStrategyId,
  generator_config? : GenValidConfig = gen_invalid_coverage_seed_generator_config(),
  require_strategy_prereqs? : Bool = true,
) -> GenInvalidAstParams {
  {
    strategy,
    seed_mode: RandomValidSeed,
    seed_profile: Some(RichSeedProfile),
    generator_config,
    require_strategy_prereqs,
  }
}

///|
pub fn gen_invalid_ast_params_profile_name(
  params : GenInvalidAstParams,
) -> String {
  match params.seed_profile {
    Some(profile) => gen_invalid_named_seed_profile_name(profile)
    None => "custom"
  }
}

///|
pub struct GenInvalidAstGenerated {
  base_module : Module
  mutation : ValidateInvalidAstMutation
} derive(Debug)

///|
fn gen_invalid_ast_strategy_label(
  strategy : ValidateInvalidAstStrategyId,
) -> String {
  match strategy {
    DuplicateExportName => "duplicate-export-name"
    InvalidExportFuncIndex => "invalid-export-func-index"
    InvalidExportFuncWrongKindIndex => "invalid-export-func-wrong-kind-index"
    InvalidImportedStartFuncParam => "invalid-imported-start-func-param"
    InvalidImportedStartFuncResult => "invalid-imported-start-func-result"
    InvalidImportedStartFuncParamResult =>
      "invalid-imported-start-func-param-result"
    InvalidImportedStartFuncMultiParam =>
      "invalid-imported-start-func-multi-param"
    InvalidImportedStartFuncF32Param => "invalid-imported-start-func-f32-param"
    InvalidImportedStartFuncExternrefParam =>
      "invalid-imported-start-func-externref-param"
    InvalidImportedStartFuncFuncrefParam =>
      "invalid-imported-start-func-funcref-param"
    InvalidStartSignature => "invalid-start-signature"
    StartFuncOutOfRange => "start-func-out-of-range"
    StartFuncWrongKindIndex => "start-func-wrong-kind-index"
    MissingDataCount => "missing-datacount"
    MissingDataCountDataDrop => "missing-datacount-data-drop"
    InvalidFunctionBodyLocalIndex => "invalid-function-body-local-index"
    InvalidFunctionBodyGlobalIndex => "invalid-function-body-global-index"
    InvalidFunctionBodyTableIndex => "invalid-function-body-table-index"
    InvalidFunctionBodyMemoryIndex => "invalid-function-body-memory-index"
    InvalidFunctionBodyCallIndex => "invalid-function-body-call-index"
    InvalidFunctionBodyBrLabelIndex =>
      "invalid-function-body-branch-label-index"
    InvalidFunctionBodyBrPayloadMismatch =>
      "invalid-function-body-branch-payload-mismatch"
    InvalidFunctionBodyCallPayloadMismatch =>
      "invalid-function-body-call-payload-mismatch"
    InvalidFunctionBodyBrIfPayloadMismatch =>
      "invalid-function-body-br-if-payload-mismatch"
    InvalidFunctionBodyBrTablePayloadMismatch =>
      "invalid-function-body-br-table-payload-mismatch"
    InvalidFunctionBodyBrOnNullPayloadMismatch =>
      "invalid-function-body-br-on-null-payload-mismatch"
    InvalidFunctionBodyIfConditionType =>
      "invalid-function-body-if-condition-type"
    InvalidFunctionBodyIfBranchResultType =>
      "invalid-function-body-if-branch-result-type"
    InvalidFunctionBodySelectConditionType =>
      "invalid-function-body-select-condition-type"
    InvalidFunctionBodySelectOperandType =>
      "invalid-function-body-select-operand-type"
    InvalidFunctionBodyThrowPayloadMismatch =>
      "invalid-function-body-throw-payload-mismatch"
    InvalidFunctionBodyTryTableCatchPayloadMismatch =>
      "invalid-function-body-try-table-catch-payload-mismatch"
    InvalidFunctionBodyThrowPayloadArityMismatch =>
      "invalid-function-body-throw-payload-arity-mismatch"
    InvalidFunctionBodyThrowTagIndex => "invalid-function-body-throw-tag-index"
    InvalidFunctionBodyMemoryAddressType =>
      "invalid-function-body-memory-address-type"
    InvalidFunctionBodyMemory64AddressType =>
      "invalid-function-body-memory64-address-type"
    InvalidFunctionBodyMemoryStoreAddressType =>
      "invalid-function-body-memory-store-address-type"
    InvalidFunctionBodyMemory64StoreAddressType =>
      "invalid-function-body-memory64-store-address-type"
    InvalidFunctionBodyMemoryStoreValueType =>
      "invalid-function-body-memory-store-value-type"
    InvalidFunctionBodyMemory64StoreValueType =>
      "invalid-function-body-memory64-store-value-type"
    InvalidFunctionBodyMemoryLoadAlignment =>
      "invalid-function-body-memory-load-alignment"
    InvalidFunctionBodyMemoryStoreAlignment =>
      "invalid-function-body-memory-store-alignment"
    InvalidFunctionBodyMemoryLoadOffsetRange =>
      "invalid-function-body-memory-load-offset-range"
    InvalidFunctionBodyMemoryStoreOffsetRange =>
      "invalid-function-body-memory-store-offset-range"
    InvalidFunctionBodyMemoryLoadIndex =>
      "invalid-function-body-memory-load-index"
    InvalidFunctionBodyMemoryStoreIndex =>
      "invalid-function-body-memory-store-index"
    InvalidFunctionBodyMemoryCopyDestIndex =>
      "invalid-function-body-memory-copy-dest-index"
    InvalidFunctionBodyMemoryCopySourceIndex =>
      "invalid-function-body-memory-copy-source-index"
    InvalidFunctionBodyMemorySizeIndex =>
      "invalid-function-body-memory-size-index"
    InvalidFunctionBodyMemoryGrowIndex =>
      "invalid-function-body-memory-grow-index"
    InvalidFunctionBodyMemoryGrowDeltaType =>
      "invalid-function-body-memory-grow-delta-type"
    InvalidFunctionBodyMemoryFillValueType =>
      "invalid-function-body-memory-fill-value-type"
    InvalidFunctionBodyMemoryFillDestType =>
      "invalid-function-body-memory-fill-dest-type"
    InvalidFunctionBodyMemoryFillLengthType =>
      "invalid-function-body-memory-fill-length-type"
    InvalidFunctionBodyMemoryCopyLengthType =>
      "invalid-function-body-memory-copy-length-type"
    InvalidFunctionBodyMemoryCopySourceType =>
      "invalid-function-body-memory-copy-source-type"
    InvalidFunctionBodyMemoryCopyDestType =>
      "invalid-function-body-memory-copy-dest-type"
    InvalidFunctionBodyMemory64CopyLengthType =>
      "invalid-function-body-memory64-copy-length-type"
    InvalidFunctionBodyMemory64CopySourceType =>
      "invalid-function-body-memory64-copy-source-type"
    InvalidFunctionBodyMemory64CopyDestType =>
      "invalid-function-body-memory64-copy-dest-type"
    InvalidFunctionBodyMemory64InitDestType =>
      "invalid-function-body-memory64-init-dest-type"
    InvalidFunctionBodyMemoryInitLengthType =>
      "invalid-function-body-memory-init-length-type"
    InvalidFunctionBodyMemoryInitSourceType =>
      "invalid-function-body-memory-init-source-type"
    InvalidFunctionBodyMemoryInitDestType =>
      "invalid-function-body-memory-init-dest-type"
    InvalidFunctionBodyMemoryInitDataIndex =>
      "invalid-function-body-memory-init-data-index"
    InvalidFunctionBodyLocalSetValueType =>
      "invalid-function-body-local-set-value-type"
    InvalidFunctionBodyLocalTeeValueType =>
      "invalid-function-body-local-tee-value-type"
    InvalidFunctionBodyReturnValueType =>
      "invalid-function-body-return-value-type"
    InvalidFunctionBodyTableGetIndexType =>
      "invalid-function-body-table-get-index-type"
    InvalidFunctionBodyTableGrowValueType =>
      "invalid-function-body-table-grow-value-type"
    InvalidFunctionBodyTableGrowDeltaType =>
      "invalid-function-body-table-grow-delta-type"
    InvalidFunctionBodyTableFillValueType =>
      "invalid-function-body-table-fill-value-type"
    InvalidFunctionBodyTableFillDestType =>
      "invalid-function-body-table-fill-dest-type"
    InvalidFunctionBodyTableFillLengthType =>
      "invalid-function-body-table-fill-length-type"
    InvalidFunctionBodyTableCopyLengthType =>
      "invalid-function-body-table-copy-length-type"
    InvalidFunctionBodyTableCopySourceType =>
      "invalid-function-body-table-copy-source-type"
    InvalidFunctionBodyTableCopyDestType =>
      "invalid-function-body-table-copy-dest-type"
    InvalidFunctionBodyTableCopyDestIndex =>
      "invalid-function-body-table-copy-dest-index"
    InvalidFunctionBodyTableCopySourceIndex =>
      "invalid-function-body-table-copy-source-index"
    InvalidFunctionBodyTableInitLengthType =>
      "invalid-function-body-table-init-length-type"
    InvalidFunctionBodyTableInitSourceType =>
      "invalid-function-body-table-init-source-type"
    InvalidFunctionBodyTableInitDestType =>
      "invalid-function-body-table-init-dest-type"
    InvalidFunctionBodyTableInitElemIndex =>
      "invalid-function-body-table-init-elem-index"
    InvalidFunctionBodyTableInitTableIndex =>
      "invalid-function-body-table-init-table-index"
    InvalidFunctionBodyDataDropIndex => "invalid-function-body-data-drop-index"
    InvalidFunctionBodyElemDropIndex => "invalid-function-body-elem-drop-index"
    InvalidFunctionBodyTableSizeIndex =>
      "invalid-function-body-table-size-index"
    InvalidFunctionBodyTableSetIndexType =>
      "invalid-function-body-table-set-index-type"
    InvalidFunctionBodyCallIndirectIndexType =>
      "invalid-function-body-call-indirect-index-type"
    InvalidFunctionBodyReturnCallIndirectIndexType =>
      "invalid-function-body-return-call-indirect-index-type"
    InvalidFunctionBodyReturnCallRefType =>
      "invalid-function-body-return-call-ref-type"
    InvalidFunctionBodyCallRefType => "invalid-function-body-call-ref-type"
    InvalidFunctionBodyRefCastInputType =>
      "invalid-function-body-ref-cast-input-type"
    InvalidFunctionBodyRefTestInputType =>
      "invalid-function-body-ref-test-input-type"
    InvalidFunctionBodyRefTestDescInputType =>
      "invalid-function-body-ref-test-desc-input-type"
    InvalidFunctionBodyRefCastDescEqInputType =>
      "invalid-function-body-ref-cast-desc-eq-input-type"
    InvalidFunctionBodyRefGetDescInputType =>
      "invalid-function-body-ref-get-desc-input-type"
    InvalidFunctionBodyRefEqInputType =>
      "invalid-function-body-ref-eq-input-type"
    InvalidFunctionBodyArrayLenInputType =>
      "invalid-function-body-array-len-input-type"
    InvalidFunctionBodyArrayGetInputType =>
      "invalid-function-body-array-get-input-type"
    InvalidFunctionBodyArraySetInputType =>
      "invalid-function-body-array-set-input-type"
    InvalidFunctionBodyArraySetValueType =>
      "invalid-function-body-array-set-value-type"
    InvalidFunctionBodyArrayFillInputType =>
      "invalid-function-body-array-fill-input-type"
    InvalidFunctionBodyArrayFillValueType =>
      "invalid-function-body-array-fill-value-type"
    InvalidFunctionBodyArrayFillLengthType =>
      "invalid-function-body-array-fill-length-type"
    InvalidFunctionBodyArrayCopyInputType =>
      "invalid-function-body-array-copy-input-type"
    InvalidFunctionBodyArrayCopySourceInputType =>
      "invalid-function-body-array-copy-source-input-type"
    InvalidFunctionBodyArrayCopyLengthType =>
      "invalid-function-body-array-copy-length-type"
    InvalidFunctionBodyArrayInitDataInputType =>
      "invalid-function-body-array-init-data-input-type"
    InvalidFunctionBodyArrayInitDataDestType =>
      "invalid-function-body-array-init-data-dest-type"
    InvalidFunctionBodyArrayInitDataSourceType =>
      "invalid-function-body-array-init-data-source-type"
    InvalidFunctionBodyArrayInitDataLengthType =>
      "invalid-function-body-array-init-data-length-type"
    InvalidFunctionBodyArrayInitElemInputType =>
      "invalid-function-body-array-init-elem-input-type"
    InvalidFunctionBodyArrayInitElemDestType =>
      "invalid-function-body-array-init-elem-dest-type"
    InvalidFunctionBodyArrayInitElemSourceType =>
      "invalid-function-body-array-init-elem-source-type"
    InvalidFunctionBodyArrayInitElemLengthType =>
      "invalid-function-body-array-init-elem-length-type"
    InvalidFunctionBodyArrayNewValueType =>
      "invalid-function-body-array-new-value-type"
    InvalidFunctionBodyArrayNewLengthType =>
      "invalid-function-body-array-new-length-type"
    InvalidFunctionBodyArrayNewDefaultLengthType =>
      "invalid-function-body-array-new-default-length-type"
    InvalidFunctionBodyArrayNewFixedValueType =>
      "invalid-function-body-array-new-fixed-value-type"
    InvalidFunctionBodyArrayNewDataSourceType =>
      "invalid-function-body-array-new-data-source-type"
    InvalidFunctionBodyArrayNewDataLengthType =>
      "invalid-function-body-array-new-data-length-type"
    InvalidFunctionBodyArrayNewElemSourceType =>
      "invalid-function-body-array-new-elem-source-type"
    InvalidFunctionBodyArrayNewElemLengthType =>
      "invalid-function-body-array-new-elem-length-type"
    InvalidFunctionBodyStructNewValueType =>
      "invalid-function-body-struct-new-value-type"
    InvalidFunctionBodyStructNewDefaultFieldType =>
      "invalid-function-body-struct-new-default-field-type"
    InvalidFunctionBodyStructGetInputType =>
      "invalid-function-body-struct-get-input-type"
    InvalidFunctionBodyStructSetInputType =>
      "invalid-function-body-struct-set-input-type"
    InvalidFunctionBodyStructSetValueType =>
      "invalid-function-body-struct-set-value-type"
    InvalidFunctionBodyStructGetFieldIndex =>
      "invalid-function-body-struct-get-field-index"
    InvalidFunctionBodyStructSetFieldIndex =>
      "invalid-function-body-struct-set-field-index"
    InvalidFunctionBodyStructSetImmutableField =>
      "invalid-function-body-struct-set-immutable-field"
    InvalidFunctionBodyStructGetSignedFieldType =>
      "invalid-function-body-struct-get-signed-field-type"
    InvalidFunctionBodyAtomicNotifyCountType =>
      "invalid-function-body-atomic-notify-count-type"
    InvalidFunctionBodyAtomicWaitTimeoutType =>
      "invalid-function-body-atomic-wait-timeout-type"
    InvalidFunctionBodyAtomicRmwValueType =>
      "invalid-function-body-atomic-rmw-value-type"
    InvalidFunctionBodyAtomicCmpxchgReplacementType =>
      "invalid-function-body-atomic-cmpxchg-replacement-type"
    InvalidFunctionBodyAtomicLoadAddressType =>
      "invalid-function-body-atomic-load-address-type"
    InvalidFunctionBodyAtomicLoadNonSharedMemory =>
      "invalid-function-body-atomic-load-non-shared-memory"
    InvalidFunctionBodyAtomicStoreAddressType =>
      "invalid-function-body-atomic-store-address-type"
    InvalidFunctionBodyAtomicStoreValueType =>
      "invalid-function-body-atomic-store-value-type"
    InvalidFunctionBodyAtomicLoadIndex =>
      "invalid-function-body-atomic-load-index"
    InvalidFunctionBodyAtomicStoreIndex =>
      "invalid-function-body-atomic-store-index"
    InvalidFunctionBodyAtomicNotifyIndex =>
      "invalid-function-body-atomic-notify-index"
    InvalidFunctionBodyAtomicWaitIndex =>
      "invalid-function-body-atomic-wait-index"
    InvalidFunctionBodyAtomicRmwIndex =>
      "invalid-function-body-atomic-rmw-index"
    InvalidFunctionBodyAtomicCmpxchgIndex =>
      "invalid-function-body-atomic-cmpxchg-index"
    InvalidFunctionBodySimdExtractLaneIndex =>
      "invalid-function-body-simd-extract-lane-index"
    InvalidFunctionBodySimdReplaceLaneIndex =>
      "invalid-function-body-simd-replace-lane-index"
    InvalidFunctionBodySimdLoadLaneIndex =>
      "invalid-function-body-simd-load-lane-index"
    InvalidFunctionBodySimdStoreLaneIndex =>
      "invalid-function-body-simd-store-lane-index"
    InvalidFunctionBodySimdSplatInputType =>
      "invalid-function-body-simd-splat-input-type"
    InvalidFunctionBodySimdSwizzleInputType =>
      "invalid-function-body-simd-swizzle-input-type"
    InvalidFunctionBodySimdBitselectMaskType =>
      "invalid-function-body-simd-bitselect-mask-type"
    InvalidFunctionBodySimdBitselectLeftType =>
      "invalid-function-body-simd-bitselect-left-type"
    InvalidFunctionBodySimdBitselectRightType =>
      "invalid-function-body-simd-bitselect-right-type"
    InvalidFunctionBodySimdExtractInputType =>
      "invalid-function-body-simd-extract-input-type"
    InvalidFunctionBodySimdReplaceVectorType =>
      "invalid-function-body-simd-replace-vector-type"
    InvalidFunctionBodySimdReplaceValueType =>
      "invalid-function-body-simd-replace-value-type"
    InvalidFunctionBodySimdLoadAddressType =>
      "invalid-function-body-simd-load-address-type"
    InvalidFunctionBodySimdStoreAddressType =>
      "invalid-function-body-simd-store-address-type"
    InvalidFunctionBodySimdStoreValueType =>
      "invalid-function-body-simd-store-value-type"
    InvalidFunctionBodySimdLoadExtendAddressType =>
      "invalid-function-body-simd-load-extend-address-type"
    InvalidFunctionBodySimdLoadSplatAddressType =>
      "invalid-function-body-simd-load-splat-address-type"
    InvalidFunctionBodySimdLoadZeroAddressType =>
      "invalid-function-body-simd-load-zero-address-type"
    InvalidFunctionBodySimdUnaryInputType =>
      "invalid-function-body-simd-unary-input-type"
    InvalidFunctionBodySimdBinaryLeftType =>
      "invalid-function-body-simd-binary-left-type"
    InvalidFunctionBodySimdBinaryRightType =>
      "invalid-function-body-simd-binary-right-type"
    InvalidFunctionBodyRelaxedSimdSwizzleLeftType =>
      "invalid-function-body-relaxed-simd-swizzle-left-type"
    InvalidFunctionBodyRelaxedSimdLaneselectMaskType =>
      "invalid-function-body-relaxed-simd-laneselect-mask-type"
    InvalidFunctionBodySimdShiftVectorType =>
      "invalid-function-body-simd-shift-vector-type"
    InvalidFunctionBodySimdShiftCountType =>
      "invalid-function-body-simd-shift-count-type"
    InvalidFunctionBodySimdLoadLaneAddressType =>
      "invalid-function-body-simd-load-lane-address-type"
    InvalidFunctionBodySimdLoadLaneVectorType =>
      "invalid-function-body-simd-load-lane-vector-type"
    InvalidFunctionBodySimdStoreLaneAddressType =>
      "invalid-function-body-simd-store-lane-address-type"
    InvalidFunctionBodySimdStoreLaneVectorType =>
      "invalid-function-body-simd-store-lane-vector-type"
    InvalidFunctionBodySimdLoadMemoryIndex =>
      "invalid-function-body-simd-load-memory-index"
    InvalidFunctionBodySimdStoreMemoryIndex =>
      "invalid-function-body-simd-store-memory-index"
    InvalidFunctionBodySimdLoadLaneMemoryIndex =>
      "invalid-function-body-simd-load-lane-memory-index"
    InvalidFunctionBodySimdStoreLaneMemoryIndex =>
      "invalid-function-body-simd-store-lane-memory-index"
    InvalidFunctionBodyAtomicNotifyAddressType =>
      "invalid-function-body-atomic-notify-address-type"
    InvalidFunctionBodyAtomicWaitAddressType =>
      "invalid-function-body-atomic-wait-address-type"
    InvalidFunctionBodyAtomicWaitExpectedType =>
      "invalid-function-body-atomic-wait-expected-type"
    InvalidFunctionBodyAtomicRmwAddressType =>
      "invalid-function-body-atomic-rmw-address-type"
    InvalidFunctionBodyAtomicCmpxchgAddressType =>
      "invalid-function-body-atomic-cmpxchg-address-type"
    InvalidFunctionBodyAtomicCmpxchgExpectedType =>
      "invalid-function-body-atomic-cmpxchg-expected-type"
    InvalidFunctionBodyBrOnCastInputType =>
      "invalid-function-body-br-on-cast-input-type"
    InvalidFunctionBodyBrOnCastFailInputType =>
      "invalid-function-body-br-on-cast-fail-input-type"
    InvalidFunctionBodyBrOnNonNullPayloadMismatch =>
      "invalid-function-body-br-on-non-null-payload-mismatch"
    InvalidFunctionBodyTableSetValueType =>
      "invalid-function-body-table-set-value-type"
    InvalidFunctionBodyGlobalSetValueType =>
      "invalid-function-body-global-set-value-type"
    UndeclaredRefFunc => "undeclared-ref-func"
    InvalidNameSectionFuncIndex => "invalid-name-section-func-index"
    InvalidLocalNameSectionIndex => "invalid-local-name-section-index"
    InvalidLabelNameSectionIndex => "invalid-label-name-section-index"
    InvalidLocalNameSectionFuncIndex => "invalid-local-name-section-func-index"
    InvalidLabelNameSectionFuncIndex => "invalid-label-name-section-func-index"
    InvalidMemoryNameSectionIndex => "invalid-memory-name-section-index"
    CodeSecWithoutFuncSec => "codesec-without-funcsec"
    InvalidTableNameSectionIndex => "invalid-table-name-section-index"
    InvalidGlobalNameSectionIndex => "invalid-global-name-section-index"
    InvalidTypeNameSectionIndex => "invalid-type-name-section-index"
    InvalidFieldNameSectionIndex => "invalid-field-name-section-index"
    InvalidElemNameSectionIndex => "invalid-elem-name-section-index"
    InvalidDataNameSectionIndex => "invalid-data-name-section-index"
    InvalidExportTableIndex => "invalid-export-table-index"
    InvalidExportGlobalIndex => "invalid-export-global-index"
    InvalidExportMemoryIndex => "invalid-export-memory-index"
    InvalidExportTagIndex => "invalid-export-tag-index"
    InvalidTagNameSectionIndex => "invalid-tag-name-section-index"
    DataCountMismatchTooSmall => "datacount-mismatch-too-small"
    DataCountMismatchTooLarge => "datacount-mismatch-too-large"
    InvalidFuncTypeIndex => "invalid-func-type-index"
    FuncSecWithoutCodeSec => "funcsec-without-codesec"
    CodeSecLengthMismatchTooSmall => "codesec-length-mismatch-too-small"
    CodeSecLengthMismatchTooLarge => "codesec-length-mismatch-too-large"
    CodeSecIncludesImportedBody => "codesec-includes-imported-body"
    MutableGlobalGetInConstInit => "mutable-global-get-in-const-init"
    InvalidGlobalInitType => "invalid-global-init-type"
    NonConstantDataOffset => "non-constant-data-offset"
    InvalidDataOffsetType => "invalid-data-offset-type"
    InvalidImportedFuncTypeIndex => "invalid-imported-func-type-index"
    InvalidImportedTagTypeIndex => "invalid-imported-tag-type-index"
    InvalidImportedTagResultType => "invalid-imported-tag-result-type"
    InvalidImportedTableRefType => "invalid-imported-table-ref-type"
    InvalidImportedGlobalRefType => "invalid-imported-global-ref-type"
    InvalidTableRefType => "invalid-table-ref-type"
    InvalidGlobalRefType => "invalid-global-ref-type"
    MutableGlobalGetInTableInit => "mutable-global-get-in-table-init"
    InvalidTableInitExprType => "invalid-table-init-expr-type"
    NonConstantElemOffset => "non-constant-elem-offset"
    InvalidElementActiveTableIndex => "invalid-element-active-table-index"
    InvalidDataActiveMemoryIndex => "invalid-data-active-memory-index"
    InvalidElementFuncIndex => "invalid-element-func-index"
    InvalidElementTypedExprType => "invalid-element-typed-expr-type"
    InvalidMemoryLimitRange => "invalid-memory-limit-range"
    InvalidTableLimitRange => "invalid-table-limit-range"
    InvalidImportedMemoryLimitRange => "invalid-imported-memory-limit-range"
    InvalidImportedTableLimitRange => "invalid-imported-table-limit-range"
    InvalidImportedSharedMemoryWithoutMax =>
      "invalid-imported-shared-memory-without-max"
    InvalidImportedSharedMemory64WithoutMax =>
      "invalid-imported-shared-memory64-without-max"
    SharedMemoryWithoutMax => "shared-memory-without-max"
    SharedMemory64WithoutMax => "shared-memory64-without-max"
    InvalidTagTypeIndex => "invalid-tag-type-index"
    InvalidTagResultType => "invalid-tag-result-type"
    InvalidSubtypeSuperIndex => "invalid-subtype-super-index"
    InvalidSubtypeSuperShape => "invalid-subtype-super-shape"
    InvalidSubtypeFuncVariance => "invalid-subtype-func-variance"
    InvalidSubtypeMutableFieldVariance =>
      "invalid-subtype-mutable-field-variance"
    InvalidSubtypeSuperCycle => "invalid-subtype-super-cycle"
    DescriptorOnFuncType => "descriptor-on-func-type"
    DescriptorCycle => "descriptor-cycle"
    InvalidDescriptorFieldRefType => "invalid-descriptor-field-ref-type"
    DataCountWithoutDataSec => "datacount-without-data-sec"
  }
}

///|
fn gen_invalid_max_int(left : Int, right : Int) -> Int {
  if left >= right {
    left
  } else {
    right
  }
}

///|
fn gen_invalid_min_int(left : Int, right : Int) -> Int {
  if left <= right {
    left
  } else {
    right
  }
}

///|
pub fn gen_invalid_require_defined_func_gen_valid_config(
  config : GenValidConfig,
) -> GenValidConfig {
  GenValidConfig::{
    ..config,
    max_type_defs: gen_invalid_max_int(config.max_type_defs, 1),
    max_defined_funcs: gen_invalid_max_int(config.max_defined_funcs, 1),
  }
}

///|
pub fn gen_invalid_require_memory_data_gen_valid_config(
  config : GenValidConfig,
) -> GenValidConfig {
  GenValidConfig::{
    ..config,
    max_mems: gen_invalid_max_int(config.max_mems, 1),
    max_datas: gen_invalid_max_int(config.max_datas, 1),
    section_bias: GenValidSectionBias::{
      ..config.section_bias,
      mems_percent: 100,
      datas_percent: 100,
    },
    features: GenValidFeatureToggles::{
      ..config.features,
      allow_mems: true,
      allow_datas: true,
    },
  }
}

///|
pub fn gen_invalid_small_gen_valid_config(
  config : GenValidConfig,
) -> GenValidConfig {
  GenValidConfig::{
    ..config,
    max_type_defs: gen_invalid_min_int(config.max_type_defs, 2),
    max_imports: gen_invalid_min_int(config.max_imports, 1),
    max_defined_funcs: gen_invalid_min_int(config.max_defined_funcs, 2),
    max_tables: gen_invalid_min_int(config.max_tables, 1),
    max_mems: gen_invalid_min_int(config.max_mems, 1),
    max_globals: gen_invalid_min_int(config.max_globals, 1),
    max_tags: gen_invalid_min_int(config.max_tags, 1),
    max_elems: gen_invalid_min_int(config.max_elems, 1),
    max_datas: gen_invalid_min_int(config.max_datas, 1),
    max_params: gen_invalid_min_int(config.max_params, 1),
    max_results: gen_invalid_min_int(config.max_results, 1),
    max_locals: gen_invalid_min_int(config.max_locals, 1),
    max_body_statements: gen_invalid_min_int(config.max_body_statements, 3),
    max_body_depth: gen_invalid_min_int(config.max_body_depth, 1),
  }
}

///|
fn gen_invalid_apply_seed_prerequisite(
  config : GenValidConfig,
  prerequisite : ValidateInvalidAstSeedPrerequisite,
) -> GenValidConfig {
  match prerequisite {
    RequiresDefinedFunc =>
      gen_invalid_require_defined_func_gen_valid_config(config)
    RequiresMemoryData =>
      gen_invalid_require_memory_data_gen_valid_config(config)
  }
}

///|
pub fn gen_invalid_ast_strategy_seed_prerequisites(
  strategy : ValidateInvalidAstStrategyId,
) -> Array[ValidateInvalidAstSeedPrerequisite] {
  match validate_invalid_ast_strategy_spec_by_id(strategy) {
    Some(spec) => spec.seed_prerequisites
    None => []
  }
}

///|
pub fn gen_invalid_ast_seed_config(
  params : GenInvalidAstParams,
) -> GenValidConfig {
  if !params.require_strategy_prereqs {
    return params.generator_config
  }
  let mut config = params.generator_config
  for
    prerequisite in gen_invalid_ast_strategy_seed_prerequisites(params.strategy) {
    config = gen_invalid_apply_seed_prerequisite(config, prerequisite)
  }
  config
}

///|
fn gen_invalid_ast_minimal_seed_module(
  strategy : ValidateInvalidAstStrategyId,
) -> Module {
  ignore(strategy)
  let (base, _) = validate_invalid_ast_ensure_any_func(Module::new())
  base
}

///|
pub fn gen_invalid_ast_seed_module(
  rnd : RandomState,
  params : GenInvalidAstParams,
) -> Result[Module, String] {
  let base = match params.seed_mode {
    RandomValidSeed => {
      let seeded_config = gen_invalid_ast_seed_config(params)
      gen_valid_module_with_config(rnd, seeded_config)
    }
    MinimalValidSeed => gen_invalid_ast_minimal_seed_module(params.strategy)
  }
  match validate_module(base) {
    Ok(_) => Ok(base)
    Err(err) =>
      Err(
        "gen-invalid base generation failed before mutation: strategy=\{gen_invalid_ast_strategy_label(params.strategy)} error=\{validation_error_message(err)}",
      )
  }
}

///|
fn gen_invalid_ast_seed_module_from_seed(
  seed : UInt64,
  params : GenInvalidAstParams,
) -> Result[Module, String] {
  let base = match params.seed_mode {
    RandomValidSeed => {
      let seeded_config = gen_invalid_ast_seed_config(params)
      match gen_valid_module_result_from_seed(seed, seeded_config) {
        Ok(generated) => generated.wasm_module
        Err(failure) => failure.last_candidate
      }
    }
    MinimalValidSeed => gen_invalid_ast_minimal_seed_module(params.strategy)
  }
  match validate_module(base) {
    Ok(_) => Ok(base)
    Err(err) =>
      Err(
        "gen-invalid base generation failed before mutation: strategy=\{gen_invalid_ast_strategy_label(params.strategy)} error=\{validation_error_message(err)}",
      )
  }
}

///|
fn gen_invalid_ast_generate_from_base(
  base : Module,
  params : GenInvalidAstParams,
) -> Result[GenInvalidAstGenerated, String] {
  let mutation = match
    apply_validate_invalid_ast_strategy(params.strategy, base) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  if !mutation.applicable {
    return Err(
      "gen-invalid mutation was not applicable after valid seed generation: strategy=\{gen_invalid_ast_strategy_label(params.strategy)}",
    )
  }
  Ok({ base_module: base, mutation })
}

///|
pub fn gen_invalid_ast_generate(
  rnd : RandomState,
  params : GenInvalidAstParams,
) -> Result[GenInvalidAstGenerated, String] {
  let base = match gen_invalid_ast_seed_module(rnd, params) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  gen_invalid_ast_generate_from_base(base, params)
}

///|
pub fn gen_invalid_ast_generate_from_seed(
  seed : UInt64,
  params : GenInvalidAstParams,
) -> Result[GenInvalidAstGenerated, String] {
  let base = match gen_invalid_ast_seed_module_from_seed(seed, params) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  gen_invalid_ast_generate_from_base(base, params)
}
