///|
using @lib {
  type CodeSec,
  type CompType,
  type Expr,
  type Func,
  type FuncSec,
  type Locals,
  type Module,
  type RecType,
  type SubType,
  type TypeIdx,
  type TypeSec,
}

///|
using @validate {
  type ValidateInvalidAstStrategyId,
  type ValidationIssueFamily,
  apply_validate_invalid_ast_strategy,
  validate_invalid_ast_strategy_by_stable_id,
  validation_error_diagnostic,
  validation_issue_family,
}

///|
pub enum ValidateInvalidBinaryExpectedResult {
  DecodeRejected
  ValidateRejected(String)
} derive(Eq, Debug)

///|
pub enum ValidateInvalidBinaryStrategyId {
  TrailingGarbage
  TruncatedModule
  DuplicateTypeSection
  DuplicateImportSection
  DuplicateExportSection
  DuplicateTableSection
  DuplicateMemorySection
  DuplicateGlobalSection
  DuplicateFunctionSection
  DuplicateCodeSection
  DuplicateElementSection
  DuplicateDataSection
  DuplicateTagSection
  DuplicateStartSection
  WrongSectionOrder
  InvalidFuncTypeIndex
  InvalidStartSignatureModule
  InvalidImportedStartFuncParamModule
  InvalidImportedStartFuncResultModule
  InvalidImportedStartFuncParamResultModule
  InvalidImportedStartFuncMultiParamModule
  InvalidImportedStartFuncF32ParamModule
  InvalidImportedStartFuncExternrefParamModule
  InvalidImportedStartFuncFuncrefParamModule
  DuplicateExportNameModule
  FuncSecWithoutCodeSecModule
  DataCountWithoutDataSecModule
  InvalidNameSectionFuncIndexModule
  InvalidLocalNameSectionIndexModule
  InvalidLabelNameSectionIndexModule
  BadMagicHeader
  BadVersionHeader
  MalformedSectionSizeUleb
  OverwideSectionSizeUleb
  SectionPayloadLengthOverflow
  SectionPayloadLengthUnderflow
  CodeSecWithoutFuncSecModule
  InvalidTableNameSectionIndexModule
  InvalidGlobalNameSectionIndexModule
  ReservedSectionId
  InvalidCustomSectionNameUtf8
  InvalidTypeNameSectionIndexModule
  InvalidFieldNameSectionIndexModule
  InvalidElemNameSectionIndexModule
  InvalidDataNameSectionIndexModule
  InvalidExportTableIndexModule
  InvalidExportGlobalIndexModule
  InvalidExportMemoryIndexModule
  InvalidExportTagIndexModule
  InvalidTagNameSectionIndexModule
  InvalidImportedTagTypeIndexModule
  DataCountMismatchTooSmallModule
  DataCountMismatchTooLargeModule
  InvalidBinaryBodyLocalSetValueTypeModule
  InvalidBinaryBranchPayloadTypeModule
  InvalidBinaryLocalIndexModule
  InvalidBinaryCallRefTypeModule
  InvalidBinaryStructGetFieldIndexModule
  InvalidBinaryThrowPayloadModule
  InvalidBinarySharedMemoryWithoutMaxModule
  InvalidBinaryMemory64AddressTypeModule
  MalformedSimdImmediate
  SimdLaneIndexOverflow
  MalformedCustomSectionPayload
  MalformedCustomSectionNameLengthUleb
  OverwideCustomSectionNameLengthUleb
  MalformedNameSubsectionSizeUleb
  OverwideNameSubsectionSizeUleb
  InvalidNameSubsectionIdByte
  OutOfOrderNameSubsectionId
  InvalidOpcodeByte
  InvalidPrefixSubopcodeByte
  InvalidGcPrefixSubopcodeByte
  InvalidBulkPrefixSubopcodeByte
  InvalidSimdPrefixSubopcodeByte
  MalformedGcPrefixSubopcodeUleb
  MalformedBulkPrefixSubopcodeUleb
  MalformedSimdPrefixSubopcodeUleb
  MalformedAtomicPrefixSubopcodeUleb
  InvalidAtomicPrefixSubopcodeByte
  OverwideGcPrefixSubopcodeUleb
  OverwideBulkPrefixSubopcodeUleb
  OverwideSimdPrefixSubopcodeUleb
  OverwideAtomicPrefixSubopcodeUleb
  MalformedAtomicLoadMemargAlignUleb
  MalformedAtomicStoreMemargAlignUleb
  MalformedAtomicLoadMemargOffsetUleb
  MalformedAtomicStoreMemargOffsetUleb
  MalformedAtomicNotifyMemargAlignUleb
  MalformedAtomicNotifyMemargOffsetUleb
  MalformedAtomicWaitMemargAlignUleb
  MalformedAtomicWaitMemargOffsetUleb
  MalformedAtomicRmwMemargAlignUleb
  MalformedAtomicRmwMemargOffsetUleb
  MalformedAtomicCmpxchgMemargAlignUleb
  MalformedAtomicCmpxchgMemargOffsetUleb
  OverwideAtomicLoadMemargAlignUleb
  OverwideAtomicStoreMemargAlignUleb
  OverwideAtomicLoadMemargOffsetUleb
  OverwideAtomicStoreMemargOffsetUleb
  OverwideAtomicNotifyMemargAlignUleb
  OverwideAtomicNotifyMemargOffsetUleb
  OverwideAtomicWaitMemargAlignUleb
  OverwideAtomicWaitMemargOffsetUleb
  OverwideAtomicRmwMemargAlignUleb
  OverwideAtomicRmwMemargOffsetUleb
  OverwideAtomicCmpxchgMemargAlignUleb
  OverwideAtomicCmpxchgMemargOffsetUleb
  MalformedMemargImmediate
  MalformedLoadMemargAlignUleb
  MalformedStoreMemargAlignUleb
  MalformedLoadMemargOffsetUleb
  MalformedStoreMemargOffsetUleb
  OverwideLoadMemargAlignUleb
  OverwideStoreMemargAlignUleb
  OverwideLoadMemargOffsetUleb
  OverwideStoreMemargOffsetUleb
  MalformedBlocktypeImmediate
  InvalidBlocktypeValTypeByte
  OverwideBlocktypeTypeIndexUleb
  MalformedMemoryMinUleb
  MalformedTableMinUleb
  MalformedMemoryMaxUleb
  MalformedTableMaxUleb
  OverwideMemoryMinUleb
  OverwideTableMinUleb
  OverwideMemoryMaxUleb
  OverwideTableMaxUleb
  InvalidExportNameUtf8
  MalformedExportNameLengthUleb
  OverwideExportNameLengthUleb
  InvalidImportModuleNameUtf8
  MalformedImportModuleNameLengthUleb
  OverwideImportModuleNameLengthUleb
  InvalidImportFieldNameUtf8
  MalformedImportFieldNameLengthUleb
  OverwideImportFieldNameLengthUleb
  InvalidImportKindByte
  MalformedFunctionSectionTypeIndexUleb
  OverwideFunctionSectionTypeIndexUleb
  MalformedImportFuncTypeIndexUleb
  OverwideImportFuncTypeIndexUleb
  MalformedImportTagTypeIndexUleb
  OverwideImportTagTypeIndexUleb
  MalformedImportMemoryMinUleb
  MalformedImportTableMinUleb
  MalformedImportMemoryMaxUleb
  MalformedImportTableMaxUleb
  OverwideImportMemoryMinUleb
  OverwideImportTableMinUleb
  OverwideImportMemoryMaxUleb
  OverwideImportTableMaxUleb
  InvalidImportTableRefTypeByte
  InvalidImportMemoryLimitsFlagByte
  InvalidImportGlobalValTypeByte
  InvalidImportGlobalMutabilityByte
  InvalidImportTagAttributeByte
  InvalidTableRefTypeByte
  InvalidTableLimitsFlagByte
  MalformedRefNullHeaptypeImmediate
  MalformedRefCastHeaptypeImmediate
  MalformedRefTestHeaptypeImmediate
  OverwideRefNullHeaptypeImmediate
  OverwideRefCastHeaptypeImmediate
  OverwideRefTestHeaptypeImmediate
  InvalidGlobalValTypeByte
  InvalidExportKindByte
  InvalidMemoryLimitsFlagByte
  InvalidTagAttributeByte
  InvalidGlobalMutabilityByte
  MalformedExportFuncIndexUleb
  MalformedExportTableIndexUleb
  MalformedExportMemoryIndexUleb
  MalformedExportGlobalIndexUleb
  MalformedExportTagIndexUleb
  OverwideExportFuncIndexUleb
  OverwideExportTableIndexUleb
  OverwideExportMemoryIndexUleb
  OverwideExportGlobalIndexUleb
  OverwideExportTagIndexUleb
  InvalidElementSegmentFlagByte
  InvalidElementKindByte
  InvalidDataSegmentFlagByte
  TypeSectionCountOverflow
  CodeSectionCountOverflow
  TableSectionCountOverflow
  ExportSectionCountOverflow
  ImportSectionCountOverflow
  GlobalSectionCountOverflow
  FunctionSectionCountOverflow
  MemorySectionCountOverflow
  ElementSectionCountOverflow
  DataSectionCountOverflow
  TagSectionCountOverflow
  MalformedTagTypeIndexUleb
  OverwideTagTypeIndexUleb
  MalformedLocalIndexUleb
  MalformedLocalSetIndexUleb
  MalformedLocalTeeIndexUleb
  OverwideLocalIndexUleb
  OverwideLocalSetIndexUleb
  OverwideLocalTeeIndexUleb
  MalformedGlobalIndexUleb
  MalformedGlobalSetIndexUleb
  OverwideGlobalIndexUleb
  OverwideGlobalSetIndexUleb
  MalformedI32ConstSleb
  MalformedI64ConstSleb
  OverwideI32ConstSleb
  OverwideI64ConstSleb
  MalformedF32ConstImmediate
  MalformedF64ConstImmediate
  MalformedCallFuncIndexUleb
  MalformedReturnCallFuncIndexUleb
  MalformedRefFuncIndexUleb
  OverwideCallFuncIndexUleb
  OverwideReturnCallFuncIndexUleb
  OverwideRefFuncIndexUleb
  MalformedCallIndirectTypeIndexUleb
  MalformedCallIndirectTableIndexUleb
  MalformedReturnCallIndirectTypeIndexUleb
  MalformedReturnCallIndirectTableIndexUleb
  MalformedCallRefTypeIndexUleb
  MalformedReturnCallRefTypeIndexUleb
  OverwideCallIndirectTypeIndexUleb
  OverwideCallIndirectTableIndexUleb
  OverwideReturnCallIndirectTypeIndexUleb
  OverwideReturnCallIndirectTableIndexUleb
  OverwideCallRefTypeIndexUleb
  OverwideReturnCallRefTypeIndexUleb
  MalformedThrowTagIndexUleb
  MalformedTryTableCatchCountUleb
  MalformedTryTableCatchTagIndexUleb
  MalformedTryTableCatchLabelIndexUleb
  OverwideThrowTagIndexUleb
  OverwideTryTableCatchCountUleb
  OverwideTryTableCatchTagIndexUleb
  OverwideTryTableCatchLabelIndexUleb
  MalformedStructNewTypeIndexUleb
  MalformedStructGetFieldIndexUleb
  MalformedArrayNewDataTypeIndexUleb
  MalformedArrayNewDataIndexUleb
  MalformedArrayNewElemTypeIndexUleb
  MalformedArrayNewElemElemIndexUleb
  OverwideStructNewTypeIndexUleb
  OverwideStructGetFieldIndexUleb
  OverwideArrayNewDataTypeIndexUleb
  OverwideArrayNewDataIndexUleb
  OverwideArrayNewElemTypeIndexUleb
  OverwideArrayNewElemElemIndexUleb
  MalformedBrLabelIndexUleb
  MalformedBrIfLabelIndexUleb
  MalformedBrTableTargetCountUleb
  MalformedBrTableTargetLabelIndexUleb
  MalformedBrTableDefaultLabelIndexUleb
  OverwideBrLabelIndexUleb
  OverwideBrIfLabelIndexUleb
  OverwideBrTableTargetCountUleb
  OverwideBrTableTargetLabelIndexUleb
  OverwideBrTableDefaultLabelIndexUleb
  MalformedTableIndexUleb
  MalformedTableSetIndexUleb
  MalformedTableSizeIndexUleb
  MalformedTableGrowIndexUleb
  MalformedTableFillIndexUleb
  OverwideTableIndexUleb
  OverwideTableSetIndexUleb
  OverwideTableSizeIndexUleb
  OverwideTableGrowIndexUleb
  OverwideTableFillIndexUleb
  MalformedMemorySizeMemoryIndexUleb
  MalformedMemoryGrowMemoryIndexUleb
  MalformedMemoryFillMemoryIndexUleb
  OverwideMemorySizeMemoryIndexUleb
  OverwideMemoryGrowMemoryIndexUleb
  OverwideMemoryFillMemoryIndexUleb
  MalformedMemoryCopyDstIndexUleb
  MalformedMemoryCopySrcIndexUleb
  MalformedTableCopyDstIndexUleb
  MalformedTableCopySrcIndexUleb
  OverwideMemoryCopyDstIndexUleb
  OverwideMemoryCopySrcIndexUleb
  OverwideTableCopyDstIndexUleb
  OverwideTableCopySrcIndexUleb
  MalformedSelectTypeCountUleb
  OverwideSelectTypeCountUleb
  InvalidTypedSelectValTypeByte
  MalformedStartFuncIndexUleb
  OverwideStartFuncIndexUleb
  MalformedDataCountUleb
  OverwideDataCountUleb
  SimdShuffleLaneOverflow
  SimdLoadLaneIndexOverflow
  SimdStoreLaneIndexOverflow
  SimdExtractLaneIndexOverflow
  SimdReplaceLaneIndexOverflow
  MalformedSimdLoadMemargAlignUleb
  MalformedSimdStoreMemargAlignUleb
  MalformedSimdLoadMemargOffsetUleb
  MalformedSimdStoreMemargOffsetUleb
  OverwideSimdLoadMemargAlignUleb
  OverwideSimdStoreMemargAlignUleb
  OverwideSimdLoadMemargOffsetUleb
  OverwideSimdStoreMemargOffsetUleb
  MalformedSimdLoadLaneMemargAlignUleb
  MalformedSimdStoreLaneMemargAlignUleb
  MalformedSimdLoadLaneMemargOffsetUleb
  MalformedSimdStoreLaneMemargOffsetUleb
  OverwideSimdLoadLaneMemargAlignUleb
  OverwideSimdStoreLaneMemargAlignUleb
  OverwideSimdLoadLaneMemargOffsetUleb
  OverwideSimdStoreLaneMemargOffsetUleb
  MalformedSimdLoadSplatMemargAlignUleb
  MalformedSimdLoadSplatMemargOffsetUleb
  OverwideSimdLoadSplatMemargAlignUleb
  OverwideSimdLoadSplatMemargOffsetUleb
  MalformedSimdLoadExtendMemargAlignUleb
  MalformedSimdLoadExtendMemargOffsetUleb
  OverwideSimdLoadExtendMemargAlignUleb
  OverwideSimdLoadExtendMemargOffsetUleb
  MalformedSimdLoadZeroMemargAlignUleb
  MalformedSimdLoadZeroMemargOffsetUleb
  OverwideSimdLoadZeroMemargAlignUleb
  OverwideSimdLoadZeroMemargOffsetUleb
  MalformedDataIndexUleb
  OverwideDataIndexUleb
  MalformedDataSegmentByteCountUleb
  OverwideDataSegmentByteCountUleb
  MalformedMemoryInitDataIndexUleb
  MalformedMemoryInitMemoryIndexUleb
  OverwideMemoryInitDataIndexUleb
  OverwideMemoryInitMemoryIndexUleb
  MalformedElemIndexUleb
  OverwideElemIndexUleb
  MalformedTableInitElemIndexUleb
  MalformedTableInitTableIndexUleb
  OverwideTableInitElemIndexUleb
  OverwideTableInitTableIndexUleb
  MalformedDataSegmentMemoryIndexUleb
  OverwideDataSegmentMemoryIndexUleb
  MalformedElementSegmentTableIndexUleb
  MalformedElementSegmentFuncIndexUleb
  OverwideElementSegmentTableIndexUleb
  OverwideElementSegmentFuncIndexUleb
  InvalidNameSectionFuncNameUtf8
  MalformedNameSectionFuncNameLengthUleb
  OverwideNameSectionFuncNameLengthUleb
  MalformedNameSectionFuncNameCountUleb
  OverwideNameSectionFuncNameCountUleb
  InvalidNameSectionLocalNameUtf8
  MalformedNameSectionLocalNameLengthUleb
  OverwideNameSectionLocalNameLengthUleb
  MalformedNameSectionLocalNameCountUleb
  OverwideNameSectionLocalNameCountUleb
  InvalidNameSectionModuleNameUtf8
  MalformedNameSectionModuleNameLengthUleb
  OverwideNameSectionModuleNameLengthUleb
  InvalidNameSectionTypeNameUtf8
  MalformedNameSectionTypeNameLengthUleb
  OverwideNameSectionTypeNameLengthUleb
  MalformedNameSectionTypeNameCountUleb
  OverwideNameSectionTypeNameCountUleb
  InvalidNameSectionTableNameUtf8
  MalformedNameSectionTableNameLengthUleb
  OverwideNameSectionTableNameLengthUleb
  MalformedNameSectionTableNameCountUleb
  OverwideNameSectionTableNameCountUleb
  InvalidNameSectionMemoryNameUtf8
  MalformedNameSectionMemoryNameLengthUleb
  OverwideNameSectionMemoryNameLengthUleb
  MalformedNameSectionMemoryNameCountUleb
  OverwideNameSectionMemoryNameCountUleb
  InvalidNameSectionGlobalNameUtf8
  MalformedNameSectionGlobalNameLengthUleb
  OverwideNameSectionGlobalNameLengthUleb
  MalformedNameSectionGlobalNameCountUleb
  OverwideNameSectionGlobalNameCountUleb
  InvalidNameSectionElemNameUtf8
  MalformedNameSectionElemNameLengthUleb
  OverwideNameSectionElemNameLengthUleb
  MalformedNameSectionElemNameCountUleb
  OverwideNameSectionElemNameCountUleb
  InvalidNameSectionDataNameUtf8
  MalformedNameSectionDataNameLengthUleb
  OverwideNameSectionDataNameLengthUleb
  InvalidNameSectionFieldNameUtf8
  MalformedNameSectionFieldNameLengthUleb
  OverwideNameSectionFieldNameLengthUleb
  InvalidNameSectionLabelNameUtf8
  MalformedNameSectionLabelNameLengthUleb
  OverwideNameSectionLabelNameLengthUleb
  InvalidNameSectionTagNameUtf8
  MalformedNameSectionTagNameLengthUleb
  OverwideNameSectionTagNameLengthUleb
  InvalidFuncTypeByte
  MalformedFuncTypeParamCountUleb
  MalformedFuncTypeResultCountUleb
  OverwideFuncTypeParamCountUleb
  OverwideFuncTypeResultCountUleb
  InvalidFuncTypeParamValTypeByte
  InvalidFuncTypeResultValTypeByte
  InvalidCodeLocalValTypeByte
  MalformedCodeLocalDeclCountUleb
  MalformedCodeLocalRunCountUleb
  OverwideCodeLocalDeclCountUleb
  OverwideCodeLocalRunCountUleb
  MalformedTypeSectionCountUleb
  MalformedCodeSectionCountUleb
  MalformedImportSectionCountUleb
  MalformedExportSectionCountUleb
  MalformedTableSectionCountUleb
  MalformedMemorySectionCountUleb
  MalformedGlobalSectionCountUleb
  MalformedFunctionSectionCountUleb
  MalformedElementSectionCountUleb
  MalformedDataSectionCountUleb
  MalformedTagSectionCountUleb
  OverwideTypeSectionCountUleb
  OverwideCodeSectionCountUleb
  OverwideImportSectionCountUleb
  OverwideExportSectionCountUleb
  OverwideTableSectionCountUleb
  OverwideMemorySectionCountUleb
  OverwideGlobalSectionCountUleb
  OverwideFunctionSectionCountUleb
  OverwideElementSectionCountUleb
  OverwideDataSectionCountUleb
  OverwideTagSectionCountUleb
  TypeSectionCountUnderflow
  CodeSectionCountUnderflow
  ImportSectionCountUnderflow
  ExportSectionCountUnderflow
  TableSectionCountUnderflow
  MemorySectionCountUnderflow
  GlobalSectionCountUnderflow
  FunctionSectionCountUnderflow
  ElementSectionCountUnderflow
  DataSectionCountUnderflow
  TagSectionCountUnderflow
  TypeSectionSizeUnderflow
  CodeBodySizeUnderflow
  MalformedCodeBodySizeUleb
  OverwideCodeBodySizeUleb
  ImportSectionSizeUnderflow
  ExportSectionSizeUnderflow
  TableSectionSizeUnderflow
  MemorySectionSizeUnderflow
  GlobalSectionSizeUnderflow
  FunctionSectionSizeUnderflow
  ElementSectionSizeUnderflow
  DataSectionSizeUnderflow
  TagSectionSizeUnderflow
  TypeSectionSizeOverflow
  CodeSectionSizeOverflow
  ImportSectionSizeOverflow
  ExportSectionSizeOverflow
  TableSectionSizeOverflow
  MemorySectionSizeOverflow
  GlobalSectionSizeOverflow
  FunctionSectionSizeOverflow
  ElementSectionSizeOverflow
  DataSectionSizeOverflow
  TagSectionSizeOverflow
  StartSectionSizeUnderflow
  DataCountSectionSizeUnderflow
  StartSectionSizeOverflow
  DataCountSectionSizeOverflow
} derive(Eq, Debug)

///|
pub struct ValidateInvalidBinaryStrategySpec {
  id : ValidateInvalidBinaryStrategyId
  stable_id : String
  variant_id : String
  display_name : String
  layer : String
  expected_result : ValidateInvalidBinaryExpectedResult
  expected_issue_kind : String?
  required_in_smoke : Bool
  seed_prerequisites : Array[String]
} derive(Eq, Debug)

///|
pub struct ValidateInvalidBinaryRunConfig {
  profile : String
  attempts : Int
  generator_config : GenValidConfig
  required_strategies : Array[ValidateInvalidBinaryStrategyId]
  seed_profiles : Array[String]
} derive(Eq, Debug)

///|
pub enum GenInvalidBinarySeedMode {
  RandomValidSeed
  MinimalValidSeed
} derive(Eq, Debug)

///|
pub struct GenInvalidBinaryParams {
  strategy : ValidateInvalidBinaryStrategyId
  seed_mode : GenInvalidBinarySeedMode
  seed_profile : String?
  generator_config : GenValidConfig
  require_strategy_prereqs : Bool
} derive(Eq, Debug)

///|
pub fn gen_invalid_binary_coverage_seed_generator_config() -> GenValidConfig {
  @validate.gen_invalid_coverage_seed_generator_config()
}

///|
pub fn GenInvalidBinaryParams::new(
  strategy : ValidateInvalidBinaryStrategyId,
  seed_mode? : GenInvalidBinarySeedMode = RandomValidSeed,
  generator_config? : GenValidConfig = gen_invalid_binary_coverage_seed_generator_config(),
  require_strategy_prereqs? : Bool = true,
) -> GenInvalidBinaryParams {
  {
    strategy,
    seed_mode,
    seed_profile: None,
    generator_config,
    require_strategy_prereqs,
  }
}

///|
pub fn GenInvalidBinaryParams::natural_seed(
  strategy : ValidateInvalidBinaryStrategyId,
  generator_config? : GenValidConfig = GenValidConfig::natural_default(),
  require_strategy_prereqs? : Bool = true,
) -> GenInvalidBinaryParams {
  {
    strategy,
    seed_mode: RandomValidSeed,
    seed_profile: Some("natural"),
    generator_config,
    require_strategy_prereqs,
  }
}

///|
pub fn GenInvalidBinaryParams::coverage_forced_seed(
  strategy : ValidateInvalidBinaryStrategyId,
  generator_config? : GenValidConfig = gen_invalid_binary_coverage_seed_generator_config(),
  require_strategy_prereqs? : Bool = true,
) -> GenInvalidBinaryParams {
  {
    strategy,
    seed_mode: RandomValidSeed,
    seed_profile: Some("coverage-forced"),
    generator_config,
    require_strategy_prereqs,
  }
}

///|
pub fn GenInvalidBinaryParams::small_natural_seed(
  strategy : ValidateInvalidBinaryStrategyId,
  generator_config? : GenValidConfig = GenValidConfig::natural_default(),
  require_strategy_prereqs? : Bool = true,
) -> GenInvalidBinaryParams {
  {
    strategy,
    seed_mode: RandomValidSeed,
    seed_profile: Some("small-natural"),
    generator_config: @validate.gen_invalid_small_gen_valid_config(
      generator_config,
    ),
    require_strategy_prereqs,
  }
}

///|
pub fn GenInvalidBinaryParams::small_coverage_forced_seed(
  strategy : ValidateInvalidBinaryStrategyId,
  generator_config? : GenValidConfig = gen_invalid_binary_coverage_seed_generator_config(),
  require_strategy_prereqs? : Bool = true,
) -> GenInvalidBinaryParams {
  {
    strategy,
    seed_mode: RandomValidSeed,
    seed_profile: Some("small-coverage-forced"),
    generator_config: @validate.gen_invalid_small_gen_valid_config(
      generator_config,
    ),
    require_strategy_prereqs,
  }
}

///|
pub fn GenInvalidBinaryParams::repro_seed(
  strategy : ValidateInvalidBinaryStrategyId,
  generator_config? : GenValidConfig = gen_invalid_binary_coverage_seed_generator_config(),
  require_strategy_prereqs? : Bool = true,
) -> GenInvalidBinaryParams {
  {
    strategy,
    seed_mode: RandomValidSeed,
    seed_profile: Some("repro"),
    generator_config: @validate.gen_invalid_small_gen_valid_config(
      generator_config,
    ),
    require_strategy_prereqs,
  }
}

///|
pub fn GenInvalidBinaryParams::minimal_seed(
  strategy : ValidateInvalidBinaryStrategyId,
  generator_config? : GenValidConfig = gen_invalid_binary_coverage_seed_generator_config(),
  require_strategy_prereqs? : Bool = true,
) -> GenInvalidBinaryParams {
  {
    strategy,
    seed_mode: MinimalValidSeed,
    seed_profile: Some("minimal"),
    generator_config,
    require_strategy_prereqs,
  }
}

///|
pub fn GenInvalidBinaryParams::rich_seed(
  strategy : ValidateInvalidBinaryStrategyId,
  generator_config? : GenValidConfig = gen_invalid_binary_coverage_seed_generator_config(),
  require_strategy_prereqs? : Bool = true,
) -> GenInvalidBinaryParams {
  {
    strategy,
    seed_mode: RandomValidSeed,
    seed_profile: Some("rich"),
    generator_config,
    require_strategy_prereqs,
  }
}

///|
pub fn gen_invalid_binary_seed_mode_name(
  mode : GenInvalidBinarySeedMode,
) -> String {
  match mode {
    RandomValidSeed => "random-valid"
    MinimalValidSeed => "minimal-valid"
  }
}

///|
pub fn gen_invalid_binary_params_profile_name(
  params : GenInvalidBinaryParams,
) -> String {
  match params.seed_profile {
    Some(profile) => profile
    None => "custom"
  }
}

///|
pub struct ValidateInvalidBinaryMutation {
  strategy : ValidateInvalidBinaryStrategyId
  applicable : Bool
  expected_result : ValidateInvalidBinaryExpectedResult
  mutated_bytes : Bytes
} derive(Debug)

///|
pub struct ValidateInvalidBinaryStrategyStats {
  strategy : ValidateInvalidBinaryStrategyId
  stable_id : String
  variant_id : String
  expected_result : ValidateInvalidBinaryExpectedResult
  expected_issue_kind : String?
  attempted : Int
  applicable : Int
  mutated : Int
  decode_rejected : Int
  validate_rejected : Int
  rejected_expected : Int
  accepted : Int
  variant_attempted : Int
  variant_applicable : Int
  variant_mutated : Int
  variant_rejected : Int
  rejected_exact_issue : Int
} derive(Eq, Debug)

///|
pub struct ValidateInvalidBinaryFuzzStats {
  profile : String
  seed : UInt64
  attempts : Int
  generator_config : GenValidConfig
  required_strategies : Array[ValidateInvalidBinaryStrategyId]
  seed_profiles : Array[String]
  seed_profile_attempts : Array[Int]
  strategy_stats : Array[ValidateInvalidBinaryStrategyStats]
} derive(Eq, Debug)

///|
pub struct GenInvalidBinaryGenerated {
  base_module : Module
  mutation : ValidateInvalidBinaryMutation
} derive(Debug)

///|
struct ValidateInvalidBinarySectionSpan {
  id : Int
  header_start : Int
  payload_start : Int
  payload_len : Int
  end : Int
} derive(Eq, Debug)

///|
fn validate_invalid_binary_ascii_lower(input : String) -> String {
  let out = StringBuilder::new()
  for c in input {
    if c >= 'A' && c <= 'Z' {
      out.write_char((c.to_int() + 32).unsafe_to_char())
    } else {
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
fn validate_invalid_binary_validation_family_label(
  family : ValidationIssueFamily,
) -> String {
  match family {
    TypeSectionFamily => "type"
    ImportSectionFamily => "import"
    FunctionSectionFamily => "function"
    TableSectionFamily => "table"
    MemorySectionFamily => "memory"
    TagSectionFamily => "tag"
    GlobalSectionFamily => "global"
    ElementSectionFamily => "element"
    DataSectionFamily => "data"
    DataCountSectionFamily => "datacount"
    StartSectionFamily => "start"
    ExportSectionFamily => "export"
    CodeSectionFamily => "code"
    NameSectionFamily => "name"
    FunctionBodyFamily => "function-body"
  }
}

///|
fn validate_invalid_binary_expected_result_label(
  expected_result : ValidateInvalidBinaryExpectedResult,
) -> String {
  match expected_result {
    DecodeRejected => "decode"
    ValidateRejected(family_label) => "validate-" + family_label
  }
}

///|
fn validate_invalid_binary_strategy_label(
  strategy : ValidateInvalidBinaryStrategyId,
) -> String {
  match strategy {
    TrailingGarbage => "trailing-garbage"
    TruncatedModule => "truncated-module"
    DuplicateTypeSection => "duplicate-type-section"
    DuplicateImportSection => "duplicate-import-section"
    DuplicateExportSection => "duplicate-export-section"
    WrongSectionOrder => "wrong-section-order"
    InvalidFuncTypeIndex => "invalid-func-type-index"
    InvalidStartSignatureModule => "invalid-start-signature-module"
    InvalidImportedStartFuncParamModule =>
      "invalid-imported-start-func-param-module"
    InvalidImportedStartFuncResultModule =>
      "invalid-imported-start-func-result-module"
    InvalidImportedStartFuncParamResultModule =>
      "invalid-imported-start-func-param-result-module"
    InvalidImportedStartFuncMultiParamModule =>
      "invalid-imported-start-func-multi-param-module"
    InvalidImportedStartFuncF32ParamModule =>
      "invalid-imported-start-func-f32-param-module"
    InvalidImportedStartFuncExternrefParamModule =>
      "invalid-imported-start-func-externref-param-module"
    InvalidImportedStartFuncFuncrefParamModule =>
      "invalid-imported-start-func-funcref-param-module"
    DuplicateTableSection => "duplicate-table-section"
    DuplicateMemorySection => "duplicate-memory-section"
    DuplicateGlobalSection => "duplicate-global-section"
    DuplicateFunctionSection => "duplicate-function-section"
    DuplicateCodeSection => "duplicate-code-section"
    DuplicateElementSection => "duplicate-element-section"
    DuplicateDataSection => "duplicate-data-section"
    DuplicateTagSection => "duplicate-tag-section"
    DuplicateStartSection => "duplicate-start-section"
    DuplicateExportNameModule => "duplicate-export-name-module"
    FuncSecWithoutCodeSecModule => "funcsec-without-codesec-module"
    DataCountWithoutDataSecModule => "datacount-without-data-sec-module"
    InvalidNameSectionFuncIndexModule =>
      "invalid-name-section-func-index-module"
    InvalidLocalNameSectionIndexModule =>
      "invalid-local-name-section-index-module"
    InvalidLabelNameSectionIndexModule =>
      "invalid-label-name-section-index-module"
    BadMagicHeader => "bad-magic-header"
    BadVersionHeader => "bad-version-header"
    MalformedSectionSizeUleb => "malformed-section-size-uleb"
    OverwideSectionSizeUleb => "overwide-section-size-uleb"
    SectionPayloadLengthOverflow => "section-payload-length-overflow"
    SectionPayloadLengthUnderflow => "section-payload-length-underflow"
    CodeSecWithoutFuncSecModule => "codesec-without-funcsec-module"
    InvalidTableNameSectionIndexModule =>
      "invalid-table-name-section-index-module"
    InvalidGlobalNameSectionIndexModule =>
      "invalid-global-name-section-index-module"
    ReservedSectionId => "reserved-section-id"
    InvalidCustomSectionNameUtf8 => "invalid-custom-section-name-utf8"
    InvalidTypeNameSectionIndexModule =>
      "invalid-type-name-section-index-module"
    InvalidFieldNameSectionIndexModule =>
      "invalid-field-name-section-index-module"
    InvalidElemNameSectionIndexModule =>
      "invalid-elem-name-section-index-module"
    InvalidDataNameSectionIndexModule =>
      "invalid-data-name-section-index-module"
    InvalidExportTableIndexModule => "invalid-export-table-index-module"
    InvalidExportGlobalIndexModule => "invalid-export-global-index-module"
    InvalidExportMemoryIndexModule => "invalid-export-memory-index-module"
    InvalidExportTagIndexModule => "invalid-export-tag-index-module"
    InvalidTagNameSectionIndexModule => "invalid-tag-name-section-index-module"
    InvalidImportedTagTypeIndexModule =>
      "invalid-imported-tag-type-index-module"
    DataCountMismatchTooSmallModule => "datacount-mismatch-too-small-module"
    DataCountMismatchTooLargeModule => "datacount-mismatch-too-large-module"
    InvalidBinaryBodyLocalSetValueTypeModule =>
      "invalid-binary-body-local-set-value-type-module"
    InvalidBinaryBranchPayloadTypeModule =>
      "invalid-binary-branch-payload-type-module"
    InvalidBinaryLocalIndexModule => "invalid-binary-local-index-module"
    InvalidBinaryCallRefTypeModule => "invalid-binary-call-ref-type-module"
    InvalidBinaryStructGetFieldIndexModule =>
      "invalid-binary-struct-get-field-index-module"
    InvalidBinaryThrowPayloadModule => "invalid-binary-throw-payload-module"
    InvalidBinarySharedMemoryWithoutMaxModule =>
      "invalid-binary-shared-memory-without-max-module"
    InvalidBinaryMemory64AddressTypeModule =>
      "invalid-binary-memory64-address-type-module"
    MalformedSimdImmediate => "malformed-simd-immediate"
    SimdLaneIndexOverflow => "simd-lane-index-overflow"
    MalformedCustomSectionPayload => "malformed-custom-section-payload"
    MalformedCustomSectionNameLengthUleb =>
      "malformed-custom-section-name-length-uleb"
    OverwideCustomSectionNameLengthUleb =>
      "overwide-custom-section-name-length-uleb"
    MalformedNameSubsectionSizeUleb => "malformed-name-subsection-size-uleb"
    OverwideNameSubsectionSizeUleb => "overwide-name-subsection-size-uleb"
    InvalidNameSubsectionIdByte => "invalid-name-subsection-id-byte"
    OutOfOrderNameSubsectionId => "out-of-order-name-subsection-id"
    InvalidOpcodeByte => "invalid-opcode-byte"
    InvalidPrefixSubopcodeByte => "invalid-prefix-subopcode-byte"
    InvalidGcPrefixSubopcodeByte => "invalid-gc-prefix-subopcode-byte"
    InvalidBulkPrefixSubopcodeByte => "invalid-bulk-prefix-subopcode-byte"
    InvalidSimdPrefixSubopcodeByte => "invalid-simd-prefix-subopcode-byte"
    MalformedGcPrefixSubopcodeUleb => "malformed-gc-prefix-subopcode-uleb"
    MalformedBulkPrefixSubopcodeUleb => "malformed-bulk-prefix-subopcode-uleb"
    MalformedSimdPrefixSubopcodeUleb => "malformed-simd-prefix-subopcode-uleb"
    MalformedAtomicPrefixSubopcodeUleb =>
      "malformed-atomic-prefix-subopcode-uleb"
    InvalidAtomicPrefixSubopcodeByte => "invalid-atomic-prefix-subopcode-byte"
    OverwideGcPrefixSubopcodeUleb => "overwide-gc-prefix-subopcode-uleb"
    OverwideBulkPrefixSubopcodeUleb => "overwide-bulk-prefix-subopcode-uleb"
    OverwideSimdPrefixSubopcodeUleb => "overwide-simd-prefix-subopcode-uleb"
    OverwideAtomicPrefixSubopcodeUleb => "overwide-atomic-prefix-subopcode-uleb"
    MalformedAtomicLoadMemargAlignUleb =>
      "malformed-atomic-load-memarg-align-uleb"
    MalformedAtomicStoreMemargAlignUleb =>
      "malformed-atomic-store-memarg-align-uleb"
    MalformedAtomicLoadMemargOffsetUleb =>
      "malformed-atomic-load-memarg-offset-uleb"
    MalformedAtomicStoreMemargOffsetUleb =>
      "malformed-atomic-store-memarg-offset-uleb"
    MalformedAtomicNotifyMemargAlignUleb =>
      "malformed-atomic-notify-memarg-align-uleb"
    MalformedAtomicNotifyMemargOffsetUleb =>
      "malformed-atomic-notify-memarg-offset-uleb"
    MalformedAtomicWaitMemargAlignUleb =>
      "malformed-atomic-wait-memarg-align-uleb"
    MalformedAtomicWaitMemargOffsetUleb =>
      "malformed-atomic-wait-memarg-offset-uleb"
    MalformedAtomicRmwMemargAlignUleb =>
      "malformed-atomic-rmw-memarg-align-uleb"
    MalformedAtomicRmwMemargOffsetUleb =>
      "malformed-atomic-rmw-memarg-offset-uleb"
    MalformedAtomicCmpxchgMemargAlignUleb =>
      "malformed-atomic-cmpxchg-memarg-align-uleb"
    MalformedAtomicCmpxchgMemargOffsetUleb =>
      "malformed-atomic-cmpxchg-memarg-offset-uleb"
    OverwideAtomicLoadMemargAlignUleb =>
      "overwide-atomic-load-memarg-align-uleb"
    OverwideAtomicStoreMemargAlignUleb =>
      "overwide-atomic-store-memarg-align-uleb"
    OverwideAtomicLoadMemargOffsetUleb =>
      "overwide-atomic-load-memarg-offset-uleb"
    OverwideAtomicStoreMemargOffsetUleb =>
      "overwide-atomic-store-memarg-offset-uleb"
    OverwideAtomicNotifyMemargAlignUleb =>
      "overwide-atomic-notify-memarg-align-uleb"
    OverwideAtomicNotifyMemargOffsetUleb =>
      "overwide-atomic-notify-memarg-offset-uleb"
    OverwideAtomicWaitMemargAlignUleb =>
      "overwide-atomic-wait-memarg-align-uleb"
    OverwideAtomicWaitMemargOffsetUleb =>
      "overwide-atomic-wait-memarg-offset-uleb"
    OverwideAtomicRmwMemargAlignUleb => "overwide-atomic-rmw-memarg-align-uleb"
    OverwideAtomicRmwMemargOffsetUleb =>
      "overwide-atomic-rmw-memarg-offset-uleb"
    OverwideAtomicCmpxchgMemargAlignUleb =>
      "overwide-atomic-cmpxchg-memarg-align-uleb"
    OverwideAtomicCmpxchgMemargOffsetUleb =>
      "overwide-atomic-cmpxchg-memarg-offset-uleb"
    MalformedMemargImmediate => "malformed-memarg-immediate"
    MalformedLoadMemargAlignUleb => "malformed-load-memarg-align-uleb"
    MalformedStoreMemargAlignUleb => "malformed-store-memarg-align-uleb"
    MalformedLoadMemargOffsetUleb => "malformed-load-memarg-offset-uleb"
    MalformedStoreMemargOffsetUleb => "malformed-store-memarg-offset-uleb"
    OverwideLoadMemargAlignUleb => "overwide-load-memarg-align-uleb"
    OverwideStoreMemargAlignUleb => "overwide-store-memarg-align-uleb"
    OverwideLoadMemargOffsetUleb => "overwide-load-memarg-offset-uleb"
    OverwideStoreMemargOffsetUleb => "overwide-store-memarg-offset-uleb"
    MalformedBlocktypeImmediate => "malformed-blocktype-immediate"
    InvalidBlocktypeValTypeByte => "invalid-blocktype-valtype-byte"
    OverwideBlocktypeTypeIndexUleb => "overwide-blocktype-type-index-uleb"
    MalformedMemoryMinUleb => "malformed-memory-min-uleb"
    MalformedTableMinUleb => "malformed-table-min-uleb"
    MalformedMemoryMaxUleb => "malformed-memory-max-uleb"
    MalformedTableMaxUleb => "malformed-table-max-uleb"
    OverwideMemoryMinUleb => "overwide-memory-min-uleb"
    OverwideTableMinUleb => "overwide-table-min-uleb"
    OverwideMemoryMaxUleb => "overwide-memory-max-uleb"
    OverwideTableMaxUleb => "overwide-table-max-uleb"
    InvalidExportNameUtf8 => "invalid-export-name-utf8"
    MalformedExportNameLengthUleb => "malformed-export-name-length-uleb"
    OverwideExportNameLengthUleb => "overwide-export-name-length-uleb"
    InvalidImportModuleNameUtf8 => "invalid-import-module-name-utf8"
    MalformedImportModuleNameLengthUleb =>
      "malformed-import-module-name-length-uleb"
    OverwideImportModuleNameLengthUleb =>
      "overwide-import-module-name-length-uleb"
    InvalidImportFieldNameUtf8 => "invalid-import-field-name-utf8"
    MalformedImportFieldNameLengthUleb =>
      "malformed-import-field-name-length-uleb"
    OverwideImportFieldNameLengthUleb =>
      "overwide-import-field-name-length-uleb"
    InvalidImportKindByte => "invalid-import-kind-byte"
    MalformedFunctionSectionTypeIndexUleb =>
      "malformed-function-section-type-index-uleb"
    OverwideFunctionSectionTypeIndexUleb =>
      "overwide-function-section-type-index-uleb"
    MalformedImportFuncTypeIndexUleb => "malformed-import-func-type-index-uleb"
    OverwideImportFuncTypeIndexUleb => "overwide-import-func-type-index-uleb"
    MalformedImportTagTypeIndexUleb => "malformed-import-tag-type-index-uleb"
    OverwideImportTagTypeIndexUleb => "overwide-import-tag-type-index-uleb"
    MalformedImportMemoryMinUleb => "malformed-import-memory-min-uleb"
    MalformedImportTableMinUleb => "malformed-import-table-min-uleb"
    MalformedImportMemoryMaxUleb => "malformed-import-memory-max-uleb"
    MalformedImportTableMaxUleb => "malformed-import-table-max-uleb"
    OverwideImportMemoryMinUleb => "overwide-import-memory-min-uleb"
    OverwideImportTableMinUleb => "overwide-import-table-min-uleb"
    OverwideImportMemoryMaxUleb => "overwide-import-memory-max-uleb"
    OverwideImportTableMaxUleb => "overwide-import-table-max-uleb"
    InvalidImportTableRefTypeByte => "invalid-import-table-reftype-byte"
    InvalidImportMemoryLimitsFlagByte =>
      "invalid-import-memory-limits-flag-byte"
    InvalidImportGlobalValTypeByte => "invalid-import-global-valtype-byte"
    InvalidImportGlobalMutabilityByte => "invalid-import-global-mutability-byte"
    InvalidImportTagAttributeByte => "invalid-import-tag-attribute-byte"
    InvalidTableRefTypeByte => "invalid-table-reftype-byte"
    InvalidTableLimitsFlagByte => "invalid-table-limits-flag-byte"
    MalformedRefNullHeaptypeImmediate => "malformed-ref-null-heaptype-immediate"
    MalformedRefCastHeaptypeImmediate => "malformed-ref-cast-heaptype-immediate"
    MalformedRefTestHeaptypeImmediate => "malformed-ref-test-heaptype-immediate"
    OverwideRefNullHeaptypeImmediate => "overwide-ref-null-heaptype-immediate"
    OverwideRefCastHeaptypeImmediate => "overwide-ref-cast-heaptype-immediate"
    OverwideRefTestHeaptypeImmediate => "overwide-ref-test-heaptype-immediate"
    InvalidGlobalValTypeByte => "invalid-global-valtype-byte"
    InvalidExportKindByte => "invalid-export-kind-byte"
    InvalidMemoryLimitsFlagByte => "invalid-memory-limits-flag-byte"
    InvalidTagAttributeByte => "invalid-tag-attribute-byte"
    InvalidGlobalMutabilityByte => "invalid-global-mutability-byte"
    MalformedExportFuncIndexUleb => "malformed-export-func-index-uleb"
    MalformedExportTableIndexUleb => "malformed-export-table-index-uleb"
    MalformedExportMemoryIndexUleb => "malformed-export-memory-index-uleb"
    MalformedExportGlobalIndexUleb => "malformed-export-global-index-uleb"
    MalformedExportTagIndexUleb => "malformed-export-tag-index-uleb"
    OverwideExportFuncIndexUleb => "overwide-export-func-index-uleb"
    OverwideExportTableIndexUleb => "overwide-export-table-index-uleb"
    OverwideExportMemoryIndexUleb => "overwide-export-memory-index-uleb"
    OverwideExportGlobalIndexUleb => "overwide-export-global-index-uleb"
    OverwideExportTagIndexUleb => "overwide-export-tag-index-uleb"
    InvalidElementSegmentFlagByte => "invalid-element-segment-flag-byte"
    InvalidElementKindByte => "invalid-element-kind-byte"
    InvalidDataSegmentFlagByte => "invalid-data-segment-flag-byte"
    TypeSectionCountOverflow => "type-section-count-overflow"
    CodeSectionCountOverflow => "code-section-count-overflow"
    TableSectionCountOverflow => "table-section-count-overflow"
    ExportSectionCountOverflow => "export-section-count-overflow"
    ImportSectionCountOverflow => "import-section-count-overflow"
    GlobalSectionCountOverflow => "global-section-count-overflow"
    FunctionSectionCountOverflow => "function-section-count-overflow"
    MemorySectionCountOverflow => "memory-section-count-overflow"
    ElementSectionCountOverflow => "element-section-count-overflow"
    DataSectionCountOverflow => "data-section-count-overflow"
    TagSectionCountOverflow => "tag-section-count-overflow"
    MalformedTagTypeIndexUleb => "malformed-tag-type-index-uleb"
    OverwideTagTypeIndexUleb => "overwide-tag-type-index-uleb"
    MalformedLocalIndexUleb => "malformed-local-index-uleb"
    MalformedLocalSetIndexUleb => "malformed-local-set-index-uleb"
    MalformedLocalTeeIndexUleb => "malformed-local-tee-index-uleb"
    OverwideLocalIndexUleb => "overwide-local-index-uleb"
    OverwideLocalSetIndexUleb => "overwide-local-set-index-uleb"
    OverwideLocalTeeIndexUleb => "overwide-local-tee-index-uleb"
    MalformedGlobalIndexUleb => "malformed-global-index-uleb"
    MalformedGlobalSetIndexUleb => "malformed-global-set-index-uleb"
    OverwideGlobalIndexUleb => "overwide-global-index-uleb"
    OverwideGlobalSetIndexUleb => "overwide-global-set-index-uleb"
    MalformedI32ConstSleb => "malformed-i32-const-sleb"
    MalformedI64ConstSleb => "malformed-i64-const-sleb"
    OverwideI32ConstSleb => "overwide-i32-const-sleb"
    OverwideI64ConstSleb => "overwide-i64-const-sleb"
    MalformedF32ConstImmediate => "malformed-f32-const-immediate"
    MalformedF64ConstImmediate => "malformed-f64-const-immediate"
    MalformedCallFuncIndexUleb => "malformed-call-func-index-uleb"
    MalformedReturnCallFuncIndexUleb => "malformed-return-call-func-index-uleb"
    MalformedRefFuncIndexUleb => "malformed-ref-func-index-uleb"
    OverwideCallFuncIndexUleb => "overwide-call-func-index-uleb"
    OverwideReturnCallFuncIndexUleb => "overwide-return-call-func-index-uleb"
    OverwideRefFuncIndexUleb => "overwide-ref-func-index-uleb"
    MalformedCallIndirectTypeIndexUleb =>
      "malformed-call-indirect-type-index-uleb"
    MalformedCallIndirectTableIndexUleb =>
      "malformed-call-indirect-table-index-uleb"
    MalformedReturnCallIndirectTypeIndexUleb =>
      "malformed-return-call-indirect-type-index-uleb"
    MalformedReturnCallIndirectTableIndexUleb =>
      "malformed-return-call-indirect-table-index-uleb"
    MalformedCallRefTypeIndexUleb => "malformed-call-ref-type-index-uleb"
    MalformedReturnCallRefTypeIndexUleb =>
      "malformed-return-call-ref-type-index-uleb"
    OverwideCallIndirectTypeIndexUleb =>
      "overwide-call-indirect-type-index-uleb"
    OverwideCallIndirectTableIndexUleb =>
      "overwide-call-indirect-table-index-uleb"
    OverwideReturnCallIndirectTypeIndexUleb =>
      "overwide-return-call-indirect-type-index-uleb"
    OverwideReturnCallIndirectTableIndexUleb =>
      "overwide-return-call-indirect-table-index-uleb"
    OverwideCallRefTypeIndexUleb => "overwide-call-ref-type-index-uleb"
    OverwideReturnCallRefTypeIndexUleb =>
      "overwide-return-call-ref-type-index-uleb"
    MalformedThrowTagIndexUleb => "malformed-throw-tag-index-uleb"
    MalformedTryTableCatchCountUleb => "malformed-try-table-catch-count-uleb"
    MalformedTryTableCatchTagIndexUleb =>
      "malformed-try-table-catch-tag-index-uleb"
    MalformedTryTableCatchLabelIndexUleb =>
      "malformed-try-table-catch-label-index-uleb"
    OverwideThrowTagIndexUleb => "overwide-throw-tag-index-uleb"
    OverwideTryTableCatchCountUleb => "overwide-try-table-catch-count-uleb"
    OverwideTryTableCatchTagIndexUleb =>
      "overwide-try-table-catch-tag-index-uleb"
    OverwideTryTableCatchLabelIndexUleb =>
      "overwide-try-table-catch-label-index-uleb"
    MalformedStructNewTypeIndexUleb => "malformed-struct-new-type-index-uleb"
    MalformedStructGetFieldIndexUleb => "malformed-struct-get-field-index-uleb"
    MalformedArrayNewDataTypeIndexUleb =>
      "malformed-array-new-data-type-index-uleb"
    MalformedArrayNewDataIndexUleb => "malformed-array-new-data-index-uleb"
    MalformedArrayNewElemTypeIndexUleb =>
      "malformed-array-new-elem-type-index-uleb"
    MalformedArrayNewElemElemIndexUleb =>
      "malformed-array-new-elem-elem-index-uleb"
    OverwideStructNewTypeIndexUleb => "overwide-struct-new-type-index-uleb"
    OverwideStructGetFieldIndexUleb => "overwide-struct-get-field-index-uleb"
    OverwideArrayNewDataTypeIndexUleb =>
      "overwide-array-new-data-type-index-uleb"
    OverwideArrayNewDataIndexUleb => "overwide-array-new-data-index-uleb"
    OverwideArrayNewElemTypeIndexUleb =>
      "overwide-array-new-elem-type-index-uleb"
    OverwideArrayNewElemElemIndexUleb =>
      "overwide-array-new-elem-elem-index-uleb"
    MalformedBrLabelIndexUleb => "malformed-br-label-index-uleb"
    MalformedBrIfLabelIndexUleb => "malformed-br-if-label-index-uleb"
    MalformedBrTableTargetCountUleb => "malformed-br-table-target-count-uleb"
    MalformedBrTableTargetLabelIndexUleb =>
      "malformed-br-table-target-label-index-uleb"
    MalformedBrTableDefaultLabelIndexUleb =>
      "malformed-br-table-default-label-index-uleb"
    OverwideBrLabelIndexUleb => "overwide-br-label-index-uleb"
    OverwideBrIfLabelIndexUleb => "overwide-br-if-label-index-uleb"
    OverwideBrTableTargetCountUleb => "overwide-br-table-target-count-uleb"
    OverwideBrTableTargetLabelIndexUleb =>
      "overwide-br-table-target-label-index-uleb"
    OverwideBrTableDefaultLabelIndexUleb =>
      "overwide-br-table-default-label-index-uleb"
    MalformedTableIndexUleb => "malformed-table-index-uleb"
    MalformedTableSetIndexUleb => "malformed-table-set-index-uleb"
    MalformedTableSizeIndexUleb => "malformed-table-size-index-uleb"
    MalformedTableGrowIndexUleb => "malformed-table-grow-index-uleb"
    MalformedTableFillIndexUleb => "malformed-table-fill-index-uleb"
    OverwideTableIndexUleb => "overwide-table-index-uleb"
    OverwideTableSetIndexUleb => "overwide-table-set-index-uleb"
    OverwideTableSizeIndexUleb => "overwide-table-size-index-uleb"
    OverwideTableGrowIndexUleb => "overwide-table-grow-index-uleb"
    OverwideTableFillIndexUleb => "overwide-table-fill-index-uleb"
    MalformedMemorySizeMemoryIndexUleb =>
      "malformed-memory-size-memory-index-uleb"
    MalformedMemoryGrowMemoryIndexUleb =>
      "malformed-memory-grow-memory-index-uleb"
    MalformedMemoryFillMemoryIndexUleb =>
      "malformed-memory-fill-memory-index-uleb"
    OverwideMemorySizeMemoryIndexUleb =>
      "overwide-memory-size-memory-index-uleb"
    OverwideMemoryGrowMemoryIndexUleb =>
      "overwide-memory-grow-memory-index-uleb"
    OverwideMemoryFillMemoryIndexUleb =>
      "overwide-memory-fill-memory-index-uleb"
    MalformedMemoryCopyDstIndexUleb => "malformed-memory-copy-dst-index-uleb"
    MalformedMemoryCopySrcIndexUleb => "malformed-memory-copy-src-index-uleb"
    MalformedTableCopyDstIndexUleb => "malformed-table-copy-dst-index-uleb"
    MalformedTableCopySrcIndexUleb => "malformed-table-copy-src-index-uleb"
    OverwideMemoryCopyDstIndexUleb => "overwide-memory-copy-dst-index-uleb"
    OverwideMemoryCopySrcIndexUleb => "overwide-memory-copy-src-index-uleb"
    OverwideTableCopyDstIndexUleb => "overwide-table-copy-dst-index-uleb"
    OverwideTableCopySrcIndexUleb => "overwide-table-copy-src-index-uleb"
    MalformedSelectTypeCountUleb => "malformed-select-type-count-uleb"
    OverwideSelectTypeCountUleb => "overwide-select-type-count-uleb"
    InvalidTypedSelectValTypeByte => "invalid-typed-select-valtype-byte"
    MalformedStartFuncIndexUleb => "malformed-start-func-index-uleb"
    OverwideStartFuncIndexUleb => "overwide-start-func-index-uleb"
    MalformedDataCountUleb => "malformed-datacount-uleb"
    OverwideDataCountUleb => "overwide-datacount-uleb"
    SimdShuffleLaneOverflow => "simd-shuffle-lane-overflow"
    SimdLoadLaneIndexOverflow => "simd-load-lane-index-overflow"
    SimdStoreLaneIndexOverflow => "simd-store-lane-index-overflow"
    SimdExtractLaneIndexOverflow => "simd-extract-lane-index-overflow"
    SimdReplaceLaneIndexOverflow => "simd-replace-lane-index-overflow"
    MalformedSimdLoadMemargAlignUleb => "malformed-simd-load-memarg-align-uleb"
    MalformedSimdStoreMemargAlignUleb =>
      "malformed-simd-store-memarg-align-uleb"
    MalformedSimdLoadMemargOffsetUleb =>
      "malformed-simd-load-memarg-offset-uleb"
    MalformedSimdStoreMemargOffsetUleb =>
      "malformed-simd-store-memarg-offset-uleb"
    OverwideSimdLoadMemargAlignUleb => "overwide-simd-load-memarg-align-uleb"
    OverwideSimdStoreMemargAlignUleb => "overwide-simd-store-memarg-align-uleb"
    OverwideSimdLoadMemargOffsetUleb => "overwide-simd-load-memarg-offset-uleb"
    OverwideSimdStoreMemargOffsetUleb =>
      "overwide-simd-store-memarg-offset-uleb"
    MalformedSimdLoadLaneMemargAlignUleb =>
      "malformed-simd-load-lane-memarg-align-uleb"
    MalformedSimdStoreLaneMemargAlignUleb =>
      "malformed-simd-store-lane-memarg-align-uleb"
    MalformedSimdLoadLaneMemargOffsetUleb =>
      "malformed-simd-load-lane-memarg-offset-uleb"
    MalformedSimdStoreLaneMemargOffsetUleb =>
      "malformed-simd-store-lane-memarg-offset-uleb"
    OverwideSimdLoadLaneMemargAlignUleb =>
      "overwide-simd-load-lane-memarg-align-uleb"
    OverwideSimdStoreLaneMemargAlignUleb =>
      "overwide-simd-store-lane-memarg-align-uleb"
    OverwideSimdLoadLaneMemargOffsetUleb =>
      "overwide-simd-load-lane-memarg-offset-uleb"
    OverwideSimdStoreLaneMemargOffsetUleb =>
      "overwide-simd-store-lane-memarg-offset-uleb"
    MalformedSimdLoadSplatMemargAlignUleb =>
      "malformed-simd-load-splat-memarg-align-uleb"
    MalformedSimdLoadSplatMemargOffsetUleb =>
      "malformed-simd-load-splat-memarg-offset-uleb"
    OverwideSimdLoadSplatMemargAlignUleb =>
      "overwide-simd-load-splat-memarg-align-uleb"
    OverwideSimdLoadSplatMemargOffsetUleb =>
      "overwide-simd-load-splat-memarg-offset-uleb"
    MalformedSimdLoadExtendMemargAlignUleb =>
      "malformed-simd-load-extend-memarg-align-uleb"
    MalformedSimdLoadExtendMemargOffsetUleb =>
      "malformed-simd-load-extend-memarg-offset-uleb"
    OverwideSimdLoadExtendMemargAlignUleb =>
      "overwide-simd-load-extend-memarg-align-uleb"
    OverwideSimdLoadExtendMemargOffsetUleb =>
      "overwide-simd-load-extend-memarg-offset-uleb"
    MalformedSimdLoadZeroMemargAlignUleb =>
      "malformed-simd-load-zero-memarg-align-uleb"
    MalformedSimdLoadZeroMemargOffsetUleb =>
      "malformed-simd-load-zero-memarg-offset-uleb"
    OverwideSimdLoadZeroMemargAlignUleb =>
      "overwide-simd-load-zero-memarg-align-uleb"
    OverwideSimdLoadZeroMemargOffsetUleb =>
      "overwide-simd-load-zero-memarg-offset-uleb"
    MalformedDataIndexUleb => "malformed-data-index-uleb"
    OverwideDataIndexUleb => "overwide-data-index-uleb"
    MalformedDataSegmentByteCountUleb =>
      "malformed-data-segment-byte-count-uleb"
    OverwideDataSegmentByteCountUleb => "overwide-data-segment-byte-count-uleb"
    MalformedMemoryInitDataIndexUleb => "malformed-memory-init-data-index-uleb"
    MalformedMemoryInitMemoryIndexUleb =>
      "malformed-memory-init-memory-index-uleb"
    OverwideMemoryInitDataIndexUleb => "overwide-memory-init-data-index-uleb"
    OverwideMemoryInitMemoryIndexUleb =>
      "overwide-memory-init-memory-index-uleb"
    MalformedElemIndexUleb => "malformed-elem-index-uleb"
    OverwideElemIndexUleb => "overwide-elem-index-uleb"
    MalformedTableInitElemIndexUleb => "malformed-table-init-elem-index-uleb"
    MalformedTableInitTableIndexUleb => "malformed-table-init-table-index-uleb"
    OverwideTableInitElemIndexUleb => "overwide-table-init-elem-index-uleb"
    OverwideTableInitTableIndexUleb => "overwide-table-init-table-index-uleb"
    MalformedDataSegmentMemoryIndexUleb =>
      "malformed-data-segment-memory-index-uleb"
    OverwideDataSegmentMemoryIndexUleb =>
      "overwide-data-segment-memory-index-uleb"
    MalformedElementSegmentTableIndexUleb =>
      "malformed-element-segment-table-index-uleb"
    MalformedElementSegmentFuncIndexUleb =>
      "malformed-element-segment-func-index-uleb"
    OverwideElementSegmentTableIndexUleb =>
      "overwide-element-segment-table-index-uleb"
    OverwideElementSegmentFuncIndexUleb =>
      "overwide-element-segment-func-index-uleb"
    InvalidNameSectionFuncNameUtf8 => "invalid-name-section-func-name-utf8"
    MalformedNameSectionFuncNameLengthUleb =>
      "malformed-name-section-func-name-length-uleb"
    OverwideNameSectionFuncNameLengthUleb =>
      "overwide-name-section-func-name-length-uleb"
    MalformedNameSectionFuncNameCountUleb =>
      "malformed-name-section-func-name-count-uleb"
    OverwideNameSectionFuncNameCountUleb =>
      "overwide-name-section-func-name-count-uleb"
    InvalidNameSectionLocalNameUtf8 => "invalid-name-section-local-name-utf8"
    MalformedNameSectionLocalNameLengthUleb =>
      "malformed-name-section-local-name-length-uleb"
    OverwideNameSectionLocalNameLengthUleb =>
      "overwide-name-section-local-name-length-uleb"
    MalformedNameSectionLocalNameCountUleb =>
      "malformed-name-section-local-name-count-uleb"
    OverwideNameSectionLocalNameCountUleb =>
      "overwide-name-section-local-name-count-uleb"
    InvalidNameSectionModuleNameUtf8 => "invalid-name-section-module-name-utf8"
    MalformedNameSectionModuleNameLengthUleb =>
      "malformed-name-section-module-name-length-uleb"
    OverwideNameSectionModuleNameLengthUleb =>
      "overwide-name-section-module-name-length-uleb"
    InvalidNameSectionTypeNameUtf8 => "invalid-name-section-type-name-utf8"
    MalformedNameSectionTypeNameLengthUleb =>
      "malformed-name-section-type-name-length-uleb"
    OverwideNameSectionTypeNameLengthUleb =>
      "overwide-name-section-type-name-length-uleb"
    MalformedNameSectionTypeNameCountUleb =>
      "malformed-name-section-type-name-count-uleb"
    OverwideNameSectionTypeNameCountUleb =>
      "overwide-name-section-type-name-count-uleb"
    InvalidNameSectionTableNameUtf8 => "invalid-name-section-table-name-utf8"
    MalformedNameSectionTableNameLengthUleb =>
      "malformed-name-section-table-name-length-uleb"
    OverwideNameSectionTableNameLengthUleb =>
      "overwide-name-section-table-name-length-uleb"
    MalformedNameSectionTableNameCountUleb =>
      "malformed-name-section-table-name-count-uleb"
    OverwideNameSectionTableNameCountUleb =>
      "overwide-name-section-table-name-count-uleb"
    InvalidNameSectionMemoryNameUtf8 => "invalid-name-section-memory-name-utf8"
    MalformedNameSectionMemoryNameLengthUleb =>
      "malformed-name-section-memory-name-length-uleb"
    OverwideNameSectionMemoryNameLengthUleb =>
      "overwide-name-section-memory-name-length-uleb"
    MalformedNameSectionMemoryNameCountUleb =>
      "malformed-name-section-memory-name-count-uleb"
    OverwideNameSectionMemoryNameCountUleb =>
      "overwide-name-section-memory-name-count-uleb"
    InvalidNameSectionGlobalNameUtf8 => "invalid-name-section-global-name-utf8"
    MalformedNameSectionGlobalNameLengthUleb =>
      "malformed-name-section-global-name-length-uleb"
    OverwideNameSectionGlobalNameLengthUleb =>
      "overwide-name-section-global-name-length-uleb"
    MalformedNameSectionGlobalNameCountUleb =>
      "malformed-name-section-global-name-count-uleb"
    OverwideNameSectionGlobalNameCountUleb =>
      "overwide-name-section-global-name-count-uleb"
    InvalidNameSectionElemNameUtf8 => "invalid-name-section-elem-name-utf8"
    MalformedNameSectionElemNameLengthUleb =>
      "malformed-name-section-elem-name-length-uleb"
    OverwideNameSectionElemNameLengthUleb =>
      "overwide-name-section-elem-name-length-uleb"
    MalformedNameSectionElemNameCountUleb =>
      "malformed-name-section-elem-name-count-uleb"
    OverwideNameSectionElemNameCountUleb =>
      "overwide-name-section-elem-name-count-uleb"
    InvalidNameSectionDataNameUtf8 => "invalid-name-section-data-name-utf8"
    MalformedNameSectionDataNameLengthUleb =>
      "malformed-name-section-data-name-length-uleb"
    OverwideNameSectionDataNameLengthUleb =>
      "overwide-name-section-data-name-length-uleb"
    InvalidNameSectionFieldNameUtf8 => "invalid-name-section-field-name-utf8"
    MalformedNameSectionFieldNameLengthUleb =>
      "malformed-name-section-field-name-length-uleb"
    OverwideNameSectionFieldNameLengthUleb =>
      "overwide-name-section-field-name-length-uleb"
    InvalidNameSectionLabelNameUtf8 => "invalid-name-section-label-name-utf8"
    MalformedNameSectionLabelNameLengthUleb =>
      "malformed-name-section-label-name-length-uleb"
    OverwideNameSectionLabelNameLengthUleb =>
      "overwide-name-section-label-name-length-uleb"
    InvalidNameSectionTagNameUtf8 => "invalid-name-section-tag-name-utf8"
    MalformedNameSectionTagNameLengthUleb =>
      "malformed-name-section-tag-name-length-uleb"
    OverwideNameSectionTagNameLengthUleb =>
      "overwide-name-section-tag-name-length-uleb"
    InvalidFuncTypeByte => "invalid-functype-byte"
    MalformedFuncTypeParamCountUleb => "malformed-functype-param-count-uleb"
    MalformedFuncTypeResultCountUleb => "malformed-functype-result-count-uleb"
    OverwideFuncTypeParamCountUleb => "overwide-functype-param-count-uleb"
    OverwideFuncTypeResultCountUleb => "overwide-functype-result-count-uleb"
    InvalidFuncTypeParamValTypeByte => "invalid-functype-param-valtype-byte"
    InvalidFuncTypeResultValTypeByte => "invalid-functype-result-valtype-byte"
    InvalidCodeLocalValTypeByte => "invalid-code-local-valtype-byte"
    MalformedCodeLocalDeclCountUleb => "malformed-code-local-decl-count-uleb"
    MalformedCodeLocalRunCountUleb => "malformed-code-local-run-count-uleb"
    OverwideCodeLocalDeclCountUleb => "overwide-code-local-decl-count-uleb"
    OverwideCodeLocalRunCountUleb => "overwide-code-local-run-count-uleb"
    MalformedTypeSectionCountUleb => "malformed-type-section-count-uleb"
    MalformedCodeSectionCountUleb => "malformed-code-section-count-uleb"
    MalformedImportSectionCountUleb => "malformed-import-section-count-uleb"
    MalformedExportSectionCountUleb => "malformed-export-section-count-uleb"
    MalformedTableSectionCountUleb => "malformed-table-section-count-uleb"
    MalformedMemorySectionCountUleb => "malformed-memory-section-count-uleb"
    MalformedGlobalSectionCountUleb => "malformed-global-section-count-uleb"
    MalformedFunctionSectionCountUleb => "malformed-function-section-count-uleb"
    MalformedElementSectionCountUleb => "malformed-element-section-count-uleb"
    MalformedDataSectionCountUleb => "malformed-data-section-count-uleb"
    MalformedTagSectionCountUleb => "malformed-tag-section-count-uleb"
    OverwideTypeSectionCountUleb => "overwide-type-section-count-uleb"
    OverwideCodeSectionCountUleb => "overwide-code-section-count-uleb"
    OverwideImportSectionCountUleb => "overwide-import-section-count-uleb"
    OverwideExportSectionCountUleb => "overwide-export-section-count-uleb"
    OverwideTableSectionCountUleb => "overwide-table-section-count-uleb"
    OverwideMemorySectionCountUleb => "overwide-memory-section-count-uleb"
    OverwideGlobalSectionCountUleb => "overwide-global-section-count-uleb"
    OverwideFunctionSectionCountUleb => "overwide-function-section-count-uleb"
    OverwideElementSectionCountUleb => "overwide-element-section-count-uleb"
    OverwideDataSectionCountUleb => "overwide-data-section-count-uleb"
    OverwideTagSectionCountUleb => "overwide-tag-section-count-uleb"
    TypeSectionCountUnderflow => "type-section-count-underflow"
    CodeSectionCountUnderflow => "code-section-count-underflow"
    ImportSectionCountUnderflow => "import-section-count-underflow"
    ExportSectionCountUnderflow => "export-section-count-underflow"
    TableSectionCountUnderflow => "table-section-count-underflow"
    MemorySectionCountUnderflow => "memory-section-count-underflow"
    GlobalSectionCountUnderflow => "global-section-count-underflow"
    FunctionSectionCountUnderflow => "function-section-count-underflow"
    ElementSectionCountUnderflow => "element-section-count-underflow"
    DataSectionCountUnderflow => "data-section-count-underflow"
    TagSectionCountUnderflow => "tag-section-count-underflow"
    TypeSectionSizeUnderflow => "type-section-size-underflow"
    CodeBodySizeUnderflow => "code-body-size-underflow"
    MalformedCodeBodySizeUleb => "malformed-code-body-size-uleb"
    OverwideCodeBodySizeUleb => "overwide-code-body-size-uleb"
    ImportSectionSizeUnderflow => "import-section-size-underflow"
    ExportSectionSizeUnderflow => "export-section-size-underflow"
    TableSectionSizeUnderflow => "table-section-size-underflow"
    MemorySectionSizeUnderflow => "memory-section-size-underflow"
    GlobalSectionSizeUnderflow => "global-section-size-underflow"
    FunctionSectionSizeUnderflow => "function-section-size-underflow"
    ElementSectionSizeUnderflow => "element-section-size-underflow"
    DataSectionSizeUnderflow => "data-section-size-underflow"
    TagSectionSizeUnderflow => "tag-section-size-underflow"
    TypeSectionSizeOverflow => "type-section-size-overflow"
    CodeSectionSizeOverflow => "code-section-size-overflow"
    ImportSectionSizeOverflow => "import-section-size-overflow"
    ExportSectionSizeOverflow => "export-section-size-overflow"
    TableSectionSizeOverflow => "table-section-size-overflow"
    MemorySectionSizeOverflow => "memory-section-size-overflow"
    GlobalSectionSizeOverflow => "global-section-size-overflow"
    FunctionSectionSizeOverflow => "function-section-size-overflow"
    ElementSectionSizeOverflow => "element-section-size-overflow"
    DataSectionSizeOverflow => "data-section-size-overflow"
    TagSectionSizeOverflow => "tag-section-size-overflow"
    StartSectionSizeUnderflow => "start-section-size-underflow"
    DataCountSectionSizeUnderflow => "datacount-section-size-underflow"
    StartSectionSizeOverflow => "start-section-size-overflow"
    DataCountSectionSizeOverflow => "datacount-section-size-overflow"
  }
}

///|
fn gen_invalid_binary_apply_seed_prerequisite(
  config : GenValidConfig,
  prerequisite : String,
) -> GenValidConfig {
  match prerequisite {
    "defined-func" =>
      @validate.gen_invalid_require_defined_func_gen_valid_config(config)
    "memory-data" =>
      @validate.gen_invalid_require_memory_data_gen_valid_config(config)
    _ => config
  }
}

///|
pub fn gen_invalid_binary_seed_config(
  params : GenInvalidBinaryParams,
) -> GenValidConfig {
  if !params.require_strategy_prereqs {
    return params.generator_config
  }
  let mut config = params.generator_config
  match
    validate_invalid_binary_strategy_by_stable_id(
      validate_invalid_binary_strategy_label(params.strategy),
    ) {
    Some(spec) =>
      for prerequisite in spec.seed_prerequisites {
        config = gen_invalid_binary_apply_seed_prerequisite(
          config, prerequisite,
        )
      }
    None => ()
  }
  config
}

///|
fn validate_invalid_binary_strategy_spec(
  id : ValidateInvalidBinaryStrategyId,
  stable_id : String,
  display_name : String,
  expected_result : ValidateInvalidBinaryExpectedResult,
  required_in_smoke? : Bool = true,
  seed_prerequisites? : Array[String] = [],
) -> ValidateInvalidBinaryStrategySpec {
  let expected_issue_kind = match expected_result {
    DecodeRejected => None
    ValidateRejected(label) => Some(label)
  }
  {
    id,
    stable_id,
    variant_id: "default",
    display_name,
    layer: "binary",
    expected_result,
    expected_issue_kind,
    required_in_smoke,
    seed_prerequisites,
  }
}

///|
pub fn validate_invalid_binary_registry() -> Array[
  ValidateInvalidBinaryStrategySpec,
] {
  [
    validate_invalid_binary_strategy_spec(
      TrailingGarbage,
      "trailing-garbage",
      "trailing garbage after a valid module",
      DecodeRejected,
    ),
    validate_invalid_binary_strategy_spec(
      TruncatedModule,
      "truncated-module",
      "truncated valid module bytes",
      DecodeRejected,
    ),
    validate_invalid_binary_strategy_spec(
      DuplicateTypeSection,
      "duplicate-type-section",
      "duplicate type section after a valid module",
      DecodeRejected,
    ),
    validate_invalid_binary_strategy_spec(
      WrongSectionOrder,
      "wrong-section-order",
      "wrong section order",
      DecodeRejected,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidFuncTypeIndex,
      "invalid-func-type-index",
      "function section type index out of range",
      ValidateRejected("function"),
      seed_prerequisites=["defined-func"],
    ),
    validate_invalid_binary_strategy_spec(
      InvalidStartSignatureModule,
      "invalid-start-signature-module",
      "encoded module with invalid start signature",
      ValidateRejected("start"),
      seed_prerequisites=["defined-func"],
    ),
    validate_invalid_binary_strategy_spec(
      InvalidImportedStartFuncParamModule,
      "invalid-imported-start-func-param-module",
      "encoded module with invalid imported start-function parameter list",
      ValidateRejected("start"),
    ),
    validate_invalid_binary_strategy_spec(
      InvalidImportedStartFuncResultModule,
      "invalid-imported-start-func-result-module",
      "encoded module with invalid imported start-function result list",
      ValidateRejected("start"),
    ),
    validate_invalid_binary_strategy_spec(
      InvalidImportedStartFuncParamResultModule,
      "invalid-imported-start-func-param-result-module",
      "encoded module with invalid imported start-function parameter and result list",
      ValidateRejected("start"),
    ),
    validate_invalid_binary_strategy_spec(
      InvalidImportedStartFuncMultiParamModule,
      "invalid-imported-start-func-multi-param-module",
      "encoded module with invalid imported multi-parameter start function",
      ValidateRejected("start"),
    ),
    validate_invalid_binary_strategy_spec(
      InvalidImportedStartFuncF32ParamModule,
      "invalid-imported-start-func-f32-param-module",
      "encoded module with invalid imported f32-parameter start function",
      ValidateRejected("start"),
    ),
    validate_invalid_binary_strategy_spec(
      InvalidImportedStartFuncExternrefParamModule,
      "invalid-imported-start-func-externref-param-module",
      "encoded module with invalid imported externref-parameter start function",
      ValidateRejected("start"),
    ),
    validate_invalid_binary_strategy_spec(
      InvalidImportedStartFuncFuncrefParamModule,
      "invalid-imported-start-func-funcref-param-module",
      "encoded module with invalid imported funcref-parameter start function",
      ValidateRejected("start"),
    ),
    validate_invalid_binary_strategy_spec(
      DuplicateExportNameModule,
      "duplicate-export-name-module",
      "encoded module with duplicate export names",
      ValidateRejected("export"),
    ),
    validate_invalid_binary_strategy_spec(
      FuncSecWithoutCodeSecModule,
      "funcsec-without-codesec-module",
      "encoded module with function section but no code section",
      ValidateRejected("code"),
      seed_prerequisites=["defined-func"],
    ),
    validate_invalid_binary_strategy_spec(
      DataCountWithoutDataSecModule,
      "datacount-without-data-sec-module",
      "encoded module with datacount but no data section",
      ValidateRejected("datacount"),
    ),
    validate_invalid_binary_strategy_spec(
      InvalidNameSectionFuncIndexModule,
      "invalid-name-section-func-index-module",
      "encoded module with out-of-range function name index",
      ValidateRejected("name"),
    ),
    validate_invalid_binary_strategy_spec(
      InvalidLocalNameSectionIndexModule,
      "invalid-local-name-section-index-module",
      "encoded module with out-of-range local name index",
      ValidateRejected("name"),
    ),
    validate_invalid_binary_strategy_spec(
      InvalidLabelNameSectionIndexModule,
      "invalid-label-name-section-index-module",
      "encoded module with out-of-range label name index",
      ValidateRejected("name"),
    ),
    validate_invalid_binary_strategy_spec(
      BadMagicHeader,
      "bad-magic-header",
      "bad wasm magic header",
      DecodeRejected,
    ),
    validate_invalid_binary_strategy_spec(
      BadVersionHeader,
      "bad-version-header",
      "bad wasm version header",
      DecodeRejected,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedSectionSizeUleb,
      "malformed-section-size-uleb",
      "section size with a malformed uleb encoding",
      DecodeRejected,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideSectionSizeUleb,
      "overwide-section-size-uleb",
      "section size whose ULEB exceeds the u32 byte budget",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      SectionPayloadLengthOverflow,
      "section-payload-length-overflow",
      "section payload length that exceeds the module bytes",
      DecodeRejected,
    ),
    validate_invalid_binary_strategy_spec(
      SectionPayloadLengthUnderflow,
      "section-payload-length-underflow",
      "section payload length that ends before the section payload bytes",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      CodeSecWithoutFuncSecModule,
      "codesec-without-funcsec-module",
      "encoded module with code section but no function section",
      ValidateRejected("code"),
    ),
    validate_invalid_binary_strategy_spec(
      InvalidTableNameSectionIndexModule,
      "invalid-table-name-section-index-module",
      "encoded module with out-of-range table name index",
      ValidateRejected("name"),
    ),
    validate_invalid_binary_strategy_spec(
      InvalidGlobalNameSectionIndexModule,
      "invalid-global-name-section-index-module",
      "encoded module with out-of-range global name index",
      ValidateRejected("name"),
    ),
    validate_invalid_binary_strategy_spec(
      ReservedSectionId,
      "reserved-section-id",
      "reserved wasm section id",
      DecodeRejected,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidCustomSectionNameUtf8,
      "invalid-custom-section-name-utf8",
      "custom section with invalid utf8 name",
      DecodeRejected,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidTypeNameSectionIndexModule,
      "invalid-type-name-section-index-module",
      "encoded module with out-of-range type name index",
      ValidateRejected("name"),
    ),
    validate_invalid_binary_strategy_spec(
      InvalidFieldNameSectionIndexModule,
      "invalid-field-name-section-index-module",
      "encoded module with out-of-range field name index",
      ValidateRejected("name"),
    ),
    validate_invalid_binary_strategy_spec(
      InvalidElemNameSectionIndexModule,
      "invalid-elem-name-section-index-module",
      "encoded module with out-of-range elem name index",
      ValidateRejected("name"),
    ),
    validate_invalid_binary_strategy_spec(
      InvalidDataNameSectionIndexModule,
      "invalid-data-name-section-index-module",
      "encoded module with out-of-range data name index",
      ValidateRejected("name"),
    ),
    validate_invalid_binary_strategy_spec(
      InvalidExportTableIndexModule,
      "invalid-export-table-index-module",
      "encoded module with out-of-range table export index",
      ValidateRejected("export"),
    ),
    validate_invalid_binary_strategy_spec(
      InvalidExportGlobalIndexModule,
      "invalid-export-global-index-module",
      "encoded module with out-of-range global export index",
      ValidateRejected("export"),
    ),
    validate_invalid_binary_strategy_spec(
      InvalidExportMemoryIndexModule,
      "invalid-export-memory-index-module",
      "encoded module with out-of-range memory export index",
      ValidateRejected("export"),
    ),
    validate_invalid_binary_strategy_spec(
      InvalidExportTagIndexModule,
      "invalid-export-tag-index-module",
      "encoded module with out-of-range tag export index",
      ValidateRejected("export"),
    ),
    validate_invalid_binary_strategy_spec(
      InvalidTagNameSectionIndexModule,
      "invalid-tag-name-section-index-module",
      "encoded module with out-of-range tag name index",
      ValidateRejected("name"),
    ),
    validate_invalid_binary_strategy_spec(
      InvalidImportedTagTypeIndexModule,
      "invalid-imported-tag-type-index-module",
      "encoded module with out-of-range imported tag type index",
      ValidateRejected("import"),
    ),
    validate_invalid_binary_strategy_spec(
      DataCountMismatchTooSmallModule,
      "datacount-mismatch-too-small-module",
      "encoded module with datacount smaller than data segment count",
      ValidateRejected("datacount"),
    ),
    validate_invalid_binary_strategy_spec(
      DataCountMismatchTooLargeModule,
      "datacount-mismatch-too-large-module",
      "encoded module with datacount larger than data segment count",
      ValidateRejected("datacount"),
    ),
    validate_invalid_binary_strategy_spec(
      InvalidBinaryBodyLocalSetValueTypeModule,
      "invalid-binary-body-local-set-value-type-module",
      "encoded module with a local.set body stack type mismatch",
      ValidateRejected("function-body"),
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidBinaryBranchPayloadTypeModule,
      "invalid-binary-branch-payload-type-module",
      "encoded module with a branch payload stack type mismatch",
      ValidateRejected("function-body"),
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidBinaryLocalIndexModule,
      "invalid-binary-local-index-module",
      "encoded module with an out-of-range function-body local index",
      ValidateRejected("function-body"),
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidBinaryCallRefTypeModule,
      "invalid-binary-call-ref-type-module",
      "encoded module with a call_ref reference-operand type mismatch",
      ValidateRejected("function-body"),
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidBinaryStructGetFieldIndexModule,
      "invalid-binary-struct-get-field-index-module",
      "encoded module with an out-of-range struct.get field index",
      ValidateRejected("function-body"),
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidBinaryThrowPayloadModule,
      "invalid-binary-throw-payload-module",
      "encoded module with a throw payload stack type mismatch",
      ValidateRejected("function-body"),
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidBinarySharedMemoryWithoutMaxModule,
      "invalid-binary-shared-memory-without-max-module",
      "encoded module with shared memory missing its required maximum",
      ValidateRejected("memory"),
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidBinaryMemory64AddressTypeModule,
      "invalid-binary-memory64-address-type-module",
      "encoded module with a memory64 load address stack type mismatch",
      ValidateRejected("function-body"),
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      DuplicateImportSection,
      "duplicate-import-section",
      "duplicate import section after a valid module",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      DuplicateExportSection,
      "duplicate-export-section",
      "duplicate export section after a valid module",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      DuplicateTableSection,
      "duplicate-table-section",
      "duplicate table section after a valid module",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      DuplicateMemorySection,
      "duplicate-memory-section",
      "duplicate memory section after a valid module",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      DuplicateGlobalSection,
      "duplicate-global-section",
      "duplicate global section after a valid module",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      DuplicateFunctionSection,
      "duplicate-function-section",
      "duplicate function section after a valid module",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      DuplicateCodeSection,
      "duplicate-code-section",
      "duplicate code section after a valid module",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      DuplicateElementSection,
      "duplicate-element-section",
      "duplicate element section after a valid module",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      DuplicateDataSection,
      "duplicate-data-section",
      "duplicate data section after a valid module",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      DuplicateTagSection,
      "duplicate-tag-section",
      "duplicate tag section after a valid module",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      DuplicateStartSection,
      "duplicate-start-section",
      "two start sections appended to a valid module",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedSimdImmediate,
      "malformed-simd-immediate",
      "SIMD opcode with malformed immediate encoding",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      SimdLaneIndexOverflow,
      "simd-lane-index-overflow",
      "SIMD lane instruction with out-of-range lane index",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedCustomSectionPayload,
      "malformed-custom-section-payload",
      "custom section whose declared name length exceeds its payload",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedCustomSectionNameLengthUleb,
      "malformed-custom-section-name-length-uleb",
      "custom section with malformed name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideCustomSectionNameLengthUleb,
      "overwide-custom-section-name-length-uleb",
      "custom section with overwide name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedNameSubsectionSizeUleb,
      "malformed-name-subsection-size-uleb",
      "name section with malformed subsection-size ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideNameSubsectionSizeUleb,
      "overwide-name-subsection-size-uleb",
      "name section with overwide subsection-size ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidNameSubsectionIdByte,
      "invalid-name-subsection-id-byte",
      "name section with an invalid subsection id byte",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OutOfOrderNameSubsectionId,
      "out-of-order-name-subsection-id",
      "name section with out-of-order subsection ids",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidOpcodeByte,
      "invalid-opcode-byte",
      "function body with an invalid core opcode byte",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidPrefixSubopcodeByte,
      "invalid-prefix-subopcode-byte",
      "function body with an invalid prefixed subopcode byte sequence",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidGcPrefixSubopcodeByte,
      "invalid-gc-prefix-subopcode-byte",
      "GC-prefixed instruction with a reserved subopcode byte",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidBulkPrefixSubopcodeByte,
      "invalid-bulk-prefix-subopcode-byte",
      "bulk/table-prefixed instruction with a reserved subopcode byte",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidSimdPrefixSubopcodeByte,
      "invalid-simd-prefix-subopcode-byte",
      "SIMD-prefixed instruction with a reserved subopcode byte",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedGcPrefixSubopcodeUleb,
      "malformed-gc-prefix-subopcode-uleb",
      "GC-prefixed instruction with a malformed subopcode ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedBulkPrefixSubopcodeUleb,
      "malformed-bulk-prefix-subopcode-uleb",
      "bulk/table-prefixed instruction with a malformed subopcode ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedSimdPrefixSubopcodeUleb,
      "malformed-simd-prefix-subopcode-uleb",
      "SIMD-prefixed instruction with a malformed subopcode ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedAtomicPrefixSubopcodeUleb,
      "malformed-atomic-prefix-subopcode-uleb",
      "atomics-prefixed instruction with a malformed subopcode ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidAtomicPrefixSubopcodeByte,
      "invalid-atomic-prefix-subopcode-byte",
      "atomics-prefixed instruction with a reserved subopcode byte",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideGcPrefixSubopcodeUleb,
      "overwide-gc-prefix-subopcode-uleb",
      "GC-prefixed instruction with an overwide subopcode ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideBulkPrefixSubopcodeUleb,
      "overwide-bulk-prefix-subopcode-uleb",
      "bulk/table-prefixed instruction with an overwide subopcode ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideSimdPrefixSubopcodeUleb,
      "overwide-simd-prefix-subopcode-uleb",
      "SIMD-prefixed instruction with an overwide subopcode ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideAtomicPrefixSubopcodeUleb,
      "overwide-atomic-prefix-subopcode-uleb",
      "atomics-prefixed instruction with an overwide subopcode ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedAtomicLoadMemargAlignUleb,
      "malformed-atomic-load-memarg-align-uleb",
      "atomic load instruction with a malformed memarg alignment encoding",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedAtomicStoreMemargAlignUleb,
      "malformed-atomic-store-memarg-align-uleb",
      "atomic store instruction with a malformed memarg alignment encoding",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedAtomicLoadMemargOffsetUleb,
      "malformed-atomic-load-memarg-offset-uleb",
      "atomic load instruction with a malformed memarg offset encoding",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedAtomicStoreMemargOffsetUleb,
      "malformed-atomic-store-memarg-offset-uleb",
      "atomic store instruction with a malformed memarg offset encoding",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedAtomicNotifyMemargAlignUleb,
      "malformed-atomic-notify-memarg-align-uleb",
      "atomic notify instruction with a malformed memarg alignment encoding",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedAtomicNotifyMemargOffsetUleb,
      "malformed-atomic-notify-memarg-offset-uleb",
      "atomic notify instruction with a malformed memarg offset encoding",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedAtomicWaitMemargAlignUleb,
      "malformed-atomic-wait-memarg-align-uleb",
      "atomic wait instruction with a malformed memarg alignment encoding",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedAtomicWaitMemargOffsetUleb,
      "malformed-atomic-wait-memarg-offset-uleb",
      "atomic wait instruction with a malformed memarg offset encoding",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedAtomicRmwMemargAlignUleb,
      "malformed-atomic-rmw-memarg-align-uleb",
      "atomic RMW instruction with a malformed memarg alignment encoding",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedAtomicRmwMemargOffsetUleb,
      "malformed-atomic-rmw-memarg-offset-uleb",
      "atomic RMW instruction with a malformed memarg offset encoding",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedAtomicCmpxchgMemargAlignUleb,
      "malformed-atomic-cmpxchg-memarg-align-uleb",
      "atomic cmpxchg instruction with a malformed memarg alignment encoding",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedAtomicCmpxchgMemargOffsetUleb,
      "malformed-atomic-cmpxchg-memarg-offset-uleb",
      "atomic cmpxchg instruction with a malformed memarg offset encoding",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideAtomicLoadMemargAlignUleb,
      "overwide-atomic-load-memarg-align-uleb",
      "atomic load instruction with an overwide memarg alignment ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideAtomicStoreMemargAlignUleb,
      "overwide-atomic-store-memarg-align-uleb",
      "atomic store instruction with an overwide memarg alignment ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideAtomicLoadMemargOffsetUleb,
      "overwide-atomic-load-memarg-offset-uleb",
      "atomic load instruction with an overwide memarg offset ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideAtomicStoreMemargOffsetUleb,
      "overwide-atomic-store-memarg-offset-uleb",
      "atomic store instruction with an overwide memarg offset ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideAtomicNotifyMemargAlignUleb,
      "overwide-atomic-notify-memarg-align-uleb",
      "atomic notify instruction with an overwide memarg alignment ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideAtomicNotifyMemargOffsetUleb,
      "overwide-atomic-notify-memarg-offset-uleb",
      "atomic notify instruction with an overwide memarg offset ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideAtomicWaitMemargAlignUleb,
      "overwide-atomic-wait-memarg-align-uleb",
      "atomic wait instruction with an overwide memarg alignment ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideAtomicWaitMemargOffsetUleb,
      "overwide-atomic-wait-memarg-offset-uleb",
      "atomic wait instruction with an overwide memarg offset ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideAtomicRmwMemargAlignUleb,
      "overwide-atomic-rmw-memarg-align-uleb",
      "atomic RMW instruction with an overwide memarg alignment ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideAtomicRmwMemargOffsetUleb,
      "overwide-atomic-rmw-memarg-offset-uleb",
      "atomic RMW instruction with an overwide memarg offset ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideAtomicCmpxchgMemargAlignUleb,
      "overwide-atomic-cmpxchg-memarg-align-uleb",
      "atomic cmpxchg instruction with an overwide memarg alignment ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideAtomicCmpxchgMemargOffsetUleb,
      "overwide-atomic-cmpxchg-memarg-offset-uleb",
      "atomic cmpxchg instruction with an overwide memarg offset ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedMemargImmediate,
      "malformed-memarg-immediate",
      "memory instruction with a malformed memarg alignment encoding",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedLoadMemargAlignUleb,
      "malformed-load-memarg-align-uleb",
      "memory load instruction with a malformed memarg alignment ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedStoreMemargAlignUleb,
      "malformed-store-memarg-align-uleb",
      "memory store instruction with a malformed memarg alignment ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedLoadMemargOffsetUleb,
      "malformed-load-memarg-offset-uleb",
      "memory load instruction with a malformed memarg offset ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedStoreMemargOffsetUleb,
      "malformed-store-memarg-offset-uleb",
      "memory store instruction with a malformed memarg offset ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideLoadMemargAlignUleb,
      "overwide-load-memarg-align-uleb",
      "memory load instruction with an overwide memarg alignment ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideStoreMemargAlignUleb,
      "overwide-store-memarg-align-uleb",
      "memory store instruction with an overwide memarg alignment ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideLoadMemargOffsetUleb,
      "overwide-load-memarg-offset-uleb",
      "memory load instruction with an overwide memarg offset ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideStoreMemargOffsetUleb,
      "overwide-store-memarg-offset-uleb",
      "memory store instruction with an overwide memarg offset ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedBlocktypeImmediate,
      "malformed-blocktype-immediate",
      "block instruction with a malformed blocktype encoding",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidBlocktypeValTypeByte,
      "invalid-blocktype-valtype-byte",
      "block instruction with an invalid blocktype value-type byte",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideBlocktypeTypeIndexUleb,
      "overwide-blocktype-type-index-uleb",
      "block instruction with an overwide blocktype type-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedMemoryMinUleb,
      "malformed-memory-min-uleb",
      "memory section limits with a malformed minimum-size ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedTableMinUleb,
      "malformed-table-min-uleb",
      "table section limits with a malformed minimum-size ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedMemoryMaxUleb,
      "malformed-memory-max-uleb",
      "memory section limits with a malformed maximum-size ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedTableMaxUleb,
      "malformed-table-max-uleb",
      "table section limits with a malformed maximum-size ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideMemoryMinUleb,
      "overwide-memory-min-uleb",
      "memory section limits with an overwide minimum-size ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideTableMinUleb,
      "overwide-table-min-uleb",
      "table section limits with an overwide minimum-size ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideMemoryMaxUleb,
      "overwide-memory-max-uleb",
      "memory section limits with an overwide maximum-size ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideTableMaxUleb,
      "overwide-table-max-uleb",
      "table section limits with an overwide maximum-size ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidExportNameUtf8,
      "invalid-export-name-utf8",
      "export section with an invalid UTF-8 export name",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedExportNameLengthUleb,
      "malformed-export-name-length-uleb",
      "export section with a malformed export name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideExportNameLengthUleb,
      "overwide-export-name-length-uleb",
      "export section with an overwide export name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidImportModuleNameUtf8,
      "invalid-import-module-name-utf8",
      "import section with an invalid UTF-8 module name",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedImportModuleNameLengthUleb,
      "malformed-import-module-name-length-uleb",
      "import section with a malformed module name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideImportModuleNameLengthUleb,
      "overwide-import-module-name-length-uleb",
      "import section with an overwide module name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidImportFieldNameUtf8,
      "invalid-import-field-name-utf8",
      "import section with an invalid UTF-8 field name",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedImportFieldNameLengthUleb,
      "malformed-import-field-name-length-uleb",
      "import section with a malformed field name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideImportFieldNameLengthUleb,
      "overwide-import-field-name-length-uleb",
      "import section with an overwide field name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidImportKindByte,
      "invalid-import-kind-byte",
      "import section with an invalid import kind byte",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedFunctionSectionTypeIndexUleb,
      "malformed-function-section-type-index-uleb",
      "function section entry with a malformed type-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideFunctionSectionTypeIndexUleb,
      "overwide-function-section-type-index-uleb",
      "function section entry with an overwide type-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedImportFuncTypeIndexUleb,
      "malformed-import-func-type-index-uleb",
      "function import descriptor with a malformed type-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideImportFuncTypeIndexUleb,
      "overwide-import-func-type-index-uleb",
      "function import descriptor with an overwide type-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedImportTagTypeIndexUleb,
      "malformed-import-tag-type-index-uleb",
      "tag import descriptor with a malformed type-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideImportTagTypeIndexUleb,
      "overwide-import-tag-type-index-uleb",
      "tag import descriptor with an overwide type-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedImportMemoryMinUleb,
      "malformed-import-memory-min-uleb",
      "memory import descriptor limits with a malformed minimum-size ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedImportTableMinUleb,
      "malformed-import-table-min-uleb",
      "table import descriptor limits with a malformed minimum-size ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedImportMemoryMaxUleb,
      "malformed-import-memory-max-uleb",
      "memory import descriptor limits with a malformed maximum-size ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedImportTableMaxUleb,
      "malformed-import-table-max-uleb",
      "table import descriptor limits with a malformed maximum-size ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideImportMemoryMinUleb,
      "overwide-import-memory-min-uleb",
      "memory import descriptor limits with an overwide minimum-size ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideImportTableMinUleb,
      "overwide-import-table-min-uleb",
      "table import descriptor limits with an overwide minimum-size ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideImportMemoryMaxUleb,
      "overwide-import-memory-max-uleb",
      "memory import descriptor limits with an overwide maximum-size ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideImportTableMaxUleb,
      "overwide-import-table-max-uleb",
      "table import descriptor limits with an overwide maximum-size ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidImportTableRefTypeByte,
      "invalid-import-table-reftype-byte",
      "table import descriptor with an invalid reference type byte",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidImportMemoryLimitsFlagByte,
      "invalid-import-memory-limits-flag-byte",
      "memory import descriptor with an invalid limits flag byte",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidImportGlobalValTypeByte,
      "invalid-import-global-valtype-byte",
      "global import descriptor with an invalid value type byte",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidImportGlobalMutabilityByte,
      "invalid-import-global-mutability-byte",
      "global import descriptor with an invalid mutability byte",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidImportTagAttributeByte,
      "invalid-import-tag-attribute-byte",
      "tag import descriptor with an invalid attribute byte",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidTableRefTypeByte,
      "invalid-table-reftype-byte",
      "table section with an invalid reference type byte",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidTableLimitsFlagByte,
      "invalid-table-limits-flag-byte",
      "table section with an invalid limits flag byte",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedRefNullHeaptypeImmediate,
      "malformed-ref-null-heaptype-immediate",
      "ref.null instruction with a malformed heaptype immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedRefCastHeaptypeImmediate,
      "malformed-ref-cast-heaptype-immediate",
      "ref.cast instruction with a malformed heaptype immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedRefTestHeaptypeImmediate,
      "malformed-ref-test-heaptype-immediate",
      "ref.test instruction with a malformed heaptype immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideRefNullHeaptypeImmediate,
      "overwide-ref-null-heaptype-immediate",
      "ref.null instruction with an overwide heaptype immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideRefCastHeaptypeImmediate,
      "overwide-ref-cast-heaptype-immediate",
      "ref.cast instruction with an overwide heaptype immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideRefTestHeaptypeImmediate,
      "overwide-ref-test-heaptype-immediate",
      "ref.test instruction with an overwide heaptype immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidGlobalValTypeByte,
      "invalid-global-valtype-byte",
      "global section with an invalid value type byte",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidExportKindByte,
      "invalid-export-kind-byte",
      "export section with an invalid export kind byte",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidMemoryLimitsFlagByte,
      "invalid-memory-limits-flag-byte",
      "memory section with an invalid limits flag byte",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidTagAttributeByte,
      "invalid-tag-attribute-byte",
      "tag section with an invalid attribute byte",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidGlobalMutabilityByte,
      "invalid-global-mutability-byte",
      "global section with an invalid mutability byte",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedExportFuncIndexUleb,
      "malformed-export-func-index-uleb",
      "function export descriptor with a malformed function-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedExportTableIndexUleb,
      "malformed-export-table-index-uleb",
      "table export descriptor with a malformed table-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedExportMemoryIndexUleb,
      "malformed-export-memory-index-uleb",
      "memory export descriptor with a malformed memory-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedExportGlobalIndexUleb,
      "malformed-export-global-index-uleb",
      "global export descriptor with a malformed global-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedExportTagIndexUleb,
      "malformed-export-tag-index-uleb",
      "tag export descriptor with a malformed tag-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideExportFuncIndexUleb,
      "overwide-export-func-index-uleb",
      "function export descriptor with an overwide function-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideExportTableIndexUleb,
      "overwide-export-table-index-uleb",
      "table export descriptor with an overwide table-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideExportMemoryIndexUleb,
      "overwide-export-memory-index-uleb",
      "memory export descriptor with an overwide memory-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideExportGlobalIndexUleb,
      "overwide-export-global-index-uleb",
      "global export descriptor with an overwide global-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideExportTagIndexUleb,
      "overwide-export-tag-index-uleb",
      "tag export descriptor with an overwide tag-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidElementSegmentFlagByte,
      "invalid-element-segment-flag-byte",
      "element section with an invalid segment flag byte",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidElementKindByte,
      "invalid-element-kind-byte",
      "element section passive/declarative segment with an invalid elemkind byte",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidDataSegmentFlagByte,
      "invalid-data-segment-flag-byte",
      "data section with an invalid segment flag byte",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      TypeSectionCountOverflow,
      "type-section-count-overflow",
      "type section whose vector count exceeds its payload entries",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      CodeSectionCountOverflow,
      "code-section-count-overflow",
      "code section whose vector count exceeds its payload bodies",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      TableSectionCountOverflow,
      "table-section-count-overflow",
      "table section whose vector count exceeds its payload tables",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      ExportSectionCountOverflow,
      "export-section-count-overflow",
      "export section whose vector count exceeds its payload exports",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      ImportSectionCountOverflow,
      "import-section-count-overflow",
      "import section whose vector count exceeds its payload imports",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      GlobalSectionCountOverflow,
      "global-section-count-overflow",
      "global section whose vector count exceeds its payload globals",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      FunctionSectionCountOverflow,
      "function-section-count-overflow",
      "function section whose vector count exceeds its payload type indices",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MemorySectionCountOverflow,
      "memory-section-count-overflow",
      "memory section whose vector count exceeds its payload memories",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      ElementSectionCountOverflow,
      "element-section-count-overflow",
      "element section whose vector count exceeds its payload elements",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      DataSectionCountOverflow,
      "data-section-count-overflow",
      "data section whose vector count exceeds its payload data segments",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      TagSectionCountOverflow,
      "tag-section-count-overflow",
      "tag section whose vector count exceeds its payload tags",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedTagTypeIndexUleb,
      "malformed-tag-type-index-uleb",
      "tag section entry with a malformed type-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideTagTypeIndexUleb,
      "overwide-tag-type-index-uleb",
      "tag section entry with an overwide type-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedLocalIndexUleb,
      "malformed-local-index-uleb",
      "local.get instruction with a malformed local-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedLocalSetIndexUleb,
      "malformed-local-set-index-uleb",
      "local.set instruction with a malformed local-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedLocalTeeIndexUleb,
      "malformed-local-tee-index-uleb",
      "local.tee instruction with a malformed local-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideLocalIndexUleb,
      "overwide-local-index-uleb",
      "local.get instruction with an overwide local-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideLocalSetIndexUleb,
      "overwide-local-set-index-uleb",
      "local.set instruction with an overwide local-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideLocalTeeIndexUleb,
      "overwide-local-tee-index-uleb",
      "local.tee instruction with an overwide local-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedGlobalIndexUleb,
      "malformed-global-index-uleb",
      "global.get instruction with a malformed global-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedGlobalSetIndexUleb,
      "malformed-global-set-index-uleb",
      "global.set instruction with a malformed global-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideGlobalIndexUleb,
      "overwide-global-index-uleb",
      "global.get instruction with an overwide global-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideGlobalSetIndexUleb,
      "overwide-global-set-index-uleb",
      "global.set instruction with an overwide global-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedI32ConstSleb,
      "malformed-i32-const-sleb",
      "i32.const instruction with a malformed signed LEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedI64ConstSleb,
      "malformed-i64-const-sleb",
      "i64.const instruction with a malformed signed LEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideI32ConstSleb,
      "overwide-i32-const-sleb",
      "i32.const instruction with an overwide signed LEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideI64ConstSleb,
      "overwide-i64-const-sleb",
      "i64.const instruction with an overwide signed LEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedF32ConstImmediate,
      "malformed-f32-const-immediate",
      "f32.const instruction with a truncated fixed-width immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedF64ConstImmediate,
      "malformed-f64-const-immediate",
      "f64.const instruction with a truncated fixed-width immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedCallFuncIndexUleb,
      "malformed-call-func-index-uleb",
      "call instruction with a malformed function-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedReturnCallFuncIndexUleb,
      "malformed-return-call-func-index-uleb",
      "return_call instruction with a malformed function-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedRefFuncIndexUleb,
      "malformed-ref-func-index-uleb",
      "ref.func instruction with a malformed function-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideCallFuncIndexUleb,
      "overwide-call-func-index-uleb",
      "call instruction with an overwide function-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideReturnCallFuncIndexUleb,
      "overwide-return-call-func-index-uleb",
      "return_call instruction with an overwide function-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideRefFuncIndexUleb,
      "overwide-ref-func-index-uleb",
      "ref.func instruction with an overwide function-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedCallIndirectTypeIndexUleb,
      "malformed-call-indirect-type-index-uleb",
      "call_indirect instruction with a malformed type-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedCallIndirectTableIndexUleb,
      "malformed-call-indirect-table-index-uleb",
      "call_indirect instruction with a malformed table-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedReturnCallIndirectTypeIndexUleb,
      "malformed-return-call-indirect-type-index-uleb",
      "return_call_indirect instruction with a malformed type-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedReturnCallIndirectTableIndexUleb,
      "malformed-return-call-indirect-table-index-uleb",
      "return_call_indirect instruction with a malformed table-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedCallRefTypeIndexUleb,
      "malformed-call-ref-type-index-uleb",
      "call_ref instruction with a malformed type-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedReturnCallRefTypeIndexUleb,
      "malformed-return-call-ref-type-index-uleb",
      "return_call_ref instruction with a malformed type-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideCallIndirectTypeIndexUleb,
      "overwide-call-indirect-type-index-uleb",
      "call_indirect instruction with an overwide type-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideCallIndirectTableIndexUleb,
      "overwide-call-indirect-table-index-uleb",
      "call_indirect instruction with an overwide table-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideReturnCallIndirectTypeIndexUleb,
      "overwide-return-call-indirect-type-index-uleb",
      "return_call_indirect instruction with an overwide type-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideReturnCallIndirectTableIndexUleb,
      "overwide-return-call-indirect-table-index-uleb",
      "return_call_indirect instruction with an overwide table-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideCallRefTypeIndexUleb,
      "overwide-call-ref-type-index-uleb",
      "call_ref instruction with an overwide type-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideReturnCallRefTypeIndexUleb,
      "overwide-return-call-ref-type-index-uleb",
      "return_call_ref instruction with an overwide type-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedThrowTagIndexUleb,
      "malformed-throw-tag-index-uleb",
      "throw instruction with a malformed tag-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedTryTableCatchCountUleb,
      "malformed-try-table-catch-count-uleb",
      "try_table instruction with a malformed catch-count ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedTryTableCatchTagIndexUleb,
      "malformed-try-table-catch-tag-index-uleb",
      "try_table catch instruction with a malformed tag-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedTryTableCatchLabelIndexUleb,
      "malformed-try-table-catch-label-index-uleb",
      "try_table catch instruction with a malformed label-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideThrowTagIndexUleb,
      "overwide-throw-tag-index-uleb",
      "throw instruction with an overwide tag-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideTryTableCatchCountUleb,
      "overwide-try-table-catch-count-uleb",
      "try_table instruction with an overwide catch-count ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideTryTableCatchTagIndexUleb,
      "overwide-try-table-catch-tag-index-uleb",
      "try_table catch instruction with an overwide tag-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideTryTableCatchLabelIndexUleb,
      "overwide-try-table-catch-label-index-uleb",
      "try_table catch instruction with an overwide label-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedStructNewTypeIndexUleb,
      "malformed-struct-new-type-index-uleb",
      "struct.new instruction with a malformed type-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedStructGetFieldIndexUleb,
      "malformed-struct-get-field-index-uleb",
      "struct.get instruction with a malformed field-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedArrayNewDataTypeIndexUleb,
      "malformed-array-new-data-type-index-uleb",
      "array.new_data instruction with a malformed type-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedArrayNewDataIndexUleb,
      "malformed-array-new-data-index-uleb",
      "array.new_data instruction with a malformed data-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedArrayNewElemTypeIndexUleb,
      "malformed-array-new-elem-type-index-uleb",
      "array.new_elem instruction with a malformed type-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedArrayNewElemElemIndexUleb,
      "malformed-array-new-elem-elem-index-uleb",
      "array.new_elem instruction with a malformed elem-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideStructNewTypeIndexUleb,
      "overwide-struct-new-type-index-uleb",
      "struct.new instruction with an overwide type-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideStructGetFieldIndexUleb,
      "overwide-struct-get-field-index-uleb",
      "struct.get instruction with an overwide field-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideArrayNewDataTypeIndexUleb,
      "overwide-array-new-data-type-index-uleb",
      "array.new_data instruction with an overwide type-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideArrayNewDataIndexUleb,
      "overwide-array-new-data-index-uleb",
      "array.new_data instruction with an overwide data-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideArrayNewElemTypeIndexUleb,
      "overwide-array-new-elem-type-index-uleb",
      "array.new_elem instruction with an overwide type-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideArrayNewElemElemIndexUleb,
      "overwide-array-new-elem-elem-index-uleb",
      "array.new_elem instruction with an overwide elem-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedBrLabelIndexUleb,
      "malformed-br-label-index-uleb",
      "br instruction with a malformed label-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedBrIfLabelIndexUleb,
      "malformed-br-if-label-index-uleb",
      "br_if instruction with a malformed label-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedBrTableTargetCountUleb,
      "malformed-br-table-target-count-uleb",
      "br_table instruction with a malformed target-count ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedBrTableTargetLabelIndexUleb,
      "malformed-br-table-target-label-index-uleb",
      "br_table instruction with a malformed target label-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedBrTableDefaultLabelIndexUleb,
      "malformed-br-table-default-label-index-uleb",
      "br_table instruction with a malformed default label-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideBrLabelIndexUleb,
      "overwide-br-label-index-uleb",
      "br instruction with an overwide label-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideBrIfLabelIndexUleb,
      "overwide-br-if-label-index-uleb",
      "br_if instruction with an overwide label-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideBrTableTargetCountUleb,
      "overwide-br-table-target-count-uleb",
      "br_table instruction with an overwide target-count ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideBrTableTargetLabelIndexUleb,
      "overwide-br-table-target-label-index-uleb",
      "br_table instruction with an overwide target label-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideBrTableDefaultLabelIndexUleb,
      "overwide-br-table-default-label-index-uleb",
      "br_table instruction with an overwide default label-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedTableIndexUleb,
      "malformed-table-index-uleb",
      "table.get instruction with a malformed table-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedTableSetIndexUleb,
      "malformed-table-set-index-uleb",
      "table.set instruction with a malformed table-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedTableSizeIndexUleb,
      "malformed-table-size-index-uleb",
      "table.size instruction with a malformed table-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedTableGrowIndexUleb,
      "malformed-table-grow-index-uleb",
      "table.grow instruction with a malformed table-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedTableFillIndexUleb,
      "malformed-table-fill-index-uleb",
      "table.fill instruction with a malformed table-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideTableIndexUleb,
      "overwide-table-index-uleb",
      "table.get instruction with an overwide table-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideTableSetIndexUleb,
      "overwide-table-set-index-uleb",
      "table.set instruction with an overwide table-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideTableSizeIndexUleb,
      "overwide-table-size-index-uleb",
      "table.size instruction with an overwide table-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideTableGrowIndexUleb,
      "overwide-table-grow-index-uleb",
      "table.grow instruction with an overwide table-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideTableFillIndexUleb,
      "overwide-table-fill-index-uleb",
      "table.fill instruction with an overwide table-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedMemorySizeMemoryIndexUleb,
      "malformed-memory-size-memory-index-uleb",
      "memory.size instruction with a malformed memory-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedMemoryGrowMemoryIndexUleb,
      "malformed-memory-grow-memory-index-uleb",
      "memory.grow instruction with a malformed memory-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedMemoryFillMemoryIndexUleb,
      "malformed-memory-fill-memory-index-uleb",
      "memory.fill instruction with a malformed memory-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideMemorySizeMemoryIndexUleb,
      "overwide-memory-size-memory-index-uleb",
      "memory.size instruction with an overwide memory-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideMemoryGrowMemoryIndexUleb,
      "overwide-memory-grow-memory-index-uleb",
      "memory.grow instruction with an overwide memory-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideMemoryFillMemoryIndexUleb,
      "overwide-memory-fill-memory-index-uleb",
      "memory.fill instruction with an overwide memory-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedMemoryCopyDstIndexUleb,
      "malformed-memory-copy-dst-index-uleb",
      "memory.copy instruction with a malformed destination memory-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedMemoryCopySrcIndexUleb,
      "malformed-memory-copy-src-index-uleb",
      "memory.copy instruction with a malformed source memory-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedTableCopyDstIndexUleb,
      "malformed-table-copy-dst-index-uleb",
      "table.copy instruction with a malformed destination table-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedTableCopySrcIndexUleb,
      "malformed-table-copy-src-index-uleb",
      "table.copy instruction with a malformed source table-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideMemoryCopyDstIndexUleb,
      "overwide-memory-copy-dst-index-uleb",
      "memory.copy instruction with an overwide destination memory-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideMemoryCopySrcIndexUleb,
      "overwide-memory-copy-src-index-uleb",
      "memory.copy instruction with an overwide source memory-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideTableCopyDstIndexUleb,
      "overwide-table-copy-dst-index-uleb",
      "table.copy instruction with an overwide destination table-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideTableCopySrcIndexUleb,
      "overwide-table-copy-src-index-uleb",
      "table.copy instruction with an overwide source table-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedSelectTypeCountUleb,
      "malformed-select-type-count-uleb",
      "typed select instruction with a malformed type-count ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideSelectTypeCountUleb,
      "overwide-select-type-count-uleb",
      "typed select instruction with an overwide type-count ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidTypedSelectValTypeByte,
      "invalid-typed-select-valtype-byte",
      "typed select instruction with an invalid valtype byte in its type vector",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedStartFuncIndexUleb,
      "malformed-start-func-index-uleb",
      "start section with a malformed function-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideStartFuncIndexUleb,
      "overwide-start-func-index-uleb",
      "start section with an overwide function-index ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedDataCountUleb,
      "malformed-datacount-uleb",
      "data count section with a malformed count ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideDataCountUleb,
      "overwide-datacount-uleb",
      "data count section with an overwide count ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      SimdShuffleLaneOverflow,
      "simd-shuffle-lane-overflow",
      "i8x16.shuffle instruction with an out-of-range lane immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      SimdLoadLaneIndexOverflow,
      "simd-load-lane-index-overflow",
      "SIMD lane load instruction with an out-of-range lane immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      SimdStoreLaneIndexOverflow,
      "simd-store-lane-index-overflow",
      "SIMD lane store instruction with an out-of-range lane immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      SimdExtractLaneIndexOverflow,
      "simd-extract-lane-index-overflow",
      "SIMD extract_lane instruction with an out-of-range lane immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      SimdReplaceLaneIndexOverflow,
      "simd-replace-lane-index-overflow",
      "SIMD replace_lane instruction with an out-of-range lane immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedSimdLoadMemargAlignUleb,
      "malformed-simd-load-memarg-align-uleb",
      "v128.load instruction with a malformed memarg alignment ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedSimdStoreMemargAlignUleb,
      "malformed-simd-store-memarg-align-uleb",
      "v128.store instruction with a malformed memarg alignment ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedSimdLoadMemargOffsetUleb,
      "malformed-simd-load-memarg-offset-uleb",
      "v128.load instruction with a malformed memarg offset ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedSimdStoreMemargOffsetUleb,
      "malformed-simd-store-memarg-offset-uleb",
      "v128.store instruction with a malformed memarg offset ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideSimdLoadMemargAlignUleb,
      "overwide-simd-load-memarg-align-uleb",
      "v128.load instruction with an overwide memarg alignment ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideSimdStoreMemargAlignUleb,
      "overwide-simd-store-memarg-align-uleb",
      "v128.store instruction with an overwide memarg alignment ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideSimdLoadMemargOffsetUleb,
      "overwide-simd-load-memarg-offset-uleb",
      "v128.load instruction with an overwide memarg offset ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideSimdStoreMemargOffsetUleb,
      "overwide-simd-store-memarg-offset-uleb",
      "v128.store instruction with an overwide memarg offset ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedSimdLoadLaneMemargAlignUleb,
      "malformed-simd-load-lane-memarg-align-uleb",
      "SIMD lane load instruction with a malformed memarg alignment ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedSimdStoreLaneMemargAlignUleb,
      "malformed-simd-store-lane-memarg-align-uleb",
      "SIMD lane store instruction with a malformed memarg alignment ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedSimdLoadLaneMemargOffsetUleb,
      "malformed-simd-load-lane-memarg-offset-uleb",
      "SIMD lane load instruction with a malformed memarg offset ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedSimdStoreLaneMemargOffsetUleb,
      "malformed-simd-store-lane-memarg-offset-uleb",
      "SIMD lane store instruction with a malformed memarg offset ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideSimdLoadLaneMemargAlignUleb,
      "overwide-simd-load-lane-memarg-align-uleb",
      "SIMD lane load instruction with an overwide memarg alignment ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideSimdStoreLaneMemargAlignUleb,
      "overwide-simd-store-lane-memarg-align-uleb",
      "SIMD lane store instruction with an overwide memarg alignment ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideSimdLoadLaneMemargOffsetUleb,
      "overwide-simd-load-lane-memarg-offset-uleb",
      "SIMD lane load instruction with an overwide memarg offset ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideSimdStoreLaneMemargOffsetUleb,
      "overwide-simd-store-lane-memarg-offset-uleb",
      "SIMD lane store instruction with an overwide memarg offset ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedSimdLoadSplatMemargAlignUleb,
      "malformed-simd-load-splat-memarg-align-uleb",
      "SIMD load splat instruction with a malformed memarg alignment ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedSimdLoadSplatMemargOffsetUleb,
      "malformed-simd-load-splat-memarg-offset-uleb",
      "SIMD load splat instruction with a malformed memarg offset ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideSimdLoadSplatMemargAlignUleb,
      "overwide-simd-load-splat-memarg-align-uleb",
      "SIMD load splat instruction with an overwide memarg alignment ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideSimdLoadSplatMemargOffsetUleb,
      "overwide-simd-load-splat-memarg-offset-uleb",
      "SIMD load splat instruction with an overwide memarg offset ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedSimdLoadExtendMemargAlignUleb,
      "malformed-simd-load-extend-memarg-align-uleb",
      "SIMD load-extend instruction with a malformed memarg alignment ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedSimdLoadExtendMemargOffsetUleb,
      "malformed-simd-load-extend-memarg-offset-uleb",
      "SIMD load-extend instruction with a malformed memarg offset ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideSimdLoadExtendMemargAlignUleb,
      "overwide-simd-load-extend-memarg-align-uleb",
      "SIMD load-extend instruction with an overwide memarg alignment ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideSimdLoadExtendMemargOffsetUleb,
      "overwide-simd-load-extend-memarg-offset-uleb",
      "SIMD load-extend instruction with an overwide memarg offset ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedSimdLoadZeroMemargAlignUleb,
      "malformed-simd-load-zero-memarg-align-uleb",
      "SIMD load-zero instruction with a malformed memarg alignment ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedSimdLoadZeroMemargOffsetUleb,
      "malformed-simd-load-zero-memarg-offset-uleb",
      "SIMD load-zero instruction with a malformed memarg offset ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideSimdLoadZeroMemargAlignUleb,
      "overwide-simd-load-zero-memarg-align-uleb",
      "SIMD load-zero instruction with an overwide memarg alignment ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideSimdLoadZeroMemargOffsetUleb,
      "overwide-simd-load-zero-memarg-offset-uleb",
      "SIMD load-zero instruction with an overwide memarg offset ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedDataIndexUleb,
      "malformed-data-index-uleb",
      "data.drop instruction with a malformed data-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideDataIndexUleb,
      "overwide-data-index-uleb",
      "data.drop instruction with an overwide data-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedDataSegmentByteCountUleb,
      "malformed-data-segment-byte-count-uleb",
      "data segment with a malformed byte-vector count ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideDataSegmentByteCountUleb,
      "overwide-data-segment-byte-count-uleb",
      "data segment with an overwide byte-vector count ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedMemoryInitDataIndexUleb,
      "malformed-memory-init-data-index-uleb",
      "memory.init instruction with a malformed data-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedMemoryInitMemoryIndexUleb,
      "malformed-memory-init-memory-index-uleb",
      "memory.init instruction with a malformed memory-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideMemoryInitDataIndexUleb,
      "overwide-memory-init-data-index-uleb",
      "memory.init instruction with an overwide data-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideMemoryInitMemoryIndexUleb,
      "overwide-memory-init-memory-index-uleb",
      "memory.init instruction with an overwide memory-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedElemIndexUleb,
      "malformed-elem-index-uleb",
      "elem.drop instruction with a malformed element-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideElemIndexUleb,
      "overwide-elem-index-uleb",
      "elem.drop instruction with an overwide element-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedTableInitElemIndexUleb,
      "malformed-table-init-elem-index-uleb",
      "table.init instruction with a malformed element-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedTableInitTableIndexUleb,
      "malformed-table-init-table-index-uleb",
      "table.init instruction with a malformed table-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideTableInitElemIndexUleb,
      "overwide-table-init-elem-index-uleb",
      "table.init instruction with an overwide element-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideTableInitTableIndexUleb,
      "overwide-table-init-table-index-uleb",
      "table.init instruction with an overwide table-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedDataSegmentMemoryIndexUleb,
      "malformed-data-segment-memory-index-uleb",
      "active data segment with a malformed memory-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideDataSegmentMemoryIndexUleb,
      "overwide-data-segment-memory-index-uleb",
      "active data segment with an overwide memory-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedElementSegmentTableIndexUleb,
      "malformed-element-segment-table-index-uleb",
      "active element segment with a malformed table-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedElementSegmentFuncIndexUleb,
      "malformed-element-segment-func-index-uleb",
      "element segment with a malformed function-index ULEB payload",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideElementSegmentTableIndexUleb,
      "overwide-element-segment-table-index-uleb",
      "active element segment with an overwide table-index ULEB immediate",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideElementSegmentFuncIndexUleb,
      "overwide-element-segment-func-index-uleb",
      "element segment with an overwide function-index ULEB payload",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidNameSectionFuncNameUtf8,
      "invalid-name-section-func-name-utf8",
      "name section function-name payload with invalid UTF-8",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedNameSectionFuncNameLengthUleb,
      "malformed-name-section-func-name-length-uleb",
      "name section function-name payload with a malformed name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideNameSectionFuncNameLengthUleb,
      "overwide-name-section-func-name-length-uleb",
      "name section function-name payload with an overwide name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedNameSectionFuncNameCountUleb,
      "malformed-name-section-func-name-count-uleb",
      "name section function-name map with a malformed count ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideNameSectionFuncNameCountUleb,
      "overwide-name-section-func-name-count-uleb",
      "name section function-name map with an overwide count ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidNameSectionLocalNameUtf8,
      "invalid-name-section-local-name-utf8",
      "name section local-name payload with invalid UTF-8",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedNameSectionLocalNameLengthUleb,
      "malformed-name-section-local-name-length-uleb",
      "name section local-name payload with a malformed name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideNameSectionLocalNameLengthUleb,
      "overwide-name-section-local-name-length-uleb",
      "name section local-name payload with an overwide name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedNameSectionLocalNameCountUleb,
      "malformed-name-section-local-name-count-uleb",
      "name section local-name map with a malformed local-name count ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideNameSectionLocalNameCountUleb,
      "overwide-name-section-local-name-count-uleb",
      "name section local-name map with an overwide local-name count ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidNameSectionModuleNameUtf8,
      "invalid-name-section-module-name-utf8",
      "name section module-name payload with invalid UTF-8",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedNameSectionModuleNameLengthUleb,
      "malformed-name-section-module-name-length-uleb",
      "name section module-name payload with a malformed name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideNameSectionModuleNameLengthUleb,
      "overwide-name-section-module-name-length-uleb",
      "name section module-name payload with an overwide name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidNameSectionTypeNameUtf8,
      "invalid-name-section-type-name-utf8",
      "name section type-name payload with invalid UTF-8",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedNameSectionTypeNameLengthUleb,
      "malformed-name-section-type-name-length-uleb",
      "name section type-name payload with a malformed name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideNameSectionTypeNameLengthUleb,
      "overwide-name-section-type-name-length-uleb",
      "name section type-name payload with an overwide name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedNameSectionTypeNameCountUleb,
      "malformed-name-section-type-name-count-uleb",
      "name section type-name map with a malformed count ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideNameSectionTypeNameCountUleb,
      "overwide-name-section-type-name-count-uleb",
      "name section type-name map with an overwide count ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidNameSectionTableNameUtf8,
      "invalid-name-section-table-name-utf8",
      "name section table-name payload with invalid UTF-8",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedNameSectionTableNameLengthUleb,
      "malformed-name-section-table-name-length-uleb",
      "name section table-name payload with a malformed name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideNameSectionTableNameLengthUleb,
      "overwide-name-section-table-name-length-uleb",
      "name section table-name payload with an overwide name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedNameSectionTableNameCountUleb,
      "malformed-name-section-table-name-count-uleb",
      "name section table-name map with a malformed count ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideNameSectionTableNameCountUleb,
      "overwide-name-section-table-name-count-uleb",
      "name section table-name map with an overwide count ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidNameSectionMemoryNameUtf8,
      "invalid-name-section-memory-name-utf8",
      "name section memory-name payload with invalid UTF-8",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedNameSectionMemoryNameLengthUleb,
      "malformed-name-section-memory-name-length-uleb",
      "name section memory-name payload with a malformed name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideNameSectionMemoryNameLengthUleb,
      "overwide-name-section-memory-name-length-uleb",
      "name section memory-name payload with an overwide name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedNameSectionMemoryNameCountUleb,
      "malformed-name-section-memory-name-count-uleb",
      "name section memory-name map with a malformed count ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideNameSectionMemoryNameCountUleb,
      "overwide-name-section-memory-name-count-uleb",
      "name section memory-name map with an overwide count ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidNameSectionGlobalNameUtf8,
      "invalid-name-section-global-name-utf8",
      "name section global-name payload with invalid UTF-8",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedNameSectionGlobalNameLengthUleb,
      "malformed-name-section-global-name-length-uleb",
      "name section global-name payload with a malformed name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideNameSectionGlobalNameLengthUleb,
      "overwide-name-section-global-name-length-uleb",
      "name section global-name payload with an overwide name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedNameSectionGlobalNameCountUleb,
      "malformed-name-section-global-name-count-uleb",
      "name section global-name map with a malformed count ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideNameSectionGlobalNameCountUleb,
      "overwide-name-section-global-name-count-uleb",
      "name section global-name map with an overwide count ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidNameSectionElemNameUtf8,
      "invalid-name-section-elem-name-utf8",
      "name section element segment name payload with invalid UTF-8",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedNameSectionElemNameLengthUleb,
      "malformed-name-section-elem-name-length-uleb",
      "name section element segment name payload with a malformed name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideNameSectionElemNameLengthUleb,
      "overwide-name-section-elem-name-length-uleb",
      "name section element segment name payload with an overwide name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedNameSectionElemNameCountUleb,
      "malformed-name-section-elem-name-count-uleb",
      "name section element segment name map with a malformed count ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideNameSectionElemNameCountUleb,
      "overwide-name-section-elem-name-count-uleb",
      "name section element segment name map with an overwide count ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidNameSectionDataNameUtf8,
      "invalid-name-section-data-name-utf8",
      "name section data segment name payload with invalid UTF-8",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedNameSectionDataNameLengthUleb,
      "malformed-name-section-data-name-length-uleb",
      "name section data segment name payload with a malformed name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideNameSectionDataNameLengthUleb,
      "overwide-name-section-data-name-length-uleb",
      "name section data segment name payload with an overwide name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidNameSectionFieldNameUtf8,
      "invalid-name-section-field-name-utf8",
      "name section field name payload with invalid UTF-8",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedNameSectionFieldNameLengthUleb,
      "malformed-name-section-field-name-length-uleb",
      "name section field name payload with a malformed name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideNameSectionFieldNameLengthUleb,
      "overwide-name-section-field-name-length-uleb",
      "name section field name payload with an overwide name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidNameSectionLabelNameUtf8,
      "invalid-name-section-label-name-utf8",
      "name section label name payload with invalid UTF-8",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedNameSectionLabelNameLengthUleb,
      "malformed-name-section-label-name-length-uleb",
      "name section label name payload with a malformed name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideNameSectionLabelNameLengthUleb,
      "overwide-name-section-label-name-length-uleb",
      "name section label name payload with an overwide name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidNameSectionTagNameUtf8,
      "invalid-name-section-tag-name-utf8",
      "name section tag-name payload with invalid UTF-8",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedNameSectionTagNameLengthUleb,
      "malformed-name-section-tag-name-length-uleb",
      "name section tag-name payload with a malformed name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideNameSectionTagNameLengthUleb,
      "overwide-name-section-tag-name-length-uleb",
      "name section tag-name payload with an overwide name-length ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidFuncTypeByte,
      "invalid-functype-byte",
      "type section entry with an invalid function-type byte",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedFuncTypeParamCountUleb,
      "malformed-functype-param-count-uleb",
      "type section function signature with a malformed parameter-count ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedFuncTypeResultCountUleb,
      "malformed-functype-result-count-uleb",
      "type section function signature with a malformed result-count ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideFuncTypeParamCountUleb,
      "overwide-functype-param-count-uleb",
      "type section function signature with an overwide parameter-count ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideFuncTypeResultCountUleb,
      "overwide-functype-result-count-uleb",
      "type section function signature with an overwide result-count ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidFuncTypeParamValTypeByte,
      "invalid-functype-param-valtype-byte",
      "type section function signature with an invalid parameter value-type byte",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidFuncTypeResultValTypeByte,
      "invalid-functype-result-valtype-byte",
      "type section function signature with an invalid result value-type byte",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      InvalidCodeLocalValTypeByte,
      "invalid-code-local-valtype-byte",
      "code section local declaration with an invalid value-type byte",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedCodeLocalDeclCountUleb,
      "malformed-code-local-decl-count-uleb",
      "code body with a malformed local declaration count ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedCodeLocalRunCountUleb,
      "malformed-code-local-run-count-uleb",
      "code body with a malformed local run-count ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideCodeLocalDeclCountUleb,
      "overwide-code-local-decl-count-uleb",
      "code body with an overwide local declaration count ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideCodeLocalRunCountUleb,
      "overwide-code-local-run-count-uleb",
      "code body with an overwide local run-count ULEB",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedTypeSectionCountUleb,
      "malformed-type-section-count-uleb",
      "type section whose vector-count ULEB is malformed",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedCodeSectionCountUleb,
      "malformed-code-section-count-uleb",
      "code section whose vector-count ULEB is malformed",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedImportSectionCountUleb,
      "malformed-import-section-count-uleb",
      "import section whose vector-count ULEB is malformed",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedExportSectionCountUleb,
      "malformed-export-section-count-uleb",
      "export section whose vector-count ULEB is malformed",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedTableSectionCountUleb,
      "malformed-table-section-count-uleb",
      "table section whose vector-count ULEB is malformed",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedMemorySectionCountUleb,
      "malformed-memory-section-count-uleb",
      "memory section whose vector-count ULEB is malformed",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedGlobalSectionCountUleb,
      "malformed-global-section-count-uleb",
      "global section whose vector-count ULEB is malformed",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedFunctionSectionCountUleb,
      "malformed-function-section-count-uleb",
      "function section whose vector-count ULEB is malformed",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedElementSectionCountUleb,
      "malformed-element-section-count-uleb",
      "element section whose vector-count ULEB is malformed",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedDataSectionCountUleb,
      "malformed-data-section-count-uleb",
      "data section whose vector-count ULEB is malformed",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedTagSectionCountUleb,
      "malformed-tag-section-count-uleb",
      "tag section whose vector-count ULEB is malformed",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideTypeSectionCountUleb,
      "overwide-type-section-count-uleb",
      "type section whose vector-count ULEB is overwide",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideCodeSectionCountUleb,
      "overwide-code-section-count-uleb",
      "code section whose vector-count ULEB is overwide",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideImportSectionCountUleb,
      "overwide-import-section-count-uleb",
      "import section whose vector-count ULEB is overwide",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideExportSectionCountUleb,
      "overwide-export-section-count-uleb",
      "export section whose vector-count ULEB is overwide",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideTableSectionCountUleb,
      "overwide-table-section-count-uleb",
      "table section whose vector-count ULEB is overwide",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideMemorySectionCountUleb,
      "overwide-memory-section-count-uleb",
      "memory section whose vector-count ULEB is overwide",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideGlobalSectionCountUleb,
      "overwide-global-section-count-uleb",
      "global section whose vector-count ULEB is overwide",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideFunctionSectionCountUleb,
      "overwide-function-section-count-uleb",
      "function section whose vector-count ULEB is overwide",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideElementSectionCountUleb,
      "overwide-element-section-count-uleb",
      "element section whose vector-count ULEB is overwide",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideDataSectionCountUleb,
      "overwide-data-section-count-uleb",
      "data section whose vector-count ULEB is overwide",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideTagSectionCountUleb,
      "overwide-tag-section-count-uleb",
      "tag section whose vector-count ULEB is overwide",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      TypeSectionCountUnderflow,
      "type-section-count-underflow",
      "type section whose vector count is smaller than its payload entries",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      CodeSectionCountUnderflow,
      "code-section-count-underflow",
      "code section whose vector count is smaller than its payload bodies",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      ImportSectionCountUnderflow,
      "import-section-count-underflow",
      "import section whose vector count is smaller than its payload imports",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      ExportSectionCountUnderflow,
      "export-section-count-underflow",
      "export section whose vector count is smaller than its payload exports",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      TableSectionCountUnderflow,
      "table-section-count-underflow",
      "table section whose vector count is smaller than its payload tables",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MemorySectionCountUnderflow,
      "memory-section-count-underflow",
      "memory section whose vector count is smaller than its payload memories",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      GlobalSectionCountUnderflow,
      "global-section-count-underflow",
      "global section whose vector count is smaller than its payload globals",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      FunctionSectionCountUnderflow,
      "function-section-count-underflow",
      "function section whose vector count is smaller than its payload type indices",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      ElementSectionCountUnderflow,
      "element-section-count-underflow",
      "element section whose vector count is smaller than its payload segments",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      DataSectionCountUnderflow,
      "data-section-count-underflow",
      "data section whose vector count is smaller than its payload segments",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      TagSectionCountUnderflow,
      "tag-section-count-underflow",
      "tag section whose vector count is smaller than its payload tags",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      TypeSectionSizeUnderflow,
      "type-section-size-underflow",
      "type section whose declared payload size ends inside a function type",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      CodeBodySizeUnderflow,
      "code-body-size-underflow",
      "code section body whose declared size ends before the function body terminator",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MalformedCodeBodySizeUleb,
      "malformed-code-body-size-uleb",
      "code section body whose declared size ULEB is malformed",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      OverwideCodeBodySizeUleb,
      "overwide-code-body-size-uleb",
      "code section body whose declared size ULEB exceeds the u32 byte budget",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      ImportSectionSizeUnderflow,
      "import-section-size-underflow",
      "import section whose declared payload size ends inside an import descriptor",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      ExportSectionSizeUnderflow,
      "export-section-size-underflow",
      "export section whose declared payload size ends inside an export descriptor",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      TableSectionSizeUnderflow,
      "table-section-size-underflow",
      "table section whose declared payload size ends inside a table limit",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MemorySectionSizeUnderflow,
      "memory-section-size-underflow",
      "memory section whose declared payload size ends inside a memory limit",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      GlobalSectionSizeUnderflow,
      "global-section-size-underflow",
      "global section whose declared payload size ends inside a global initializer",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      FunctionSectionSizeUnderflow,
      "function-section-size-underflow",
      "function section whose declared payload size ends before a type index",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      ElementSectionSizeUnderflow,
      "element-section-size-underflow",
      "element section whose declared payload size ends inside a segment descriptor",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      DataSectionSizeUnderflow,
      "data-section-size-underflow",
      "data section whose declared payload size ends inside a segment descriptor",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      TagSectionSizeUnderflow,
      "tag-section-size-underflow",
      "tag section whose declared payload size ends before a tag type index",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      TypeSectionSizeOverflow,
      "type-section-size-overflow",
      "type section whose declared payload size extends past the available payload bytes",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      CodeSectionSizeOverflow,
      "code-section-size-overflow",
      "code section whose declared payload size extends past the available payload bytes",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      ImportSectionSizeOverflow,
      "import-section-size-overflow",
      "import section whose declared payload size extends past the available payload bytes",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      ExportSectionSizeOverflow,
      "export-section-size-overflow",
      "export section whose declared payload size extends past the available payload bytes",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      TableSectionSizeOverflow,
      "table-section-size-overflow",
      "table section whose declared payload size extends past the available payload bytes",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      MemorySectionSizeOverflow,
      "memory-section-size-overflow",
      "memory section whose declared payload size extends past the available payload bytes",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      GlobalSectionSizeOverflow,
      "global-section-size-overflow",
      "global section whose declared payload size extends past the available payload bytes",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      FunctionSectionSizeOverflow,
      "function-section-size-overflow",
      "function section whose declared payload size extends past the available type-index bytes",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      ElementSectionSizeOverflow,
      "element-section-size-overflow",
      "element section whose declared payload size extends past the available segment bytes",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      DataSectionSizeOverflow,
      "data-section-size-overflow",
      "data section whose declared payload size extends past the available segment bytes",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      TagSectionSizeOverflow,
      "tag-section-size-overflow",
      "tag section whose declared payload size extends past the available tag bytes",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      StartSectionSizeUnderflow,
      "start-section-size-underflow",
      "start section whose declared payload size ends before its function index",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      DataCountSectionSizeUnderflow,
      "datacount-section-size-underflow",
      "datacount section whose declared payload size ends before its count",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      StartSectionSizeOverflow,
      "start-section-size-overflow",
      "start section whose declared payload size extends past the available function-index bytes",
      DecodeRejected,
      required_in_smoke=false,
    ),
    validate_invalid_binary_strategy_spec(
      DataCountSectionSizeOverflow,
      "datacount-section-size-overflow",
      "datacount section whose declared payload size extends past the available count bytes",
      DecodeRejected,
      required_in_smoke=false,
    ),
  ]
}

///|
pub fn validate_invalid_binary_strategy_by_stable_id(
  stable_id : String,
) -> ValidateInvalidBinaryStrategySpec? {
  for spec in validate_invalid_binary_registry() {
    if spec.stable_id == stable_id {
      return Some(spec)
    }
  }
  None
}

///|
fn validate_invalid_binary_strategy_index(
  id : ValidateInvalidBinaryStrategyId,
) -> Int {
  let registry = validate_invalid_binary_registry()
  let mut i = 0
  while i < registry.length() {
    if registry[i].id == id {
      return i
    }
    i += 1
  }
  registry.length()
}

///|
fn validate_invalid_binary_required_strategies(
  normalized : String,
) -> Array[ValidateInvalidBinaryStrategyId] {
  ignore(normalized)
  validate_invalid_binary_registry()
  .filter(fn(spec) { spec.required_in_smoke })
  .map(fn(spec) { spec.id })
}

///|
fn validate_invalid_binary_profile_has_prefix(
  text : String,
  prefix : String,
) -> Bool {
  if text.length() < prefix.length() {
    return false
  }
  text.sub(end=prefix.length()).to_owned() == prefix
}

///|
fn validate_invalid_binary_mixed_seed_profiles() -> Array[String] {
  [
    "minimal", "repro", "small-natural", "small-coverage-forced", "natural", "coverage-forced",
    "rich",
  ]
}

///|
fn validate_invalid_binary_seed_profiles_from_modifier(
  raw : String,
) -> Result[Array[String], String] {
  let normalized = validate_invalid_binary_ascii_lower(raw.trim().to_owned())
  match normalized {
    "default" | "rich" => Ok(["rich"])
    "mixed" | "all" => Ok(validate_invalid_binary_mixed_seed_profiles())
    _ => {
      let out : Array[String] = []
      for part in normalized.split(",") {
        let item = part.trim().to_owned()
        if item.length() > 0 {
          match item {
            "natural"
            | "coverage-forced"
            | "small-natural"
            | "small-coverage-forced"
            | "repro"
            | "minimal"
            | "rich" => out.push(item)
            _ =>
              return Err(
                "unknown validate-invalid-binary seed profile '\{item}'",
              )
          }
        }
      }
      if out.is_empty() {
        return Err(
          "validate-invalid-binary seed profile list must not be empty",
        )
      }
      Ok(out)
    }
  }
}

///|
pub fn validate_invalid_binary_run_config(
  profile : String,
) -> Result[ValidateInvalidBinaryRunConfig, String] {
  let raw = profile.trim().to_owned()
  let parts : Array[String] = []
  for part in raw.split("+") {
    parts.push(part.to_owned())
  }
  let normalized = if parts.length() == 0 ||
    parts[0].trim().to_owned().length() == 0 {
    "smoke"
  } else {
    validate_invalid_binary_ascii_lower(parts[0].trim().to_owned())
  }
  let base_attempts = match normalized {
    "smoke" => 40
    "ci" => 400
    "stress" => 4000
    _ =>
      return Err(
        "unknown validate-invalid-binary fuzz profile '\{profile}'; expected smoke|ci|stress",
      )
  }
  let mut seed_profiles : Array[String] = []
  let mut i = 1
  while i < parts.length() {
    let part = validate_invalid_binary_ascii_lower(parts[i].trim().to_owned())
    if part.length() == 0 {
      ()
    } else if validate_invalid_binary_profile_has_prefix(part, "seeds=") {
      match
        validate_invalid_binary_seed_profiles_from_modifier(
          part.sub(start=6).to_owned(),
        ) {
        Ok(v) => seed_profiles = v
        Err(msg) => return Err(msg)
      }
    } else if validate_invalid_binary_profile_has_prefix(part, "seed-profiles=") {
      match
        validate_invalid_binary_seed_profiles_from_modifier(
          part.sub(start=14).to_owned(),
        ) {
        Ok(v) => seed_profiles = v
        Err(msg) => return Err(msg)
      }
    } else {
      return Err(
        "unknown validate-invalid-binary profile modifier '\{parts[i]}' in '\{profile}'",
      )
    }
    i += 1
  }
  if seed_profiles.is_empty() {
    seed_profiles = ["rich"]
  }
  Ok({
    profile: normalized,
    attempts: base_attempts * seed_profiles.length(),
    generator_config: gen_invalid_binary_coverage_seed_generator_config(),
    required_strategies: validate_invalid_binary_required_strategies(normalized),
    seed_profiles,
  })
}

///|
fn validate_invalid_binary_type_entries(mod : Module) -> Array[RecType] {
  match mod.type_sec {
    Some(TypeSec(entries)) => entries.copy()
    None => []
  }
}

///|
fn validate_invalid_binary_func_type_entries(mod : Module) -> Array[TypeIdx] {
  match mod.func_sec {
    Some(FuncSec(entries)) => entries.copy()
    None => []
  }
}

///|
fn validate_invalid_binary_code_entries(mod : Module) -> Array[Func] {
  match mod.code_sec {
    Some(CodeSec(entries)) => entries.copy()
    None => []
  }
}

///|
fn validate_invalid_binary_ensure_defined_func(mod : Module) -> Module {
  let func_types = validate_invalid_binary_func_type_entries(mod)
  if !func_types.is_empty() {
    return mod
  }
  let types = validate_invalid_binary_type_entries(mod)
  let code = validate_invalid_binary_code_entries(mod)
  let type_idx = TypeIdx::new(types.length().reinterpret_as_uint())
  types.push(RecType::new(SubType::comp_type(CompType::func([], []))))
  func_types.push(type_idx)
  code.push(Func::new(Locals::empty(), Expr::new([])))
  mod
  .with_type_sec(TypeSec::new(types))
  .with_func_sec(FuncSec::new(func_types))
  .with_code_sec(CodeSec::new(code))
}

///|
fn validate_invalid_binary_decode_uleb(
  bytes : Bytes,
  start : Int,
  limit : Int,
) -> Result[(Int, Int), String] {
  let mut acc = 0
  let mut shift = 0
  let mut i = start
  while i < limit {
    let byte = match bytes.get(i) {
      Some(value) => value.to_int()
      None => return Err("unexpected eof while decoding uleb")
    }
    let payload = byte & 0x7f
    acc = acc | (payload << shift)
    i += 1
    if (byte & 0x80) == 0 {
      return Ok((acc, i))
    }
    shift += 7
    if shift >= 28 {
      return Err("uleb is too wide")
    }
  }
  Err("uleb exceeds available bytes")
}

///|
fn validate_invalid_binary_encode_uleb(value : Int) -> Array[Byte] {
  let out : Array[Byte] = []
  let mut x = value
  while true {
    let payload = x & 0x7f
    x = x >> 7
    let byte = if x == 0 { payload } else { payload | 0x80 }
    out.push(byte.to_byte())
    if x == 0 {
      break
    }
  }
  out
}

///|
fn validate_invalid_binary_scan_sections(
  bytes : Bytes,
) -> Result[Array[ValidateInvalidBinarySectionSpan], String] {
  if bytes.length() < 8 {
    return Err("module bytes shorter than wasm header")
  }
  let spans : Array[ValidateInvalidBinarySectionSpan] = []
  let mut cursor = 8
  while cursor < bytes.length() {
    let id = match bytes.get(cursor) {
      Some(value) => value.to_int()
      None => return Err("unexpected eof while reading section id")
    }
    let header_start = cursor
    let (payload_len, payload_start) = match
      validate_invalid_binary_decode_uleb(bytes, cursor + 1, bytes.length()) {
      Ok(v) => v
      Err(msg) => return Err(msg)
    }
    let end = payload_start + payload_len
    if end > bytes.length() {
      return Err("section payload exceeds module length")
    }
    spans.push({ id, header_start, payload_start, payload_len, end })
    cursor = end
  }
  if cursor != bytes.length() {
    return Err("section scan ended before module length")
  }
  Ok(spans)
}

///|
fn validate_invalid_binary_find_section(
  spans : Array[ValidateInvalidBinarySectionSpan],
  section_id : Int,
) -> ValidateInvalidBinarySectionSpan? {
  for span in spans {
    if span.id == section_id {
      return Some(span)
    }
  }
  None
}

///|
fn validate_invalid_binary_append_range(
  out : Array[Byte],
  source : Array[Byte],
  start : Int,
  end : Int,
) -> Unit {
  let mut i = start
  while i < end {
    out.push(source[i])
    i += 1
  }
}

///|
fn validate_invalid_binary_replace_range(
  bytes : Bytes,
  start : Int,
  end : Int,
  replacement : Array[Byte],
) -> Bytes {
  let source = bytes.to_array()
  let out : Array[Byte] = []
  validate_invalid_binary_append_range(out, source, 0, start)
  for byte in replacement {
    out.push(byte)
  }
  validate_invalid_binary_append_range(out, source, end, source.length())
  Bytes::from_array(out)
}

///|
fn validate_invalid_binary_encode_seed_module(
  mod : Module,
) -> Result[Bytes, String] {
  let prepared = validate_invalid_binary_ensure_defined_func(mod)
  match validate_module(prepared) {
    Ok(_) => ()
    Err(err) =>
      return Err(
        "validate-invalid-binary prepared seed must validate before corruption: \{validation_error_message(err)}",
      )
  }
  match encode_module(prepared) {
    Ok(bytes) => Ok(bytes)
    Err(err) =>
      Err("validate-invalid-binary encode failed before corruption: \{err}")
  }
}

///|
fn validate_invalid_binary_mutation(
  strategy : ValidateInvalidBinaryStrategyId,
  expected_result : ValidateInvalidBinaryExpectedResult,
  applicable : Bool,
  mutated_bytes : Bytes,
) -> ValidateInvalidBinaryMutation {
  { strategy, applicable, expected_result, mutated_bytes }
}

///|
fn validate_invalid_binary_mutate_trailing_garbage(
  mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let encoded = match validate_invalid_binary_encode_seed_module(mod) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let mutated = encoded.to_array()
  mutated.push((0x7f).to_byte())
  Ok(
    validate_invalid_binary_mutation(
      TrailingGarbage,
      DecodeRejected,
      true,
      Bytes::from_array(mutated),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_truncated_module(
  mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let encoded = match validate_invalid_binary_encode_seed_module(mod) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let mutated = encoded.to_array()
  if mutated.length() <= 8 {
    return Ok(
      validate_invalid_binary_mutation(
        TruncatedModule,
        DecodeRejected,
        false,
        encoded,
      ),
    )
  }
  ignore(mutated.pop())
  Ok(
    validate_invalid_binary_mutation(
      TruncatedModule,
      DecodeRejected,
      true,
      Bytes::from_array(mutated),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_duplicate_section(
  mod : Module,
  strategy : ValidateInvalidBinaryStrategyId,
  section_id : Int,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let encoded = match validate_invalid_binary_encode_seed_module(mod) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let spans = match validate_invalid_binary_scan_sections(encoded) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let section_span = match
    validate_invalid_binary_find_section(spans, section_id) {
    Some(span) => span
    None =>
      return Ok(
        validate_invalid_binary_mutation(
          strategy,
          DecodeRejected,
          false,
          encoded,
        ),
      )
  }
  let mutated = encoded.to_array()
  let source = encoded.to_array()
  validate_invalid_binary_append_range(
    mutated,
    source,
    section_span.header_start,
    section_span.end,
  )
  Ok(
    validate_invalid_binary_mutation(
      strategy,
      DecodeRejected,
      true,
      Bytes::from_array(mutated),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_duplicate_type_section(
  mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  validate_invalid_binary_mutate_duplicate_section(mod, DuplicateTypeSection, 1)
}

///|
fn validate_invalid_binary_mutate_duplicate_import_section(
  mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  validate_invalid_binary_mutate_duplicate_section(
    mod,
    DuplicateImportSection,
    2,
  )
}

///|
fn validate_invalid_binary_mutate_duplicate_export_section(
  mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  validate_invalid_binary_mutate_duplicate_section(
    mod,
    DuplicateExportSection,
    7,
  )
}

///|
fn validate_invalid_binary_mutate_duplicate_table_section(
  mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  validate_invalid_binary_mutate_duplicate_section(
    mod,
    DuplicateTableSection,
    4,
  )
}

///|
fn validate_invalid_binary_mutate_duplicate_memory_section(
  mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  validate_invalid_binary_mutate_duplicate_section(
    mod,
    DuplicateMemorySection,
    5,
  )
}

///|
fn validate_invalid_binary_mutate_duplicate_global_section(
  mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  validate_invalid_binary_mutate_duplicate_section(
    mod,
    DuplicateGlobalSection,
    6,
  )
}

///|
fn validate_invalid_binary_mutate_duplicate_function_section(
  mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  validate_invalid_binary_mutate_duplicate_section(
    mod,
    DuplicateFunctionSection,
    3,
  )
}

///|
fn validate_invalid_binary_mutate_duplicate_code_section(
  mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  validate_invalid_binary_mutate_duplicate_section(
    mod,
    DuplicateCodeSection,
    10,
  )
}

///|
fn validate_invalid_binary_mutate_duplicate_element_section(
  mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  validate_invalid_binary_mutate_duplicate_section(
    mod,
    DuplicateElementSection,
    9,
  )
}

///|
fn validate_invalid_binary_mutate_duplicate_data_section(
  mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  validate_invalid_binary_mutate_duplicate_section(
    mod,
    DuplicateDataSection,
    11,
  )
}

///|
fn validate_invalid_binary_mutate_duplicate_tag_section(
  mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  validate_invalid_binary_mutate_duplicate_section(mod, DuplicateTagSection, 13)
}

///|
fn validate_invalid_binary_mutate_duplicate_start_section(
  mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let encoded = match validate_invalid_binary_encode_seed_module(mod) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let mutated = encoded.to_array()
  // Append two singleton start sections. This is intentionally section-order
  // agnostic: any duplicate non-custom section must be rejected by decoding.
  mutated.push(8)
  mutated.push(1)
  mutated.push(0)
  mutated.push(8)
  mutated.push(1)
  mutated.push(0)
  Ok(
    validate_invalid_binary_mutation(
      DuplicateStartSection,
      DecodeRejected,
      true,
      Bytes::from_array(mutated),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_wrong_section_order(
  mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let encoded = match validate_invalid_binary_encode_seed_module(mod) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let spans = match validate_invalid_binary_scan_sections(encoded) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let mut pair_idx = -1
  let mut i = 0
  while i + 1 < spans.length() {
    if spans[i].id != 0 && spans[i + 1].id != 0 {
      pair_idx = i
      break
    }
    i += 1
  }
  if pair_idx < 0 {
    return Ok(
      validate_invalid_binary_mutation(
        WrongSectionOrder,
        DecodeRejected,
        false,
        encoded,
      ),
    )
  }
  let first = spans[pair_idx]
  let second = spans[pair_idx + 1]
  let source = encoded.to_array()
  let out : Array[Byte] = []
  validate_invalid_binary_append_range(out, source, 0, first.header_start)
  validate_invalid_binary_append_range(
    out,
    source,
    second.header_start,
    second.end,
  )
  validate_invalid_binary_append_range(
    out,
    source,
    first.header_start,
    first.end,
  )
  validate_invalid_binary_append_range(out, source, second.end, source.length())
  Ok(
    validate_invalid_binary_mutation(
      WrongSectionOrder,
      DecodeRejected,
      true,
      Bytes::from_array(out),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_bad_magic_header(
  mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let encoded = match validate_invalid_binary_encode_seed_module(mod) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let mutated = encoded.to_array()
  mutated[0] = (0x01).to_byte()
  Ok(
    validate_invalid_binary_mutation(
      BadMagicHeader,
      DecodeRejected,
      true,
      Bytes::from_array(mutated),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_bad_version_header(
  mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let encoded = match validate_invalid_binary_encode_seed_module(mod) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let mutated = encoded.to_array()
  mutated[4] = (0x00).to_byte()
  mutated[5] = (0x00).to_byte()
  mutated[6] = (0x00).to_byte()
  mutated[7] = (0x00).to_byte()
  Ok(
    validate_invalid_binary_mutation(
      BadVersionHeader,
      DecodeRejected,
      true,
      Bytes::from_array(mutated),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_section_size_uleb(
  mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let encoded = match validate_invalid_binary_encode_seed_module(mod) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let spans = match validate_invalid_binary_scan_sections(encoded) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  if spans.is_empty() {
    return Ok(
      validate_invalid_binary_mutation(
        MalformedSectionSizeUleb,
        DecodeRejected,
        false,
        encoded,
      ),
    )
  }
  let target = spans[0]
  let replacement = [
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ]
  Ok(
    validate_invalid_binary_mutation(
      MalformedSectionSizeUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_replace_range(
        encoded,
        target.header_start + 1,
        target.payload_start,
        replacement,
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_section_size_uleb(
  mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let encoded = match validate_invalid_binary_encode_seed_module(mod) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let spans = match validate_invalid_binary_scan_sections(encoded) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  if spans.is_empty() {
    return Ok(
      validate_invalid_binary_mutation(
        OverwideSectionSizeUleb,
        DecodeRejected,
        false,
        encoded,
      ),
    )
  }
  let target = spans[0]
  Ok(
    validate_invalid_binary_mutation(
      OverwideSectionSizeUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_replace_range(
        encoded,
        target.header_start + 1,
        target.payload_start,
        validate_invalid_binary_overwide_u32_uleb_bytes(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_section_payload_length_overflow(
  mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let encoded = match validate_invalid_binary_encode_seed_module(mod) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let spans = match validate_invalid_binary_scan_sections(encoded) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  if spans.is_empty() {
    return Ok(
      validate_invalid_binary_mutation(
        SectionPayloadLengthOverflow,
        DecodeRejected,
        false,
        encoded,
      ),
    )
  }
  let target = spans[spans.length() - 1]
  let replacement = validate_invalid_binary_encode_uleb(target.payload_len + 1)
  Ok(
    validate_invalid_binary_mutation(
      SectionPayloadLengthOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_replace_range(
        encoded,
        target.header_start + 1,
        target.payload_start,
        replacement,
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_section_payload_length_underflow(
  mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let encoded = match validate_invalid_binary_encode_seed_module(mod) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let spans = match validate_invalid_binary_scan_sections(encoded) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let mut target : ValidateInvalidBinarySectionSpan? = None
  for span in spans {
    if span.payload_len > 0 {
      target = Some(span)
      break
    }
  }
  let target = match target {
    Some(v) => v
    None =>
      return Ok(
        validate_invalid_binary_mutation(
          SectionPayloadLengthUnderflow,
          DecodeRejected,
          false,
          encoded,
        ),
      )
  }
  let replacement = validate_invalid_binary_encode_uleb(target.payload_len - 1)
  Ok(
    validate_invalid_binary_mutation(
      SectionPayloadLengthUnderflow,
      DecodeRejected,
      true,
      validate_invalid_binary_replace_range(
        encoded,
        target.header_start + 1,
        target.payload_start,
        replacement,
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_reserved_section_id(
  mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let encoded = match validate_invalid_binary_encode_seed_module(mod) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let spans = match validate_invalid_binary_scan_sections(encoded) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let mut target : ValidateInvalidBinarySectionSpan? = None
  for span in spans {
    if span.id != 0 {
      target = Some(span)
      break
    }
  }
  let target = match target {
    Some(v) => v
    None =>
      return Ok(
        validate_invalid_binary_mutation(
          ReservedSectionId,
          DecodeRejected,
          false,
          encoded,
        ),
      )
  }
  let mutated = encoded.to_array()
  mutated[target.header_start] = (13).to_byte()
  Ok(
    validate_invalid_binary_mutation(
      ReservedSectionId,
      DecodeRejected,
      true,
      Bytes::from_array(mutated),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_custom_section_name_utf8(
  mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let encoded = match validate_invalid_binary_encode_seed_module(mod) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let mutated = encoded.to_array()
  mutated.push((0).to_byte())
  mutated.push((2).to_byte())
  mutated.push((1).to_byte())
  mutated.push((0x80).to_byte())
  Ok(
    validate_invalid_binary_mutation(
      InvalidCustomSectionNameUtf8,
      DecodeRejected,
      true,
      Bytes::from_array(mutated),
    ),
  )
}

///|
fn validate_invalid_binary_minimal_code_with_instr(
  instr : Array[Byte],
) -> Bytes {
  let body_size = instr.length() + 2
  let code_payload_size = body_size + 2
  let out : Array[Byte] = [
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x03).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x0a).to_byte(),
    code_payload_size.to_byte(),
    (0x01).to_byte(),
    body_size.to_byte(),
    (0x00).to_byte(),
  ]
  for byte in instr {
    out.push(byte)
  }
  out.push((0x0b).to_byte())
  Bytes::from_array(out)
}

///|
fn validate_invalid_binary_mutate_malformed_simd_immediate(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedSimdImmediate,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfd).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_simd_lane_index_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      SimdLaneIndexOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x41).to_byte(),
        (0x00).to_byte(),
        (0xfd).to_byte(),
        (0x15).to_byte(),
        (0x10).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_custom_section_payload(
  mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let encoded = match validate_invalid_binary_encode_seed_module(mod) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let mutated = encoded.to_array()
  mutated.push((0).to_byte())
  mutated.push((1).to_byte())
  mutated.push((2).to_byte())
  Ok(
    validate_invalid_binary_mutation(
      MalformedCustomSectionPayload,
      DecodeRejected,
      true,
      Bytes::from_array(mutated),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_malformed_custom_section_name_length_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x05).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_overwide_custom_section_name_length_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x06).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_malformed_name_subsection_size_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0a).to_byte(),
    (0x04).to_byte(),
    (0x6e).to_byte(),
    (0x61).to_byte(),
    (0x6d).to_byte(),
    (0x65).to_byte(),
    (0x01).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_overwide_name_subsection_size_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0c).to_byte(),
    (0x04).to_byte(),
    (0x6e).to_byte(),
    (0x61).to_byte(),
    (0x6d).to_byte(),
    (0x65).to_byte(),
    (0x01).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_invalid_name_subsection_id_byte() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x07).to_byte(),
    (0x04).to_byte(),
    (0x6e).to_byte(),
    (0x61).to_byte(),
    (0x6d).to_byte(),
    (0x65).to_byte(),
    (0x0c).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_out_of_order_name_subsection_id() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
    (0x04).to_byte(),
    (0x6e).to_byte(),
    (0x61).to_byte(),
    (0x6d).to_byte(),
    (0x65).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_malformed_custom_section_name_length_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedCustomSectionNameLengthUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_custom_section_name_length_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_custom_section_name_length_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideCustomSectionNameLengthUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_overwide_custom_section_name_length_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_name_subsection_size_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedNameSubsectionSizeUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_name_subsection_size_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_name_subsection_size_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideNameSubsectionSizeUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_overwide_name_subsection_size_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_name_subsection_id_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidNameSubsectionIdByte,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_name_subsection_id_byte(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_out_of_order_name_subsection_id(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OutOfOrderNameSubsectionId,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_out_of_order_name_subsection_id(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_opcode_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidOpcodeByte,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([(0xff).to_byte()]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_prefix_subopcode_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidPrefixSubopcodeByte,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfc).to_byte(),
        (0xff).to_byte(),
        (0xff).to_byte(),
        (0xff).to_byte(),
        (0xff).to_byte(),
        (0x0f).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_invalid_prefix_subopcode_module(
  prefix : Byte,
) -> Bytes {
  validate_invalid_binary_minimal_code_with_instr([prefix, (0x7f).to_byte()])
}

///|
fn validate_invalid_binary_mutate_invalid_gc_prefix_subopcode_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidGcPrefixSubopcodeByte,
      DecodeRejected,
      true,
      validate_invalid_binary_invalid_prefix_subopcode_module((0xfb).to_byte()),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_bulk_prefix_subopcode_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidBulkPrefixSubopcodeByte,
      DecodeRejected,
      true,
      validate_invalid_binary_invalid_prefix_subopcode_module((0xfc).to_byte()),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_simd_prefix_subopcode_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidSimdPrefixSubopcodeByte,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfd).to_byte(),
        (0xff).to_byte(),
        (0xff).to_byte(),
        (0xff).to_byte(),
        (0xff).to_byte(),
        (0x0f).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_malformed_prefix_subopcode_module(
  prefix : Byte,
) -> Bytes {
  validate_invalid_binary_minimal_code_with_instr([
    prefix,
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_overwide_prefix_subopcode_module(
  prefix : Byte,
) -> Bytes {
  validate_invalid_binary_minimal_code_with_instr([
    prefix,
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_malformed_gc_prefix_subopcode_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedGcPrefixSubopcodeUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_malformed_prefix_subopcode_module(
        (0xfb).to_byte(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_bulk_prefix_subopcode_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedBulkPrefixSubopcodeUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_malformed_prefix_subopcode_module(
        (0xfc).to_byte(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_simd_prefix_subopcode_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedSimdPrefixSubopcodeUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_malformed_prefix_subopcode_module(
        (0xfd).to_byte(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_atomic_prefix_subopcode_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedAtomicPrefixSubopcodeUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_malformed_prefix_subopcode_module(
        (0xfe).to_byte(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_atomic_prefix_subopcode_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidAtomicPrefixSubopcodeByte,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfe).to_byte(),
        (0x7f).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_gc_prefix_subopcode_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideGcPrefixSubopcodeUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_overwide_prefix_subopcode_module((0xfb).to_byte()),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_bulk_prefix_subopcode_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideBulkPrefixSubopcodeUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_overwide_prefix_subopcode_module((0xfc).to_byte()),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_simd_prefix_subopcode_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideSimdPrefixSubopcodeUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_overwide_prefix_subopcode_module((0xfd).to_byte()),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_atomic_prefix_subopcode_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideAtomicPrefixSubopcodeUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_overwide_prefix_subopcode_module((0xfe).to_byte()),
    ),
  )
}

///|
fn validate_invalid_binary_atomic_notify_prefix() -> Array[Byte] {
  [
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0xfe).to_byte(),
    (0x00).to_byte(),
  ]
}

///|
fn validate_invalid_binary_atomic_wait_prefix() -> Array[Byte] {
  [
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0x42).to_byte(),
    (0x00).to_byte(),
    (0xfe).to_byte(),
    (0x01).to_byte(),
  ]
}

///|
fn validate_invalid_binary_atomic_rmw_prefix() -> Array[Byte] {
  [
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0xfe).to_byte(),
    (0x1e).to_byte(),
  ]
}

///|
fn validate_invalid_binary_atomic_cmpxchg_prefix() -> Array[Byte] {
  [
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0xfe).to_byte(),
    (0x48).to_byte(),
  ]
}

///|
fn validate_invalid_binary_atomic_memarg_with_malformed_align(
  prefix : Array[Byte],
) -> Bytes {
  let instr = prefix
  instr.append([
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
  validate_invalid_binary_minimal_code_with_instr(instr)
}

///|
fn validate_invalid_binary_atomic_memarg_with_malformed_offset(
  prefix : Array[Byte],
) -> Bytes {
  let instr = prefix
  instr.append([
    (0x02).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
  validate_invalid_binary_minimal_code_with_instr(instr)
}

///|
fn validate_invalid_binary_atomic_memarg_with_overwide_align(
  prefix : Array[Byte],
) -> Bytes {
  let instr = prefix
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  instr.push((0x00).to_byte())
  validate_invalid_binary_minimal_code_with_instr(instr)
}

///|
fn validate_invalid_binary_atomic_memarg_with_overwide_offset(
  prefix : Array[Byte],
) -> Bytes {
  let instr = prefix
  instr.push((0x02).to_byte())
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  validate_invalid_binary_minimal_code_with_instr(instr)
}

///|
fn validate_invalid_binary_mutate_malformed_atomic_load_memarg_align_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedAtomicLoadMemargAlignUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x41).to_byte(),
        (0x00).to_byte(),
        (0xfe).to_byte(),
        (0x10).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_atomic_store_memarg_align_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedAtomicStoreMemargAlignUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x41).to_byte(),
        (0x00).to_byte(),
        (0x41).to_byte(),
        (0x00).to_byte(),
        (0xfe).to_byte(),
        (0x17).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_atomic_load_memarg_offset_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedAtomicLoadMemargOffsetUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x41).to_byte(),
        (0x00).to_byte(),
        (0xfe).to_byte(),
        (0x10).to_byte(),
        (0x02).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_atomic_store_memarg_offset_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedAtomicStoreMemargOffsetUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x41).to_byte(),
        (0x00).to_byte(),
        (0x41).to_byte(),
        (0x00).to_byte(),
        (0xfe).to_byte(),
        (0x17).to_byte(),
        (0x02).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_atomic_load_memarg_align_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0xfe).to_byte(),
    (0x10).to_byte(),
  ]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  instr.push((0x00).to_byte())
  Ok(
    validate_invalid_binary_mutation(
      OverwideAtomicLoadMemargAlignUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_atomic_store_memarg_align_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0xfe).to_byte(),
    (0x17).to_byte(),
  ]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  instr.push((0x00).to_byte())
  Ok(
    validate_invalid_binary_mutation(
      OverwideAtomicStoreMemargAlignUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_atomic_load_memarg_offset_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0xfe).to_byte(),
    (0x10).to_byte(),
    (0x02).to_byte(),
  ]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideAtomicLoadMemargOffsetUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_atomic_store_memarg_offset_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0xfe).to_byte(),
    (0x17).to_byte(),
    (0x02).to_byte(),
  ]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideAtomicStoreMemargOffsetUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_atomic_notify_memarg_align_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedAtomicNotifyMemargAlignUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_atomic_memarg_with_malformed_align(
        validate_invalid_binary_atomic_notify_prefix(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_atomic_notify_memarg_offset_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedAtomicNotifyMemargOffsetUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_atomic_memarg_with_malformed_offset(
        validate_invalid_binary_atomic_notify_prefix(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_atomic_wait_memarg_align_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedAtomicWaitMemargAlignUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_atomic_memarg_with_malformed_align(
        validate_invalid_binary_atomic_wait_prefix(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_atomic_wait_memarg_offset_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedAtomicWaitMemargOffsetUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_atomic_memarg_with_malformed_offset(
        validate_invalid_binary_atomic_wait_prefix(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_atomic_rmw_memarg_align_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedAtomicRmwMemargAlignUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_atomic_memarg_with_malformed_align(
        validate_invalid_binary_atomic_rmw_prefix(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_atomic_rmw_memarg_offset_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedAtomicRmwMemargOffsetUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_atomic_memarg_with_malformed_offset(
        validate_invalid_binary_atomic_rmw_prefix(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_atomic_cmpxchg_memarg_align_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedAtomicCmpxchgMemargAlignUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_atomic_memarg_with_malformed_align(
        validate_invalid_binary_atomic_cmpxchg_prefix(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_atomic_cmpxchg_memarg_offset_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedAtomicCmpxchgMemargOffsetUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_atomic_memarg_with_malformed_offset(
        validate_invalid_binary_atomic_cmpxchg_prefix(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_atomic_notify_memarg_align_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideAtomicNotifyMemargAlignUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_atomic_memarg_with_overwide_align(
        validate_invalid_binary_atomic_notify_prefix(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_atomic_notify_memarg_offset_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideAtomicNotifyMemargOffsetUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_atomic_memarg_with_overwide_offset(
        validate_invalid_binary_atomic_notify_prefix(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_atomic_wait_memarg_align_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideAtomicWaitMemargAlignUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_atomic_memarg_with_overwide_align(
        validate_invalid_binary_atomic_wait_prefix(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_atomic_wait_memarg_offset_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideAtomicWaitMemargOffsetUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_atomic_memarg_with_overwide_offset(
        validate_invalid_binary_atomic_wait_prefix(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_atomic_rmw_memarg_align_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideAtomicRmwMemargAlignUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_atomic_memarg_with_overwide_align(
        validate_invalid_binary_atomic_rmw_prefix(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_atomic_rmw_memarg_offset_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideAtomicRmwMemargOffsetUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_atomic_memarg_with_overwide_offset(
        validate_invalid_binary_atomic_rmw_prefix(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_atomic_cmpxchg_memarg_align_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideAtomicCmpxchgMemargAlignUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_atomic_memarg_with_overwide_align(
        validate_invalid_binary_atomic_cmpxchg_prefix(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_atomic_cmpxchg_memarg_offset_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideAtomicCmpxchgMemargOffsetUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_atomic_memarg_with_overwide_offset(
        validate_invalid_binary_atomic_cmpxchg_prefix(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_memarg_immediate(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedMemargImmediate,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x41).to_byte(),
        (0x00).to_byte(),
        (0x28).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_load_memarg_align_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedLoadMemargAlignUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x41).to_byte(),
        (0x00).to_byte(),
        (0x28).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_store_memarg_align_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedStoreMemargAlignUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x41).to_byte(),
        (0x00).to_byte(),
        (0x41).to_byte(),
        (0x00).to_byte(),
        (0x36).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_load_memarg_offset_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedLoadMemargOffsetUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x41).to_byte(),
        (0x00).to_byte(),
        (0x28).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_store_memarg_offset_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedStoreMemargOffsetUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x41).to_byte(),
        (0x00).to_byte(),
        (0x41).to_byte(),
        (0x00).to_byte(),
        (0x36).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_overwide_u32_uleb_bytes() -> Array[Byte] {
  [
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x00).to_byte(),
  ]
}

///|
fn validate_invalid_binary_mutate_overwide_load_memarg_align_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0x28).to_byte(),
  ]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  instr.push((0x00).to_byte())
  Ok(
    validate_invalid_binary_mutation(
      OverwideLoadMemargAlignUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_store_memarg_align_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0x36).to_byte(),
  ]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  instr.push((0x00).to_byte())
  Ok(
    validate_invalid_binary_mutation(
      OverwideStoreMemargAlignUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_load_memarg_offset_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0x28).to_byte(),
    (0x00).to_byte(),
  ]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideLoadMemargOffsetUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_store_memarg_offset_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0x36).to_byte(),
    (0x00).to_byte(),
  ]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideStoreMemargOffsetUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_blocktype_immediate(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedBlocktypeImmediate,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x02).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_blocktype_valtype_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidBlocktypeValTypeByte,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x02).to_byte(),
        (0x7a).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_blocktype_type_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideBlocktypeTypeIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x02).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x00).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_memory_min_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedMemoryMinUleb,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x05).to_byte(),
        (0x07).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_table_min_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedTableMinUleb,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x04).to_byte(),
        (0x08).to_byte(),
        (0x01).to_byte(),
        (0x70).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_memory_max_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedMemoryMaxUleb,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x05).to_byte(),
        (0x08).to_byte(),
        (0x01).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_table_max_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedTableMaxUleb,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x04).to_byte(),
        (0x09).to_byte(),
        (0x01).to_byte(),
        (0x70).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_memory_min_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideMemoryMinUleb,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x05).to_byte(),
        (0x0d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x00).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_table_min_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideTableMinUleb,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x04).to_byte(),
        (0x0e).to_byte(),
        (0x01).to_byte(),
        (0x70).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x00).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_memory_max_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideMemoryMaxUleb,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x05).to_byte(),
        (0x0e).to_byte(),
        (0x01).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x00).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_table_max_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideTableMaxUleb,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x04).to_byte(),
        (0x0f).to_byte(),
        (0x01).to_byte(),
        (0x70).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x00).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_tag_type_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideTagTypeIndexUleb,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x0d).to_byte(),
        (0x08).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x00).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_local_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedLocalIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x20).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_local_set_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedLocalSetIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x21).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_local_tee_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedLocalTeeIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x22).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_global_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedGlobalIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x23).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_global_set_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedGlobalSetIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x24).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_minimal_code_with_overwide_u32_instr(
  opcode : Byte,
) -> Bytes {
  validate_invalid_binary_minimal_code_with_instr([
    opcode,
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_overwide_local_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideLocalIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_overwide_u32_instr(
        (0x20).to_byte(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_local_set_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideLocalSetIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_overwide_u32_instr(
        (0x21).to_byte(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_local_tee_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideLocalTeeIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_overwide_u32_instr(
        (0x22).to_byte(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_global_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideGlobalIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_overwide_u32_instr(
        (0x23).to_byte(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_global_set_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideGlobalSetIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_overwide_u32_instr(
        (0x24).to_byte(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_i32_const_sleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedI32ConstSleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x41).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_i64_const_sleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedI64ConstSleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x42).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_i32_const_sleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideI32ConstSleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x41).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x00).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_i64_const_sleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideI64ConstSleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x42).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x00).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_f32_const_immediate(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedF32ConstImmediate,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x43).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_f64_const_immediate(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedF64ConstImmediate,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x44).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_call_func_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedCallFuncIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x10).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_return_call_func_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedReturnCallFuncIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x12).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_ref_func_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedRefFuncIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xd2).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_call_func_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideCallFuncIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_overwide_u32_instr(
        (0x10).to_byte(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_return_call_func_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideReturnCallFuncIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_overwide_u32_instr(
        (0x12).to_byte(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_ref_func_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideRefFuncIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_overwide_u32_instr(
        (0xd2).to_byte(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_call_indirect_type_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedCallIndirectTypeIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x11).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_call_indirect_table_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedCallIndirectTableIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x11).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_return_call_indirect_type_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedReturnCallIndirectTypeIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x13).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_return_call_indirect_table_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedReturnCallIndirectTableIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x13).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_call_ref_type_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedCallRefTypeIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x14).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_return_call_ref_type_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedReturnCallRefTypeIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x15).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_call_indirect_type_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideCallIndirectTypeIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x11).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x00).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_call_indirect_table_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideCallIndirectTableIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x11).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x00).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_return_call_indirect_type_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideReturnCallIndirectTypeIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x13).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x00).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_return_call_indirect_table_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideReturnCallIndirectTableIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x13).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x00).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_call_ref_type_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideCallRefTypeIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_overwide_u32_instr(
        (0x14).to_byte(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_return_call_ref_type_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideReturnCallRefTypeIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_overwide_u32_instr(
        (0x15).to_byte(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_throw_tag_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedThrowTagIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x08).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_try_table_catch_count_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedTryTableCatchCountUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x1f).to_byte(),
        (0x40).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_try_table_catch_tag_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedTryTableCatchTagIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x1f).to_byte(),
        (0x40).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_try_table_catch_label_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedTryTableCatchLabelIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x1f).to_byte(),
        (0x40).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_struct_new_type_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedStructNewTypeIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfb).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_struct_get_field_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedStructGetFieldIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfb).to_byte(),
        (0x02).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_array_new_data_type_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedArrayNewDataTypeIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfb).to_byte(),
        (0x09).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_array_new_data_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedArrayNewDataIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfb).to_byte(),
        (0x09).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_array_new_elem_type_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedArrayNewElemTypeIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfb).to_byte(),
        (0x0a).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_array_new_elem_elem_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedArrayNewElemElemIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfb).to_byte(),
        (0x0a).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_throw_tag_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [(0x08).to_byte()]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideThrowTagIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_try_table_catch_count_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [(0x1f).to_byte(), (0x40).to_byte()]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideTryTableCatchCountUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_try_table_catch_tag_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [
    (0x1f).to_byte(),
    (0x40).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
  ]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideTryTableCatchTagIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_try_table_catch_label_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [
    (0x1f).to_byte(),
    (0x40).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
  ]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideTryTableCatchLabelIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_struct_new_type_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [(0xfb).to_byte(), (0x00).to_byte()]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideStructNewTypeIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_struct_get_field_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [
    (0xfb).to_byte(),
    (0x02).to_byte(),
    (0x00).to_byte(),
  ]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideStructGetFieldIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_array_new_data_type_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [(0xfb).to_byte(), (0x09).to_byte()]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideArrayNewDataTypeIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_array_new_data_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [
    (0xfb).to_byte(),
    (0x09).to_byte(),
    (0x00).to_byte(),
  ]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideArrayNewDataIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_array_new_elem_type_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [(0xfb).to_byte(), (0x0a).to_byte()]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideArrayNewElemTypeIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_array_new_elem_elem_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [
    (0xfb).to_byte(),
    (0x0a).to_byte(),
    (0x00).to_byte(),
  ]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideArrayNewElemElemIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_br_label_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedBrLabelIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x0c).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_br_if_label_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedBrIfLabelIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x0d).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_br_table_target_count_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedBrTableTargetCountUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x0e).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_br_table_target_label_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedBrTableTargetLabelIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x0e).to_byte(),
        (0x01).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_br_table_default_label_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedBrTableDefaultLabelIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x0e).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_br_label_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [(0x0c).to_byte()]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideBrLabelIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_br_if_label_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [(0x0d).to_byte()]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideBrIfLabelIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_br_table_target_count_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [(0x0e).to_byte()]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideBrTableTargetCountUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_br_table_target_label_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [(0x0e).to_byte(), (0x01).to_byte()]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideBrTableTargetLabelIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_br_table_default_label_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [(0x0e).to_byte(), (0x00).to_byte()]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideBrTableDefaultLabelIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_table_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedTableIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x25).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_table_set_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedTableSetIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x26).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_table_size_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedTableSizeIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfc).to_byte(),
        (0x10).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_table_grow_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedTableGrowIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfc).to_byte(),
        (0x0f).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_table_fill_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedTableFillIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfc).to_byte(),
        (0x11).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_table_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [(0x25).to_byte()]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideTableIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_table_set_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [(0x26).to_byte()]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideTableSetIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_table_size_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [(0xfc).to_byte(), (0x10).to_byte()]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideTableSizeIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_table_grow_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [(0xfc).to_byte(), (0x0f).to_byte()]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideTableGrowIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_table_fill_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [(0xfc).to_byte(), (0x11).to_byte()]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideTableFillIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_memory_size_memory_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedMemorySizeMemoryIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x3f).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_memory_grow_memory_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedMemoryGrowMemoryIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x41).to_byte(),
        (0x00).to_byte(),
        (0x40).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_memory_fill_memory_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedMemoryFillMemoryIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfc).to_byte(),
        (0x0b).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_memory_size_memory_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [(0x3f).to_byte()]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideMemorySizeMemoryIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_memory_grow_memory_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0x40).to_byte(),
  ]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideMemoryGrowMemoryIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_memory_fill_memory_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [(0xfc).to_byte(), (0x0b).to_byte()]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideMemoryFillMemoryIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_memory_copy_dst_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedMemoryCopyDstIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfc).to_byte(),
        (0x0a).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_memory_copy_src_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedMemoryCopySrcIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfc).to_byte(),
        (0x0a).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_table_copy_dst_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedTableCopyDstIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfc).to_byte(),
        (0x0e).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_table_copy_src_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedTableCopySrcIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfc).to_byte(),
        (0x0e).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_memory_copy_dst_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [(0xfc).to_byte(), (0x0a).to_byte()]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideMemoryCopyDstIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_memory_copy_src_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [
    (0xfc).to_byte(),
    (0x0a).to_byte(),
    (0x00).to_byte(),
  ]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideMemoryCopySrcIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_table_copy_dst_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [(0xfc).to_byte(), (0x0e).to_byte()]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideTableCopyDstIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_table_copy_src_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [
    (0xfc).to_byte(),
    (0x0e).to_byte(),
    (0x00).to_byte(),
  ]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideTableCopySrcIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_select_type_count_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedSelectTypeCountUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x1c).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_select_type_count_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [(0x1c).to_byte()]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideSelectTypeCountUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_typed_select_valtype_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidTypedSelectValTypeByte,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x1c).to_byte(),
        (0x01).to_byte(),
        (0xff).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_start_func_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedStartFuncIndexUleb,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x08).to_byte(),
        (0x05).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_datacount_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedDataCountUleb,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x0c).to_byte(),
        (0x05).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_minimal_singleton_section_with_overwide_u32(
  section_id : Byte,
) -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    section_id,
    (0x06).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_overwide_start_func_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideStartFuncIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_singleton_section_with_overwide_u32(
        (0x08).to_byte(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_datacount_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideDataCountUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_singleton_section_with_overwide_u32(
        (0x0c).to_byte(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_simd_shuffle_lane_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      SimdShuffleLaneOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfd).to_byte(),
        (0x0d).to_byte(),
        (0x00).to_byte(),
        (0x01).to_byte(),
        (0x02).to_byte(),
        (0x03).to_byte(),
        (0x04).to_byte(),
        (0x05).to_byte(),
        (0x06).to_byte(),
        (0x07).to_byte(),
        (0x08).to_byte(),
        (0x09).to_byte(),
        (0x0a).to_byte(),
        (0x0b).to_byte(),
        (0x0c).to_byte(),
        (0x0d).to_byte(),
        (0x0e).to_byte(),
        (0x20).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_simd_load_lane_index_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      SimdLoadLaneIndexOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0x41).to_byte(),
        (0x00).to_byte(),
        (0xfd).to_byte(),
        (0x54).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x10).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_simd_store_lane_index_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      SimdStoreLaneIndexOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfd).to_byte(),
        (0x58).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x10).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_simd_extract_lane_index_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      SimdExtractLaneIndexOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfd).to_byte(),
        (0x15).to_byte(),
        (0x10).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_simd_replace_lane_index_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      SimdReplaceLaneIndexOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfd).to_byte(),
        (0x17).to_byte(),
        (0x10).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_simd_memarg_prefix(is_store : Bool) -> Array[Byte] {
  if is_store {
    [(0xfd).to_byte(), (0x0b).to_byte()]
  } else {
    [(0xfd).to_byte(), (0x00).to_byte()]
  }
}

///|
fn validate_invalid_binary_simd_lane_memarg_prefix(
  is_store : Bool,
) -> Array[Byte] {
  if is_store {
    [(0xfd).to_byte(), (0x58).to_byte()]
  } else {
    [(0xfd).to_byte(), (0x54).to_byte()]
  }
}

///|
fn validate_invalid_binary_simd_load_splat_memarg_prefix() -> Array[Byte] {
  [(0xfd).to_byte(), (0x07).to_byte()]
}

///|
fn validate_invalid_binary_simd_load_extend_memarg_prefix() -> Array[Byte] {
  [(0xfd).to_byte(), (0x01).to_byte()]
}

///|
fn validate_invalid_binary_simd_load_zero_memarg_prefix() -> Array[Byte] {
  [(0xfd).to_byte(), (0x5c).to_byte()]
}

///|
fn validate_invalid_binary_mutate_malformed_simd_memarg_align_uleb(
  kind : ValidateInvalidBinaryStrategyId,
  is_store : Bool,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr = validate_invalid_binary_simd_memarg_prefix(is_store)
  validate_invalid_binary_mutate_malformed_simd_memarg_align_uleb_with_prefix(
    kind, instr,
  )
}

///|
fn validate_invalid_binary_mutate_malformed_simd_memarg_align_uleb_with_prefix(
  kind : ValidateInvalidBinaryStrategyId,
  instr : Array[Byte],
) -> Result[ValidateInvalidBinaryMutation, String] {
  instr.append([
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
  Ok(
    validate_invalid_binary_mutation(
      kind,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_simd_memarg_offset_uleb(
  kind : ValidateInvalidBinaryStrategyId,
  is_store : Bool,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr = validate_invalid_binary_simd_memarg_prefix(is_store)
  validate_invalid_binary_mutate_malformed_simd_memarg_offset_uleb_with_prefix(
    kind, instr,
  )
}

///|
fn validate_invalid_binary_mutate_malformed_simd_memarg_offset_uleb_with_prefix(
  kind : ValidateInvalidBinaryStrategyId,
  instr : Array[Byte],
) -> Result[ValidateInvalidBinaryMutation, String] {
  instr.append([
    (0x00).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
  Ok(
    validate_invalid_binary_mutation(
      kind,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_simd_memarg_align_uleb(
  kind : ValidateInvalidBinaryStrategyId,
  is_store : Bool,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr = validate_invalid_binary_simd_memarg_prefix(is_store)
  validate_invalid_binary_mutate_overwide_simd_memarg_align_uleb_with_prefix(
    kind, instr,
  )
}

///|
fn validate_invalid_binary_mutate_overwide_simd_memarg_align_uleb_with_prefix(
  kind : ValidateInvalidBinaryStrategyId,
  instr : Array[Byte],
) -> Result[ValidateInvalidBinaryMutation, String] {
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  instr.push((0x00).to_byte())
  Ok(
    validate_invalid_binary_mutation(
      kind,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_simd_memarg_offset_uleb(
  kind : ValidateInvalidBinaryStrategyId,
  is_store : Bool,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr = validate_invalid_binary_simd_memarg_prefix(is_store)
  validate_invalid_binary_mutate_overwide_simd_memarg_offset_uleb_with_prefix(
    kind, instr,
  )
}

///|
fn validate_invalid_binary_mutate_overwide_simd_memarg_offset_uleb_with_prefix(
  kind : ValidateInvalidBinaryStrategyId,
  instr : Array[Byte],
) -> Result[ValidateInvalidBinaryMutation, String] {
  instr.push((0x00).to_byte())
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      kind,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_simd_lane_memarg_align_uleb(
  kind : ValidateInvalidBinaryStrategyId,
  is_store : Bool,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr = validate_invalid_binary_simd_lane_memarg_prefix(is_store)
  instr.append([
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
  Ok(
    validate_invalid_binary_mutation(
      kind,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_simd_lane_memarg_offset_uleb(
  kind : ValidateInvalidBinaryStrategyId,
  is_store : Bool,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr = validate_invalid_binary_simd_lane_memarg_prefix(is_store)
  instr.append([
    (0x00).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
  Ok(
    validate_invalid_binary_mutation(
      kind,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_simd_lane_memarg_align_uleb(
  kind : ValidateInvalidBinaryStrategyId,
  is_store : Bool,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr = validate_invalid_binary_simd_lane_memarg_prefix(is_store)
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  instr.push((0x00).to_byte())
  instr.push((0x00).to_byte())
  Ok(
    validate_invalid_binary_mutation(
      kind,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_simd_lane_memarg_offset_uleb(
  kind : ValidateInvalidBinaryStrategyId,
  is_store : Bool,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr = validate_invalid_binary_simd_lane_memarg_prefix(is_store)
  instr.push((0x00).to_byte())
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  instr.push((0x00).to_byte())
  Ok(
    validate_invalid_binary_mutation(
      kind,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_data_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedDataIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfc).to_byte(),
        (0x09).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_data_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [(0xfc).to_byte(), (0x09).to_byte()]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideDataIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_malformed_data_segment_byte_count_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
    (0x07).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_malformed_data_segment_byte_count_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedDataSegmentByteCountUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_data_segment_byte_count_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_overwide_data_segment_byte_count_uleb() -> Bytes {
  let bytes : Array[Byte] = [
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
    (0x08).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
  ]
  bytes.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Bytes::from_array(bytes)
}

///|
fn validate_invalid_binary_mutate_overwide_data_segment_byte_count_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideDataSegmentByteCountUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_overwide_data_segment_byte_count_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_memory_init_data_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedMemoryInitDataIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfc).to_byte(),
        (0x08).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_memory_init_memory_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedMemoryInitMemoryIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfc).to_byte(),
        (0x08).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_memory_init_data_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [(0xfc).to_byte(), (0x08).to_byte()]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideMemoryInitDataIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_memory_init_memory_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [
    (0xfc).to_byte(),
    (0x08).to_byte(),
    (0x00).to_byte(),
  ]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideMemoryInitMemoryIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_elem_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedElemIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfc).to_byte(),
        (0x0d).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_elem_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [(0xfc).to_byte(), (0x0d).to_byte()]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideElemIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_table_init_elem_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedTableInitElemIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfc).to_byte(),
        (0x0c).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_table_init_table_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedTableInitTableIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfc).to_byte(),
        (0x0c).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_table_init_elem_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [(0xfc).to_byte(), (0x0c).to_byte()]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideTableInitElemIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_table_init_table_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [
    (0xfc).to_byte(),
    (0x0c).to_byte(),
    (0x00).to_byte(),
  ]
  instr.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideTableInitTableIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_malformed_data_segment_memory_index_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
    (0x07).to_byte(),
    (0x01).to_byte(),
    (0x02).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_malformed_element_segment_table_index_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x09).to_byte(),
    (0x07).to_byte(),
    (0x01).to_byte(),
    (0x02).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_malformed_data_segment_memory_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedDataSegmentMemoryIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_data_segment_memory_index_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_overwide_data_segment_memory_index_uleb() -> Bytes {
  let bytes : Array[Byte] = [
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
    (0x08).to_byte(),
    (0x01).to_byte(),
    (0x02).to_byte(),
  ]
  bytes.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Bytes::from_array(bytes)
}

///|
fn validate_invalid_binary_mutate_overwide_data_segment_memory_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideDataSegmentMemoryIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_overwide_data_segment_memory_index_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_element_segment_table_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedElementSegmentTableIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_element_segment_table_index_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_malformed_element_segment_func_index_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x09).to_byte(),
    (0x0b).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
    (0x01).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_malformed_element_segment_func_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedElementSegmentFuncIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_element_segment_func_index_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_overwide_element_segment_table_index_uleb() -> Bytes {
  let bytes : Array[Byte] = [
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x09).to_byte(),
    (0x0d).to_byte(),
    (0x01).to_byte(),
    (0x02).to_byte(),
  ]
  bytes.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Bytes::from_array(bytes)
}

///|
fn validate_invalid_binary_mutate_overwide_element_segment_table_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideElementSegmentTableIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_overwide_element_segment_table_index_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_overwide_element_segment_func_index_uleb() -> Bytes {
  let bytes : Array[Byte] = [
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x09).to_byte(),
    (0x11).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
    (0x01).to_byte(),
  ]
  bytes.append(validate_invalid_binary_overwide_u32_uleb_bytes())
  Bytes::from_array(bytes)
}

///|
fn validate_invalid_binary_mutate_overwide_element_segment_func_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideElementSegmentFuncIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_overwide_element_segment_func_index_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_invalid_name_section_func_name_utf8() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
    (0x04).to_byte(),
    (0x6e).to_byte(),
    (0x61).to_byte(),
    (0x6d).to_byte(),
    (0x65).to_byte(),
    (0x01).to_byte(),
    (0x05).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_malformed_name_section_func_name_length_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0e).to_byte(),
    (0x04).to_byte(),
    (0x6e).to_byte(),
    (0x61).to_byte(),
    (0x6d).to_byte(),
    (0x65).to_byte(),
    (0x01).to_byte(),
    (0x07).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_invalid_name_section_local_name_utf8() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0d).to_byte(),
    (0x04).to_byte(),
    (0x6e).to_byte(),
    (0x61).to_byte(),
    (0x6d).to_byte(),
    (0x65).to_byte(),
    (0x02).to_byte(),
    (0x06).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_malformed_name_section_local_name_length_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x10).to_byte(),
    (0x04).to_byte(),
    (0x6e).to_byte(),
    (0x61).to_byte(),
    (0x6d).to_byte(),
    (0x65).to_byte(),
    (0x02).to_byte(),
    (0x09).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_malformed_name_section_local_name_count_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0e).to_byte(),
    (0x04).to_byte(),
    (0x6e).to_byte(),
    (0x61).to_byte(),
    (0x6d).to_byte(),
    (0x65).to_byte(),
    (0x02).to_byte(),
    (0x07).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_overwide_name_section_local_name_count_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0f).to_byte(),
    (0x04).to_byte(),
    (0x6e).to_byte(),
    (0x61).to_byte(),
    (0x6d).to_byte(),
    (0x65).to_byte(),
    (0x02).to_byte(),
    (0x08).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_invalid_name_section_module_name_utf8() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x09).to_byte(),
    (0x04).to_byte(),
    (0x6e).to_byte(),
    (0x61).to_byte(),
    (0x6d).to_byte(),
    (0x65).to_byte(),
    (0x00).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_malformed_name_section_module_name_length_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0c).to_byte(),
    (0x04).to_byte(),
    (0x6e).to_byte(),
    (0x61).to_byte(),
    (0x6d).to_byte(),
    (0x65).to_byte(),
    (0x00).to_byte(),
    (0x05).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_invalid_name_section_type_name_utf8() -> Bytes {
  validate_invalid_binary_module_with_invalid_name_section_name_map_utf8(0x04)
}

///|
fn validate_invalid_binary_module_with_malformed_name_section_type_name_length_uleb() -> Bytes {
  validate_invalid_binary_module_with_malformed_name_section_name_map_length_uleb(
    0x04,
  )
}

///|
fn validate_invalid_binary_module_with_invalid_name_section_table_name_utf8() -> Bytes {
  validate_invalid_binary_module_with_invalid_name_section_name_map_utf8(0x05)
}

///|
fn validate_invalid_binary_module_with_malformed_name_section_table_name_length_uleb() -> Bytes {
  validate_invalid_binary_module_with_malformed_name_section_name_map_length_uleb(
    0x05,
  )
}

///|
fn validate_invalid_binary_module_with_invalid_name_section_memory_name_utf8() -> Bytes {
  validate_invalid_binary_module_with_invalid_name_section_name_map_utf8(0x06)
}

///|
fn validate_invalid_binary_module_with_malformed_name_section_memory_name_length_uleb() -> Bytes {
  validate_invalid_binary_module_with_malformed_name_section_name_map_length_uleb(
    0x06,
  )
}

///|
fn validate_invalid_binary_module_with_invalid_name_section_global_name_utf8() -> Bytes {
  validate_invalid_binary_module_with_invalid_name_section_name_map_utf8(0x07)
}

///|
fn validate_invalid_binary_module_with_malformed_name_section_global_name_length_uleb() -> Bytes {
  validate_invalid_binary_module_with_malformed_name_section_name_map_length_uleb(
    0x07,
  )
}

///|
fn validate_invalid_binary_module_with_invalid_name_section_elem_name_utf8() -> Bytes {
  validate_invalid_binary_module_with_invalid_name_section_name_map_utf8(0x08)
}

///|
fn validate_invalid_binary_module_with_malformed_name_section_elem_name_length_uleb() -> Bytes {
  validate_invalid_binary_module_with_malformed_name_section_name_map_length_uleb(
    0x08,
  )
}

///|
fn validate_invalid_binary_module_with_invalid_name_section_data_name_utf8() -> Bytes {
  validate_invalid_binary_module_with_invalid_name_section_name_map_utf8(0x09)
}

///|
fn validate_invalid_binary_module_with_malformed_name_section_data_name_length_uleb() -> Bytes {
  validate_invalid_binary_module_with_malformed_name_section_name_map_length_uleb(
    0x09,
  )
}

///|
fn validate_invalid_binary_module_with_invalid_name_section_field_name_utf8() -> Bytes {
  validate_invalid_binary_module_with_invalid_name_section_name_map_utf8(0x0a)
}

///|
fn validate_invalid_binary_module_with_malformed_name_section_field_name_length_uleb() -> Bytes {
  validate_invalid_binary_module_with_malformed_name_section_name_map_length_uleb(
    0x0a,
  )
}

///|
fn validate_invalid_binary_module_with_invalid_name_section_label_name_utf8() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0d).to_byte(),
    (0x04).to_byte(),
    (0x6e).to_byte(),
    (0x61).to_byte(),
    (0x6d).to_byte(),
    (0x65).to_byte(),
    (0x03).to_byte(),
    (0x06).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_malformed_name_section_label_name_length_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x10).to_byte(),
    (0x04).to_byte(),
    (0x6e).to_byte(),
    (0x61).to_byte(),
    (0x6d).to_byte(),
    (0x65).to_byte(),
    (0x03).to_byte(),
    (0x09).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_invalid_name_section_tag_name_utf8() -> Bytes {
  validate_invalid_binary_module_with_invalid_name_section_name_map_utf8(0x0b)
}

///|
fn validate_invalid_binary_module_with_malformed_name_section_tag_name_length_uleb() -> Bytes {
  validate_invalid_binary_module_with_malformed_name_section_name_map_length_uleb(
    0x0b,
  )
}

///|
fn validate_invalid_binary_module_with_overwide_name_section_type_name_length_uleb() -> Bytes {
  validate_invalid_binary_module_with_overwide_name_section_name_map_length_uleb(
    0x04,
  )
}

///|
fn validate_invalid_binary_module_with_overwide_name_section_table_name_length_uleb() -> Bytes {
  validate_invalid_binary_module_with_overwide_name_section_name_map_length_uleb(
    0x05,
  )
}

///|
fn validate_invalid_binary_module_with_overwide_name_section_memory_name_length_uleb() -> Bytes {
  validate_invalid_binary_module_with_overwide_name_section_name_map_length_uleb(
    0x06,
  )
}

///|
fn validate_invalid_binary_module_with_overwide_name_section_global_name_length_uleb() -> Bytes {
  validate_invalid_binary_module_with_overwide_name_section_name_map_length_uleb(
    0x07,
  )
}

///|
fn validate_invalid_binary_module_with_overwide_name_section_elem_name_length_uleb() -> Bytes {
  validate_invalid_binary_module_with_overwide_name_section_name_map_length_uleb(
    0x08,
  )
}

///|
fn validate_invalid_binary_module_with_overwide_name_section_data_name_length_uleb() -> Bytes {
  validate_invalid_binary_module_with_overwide_name_section_name_map_length_uleb(
    0x09,
  )
}

///|
fn validate_invalid_binary_module_with_overwide_name_section_field_name_length_uleb() -> Bytes {
  validate_invalid_binary_module_with_overwide_name_section_name_map_length_uleb(
    0x0a,
  )
}

///|
fn validate_invalid_binary_module_with_overwide_name_section_label_name_length_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x11).to_byte(),
    (0x04).to_byte(),
    (0x6e).to_byte(),
    (0x61).to_byte(),
    (0x6d).to_byte(),
    (0x65).to_byte(),
    (0x03).to_byte(),
    (0x0a).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_overwide_name_section_tag_name_length_uleb() -> Bytes {
  validate_invalid_binary_module_with_overwide_name_section_name_map_length_uleb(
    0x0b,
  )
}

///|
fn validate_invalid_binary_module_with_invalid_name_section_name_map_utf8(
  subsection_id : Int,
) -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
    (0x04).to_byte(),
    (0x6e).to_byte(),
    (0x61).to_byte(),
    (0x6d).to_byte(),
    (0x65).to_byte(),
    subsection_id.to_byte(),
    (0x05).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_malformed_name_section_name_map_length_uleb(
  subsection_id : Int,
) -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0e).to_byte(),
    (0x04).to_byte(),
    (0x6e).to_byte(),
    (0x61).to_byte(),
    (0x6d).to_byte(),
    (0x65).to_byte(),
    subsection_id.to_byte(),
    (0x07).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_overwide_name_section_func_name_length_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0f).to_byte(),
    (0x04).to_byte(),
    (0x6e).to_byte(),
    (0x61).to_byte(),
    (0x6d).to_byte(),
    (0x65).to_byte(),
    (0x01).to_byte(),
    (0x08).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_malformed_name_section_func_name_count_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0c).to_byte(),
    (0x04).to_byte(),
    (0x6e).to_byte(),
    (0x61).to_byte(),
    (0x6d).to_byte(),
    (0x65).to_byte(),
    (0x01).to_byte(),
    (0x05).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_overwide_name_section_func_name_count_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0d).to_byte(),
    (0x04).to_byte(),
    (0x6e).to_byte(),
    (0x61).to_byte(),
    (0x6d).to_byte(),
    (0x65).to_byte(),
    (0x01).to_byte(),
    (0x06).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_overwide_name_section_local_name_length_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x11).to_byte(),
    (0x04).to_byte(),
    (0x6e).to_byte(),
    (0x61).to_byte(),
    (0x6d).to_byte(),
    (0x65).to_byte(),
    (0x02).to_byte(),
    (0x0a).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_overwide_name_section_module_name_length_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0d).to_byte(),
    (0x04).to_byte(),
    (0x6e).to_byte(),
    (0x61).to_byte(),
    (0x6d).to_byte(),
    (0x65).to_byte(),
    (0x00).to_byte(),
    (0x06).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_malformed_name_section_name_map_count_uleb(
  subsection_id : Int,
) -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0c).to_byte(),
    (0x04).to_byte(),
    (0x6e).to_byte(),
    (0x61).to_byte(),
    (0x6d).to_byte(),
    (0x65).to_byte(),
    subsection_id.to_byte(),
    (0x05).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_overwide_name_section_name_map_count_uleb(
  subsection_id : Int,
) -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0d).to_byte(),
    (0x04).to_byte(),
    (0x6e).to_byte(),
    (0x61).to_byte(),
    (0x6d).to_byte(),
    (0x65).to_byte(),
    subsection_id.to_byte(),
    (0x06).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_malformed_name_section_type_name_count_uleb() -> Bytes {
  validate_invalid_binary_module_with_malformed_name_section_name_map_count_uleb(
    0x04,
  )
}

///|
fn validate_invalid_binary_module_with_overwide_name_section_type_name_count_uleb() -> Bytes {
  validate_invalid_binary_module_with_overwide_name_section_name_map_count_uleb(
    0x04,
  )
}

///|
fn validate_invalid_binary_module_with_malformed_name_section_table_name_count_uleb() -> Bytes {
  validate_invalid_binary_module_with_malformed_name_section_name_map_count_uleb(
    0x05,
  )
}

///|
fn validate_invalid_binary_module_with_overwide_name_section_table_name_count_uleb() -> Bytes {
  validate_invalid_binary_module_with_overwide_name_section_name_map_count_uleb(
    0x05,
  )
}

///|
fn validate_invalid_binary_module_with_malformed_name_section_memory_name_count_uleb() -> Bytes {
  validate_invalid_binary_module_with_malformed_name_section_name_map_count_uleb(
    0x06,
  )
}

///|
fn validate_invalid_binary_module_with_overwide_name_section_memory_name_count_uleb() -> Bytes {
  validate_invalid_binary_module_with_overwide_name_section_name_map_count_uleb(
    0x06,
  )
}

///|
fn validate_invalid_binary_module_with_malformed_name_section_global_name_count_uleb() -> Bytes {
  validate_invalid_binary_module_with_malformed_name_section_name_map_count_uleb(
    0x07,
  )
}

///|
fn validate_invalid_binary_module_with_overwide_name_section_global_name_count_uleb() -> Bytes {
  validate_invalid_binary_module_with_overwide_name_section_name_map_count_uleb(
    0x07,
  )
}

///|
fn validate_invalid_binary_module_with_malformed_name_section_elem_name_count_uleb() -> Bytes {
  validate_invalid_binary_module_with_malformed_name_section_name_map_count_uleb(
    0x08,
  )
}

///|
fn validate_invalid_binary_module_with_overwide_name_section_elem_name_count_uleb() -> Bytes {
  validate_invalid_binary_module_with_overwide_name_section_name_map_count_uleb(
    0x08,
  )
}

///|
fn validate_invalid_binary_module_with_overwide_name_section_name_map_length_uleb(
  subsection_id : Int,
) -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0f).to_byte(),
    (0x04).to_byte(),
    (0x6e).to_byte(),
    (0x61).to_byte(),
    (0x6d).to_byte(),
    (0x65).to_byte(),
    subsection_id.to_byte(),
    (0x08).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_invalid_name_section_func_name_utf8(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidNameSectionFuncNameUtf8,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_name_section_func_name_utf8(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_name_section_func_name_length_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedNameSectionFuncNameLengthUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_name_section_func_name_length_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_name_section_func_name_length_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideNameSectionFuncNameLengthUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_overwide_name_section_func_name_length_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_name_section_func_name_count_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedNameSectionFuncNameCountUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_name_section_func_name_count_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_name_section_func_name_count_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideNameSectionFuncNameCountUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_overwide_name_section_func_name_count_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_name_section_local_name_utf8(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidNameSectionLocalNameUtf8,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_name_section_local_name_utf8(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_name_section_local_name_length_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedNameSectionLocalNameLengthUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_name_section_local_name_length_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_name_section_local_name_length_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideNameSectionLocalNameLengthUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_overwide_name_section_local_name_length_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_name_section_local_name_count_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedNameSectionLocalNameCountUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_name_section_local_name_count_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_name_section_local_name_count_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideNameSectionLocalNameCountUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_overwide_name_section_local_name_count_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_name_section_module_name_utf8(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidNameSectionModuleNameUtf8,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_name_section_module_name_utf8(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_name_section_module_name_length_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedNameSectionModuleNameLengthUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_name_section_module_name_length_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_name_section_module_name_length_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideNameSectionModuleNameLengthUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_overwide_name_section_module_name_length_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_decode_rejected_bytes(
  strategy : ValidateInvalidBinaryStrategyId,
  bytes : Bytes,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(validate_invalid_binary_mutation(strategy, DecodeRejected, true, bytes))
}

///|
fn validate_invalid_binary_mutate_invalid_name_section_type_name_utf8(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidNameSectionTypeNameUtf8,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_name_section_type_name_utf8(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_name_section_type_name_length_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedNameSectionTypeNameLengthUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_name_section_type_name_length_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_name_section_table_name_utf8(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidNameSectionTableNameUtf8,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_name_section_table_name_utf8(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_name_section_table_name_length_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedNameSectionTableNameLengthUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_name_section_table_name_length_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_name_section_memory_name_utf8(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidNameSectionMemoryNameUtf8,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_name_section_memory_name_utf8(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_name_section_memory_name_length_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedNameSectionMemoryNameLengthUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_name_section_memory_name_length_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_name_section_global_name_utf8(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidNameSectionGlobalNameUtf8,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_name_section_global_name_utf8(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_name_section_global_name_length_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedNameSectionGlobalNameLengthUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_name_section_global_name_length_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_name_section_elem_name_utf8(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidNameSectionElemNameUtf8,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_name_section_elem_name_utf8(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_name_section_elem_name_length_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedNameSectionElemNameLengthUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_name_section_elem_name_length_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_name_section_data_name_utf8(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidNameSectionDataNameUtf8,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_name_section_data_name_utf8(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_name_section_data_name_length_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedNameSectionDataNameLengthUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_name_section_data_name_length_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_name_section_field_name_utf8(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidNameSectionFieldNameUtf8,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_name_section_field_name_utf8(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_name_section_field_name_length_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedNameSectionFieldNameLengthUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_name_section_field_name_length_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_name_section_label_name_utf8(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidNameSectionLabelNameUtf8,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_name_section_label_name_utf8(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_name_section_label_name_length_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedNameSectionLabelNameLengthUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_name_section_label_name_length_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_name_section_tag_name_utf8(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidNameSectionTagNameUtf8,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_name_section_tag_name_utf8(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_name_section_tag_name_length_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedNameSectionTagNameLengthUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_name_section_tag_name_length_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_invalid_functype_byte() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0xff).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_malformed_functype_param_count_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x07).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_malformed_functype_result_count_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x08).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_overwide_functype_param_count_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x08).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_overwide_functype_result_count_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x09).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_invalid_functype_param_valtype_byte() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x05).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x01).to_byte(),
    (0xff).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_invalid_functype_result_valtype_byte() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x05).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0xff).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_invalid_code_local_valtype_byte() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x03).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x0a).to_byte(),
    (0x06).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
    (0xff).to_byte(),
    (0x0b).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_invalid_functype_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidFuncTypeByte,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_functype_byte(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_functype_param_count_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedFuncTypeParamCountUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_functype_param_count_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_functype_result_count_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedFuncTypeResultCountUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_functype_result_count_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_functype_param_count_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideFuncTypeParamCountUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_overwide_functype_param_count_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_functype_result_count_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideFuncTypeResultCountUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_overwide_functype_result_count_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_functype_param_valtype_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidFuncTypeParamValTypeByte,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_functype_param_valtype_byte(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_functype_result_valtype_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidFuncTypeResultValTypeByte,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_functype_result_valtype_byte(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_code_local_valtype_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidCodeLocalValTypeByte,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_code_local_valtype_byte(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_malformed_code_local_decl_count_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x03).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x0a).to_byte(),
    (0x07).to_byte(),
    (0x01).to_byte(),
    (0x05).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_malformed_code_local_decl_count_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedCodeLocalDeclCountUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_code_local_decl_count_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_malformed_code_local_run_count_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x03).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x0a).to_byte(),
    (0x08).to_byte(),
    (0x01).to_byte(),
    (0x06).to_byte(),
    (0x01).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_malformed_code_local_run_count_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedCodeLocalRunCountUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_code_local_run_count_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_overwide_code_local_decl_count_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x03).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x0a).to_byte(),
    (0x08).to_byte(),
    (0x01).to_byte(),
    (0x06).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_overwide_code_local_decl_count_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideCodeLocalDeclCountUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_overwide_code_local_decl_count_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_overwide_code_local_run_count_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x03).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x0a).to_byte(),
    (0x09).to_byte(),
    (0x01).to_byte(),
    (0x07).to_byte(),
    (0x01).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_overwide_code_local_run_count_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideCodeLocalRunCountUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_overwide_code_local_run_count_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_malformed_section_count_uleb(
  section_id : Int,
) -> Bytes {
  let out : Array[Byte] = [
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
  ]
  out.push(section_id.to_byte())
  out.push((0x05).to_byte())
  out.push((0x80).to_byte())
  out.push((0x80).to_byte())
  out.push((0x80).to_byte())
  out.push((0x80).to_byte())
  out.push((0x80).to_byte())
  Bytes::from_array(out)
}

///|
fn validate_invalid_binary_module_with_malformed_type_section_count_uleb() -> Bytes {
  validate_invalid_binary_module_with_malformed_section_count_uleb(0x01)
}

///|
fn validate_invalid_binary_module_with_malformed_code_section_count_uleb() -> Bytes {
  validate_invalid_binary_module_with_malformed_section_count_uleb(0x0a)
}

///|
fn validate_invalid_binary_module_with_overwide_section_count_uleb(
  section_id : Int,
) -> Bytes {
  let out : Array[Byte] = [
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
  ]
  out.push(section_id.to_byte())
  out.push((0x06).to_byte())
  out.push((0x80).to_byte())
  out.push((0x80).to_byte())
  out.push((0x80).to_byte())
  out.push((0x80).to_byte())
  out.push((0x80).to_byte())
  out.push((0x00).to_byte())
  Bytes::from_array(out)
}

///|
fn validate_invalid_binary_module_with_type_section_count_underflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x07).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_code_section_count_underflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x03).to_byte(),
    (0x03).to_byte(),
    (0x02).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0a).to_byte(),
    (0x07).to_byte(),
    (0x01).to_byte(),
    (0x02).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
    (0x02).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_type_section_count_underflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      TypeSectionCountUnderflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_type_section_count_underflow(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_code_section_count_underflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      CodeSectionCountUnderflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_code_section_count_underflow(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_import_section_count_underflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x02).to_byte(),
    (0x0d).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x66).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x6e).to_byte(),
    (0x01).to_byte(),
    (0x67).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_export_section_count_underflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x03).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x07).to_byte(),
    (0x09).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
    (0x78).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x79).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0a).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x02).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_import_section_count_underflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      ImportSectionCountUnderflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_import_section_count_underflow(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_export_section_count_underflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      ExportSectionCountUnderflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_export_section_count_underflow(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_table_section_count_underflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x04).to_byte(),
    (0x07).to_byte(),
    (0x01).to_byte(),
    (0x70).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x70).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_memory_section_count_underflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x05).to_byte(),
    (0x05).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_global_section_count_underflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x06).to_byte(),
    (0x0b).to_byte(),
    (0x01).to_byte(),
    (0x7f).to_byte(),
    (0x00).to_byte(),
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
    (0x7f).to_byte(),
    (0x00).to_byte(),
    (0x41).to_byte(),
    (0x01).to_byte(),
    (0x0b).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_table_section_count_underflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      TableSectionCountUnderflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_table_section_count_underflow(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_memory_section_count_underflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MemorySectionCountUnderflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_memory_section_count_underflow(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_global_section_count_underflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      GlobalSectionCountUnderflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_global_section_count_underflow(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_function_section_count_underflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x03).to_byte(),
    (0x03).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_element_section_count_underflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x09).to_byte(),
    (0x07).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_data_section_count_underflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
    (0x05).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_tag_section_count_underflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0d).to_byte(),
    (0x05).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_function_section_count_underflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      FunctionSectionCountUnderflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_function_section_count_underflow(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_element_section_count_underflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      ElementSectionCountUnderflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_element_section_count_underflow(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_data_section_count_underflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      DataSectionCountUnderflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_data_section_count_underflow(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_tag_section_count_underflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      TagSectionCountUnderflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_tag_section_count_underflow(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_type_section_size_underflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x03).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_code_body_size_underflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x03).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x0a).to_byte(),
    (0x03).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_type_section_size_underflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      TypeSectionSizeUnderflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_type_section_size_underflow(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_code_body_size_underflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      CodeBodySizeUnderflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_code_body_size_underflow(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_malformed_code_body_size_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x03).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x0a).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_malformed_code_body_size_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedCodeBodySizeUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_code_body_size_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_overwide_code_body_size_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x03).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x0a).to_byte(),
    (0x07).to_byte(),
    (0x01).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_import_section_size_underflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x02).to_byte(),
    (0x06).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x66).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_export_section_size_underflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x03).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x07).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
    (0x78).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_import_section_size_underflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      ImportSectionSizeUnderflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_import_section_size_underflow(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_export_section_size_underflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      ExportSectionSizeUnderflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_export_section_size_underflow(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_table_section_size_underflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x04).to_byte(),
    (0x03).to_byte(),
    (0x01).to_byte(),
    (0x70).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_memory_section_size_underflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x05).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_global_section_size_underflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x06).to_byte(),
    (0x05).to_byte(),
    (0x01).to_byte(),
    (0x7f).to_byte(),
    (0x00).to_byte(),
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_table_section_size_underflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      TableSectionSizeUnderflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_table_section_size_underflow(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_memory_section_size_underflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MemorySectionSizeUnderflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_memory_section_size_underflow(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_global_section_size_underflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      GlobalSectionSizeUnderflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_global_section_size_underflow(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_function_section_size_underflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x03).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_element_section_size_underflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x09).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_data_section_size_underflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_tag_section_size_underflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0d).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_function_section_size_underflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      FunctionSectionSizeUnderflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_function_section_size_underflow(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_element_section_size_underflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      ElementSectionSizeUnderflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_element_section_size_underflow(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_data_section_size_underflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      DataSectionSizeUnderflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_data_section_size_underflow(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_tag_section_size_underflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      TagSectionSizeUnderflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_tag_section_size_underflow(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_type_section_size_overflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x05).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_import_section_size_overflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x02).to_byte(),
    (0x08).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x66).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_type_section_size_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      TypeSectionSizeOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_type_section_size_overflow(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_code_section_size_overflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x03).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x0a).to_byte(),
    (0x05).to_byte(),
    (0x01).to_byte(),
    (0x02).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_code_section_size_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      CodeSectionSizeOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_code_section_size_overflow(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_import_section_size_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      ImportSectionSizeOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_import_section_size_overflow(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_export_section_size_overflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x03).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x07).to_byte(),
    (0x06).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
    (0x78).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_table_section_size_overflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x04).to_byte(),
    (0x05).to_byte(),
    (0x01).to_byte(),
    (0x70).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_memory_section_size_overflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x05).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_global_section_size_overflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x06).to_byte(),
    (0x07).to_byte(),
    (0x01).to_byte(),
    (0x7f).to_byte(),
    (0x00).to_byte(),
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_export_section_size_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      ExportSectionSizeOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_export_section_size_overflow(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_table_section_size_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      TableSectionSizeOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_table_section_size_overflow(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_memory_section_size_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MemorySectionSizeOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_memory_section_size_overflow(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_global_section_size_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      GlobalSectionSizeOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_global_section_size_overflow(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_function_section_size_overflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x03).to_byte(),
    (0x03).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_element_section_size_overflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x09).to_byte(),
    (0x03).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_data_section_size_overflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
    (0x03).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_tag_section_size_overflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0d).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_function_section_size_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      FunctionSectionSizeOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_function_section_size_overflow(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_element_section_size_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      ElementSectionSizeOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_element_section_size_overflow(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_data_section_size_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      DataSectionSizeOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_data_section_size_overflow(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_tag_section_size_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      TagSectionSizeOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_tag_section_size_overflow(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_start_section_size_underflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x08).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_datacount_section_size_underflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0c).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_start_section_size_overflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x08).to_byte(),
    (0x02).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_datacount_section_size_overflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0c).to_byte(),
    (0x02).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_start_section_size_underflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      StartSectionSizeUnderflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_start_section_size_underflow(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_datacount_section_size_underflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      DataCountSectionSizeUnderflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_datacount_section_size_underflow(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_start_section_size_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      StartSectionSizeOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_start_section_size_overflow(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_datacount_section_size_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      DataCountSectionSizeOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_datacount_section_size_overflow(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_invalid_export_name_utf8() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x03).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x07).to_byte(),
    (0x05).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
    (0x80).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0a).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x02).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_malformed_export_name_length_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x07).to_byte(),
    (0x06).to_byte(),
    (0x01).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_overwide_export_name_length_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x07).to_byte(),
    (0x07).to_byte(),
    (0x01).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_invalid_import_module_name_utf8() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x02).to_byte(),
    (0x07).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
    (0x80).to_byte(),
    (0x01).to_byte(),
    (0x78).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_invalid_export_name_utf8(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidExportNameUtf8,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_export_name_utf8(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_export_name_length_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedExportNameLengthUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_export_name_length_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_export_name_length_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideExportNameLengthUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_overwide_export_name_length_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_import_module_name_utf8(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidImportModuleNameUtf8,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_import_module_name_utf8(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_malformed_import_module_name_length_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x02).to_byte(),
    (0x06).to_byte(),
    (0x01).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_overwide_import_module_name_length_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x02).to_byte(),
    (0x07).to_byte(),
    (0x01).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_malformed_import_module_name_length_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedImportModuleNameLengthUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_import_module_name_length_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_import_module_name_length_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideImportModuleNameLengthUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_overwide_import_module_name_length_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_invalid_import_field_name_utf8() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x02).to_byte(),
    (0x07).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x80).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_malformed_import_field_name_length_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x02).to_byte(),
    (0x08).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
    (0x6d).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_overwide_import_field_name_length_uleb() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x02).to_byte(),
    (0x09).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
    (0x6d).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_invalid_import_kind_byte() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x02).to_byte(),
    (0x07).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x78).to_byte(),
    (0xff).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_invalid_import_field_name_utf8(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidImportFieldNameUtf8,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_import_field_name_utf8(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_import_field_name_length_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedImportFieldNameLengthUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_import_field_name_length_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_import_field_name_length_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideImportFieldNameLengthUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_overwide_import_field_name_length_uleb(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_import_kind_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidImportKindByte,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_import_kind_byte(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_function_section_type_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedFunctionSectionTypeIndexUleb,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x03).to_byte(),
        (0x06).to_byte(),
        (0x01).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_function_section_type_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideFunctionSectionTypeIndexUleb,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x03).to_byte(),
        (0x07).to_byte(),
        (0x01).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x00).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_import_func_type_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedImportFuncTypeIndexUleb,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x02).to_byte(),
        (0x0b).to_byte(),
        (0x01).to_byte(),
        (0x01).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x66).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_import_func_type_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideImportFuncTypeIndexUleb,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x02).to_byte(),
        (0x0c).to_byte(),
        (0x01).to_byte(),
        (0x01).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x66).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x00).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_import_table_reftype_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidImportTableRefTypeByte,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x02).to_byte(),
        (0x09).to_byte(),
        (0x01).to_byte(),
        (0x01).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x74).to_byte(),
        (0x01).to_byte(),
        (0xff).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_import_memory_min_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedImportMemoryMinUleb,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x02).to_byte(),
        (0x0c).to_byte(),
        (0x01).to_byte(),
        (0x01).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x78).to_byte(),
        (0x02).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_import_table_min_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedImportTableMinUleb,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x02).to_byte(),
        (0x0d).to_byte(),
        (0x01).to_byte(),
        (0x01).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x74).to_byte(),
        (0x01).to_byte(),
        (0x70).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_import_memory_max_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedImportMemoryMaxUleb,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x02).to_byte(),
        (0x0d).to_byte(),
        (0x01).to_byte(),
        (0x01).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x78).to_byte(),
        (0x02).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_import_table_max_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedImportTableMaxUleb,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x02).to_byte(),
        (0x0e).to_byte(),
        (0x01).to_byte(),
        (0x01).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x74).to_byte(),
        (0x01).to_byte(),
        (0x70).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_import_memory_min_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideImportMemoryMinUleb,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x02).to_byte(),
        (0x12).to_byte(),
        (0x01).to_byte(),
        (0x01).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x78).to_byte(),
        (0x02).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x00).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_import_table_min_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideImportTableMinUleb,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x02).to_byte(),
        (0x13).to_byte(),
        (0x01).to_byte(),
        (0x01).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x74).to_byte(),
        (0x01).to_byte(),
        (0x70).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x00).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_import_memory_max_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideImportMemoryMaxUleb,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x02).to_byte(),
        (0x13).to_byte(),
        (0x01).to_byte(),
        (0x01).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x78).to_byte(),
        (0x02).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x00).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_import_table_max_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideImportTableMaxUleb,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x02).to_byte(),
        (0x14).to_byte(),
        (0x01).to_byte(),
        (0x01).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x74).to_byte(),
        (0x01).to_byte(),
        (0x70).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x00).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_import_memory_limits_flag_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidImportMemoryLimitsFlagByte,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x02).to_byte(),
        (0x07).to_byte(),
        (0x01).to_byte(),
        (0x01).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x78).to_byte(),
        (0x02).to_byte(),
        (0xff).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_import_global_valtype_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidImportGlobalValTypeByte,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x02).to_byte(),
        (0x08).to_byte(),
        (0x01).to_byte(),
        (0x01).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x67).to_byte(),
        (0x03).to_byte(),
        (0xff).to_byte(),
        (0x00).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_import_global_mutability_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidImportGlobalMutabilityByte,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x02).to_byte(),
        (0x08).to_byte(),
        (0x01).to_byte(),
        (0x01).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x67).to_byte(),
        (0x03).to_byte(),
        (0x7f).to_byte(),
        (0xff).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_import_tag_type_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedImportTagTypeIndexUleb,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x02).to_byte(),
        (0x0c).to_byte(),
        (0x01).to_byte(),
        (0x01).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x74).to_byte(),
        (0x04).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_import_tag_attribute_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidImportTagAttributeByte,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x02).to_byte(),
        (0x09).to_byte(),
        (0x01).to_byte(),
        (0x01).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x74).to_byte(),
        (0x04).to_byte(),
        (0xff).to_byte(),
        (0x00).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_invalid_table_reftype_byte() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x04).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0xff).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_overwide_import_tag_type_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideImportTagTypeIndexUleb,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x02).to_byte(),
        (0x0d).to_byte(),
        (0x01).to_byte(),
        (0x01).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x74).to_byte(),
        (0x04).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x00).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_table_reftype_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidTableRefTypeByte,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_table_reftype_byte(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_invalid_table_limits_flag_byte() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x04).to_byte(),
    (0x03).to_byte(),
    (0x01).to_byte(),
    (0x70).to_byte(),
    (0xff).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_invalid_table_limits_flag_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidTableLimitsFlagByte,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_table_limits_flag_byte(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_ref_null_heaptype_immediate(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedRefNullHeaptypeImmediate,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xd0).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_ref_cast_heaptype_immediate(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedRefCastHeaptypeImmediate,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfb).to_byte(),
        (0x16).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_ref_test_heaptype_immediate(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedRefTestHeaptypeImmediate,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr([
        (0xfb).to_byte(),
        (0x14).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_overwide_heaptype_bytes() -> Array[Byte] {
  [
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x00).to_byte(),
  ]
}

///|
fn validate_invalid_binary_mutate_overwide_ref_null_heaptype_immediate(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [(0xd0).to_byte()]
  instr.append(validate_invalid_binary_overwide_heaptype_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideRefNullHeaptypeImmediate,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_ref_cast_heaptype_immediate(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [(0xfb).to_byte(), (0x16).to_byte()]
  instr.append(validate_invalid_binary_overwide_heaptype_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideRefCastHeaptypeImmediate,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_ref_test_heaptype_immediate(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let instr : Array[Byte] = [(0xfb).to_byte(), (0x14).to_byte()]
  instr.append(validate_invalid_binary_overwide_heaptype_bytes())
  Ok(
    validate_invalid_binary_mutation(
      OverwideRefTestHeaptypeImmediate,
      DecodeRejected,
      true,
      validate_invalid_binary_minimal_code_with_instr(instr),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_invalid_global_valtype_byte() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x06).to_byte(),
    (0x06).to_byte(),
    (0x01).to_byte(),
    (0xff).to_byte(),
    (0x00).to_byte(),
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_invalid_global_valtype_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidGlobalValTypeByte,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_global_valtype_byte(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_invalid_export_kind_byte() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x03).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x07).to_byte(),
    (0x06).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
    (0x78).to_byte(),
    (0xff).to_byte(),
    (0x00).to_byte(),
    (0x0a).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x02).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_invalid_export_kind_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidExportKindByte,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_export_kind_byte(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_invalid_memory_limits_flag_byte() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x05).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0xff).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_invalid_memory_limits_flag_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidMemoryLimitsFlagByte,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_memory_limits_flag_byte(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_invalid_tag_attribute_byte() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0d).to_byte(),
    (0x03).to_byte(),
    (0x01).to_byte(),
    (0xff).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_invalid_tag_attribute_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidTagAttributeByte,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_tag_attribute_byte(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_invalid_global_mutability_byte() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x06).to_byte(),
    (0x06).to_byte(),
    (0x01).to_byte(),
    (0x7f).to_byte(),
    (0xff).to_byte(),
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_invalid_global_mutability_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidGlobalMutabilityByte,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_global_mutability_byte(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_malformed_export_index_uleb(
  kind : Byte,
) -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x07).to_byte(),
    (0x05).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
    (0x78).to_byte(),
    kind,
    (0x80).to_byte(),
  ])
}

///|
fn validate_invalid_binary_module_with_overwide_export_index_uleb(
  kind : Byte,
) -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x07).to_byte(),
    (0x0a).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
    (0x78).to_byte(),
    kind,
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_malformed_export_func_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedExportFuncIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_export_index_uleb(
        (0x00).to_byte(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_export_table_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedExportTableIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_export_index_uleb(
        (0x01).to_byte(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_export_memory_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedExportMemoryIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_export_index_uleb(
        (0x02).to_byte(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_export_global_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedExportGlobalIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_export_index_uleb(
        (0x03).to_byte(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_export_tag_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedExportTagIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_malformed_export_index_uleb(
        (0x04).to_byte(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_export_func_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideExportFuncIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_overwide_export_index_uleb(
        (0x00).to_byte(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_export_table_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideExportTableIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_overwide_export_index_uleb(
        (0x01).to_byte(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_export_memory_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideExportMemoryIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_overwide_export_index_uleb(
        (0x02).to_byte(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_export_global_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideExportGlobalIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_overwide_export_index_uleb(
        (0x03).to_byte(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_overwide_export_tag_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      OverwideExportTagIndexUleb,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_overwide_export_index_uleb(
        (0x04).to_byte(),
      ),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_invalid_element_segment_flag_byte() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x09).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0x7f).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_invalid_element_segment_flag_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidElementSegmentFlagByte,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_element_segment_flag_byte(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_invalid_element_kind_byte() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x09).to_byte(),
    (0x03).to_byte(),
    (0x01).to_byte(),
    (0x01).to_byte(),
    (0xff).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_invalid_element_kind_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidElementKindByte,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_element_kind_byte(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_invalid_data_segment_flag_byte() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0x7f).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_invalid_data_segment_flag_byte(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      InvalidDataSegmentFlagByte,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_invalid_data_segment_flag_byte(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_type_section_count_overflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x02).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_type_section_count_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      TypeSectionCountOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_type_section_count_overflow(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_code_section_count_overflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x03).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x0a).to_byte(),
    (0x04).to_byte(),
    (0x02).to_byte(),
    (0x02).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_code_section_count_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      CodeSectionCountOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_code_section_count_overflow(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_table_section_count_overflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x04).to_byte(),
    (0x04).to_byte(),
    (0x02).to_byte(),
    (0x70).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_table_section_count_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      TableSectionCountOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_table_section_count_overflow(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_export_section_count_overflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x03).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x07).to_byte(),
    (0x06).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0x78).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0a).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x02).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_export_section_count_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      ExportSectionCountOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_export_section_count_overflow(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_import_section_count_overflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x02).to_byte(),
    (0x08).to_byte(),
    (0x02).to_byte(),
    (0x01).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x66).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_import_section_count_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      ImportSectionCountOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_import_section_count_overflow(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_global_section_count_overflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x06).to_byte(),
    (0x06).to_byte(),
    (0x02).to_byte(),
    (0x7f).to_byte(),
    (0x00).to_byte(),
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_global_section_count_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      GlobalSectionCountOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_global_section_count_overflow(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_function_section_count_overflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x03).to_byte(),
    (0x02).to_byte(),
    (0x02).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_function_section_count_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      FunctionSectionCountOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_function_section_count_overflow(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_memory_section_count_overflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x05).to_byte(),
    (0x03).to_byte(),
    (0x02).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_memory_section_count_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MemorySectionCountOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_memory_section_count_overflow(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_element_section_count_overflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x09).to_byte(),
    (0x06).to_byte(),
    (0x02).to_byte(),
    (0x00).to_byte(),
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_element_section_count_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      ElementSectionCountOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_element_section_count_overflow(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_data_section_count_overflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
    (0x06).to_byte(),
    (0x02).to_byte(),
    (0x00).to_byte(),
    (0x41).to_byte(),
    (0x00).to_byte(),
    (0x0b).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_data_section_count_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      DataSectionCountOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_data_section_count_overflow(),
    ),
  )
}

///|
fn validate_invalid_binary_module_with_tag_section_count_overflow() -> Bytes {
  Bytes::from_array([
    (0x00).to_byte(),
    (0x61).to_byte(),
    (0x73).to_byte(),
    (0x6d).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x01).to_byte(),
    (0x04).to_byte(),
    (0x01).to_byte(),
    (0x60).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x0d).to_byte(),
    (0x03).to_byte(),
    (0x02).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
  ])
}

///|
fn validate_invalid_binary_mutate_tag_section_count_overflow(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      TagSectionCountOverflow,
      DecodeRejected,
      true,
      validate_invalid_binary_module_with_tag_section_count_overflow(),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_malformed_tag_type_index_uleb(
  _mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  Ok(
    validate_invalid_binary_mutation(
      MalformedTagTypeIndexUleb,
      DecodeRejected,
      true,
      Bytes::from_array([
        (0x00).to_byte(),
        (0x61).to_byte(),
        (0x73).to_byte(),
        (0x6d).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x00).to_byte(),
        (0x0d).to_byte(),
        (0x07).to_byte(),
        (0x01).to_byte(),
        (0x00).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
        (0x80).to_byte(),
      ]),
    ),
  )
}

///|
fn validate_invalid_binary_mutate_invalid_func_type_index(
  mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let encoded = match validate_invalid_binary_encode_seed_module(mod) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let spans = match validate_invalid_binary_scan_sections(encoded) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let type_span = match validate_invalid_binary_find_section(spans, 1) {
    Some(span) => span
    None =>
      return Ok(
        validate_invalid_binary_mutation(
          InvalidFuncTypeIndex,
          ValidateRejected("function"),
          false,
          encoded,
        ),
      )
  }
  let func_span = match validate_invalid_binary_find_section(spans, 3) {
    Some(span) => span
    None =>
      return Ok(
        validate_invalid_binary_mutation(
          InvalidFuncTypeIndex,
          ValidateRejected("function"),
          false,
          encoded,
        ),
      )
  }
  let (type_count, _) = match
    validate_invalid_binary_decode_uleb(
      encoded,
      type_span.payload_start,
      type_span.end,
    ) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let (func_count, first_idx_start) = match
    validate_invalid_binary_decode_uleb(
      encoded,
      func_span.payload_start,
      func_span.end,
    ) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  if func_count == 0 {
    return Ok(
      validate_invalid_binary_mutation(
        InvalidFuncTypeIndex,
        ValidateRejected("function"),
        false,
        encoded,
      ),
    )
  }
  let (_, first_idx_end) = match
    validate_invalid_binary_decode_uleb(encoded, first_idx_start, func_span.end) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let replacement = validate_invalid_binary_encode_uleb(type_count)
  if replacement.length() != first_idx_end - first_idx_start {
    return Ok(
      validate_invalid_binary_mutation(
        InvalidFuncTypeIndex,
        ValidateRejected("function"),
        false,
        encoded,
      ),
    )
  }
  Ok(
    validate_invalid_binary_mutation(
      InvalidFuncTypeIndex,
      ValidateRejected("function"),
      true,
      validate_invalid_binary_replace_range(
        encoded, first_idx_start, first_idx_end, replacement,
      ),
    ),
  )
}

///|
fn validate_invalid_binary_required_ast_strategy(
  stable_id : String,
) -> Result[ValidateInvalidAstStrategyId, String] {
  match validate_invalid_ast_strategy_by_stable_id(stable_id) {
    Some(spec) => Ok(spec.id)
    None => Err("missing validate-invalid-ast strategy '\{stable_id}'")
  }
}

///|
fn validate_invalid_binary_mutate_encoded_invalid_ast_module(
  binary_strategy : ValidateInvalidBinaryStrategyId,
  ast_strategy : ValidateInvalidAstStrategyId,
  expected_family : String,
  mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let mutation = match apply_validate_invalid_ast_strategy(ast_strategy, mod) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let mutated_bytes = match encode_module(mutation.mutated_module) {
    Ok(v) => v
    Err(msg) => return Err("\{msg}")
  }
  Ok(
    validate_invalid_binary_mutation(
      binary_strategy,
      ValidateRejected(expected_family),
      mutation.applicable,
      mutated_bytes,
    ),
  )
}

///|
pub fn apply_validate_invalid_binary_strategy(
  strategy : ValidateInvalidBinaryStrategyId,
  mod : Module,
) -> Result[ValidateInvalidBinaryMutation, String] {
  let base = match validate_module(mod) {
    Ok(_) => mod
    Err(err) =>
      return Err(
        "validate-invalid-binary requires a valid base module before corruption: \{validation_error_message(err)}",
      )
  }
  match strategy {
    TrailingGarbage => validate_invalid_binary_mutate_trailing_garbage(base)
    TruncatedModule => validate_invalid_binary_mutate_truncated_module(base)
    DuplicateTypeSection =>
      validate_invalid_binary_mutate_duplicate_type_section(base)
    DuplicateImportSection =>
      validate_invalid_binary_mutate_duplicate_import_section(base)
    DuplicateExportSection =>
      validate_invalid_binary_mutate_duplicate_export_section(base)
    DuplicateTableSection =>
      validate_invalid_binary_mutate_duplicate_table_section(base)
    DuplicateMemorySection =>
      validate_invalid_binary_mutate_duplicate_memory_section(base)
    DuplicateGlobalSection =>
      validate_invalid_binary_mutate_duplicate_global_section(base)
    DuplicateFunctionSection =>
      validate_invalid_binary_mutate_duplicate_function_section(base)
    DuplicateCodeSection =>
      validate_invalid_binary_mutate_duplicate_code_section(base)
    DuplicateElementSection =>
      validate_invalid_binary_mutate_duplicate_element_section(base)
    DuplicateDataSection =>
      validate_invalid_binary_mutate_duplicate_data_section(base)
    DuplicateTagSection =>
      validate_invalid_binary_mutate_duplicate_tag_section(base)
    DuplicateStartSection =>
      validate_invalid_binary_mutate_duplicate_start_section(base)
    WrongSectionOrder =>
      validate_invalid_binary_mutate_wrong_section_order(base)
    InvalidFuncTypeIndex =>
      validate_invalid_binary_mutate_invalid_func_type_index(base)
    BadMagicHeader => validate_invalid_binary_mutate_bad_magic_header(base)
    BadVersionHeader => validate_invalid_binary_mutate_bad_version_header(base)
    MalformedSectionSizeUleb =>
      validate_invalid_binary_mutate_malformed_section_size_uleb(base)
    OverwideSectionSizeUleb =>
      validate_invalid_binary_mutate_overwide_section_size_uleb(base)
    SectionPayloadLengthOverflow =>
      validate_invalid_binary_mutate_section_payload_length_overflow(base)
    SectionPayloadLengthUnderflow =>
      validate_invalid_binary_mutate_section_payload_length_underflow(base)
    ReservedSectionId =>
      validate_invalid_binary_mutate_reserved_section_id(base)
    InvalidCustomSectionNameUtf8 =>
      validate_invalid_binary_mutate_invalid_custom_section_name_utf8(base)
    MalformedSimdImmediate =>
      validate_invalid_binary_mutate_malformed_simd_immediate(base)
    SimdLaneIndexOverflow =>
      validate_invalid_binary_mutate_simd_lane_index_overflow(base)
    MalformedCustomSectionPayload =>
      validate_invalid_binary_mutate_malformed_custom_section_payload(base)
    MalformedCustomSectionNameLengthUleb =>
      validate_invalid_binary_mutate_malformed_custom_section_name_length_uleb(
        base,
      )
    OverwideCustomSectionNameLengthUleb =>
      validate_invalid_binary_mutate_overwide_custom_section_name_length_uleb(
        base,
      )
    MalformedNameSubsectionSizeUleb =>
      validate_invalid_binary_mutate_malformed_name_subsection_size_uleb(base)
    OverwideNameSubsectionSizeUleb =>
      validate_invalid_binary_mutate_overwide_name_subsection_size_uleb(base)
    InvalidNameSubsectionIdByte =>
      validate_invalid_binary_mutate_invalid_name_subsection_id_byte(base)
    OutOfOrderNameSubsectionId =>
      validate_invalid_binary_mutate_out_of_order_name_subsection_id(base)
    InvalidOpcodeByte =>
      validate_invalid_binary_mutate_invalid_opcode_byte(base)
    InvalidPrefixSubopcodeByte =>
      validate_invalid_binary_mutate_invalid_prefix_subopcode_byte(base)
    InvalidGcPrefixSubopcodeByte =>
      validate_invalid_binary_mutate_invalid_gc_prefix_subopcode_byte(base)
    InvalidBulkPrefixSubopcodeByte =>
      validate_invalid_binary_mutate_invalid_bulk_prefix_subopcode_byte(base)
    InvalidSimdPrefixSubopcodeByte =>
      validate_invalid_binary_mutate_invalid_simd_prefix_subopcode_byte(base)
    MalformedGcPrefixSubopcodeUleb =>
      validate_invalid_binary_mutate_malformed_gc_prefix_subopcode_uleb(base)
    MalformedBulkPrefixSubopcodeUleb =>
      validate_invalid_binary_mutate_malformed_bulk_prefix_subopcode_uleb(base)
    MalformedSimdPrefixSubopcodeUleb =>
      validate_invalid_binary_mutate_malformed_simd_prefix_subopcode_uleb(base)
    MalformedAtomicPrefixSubopcodeUleb =>
      validate_invalid_binary_mutate_malformed_atomic_prefix_subopcode_uleb(
        base,
      )
    InvalidAtomicPrefixSubopcodeByte =>
      validate_invalid_binary_mutate_invalid_atomic_prefix_subopcode_byte(base)
    OverwideGcPrefixSubopcodeUleb =>
      validate_invalid_binary_mutate_overwide_gc_prefix_subopcode_uleb(base)
    OverwideBulkPrefixSubopcodeUleb =>
      validate_invalid_binary_mutate_overwide_bulk_prefix_subopcode_uleb(base)
    OverwideSimdPrefixSubopcodeUleb =>
      validate_invalid_binary_mutate_overwide_simd_prefix_subopcode_uleb(base)
    OverwideAtomicPrefixSubopcodeUleb =>
      validate_invalid_binary_mutate_overwide_atomic_prefix_subopcode_uleb(base)
    MalformedAtomicLoadMemargAlignUleb =>
      validate_invalid_binary_mutate_malformed_atomic_load_memarg_align_uleb(
        base,
      )
    MalformedAtomicStoreMemargAlignUleb =>
      validate_invalid_binary_mutate_malformed_atomic_store_memarg_align_uleb(
        base,
      )
    MalformedAtomicLoadMemargOffsetUleb =>
      validate_invalid_binary_mutate_malformed_atomic_load_memarg_offset_uleb(
        base,
      )
    MalformedAtomicStoreMemargOffsetUleb =>
      validate_invalid_binary_mutate_malformed_atomic_store_memarg_offset_uleb(
        base,
      )
    MalformedAtomicNotifyMemargAlignUleb =>
      validate_invalid_binary_mutate_malformed_atomic_notify_memarg_align_uleb(
        base,
      )
    MalformedAtomicNotifyMemargOffsetUleb =>
      validate_invalid_binary_mutate_malformed_atomic_notify_memarg_offset_uleb(
        base,
      )
    MalformedAtomicWaitMemargAlignUleb =>
      validate_invalid_binary_mutate_malformed_atomic_wait_memarg_align_uleb(
        base,
      )
    MalformedAtomicWaitMemargOffsetUleb =>
      validate_invalid_binary_mutate_malformed_atomic_wait_memarg_offset_uleb(
        base,
      )
    MalformedAtomicRmwMemargAlignUleb =>
      validate_invalid_binary_mutate_malformed_atomic_rmw_memarg_align_uleb(
        base,
      )
    MalformedAtomicRmwMemargOffsetUleb =>
      validate_invalid_binary_mutate_malformed_atomic_rmw_memarg_offset_uleb(
        base,
      )
    MalformedAtomicCmpxchgMemargAlignUleb =>
      validate_invalid_binary_mutate_malformed_atomic_cmpxchg_memarg_align_uleb(
        base,
      )
    MalformedAtomicCmpxchgMemargOffsetUleb =>
      validate_invalid_binary_mutate_malformed_atomic_cmpxchg_memarg_offset_uleb(
        base,
      )
    OverwideAtomicLoadMemargAlignUleb =>
      validate_invalid_binary_mutate_overwide_atomic_load_memarg_align_uleb(
        base,
      )
    OverwideAtomicStoreMemargAlignUleb =>
      validate_invalid_binary_mutate_overwide_atomic_store_memarg_align_uleb(
        base,
      )
    OverwideAtomicLoadMemargOffsetUleb =>
      validate_invalid_binary_mutate_overwide_atomic_load_memarg_offset_uleb(
        base,
      )
    OverwideAtomicStoreMemargOffsetUleb =>
      validate_invalid_binary_mutate_overwide_atomic_store_memarg_offset_uleb(
        base,
      )
    OverwideAtomicNotifyMemargAlignUleb =>
      validate_invalid_binary_mutate_overwide_atomic_notify_memarg_align_uleb(
        base,
      )
    OverwideAtomicNotifyMemargOffsetUleb =>
      validate_invalid_binary_mutate_overwide_atomic_notify_memarg_offset_uleb(
        base,
      )
    OverwideAtomicWaitMemargAlignUleb =>
      validate_invalid_binary_mutate_overwide_atomic_wait_memarg_align_uleb(
        base,
      )
    OverwideAtomicWaitMemargOffsetUleb =>
      validate_invalid_binary_mutate_overwide_atomic_wait_memarg_offset_uleb(
        base,
      )
    OverwideAtomicRmwMemargAlignUleb =>
      validate_invalid_binary_mutate_overwide_atomic_rmw_memarg_align_uleb(base)
    OverwideAtomicRmwMemargOffsetUleb =>
      validate_invalid_binary_mutate_overwide_atomic_rmw_memarg_offset_uleb(
        base,
      )
    OverwideAtomicCmpxchgMemargAlignUleb =>
      validate_invalid_binary_mutate_overwide_atomic_cmpxchg_memarg_align_uleb(
        base,
      )
    OverwideAtomicCmpxchgMemargOffsetUleb =>
      validate_invalid_binary_mutate_overwide_atomic_cmpxchg_memarg_offset_uleb(
        base,
      )
    MalformedMemargImmediate =>
      validate_invalid_binary_mutate_malformed_memarg_immediate(base)
    MalformedLoadMemargAlignUleb =>
      validate_invalid_binary_mutate_malformed_load_memarg_align_uleb(base)
    MalformedStoreMemargAlignUleb =>
      validate_invalid_binary_mutate_malformed_store_memarg_align_uleb(base)
    MalformedLoadMemargOffsetUleb =>
      validate_invalid_binary_mutate_malformed_load_memarg_offset_uleb(base)
    MalformedStoreMemargOffsetUleb =>
      validate_invalid_binary_mutate_malformed_store_memarg_offset_uleb(base)
    OverwideLoadMemargAlignUleb =>
      validate_invalid_binary_mutate_overwide_load_memarg_align_uleb(base)
    OverwideStoreMemargAlignUleb =>
      validate_invalid_binary_mutate_overwide_store_memarg_align_uleb(base)
    OverwideLoadMemargOffsetUleb =>
      validate_invalid_binary_mutate_overwide_load_memarg_offset_uleb(base)
    OverwideStoreMemargOffsetUleb =>
      validate_invalid_binary_mutate_overwide_store_memarg_offset_uleb(base)
    MalformedBlocktypeImmediate =>
      validate_invalid_binary_mutate_malformed_blocktype_immediate(base)
    InvalidBlocktypeValTypeByte =>
      validate_invalid_binary_mutate_invalid_blocktype_valtype_byte(base)
    OverwideBlocktypeTypeIndexUleb =>
      validate_invalid_binary_mutate_overwide_blocktype_type_index_uleb(base)
    MalformedMemoryMinUleb =>
      validate_invalid_binary_mutate_malformed_memory_min_uleb(base)
    MalformedTableMinUleb =>
      validate_invalid_binary_mutate_malformed_table_min_uleb(base)
    MalformedMemoryMaxUleb =>
      validate_invalid_binary_mutate_malformed_memory_max_uleb(base)
    MalformedTableMaxUleb =>
      validate_invalid_binary_mutate_malformed_table_max_uleb(base)
    OverwideMemoryMinUleb =>
      validate_invalid_binary_mutate_overwide_memory_min_uleb(base)
    OverwideTableMinUleb =>
      validate_invalid_binary_mutate_overwide_table_min_uleb(base)
    OverwideMemoryMaxUleb =>
      validate_invalid_binary_mutate_overwide_memory_max_uleb(base)
    OverwideTableMaxUleb =>
      validate_invalid_binary_mutate_overwide_table_max_uleb(base)
    InvalidExportNameUtf8 =>
      validate_invalid_binary_mutate_invalid_export_name_utf8(base)
    MalformedExportNameLengthUleb =>
      validate_invalid_binary_mutate_malformed_export_name_length_uleb(base)
    OverwideExportNameLengthUleb =>
      validate_invalid_binary_mutate_overwide_export_name_length_uleb(base)
    InvalidImportModuleNameUtf8 =>
      validate_invalid_binary_mutate_invalid_import_module_name_utf8(base)
    MalformedImportModuleNameLengthUleb =>
      validate_invalid_binary_mutate_malformed_import_module_name_length_uleb(
        base,
      )
    OverwideImportModuleNameLengthUleb =>
      validate_invalid_binary_mutate_overwide_import_module_name_length_uleb(
        base,
      )
    InvalidImportFieldNameUtf8 =>
      validate_invalid_binary_mutate_invalid_import_field_name_utf8(base)
    MalformedImportFieldNameLengthUleb =>
      validate_invalid_binary_mutate_malformed_import_field_name_length_uleb(
        base,
      )
    OverwideImportFieldNameLengthUleb =>
      validate_invalid_binary_mutate_overwide_import_field_name_length_uleb(
        base,
      )
    InvalidImportKindByte =>
      validate_invalid_binary_mutate_invalid_import_kind_byte(base)
    MalformedFunctionSectionTypeIndexUleb =>
      validate_invalid_binary_mutate_malformed_function_section_type_index_uleb(
        base,
      )
    OverwideFunctionSectionTypeIndexUleb =>
      validate_invalid_binary_mutate_overwide_function_section_type_index_uleb(
        base,
      )
    MalformedImportFuncTypeIndexUleb =>
      validate_invalid_binary_mutate_malformed_import_func_type_index_uleb(base)
    OverwideImportFuncTypeIndexUleb =>
      validate_invalid_binary_mutate_overwide_import_func_type_index_uleb(base)
    MalformedImportTagTypeIndexUleb =>
      validate_invalid_binary_mutate_malformed_import_tag_type_index_uleb(base)
    OverwideImportTagTypeIndexUleb =>
      validate_invalid_binary_mutate_overwide_import_tag_type_index_uleb(base)
    MalformedImportMemoryMinUleb =>
      validate_invalid_binary_mutate_malformed_import_memory_min_uleb(base)
    MalformedImportTableMinUleb =>
      validate_invalid_binary_mutate_malformed_import_table_min_uleb(base)
    MalformedImportMemoryMaxUleb =>
      validate_invalid_binary_mutate_malformed_import_memory_max_uleb(base)
    MalformedImportTableMaxUleb =>
      validate_invalid_binary_mutate_malformed_import_table_max_uleb(base)
    OverwideImportMemoryMinUleb =>
      validate_invalid_binary_mutate_overwide_import_memory_min_uleb(base)
    OverwideImportTableMinUleb =>
      validate_invalid_binary_mutate_overwide_import_table_min_uleb(base)
    OverwideImportMemoryMaxUleb =>
      validate_invalid_binary_mutate_overwide_import_memory_max_uleb(base)
    OverwideImportTableMaxUleb =>
      validate_invalid_binary_mutate_overwide_import_table_max_uleb(base)
    InvalidImportTableRefTypeByte =>
      validate_invalid_binary_mutate_invalid_import_table_reftype_byte(base)
    InvalidImportMemoryLimitsFlagByte =>
      validate_invalid_binary_mutate_invalid_import_memory_limits_flag_byte(
        base,
      )
    InvalidImportGlobalValTypeByte =>
      validate_invalid_binary_mutate_invalid_import_global_valtype_byte(base)
    InvalidImportGlobalMutabilityByte =>
      validate_invalid_binary_mutate_invalid_import_global_mutability_byte(base)
    InvalidImportTagAttributeByte =>
      validate_invalid_binary_mutate_invalid_import_tag_attribute_byte(base)
    InvalidTableRefTypeByte =>
      validate_invalid_binary_mutate_invalid_table_reftype_byte(base)
    InvalidTableLimitsFlagByte =>
      validate_invalid_binary_mutate_invalid_table_limits_flag_byte(base)
    MalformedRefNullHeaptypeImmediate =>
      validate_invalid_binary_mutate_malformed_ref_null_heaptype_immediate(base)
    MalformedRefCastHeaptypeImmediate =>
      validate_invalid_binary_mutate_malformed_ref_cast_heaptype_immediate(base)
    MalformedRefTestHeaptypeImmediate =>
      validate_invalid_binary_mutate_malformed_ref_test_heaptype_immediate(base)
    OverwideRefNullHeaptypeImmediate =>
      validate_invalid_binary_mutate_overwide_ref_null_heaptype_immediate(base)
    OverwideRefCastHeaptypeImmediate =>
      validate_invalid_binary_mutate_overwide_ref_cast_heaptype_immediate(base)
    OverwideRefTestHeaptypeImmediate =>
      validate_invalid_binary_mutate_overwide_ref_test_heaptype_immediate(base)
    InvalidGlobalValTypeByte =>
      validate_invalid_binary_mutate_invalid_global_valtype_byte(base)
    InvalidExportKindByte =>
      validate_invalid_binary_mutate_invalid_export_kind_byte(base)
    InvalidMemoryLimitsFlagByte =>
      validate_invalid_binary_mutate_invalid_memory_limits_flag_byte(base)
    InvalidTagAttributeByte =>
      validate_invalid_binary_mutate_invalid_tag_attribute_byte(base)
    InvalidGlobalMutabilityByte =>
      validate_invalid_binary_mutate_invalid_global_mutability_byte(base)
    MalformedExportFuncIndexUleb =>
      validate_invalid_binary_mutate_malformed_export_func_index_uleb(base)
    MalformedExportTableIndexUleb =>
      validate_invalid_binary_mutate_malformed_export_table_index_uleb(base)
    MalformedExportMemoryIndexUleb =>
      validate_invalid_binary_mutate_malformed_export_memory_index_uleb(base)
    MalformedExportGlobalIndexUleb =>
      validate_invalid_binary_mutate_malformed_export_global_index_uleb(base)
    MalformedExportTagIndexUleb =>
      validate_invalid_binary_mutate_malformed_export_tag_index_uleb(base)
    OverwideExportFuncIndexUleb =>
      validate_invalid_binary_mutate_overwide_export_func_index_uleb(base)
    OverwideExportTableIndexUleb =>
      validate_invalid_binary_mutate_overwide_export_table_index_uleb(base)
    OverwideExportMemoryIndexUleb =>
      validate_invalid_binary_mutate_overwide_export_memory_index_uleb(base)
    OverwideExportGlobalIndexUleb =>
      validate_invalid_binary_mutate_overwide_export_global_index_uleb(base)
    OverwideExportTagIndexUleb =>
      validate_invalid_binary_mutate_overwide_export_tag_index_uleb(base)
    InvalidElementSegmentFlagByte =>
      validate_invalid_binary_mutate_invalid_element_segment_flag_byte(base)
    InvalidElementKindByte =>
      validate_invalid_binary_mutate_invalid_element_kind_byte(base)
    InvalidDataSegmentFlagByte =>
      validate_invalid_binary_mutate_invalid_data_segment_flag_byte(base)
    TypeSectionCountOverflow =>
      validate_invalid_binary_mutate_type_section_count_overflow(base)
    CodeSectionCountOverflow =>
      validate_invalid_binary_mutate_code_section_count_overflow(base)
    TableSectionCountOverflow =>
      validate_invalid_binary_mutate_table_section_count_overflow(base)
    ExportSectionCountOverflow =>
      validate_invalid_binary_mutate_export_section_count_overflow(base)
    ImportSectionCountOverflow =>
      validate_invalid_binary_mutate_import_section_count_overflow(base)
    GlobalSectionCountOverflow =>
      validate_invalid_binary_mutate_global_section_count_overflow(base)
    FunctionSectionCountOverflow =>
      validate_invalid_binary_mutate_function_section_count_overflow(base)
    MemorySectionCountOverflow =>
      validate_invalid_binary_mutate_memory_section_count_overflow(base)
    ElementSectionCountOverflow =>
      validate_invalid_binary_mutate_element_section_count_overflow(base)
    DataSectionCountOverflow =>
      validate_invalid_binary_mutate_data_section_count_overflow(base)
    TagSectionCountOverflow =>
      validate_invalid_binary_mutate_tag_section_count_overflow(base)
    MalformedTagTypeIndexUleb =>
      validate_invalid_binary_mutate_malformed_tag_type_index_uleb(base)
    OverwideTagTypeIndexUleb =>
      validate_invalid_binary_mutate_overwide_tag_type_index_uleb(base)
    MalformedLocalIndexUleb =>
      validate_invalid_binary_mutate_malformed_local_index_uleb(base)
    MalformedLocalSetIndexUleb =>
      validate_invalid_binary_mutate_malformed_local_set_index_uleb(base)
    MalformedLocalTeeIndexUleb =>
      validate_invalid_binary_mutate_malformed_local_tee_index_uleb(base)
    OverwideLocalIndexUleb =>
      validate_invalid_binary_mutate_overwide_local_index_uleb(base)
    OverwideLocalSetIndexUleb =>
      validate_invalid_binary_mutate_overwide_local_set_index_uleb(base)
    OverwideLocalTeeIndexUleb =>
      validate_invalid_binary_mutate_overwide_local_tee_index_uleb(base)
    MalformedGlobalIndexUleb =>
      validate_invalid_binary_mutate_malformed_global_index_uleb(base)
    MalformedGlobalSetIndexUleb =>
      validate_invalid_binary_mutate_malformed_global_set_index_uleb(base)
    OverwideGlobalIndexUleb =>
      validate_invalid_binary_mutate_overwide_global_index_uleb(base)
    OverwideGlobalSetIndexUleb =>
      validate_invalid_binary_mutate_overwide_global_set_index_uleb(base)
    MalformedI32ConstSleb =>
      validate_invalid_binary_mutate_malformed_i32_const_sleb(base)
    MalformedI64ConstSleb =>
      validate_invalid_binary_mutate_malformed_i64_const_sleb(base)
    OverwideI32ConstSleb =>
      validate_invalid_binary_mutate_overwide_i32_const_sleb(base)
    OverwideI64ConstSleb =>
      validate_invalid_binary_mutate_overwide_i64_const_sleb(base)
    MalformedF32ConstImmediate =>
      validate_invalid_binary_mutate_malformed_f32_const_immediate(base)
    MalformedF64ConstImmediate =>
      validate_invalid_binary_mutate_malformed_f64_const_immediate(base)
    MalformedCallFuncIndexUleb =>
      validate_invalid_binary_mutate_malformed_call_func_index_uleb(base)
    MalformedReturnCallFuncIndexUleb =>
      validate_invalid_binary_mutate_malformed_return_call_func_index_uleb(base)
    MalformedRefFuncIndexUleb =>
      validate_invalid_binary_mutate_malformed_ref_func_index_uleb(base)
    OverwideCallFuncIndexUleb =>
      validate_invalid_binary_mutate_overwide_call_func_index_uleb(base)
    OverwideReturnCallFuncIndexUleb =>
      validate_invalid_binary_mutate_overwide_return_call_func_index_uleb(base)
    OverwideRefFuncIndexUleb =>
      validate_invalid_binary_mutate_overwide_ref_func_index_uleb(base)
    MalformedCallIndirectTypeIndexUleb =>
      validate_invalid_binary_mutate_malformed_call_indirect_type_index_uleb(
        base,
      )
    MalformedCallIndirectTableIndexUleb =>
      validate_invalid_binary_mutate_malformed_call_indirect_table_index_uleb(
        base,
      )
    MalformedReturnCallIndirectTypeIndexUleb =>
      validate_invalid_binary_mutate_malformed_return_call_indirect_type_index_uleb(
        base,
      )
    MalformedReturnCallIndirectTableIndexUleb =>
      validate_invalid_binary_mutate_malformed_return_call_indirect_table_index_uleb(
        base,
      )
    MalformedCallRefTypeIndexUleb =>
      validate_invalid_binary_mutate_malformed_call_ref_type_index_uleb(base)
    MalformedReturnCallRefTypeIndexUleb =>
      validate_invalid_binary_mutate_malformed_return_call_ref_type_index_uleb(
        base,
      )
    OverwideCallIndirectTypeIndexUleb =>
      validate_invalid_binary_mutate_overwide_call_indirect_type_index_uleb(
        base,
      )
    OverwideCallIndirectTableIndexUleb =>
      validate_invalid_binary_mutate_overwide_call_indirect_table_index_uleb(
        base,
      )
    OverwideReturnCallIndirectTypeIndexUleb =>
      validate_invalid_binary_mutate_overwide_return_call_indirect_type_index_uleb(
        base,
      )
    OverwideReturnCallIndirectTableIndexUleb =>
      validate_invalid_binary_mutate_overwide_return_call_indirect_table_index_uleb(
        base,
      )
    OverwideCallRefTypeIndexUleb =>
      validate_invalid_binary_mutate_overwide_call_ref_type_index_uleb(base)
    OverwideReturnCallRefTypeIndexUleb =>
      validate_invalid_binary_mutate_overwide_return_call_ref_type_index_uleb(
        base,
      )
    MalformedThrowTagIndexUleb =>
      validate_invalid_binary_mutate_malformed_throw_tag_index_uleb(base)
    MalformedTryTableCatchCountUleb =>
      validate_invalid_binary_mutate_malformed_try_table_catch_count_uleb(base)
    MalformedTryTableCatchTagIndexUleb =>
      validate_invalid_binary_mutate_malformed_try_table_catch_tag_index_uleb(
        base,
      )
    MalformedTryTableCatchLabelIndexUleb =>
      validate_invalid_binary_mutate_malformed_try_table_catch_label_index_uleb(
        base,
      )
    OverwideThrowTagIndexUleb =>
      validate_invalid_binary_mutate_overwide_throw_tag_index_uleb(base)
    OverwideTryTableCatchCountUleb =>
      validate_invalid_binary_mutate_overwide_try_table_catch_count_uleb(base)
    OverwideTryTableCatchTagIndexUleb =>
      validate_invalid_binary_mutate_overwide_try_table_catch_tag_index_uleb(
        base,
      )
    OverwideTryTableCatchLabelIndexUleb =>
      validate_invalid_binary_mutate_overwide_try_table_catch_label_index_uleb(
        base,
      )
    MalformedStructNewTypeIndexUleb =>
      validate_invalid_binary_mutate_malformed_struct_new_type_index_uleb(base)
    MalformedStructGetFieldIndexUleb =>
      validate_invalid_binary_mutate_malformed_struct_get_field_index_uleb(base)
    MalformedArrayNewDataTypeIndexUleb =>
      validate_invalid_binary_mutate_malformed_array_new_data_type_index_uleb(
        base,
      )
    MalformedArrayNewDataIndexUleb =>
      validate_invalid_binary_mutate_malformed_array_new_data_index_uleb(base)
    MalformedArrayNewElemTypeIndexUleb =>
      validate_invalid_binary_mutate_malformed_array_new_elem_type_index_uleb(
        base,
      )
    MalformedArrayNewElemElemIndexUleb =>
      validate_invalid_binary_mutate_malformed_array_new_elem_elem_index_uleb(
        base,
      )
    OverwideStructNewTypeIndexUleb =>
      validate_invalid_binary_mutate_overwide_struct_new_type_index_uleb(base)
    OverwideStructGetFieldIndexUleb =>
      validate_invalid_binary_mutate_overwide_struct_get_field_index_uleb(base)
    OverwideArrayNewDataTypeIndexUleb =>
      validate_invalid_binary_mutate_overwide_array_new_data_type_index_uleb(
        base,
      )
    OverwideArrayNewDataIndexUleb =>
      validate_invalid_binary_mutate_overwide_array_new_data_index_uleb(base)
    OverwideArrayNewElemTypeIndexUleb =>
      validate_invalid_binary_mutate_overwide_array_new_elem_type_index_uleb(
        base,
      )
    OverwideArrayNewElemElemIndexUleb =>
      validate_invalid_binary_mutate_overwide_array_new_elem_elem_index_uleb(
        base,
      )
    MalformedBrLabelIndexUleb =>
      validate_invalid_binary_mutate_malformed_br_label_index_uleb(base)
    MalformedBrIfLabelIndexUleb =>
      validate_invalid_binary_mutate_malformed_br_if_label_index_uleb(base)
    MalformedBrTableTargetCountUleb =>
      validate_invalid_binary_mutate_malformed_br_table_target_count_uleb(base)
    MalformedBrTableTargetLabelIndexUleb =>
      validate_invalid_binary_mutate_malformed_br_table_target_label_index_uleb(
        base,
      )
    MalformedBrTableDefaultLabelIndexUleb =>
      validate_invalid_binary_mutate_malformed_br_table_default_label_index_uleb(
        base,
      )
    OverwideBrLabelIndexUleb =>
      validate_invalid_binary_mutate_overwide_br_label_index_uleb(base)
    OverwideBrIfLabelIndexUleb =>
      validate_invalid_binary_mutate_overwide_br_if_label_index_uleb(base)
    OverwideBrTableTargetCountUleb =>
      validate_invalid_binary_mutate_overwide_br_table_target_count_uleb(base)
    OverwideBrTableTargetLabelIndexUleb =>
      validate_invalid_binary_mutate_overwide_br_table_target_label_index_uleb(
        base,
      )
    OverwideBrTableDefaultLabelIndexUleb =>
      validate_invalid_binary_mutate_overwide_br_table_default_label_index_uleb(
        base,
      )
    MalformedTableIndexUleb =>
      validate_invalid_binary_mutate_malformed_table_index_uleb(base)
    MalformedTableSetIndexUleb =>
      validate_invalid_binary_mutate_malformed_table_set_index_uleb(base)
    MalformedTableSizeIndexUleb =>
      validate_invalid_binary_mutate_malformed_table_size_index_uleb(base)
    MalformedTableGrowIndexUleb =>
      validate_invalid_binary_mutate_malformed_table_grow_index_uleb(base)
    MalformedTableFillIndexUleb =>
      validate_invalid_binary_mutate_malformed_table_fill_index_uleb(base)
    OverwideTableIndexUleb =>
      validate_invalid_binary_mutate_overwide_table_index_uleb(base)
    OverwideTableSetIndexUleb =>
      validate_invalid_binary_mutate_overwide_table_set_index_uleb(base)
    OverwideTableSizeIndexUleb =>
      validate_invalid_binary_mutate_overwide_table_size_index_uleb(base)
    OverwideTableGrowIndexUleb =>
      validate_invalid_binary_mutate_overwide_table_grow_index_uleb(base)
    OverwideTableFillIndexUleb =>
      validate_invalid_binary_mutate_overwide_table_fill_index_uleb(base)
    MalformedMemorySizeMemoryIndexUleb =>
      validate_invalid_binary_mutate_malformed_memory_size_memory_index_uleb(
        base,
      )
    MalformedMemoryGrowMemoryIndexUleb =>
      validate_invalid_binary_mutate_malformed_memory_grow_memory_index_uleb(
        base,
      )
    MalformedMemoryFillMemoryIndexUleb =>
      validate_invalid_binary_mutate_malformed_memory_fill_memory_index_uleb(
        base,
      )
    OverwideMemorySizeMemoryIndexUleb =>
      validate_invalid_binary_mutate_overwide_memory_size_memory_index_uleb(
        base,
      )
    OverwideMemoryGrowMemoryIndexUleb =>
      validate_invalid_binary_mutate_overwide_memory_grow_memory_index_uleb(
        base,
      )
    OverwideMemoryFillMemoryIndexUleb =>
      validate_invalid_binary_mutate_overwide_memory_fill_memory_index_uleb(
        base,
      )
    MalformedMemoryCopyDstIndexUleb =>
      validate_invalid_binary_mutate_malformed_memory_copy_dst_index_uleb(base)
    MalformedMemoryCopySrcIndexUleb =>
      validate_invalid_binary_mutate_malformed_memory_copy_src_index_uleb(base)
    MalformedTableCopyDstIndexUleb =>
      validate_invalid_binary_mutate_malformed_table_copy_dst_index_uleb(base)
    MalformedTableCopySrcIndexUleb =>
      validate_invalid_binary_mutate_malformed_table_copy_src_index_uleb(base)
    OverwideMemoryCopyDstIndexUleb =>
      validate_invalid_binary_mutate_overwide_memory_copy_dst_index_uleb(base)
    OverwideMemoryCopySrcIndexUleb =>
      validate_invalid_binary_mutate_overwide_memory_copy_src_index_uleb(base)
    OverwideTableCopyDstIndexUleb =>
      validate_invalid_binary_mutate_overwide_table_copy_dst_index_uleb(base)
    OverwideTableCopySrcIndexUleb =>
      validate_invalid_binary_mutate_overwide_table_copy_src_index_uleb(base)
    MalformedSelectTypeCountUleb =>
      validate_invalid_binary_mutate_malformed_select_type_count_uleb(base)
    OverwideSelectTypeCountUleb =>
      validate_invalid_binary_mutate_overwide_select_type_count_uleb(base)
    InvalidTypedSelectValTypeByte =>
      validate_invalid_binary_mutate_invalid_typed_select_valtype_byte(base)
    MalformedStartFuncIndexUleb =>
      validate_invalid_binary_mutate_malformed_start_func_index_uleb(base)
    OverwideStartFuncIndexUleb =>
      validate_invalid_binary_mutate_overwide_start_func_index_uleb(base)
    MalformedDataCountUleb =>
      validate_invalid_binary_mutate_malformed_datacount_uleb(base)
    OverwideDataCountUleb =>
      validate_invalid_binary_mutate_overwide_datacount_uleb(base)
    SimdShuffleLaneOverflow =>
      validate_invalid_binary_mutate_simd_shuffle_lane_overflow(base)
    SimdLoadLaneIndexOverflow =>
      validate_invalid_binary_mutate_simd_load_lane_index_overflow(base)
    SimdStoreLaneIndexOverflow =>
      validate_invalid_binary_mutate_simd_store_lane_index_overflow(base)
    SimdExtractLaneIndexOverflow =>
      validate_invalid_binary_mutate_simd_extract_lane_index_overflow(base)
    SimdReplaceLaneIndexOverflow =>
      validate_invalid_binary_mutate_simd_replace_lane_index_overflow(base)
    MalformedSimdLoadMemargAlignUleb =>
      validate_invalid_binary_mutate_malformed_simd_memarg_align_uleb(
        strategy, false,
      )
    MalformedSimdStoreMemargAlignUleb =>
      validate_invalid_binary_mutate_malformed_simd_memarg_align_uleb(
        strategy, true,
      )
    MalformedSimdLoadMemargOffsetUleb =>
      validate_invalid_binary_mutate_malformed_simd_memarg_offset_uleb(
        strategy, false,
      )
    MalformedSimdStoreMemargOffsetUleb =>
      validate_invalid_binary_mutate_malformed_simd_memarg_offset_uleb(
        strategy, true,
      )
    OverwideSimdLoadMemargAlignUleb =>
      validate_invalid_binary_mutate_overwide_simd_memarg_align_uleb(
        strategy, false,
      )
    OverwideSimdStoreMemargAlignUleb =>
      validate_invalid_binary_mutate_overwide_simd_memarg_align_uleb(
        strategy, true,
      )
    OverwideSimdLoadMemargOffsetUleb =>
      validate_invalid_binary_mutate_overwide_simd_memarg_offset_uleb(
        strategy, false,
      )
    OverwideSimdStoreMemargOffsetUleb =>
      validate_invalid_binary_mutate_overwide_simd_memarg_offset_uleb(
        strategy, true,
      )
    MalformedSimdLoadLaneMemargAlignUleb =>
      validate_invalid_binary_mutate_malformed_simd_lane_memarg_align_uleb(
        strategy, false,
      )
    MalformedSimdStoreLaneMemargAlignUleb =>
      validate_invalid_binary_mutate_malformed_simd_lane_memarg_align_uleb(
        strategy, true,
      )
    MalformedSimdLoadLaneMemargOffsetUleb =>
      validate_invalid_binary_mutate_malformed_simd_lane_memarg_offset_uleb(
        strategy, false,
      )
    MalformedSimdStoreLaneMemargOffsetUleb =>
      validate_invalid_binary_mutate_malformed_simd_lane_memarg_offset_uleb(
        strategy, true,
      )
    OverwideSimdLoadLaneMemargAlignUleb =>
      validate_invalid_binary_mutate_overwide_simd_lane_memarg_align_uleb(
        strategy, false,
      )
    OverwideSimdStoreLaneMemargAlignUleb =>
      validate_invalid_binary_mutate_overwide_simd_lane_memarg_align_uleb(
        strategy, true,
      )
    OverwideSimdLoadLaneMemargOffsetUleb =>
      validate_invalid_binary_mutate_overwide_simd_lane_memarg_offset_uleb(
        strategy, false,
      )
    OverwideSimdStoreLaneMemargOffsetUleb =>
      validate_invalid_binary_mutate_overwide_simd_lane_memarg_offset_uleb(
        strategy, true,
      )
    MalformedSimdLoadSplatMemargAlignUleb =>
      validate_invalid_binary_mutate_malformed_simd_memarg_align_uleb_with_prefix(
        strategy,
        validate_invalid_binary_simd_load_splat_memarg_prefix(),
      )
    MalformedSimdLoadSplatMemargOffsetUleb =>
      validate_invalid_binary_mutate_malformed_simd_memarg_offset_uleb_with_prefix(
        strategy,
        validate_invalid_binary_simd_load_splat_memarg_prefix(),
      )
    OverwideSimdLoadSplatMemargAlignUleb =>
      validate_invalid_binary_mutate_overwide_simd_memarg_align_uleb_with_prefix(
        strategy,
        validate_invalid_binary_simd_load_splat_memarg_prefix(),
      )
    OverwideSimdLoadSplatMemargOffsetUleb =>
      validate_invalid_binary_mutate_overwide_simd_memarg_offset_uleb_with_prefix(
        strategy,
        validate_invalid_binary_simd_load_splat_memarg_prefix(),
      )
    MalformedSimdLoadExtendMemargAlignUleb =>
      validate_invalid_binary_mutate_malformed_simd_memarg_align_uleb_with_prefix(
        strategy,
        validate_invalid_binary_simd_load_extend_memarg_prefix(),
      )
    MalformedSimdLoadExtendMemargOffsetUleb =>
      validate_invalid_binary_mutate_malformed_simd_memarg_offset_uleb_with_prefix(
        strategy,
        validate_invalid_binary_simd_load_extend_memarg_prefix(),
      )
    OverwideSimdLoadExtendMemargAlignUleb =>
      validate_invalid_binary_mutate_overwide_simd_memarg_align_uleb_with_prefix(
        strategy,
        validate_invalid_binary_simd_load_extend_memarg_prefix(),
      )
    OverwideSimdLoadExtendMemargOffsetUleb =>
      validate_invalid_binary_mutate_overwide_simd_memarg_offset_uleb_with_prefix(
        strategy,
        validate_invalid_binary_simd_load_extend_memarg_prefix(),
      )
    MalformedSimdLoadZeroMemargAlignUleb =>
      validate_invalid_binary_mutate_malformed_simd_memarg_align_uleb_with_prefix(
        strategy,
        validate_invalid_binary_simd_load_zero_memarg_prefix(),
      )
    MalformedSimdLoadZeroMemargOffsetUleb =>
      validate_invalid_binary_mutate_malformed_simd_memarg_offset_uleb_with_prefix(
        strategy,
        validate_invalid_binary_simd_load_zero_memarg_prefix(),
      )
    OverwideSimdLoadZeroMemargAlignUleb =>
      validate_invalid_binary_mutate_overwide_simd_memarg_align_uleb_with_prefix(
        strategy,
        validate_invalid_binary_simd_load_zero_memarg_prefix(),
      )
    OverwideSimdLoadZeroMemargOffsetUleb =>
      validate_invalid_binary_mutate_overwide_simd_memarg_offset_uleb_with_prefix(
        strategy,
        validate_invalid_binary_simd_load_zero_memarg_prefix(),
      )
    MalformedDataIndexUleb =>
      validate_invalid_binary_mutate_malformed_data_index_uleb(base)
    OverwideDataIndexUleb =>
      validate_invalid_binary_mutate_overwide_data_index_uleb(base)
    MalformedDataSegmentByteCountUleb =>
      validate_invalid_binary_mutate_malformed_data_segment_byte_count_uleb(
        base,
      )
    OverwideDataSegmentByteCountUleb =>
      validate_invalid_binary_mutate_overwide_data_segment_byte_count_uleb(base)
    MalformedMemoryInitDataIndexUleb =>
      validate_invalid_binary_mutate_malformed_memory_init_data_index_uleb(base)
    MalformedMemoryInitMemoryIndexUleb =>
      validate_invalid_binary_mutate_malformed_memory_init_memory_index_uleb(
        base,
      )
    OverwideMemoryInitDataIndexUleb =>
      validate_invalid_binary_mutate_overwide_memory_init_data_index_uleb(base)
    OverwideMemoryInitMemoryIndexUleb =>
      validate_invalid_binary_mutate_overwide_memory_init_memory_index_uleb(
        base,
      )
    MalformedElemIndexUleb =>
      validate_invalid_binary_mutate_malformed_elem_index_uleb(base)
    OverwideElemIndexUleb =>
      validate_invalid_binary_mutate_overwide_elem_index_uleb(base)
    MalformedTableInitElemIndexUleb =>
      validate_invalid_binary_mutate_malformed_table_init_elem_index_uleb(base)
    MalformedTableInitTableIndexUleb =>
      validate_invalid_binary_mutate_malformed_table_init_table_index_uleb(base)
    OverwideTableInitElemIndexUleb =>
      validate_invalid_binary_mutate_overwide_table_init_elem_index_uleb(base)
    OverwideTableInitTableIndexUleb =>
      validate_invalid_binary_mutate_overwide_table_init_table_index_uleb(base)
    MalformedDataSegmentMemoryIndexUleb =>
      validate_invalid_binary_mutate_malformed_data_segment_memory_index_uleb(
        base,
      )
    OverwideDataSegmentMemoryIndexUleb =>
      validate_invalid_binary_mutate_overwide_data_segment_memory_index_uleb(
        base,
      )
    MalformedElementSegmentTableIndexUleb =>
      validate_invalid_binary_mutate_malformed_element_segment_table_index_uleb(
        base,
      )
    MalformedElementSegmentFuncIndexUleb =>
      validate_invalid_binary_mutate_malformed_element_segment_func_index_uleb(
        base,
      )
    OverwideElementSegmentTableIndexUleb =>
      validate_invalid_binary_mutate_overwide_element_segment_table_index_uleb(
        base,
      )
    OverwideElementSegmentFuncIndexUleb =>
      validate_invalid_binary_mutate_overwide_element_segment_func_index_uleb(
        base,
      )
    InvalidNameSectionFuncNameUtf8 =>
      validate_invalid_binary_mutate_invalid_name_section_func_name_utf8(base)
    MalformedNameSectionFuncNameLengthUleb =>
      validate_invalid_binary_mutate_malformed_name_section_func_name_length_uleb(
        base,
      )
    OverwideNameSectionFuncNameLengthUleb =>
      validate_invalid_binary_mutate_overwide_name_section_func_name_length_uleb(
        base,
      )
    MalformedNameSectionFuncNameCountUleb =>
      validate_invalid_binary_mutate_malformed_name_section_func_name_count_uleb(
        base,
      )
    OverwideNameSectionFuncNameCountUleb =>
      validate_invalid_binary_mutate_overwide_name_section_func_name_count_uleb(
        base,
      )
    InvalidNameSectionLocalNameUtf8 =>
      validate_invalid_binary_mutate_invalid_name_section_local_name_utf8(base)
    MalformedNameSectionLocalNameLengthUleb =>
      validate_invalid_binary_mutate_malformed_name_section_local_name_length_uleb(
        base,
      )
    OverwideNameSectionLocalNameLengthUleb =>
      validate_invalid_binary_mutate_overwide_name_section_local_name_length_uleb(
        base,
      )
    MalformedNameSectionLocalNameCountUleb =>
      validate_invalid_binary_mutate_malformed_name_section_local_name_count_uleb(
        base,
      )
    OverwideNameSectionLocalNameCountUleb =>
      validate_invalid_binary_mutate_overwide_name_section_local_name_count_uleb(
        base,
      )
    InvalidNameSectionModuleNameUtf8 =>
      validate_invalid_binary_mutate_invalid_name_section_module_name_utf8(base)
    MalformedNameSectionModuleNameLengthUleb =>
      validate_invalid_binary_mutate_malformed_name_section_module_name_length_uleb(
        base,
      )
    OverwideNameSectionModuleNameLengthUleb =>
      validate_invalid_binary_mutate_overwide_name_section_module_name_length_uleb(
        base,
      )
    InvalidNameSectionTypeNameUtf8 =>
      validate_invalid_binary_mutate_invalid_name_section_type_name_utf8(base)
    MalformedNameSectionTypeNameLengthUleb =>
      validate_invalid_binary_mutate_malformed_name_section_type_name_length_uleb(
        base,
      )
    OverwideNameSectionTypeNameLengthUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        OverwideNameSectionTypeNameLengthUleb,
        validate_invalid_binary_module_with_overwide_name_section_type_name_length_uleb(),
      )
    MalformedNameSectionTypeNameCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        MalformedNameSectionTypeNameCountUleb,
        validate_invalid_binary_module_with_malformed_name_section_type_name_count_uleb(),
      )
    OverwideNameSectionTypeNameCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        OverwideNameSectionTypeNameCountUleb,
        validate_invalid_binary_module_with_overwide_name_section_type_name_count_uleb(),
      )
    InvalidNameSectionTableNameUtf8 =>
      validate_invalid_binary_mutate_invalid_name_section_table_name_utf8(base)
    MalformedNameSectionTableNameLengthUleb =>
      validate_invalid_binary_mutate_malformed_name_section_table_name_length_uleb(
        base,
      )
    OverwideNameSectionTableNameLengthUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        OverwideNameSectionTableNameLengthUleb,
        validate_invalid_binary_module_with_overwide_name_section_table_name_length_uleb(),
      )
    MalformedNameSectionTableNameCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        MalformedNameSectionTableNameCountUleb,
        validate_invalid_binary_module_with_malformed_name_section_table_name_count_uleb(),
      )
    OverwideNameSectionTableNameCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        OverwideNameSectionTableNameCountUleb,
        validate_invalid_binary_module_with_overwide_name_section_table_name_count_uleb(),
      )
    InvalidNameSectionMemoryNameUtf8 =>
      validate_invalid_binary_mutate_invalid_name_section_memory_name_utf8(base)
    MalformedNameSectionMemoryNameLengthUleb =>
      validate_invalid_binary_mutate_malformed_name_section_memory_name_length_uleb(
        base,
      )
    OverwideNameSectionMemoryNameLengthUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        OverwideNameSectionMemoryNameLengthUleb,
        validate_invalid_binary_module_with_overwide_name_section_memory_name_length_uleb(),
      )
    MalformedNameSectionMemoryNameCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        MalformedNameSectionMemoryNameCountUleb,
        validate_invalid_binary_module_with_malformed_name_section_memory_name_count_uleb(),
      )
    OverwideNameSectionMemoryNameCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        OverwideNameSectionMemoryNameCountUleb,
        validate_invalid_binary_module_with_overwide_name_section_memory_name_count_uleb(),
      )
    InvalidNameSectionGlobalNameUtf8 =>
      validate_invalid_binary_mutate_invalid_name_section_global_name_utf8(base)
    MalformedNameSectionGlobalNameLengthUleb =>
      validate_invalid_binary_mutate_malformed_name_section_global_name_length_uleb(
        base,
      )
    OverwideNameSectionGlobalNameLengthUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        OverwideNameSectionGlobalNameLengthUleb,
        validate_invalid_binary_module_with_overwide_name_section_global_name_length_uleb(),
      )
    MalformedNameSectionGlobalNameCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        MalformedNameSectionGlobalNameCountUleb,
        validate_invalid_binary_module_with_malformed_name_section_global_name_count_uleb(),
      )
    OverwideNameSectionGlobalNameCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        OverwideNameSectionGlobalNameCountUleb,
        validate_invalid_binary_module_with_overwide_name_section_global_name_count_uleb(),
      )
    InvalidNameSectionElemNameUtf8 =>
      validate_invalid_binary_mutate_invalid_name_section_elem_name_utf8(base)
    MalformedNameSectionElemNameLengthUleb =>
      validate_invalid_binary_mutate_malformed_name_section_elem_name_length_uleb(
        base,
      )
    OverwideNameSectionElemNameLengthUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        OverwideNameSectionElemNameLengthUleb,
        validate_invalid_binary_module_with_overwide_name_section_elem_name_length_uleb(),
      )
    MalformedNameSectionElemNameCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        MalformedNameSectionElemNameCountUleb,
        validate_invalid_binary_module_with_malformed_name_section_elem_name_count_uleb(),
      )
    OverwideNameSectionElemNameCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        OverwideNameSectionElemNameCountUleb,
        validate_invalid_binary_module_with_overwide_name_section_elem_name_count_uleb(),
      )
    InvalidNameSectionDataNameUtf8 =>
      validate_invalid_binary_mutate_invalid_name_section_data_name_utf8(base)
    MalformedNameSectionDataNameLengthUleb =>
      validate_invalid_binary_mutate_malformed_name_section_data_name_length_uleb(
        base,
      )
    OverwideNameSectionDataNameLengthUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        OverwideNameSectionDataNameLengthUleb,
        validate_invalid_binary_module_with_overwide_name_section_data_name_length_uleb(),
      )
    InvalidNameSectionFieldNameUtf8 =>
      validate_invalid_binary_mutate_invalid_name_section_field_name_utf8(base)
    MalformedNameSectionFieldNameLengthUleb =>
      validate_invalid_binary_mutate_malformed_name_section_field_name_length_uleb(
        base,
      )
    OverwideNameSectionFieldNameLengthUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        OverwideNameSectionFieldNameLengthUleb,
        validate_invalid_binary_module_with_overwide_name_section_field_name_length_uleb(),
      )
    InvalidNameSectionLabelNameUtf8 =>
      validate_invalid_binary_mutate_invalid_name_section_label_name_utf8(base)
    MalformedNameSectionLabelNameLengthUleb =>
      validate_invalid_binary_mutate_malformed_name_section_label_name_length_uleb(
        base,
      )
    OverwideNameSectionLabelNameLengthUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        OverwideNameSectionLabelNameLengthUleb,
        validate_invalid_binary_module_with_overwide_name_section_label_name_length_uleb(),
      )
    InvalidNameSectionTagNameUtf8 =>
      validate_invalid_binary_mutate_invalid_name_section_tag_name_utf8(base)
    MalformedNameSectionTagNameLengthUleb =>
      validate_invalid_binary_mutate_malformed_name_section_tag_name_length_uleb(
        base,
      )
    OverwideNameSectionTagNameLengthUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        OverwideNameSectionTagNameLengthUleb,
        validate_invalid_binary_module_with_overwide_name_section_tag_name_length_uleb(),
      )
    InvalidFuncTypeByte =>
      validate_invalid_binary_mutate_invalid_functype_byte(base)
    MalformedFuncTypeParamCountUleb =>
      validate_invalid_binary_mutate_malformed_functype_param_count_uleb(base)
    MalformedFuncTypeResultCountUleb =>
      validate_invalid_binary_mutate_malformed_functype_result_count_uleb(base)
    OverwideFuncTypeParamCountUleb =>
      validate_invalid_binary_mutate_overwide_functype_param_count_uleb(base)
    OverwideFuncTypeResultCountUleb =>
      validate_invalid_binary_mutate_overwide_functype_result_count_uleb(base)
    InvalidFuncTypeParamValTypeByte =>
      validate_invalid_binary_mutate_invalid_functype_param_valtype_byte(base)
    InvalidFuncTypeResultValTypeByte =>
      validate_invalid_binary_mutate_invalid_functype_result_valtype_byte(base)
    InvalidCodeLocalValTypeByte =>
      validate_invalid_binary_mutate_invalid_code_local_valtype_byte(base)
    MalformedCodeLocalDeclCountUleb =>
      validate_invalid_binary_mutate_malformed_code_local_decl_count_uleb(base)
    MalformedCodeLocalRunCountUleb =>
      validate_invalid_binary_mutate_malformed_code_local_run_count_uleb(base)
    OverwideCodeLocalDeclCountUleb =>
      validate_invalid_binary_mutate_overwide_code_local_decl_count_uleb(base)
    OverwideCodeLocalRunCountUleb =>
      validate_invalid_binary_mutate_overwide_code_local_run_count_uleb(base)
    MalformedTypeSectionCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        MalformedTypeSectionCountUleb,
        validate_invalid_binary_module_with_malformed_type_section_count_uleb(),
      )
    MalformedCodeSectionCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        MalformedCodeSectionCountUleb,
        validate_invalid_binary_module_with_malformed_code_section_count_uleb(),
      )
    MalformedImportSectionCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        MalformedImportSectionCountUleb,
        validate_invalid_binary_module_with_malformed_section_count_uleb(0x02),
      )
    MalformedExportSectionCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        MalformedExportSectionCountUleb,
        validate_invalid_binary_module_with_malformed_section_count_uleb(0x07),
      )
    MalformedTableSectionCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        MalformedTableSectionCountUleb,
        validate_invalid_binary_module_with_malformed_section_count_uleb(0x04),
      )
    MalformedMemorySectionCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        MalformedMemorySectionCountUleb,
        validate_invalid_binary_module_with_malformed_section_count_uleb(0x05),
      )
    MalformedGlobalSectionCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        MalformedGlobalSectionCountUleb,
        validate_invalid_binary_module_with_malformed_section_count_uleb(0x06),
      )
    MalformedFunctionSectionCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        MalformedFunctionSectionCountUleb,
        validate_invalid_binary_module_with_malformed_section_count_uleb(0x03),
      )
    MalformedElementSectionCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        MalformedElementSectionCountUleb,
        validate_invalid_binary_module_with_malformed_section_count_uleb(0x09),
      )
    MalformedDataSectionCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        MalformedDataSectionCountUleb,
        validate_invalid_binary_module_with_malformed_section_count_uleb(0x0b),
      )
    MalformedTagSectionCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        MalformedTagSectionCountUleb,
        validate_invalid_binary_module_with_malformed_section_count_uleb(0x0d),
      )
    OverwideTypeSectionCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        OverwideTypeSectionCountUleb,
        validate_invalid_binary_module_with_overwide_section_count_uleb(0x01),
      )
    OverwideCodeSectionCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        OverwideCodeSectionCountUleb,
        validate_invalid_binary_module_with_overwide_section_count_uleb(0x0a),
      )
    OverwideImportSectionCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        OverwideImportSectionCountUleb,
        validate_invalid_binary_module_with_overwide_section_count_uleb(0x02),
      )
    OverwideExportSectionCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        OverwideExportSectionCountUleb,
        validate_invalid_binary_module_with_overwide_section_count_uleb(0x07),
      )
    OverwideTableSectionCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        OverwideTableSectionCountUleb,
        validate_invalid_binary_module_with_overwide_section_count_uleb(0x04),
      )
    OverwideMemorySectionCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        OverwideMemorySectionCountUleb,
        validate_invalid_binary_module_with_overwide_section_count_uleb(0x05),
      )
    OverwideGlobalSectionCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        OverwideGlobalSectionCountUleb,
        validate_invalid_binary_module_with_overwide_section_count_uleb(0x06),
      )
    OverwideFunctionSectionCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        OverwideFunctionSectionCountUleb,
        validate_invalid_binary_module_with_overwide_section_count_uleb(0x03),
      )
    OverwideElementSectionCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        OverwideElementSectionCountUleb,
        validate_invalid_binary_module_with_overwide_section_count_uleb(0x09),
      )
    OverwideDataSectionCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        OverwideDataSectionCountUleb,
        validate_invalid_binary_module_with_overwide_section_count_uleb(0x0b),
      )
    OverwideTagSectionCountUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        OverwideTagSectionCountUleb,
        validate_invalid_binary_module_with_overwide_section_count_uleb(0x0d),
      )
    TypeSectionCountUnderflow =>
      validate_invalid_binary_mutate_type_section_count_underflow(base)
    CodeSectionCountUnderflow =>
      validate_invalid_binary_mutate_code_section_count_underflow(base)
    ImportSectionCountUnderflow =>
      validate_invalid_binary_mutate_import_section_count_underflow(base)
    ExportSectionCountUnderflow =>
      validate_invalid_binary_mutate_export_section_count_underflow(base)
    TableSectionCountUnderflow =>
      validate_invalid_binary_mutate_table_section_count_underflow(base)
    MemorySectionCountUnderflow =>
      validate_invalid_binary_mutate_memory_section_count_underflow(base)
    GlobalSectionCountUnderflow =>
      validate_invalid_binary_mutate_global_section_count_underflow(base)
    FunctionSectionCountUnderflow =>
      validate_invalid_binary_mutate_function_section_count_underflow(base)
    ElementSectionCountUnderflow =>
      validate_invalid_binary_mutate_element_section_count_underflow(base)
    DataSectionCountUnderflow =>
      validate_invalid_binary_mutate_data_section_count_underflow(base)
    TagSectionCountUnderflow =>
      validate_invalid_binary_mutate_tag_section_count_underflow(base)
    TypeSectionSizeUnderflow =>
      validate_invalid_binary_mutate_type_section_size_underflow(base)
    CodeBodySizeUnderflow =>
      validate_invalid_binary_mutate_code_body_size_underflow(base)
    MalformedCodeBodySizeUleb =>
      validate_invalid_binary_mutate_malformed_code_body_size_uleb(base)
    OverwideCodeBodySizeUleb =>
      validate_invalid_binary_mutate_decode_rejected_bytes(
        OverwideCodeBodySizeUleb,
        validate_invalid_binary_module_with_overwide_code_body_size_uleb(),
      )
    ImportSectionSizeUnderflow =>
      validate_invalid_binary_mutate_import_section_size_underflow(base)
    ExportSectionSizeUnderflow =>
      validate_invalid_binary_mutate_export_section_size_underflow(base)
    TableSectionSizeUnderflow =>
      validate_invalid_binary_mutate_table_section_size_underflow(base)
    MemorySectionSizeUnderflow =>
      validate_invalid_binary_mutate_memory_section_size_underflow(base)
    GlobalSectionSizeUnderflow =>
      validate_invalid_binary_mutate_global_section_size_underflow(base)
    FunctionSectionSizeUnderflow =>
      validate_invalid_binary_mutate_function_section_size_underflow(base)
    ElementSectionSizeUnderflow =>
      validate_invalid_binary_mutate_element_section_size_underflow(base)
    DataSectionSizeUnderflow =>
      validate_invalid_binary_mutate_data_section_size_underflow(base)
    TagSectionSizeUnderflow =>
      validate_invalid_binary_mutate_tag_section_size_underflow(base)
    TypeSectionSizeOverflow =>
      validate_invalid_binary_mutate_type_section_size_overflow(base)
    CodeSectionSizeOverflow =>
      validate_invalid_binary_mutate_code_section_size_overflow(base)
    ImportSectionSizeOverflow =>
      validate_invalid_binary_mutate_import_section_size_overflow(base)
    ExportSectionSizeOverflow =>
      validate_invalid_binary_mutate_export_section_size_overflow(base)
    TableSectionSizeOverflow =>
      validate_invalid_binary_mutate_table_section_size_overflow(base)
    MemorySectionSizeOverflow =>
      validate_invalid_binary_mutate_memory_section_size_overflow(base)
    GlobalSectionSizeOverflow =>
      validate_invalid_binary_mutate_global_section_size_overflow(base)
    FunctionSectionSizeOverflow =>
      validate_invalid_binary_mutate_function_section_size_overflow(base)
    ElementSectionSizeOverflow =>
      validate_invalid_binary_mutate_element_section_size_overflow(base)
    DataSectionSizeOverflow =>
      validate_invalid_binary_mutate_data_section_size_overflow(base)
    TagSectionSizeOverflow =>
      validate_invalid_binary_mutate_tag_section_size_overflow(base)
    StartSectionSizeUnderflow =>
      validate_invalid_binary_mutate_start_section_size_underflow(base)
    DataCountSectionSizeUnderflow =>
      validate_invalid_binary_mutate_datacount_section_size_underflow(base)
    StartSectionSizeOverflow =>
      validate_invalid_binary_mutate_start_section_size_overflow(base)
    DataCountSectionSizeOverflow =>
      validate_invalid_binary_mutate_datacount_section_size_overflow(base)
    InvalidStartSignatureModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy("invalid-start-signature") {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidStartSignatureModule,
        ast_strategy,
        "start",
        base,
      )
    }
    InvalidImportedStartFuncParamModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-imported-start-func-param",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidImportedStartFuncParamModule,
        ast_strategy,
        "start",
        base,
      )
    }
    InvalidImportedStartFuncResultModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-imported-start-func-result",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidImportedStartFuncResultModule,
        ast_strategy,
        "start",
        base,
      )
    }
    InvalidImportedStartFuncParamResultModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-imported-start-func-param-result",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidImportedStartFuncParamResultModule,
        ast_strategy,
        "start",
        base,
      )
    }
    InvalidImportedStartFuncMultiParamModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-imported-start-func-multi-param",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidImportedStartFuncMultiParamModule,
        ast_strategy,
        "start",
        base,
      )
    }
    InvalidImportedStartFuncF32ParamModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-imported-start-func-f32-param",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidImportedStartFuncF32ParamModule,
        ast_strategy,
        "start",
        base,
      )
    }
    InvalidImportedStartFuncExternrefParamModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-imported-start-func-externref-param",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidImportedStartFuncExternrefParamModule,
        ast_strategy,
        "start",
        base,
      )
    }
    InvalidImportedStartFuncFuncrefParamModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-imported-start-func-funcref-param",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidImportedStartFuncFuncrefParamModule,
        ast_strategy,
        "start",
        base,
      )
    }
    DuplicateExportNameModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy("duplicate-export-name") {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        DuplicateExportNameModule,
        ast_strategy,
        "export",
        base,
      )
    }
    FuncSecWithoutCodeSecModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy("funcsec-without-codesec") {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        FuncSecWithoutCodeSecModule,
        ast_strategy,
        "code",
        base,
      )
    }
    DataCountWithoutDataSecModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "datacount-without-data-sec",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        DataCountWithoutDataSecModule,
        ast_strategy,
        "datacount",
        base,
      )
    }
    InvalidNameSectionFuncIndexModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-name-section-func-index",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidNameSectionFuncIndexModule,
        ast_strategy,
        "name",
        base,
      )
    }
    InvalidLocalNameSectionIndexModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-local-name-section-index",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidLocalNameSectionIndexModule,
        ast_strategy,
        "name",
        base,
      )
    }
    InvalidLabelNameSectionIndexModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-label-name-section-index",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidLabelNameSectionIndexModule,
        ast_strategy,
        "name",
        base,
      )
    }
    CodeSecWithoutFuncSecModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy("codesec-without-funcsec") {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        CodeSecWithoutFuncSecModule,
        ast_strategy,
        "code",
        base,
      )
    }
    InvalidTableNameSectionIndexModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-table-name-section-index",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidTableNameSectionIndexModule,
        ast_strategy,
        "name",
        base,
      )
    }
    InvalidGlobalNameSectionIndexModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-global-name-section-index",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidGlobalNameSectionIndexModule,
        ast_strategy,
        "name",
        base,
      )
    }
    InvalidTypeNameSectionIndexModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-type-name-section-index",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidTypeNameSectionIndexModule,
        ast_strategy,
        "name",
        base,
      )
    }
    InvalidFieldNameSectionIndexModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-field-name-section-index",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidFieldNameSectionIndexModule,
        ast_strategy,
        "name",
        base,
      )
    }
    InvalidElemNameSectionIndexModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-elem-name-section-index",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidElemNameSectionIndexModule,
        ast_strategy,
        "name",
        base,
      )
    }
    InvalidDataNameSectionIndexModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-data-name-section-index",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidDataNameSectionIndexModule,
        ast_strategy,
        "name",
        base,
      )
    }
    InvalidExportTableIndexModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-export-table-index",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidExportTableIndexModule,
        ast_strategy,
        "export",
        base,
      )
    }
    InvalidExportGlobalIndexModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-export-global-index",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidExportGlobalIndexModule,
        ast_strategy,
        "export",
        base,
      )
    }
    InvalidExportMemoryIndexModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-export-memory-index",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidExportMemoryIndexModule,
        ast_strategy,
        "export",
        base,
      )
    }
    InvalidExportTagIndexModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-export-tag-index",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidExportTagIndexModule,
        ast_strategy,
        "export",
        base,
      )
    }
    InvalidTagNameSectionIndexModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-tag-name-section-index",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidTagNameSectionIndexModule,
        ast_strategy,
        "name",
        base,
      )
    }
    InvalidImportedTagTypeIndexModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-imported-tag-type-index",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidImportedTagTypeIndexModule,
        ast_strategy,
        "import",
        base,
      )
    }
    DataCountMismatchTooSmallModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "datacount-mismatch-too-small",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        DataCountMismatchTooSmallModule,
        ast_strategy,
        "datacount",
        base,
      )
    }
    DataCountMismatchTooLargeModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "datacount-mismatch-too-large",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        DataCountMismatchTooLargeModule,
        ast_strategy,
        "datacount",
        base,
      )
    }
    InvalidBinaryBodyLocalSetValueTypeModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-function-body-local-set-value-type",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidBinaryBodyLocalSetValueTypeModule,
        ast_strategy,
        "function-body",
        base,
      )
    }
    InvalidBinaryBranchPayloadTypeModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-function-body-br-if-payload-mismatch",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidBinaryBranchPayloadTypeModule,
        ast_strategy,
        "function-body",
        base,
      )
    }
    InvalidBinaryLocalIndexModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-function-body-local-index",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidBinaryLocalIndexModule,
        ast_strategy,
        "function-body",
        base,
      )
    }
    InvalidBinaryCallRefTypeModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-function-body-call-ref-type",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidBinaryCallRefTypeModule,
        ast_strategy,
        "function-body",
        base,
      )
    }
    InvalidBinaryStructGetFieldIndexModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-function-body-struct-get-field-index",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidBinaryStructGetFieldIndexModule,
        ast_strategy,
        "function-body",
        base,
      )
    }
    InvalidBinaryThrowPayloadModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-function-body-throw-payload-mismatch",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidBinaryThrowPayloadModule,
        ast_strategy,
        "function-body",
        base,
      )
    }
    InvalidBinarySharedMemoryWithoutMaxModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "shared-memory-without-max",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidBinarySharedMemoryWithoutMaxModule,
        ast_strategy,
        "memory",
        base,
      )
    }
    InvalidBinaryMemory64AddressTypeModule => {
      let ast_strategy = match
        validate_invalid_binary_required_ast_strategy(
          "invalid-function-body-memory64-address-type",
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      validate_invalid_binary_mutate_encoded_invalid_ast_module(
        InvalidBinaryMemory64AddressTypeModule,
        ast_strategy,
        "function-body",
        base,
      )
    }
  }
}

///|
fn validate_invalid_binary_minimal_valid_module() -> Module {
  validate_invalid_binary_ensure_defined_func(Module::new())
}

///|
pub fn gen_invalid_binary_seed_module(
  rnd : @splitmix.RandomState,
  params : GenInvalidBinaryParams,
) -> Result[Module, String] {
  let base = match params.seed_mode {
    RandomValidSeed =>
      gen_valid_module_with_config(rnd, gen_invalid_binary_seed_config(params))
    MinimalValidSeed => validate_invalid_binary_minimal_valid_module()
  }
  match validate_module(base) {
    Ok(_) => Ok(base)
    Err(err) =>
      Err(
        "gen-invalid-binary base generation failed before corruption: strategy=\{validate_invalid_binary_strategy_label(params.strategy)} error=\{validation_error_message(err)}",
      )
  }
}

///|
pub fn gen_invalid_binary_generate(
  rnd : @splitmix.RandomState,
  params : GenInvalidBinaryParams,
) -> Result[GenInvalidBinaryGenerated, String] {
  let base = match gen_invalid_binary_seed_module(rnd, params) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let mutation = match
    apply_validate_invalid_binary_strategy(params.strategy, base) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  if !mutation.applicable {
    return Err(
      "gen-invalid-binary mutation was not applicable after valid seed generation: strategy=\{validate_invalid_binary_strategy_label(params.strategy)}",
    )
  }
  Ok({ base_module: base, mutation })
}

///|
pub fn build_validate_invalid_binary_minimal_repro(
  strategy : ValidateInvalidBinaryStrategyId,
) -> Result[Bytes, String] {
  let mutation = match
    apply_validate_invalid_binary_strategy(
      strategy,
      validate_invalid_binary_minimal_valid_module(),
    ) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  if !mutation.applicable {
    return Err("validate-invalid-binary minimal repro is not applicable")
  }
  Ok(mutation.mutated_bytes)
}

///|
pub fn build_validate_invalid_binary_minimal_repro_by_stable_id(
  stable_id : String,
) -> Result[Bytes, String] {
  let spec = match validate_invalid_binary_strategy_by_stable_id(stable_id) {
    Some(v) => v
    None =>
      return Err("unknown validate-invalid-binary strategy '\{stable_id}'")
  }
  build_validate_invalid_binary_minimal_repro(spec.id)
}

///|
fn validate_invalid_binary_empty_strategy_stats() -> Array[
  ValidateInvalidBinaryStrategyStats,
] {
  let stats : Array[ValidateInvalidBinaryStrategyStats] = []
  for spec in validate_invalid_binary_registry() {
    stats.push({
      strategy: spec.id,
      stable_id: spec.stable_id,
      variant_id: spec.variant_id,
      expected_result: spec.expected_result,
      expected_issue_kind: spec.expected_issue_kind,
      attempted: 0,
      applicable: 0,
      mutated: 0,
      decode_rejected: 0,
      validate_rejected: 0,
      rejected_expected: 0,
      accepted: 0,
      variant_attempted: 0,
      variant_applicable: 0,
      variant_mutated: 0,
      variant_rejected: 0,
      rejected_exact_issue: 0,
    })
  }
  stats
}

///|
fn validate_invalid_binary_update_strategy_stats(
  stats : Array[ValidateInvalidBinaryStrategyStats],
  idx : Int,
  attempted? : Int = stats[idx].attempted,
  applicable? : Int = stats[idx].applicable,
  mutated? : Int = stats[idx].mutated,
  decode_rejected? : Int = stats[idx].decode_rejected,
  validate_rejected? : Int = stats[idx].validate_rejected,
  rejected_expected? : Int = stats[idx].rejected_expected,
  accepted? : Int = stats[idx].accepted,
  variant_attempted? : Int = stats[idx].variant_attempted,
  variant_applicable? : Int = stats[idx].variant_applicable,
  variant_mutated? : Int = stats[idx].variant_mutated,
  variant_rejected? : Int = stats[idx].variant_rejected,
  rejected_exact_issue? : Int = stats[idx].rejected_exact_issue,
) -> Unit {
  let current = stats[idx]
  stats[idx] = {
    strategy: current.strategy,
    stable_id: current.stable_id,
    variant_id: current.variant_id,
    expected_result: current.expected_result,
    expected_issue_kind: current.expected_issue_kind,
    attempted,
    applicable,
    mutated,
    decode_rejected,
    validate_rejected,
    rejected_expected,
    accepted,
    variant_attempted,
    variant_applicable,
    variant_mutated,
    variant_rejected,
    rejected_exact_issue,
  }
}

///|
fn validate_invalid_binary_join(values : Array[String], sep : String) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  while i < values.length() {
    if i > 0 {
      out.write_string(sep)
    }
    out.write_string(values[i])
    i += 1
  }
  out.to_string()
}

///|
fn validate_invalid_binary_required_failure_messages(
  required_strategies : Array[ValidateInvalidBinaryStrategyId],
  stats : Array[ValidateInvalidBinaryStrategyStats],
) -> Array[String] {
  let failures : Array[String] = []
  for strategy in required_strategies {
    let stat = stats[validate_invalid_binary_strategy_index(strategy)]
    if stat.applicable == 0 {
      failures.push("\{stat.stable_id}: applicable=0")
      continue
    }
    if stat.mutated == 0 {
      failures.push("\{stat.stable_id}: mutated=0")
      continue
    }
    if stat.rejected_expected == 0 {
      failures.push(
        "\{stat.stable_id}: rejected_expected=0 expected=\{validate_invalid_binary_expected_result_label(stat.expected_result)} decode=\{stat.decode_rejected} validate=\{stat.validate_rejected} accepted=\{stat.accepted}",
      )
    }
  }
  failures
}

///|
fn validate_invalid_binary_stable_string_salt(value : String) -> UInt64 {
  let mut hash = 1469598103934665603UL
  let mut i = 0
  while i < value.length() {
    hash = hash ^ value[i].to_uint64()
    hash = hash * 1099511628211UL
    i += 1
  }
  hash
}

///|
fn validate_invalid_binary_seed_profile_salt(seed_profile : String) -> UInt64 {
  match seed_profile {
    "natural" => 0x6e61747572616cUL
    "coverage-forced" => 0x636f766572616765UL
    "small-natural" => 0x736d616c6c6e6174UL
    "small-coverage-forced" => 0x736d616c6c636f76UL
    "repro" => 0x726570726fUL
    "minimal" => 0x6d696e696d616cUL
    "rich" => 0x72696368UL
    _ => validate_invalid_binary_stable_string_salt(seed_profile)
  }
}

///|
fn validate_invalid_binary_stream_seed(seed : UInt64) -> UInt64 {
  for label in gen_valid_random_stream_labels() {
    if gen_valid_random_stream_label_name(label) == "invalid-mutation-choice" {
      return gen_valid_derive_stream_seed(seed, label)
    }
  }
  seed
}

///|
pub fn validate_invalid_binary_attempt_seed(
  seed : UInt64,
  stable_id : String,
  seed_profile : String,
) -> UInt64 {
  validate_invalid_binary_stream_seed(seed) ^
  validate_invalid_binary_stable_string_salt(stable_id) ^
  validate_invalid_binary_seed_profile_salt(seed_profile)
}

///|
fn validate_invalid_binary_params_for_seed_profile(
  strategy : ValidateInvalidBinaryStrategyId,
  seed_profile : String,
  generator_config : GenValidConfig,
) -> GenInvalidBinaryParams {
  match seed_profile {
    "natural" => GenInvalidBinaryParams::natural_seed(strategy)
    "coverage-forced" => GenInvalidBinaryParams::coverage_forced_seed(strategy)
    "small-natural" => GenInvalidBinaryParams::small_natural_seed(strategy)
    "small-coverage-forced" =>
      GenInvalidBinaryParams::small_coverage_forced_seed(strategy)
    "repro" => GenInvalidBinaryParams::repro_seed(strategy)
    "minimal" => GenInvalidBinaryParams::minimal_seed(strategy)
    _ => GenInvalidBinaryParams::rich_seed(strategy, generator_config~)
  }
}

///|
pub fn run_validate_invalid_binary_fuzz(
  profile : String,
  seed : UInt64,
) -> Result[ValidateInvalidBinaryFuzzStats, String] {
  let run_config = match validate_invalid_binary_run_config(profile) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let normalized = run_config.profile
  let attempts = run_config.attempts
  let generator_config = run_config.generator_config
  let required_strategies = run_config.required_strategies
  let seed_profiles = run_config.seed_profiles
  let registry = validate_invalid_binary_registry()
  if registry.is_empty() {
    return Err("validate-invalid-binary registry must not be empty")
  }
  let stats = validate_invalid_binary_empty_strategy_stats()
  let seed_profile_attempts = seed_profiles.map(fn(_) { 0 })
  let mut attempt = 0
  while attempt < attempts {
    let seed_profile_idx = attempt % seed_profiles.length()
    let seed_profile = seed_profiles[seed_profile_idx]
    seed_profile_attempts[seed_profile_idx] = seed_profile_attempts[seed_profile_idx] +
      1
    let strategy_attempt = attempt / seed_profiles.length()
    let spec = if strategy_attempt < required_strategies.length() {
      registry[validate_invalid_binary_strategy_index(
        required_strategies[strategy_attempt],
      )]
    } else {
      registry[strategy_attempt % registry.length()]
    }
    let stat_idx = validate_invalid_binary_strategy_index(spec.id)
    validate_invalid_binary_update_strategy_stats(
      stats,
      stat_idx,
      attempted=stats[stat_idx].attempted + 1,
      variant_attempted=stats[stat_idx].variant_attempted + 1,
    )
    let generated = match
      gen_invalid_binary_generate(
        @splitmix.new(
          seed=validate_invalid_binary_attempt_seed(
            seed,
            spec.stable_id,
            seed_profile,
          ),
        ),
        validate_invalid_binary_params_for_seed_profile(
          spec.id,
          seed_profile,
          generator_config,
        ),
      ) {
      Ok(v) => v
      Err(msg) =>
        return Err(
          "validate-invalid-binary generation failed: profile=\{normalized} seed=\{seed} attempt=\{attempt + 1} strategy=\{spec.stable_id} error=\{msg}",
        )
    }
    let mutation = generated.mutation
    if mutation.applicable {
      validate_invalid_binary_update_strategy_stats(
        stats,
        stat_idx,
        applicable=stats[stat_idx].applicable + 1,
        mutated=stats[stat_idx].mutated + 1,
        variant_applicable=stats[stat_idx].variant_applicable + 1,
        variant_mutated=stats[stat_idx].variant_mutated + 1,
      )
      match decode_module(mutation.mutated_bytes) {
        Err(_) => {
          let rejected_expected_now = match mutation.expected_result {
            DecodeRejected => stats[stat_idx].rejected_expected + 1
            ValidateRejected(_) => stats[stat_idx].rejected_expected
          }
          let rejected_exact_issue_now = match spec.expected_issue_kind {
            None =>
              if mutation.expected_result == DecodeRejected {
                stats[stat_idx].rejected_exact_issue + 1
              } else {
                stats[stat_idx].rejected_exact_issue
              }
            Some(_) => stats[stat_idx].rejected_exact_issue
          }
          validate_invalid_binary_update_strategy_stats(
            stats,
            stat_idx,
            decode_rejected=stats[stat_idx].decode_rejected + 1,
            rejected_expected=rejected_expected_now,
            variant_rejected=stats[stat_idx].variant_rejected + 1,
            rejected_exact_issue=rejected_exact_issue_now,
          )
        }
        Ok(decoded) =>
          match validate_module(decoded) {
            Ok(_) => {
              validate_invalid_binary_update_strategy_stats(
                stats,
                stat_idx,
                accepted=stats[stat_idx].accepted + 1,
              )
              return Err(
                "validate-invalid-binary accepted corrupted bytes: profile=\{normalized} seed=\{seed} attempt=\{attempt + 1} strategy=\{spec.stable_id}",
              )
            }
            Err(err) => {
              let family = validation_issue_family(
                validation_error_diagnostic(err).issue,
              )
              let family_label = validate_invalid_binary_validation_family_label(
                family,
              )
              let rejected_expected_now = match mutation.expected_result {
                DecodeRejected => stats[stat_idx].rejected_expected
                ValidateRejected(expected_family_label) =>
                  if family_label == expected_family_label {
                    stats[stat_idx].rejected_expected + 1
                  } else {
                    stats[stat_idx].rejected_expected
                  }
              }
              let rejected_exact_issue_now = match spec.expected_issue_kind {
                Some(expected_family_label) =>
                  if family_label == expected_family_label {
                    stats[stat_idx].rejected_exact_issue + 1
                  } else {
                    stats[stat_idx].rejected_exact_issue
                  }
                None => stats[stat_idx].rejected_exact_issue
              }
              validate_invalid_binary_update_strategy_stats(
                stats,
                stat_idx,
                validate_rejected=stats[stat_idx].validate_rejected + 1,
                rejected_expected=rejected_expected_now,
                variant_rejected=stats[stat_idx].variant_rejected + 1,
                rejected_exact_issue=rejected_exact_issue_now,
              )
            }
          }
      }
    }
    attempt += 1
  }
  let required_failures = validate_invalid_binary_required_failure_messages(
    required_strategies, stats,
  )
  if !required_failures.is_empty() {
    let joined_failures = validate_invalid_binary_join(required_failures, "; ")
    return Err(
      "validate-invalid-binary required strategy floors failed: profile=\{normalized} seed=\{seed} \{joined_failures}",
    )
  }
  Ok({
    profile: normalized,
    seed,
    attempts,
    generator_config,
    required_strategies,
    seed_profiles,
    seed_profile_attempts,
    strategy_stats: stats,
  })
}
