///|
pub enum ValidationIssueFamily {
  TypeSectionFamily
  ImportSectionFamily
  FunctionSectionFamily
  TableSectionFamily
  MemorySectionFamily
  TagSectionFamily
  GlobalSectionFamily
  ElementSectionFamily
  DataSectionFamily
  DataCountSectionFamily
  StartSectionFamily
  ExportSectionFamily
  CodeSectionFamily
  NameSectionFamily
  FunctionBodyFamily
} derive(Eq, Debug)

///|
pub fn validation_issue_family(
  issue : ValidationIssue,
) -> ValidationIssueFamily {
  match issue {
    TypeSection(_) => TypeSectionFamily
    ImportSection(_) => ImportSectionFamily
    FunctionSection(_) => FunctionSectionFamily
    TableSection(_) => TableSectionFamily
    MemorySection(_) => MemorySectionFamily
    TagSection(_) => TagSectionFamily
    GlobalSection(_) => GlobalSectionFamily
    ElementSection(_) => ElementSectionFamily
    DataSection(_) => DataSectionFamily
    DataCountSection(_) => DataCountSectionFamily
    StartSection(_) => StartSectionFamily
    ExportSection(_) => ExportSectionFamily
    CodeSection(_) => CodeSectionFamily
    NameSection(_) => NameSectionFamily
    FunctionBody(_) => FunctionBodyFamily
  }
}

///|
fn validation_issue_family_label(family : ValidationIssueFamily) -> String {
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
pub enum ValidateInvalidAstStrategyId {
  DuplicateExportName
  InvalidStartSignature
  InvalidImportedStartFuncParam
  InvalidImportedStartFuncResult
  InvalidImportedStartFuncParamResult
  InvalidImportedStartFuncMultiParam
  InvalidImportedStartFuncF32Param
  InvalidImportedStartFuncExternrefParam
  InvalidImportedStartFuncFuncrefParam
  MissingDataCount
  UndeclaredRefFunc
  InvalidFunctionBodyLocalIndex
  InvalidFunctionBodyGlobalIndex
  InvalidFunctionBodyTableIndex
  InvalidFunctionBodyMemoryIndex
  InvalidFunctionBodyCallIndex
  InvalidFunctionBodyBrLabelIndex
  InvalidFunctionBodyBrPayloadMismatch
  InvalidFunctionBodyCallPayloadMismatch
  InvalidFunctionBodyBrIfPayloadMismatch
  InvalidFunctionBodyBrTablePayloadMismatch
  InvalidFunctionBodyThrowPayloadMismatch
  InvalidFunctionBodyTryTableCatchPayloadMismatch
  InvalidFunctionBodyMemoryAddressType
  InvalidFunctionBodyMemory64AddressType
  InvalidFunctionBodyMemoryStoreValueType
  InvalidFunctionBodyMemoryGrowDeltaType
  InvalidFunctionBodyMemoryFillValueType
  InvalidFunctionBodyMemoryCopyLengthType
  InvalidFunctionBodyMemoryCopySourceType
  InvalidFunctionBodyMemoryCopyDestType
  InvalidFunctionBodyMemoryInitLengthType
  InvalidFunctionBodyMemoryInitSourceType
  InvalidFunctionBodyMemoryInitDestType
  InvalidFunctionBodyLocalSetValueType
  InvalidFunctionBodyLocalTeeValueType
  InvalidFunctionBodyReturnValueType
  InvalidFunctionBodyTableGetIndexType
  InvalidFunctionBodyTableGrowValueType
  InvalidFunctionBodyTableGrowDeltaType
  InvalidFunctionBodyTableFillValueType
  InvalidFunctionBodyTableFillDestType
  InvalidFunctionBodyTableFillLengthType
  InvalidFunctionBodyTableCopyLengthType
  InvalidFunctionBodyTableCopySourceType
  InvalidFunctionBodyTableCopyDestType
  InvalidFunctionBodyTableInitLengthType
  InvalidFunctionBodyTableInitSourceType
  InvalidFunctionBodyTableInitDestType
  InvalidFunctionBodyDataDropIndex
  InvalidFunctionBodyElemDropIndex
  InvalidFunctionBodyTableSizeIndex
  InvalidFunctionBodyTableSetIndexType
  InvalidFunctionBodyCallIndirectIndexType
  InvalidFunctionBodyReturnCallIndirectIndexType
  InvalidFunctionBodyReturnCallRefType
  InvalidFunctionBodyCallRefType
  InvalidFunctionBodyRefCastInputType
  InvalidFunctionBodyRefTestInputType
  InvalidFunctionBodyRefTestDescInputType
  InvalidFunctionBodyRefCastDescEqInputType
  InvalidFunctionBodyTableSetValueType
  InvalidFunctionBodyGlobalSetValueType
  InvalidNameSectionFuncIndex
  InvalidLocalNameSectionIndex
  InvalidLabelNameSectionIndex
  InvalidFuncTypeIndex
  FuncSecWithoutCodeSec
  MutableGlobalGetInConstInit
  NonConstantDataOffset
  InvalidImportedFuncTypeIndex
  InvalidImportedTagTypeIndex
  MutableGlobalGetInTableInit
  NonConstantElemOffset
  SharedMemoryWithoutMax
  SharedMemory64WithoutMax
  InvalidTagTypeIndex
  InvalidSubtypeSuperIndex
  InvalidSubtypeSuperShape
  DescriptorOnFuncType
  DataCountWithoutDataSec
  InvalidExportFuncIndex
  StartFuncOutOfRange
  MissingDataCountDataDrop
  InvalidMemoryNameSectionIndex
  CodeSecWithoutFuncSec
  InvalidTableNameSectionIndex
  InvalidGlobalNameSectionIndex
  InvalidTypeNameSectionIndex
  InvalidFieldNameSectionIndex
  InvalidElemNameSectionIndex
  InvalidDataNameSectionIndex
  InvalidExportTableIndex
  InvalidExportGlobalIndex
  InvalidExportMemoryIndex
  InvalidExportTagIndex
  InvalidTagNameSectionIndex
  DataCountMismatchTooSmall
  DataCountMismatchTooLarge
} derive(Eq, Debug)

///|
pub enum ValidateInvalidAstSeedPrerequisite {
  RequiresDefinedFunc
  RequiresMemoryData
} derive(Eq, Debug)

///|
pub struct ValidateInvalidAstStrategySpec {
  id : ValidateInvalidAstStrategyId
  stable_id : String
  variant_id : String
  display_name : String
  layer : String
  expected_family : ValidationIssueFamily
  expected_issue_kind : ValidationIssueFamily
  required_in_smoke : Bool
  seed_prerequisites : Array[ValidateInvalidAstSeedPrerequisite]
} derive(Eq, Debug)

///|
pub struct ValidateInvalidAstRunConfig {
  profile : String
  attempts : Int
  generator_config : GenValidConfig
  required_strategies : Array[ValidateInvalidAstStrategyId]
  seed_profiles : Array[GenInvalidNamedSeedProfile]
} derive(Eq, Debug)

///|
pub struct ValidateInvalidAstMutation {
  strategy : ValidateInvalidAstStrategyId
  applicable : Bool
  expected_family : ValidationIssueFamily
  mutated_module : Module
} derive(Debug)

///|
pub struct ValidateInvalidAstStrategyStats {
  strategy : ValidateInvalidAstStrategyId
  stable_id : String
  variant_id : String
  expected_family : ValidationIssueFamily
  expected_issue_kind : ValidationIssueFamily
  attempted : Int
  applicable : Int
  mutated : Int
  rejected : Int
  rejected_expected : Int
  variant_attempted : Int
  variant_applicable : Int
  variant_mutated : Int
  variant_rejected : Int
  rejected_exact_issue : Int
} derive(Eq, Debug)

///|
pub struct ValidateInvalidAstFuzzStats {
  profile : String
  seed : UInt64
  attempts : Int
  generator_config : GenValidConfig
  required_strategies : Array[ValidateInvalidAstStrategyId]
  seed_profiles : Array[GenInvalidNamedSeedProfile]
  seed_profile_attempts : Array[Int]
  strategy_stats : Array[ValidateInvalidAstStrategyStats]
} derive(Eq, Debug)

///|
fn validate_invalid_ast_strategy_spec(
  id : ValidateInvalidAstStrategyId,
  stable_id : String,
  display_name : String,
  expected_family : ValidationIssueFamily,
  required_in_smoke? : Bool = true,
  seed_prerequisites? : Array[ValidateInvalidAstSeedPrerequisite] = [],
) -> ValidateInvalidAstStrategySpec {
  {
    id,
    stable_id,
    variant_id: "default",
    display_name,
    layer: "ast",
    expected_family,
    expected_issue_kind: expected_family,
    required_in_smoke,
    seed_prerequisites,
  }
}

///|
pub fn validate_invalid_ast_registry() -> Array[ValidateInvalidAstStrategySpec] {
  [
    validate_invalid_ast_strategy_spec(
      DuplicateExportName,
      "duplicate-export-name",
      "duplicate export name",
      ExportSectionFamily,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidStartSignature,
      "invalid-start-signature",
      "invalid start signature",
      StartSectionFamily,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidImportedStartFuncParam,
      "invalid-imported-start-func-param",
      "invalid imported start function parameter list",
      StartSectionFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidImportedStartFuncResult,
      "invalid-imported-start-func-result",
      "invalid imported start function result list",
      StartSectionFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidImportedStartFuncParamResult,
      "invalid-imported-start-func-param-result",
      "invalid imported start function parameter and result list",
      StartSectionFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidImportedStartFuncMultiParam,
      "invalid-imported-start-func-multi-param",
      "invalid imported start function with multiple parameters",
      StartSectionFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidImportedStartFuncF32Param,
      "invalid-imported-start-func-f32-param",
      "invalid imported start function with an f32 parameter",
      StartSectionFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidImportedStartFuncExternrefParam,
      "invalid-imported-start-func-externref-param",
      "invalid imported start function with an externref parameter",
      StartSectionFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidImportedStartFuncFuncrefParam,
      "invalid-imported-start-func-funcref-param",
      "invalid imported start function with a funcref parameter",
      StartSectionFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      MissingDataCount,
      "missing-datacount",
      "missing datacount for bulk-memory use",
      FunctionBodyFamily,
      seed_prerequisites=[RequiresMemoryData],
    ),
    validate_invalid_ast_strategy_spec(
      UndeclaredRefFunc,
      "undeclared-ref-func",
      "undeclared ref.func",
      FunctionBodyFamily,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidNameSectionFuncIndex,
      "invalid-name-section-func-index",
      "invalid function name index",
      NameSectionFamily,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidLocalNameSectionIndex,
      "invalid-local-name-section-index",
      "invalid local name index",
      NameSectionFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidLabelNameSectionIndex,
      "invalid-label-name-section-index",
      "invalid label name index",
      NameSectionFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFuncTypeIndex,
      "invalid-func-type-index",
      "invalid function type index",
      FunctionSectionFamily,
    ),
    validate_invalid_ast_strategy_spec(
      FuncSecWithoutCodeSec,
      "funcsec-without-codesec",
      "function section without code section",
      CodeSectionFamily,
    ),
    validate_invalid_ast_strategy_spec(
      MutableGlobalGetInConstInit,
      "mutable-global-get-in-const-init",
      "mutable global.get in const global initializer",
      GlobalSectionFamily,
    ),
    validate_invalid_ast_strategy_spec(
      NonConstantDataOffset,
      "non-constant-data-offset",
      "non-constant active data offset",
      DataSectionFamily,
      seed_prerequisites=[RequiresMemoryData],
    ),
    validate_invalid_ast_strategy_spec(
      InvalidImportedFuncTypeIndex,
      "invalid-imported-func-type-index",
      "invalid imported function type index",
      ImportSectionFamily,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidImportedTagTypeIndex,
      "invalid-imported-tag-type-index",
      "invalid imported tag type index",
      ImportSectionFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      MutableGlobalGetInTableInit,
      "mutable-global-get-in-table-init",
      "mutable global.get in table initializer",
      TableSectionFamily,
    ),
    validate_invalid_ast_strategy_spec(
      NonConstantElemOffset,
      "non-constant-elem-offset",
      "non-constant active element offset",
      ElementSectionFamily,
    ),
    validate_invalid_ast_strategy_spec(
      SharedMemoryWithoutMax,
      "shared-memory-without-max",
      "shared memory without maximum",
      MemorySectionFamily,
    ),
    validate_invalid_ast_strategy_spec(
      SharedMemory64WithoutMax,
      "shared-memory64-without-max",
      "shared memory64 without maximum",
      MemorySectionFamily,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidTagTypeIndex,
      "invalid-tag-type-index",
      "invalid tag type index",
      TagSectionFamily,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidSubtypeSuperIndex,
      "invalid-subtype-super-index",
      "subtype super index out of range",
      TypeSectionFamily,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidSubtypeSuperShape,
      "invalid-subtype-super-shape",
      "subtype super shape mismatch",
      TypeSectionFamily,
    ),
    validate_invalid_ast_strategy_spec(
      DescriptorOnFuncType,
      "descriptor-on-func-type",
      "descriptor metadata on function type",
      TypeSectionFamily,
    ),
    validate_invalid_ast_strategy_spec(
      DataCountWithoutDataSec,
      "datacount-without-data-sec",
      "datacount section without data section",
      DataCountSectionFamily,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidExportFuncIndex,
      "invalid-export-func-index",
      "export function index out of range",
      ExportSectionFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      StartFuncOutOfRange,
      "start-func-out-of-range",
      "start function index out of range",
      StartSectionFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      MissingDataCountDataDrop,
      "missing-datacount-data-drop",
      "missing datacount for data.drop",
      FunctionBodyFamily,
      required_in_smoke=false,
      seed_prerequisites=[RequiresDefinedFunc, RequiresMemoryData],
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyLocalIndex,
      "invalid-function-body-local-index",
      "invalid local index in function body",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyGlobalIndex,
      "invalid-function-body-global-index",
      "invalid global index in function body",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyTableIndex,
      "invalid-function-body-table-index",
      "invalid table index in function body",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyMemoryIndex,
      "invalid-function-body-memory-index",
      "invalid memory index in function body",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyCallIndex,
      "invalid-function-body-call-index",
      "invalid function index in function body",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyBrLabelIndex,
      "invalid-function-body-branch-label-index",
      "invalid branch label index in function body",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyBrPayloadMismatch,
      "invalid-function-body-branch-payload-mismatch",
      "invalid function-body branch payload",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyCallPayloadMismatch,
      "invalid-function-body-call-payload-mismatch",
      "invalid function-body call payload",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyBrIfPayloadMismatch,
      "invalid-function-body-br-if-payload-mismatch",
      "invalid function-body br_if payload",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyBrTablePayloadMismatch,
      "invalid-function-body-br-table-payload-mismatch",
      "invalid function-body br_table payload",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyThrowPayloadMismatch,
      "invalid-function-body-throw-payload-mismatch",
      "invalid function-body throw payload",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyTryTableCatchPayloadMismatch,
      "invalid-function-body-try-table-catch-payload-mismatch",
      "invalid function-body try_table catch payload",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyMemoryAddressType,
      "invalid-function-body-memory-address-type",
      "invalid function-body memory address type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyMemory64AddressType,
      "invalid-function-body-memory64-address-type",
      "invalid function-body memory64 address type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyMemoryStoreValueType,
      "invalid-function-body-memory-store-value-type",
      "invalid function-body memory store value type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyMemoryGrowDeltaType,
      "invalid-function-body-memory-grow-delta-type",
      "invalid function-body memory.grow delta type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyMemoryFillValueType,
      "invalid-function-body-memory-fill-value-type",
      "invalid function-body memory.fill value type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyMemoryCopyLengthType,
      "invalid-function-body-memory-copy-length-type",
      "invalid function-body memory.copy length type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyMemoryCopySourceType,
      "invalid-function-body-memory-copy-source-type",
      "invalid function-body memory.copy source type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyMemoryCopyDestType,
      "invalid-function-body-memory-copy-dest-type",
      "invalid function-body memory.copy dest type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyMemoryInitLengthType,
      "invalid-function-body-memory-init-length-type",
      "invalid function-body memory.init length type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyMemoryInitSourceType,
      "invalid-function-body-memory-init-source-type",
      "invalid function-body memory.init source type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyMemoryInitDestType,
      "invalid-function-body-memory-init-dest-type",
      "invalid function-body memory.init dest type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyLocalSetValueType,
      "invalid-function-body-local-set-value-type",
      "invalid function-body local.set value type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyLocalTeeValueType,
      "invalid-function-body-local-tee-value-type",
      "invalid function-body local.tee value type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyReturnValueType,
      "invalid-function-body-return-value-type",
      "invalid function-body return value type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyTableGetIndexType,
      "invalid-function-body-table-get-index-type",
      "invalid function-body table.get index type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyTableGrowValueType,
      "invalid-function-body-table-grow-value-type",
      "invalid function-body table.grow value type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyTableGrowDeltaType,
      "invalid-function-body-table-grow-delta-type",
      "invalid function-body table.grow delta type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyTableFillValueType,
      "invalid-function-body-table-fill-value-type",
      "invalid function-body table.fill value type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyTableFillDestType,
      "invalid-function-body-table-fill-dest-type",
      "invalid function-body table.fill dest type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyTableFillLengthType,
      "invalid-function-body-table-fill-length-type",
      "invalid function-body table.fill length type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyTableCopyLengthType,
      "invalid-function-body-table-copy-length-type",
      "invalid function-body table.copy length type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyTableCopySourceType,
      "invalid-function-body-table-copy-source-type",
      "invalid function-body table.copy source type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyTableCopyDestType,
      "invalid-function-body-table-copy-dest-type",
      "invalid function-body table.copy dest type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyTableInitLengthType,
      "invalid-function-body-table-init-length-type",
      "invalid function-body table.init length type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyTableInitSourceType,
      "invalid-function-body-table-init-source-type",
      "invalid function-body table.init source type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyTableInitDestType,
      "invalid-function-body-table-init-dest-type",
      "invalid function-body table.init dest type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyDataDropIndex,
      "invalid-function-body-data-drop-index",
      "invalid function-body data.drop index",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyElemDropIndex,
      "invalid-function-body-elem-drop-index",
      "invalid function-body elem.drop index",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyTableSizeIndex,
      "invalid-function-body-table-size-index",
      "invalid function-body table.size index",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyTableSetIndexType,
      "invalid-function-body-table-set-index-type",
      "invalid function-body table.set index type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyCallIndirectIndexType,
      "invalid-function-body-call-indirect-index-type",
      "invalid function-body call_indirect table index type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyReturnCallIndirectIndexType,
      "invalid-function-body-return-call-indirect-index-type",
      "invalid function-body return_call_indirect table index type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyReturnCallRefType,
      "invalid-function-body-return-call-ref-type",
      "invalid function-body return_call_ref ref type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyCallRefType,
      "invalid-function-body-call-ref-type",
      "invalid function-body call_ref ref type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyRefCastInputType,
      "invalid-function-body-ref-cast-input-type",
      "invalid function-body ref.cast input type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyRefTestInputType,
      "invalid-function-body-ref-test-input-type",
      "invalid function-body ref.test input type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyRefTestDescInputType,
      "invalid-function-body-ref-test-desc-input-type",
      "invalid function-body ref.test_desc input type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyRefCastDescEqInputType,
      "invalid-function-body-ref-cast-desc-eq-input-type",
      "invalid function-body ref.cast_desc_eq input type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyTableSetValueType,
      "invalid-function-body-table-set-value-type",
      "invalid function-body table.set value type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFunctionBodyGlobalSetValueType,
      "invalid-function-body-global-set-value-type",
      "invalid function-body global.set value type",
      FunctionBodyFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidMemoryNameSectionIndex,
      "invalid-memory-name-section-index",
      "invalid memory name index",
      NameSectionFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      CodeSecWithoutFuncSec,
      "codesec-without-funcsec",
      "code section without function section",
      CodeSectionFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidTableNameSectionIndex,
      "invalid-table-name-section-index",
      "invalid table name index",
      NameSectionFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidGlobalNameSectionIndex,
      "invalid-global-name-section-index",
      "invalid global name index",
      NameSectionFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidTypeNameSectionIndex,
      "invalid-type-name-section-index",
      "invalid type name index",
      NameSectionFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidFieldNameSectionIndex,
      "invalid-field-name-section-index",
      "invalid field name index",
      NameSectionFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidElemNameSectionIndex,
      "invalid-elem-name-section-index",
      "invalid elem name index",
      NameSectionFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidDataNameSectionIndex,
      "invalid-data-name-section-index",
      "invalid data name index",
      NameSectionFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidExportTableIndex,
      "invalid-export-table-index",
      "export table index out of range",
      ExportSectionFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidExportGlobalIndex,
      "invalid-export-global-index",
      "export global index out of range",
      ExportSectionFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidExportMemoryIndex,
      "invalid-export-memory-index",
      "export memory index out of range",
      ExportSectionFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidExportTagIndex,
      "invalid-export-tag-index",
      "export tag index out of range",
      ExportSectionFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      InvalidTagNameSectionIndex,
      "invalid-tag-name-section-index",
      "invalid tag name index",
      NameSectionFamily,
      required_in_smoke=false,
    ),
    validate_invalid_ast_strategy_spec(
      DataCountMismatchTooSmall,
      "datacount-mismatch-too-small",
      "datacount section smaller than data segment count",
      DataCountSectionFamily,
      required_in_smoke=false,
      seed_prerequisites=[RequiresMemoryData],
    ),
    validate_invalid_ast_strategy_spec(
      DataCountMismatchTooLarge,
      "datacount-mismatch-too-large",
      "datacount section larger than data segment count",
      DataCountSectionFamily,
      required_in_smoke=false,
      seed_prerequisites=[RequiresMemoryData],
    ),
  ]
}

///|
pub fn validate_invalid_ast_strategy_spec_by_id(
  id : ValidateInvalidAstStrategyId,
) -> ValidateInvalidAstStrategySpec? {
  for spec in validate_invalid_ast_registry() {
    if spec.id == id {
      return Some(spec)
    }
  }
  None
}

///|
pub fn validate_invalid_ast_strategy_by_stable_id(
  stable_id : String,
) -> ValidateInvalidAstStrategySpec? {
  for spec in validate_invalid_ast_registry() {
    if spec.stable_id == stable_id {
      return Some(spec)
    }
  }
  None
}

///|
fn validate_invalid_ast_strategy_index(
  id : ValidateInvalidAstStrategyId,
) -> Int {
  match id {
    DuplicateExportName => 0
    InvalidStartSignature => 1
    InvalidImportedStartFuncParam => 2
    InvalidImportedStartFuncResult => 3
    InvalidImportedStartFuncParamResult => 4
    InvalidImportedStartFuncMultiParam => 5
    InvalidImportedStartFuncF32Param => 6
    InvalidImportedStartFuncExternrefParam => 7
    InvalidImportedStartFuncFuncrefParam => 8
    MissingDataCount => 9
    UndeclaredRefFunc => 10
    InvalidNameSectionFuncIndex => 11
    InvalidLocalNameSectionIndex => 12
    InvalidLabelNameSectionIndex => 13
    InvalidFuncTypeIndex => 14
    FuncSecWithoutCodeSec => 15
    MutableGlobalGetInConstInit => 16
    NonConstantDataOffset => 17
    InvalidImportedFuncTypeIndex => 18
    InvalidImportedTagTypeIndex => 19
    MutableGlobalGetInTableInit => 20
    NonConstantElemOffset => 21
    SharedMemoryWithoutMax => 22
    SharedMemory64WithoutMax => 23
    InvalidTagTypeIndex => 24
    InvalidSubtypeSuperIndex => 25
    InvalidSubtypeSuperShape => 26
    DescriptorOnFuncType => 27
    DataCountWithoutDataSec => 28
    InvalidExportFuncIndex => 29
    StartFuncOutOfRange => 30
    MissingDataCountDataDrop => 31
    InvalidFunctionBodyLocalIndex => 32
    InvalidFunctionBodyGlobalIndex => 33
    InvalidFunctionBodyTableIndex => 34
    InvalidFunctionBodyMemoryIndex => 35
    InvalidFunctionBodyCallIndex => 36
    InvalidFunctionBodyBrLabelIndex => 37
    InvalidFunctionBodyBrPayloadMismatch => 38
    InvalidFunctionBodyCallPayloadMismatch => 39
    InvalidFunctionBodyBrIfPayloadMismatch => 40
    InvalidFunctionBodyBrTablePayloadMismatch => 41
    InvalidFunctionBodyThrowPayloadMismatch => 42
    InvalidFunctionBodyTryTableCatchPayloadMismatch => 43
    InvalidFunctionBodyMemoryAddressType => 44
    InvalidFunctionBodyMemory64AddressType => 45
    InvalidFunctionBodyMemoryStoreValueType => 46
    InvalidFunctionBodyMemoryGrowDeltaType => 70
    InvalidFunctionBodyMemoryFillValueType => 71
    InvalidFunctionBodyMemoryCopyLengthType => 72
    InvalidFunctionBodyMemoryCopySourceType => 73
    InvalidFunctionBodyMemoryCopyDestType => 74
    InvalidFunctionBodyMemoryInitLengthType => 75
    InvalidFunctionBodyMemoryInitSourceType => 76
    InvalidFunctionBodyMemoryInitDestType => 77
    InvalidFunctionBodyLocalSetValueType => 64
    InvalidFunctionBodyLocalTeeValueType => 65
    InvalidFunctionBodyReturnValueType => 66
    InvalidFunctionBodyTableGetIndexType => 67
    InvalidFunctionBodyTableGrowValueType => 68
    InvalidFunctionBodyTableGrowDeltaType => 87
    InvalidFunctionBodyTableFillValueType => 69
    InvalidFunctionBodyTableFillDestType => 88
    InvalidFunctionBodyTableFillLengthType => 89
    InvalidFunctionBodyTableCopyLengthType => 78
    InvalidFunctionBodyTableCopySourceType => 79
    InvalidFunctionBodyTableCopyDestType => 80
    InvalidFunctionBodyTableInitLengthType => 81
    InvalidFunctionBodyTableInitSourceType => 82
    InvalidFunctionBodyTableInitDestType => 83
    InvalidFunctionBodyDataDropIndex => 84
    InvalidFunctionBodyElemDropIndex => 85
    InvalidFunctionBodyTableSizeIndex => 86
    InvalidFunctionBodyTableSetIndexType => 90
    InvalidFunctionBodyCallIndirectIndexType => 91
    InvalidFunctionBodyReturnCallIndirectIndexType => 92
    InvalidFunctionBodyReturnCallRefType => 93
    InvalidFunctionBodyCallRefType => 94
    InvalidFunctionBodyRefCastInputType => 95
    InvalidFunctionBodyRefTestInputType => 96
    InvalidFunctionBodyRefTestDescInputType => 97
    InvalidFunctionBodyRefCastDescEqInputType => 98
    InvalidFunctionBodyTableSetValueType => 62
    InvalidFunctionBodyGlobalSetValueType => 63
    InvalidMemoryNameSectionIndex => 47
    CodeSecWithoutFuncSec => 48
    InvalidTableNameSectionIndex => 49
    InvalidGlobalNameSectionIndex => 50
    InvalidTypeNameSectionIndex => 51
    InvalidFieldNameSectionIndex => 52
    InvalidElemNameSectionIndex => 53
    InvalidDataNameSectionIndex => 54
    InvalidExportTableIndex => 55
    InvalidExportGlobalIndex => 56
    InvalidExportMemoryIndex => 57
    InvalidExportTagIndex => 58
    InvalidTagNameSectionIndex => 59
    DataCountMismatchTooSmall => 60
    DataCountMismatchTooLarge => 61
  }
}

///|
fn validate_invalid_ast_required_strategies(
  normalized : String,
) -> Array[ValidateInvalidAstStrategyId] {
  ignore(normalized)
  validate_invalid_ast_registry()
  .filter(fn(spec) { spec.required_in_smoke })
  .map(fn(spec) { spec.id })
}

///|
fn validate_invalid_ast_profile_has_prefix(
  text : String,
  prefix : String,
) -> Bool {
  if text.length() < prefix.length() {
    return false
  }
  text.sub(end=prefix.length()).to_owned() == prefix
}

///|
fn validate_invalid_ast_seed_profile_by_name(
  name : String,
) -> Result[GenInvalidNamedSeedProfile, String] {
  match validate_fuzz_ascii_lower(name.trim().to_owned()) {
    "natural" => Ok(NaturalSeedProfile)
    "coverage-forced" => Ok(CoverageForcedSeedProfile)
    "small-natural" => Ok(SmallNaturalSeedProfile)
    "small-coverage-forced" => Ok(SmallCoverageForcedSeedProfile)
    "repro" => Ok(ReproSeedProfile)
    "minimal" => Ok(MinimalSeedProfile)
    "rich" => Ok(RichSeedProfile)
    other => Err("unknown validate-invalid-ast seed profile '\{other}'")
  }
}

///|
fn validate_invalid_ast_mixed_seed_profiles() -> Array[
  GenInvalidNamedSeedProfile,
] {
  [
    MinimalSeedProfile,
    ReproSeedProfile,
    SmallNaturalSeedProfile,
    SmallCoverageForcedSeedProfile,
    NaturalSeedProfile,
    CoverageForcedSeedProfile,
    RichSeedProfile,
  ]
}

///|
fn validate_invalid_ast_seed_profiles_from_modifier(
  raw : String,
) -> Result[Array[GenInvalidNamedSeedProfile], String] {
  let normalized = validate_fuzz_ascii_lower(raw.trim().to_owned())
  match normalized {
    "default" | "rich" => Ok([RichSeedProfile])
    "mixed" | "all" => Ok(validate_invalid_ast_mixed_seed_profiles())
    _ => {
      let out : Array[GenInvalidNamedSeedProfile] = []
      for part in normalized.split(",") {
        let item = part.trim().to_owned()
        if item.length() > 0 {
          match validate_invalid_ast_seed_profile_by_name(item) {
            Ok(v) => out.push(v)
            Err(msg) => return Err(msg)
          }
        }
      }
      if out.is_empty() {
        return Err("validate-invalid-ast seed profile list must not be empty")
      }
      Ok(out)
    }
  }
}

///|
pub fn validate_invalid_ast_run_config(
  profile : String,
) -> Result[ValidateInvalidAstRunConfig, String] {
  let raw = profile.trim().to_owned()
  let parts : Array[String] = []
  for part in raw.split("+") {
    parts.push(part.to_owned())
  }
  let normalized = if parts.length() == 0 ||
    parts[0].trim().to_owned().length() == 0 {
    "smoke"
  } else {
    validate_fuzz_ascii_lower(parts[0].trim().to_owned())
  }
  let strategy_count = validate_invalid_ast_registry().length()
  let base_attempts = match normalized {
    "smoke" => strategy_count
    "ci" => strategy_count * 10
    "stress" => strategy_count * 100
    _ =>
      return Err(
        "unknown validate-invalid-ast fuzz profile '\{profile}'; expected smoke|ci|stress",
      )
  }
  let mut seed_profiles : Array[GenInvalidNamedSeedProfile] = []
  let mut i = 1
  while i < parts.length() {
    let part = validate_fuzz_ascii_lower(parts[i].trim().to_owned())
    if part.length() == 0 {
      ()
    } else if validate_invalid_ast_profile_has_prefix(part, "seeds=") {
      match
        validate_invalid_ast_seed_profiles_from_modifier(
          part.sub(start=6).to_owned(),
        ) {
        Ok(v) => seed_profiles = v
        Err(msg) => return Err(msg)
      }
    } else if validate_invalid_ast_profile_has_prefix(part, "seed-profiles=") {
      match
        validate_invalid_ast_seed_profiles_from_modifier(
          part.sub(start=14).to_owned(),
        ) {
        Ok(v) => seed_profiles = v
        Err(msg) => return Err(msg)
      }
    } else {
      return Err(
        "unknown validate-invalid-ast profile modifier '\{parts[i]}' in '\{profile}'",
      )
    }
    i += 1
  }
  if seed_profiles.is_empty() {
    seed_profiles = [RichSeedProfile]
  }
  Ok({
    profile: normalized,
    attempts: base_attempts * seed_profiles.length(),
    generator_config: gen_invalid_coverage_seed_generator_config(),
    required_strategies: validate_invalid_ast_required_strategies(normalized),
    seed_profiles,
  })
}

///|
fn validate_invalid_ast_type_entries(mod : Module) -> Array[RecType] {
  match mod.type_sec {
    Some(TypeSec(entries)) => entries.copy()
    None => []
  }
}

///|
fn validate_invalid_ast_flat_type_count(mod : Module) -> Int {
  let mut count = 0
  for entry in validate_invalid_ast_type_entries(mod) {
    match entry {
      SingleRecType(_) => count += 1
      GroupRecType(group) => count += group.length()
    }
  }
  count
}

///|
fn validate_invalid_ast_func_type_entries(mod : Module) -> Array[TypeIdx] {
  match mod.func_sec {
    Some(FuncSec(entries)) => entries.copy()
    None => []
  }
}

///|
fn validate_invalid_ast_code_entries(mod : Module) -> Array[Func] {
  match mod.code_sec {
    Some(CodeSec(entries)) => entries.copy()
    None => []
  }
}

///|
fn validate_invalid_ast_export_entries(mod : Module) -> Array[Export] {
  match mod.export_sec {
    Some(ExportSec(entries)) => entries.copy()
    None => []
  }
}

///|
fn validate_invalid_ast_import_entries(mod : Module) -> Array[Import] {
  match mod.import_sec {
    Some(ImportSec(entries)) => entries.copy()
    None => []
  }
}

///|
fn validate_invalid_ast_mem_entries(mod : Module) -> Array[MemType] {
  match mod.mem_sec {
    Some(MemSec(entries)) => entries.copy()
    None => []
  }
}

///|
fn validate_invalid_ast_table_entries(mod : Module) -> Array[Table] {
  match mod.table_sec {
    Some(TableSec(entries)) => entries.copy()
    None => []
  }
}

///|
fn validate_invalid_ast_data_entries(mod : Module) -> Array[Data] {
  match mod.data_sec {
    Some(DataSec(entries)) => entries.copy()
    None => []
  }
}

///|
fn validate_invalid_ast_elem_entries(mod : Module) -> Array[Elem] {
  match mod.elem_sec {
    Some(ElemSec(entries)) => entries.copy()
    None => []
  }
}

///|
fn validate_invalid_ast_global_entries(mod : Module) -> Array[Global] {
  match mod.global_sec {
    Some(GlobalSec(entries)) => entries.copy()
    None => []
  }
}

///|
fn validate_invalid_ast_tag_entries(mod : Module) -> Array[TagType] {
  match mod.tag_sec {
    Some(TagSec(entries)) => entries.copy()
    None => []
  }
}

///|
fn validate_invalid_ast_imported_func_count(mod : Module) -> Int {
  let mut count = 0
  for imp in validate_invalid_ast_import_entries(mod) {
    let Import(_, _, et) = imp
    if et is FuncExternType(_) {
      count += 1
    }
  }
  count
}

///|
fn validate_invalid_ast_defined_func_count(mod : Module) -> Int {
  validate_invalid_ast_func_type_entries(mod).length()
}

///|
fn validate_invalid_ast_imported_global_count(mod : Module) -> Int {
  let mut count = 0
  for imp in validate_invalid_ast_import_entries(mod) {
    let Import(_, _, et) = imp
    if et is GlobalExternType(_) {
      count += 1
    }
  }
  count
}

///|
fn validate_invalid_ast_imported_table_count(mod : Module) -> Int {
  let mut count = 0
  for imp in validate_invalid_ast_import_entries(mod) {
    let Import(_, _, et) = imp
    if et is TableExternType(_) {
      count += 1
    }
  }
  count
}

///|
fn validate_invalid_ast_imported_mem_count(mod : Module) -> Int {
  let mut count = 0
  for imp in validate_invalid_ast_import_entries(mod) {
    let Import(_, _, et) = imp
    if et is MemExternType(_) {
      count += 1
    }
  }
  count
}

///|
fn validate_invalid_ast_imported_tag_count(mod : Module) -> Int {
  let mut count = 0
  for imp in validate_invalid_ast_import_entries(mod) {
    let Import(_, _, et) = imp
    if et is TagExternType(_) {
      count += 1
    }
  }
  count
}

///|
fn validate_invalid_ast_total_func_count(mod : Module) -> Int {
  validate_invalid_ast_imported_func_count(mod) +
  validate_invalid_ast_defined_func_count(mod)
}

///|
fn validate_invalid_ast_total_table_count(mod : Module) -> Int {
  validate_invalid_ast_imported_table_count(mod) +
  validate_invalid_ast_table_entries(mod).length()
}

///|
fn validate_invalid_ast_total_global_count(mod : Module) -> Int {
  validate_invalid_ast_imported_global_count(mod) +
  validate_invalid_ast_global_entries(mod).length()
}

///|
fn validate_invalid_ast_total_mem_count(mod : Module) -> Int {
  validate_invalid_ast_imported_mem_count(mod) +
  validate_invalid_ast_mem_entries(mod).length()
}

///|
fn validate_invalid_ast_total_tag_count(mod : Module) -> Int {
  validate_invalid_ast_imported_tag_count(mod) +
  validate_invalid_ast_tag_entries(mod).length()
}

///|
fn validate_invalid_ast_append_defined_func(
  mod : Module,
  params : Array[ValType],
  results : Array[ValType],
  locals : Locals,
  body : Expr,
) -> (Module, FuncIdx, TypeIdx) {
  let types = validate_invalid_ast_type_entries(mod)
  let func_types = validate_invalid_ast_func_type_entries(mod)
  let code = validate_invalid_ast_code_entries(mod)
  let type_idx = TypeIdx::new(
    validate_invalid_ast_flat_type_count(mod).reinterpret_as_uint(),
  )
  let func_idx = FuncIdx::new(
    (validate_invalid_ast_imported_func_count(mod) +
    validate_invalid_ast_defined_func_count(mod)).reinterpret_as_uint(),
  )
  types.push(RecType::new(SubType::comp_type(CompType::func(params, results))))
  func_types.push(type_idx)
  code.push(Func::new(locals, body))
  (
    mod
    .with_type_sec(TypeSec::new(types))
    .with_func_sec(FuncSec::new(func_types))
    .with_code_sec(CodeSec::new(code)),
    func_idx,
    type_idx,
  )
}

///|
fn validate_invalid_ast_append_tag(
  mod : Module,
  params : Array[ValType],
) -> (Module, TagIdx, TypeIdx) {
  let types = validate_invalid_ast_type_entries(mod)
  let tags = validate_invalid_ast_tag_entries(mod)
  let type_idx = TypeIdx::new(
    validate_invalid_ast_flat_type_count(mod).reinterpret_as_uint(),
  )
  let tag_idx = TagIdx::new(
    validate_invalid_ast_total_tag_count(mod).reinterpret_as_uint(),
  )
  types.push(RecType::new(SubType::comp_type(CompType::func(params, []))))
  tags.push(TagType::new(type_idx))
  (
    mod.with_type_sec(TypeSec::new(types)).with_tag_sec(TagSec::new(tags)),
    tag_idx,
    type_idx,
  )
}

///|
fn validate_invalid_ast_ensure_any_func(mod : Module) -> (Module, FuncIdx) {
  if validate_invalid_ast_total_func_count(mod) > 0 {
    return (mod, FuncIdx::new(0U))
  }
  let (next, func_idx, _) = validate_invalid_ast_append_defined_func(
    mod,
    [],
    [],
    Locals::empty(),
    Expr::new([]),
  )
  (next, func_idx)
}

///|
fn validate_invalid_ast_ensure_memory(mod : Module) -> Module {
  if validate_invalid_ast_mem_entries(mod).length() > 0 {
    return mod
  }
  mod.with_mem_sec(MemSec::new([MemType::new(Limits::i32(1U, Some(1U)))]))
}

///|
fn validate_invalid_ast_append_passive_data(mod : Module) -> (Module, DataIdx) {
  let datas = validate_invalid_ast_data_entries(mod)
  let idx = DataIdx::new(datas.length().reinterpret_as_uint())
  datas.push(Data::new(DataMode::passive(), b"x"))
  (mod.with_data_sec(DataSec::new(datas)), idx)
}

///|
fn validate_invalid_ast_without_data_cnt_sec(mod : Module) -> Module {
  Module::new(
    custom_secs=mod.custom_secs,
    name_sec=mod.name_sec,
    raw_name_sec_payload=mod.raw_name_sec_payload,
    type_sec=mod.type_sec,
    import_sec=mod.import_sec,
    func_annotation_sec=mod.func_annotation_sec,
    func_sec=mod.func_sec,
    table_sec=mod.table_sec,
    mem_sec=mod.mem_sec,
    tag_sec=mod.tag_sec,
    stringrefs_sec=mod.stringrefs_sec,
    global_sec=mod.global_sec,
    export_sec=mod.export_sec,
    start_sec=mod.start_sec,
    elem_sec=mod.elem_sec,
    data_cnt_sec=None,
    code_sec=mod.code_sec,
    data_sec=mod.data_sec,
  )
}

///|
fn validate_invalid_ast_without_code_sec(mod : Module) -> Module {
  Module::new(
    custom_secs=mod.custom_secs,
    name_sec=mod.name_sec,
    raw_name_sec_payload=mod.raw_name_sec_payload,
    type_sec=mod.type_sec,
    import_sec=mod.import_sec,
    func_annotation_sec=mod.func_annotation_sec,
    func_sec=mod.func_sec,
    table_sec=mod.table_sec,
    mem_sec=mod.mem_sec,
    tag_sec=mod.tag_sec,
    stringrefs_sec=mod.stringrefs_sec,
    global_sec=mod.global_sec,
    export_sec=mod.export_sec,
    start_sec=mod.start_sec,
    elem_sec=mod.elem_sec,
    data_cnt_sec=mod.data_cnt_sec,
    code_sec=None,
    data_sec=mod.data_sec,
  )
}

///|
fn validate_invalid_ast_without_data_sec(mod : Module) -> Module {
  Module::new(
    custom_secs=mod.custom_secs,
    name_sec=mod.name_sec,
    raw_name_sec_payload=mod.raw_name_sec_payload,
    type_sec=mod.type_sec,
    import_sec=mod.import_sec,
    func_annotation_sec=mod.func_annotation_sec,
    func_sec=mod.func_sec,
    table_sec=mod.table_sec,
    mem_sec=mod.mem_sec,
    tag_sec=mod.tag_sec,
    stringrefs_sec=mod.stringrefs_sec,
    global_sec=mod.global_sec,
    export_sec=mod.export_sec,
    start_sec=mod.start_sec,
    elem_sec=mod.elem_sec,
    data_cnt_sec=mod.data_cnt_sec,
    code_sec=mod.code_sec,
    data_sec=None,
  )
}

///|
fn validate_invalid_ast_without_func_sec(mod : Module) -> Module {
  Module::new(
    custom_secs=mod.custom_secs,
    name_sec=mod.name_sec,
    raw_name_sec_payload=mod.raw_name_sec_payload,
    type_sec=mod.type_sec,
    import_sec=mod.import_sec,
    func_annotation_sec=mod.func_annotation_sec,
    func_sec=None,
    table_sec=mod.table_sec,
    mem_sec=mod.mem_sec,
    tag_sec=mod.tag_sec,
    stringrefs_sec=mod.stringrefs_sec,
    global_sec=mod.global_sec,
    export_sec=mod.export_sec,
    start_sec=mod.start_sec,
    elem_sec=mod.elem_sec,
    data_cnt_sec=mod.data_cnt_sec,
    code_sec=mod.code_sec,
    data_sec=mod.data_sec,
  )
}

///|
fn validate_invalid_ast_with_func_names(
  mod : Module,
  func_names : NameMap,
) -> Module {
  let next_name_sec = match mod.name_sec {
    Some(name_sec) =>
      NameSec::new(
        module_name=name_sec.module_name,
        func_names=Some(func_names),
        local_names=name_sec.local_names,
        label_names=name_sec.label_names,
        type_names=name_sec.type_names,
        table_names=name_sec.table_names,
        memory_names=name_sec.memory_names,
        global_names=name_sec.global_names,
        elem_names=name_sec.elem_names,
        data_names=name_sec.data_names,
        field_names=name_sec.field_names,
        tag_names=name_sec.tag_names,
      )
    None => NameSec::new(func_names=Some(func_names))
  }
  mod.with_name_sec(next_name_sec)
}

///|
fn validate_invalid_ast_with_local_names(
  mod : Module,
  local_names : IndirectNameMap,
) -> Module {
  let next_name_sec = match mod.name_sec {
    Some(name_sec) =>
      NameSec::new(
        module_name=name_sec.module_name,
        func_names=name_sec.func_names,
        local_names=Some(local_names),
        label_names=name_sec.label_names,
        type_names=name_sec.type_names,
        table_names=name_sec.table_names,
        memory_names=name_sec.memory_names,
        global_names=name_sec.global_names,
        elem_names=name_sec.elem_names,
        data_names=name_sec.data_names,
        field_names=name_sec.field_names,
        tag_names=name_sec.tag_names,
      )
    None => NameSec::new(local_names=Some(local_names))
  }
  mod.with_name_sec(next_name_sec)
}

///|
fn validate_invalid_ast_with_label_names(
  mod : Module,
  label_names : IndirectNameMap,
) -> Module {
  let next_name_sec = match mod.name_sec {
    Some(name_sec) =>
      NameSec::new(
        module_name=name_sec.module_name,
        func_names=name_sec.func_names,
        local_names=name_sec.local_names,
        label_names=Some(label_names),
        type_names=name_sec.type_names,
        table_names=name_sec.table_names,
        memory_names=name_sec.memory_names,
        global_names=name_sec.global_names,
        elem_names=name_sec.elem_names,
        data_names=name_sec.data_names,
        field_names=name_sec.field_names,
        tag_names=name_sec.tag_names,
      )
    None => NameSec::new(label_names=Some(label_names))
  }
  mod.with_name_sec(next_name_sec)
}

///|
fn validate_invalid_ast_with_memory_names(
  mod : Module,
  memory_names : NameMap,
) -> Module {
  let next_name_sec = match mod.name_sec {
    Some(name_sec) =>
      NameSec::new(
        module_name=name_sec.module_name,
        func_names=name_sec.func_names,
        local_names=name_sec.local_names,
        label_names=name_sec.label_names,
        type_names=name_sec.type_names,
        table_names=name_sec.table_names,
        memory_names=Some(memory_names),
        global_names=name_sec.global_names,
        elem_names=name_sec.elem_names,
        data_names=name_sec.data_names,
        field_names=name_sec.field_names,
        tag_names=name_sec.tag_names,
      )
    None => NameSec::new(memory_names=Some(memory_names))
  }
  mod.with_name_sec(next_name_sec)
}

///|
fn validate_invalid_ast_with_table_names(
  mod : Module,
  table_names : NameMap,
) -> Module {
  let next_name_sec = match mod.name_sec {
    Some(name_sec) =>
      NameSec::new(
        module_name=name_sec.module_name,
        func_names=name_sec.func_names,
        local_names=name_sec.local_names,
        label_names=name_sec.label_names,
        type_names=name_sec.type_names,
        table_names=Some(table_names),
        memory_names=name_sec.memory_names,
        global_names=name_sec.global_names,
        elem_names=name_sec.elem_names,
        data_names=name_sec.data_names,
        field_names=name_sec.field_names,
        tag_names=name_sec.tag_names,
      )
    None => NameSec::new(table_names=Some(table_names))
  }
  mod.with_name_sec(next_name_sec)
}

///|
fn validate_invalid_ast_with_global_names(
  mod : Module,
  global_names : NameMap,
) -> Module {
  let next_name_sec = match mod.name_sec {
    Some(name_sec) =>
      NameSec::new(
        module_name=name_sec.module_name,
        func_names=name_sec.func_names,
        local_names=name_sec.local_names,
        label_names=name_sec.label_names,
        type_names=name_sec.type_names,
        table_names=name_sec.table_names,
        memory_names=name_sec.memory_names,
        global_names=Some(global_names),
        elem_names=name_sec.elem_names,
        data_names=name_sec.data_names,
        field_names=name_sec.field_names,
        tag_names=name_sec.tag_names,
      )
    None => NameSec::new(global_names=Some(global_names))
  }
  mod.with_name_sec(next_name_sec)
}

///|
fn validate_invalid_ast_with_type_names(
  mod : Module,
  type_names : NameMap,
) -> Module {
  let next_name_sec = match mod.name_sec {
    Some(name_sec) =>
      NameSec::new(
        module_name=name_sec.module_name,
        func_names=name_sec.func_names,
        local_names=name_sec.local_names,
        label_names=name_sec.label_names,
        type_names=Some(type_names),
        table_names=name_sec.table_names,
        memory_names=name_sec.memory_names,
        global_names=name_sec.global_names,
        elem_names=name_sec.elem_names,
        data_names=name_sec.data_names,
        field_names=name_sec.field_names,
        tag_names=name_sec.tag_names,
      )
    None => NameSec::new(type_names=Some(type_names))
  }
  mod.with_name_sec(next_name_sec)
}

///|
fn validate_invalid_ast_with_field_names(
  mod : Module,
  field_names : IndirectNameMap,
) -> Module {
  let next_name_sec = match mod.name_sec {
    Some(name_sec) =>
      NameSec::new(
        module_name=name_sec.module_name,
        func_names=name_sec.func_names,
        local_names=name_sec.local_names,
        label_names=name_sec.label_names,
        type_names=name_sec.type_names,
        table_names=name_sec.table_names,
        memory_names=name_sec.memory_names,
        global_names=name_sec.global_names,
        elem_names=name_sec.elem_names,
        data_names=name_sec.data_names,
        field_names=Some(field_names),
        tag_names=name_sec.tag_names,
      )
    None => NameSec::new(field_names=Some(field_names))
  }
  mod.with_name_sec(next_name_sec)
}

///|
fn validate_invalid_ast_with_elem_names(
  mod : Module,
  elem_names : NameMap,
) -> Module {
  let next_name_sec = match mod.name_sec {
    Some(name_sec) =>
      NameSec::new(
        module_name=name_sec.module_name,
        func_names=name_sec.func_names,
        local_names=name_sec.local_names,
        label_names=name_sec.label_names,
        type_names=name_sec.type_names,
        table_names=name_sec.table_names,
        memory_names=name_sec.memory_names,
        global_names=name_sec.global_names,
        elem_names=Some(elem_names),
        data_names=name_sec.data_names,
        field_names=name_sec.field_names,
        tag_names=name_sec.tag_names,
      )
    None => NameSec::new(elem_names=Some(elem_names))
  }
  mod.with_name_sec(next_name_sec)
}

///|
fn validate_invalid_ast_with_data_names(
  mod : Module,
  data_names : NameMap,
) -> Module {
  let next_name_sec = match mod.name_sec {
    Some(name_sec) =>
      NameSec::new(
        module_name=name_sec.module_name,
        func_names=name_sec.func_names,
        local_names=name_sec.local_names,
        label_names=name_sec.label_names,
        type_names=name_sec.type_names,
        table_names=name_sec.table_names,
        memory_names=name_sec.memory_names,
        global_names=name_sec.global_names,
        elem_names=name_sec.elem_names,
        data_names=Some(data_names),
        field_names=name_sec.field_names,
        tag_names=name_sec.tag_names,
      )
    None => NameSec::new(data_names=Some(data_names))
  }
  mod.with_name_sec(next_name_sec)
}

///|
fn validate_invalid_ast_with_tag_names(
  mod : Module,
  tag_names : NameMap,
) -> Module {
  let next_name_sec = match mod.name_sec {
    Some(name_sec) =>
      NameSec::new(
        module_name=name_sec.module_name,
        func_names=name_sec.func_names,
        local_names=name_sec.local_names,
        label_names=name_sec.label_names,
        type_names=name_sec.type_names,
        table_names=name_sec.table_names,
        memory_names=name_sec.memory_names,
        global_names=name_sec.global_names,
        elem_names=name_sec.elem_names,
        data_names=name_sec.data_names,
        field_names=name_sec.field_names,
        tag_names=Some(tag_names),
      )
    None => NameSec::new(tag_names=Some(tag_names))
  }
  mod.with_name_sec(next_name_sec)
}

///|
fn validate_invalid_ast_mutate_duplicate_export_name(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let (base, target_func) = validate_invalid_ast_ensure_any_func(mod)
  let exports = validate_invalid_ast_export_entries(base)
  let duplicate_name = if exports.length() > 0 {
    let Export(name, _) = exports[0]
    name
  } else {
    Name::new("dup")
  }
  if exports.is_empty() {
    exports.push(Export::new(duplicate_name, ExternIdx::func(target_func)))
  }
  exports.push(Export::new(duplicate_name, ExternIdx::func(target_func)))
  {
    strategy: DuplicateExportName,
    applicable: true,
    expected_family: ExportSectionFamily,
    mutated_module: base.with_export_sec(ExportSec::new(exports)),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_export_func_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let bad_idx = FuncIdx::new(
    validate_invalid_ast_total_func_count(mod).reinterpret_as_uint(),
  )
  let exports = validate_invalid_ast_export_entries(mod)
  exports.push(Export::new(Name::new("bad"), ExternIdx::func(bad_idx)))
  {
    strategy: InvalidExportFuncIndex,
    applicable: true,
    expected_family: ExportSectionFamily,
    mutated_module: mod.with_export_sec(ExportSec::new(exports)),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_export_table_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let bad_idx = TableIdx::new(
    validate_invalid_ast_total_table_count(mod).reinterpret_as_uint(),
  )
  let exports = validate_invalid_ast_export_entries(mod)
  exports.push(Export::new(Name::new("bad-table"), ExternIdx::table(bad_idx)))
  {
    strategy: InvalidExportTableIndex,
    applicable: true,
    expected_family: ExportSectionFamily,
    mutated_module: mod.with_export_sec(ExportSec::new(exports)),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_export_global_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let bad_idx = GlobalIdx::new(
    validate_invalid_ast_total_global_count(mod).reinterpret_as_uint(),
  )
  let exports = validate_invalid_ast_export_entries(mod)
  exports.push(Export::new(Name::new("bad-global"), ExternIdx::global(bad_idx)))
  {
    strategy: InvalidExportGlobalIndex,
    applicable: true,
    expected_family: ExportSectionFamily,
    mutated_module: mod.with_export_sec(ExportSec::new(exports)),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_export_memory_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let bad_idx = MemIdx::new(
    validate_invalid_ast_total_mem_count(mod).reinterpret_as_uint(),
  )
  let exports = validate_invalid_ast_export_entries(mod)
  exports.push(Export::new(Name::new("bad-memory"), ExternIdx::mem(bad_idx)))
  {
    strategy: InvalidExportMemoryIndex,
    applicable: true,
    expected_family: ExportSectionFamily,
    mutated_module: mod.with_export_sec(ExportSec::new(exports)),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_export_tag_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let bad_idx = TagIdx::new(
    validate_invalid_ast_total_tag_count(mod).reinterpret_as_uint(),
  )
  let exports = validate_invalid_ast_export_entries(mod)
  exports.push(Export::new(Name::new("bad-tag"), ExternIdx::tag(bad_idx)))
  {
    strategy: InvalidExportTagIndex,
    applicable: true,
    expected_family: ExportSectionFamily,
    mutated_module: mod.with_export_sec(ExportSec::new(exports)),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_start_signature(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let (base, func_idx, _) = validate_invalid_ast_append_defined_func(
    mod,
    [ValType::i32()],
    [],
    Locals::empty(),
    Expr::new([]),
  )
  {
    strategy: InvalidStartSignature,
    applicable: true,
    expected_family: StartSectionFamily,
    mutated_module: base.with_start_sec(StartSec::new(func_idx)),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_imported_start_func_param(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let type_idx = TypeIdx::new(0U)
  let imported = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([ValType::i32()], []))),
      ]),
    )
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("start"),
          ExternType::func(type_idx),
        ),
      ]),
    )
  {
    strategy: InvalidImportedStartFuncParam,
    applicable: true,
    expected_family: StartSectionFamily,
    mutated_module: imported.with_start_sec(StartSec::new(FuncIdx::new(0U))),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_imported_start_func_result(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let type_idx = TypeIdx::new(0U)
  let imported = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], [ValType::i32()]))),
      ]),
    )
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("start"),
          ExternType::func(type_idx),
        ),
      ]),
    )
  {
    strategy: InvalidImportedStartFuncResult,
    applicable: true,
    expected_family: StartSectionFamily,
    mutated_module: imported.with_start_sec(StartSec::new(FuncIdx::new(0U))),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_imported_start_func_param_result(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let type_idx = TypeIdx::new(0U)
  let imported = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(
          SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
        ),
      ]),
    )
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("start"),
          ExternType::func(type_idx),
        ),
      ]),
    )
  {
    strategy: InvalidImportedStartFuncParamResult,
    applicable: true,
    expected_family: StartSectionFamily,
    mutated_module: imported.with_start_sec(StartSec::new(FuncIdx::new(0U))),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_imported_start_func_multi_param(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let type_idx = TypeIdx::new(0U)
  let imported = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(
          SubType::comp_type(
            CompType::func([ValType::i32(), ValType::i32()], []),
          ),
        ),
      ]),
    )
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("start"),
          ExternType::func(type_idx),
        ),
      ]),
    )
  {
    strategy: InvalidImportedStartFuncMultiParam,
    applicable: true,
    expected_family: StartSectionFamily,
    mutated_module: imported.with_start_sec(StartSec::new(FuncIdx::new(0U))),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_imported_start_func_f32_param(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let type_idx = TypeIdx::new(0U)
  let imported = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([ValType::f32()], []))),
      ]),
    )
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("start"),
          ExternType::func(type_idx),
        ),
      ]),
    )
  {
    strategy: InvalidImportedStartFuncF32Param,
    applicable: true,
    expected_family: StartSectionFamily,
    mutated_module: imported.with_start_sec(StartSec::new(FuncIdx::new(0U))),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_imported_start_func_externref_param(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let type_idx = TypeIdx::new(0U)
  let externref = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::extern_())),
  )
  let imported = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([externref], []))),
      ]),
    )
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("start"),
          ExternType::func(type_idx),
        ),
      ]),
    )
  {
    strategy: InvalidImportedStartFuncExternrefParam,
    applicable: true,
    expected_family: StartSectionFamily,
    mutated_module: imported.with_start_sec(StartSec::new(FuncIdx::new(0U))),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_imported_start_func_funcref_param(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let type_idx = TypeIdx::new(0U)
  let funcref = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let imported = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([funcref], []))),
      ]),
    )
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("start"),
          ExternType::func(type_idx),
        ),
      ]),
    )
  {
    strategy: InvalidImportedStartFuncFuncrefParam,
    applicable: true,
    expected_family: StartSectionFamily,
    mutated_module: imported.with_start_sec(StartSec::new(FuncIdx::new(0U))),
  }
}

///|
fn validate_invalid_ast_mutate_start_func_out_of_range(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let bad_idx = FuncIdx::new(
    validate_invalid_ast_total_func_count(mod).reinterpret_as_uint(),
  )
  {
    strategy: StartFuncOutOfRange,
    applicable: true,
    expected_family: StartSectionFamily,
    mutated_module: mod.with_start_sec(StartSec::new(bad_idx)),
  }
}

///|
fn validate_invalid_ast_mutate_missing_datacount(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let with_memory = validate_invalid_ast_ensure_memory(mod)
  let (with_data, data_idx) = validate_invalid_ast_append_passive_data(
    with_memory,
  )
  let body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(0)),
    Instruction::memory_init(data_idx, MemIdx::new(0U)),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_data,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: MissingDataCount,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: validate_invalid_ast_without_data_cnt_sec(with_func),
  }
}

///|
fn validate_invalid_ast_mutate_missing_datacount_data_drop(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let (with_data, data_idx) = validate_invalid_ast_append_passive_data(mod)
  let body = Expr::new([Instruction::data_drop(data_idx)])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_data,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: MissingDataCountDataDrop,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: validate_invalid_ast_without_data_cnt_sec(with_func),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_local_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let body = Expr::new([
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::drop(),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    mod,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyLocalIndex,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_global_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let bad_global_idx = GlobalIdx::new(
    validate_invalid_ast_total_global_count(mod).reinterpret_as_uint(),
  )
  let body = Expr::new([
    Instruction::global_get(bad_global_idx),
    Instruction::drop(),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    mod,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyGlobalIndex,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_table_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let bad_table_idx = TableIdx::new(
    validate_invalid_ast_total_table_count(mod).reinterpret_as_uint(),
  )
  let body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::table_get(bad_table_idx),
    Instruction::drop(),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    mod,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyTableIndex,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_call_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let bad_func_idx = FuncIdx::new(
    (validate_invalid_ast_total_func_count(mod) + 1).reinterpret_as_uint(),
  )
  let body = Expr::new([Instruction::call(bad_func_idx), Instruction::drop()])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    mod,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyCallIndex,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_br_label_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let body = Expr::new([
    Instruction::block(
      BlockType::void_(),
      Expr::new([Instruction::br(LabelIdx::new(2U))]),
    ),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    mod,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyBrLabelIndex,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_br_payload_mismatch(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let body = Expr::new([
    Instruction::block(
      BlockType::val_type(ValType::i32()),
      Expr::new([
        Instruction::i64_const(I64(0)),
        Instruction::br(LabelIdx::new(0U)),
      ]),
    ),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    mod,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyBrPayloadMismatch,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_call_payload_mismatch(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let (with_callee, callee_idx, _) = validate_invalid_ast_append_defined_func(
    mod,
    [ValType::i32()],
    [],
    Locals::empty(),
    Expr::new([]),
  )
  let caller_body = Expr::new([
    Instruction::i64_const(I64(0)),
    Instruction::call(callee_idx),
  ])
  let (with_caller, _, _) = validate_invalid_ast_append_defined_func(
    with_callee,
    [],
    [],
    Locals::empty(),
    caller_body,
  )
  {
    strategy: InvalidFunctionBodyCallPayloadMismatch,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_caller,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_br_if_payload_mismatch(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let body = Expr::new([
    Instruction::block(
      BlockType::val_type(ValType::i32()),
      Expr::new([
        Instruction::i64_const(I64(0)),
        Instruction::i32_const(I32(1)),
        Instruction::br_if(LabelIdx::new(0U)),
      ]),
    ),
    Instruction::drop(),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    mod,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyBrIfPayloadMismatch,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_br_table_payload_mismatch(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let body = Expr::new([
    Instruction::block(
      BlockType::val_type(ValType::i32()),
      Expr::new([
        Instruction::i64_const(I64(0)),
        Instruction::i32_const(I32(0)),
        Instruction::br_table([], LabelIdx::new(0U)),
      ]),
    ),
    Instruction::drop(),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    mod,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyBrTablePayloadMismatch,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_throw_payload_mismatch(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let (with_tag, tag_idx, _) = validate_invalid_ast_append_tag(mod, [
    ValType::i32(),
  ])
  let body = Expr::new([
    Instruction::i64_const(I64(0)),
    Instruction::throw_(tag_idx),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_tag,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyThrowPayloadMismatch,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_try_table_catch_payload_mismatch(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let (with_tag, tag_idx, _) = validate_invalid_ast_append_tag(mod, [
    ValType::i64(),
  ])
  let body = Expr::new([
    Instruction::block(
      BlockType::val_type(ValType::i32()),
      Expr::new([
        Instruction::try_table(
          BlockType::void_(),
          [Catch::new(tag_idx, LabelIdx::new(0U))],
          Expr::new([
            Instruction::i64_const(I64(0)),
            Instruction::throw_(tag_idx),
          ]),
        ),
        Instruction::unreachable_(),
      ]),
    ),
    Instruction::drop(),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_tag,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyTryTableCatchPayloadMismatch,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_memory_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let bad_mem_idx = MemIdx::new(
    validate_invalid_ast_total_mem_count(mod).reinterpret_as_uint(),
  )
  let body = Expr::new([
    Instruction::memory_size(bad_mem_idx),
    Instruction::drop(),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    mod,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyMemoryIndex,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_memory_address_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let with_memory = validate_invalid_ast_ensure_memory(Module::new())
  let body = Expr::new([
    Instruction::i64_const(I64(0)),
    Instruction::i32_load(MemArg::new(2U, None, 0UL)),
    Instruction::drop(),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_memory,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyMemoryAddressType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_memory64_address_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let with_memory64 = Module::new().with_mem_sec(
    MemSec::new([MemType::new(Limits::i64(1UL, Some(1UL)))]),
  )
  let body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::i32_load(MemArg::new(2U, None, 0UL)),
    Instruction::drop(),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_memory64,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyMemory64AddressType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_memory_store_value_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let with_memory = validate_invalid_ast_ensure_memory(Module::new())
  let body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::i64_const(I64(7)),
    Instruction::i32_store(MemArg::new(2U, None, 0UL)),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_memory,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyMemoryStoreValueType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_memory_grow_delta_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let with_memory = Module::new().with_mem_sec(
    MemSec::new([MemType::new(Limits::i32(1U, Some(1U)))]),
  )
  let body = Expr::new([
    Instruction::i64_const(I64(1)),
    Instruction::memory_grow(MemIdx::new(0U)),
    Instruction::drop(),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_memory,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyMemoryGrowDeltaType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_memory_fill_value_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let with_memory = Module::new().with_mem_sec(
    MemSec::new([MemType::new(Limits::i32(1U, Some(1U)))]),
  )
  let body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::i64_const(I64(7)),
    Instruction::i32_const(I32(1)),
    Instruction::memory_fill(MemIdx::new(0U)),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_memory,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyMemoryFillValueType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_memory_copy_length_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let with_memory = Module::new().with_mem_sec(
    MemSec::new([MemType::new(Limits::i32(1U, Some(1U)))]),
  )
  let body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(0)),
    Instruction::i64_const(I64(1)),
    Instruction::memory_copy(MemIdx::new(0U), MemIdx::new(0U)),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_memory,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyMemoryCopyLengthType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_memory_copy_source_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let with_memory = Module::new().with_mem_sec(
    MemSec::new([MemType::new(Limits::i32(1U, Some(1U)))]),
  )
  let body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::i64_const(I64(0)),
    Instruction::i32_const(I32(1)),
    Instruction::memory_copy(MemIdx::new(0U), MemIdx::new(0U)),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_memory,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyMemoryCopySourceType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_memory_copy_dest_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let with_memory = Module::new().with_mem_sec(
    MemSec::new([MemType::new(Limits::i32(1U, Some(1U)))]),
  )
  let body = Expr::new([
    Instruction::i64_const(I64(0)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(1)),
    Instruction::memory_copy(MemIdx::new(0U), MemIdx::new(0U)),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_memory,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyMemoryCopyDestType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_memory_init_length_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let with_memory = Module::new().with_mem_sec(
    MemSec::new([MemType::new(Limits::i32(1U, Some(1U)))]),
  )
  let (with_data, data_idx) = validate_invalid_ast_append_passive_data(
    with_memory,
  )
  let with_count = with_data.with_data_cnt_sec(DataCntSec::new(U32(1U)))
  let body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(0)),
    Instruction::i64_const(I64(1)),
    Instruction::memory_init(data_idx, MemIdx::new(0U)),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_count,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyMemoryInitLengthType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_memory_init_source_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let with_memory = Module::new().with_mem_sec(
    MemSec::new([MemType::new(Limits::i32(1U, Some(1U)))]),
  )
  let (with_data, data_idx) = validate_invalid_ast_append_passive_data(
    with_memory,
  )
  let with_count = with_data.with_data_cnt_sec(DataCntSec::new(U32(1U)))
  let body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::i64_const(I64(0)),
    Instruction::i32_const(I32(1)),
    Instruction::memory_init(data_idx, MemIdx::new(0U)),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_count,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyMemoryInitSourceType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_memory_init_dest_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let with_memory = Module::new().with_mem_sec(
    MemSec::new([MemType::new(Limits::i32(1U, Some(1U)))]),
  )
  let (with_data, data_idx) = validate_invalid_ast_append_passive_data(
    with_memory,
  )
  let with_count = with_data.with_data_cnt_sec(DataCntSec::new(U32(1U)))
  let body = Expr::new([
    Instruction::i64_const(I64(0)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(1)),
    Instruction::memory_init(data_idx, MemIdx::new(0U)),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_count,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyMemoryInitDestType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_local_set_value_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let body = Expr::new([
    Instruction::i64_const(I64(7)),
    Instruction::local_set(LocalIdx::new(0U)),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    Module::new(),
    [ValType::i32()],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyLocalSetValueType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_local_tee_value_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let body = Expr::new([
    Instruction::i64_const(I64(7)),
    Instruction::local_tee(LocalIdx::new(0U)),
    Instruction::drop(),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    Module::new(),
    [ValType::i32()],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyLocalTeeValueType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_return_value_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let body = Expr::new([
    Instruction::i64_const(I64(7)),
    Instruction::return_(),
    Instruction::unreachable_(),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    Module::new(),
    [],
    [ValType::i32()],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyReturnValueType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_table_get_index_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let with_table = Module::new().with_table_sec(
    TableSec::new([
      Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
    ]),
  )
  let body = Expr::new([
    Instruction::i64_const(I64(0)),
    Instruction::table_get(TableIdx::new(0U)),
    Instruction::drop(),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_table,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyTableGetIndexType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_table_grow_value_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let with_table = Module::new().with_table_sec(
    TableSec::new([
      Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
    ]),
  )
  let body = Expr::new([
    Instruction::ref_null(HeapType::abs(AbsHeapType::extern_())),
    Instruction::i32_const(I32(1)),
    Instruction::table_grow(TableIdx::new(0U)),
    Instruction::drop(),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_table,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyTableGrowValueType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_table_grow_delta_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let with_table = Module::new().with_table_sec(
    TableSec::new([
      Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
    ]),
  )
  let body = Expr::new([
    Instruction::ref_null(HeapType::abs(AbsHeapType::func())),
    Instruction::i64_const(I64(1)),
    Instruction::table_grow(TableIdx::new(0U)),
    Instruction::drop(),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_table,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyTableGrowDeltaType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_func_table_module() -> Module {
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  Module::new().with_table_sec(
    TableSec::new([
      Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
    ]),
  )
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_table_fill_value_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::ref_null(HeapType::abs(AbsHeapType::extern_())),
    Instruction::i32_const(I32(1)),
    Instruction::table_fill(TableIdx::new(0U)),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    validate_invalid_ast_func_table_module(),
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyTableFillValueType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_table_fill_dest_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let body = Expr::new([
    Instruction::i64_const(I64(0)),
    Instruction::ref_null(HeapType::abs(AbsHeapType::func())),
    Instruction::i32_const(I32(1)),
    Instruction::table_fill(TableIdx::new(0U)),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    validate_invalid_ast_func_table_module(),
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyTableFillDestType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_table_fill_length_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::ref_null(HeapType::abs(AbsHeapType::func())),
    Instruction::i64_const(I64(1)),
    Instruction::table_fill(TableIdx::new(0U)),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    validate_invalid_ast_func_table_module(),
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyTableFillLengthType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_table_copy_length_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let with_table = Module::new().with_table_sec(
    TableSec::new([
      Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
    ]),
  )
  let body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(0)),
    Instruction::i64_const(I64(1)),
    Instruction::table_copy(TableIdx::new(0U), TableIdx::new(0U)),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_table,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyTableCopyLengthType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_table_copy_source_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let with_table = Module::new().with_table_sec(
    TableSec::new([
      Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
    ]),
  )
  let body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::i64_const(I64(0)),
    Instruction::i32_const(I32(1)),
    Instruction::table_copy(TableIdx::new(0U), TableIdx::new(0U)),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_table,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyTableCopySourceType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_table_copy_dest_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let with_table = Module::new().with_table_sec(
    TableSec::new([
      Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
    ]),
  )
  let body = Expr::new([
    Instruction::i64_const(I64(0)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(1)),
    Instruction::table_copy(TableIdx::new(0U), TableIdx::new(0U)),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_table,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyTableCopyDestType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_table_init_base_module() -> Module {
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  Module::new()
  .with_table_sec(
    TableSec::new([
      Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
    ]),
  )
  .with_elem_sec(
    ElemSec::new([Elem::new(ElemMode::passive(), ElemKind::funcs([]))]),
  )
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_table_init_length_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(0)),
    Instruction::i64_const(I64(1)),
    Instruction::table_init(ElemIdx::new(0U), TableIdx::new(0U)),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    validate_invalid_ast_table_init_base_module(),
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyTableInitLengthType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_table_init_source_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::i64_const(I64(0)),
    Instruction::i32_const(I32(1)),
    Instruction::table_init(ElemIdx::new(0U), TableIdx::new(0U)),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    validate_invalid_ast_table_init_base_module(),
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyTableInitSourceType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_table_init_dest_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let body = Expr::new([
    Instruction::i64_const(I64(0)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(1)),
    Instruction::table_init(ElemIdx::new(0U), TableIdx::new(0U)),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    validate_invalid_ast_table_init_base_module(),
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyTableInitDestType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_data_drop_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let base = Module::new()
    .with_data_sec(DataSec::new([]))
    .with_data_cnt_sec(DataCntSec::new(U32(0U)))
  let body = Expr::new([Instruction::data_drop(DataIdx::new(0U))])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    base,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyDataDropIndex,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_elem_drop_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let body = Expr::new([Instruction::elem_drop(ElemIdx::new(0U))])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    Module::new(),
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyElemDropIndex,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_table_size_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let bad_table_idx = TableIdx::new(
    validate_invalid_ast_total_table_count(mod).reinterpret_as_uint(),
  )
  let body = Expr::new([
    Instruction::table_size(bad_table_idx),
    Instruction::drop(),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    mod,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyTableSizeIndex,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_table_set_index_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let with_table = Module::new().with_table_sec(
    TableSec::new([
      Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
    ]),
  )
  let body = Expr::new([
    Instruction::i64_const(I64(0)),
    Instruction::ref_null(HeapType::abs(AbsHeapType::func())),
    Instruction::table_set(TableIdx::new(0U)),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_table,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyTableSetIndexType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_make_indirect_call_base() -> Module {
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  Module::new()
  .with_type_sec(
    TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
  )
  .with_table_sec(
    TableSec::new([
      Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
    ]),
  )
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_call_indirect_index_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let body = Expr::new([
    Instruction::i64_const(I64(0)),
    Instruction::call_indirect(TypeIdx::new(0U), TableIdx::new(0U)),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    validate_invalid_ast_make_indirect_call_base(),
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyCallIndirectIndexType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_return_call_indirect_index_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let body = Expr::new([
    Instruction::i64_const(I64(0)),
    Instruction::return_call_indirect(TypeIdx::new(0U), TableIdx::new(0U)),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    validate_invalid_ast_make_indirect_call_base(),
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyReturnCallIndirectIndexType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_return_call_ref_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let with_type = Module::new().with_type_sec(
    TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
  )
  let body = Expr::new([
    Instruction::ref_null(HeapType::abs(AbsHeapType::extern_())),
    Instruction::return_call_ref(TypeIdx::new(0U)),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_type,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyReturnCallRefType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_call_ref_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let with_type = Module::new().with_type_sec(
    TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
  )
  let body = Expr::new([
    Instruction::ref_null(HeapType::abs(AbsHeapType::extern_())),
    Instruction::call_ref(TypeIdx::new(0U)),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_type,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyCallRefType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_ref_cast_input_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::ref_cast(true, HeapType::abs(AbsHeapType::eq())),
    Instruction::drop(),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    Module::new(),
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyRefCastInputType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_ref_test_input_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::ref_test(true, HeapType::abs(AbsHeapType::eq())),
    Instruction::drop(),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    Module::new(),
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyRefTestInputType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_ref_test_desc_input_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::ref_test_desc(true, HeapType::abs(AbsHeapType::eq())),
    Instruction::drop(),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    Module::new(),
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyRefTestDescInputType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_ref_cast_desc_eq_input_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::ref_cast_desc_eq(true, HeapType::abs(AbsHeapType::eq())),
    Instruction::drop(),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    Module::new(),
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyRefCastDescEqInputType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_table_set_value_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let with_table = Module::new().with_table_sec(
    TableSec::new([
      Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
    ]),
  )
  let body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::ref_null(HeapType::abs(AbsHeapType::extern_())),
    Instruction::table_set(TableIdx::new(0U)),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_table,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyTableSetValueType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_function_body_global_set_value_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let globals = [
    Global::new(
      GlobalType::new(ValType::i32(), true),
      Expr::new([Instruction::i32_const(I32(0))]),
    ),
  ]
  let body = Expr::new([
    Instruction::i64_const(I64(7)),
    Instruction::global_set(GlobalIdx::new(0U)),
  ])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    Module::new().with_global_sec(GlobalSec::new(globals)),
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: InvalidFunctionBodyGlobalSetValueType,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_undeclared_ref_func(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let target_idx = FuncIdx::new(
    validate_invalid_ast_total_func_count(mod).reinterpret_as_uint(),
  )
  let body = Expr::new([Instruction::ref_func(target_idx), Instruction::drop()])
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    mod,
    [],
    [],
    Locals::empty(),
    body,
  )
  {
    strategy: UndeclaredRefFunc,
    applicable: true,
    expected_family: FunctionBodyFamily,
    mutated_module: with_func,
  }
}

///|
fn validate_invalid_ast_mutate_invalid_name_section_func_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let (base, _) = validate_invalid_ast_ensure_any_func(mod)
  let bad_idx = validate_invalid_ast_total_func_count(base).reinterpret_as_uint()
  let func_names = NameMap::new([NameAssoc::new(bad_idx, Name::new("bad"))])
  {
    strategy: InvalidNameSectionFuncIndex,
    applicable: true,
    expected_family: NameSectionFamily,
    mutated_module: validate_invalid_ast_with_func_names(base, func_names),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_local_name_section_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let imported = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([ValType::i32()], []))),
      ]),
    )
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("f"),
          ExternType::func(TypeIdx::new(0U)),
        ),
      ]),
    )
  let local_names = IndirectNameMap::new([
    IndirectNameAssoc::new(
      0U,
      NameMap::new([NameAssoc::new(1U, Name::new("too-far"))]),
    ),
  ])
  {
    strategy: InvalidLocalNameSectionIndex,
    applicable: true,
    expected_family: NameSectionFamily,
    mutated_module: validate_invalid_ast_with_local_names(imported, local_names),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_label_name_section_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let imported = Module::new()
    .with_type_sec(
      TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
    )
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("f"),
          ExternType::func(TypeIdx::new(0U)),
        ),
      ]),
    )
  let label_names = IndirectNameMap::new([
    IndirectNameAssoc::new(
      0U,
      NameMap::new([NameAssoc::new(0U, Name::new("entry"))]),
    ),
  ])
  {
    strategy: InvalidLabelNameSectionIndex,
    applicable: true,
    expected_family: NameSectionFamily,
    mutated_module: validate_invalid_ast_with_label_names(imported, label_names),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_memory_name_section_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let bad_idx = validate_invalid_ast_total_mem_count(mod).reinterpret_as_uint()
  let memory_names = NameMap::new([NameAssoc::new(bad_idx, Name::new("mem"))])
  {
    strategy: InvalidMemoryNameSectionIndex,
    applicable: true,
    expected_family: NameSectionFamily,
    mutated_module: validate_invalid_ast_with_memory_names(mod, memory_names),
  }
}

///|
fn validate_invalid_ast_mutate_codesec_without_funcsec(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  {
    strategy: CodeSecWithoutFuncSec,
    applicable: true,
    expected_family: CodeSectionFamily,
    mutated_module: validate_invalid_ast_without_func_sec(
      Module::new().with_code_sec(
        CodeSec::new([Func::new(Locals::empty(), Expr::new([]))]),
      ),
    ),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_table_name_section_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let bad_idx = validate_invalid_ast_total_table_count(mod).reinterpret_as_uint()
  let table_names = NameMap::new([NameAssoc::new(bad_idx, Name::new("tab"))])
  {
    strategy: InvalidTableNameSectionIndex,
    applicable: true,
    expected_family: NameSectionFamily,
    mutated_module: validate_invalid_ast_with_table_names(mod, table_names),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_global_name_section_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let bad_idx = validate_invalid_ast_total_global_count(mod).reinterpret_as_uint()
  let global_names = NameMap::new([NameAssoc::new(bad_idx, Name::new("glob"))])
  {
    strategy: InvalidGlobalNameSectionIndex,
    applicable: true,
    expected_family: NameSectionFamily,
    mutated_module: validate_invalid_ast_with_global_names(mod, global_names),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_type_name_section_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let bad_idx = validate_invalid_ast_flat_type_count(mod).reinterpret_as_uint()
  let type_names = NameMap::new([NameAssoc::new(bad_idx, Name::new("ty"))])
  {
    strategy: InvalidTypeNameSectionIndex,
    applicable: true,
    expected_family: NameSectionFamily,
    mutated_module: validate_invalid_ast_with_type_names(mod, type_names),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_field_name_section_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  ignore(mod)
  let struct_type = RecType::new(
    SubType::comp_type(
      CompType::struct_([
        FieldType::new(StorageType::val_type(ValType::i32()), Const),
      ]),
    ),
  )
  let base = Module::new().with_type_sec(TypeSec::new([struct_type]))
  let field_names = IndirectNameMap::new([
    IndirectNameAssoc::new(
      0U,
      NameMap::new([NameAssoc::new(1U, Name::new("field"))]),
    ),
  ])
  {
    strategy: InvalidFieldNameSectionIndex,
    applicable: true,
    expected_family: NameSectionFamily,
    mutated_module: validate_invalid_ast_with_field_names(base, field_names),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_elem_name_section_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let bad_idx = validate_invalid_ast_elem_entries(mod)
    .length()
    .reinterpret_as_uint()
  let elem_names = NameMap::new([NameAssoc::new(bad_idx, Name::new("elem"))])
  {
    strategy: InvalidElemNameSectionIndex,
    applicable: true,
    expected_family: NameSectionFamily,
    mutated_module: validate_invalid_ast_with_elem_names(mod, elem_names),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_data_name_section_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let bad_idx = validate_invalid_ast_data_entries(mod)
    .length()
    .reinterpret_as_uint()
  let data_names = NameMap::new([NameAssoc::new(bad_idx, Name::new("data"))])
  {
    strategy: InvalidDataNameSectionIndex,
    applicable: true,
    expected_family: NameSectionFamily,
    mutated_module: validate_invalid_ast_with_data_names(mod, data_names),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_tag_name_section_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let bad_idx = validate_invalid_ast_total_tag_count(mod).reinterpret_as_uint()
  let tag_names = NameMap::new([NameAssoc::new(bad_idx, Name::new("tag"))])
  {
    strategy: InvalidTagNameSectionIndex,
    applicable: true,
    expected_family: NameSectionFamily,
    mutated_module: validate_invalid_ast_with_tag_names(mod, tag_names),
  }
}

///|
fn validate_invalid_ast_mutate_datacount_mismatch_too_small(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let (with_first, _) = validate_invalid_ast_append_passive_data(mod)
  let (with_second, _) = validate_invalid_ast_append_passive_data(with_first)
  let actual = validate_invalid_ast_data_entries(with_second)
    .length()
    .reinterpret_as_uint()
  {
    strategy: DataCountMismatchTooSmall,
    applicable: true,
    expected_family: DataCountSectionFamily,
    mutated_module: with_second.with_data_cnt_sec(
      DataCntSec::new(U32(actual - 1U)),
    ),
  }
}

///|
fn validate_invalid_ast_mutate_datacount_mismatch_too_large(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let (with_first, _) = validate_invalid_ast_append_passive_data(mod)
  let actual = validate_invalid_ast_data_entries(with_first)
    .length()
    .reinterpret_as_uint()
  {
    strategy: DataCountMismatchTooLarge,
    applicable: true,
    expected_family: DataCountSectionFamily,
    mutated_module: with_first.with_data_cnt_sec(
      DataCntSec::new(U32(actual + 1U)),
    ),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_func_type_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let func_types = validate_invalid_ast_func_type_entries(mod)
  let code = validate_invalid_ast_code_entries(mod)
  let bad_type_idx = TypeIdx::new(
    validate_invalid_ast_flat_type_count(mod).reinterpret_as_uint(),
  )
  func_types.push(bad_type_idx)
  code.push(Func::new(Locals::empty(), Expr::new([])))
  {
    strategy: InvalidFuncTypeIndex,
    applicable: true,
    expected_family: FunctionSectionFamily,
    mutated_module: mod
    .with_func_sec(FuncSec::new(func_types))
    .with_code_sec(CodeSec::new(code)),
  }
}

///|
fn validate_invalid_ast_mutate_funcsec_without_codesec(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    mod,
    [],
    [],
    Locals::empty(),
    Expr::new([]),
  )
  {
    strategy: FuncSecWithoutCodeSec,
    applicable: true,
    expected_family: CodeSectionFamily,
    mutated_module: validate_invalid_ast_without_code_sec(with_func),
  }
}

///|
fn validate_invalid_ast_mutate_mutable_global_get_in_const_init(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let imports = validate_invalid_ast_import_entries(mod)
  let globals = validate_invalid_ast_global_entries(mod)
  let imported_global_idx = GlobalIdx::new(
    validate_invalid_ast_imported_global_count(mod).reinterpret_as_uint(),
  )
  imports.push(
    Import::new(
      Name::new("env"),
      Name::new("g"),
      ExternType::global(GlobalType::new(ValType::i32(), true)),
    ),
  )
  globals.push(
    Global::new(
      GlobalType::new(ValType::i32(), false),
      Expr::new([Instruction::global_get(imported_global_idx)]),
    ),
  )
  {
    strategy: MutableGlobalGetInConstInit,
    applicable: true,
    expected_family: GlobalSectionFamily,
    mutated_module: mod
    .with_import_sec(ImportSec::new(imports))
    .with_global_sec(GlobalSec::new(globals)),
  }
}

///|
fn validate_invalid_ast_mutate_non_constant_data_offset(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let with_memory = validate_invalid_ast_ensure_memory(mod)
  let datas = validate_invalid_ast_data_entries(with_memory)
  datas.push(
    Data::new(
      DataMode::active(
        MemIdx::new(0U),
        Expr::new([Instruction::i32_const(I32(1)), Instruction::drop()]),
      ),
      b"x",
    ),
  )
  {
    strategy: NonConstantDataOffset,
    applicable: true,
    expected_family: DataSectionFamily,
    mutated_module: with_memory.with_data_sec(DataSec::new(datas)),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_imported_func_type_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let imports = validate_invalid_ast_import_entries(mod)
  let bad_type_idx = TypeIdx::new(
    validate_invalid_ast_flat_type_count(mod).reinterpret_as_uint(),
  )
  imports.push(
    Import::new(
      Name::new("env"),
      Name::new("f"),
      ExternType::func(bad_type_idx),
    ),
  )
  {
    strategy: InvalidImportedFuncTypeIndex,
    applicable: true,
    expected_family: ImportSectionFamily,
    mutated_module: mod.with_import_sec(ImportSec::new(imports)),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_imported_tag_type_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let imports = validate_invalid_ast_import_entries(mod)
  let bad_type_idx = TypeIdx::new(
    validate_invalid_ast_flat_type_count(mod).reinterpret_as_uint(),
  )
  imports.push(
    Import::new(
      Name::new("env"),
      Name::new("tag"),
      ExternType::tag(TagType::new(bad_type_idx)),
    ),
  )
  {
    strategy: InvalidImportedTagTypeIndex,
    applicable: true,
    expected_family: ImportSectionFamily,
    mutated_module: mod.with_import_sec(ImportSec::new(imports)),
  }
}

///|
fn validate_invalid_ast_mutate_mutable_global_get_in_table_init(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let imports = validate_invalid_ast_import_entries(mod)
  let tables = validate_invalid_ast_table_entries(mod)
  let imported_global_idx = GlobalIdx::new(
    validate_invalid_ast_imported_global_count(mod).reinterpret_as_uint(),
  )
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  imports.push(
    Import::new(
      Name::new("env"),
      Name::new("g"),
      ExternType::global(GlobalType::new(ValType::ref_type(func_ref), true)),
    ),
  )
  tables.push(
    Table::new(
      TableType::new(func_ref, Limits::i32(1, None)),
      Some(Expr::new([Instruction::global_get(imported_global_idx)])),
    ),
  )
  {
    strategy: MutableGlobalGetInTableInit,
    applicable: true,
    expected_family: TableSectionFamily,
    mutated_module: mod
    .with_import_sec(ImportSec::new(imports))
    .with_table_sec(TableSec::new(tables)),
  }
}

///|
fn validate_invalid_ast_mutate_non_constant_elem_offset(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let tables = validate_invalid_ast_table_entries(mod)
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  if tables.length() == 0 {
    tables.push(
      Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
    )
  }
  let elem = Elem::new(
    ElemMode::active(
      TableIdx::new(0U),
      Expr::new([Instruction::i32_const(I32(1)), Instruction::drop()]),
    ),
    ElemKind::funcs([]),
  )
  {
    strategy: NonConstantElemOffset,
    applicable: true,
    expected_family: ElementSectionFamily,
    mutated_module: mod
    .with_table_sec(TableSec::new(tables))
    .with_elem_sec(ElemSec::new([elem])),
  }
}

///|
fn validate_invalid_ast_mutate_shared_memory_without_max(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let mems = validate_invalid_ast_mem_entries(mod)
  mems.push(MemType::new(Limits::i32(1, None), shared=true))
  {
    strategy: SharedMemoryWithoutMax,
    applicable: true,
    expected_family: MemorySectionFamily,
    mutated_module: mod.with_mem_sec(MemSec::new(mems)),
  }
}

///|
fn validate_invalid_ast_mutate_shared_memory64_without_max(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let mems = validate_invalid_ast_mem_entries(mod)
  mems.push(MemType::new(Limits::i64(1UL, None), shared=true))
  {
    strategy: SharedMemory64WithoutMax,
    applicable: true,
    expected_family: MemorySectionFamily,
    mutated_module: mod.with_mem_sec(MemSec::new(mems)),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_tag_type_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let tags : Array[TagType] = []
  let bad_type_idx = TypeIdx::new(
    validate_invalid_ast_flat_type_count(mod).reinterpret_as_uint(),
  )
  tags.push(TagType::new(bad_type_idx))
  {
    strategy: InvalidTagTypeIndex,
    applicable: true,
    expected_family: TagSectionFamily,
    mutated_module: mod.with_tag_sec(TagSec::new(tags)),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_subtype_super_index(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let types = validate_invalid_ast_type_entries(mod)
  types.push(
    RecType::new(
      SubType::new(false, [TypeIdx::new(9999U)], CompType::func([], [])),
    ),
  )
  {
    strategy: InvalidSubtypeSuperIndex,
    applicable: true,
    expected_family: TypeSectionFamily,
    mutated_module: mod.with_type_sec(TypeSec::new(types)),
  }
}

///|
fn validate_invalid_ast_mutate_invalid_subtype_super_shape(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let types = validate_invalid_ast_type_entries(mod)
  let super_idx = TypeIdx::new(
    validate_invalid_ast_flat_type_count(mod).reinterpret_as_uint(),
  )
  types.push(RecType::new(SubType::comp_type(CompType::func([], []))))
  types.push(
    RecType::new(
      SubType::new(false, [super_idx], CompType::func([ValType::i32()], [])),
    ),
  )
  {
    strategy: InvalidSubtypeSuperShape,
    applicable: true,
    expected_family: TypeSectionFamily,
    mutated_module: mod.with_type_sec(TypeSec::new(types)),
  }
}

///|
fn validate_invalid_ast_mutate_descriptor_on_func_type(
  mod : Module,
) -> ValidateInvalidAstMutation {
  let types = validate_invalid_ast_type_entries(mod)
  types.push(
    RecType::new(
      SubType::comp_type(
        CompType::func([], []),
        metadata=TypeMetadata::new(descriptor=Some(TypeIdx::new(0U))),
      ),
    ),
  )
  {
    strategy: DescriptorOnFuncType,
    applicable: true,
    expected_family: TypeSectionFamily,
    mutated_module: mod.with_type_sec(TypeSec::new(types)),
  }
}

///|
fn validate_invalid_ast_mutate_datacount_without_data_sec(
  mod : Module,
) -> ValidateInvalidAstMutation {
  {
    strategy: DataCountWithoutDataSec,
    applicable: true,
    expected_family: DataCountSectionFamily,
    mutated_module: validate_invalid_ast_without_data_sec(mod).with_data_cnt_sec(
      DataCntSec::new(U32(1U)),
    ),
  }
}

///|
pub fn apply_validate_invalid_ast_strategy(
  strategy : ValidateInvalidAstStrategyId,
  mod : Module,
) -> Result[ValidateInvalidAstMutation, String] {
  let base = match validate_module(mod) {
    Ok(_) => mod
    Err(err) =>
      return Err(
        "validate-invalid-ast requires a valid base module before mutation: \{validation_error_message(err)}",
      )
  }
  Ok(
    match strategy {
      DuplicateExportName =>
        validate_invalid_ast_mutate_duplicate_export_name(base)
      InvalidExportFuncIndex =>
        validate_invalid_ast_mutate_invalid_export_func_index(base)
      InvalidImportedStartFuncParam =>
        validate_invalid_ast_mutate_invalid_imported_start_func_param(base)
      InvalidImportedStartFuncResult =>
        validate_invalid_ast_mutate_invalid_imported_start_func_result(base)
      InvalidImportedStartFuncParamResult =>
        validate_invalid_ast_mutate_invalid_imported_start_func_param_result(
          base,
        )
      InvalidImportedStartFuncMultiParam =>
        validate_invalid_ast_mutate_invalid_imported_start_func_multi_param(
          base,
        )
      InvalidImportedStartFuncF32Param =>
        validate_invalid_ast_mutate_invalid_imported_start_func_f32_param(base)
      InvalidImportedStartFuncExternrefParam =>
        validate_invalid_ast_mutate_invalid_imported_start_func_externref_param(
          base,
        )
      InvalidImportedStartFuncFuncrefParam =>
        validate_invalid_ast_mutate_invalid_imported_start_func_funcref_param(
          base,
        )
      InvalidExportTableIndex =>
        validate_invalid_ast_mutate_invalid_export_table_index(base)
      InvalidExportGlobalIndex =>
        validate_invalid_ast_mutate_invalid_export_global_index(base)
      InvalidExportMemoryIndex =>
        validate_invalid_ast_mutate_invalid_export_memory_index(base)
      InvalidExportTagIndex =>
        validate_invalid_ast_mutate_invalid_export_tag_index(base)
      InvalidTagNameSectionIndex =>
        validate_invalid_ast_mutate_invalid_tag_name_section_index(base)
      DataCountMismatchTooSmall =>
        validate_invalid_ast_mutate_datacount_mismatch_too_small(base)
      DataCountMismatchTooLarge =>
        validate_invalid_ast_mutate_datacount_mismatch_too_large(base)
      InvalidStartSignature =>
        validate_invalid_ast_mutate_invalid_start_signature(base)
      StartFuncOutOfRange =>
        validate_invalid_ast_mutate_start_func_out_of_range(base)
      MissingDataCount => validate_invalid_ast_mutate_missing_datacount(base)
      MissingDataCountDataDrop =>
        validate_invalid_ast_mutate_missing_datacount_data_drop(base)
      UndeclaredRefFunc => validate_invalid_ast_mutate_undeclared_ref_func(base)
      InvalidFunctionBodyLocalIndex =>
        validate_invalid_ast_mutate_invalid_function_body_local_index(base)
      InvalidFunctionBodyGlobalIndex =>
        validate_invalid_ast_mutate_invalid_function_body_global_index(base)
      InvalidFunctionBodyTableIndex =>
        validate_invalid_ast_mutate_invalid_function_body_table_index(base)
      InvalidFunctionBodyMemoryIndex =>
        validate_invalid_ast_mutate_invalid_function_body_memory_index(base)
      InvalidFunctionBodyCallIndex =>
        validate_invalid_ast_mutate_invalid_function_body_call_index(base)
      InvalidFunctionBodyBrLabelIndex =>
        validate_invalid_ast_mutate_invalid_function_body_br_label_index(base)
      InvalidFunctionBodyBrPayloadMismatch =>
        validate_invalid_ast_mutate_invalid_function_body_br_payload_mismatch(
          base,
        )
      InvalidFunctionBodyCallPayloadMismatch =>
        validate_invalid_ast_mutate_invalid_function_body_call_payload_mismatch(
          base,
        )
      InvalidFunctionBodyBrIfPayloadMismatch =>
        validate_invalid_ast_mutate_invalid_function_body_br_if_payload_mismatch(
          base,
        )
      InvalidFunctionBodyBrTablePayloadMismatch =>
        validate_invalid_ast_mutate_invalid_function_body_br_table_payload_mismatch(
          base,
        )
      InvalidFunctionBodyThrowPayloadMismatch =>
        validate_invalid_ast_mutate_invalid_function_body_throw_payload_mismatch(
          base,
        )
      InvalidFunctionBodyTryTableCatchPayloadMismatch =>
        validate_invalid_ast_mutate_invalid_function_body_try_table_catch_payload_mismatch(
          base,
        )
      InvalidFunctionBodyMemoryAddressType =>
        validate_invalid_ast_mutate_invalid_function_body_memory_address_type(
          base,
        )
      InvalidFunctionBodyMemory64AddressType =>
        validate_invalid_ast_mutate_invalid_function_body_memory64_address_type(
          base,
        )
      InvalidFunctionBodyMemoryStoreValueType =>
        validate_invalid_ast_mutate_invalid_function_body_memory_store_value_type(
          base,
        )
      InvalidFunctionBodyMemoryGrowDeltaType =>
        validate_invalid_ast_mutate_invalid_function_body_memory_grow_delta_type(
          base,
        )
      InvalidFunctionBodyMemoryFillValueType =>
        validate_invalid_ast_mutate_invalid_function_body_memory_fill_value_type(
          base,
        )
      InvalidFunctionBodyMemoryCopyLengthType =>
        validate_invalid_ast_mutate_invalid_function_body_memory_copy_length_type(
          base,
        )
      InvalidFunctionBodyMemoryCopySourceType =>
        validate_invalid_ast_mutate_invalid_function_body_memory_copy_source_type(
          base,
        )
      InvalidFunctionBodyMemoryCopyDestType =>
        validate_invalid_ast_mutate_invalid_function_body_memory_copy_dest_type(
          base,
        )
      InvalidFunctionBodyMemoryInitLengthType =>
        validate_invalid_ast_mutate_invalid_function_body_memory_init_length_type(
          base,
        )
      InvalidFunctionBodyMemoryInitSourceType =>
        validate_invalid_ast_mutate_invalid_function_body_memory_init_source_type(
          base,
        )
      InvalidFunctionBodyMemoryInitDestType =>
        validate_invalid_ast_mutate_invalid_function_body_memory_init_dest_type(
          base,
        )
      InvalidFunctionBodyLocalSetValueType =>
        validate_invalid_ast_mutate_invalid_function_body_local_set_value_type(
          base,
        )
      InvalidFunctionBodyLocalTeeValueType =>
        validate_invalid_ast_mutate_invalid_function_body_local_tee_value_type(
          base,
        )
      InvalidFunctionBodyReturnValueType =>
        validate_invalid_ast_mutate_invalid_function_body_return_value_type(
          base,
        )
      InvalidFunctionBodyTableGetIndexType =>
        validate_invalid_ast_mutate_invalid_function_body_table_get_index_type(
          base,
        )
      InvalidFunctionBodyTableGrowValueType =>
        validate_invalid_ast_mutate_invalid_function_body_table_grow_value_type(
          base,
        )
      InvalidFunctionBodyTableGrowDeltaType =>
        validate_invalid_ast_mutate_invalid_function_body_table_grow_delta_type(
          base,
        )
      InvalidFunctionBodyTableFillValueType =>
        validate_invalid_ast_mutate_invalid_function_body_table_fill_value_type(
          base,
        )
      InvalidFunctionBodyTableFillDestType =>
        validate_invalid_ast_mutate_invalid_function_body_table_fill_dest_type(
          base,
        )
      InvalidFunctionBodyTableFillLengthType =>
        validate_invalid_ast_mutate_invalid_function_body_table_fill_length_type(
          base,
        )
      InvalidFunctionBodyTableCopyLengthType =>
        validate_invalid_ast_mutate_invalid_function_body_table_copy_length_type(
          base,
        )
      InvalidFunctionBodyTableCopySourceType =>
        validate_invalid_ast_mutate_invalid_function_body_table_copy_source_type(
          base,
        )
      InvalidFunctionBodyTableCopyDestType =>
        validate_invalid_ast_mutate_invalid_function_body_table_copy_dest_type(
          base,
        )
      InvalidFunctionBodyTableInitLengthType =>
        validate_invalid_ast_mutate_invalid_function_body_table_init_length_type(
          base,
        )
      InvalidFunctionBodyTableInitSourceType =>
        validate_invalid_ast_mutate_invalid_function_body_table_init_source_type(
          base,
        )
      InvalidFunctionBodyTableInitDestType =>
        validate_invalid_ast_mutate_invalid_function_body_table_init_dest_type(
          base,
        )
      InvalidFunctionBodyDataDropIndex =>
        validate_invalid_ast_mutate_invalid_function_body_data_drop_index(base)
      InvalidFunctionBodyElemDropIndex =>
        validate_invalid_ast_mutate_invalid_function_body_elem_drop_index(base)
      InvalidFunctionBodyTableSizeIndex =>
        validate_invalid_ast_mutate_invalid_function_body_table_size_index(base)
      InvalidFunctionBodyTableSetIndexType =>
        validate_invalid_ast_mutate_invalid_function_body_table_set_index_type(
          base,
        )
      InvalidFunctionBodyCallIndirectIndexType =>
        validate_invalid_ast_mutate_invalid_function_body_call_indirect_index_type(
          base,
        )
      InvalidFunctionBodyReturnCallIndirectIndexType =>
        validate_invalid_ast_mutate_invalid_function_body_return_call_indirect_index_type(
          base,
        )
      InvalidFunctionBodyReturnCallRefType =>
        validate_invalid_ast_mutate_invalid_function_body_return_call_ref_type(
          base,
        )
      InvalidFunctionBodyCallRefType =>
        validate_invalid_ast_mutate_invalid_function_body_call_ref_type(base)
      InvalidFunctionBodyRefCastInputType =>
        validate_invalid_ast_mutate_invalid_function_body_ref_cast_input_type(
          base,
        )
      InvalidFunctionBodyRefTestInputType =>
        validate_invalid_ast_mutate_invalid_function_body_ref_test_input_type(
          base,
        )
      InvalidFunctionBodyRefTestDescInputType =>
        validate_invalid_ast_mutate_invalid_function_body_ref_test_desc_input_type(
          base,
        )
      InvalidFunctionBodyRefCastDescEqInputType =>
        validate_invalid_ast_mutate_invalid_function_body_ref_cast_desc_eq_input_type(
          base,
        )
      InvalidFunctionBodyTableSetValueType =>
        validate_invalid_ast_mutate_invalid_function_body_table_set_value_type(
          base,
        )
      InvalidFunctionBodyGlobalSetValueType =>
        validate_invalid_ast_mutate_invalid_function_body_global_set_value_type(
          base,
        )
      InvalidNameSectionFuncIndex =>
        validate_invalid_ast_mutate_invalid_name_section_func_index(base)
      InvalidLocalNameSectionIndex =>
        validate_invalid_ast_mutate_invalid_local_name_section_index(base)
      InvalidLabelNameSectionIndex =>
        validate_invalid_ast_mutate_invalid_label_name_section_index(base)
      InvalidMemoryNameSectionIndex =>
        validate_invalid_ast_mutate_invalid_memory_name_section_index(base)
      CodeSecWithoutFuncSec =>
        validate_invalid_ast_mutate_codesec_without_funcsec(base)
      InvalidTableNameSectionIndex =>
        validate_invalid_ast_mutate_invalid_table_name_section_index(base)
      InvalidGlobalNameSectionIndex =>
        validate_invalid_ast_mutate_invalid_global_name_section_index(base)
      InvalidTypeNameSectionIndex =>
        validate_invalid_ast_mutate_invalid_type_name_section_index(base)
      InvalidFieldNameSectionIndex =>
        validate_invalid_ast_mutate_invalid_field_name_section_index(base)
      InvalidElemNameSectionIndex =>
        validate_invalid_ast_mutate_invalid_elem_name_section_index(base)
      InvalidDataNameSectionIndex =>
        validate_invalid_ast_mutate_invalid_data_name_section_index(base)
      InvalidFuncTypeIndex =>
        validate_invalid_ast_mutate_invalid_func_type_index(base)
      FuncSecWithoutCodeSec =>
        validate_invalid_ast_mutate_funcsec_without_codesec(base)
      MutableGlobalGetInConstInit =>
        validate_invalid_ast_mutate_mutable_global_get_in_const_init(base)
      NonConstantDataOffset =>
        validate_invalid_ast_mutate_non_constant_data_offset(base)
      InvalidImportedFuncTypeIndex =>
        validate_invalid_ast_mutate_invalid_imported_func_type_index(base)
      InvalidImportedTagTypeIndex =>
        validate_invalid_ast_mutate_invalid_imported_tag_type_index(base)
      MutableGlobalGetInTableInit =>
        validate_invalid_ast_mutate_mutable_global_get_in_table_init(base)
      NonConstantElemOffset =>
        validate_invalid_ast_mutate_non_constant_elem_offset(base)
      SharedMemoryWithoutMax =>
        validate_invalid_ast_mutate_shared_memory_without_max(base)
      SharedMemory64WithoutMax =>
        validate_invalid_ast_mutate_shared_memory64_without_max(base)
      InvalidTagTypeIndex =>
        validate_invalid_ast_mutate_invalid_tag_type_index(base)
      InvalidSubtypeSuperIndex =>
        validate_invalid_ast_mutate_invalid_subtype_super_index(base)
      InvalidSubtypeSuperShape =>
        validate_invalid_ast_mutate_invalid_subtype_super_shape(base)
      DescriptorOnFuncType =>
        validate_invalid_ast_mutate_descriptor_on_func_type(base)
      DataCountWithoutDataSec =>
        validate_invalid_ast_mutate_datacount_without_data_sec(base)
    },
  )
}

///|
fn validate_invalid_ast_minimal_valid_module() -> Module {
  let (base, _) = validate_invalid_ast_ensure_any_func(Module::new())
  base
}

///|
pub fn build_validate_invalid_ast_minimal_repro(
  strategy : ValidateInvalidAstStrategyId,
) -> Result[Module, String] {
  let mutation = match
    apply_validate_invalid_ast_strategy(
      strategy,
      validate_invalid_ast_minimal_valid_module(),
    ) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  if !mutation.applicable {
    return Err("validate-invalid-ast minimal repro is not applicable")
  }
  Ok(mutation.mutated_module)
}

///|
pub fn build_validate_invalid_ast_minimal_repro_by_stable_id(
  stable_id : String,
) -> Result[Module, String] {
  let spec = match validate_invalid_ast_strategy_by_stable_id(stable_id) {
    Some(v) => v
    None => return Err("unknown validate-invalid-ast strategy '\{stable_id}'")
  }
  build_validate_invalid_ast_minimal_repro(spec.id)
}

///|
fn validate_invalid_ast_empty_strategy_stats() -> Array[
  ValidateInvalidAstStrategyStats,
] {
  let stats : Array[ValidateInvalidAstStrategyStats] = []
  for spec in validate_invalid_ast_registry() {
    stats.push({
      strategy: spec.id,
      stable_id: spec.stable_id,
      variant_id: spec.variant_id,
      expected_family: spec.expected_family,
      expected_issue_kind: spec.expected_issue_kind,
      attempted: 0,
      applicable: 0,
      mutated: 0,
      rejected: 0,
      rejected_expected: 0,
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
fn validate_invalid_ast_update_strategy_stats(
  stats : Array[ValidateInvalidAstStrategyStats],
  idx : Int,
  attempted? : Int = stats[idx].attempted,
  applicable? : Int = stats[idx].applicable,
  mutated? : Int = stats[idx].mutated,
  rejected? : Int = stats[idx].rejected,
  rejected_expected? : Int = stats[idx].rejected_expected,
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
    expected_family: current.expected_family,
    expected_issue_kind: current.expected_issue_kind,
    attempted,
    applicable,
    mutated,
    rejected,
    rejected_expected,
    variant_attempted,
    variant_applicable,
    variant_mutated,
    variant_rejected,
    rejected_exact_issue,
  }
}

///|
fn validate_invalid_ast_required_failure_messages(
  required_strategies : Array[ValidateInvalidAstStrategyId],
  stats : Array[ValidateInvalidAstStrategyStats],
) -> Array[String] {
  let failures : Array[String] = []
  for strategy in required_strategies {
    let stat = stats[validate_invalid_ast_strategy_index(strategy)]
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
        "\{stat.stable_id}: rejected_expected=0 rejected=\{stat.rejected}",
      )
    }
  }
  failures
}

///|
fn validate_invalid_ast_join(values : Array[String], sep : String) -> String {
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
fn validate_invalid_ast_params_for_seed_profile(
  strategy : ValidateInvalidAstStrategyId,
  seed_profile : GenInvalidNamedSeedProfile,
  generator_config : GenValidConfig,
) -> GenInvalidAstParams {
  match seed_profile {
    NaturalSeedProfile => GenInvalidAstParams::natural_seed(strategy)
    CoverageForcedSeedProfile =>
      GenInvalidAstParams::coverage_forced_seed(strategy)
    SmallNaturalSeedProfile => GenInvalidAstParams::small_natural_seed(strategy)
    SmallCoverageForcedSeedProfile =>
      GenInvalidAstParams::small_coverage_forced_seed(strategy)
    ReproSeedProfile => GenInvalidAstParams::repro_seed(strategy)
    MinimalSeedProfile => GenInvalidAstParams::minimal_seed(strategy)
    RichSeedProfile =>
      GenInvalidAstParams::rich_seed(strategy, generator_config~)
  }
}

///|
pub fn run_validate_invalid_ast_fuzz(
  profile : String,
  seed : UInt64,
) -> Result[ValidateInvalidAstFuzzStats, String] {
  let run_config = match validate_invalid_ast_run_config(profile) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let normalized = run_config.profile
  let attempts = run_config.attempts
  let generator_config = run_config.generator_config
  let required_strategies = run_config.required_strategies
  let seed_profiles = run_config.seed_profiles
  let registry = validate_invalid_ast_registry()
  if registry.is_empty() {
    return Err("validate-invalid-ast registry must not be empty")
  }
  let rnd = @splitmix.new(seed~)
  let stats = validate_invalid_ast_empty_strategy_stats()
  let seed_profile_attempts = seed_profiles.map(fn(_) { 0 })
  let mut attempt = 0
  while attempt < attempts {
    let seed_profile_idx = attempt % seed_profiles.length()
    let seed_profile = seed_profiles[seed_profile_idx]
    seed_profile_attempts[seed_profile_idx] = seed_profile_attempts[seed_profile_idx] +
      1
    let strategy_attempt = attempt / seed_profiles.length()
    let spec = registry[strategy_attempt % registry.length()]
    let stat_idx = validate_invalid_ast_strategy_index(spec.id)
    let current = stats[stat_idx]
    validate_invalid_ast_update_strategy_stats(
      stats,
      stat_idx,
      attempted=current.attempted + 1,
      variant_attempted=current.variant_attempted + 1,
    )
    let generated = match
      gen_invalid_ast_generate(
        rnd,
        validate_invalid_ast_params_for_seed_profile(
          spec.id,
          seed_profile,
          generator_config,
        ),
      ) {
      Ok(v) => v
      Err(msg) =>
        return Err(
          "validate-invalid-ast generation failed: profile=\{normalized} seed=\{seed} attempt=\{attempt + 1} strategy=\{spec.stable_id} error=\{msg}",
        )
    }
    let mutation = generated.mutation
    if mutation.applicable {
      let applicable_now = stats[stat_idx].applicable + 1
      validate_invalid_ast_update_strategy_stats(
        stats,
        stat_idx,
        applicable=applicable_now,
        mutated=stats[stat_idx].mutated + 1,
        variant_applicable=stats[stat_idx].variant_applicable + 1,
        variant_mutated=stats[stat_idx].variant_mutated + 1,
      )
      match validate_module(mutation.mutated_module) {
        Ok(_) =>
          return Err(
            "validate-invalid-ast accepted mutated module: profile=\{normalized} seed=\{seed} attempt=\{attempt + 1} strategy=\{spec.stable_id}",
          )
        Err(err) => {
          let family = validation_issue_family(
            validation_error_diagnostic(err).issue,
          )
          let rejected_now = stats[stat_idx].rejected + 1
          let rejected_expected_now = if family == mutation.expected_family {
            stats[stat_idx].rejected_expected + 1
          } else {
            stats[stat_idx].rejected_expected
          }
          let rejected_exact_issue_now = if family == spec.expected_issue_kind {
            stats[stat_idx].rejected_exact_issue + 1
          } else {
            stats[stat_idx].rejected_exact_issue
          }
          validate_invalid_ast_update_strategy_stats(
            stats,
            stat_idx,
            rejected=rejected_now,
            rejected_expected=rejected_expected_now,
            variant_rejected=stats[stat_idx].variant_rejected + 1,
            rejected_exact_issue=rejected_exact_issue_now,
          )
        }
      }
    }
    attempt += 1
  }
  let required_failures = validate_invalid_ast_required_failure_messages(
    required_strategies, stats,
  )
  if !required_failures.is_empty() {
    let joined_failures = validate_invalid_ast_join(required_failures, "; ")
    return Err(
      "validate-invalid-ast required strategy floors failed: profile=\{normalized} seed=\{seed} \{joined_failures}",
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

///|
test "validate_invalid_ast_run_config can schedule mixed seed profiles" {
  let config = match validate_invalid_ast_run_config("smoke+seeds=mixed") {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(config.profile, "smoke")
  @debug.assert_eq(config.seed_profiles, [
    MinimalSeedProfile,
    ReproSeedProfile,
    SmallNaturalSeedProfile,
    SmallCoverageForcedSeedProfile,
    NaturalSeedProfile,
    CoverageForcedSeedProfile,
    RichSeedProfile,
  ])
  @debug.assert_eq(
    config.attempts,
    validate_invalid_ast_registry().length() * 7,
  )
}

///|
test "validate_invalid_ast_run_config accepts explicit seed profile list" {
  let config = match
    validate_invalid_ast_run_config("smoke+seed-profiles=minimal,natural,rich") {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(config.seed_profiles, [
    MinimalSeedProfile,
    NaturalSeedProfile,
    RichSeedProfile,
  ])
  @debug.assert_eq(
    config.attempts,
    validate_invalid_ast_registry().length() * 3,
  )
}

///|
test "validate_invalid_ast mixed seed fuzz records seed profile attempts" {
  let stats = match
    run_validate_invalid_ast_fuzz("smoke+seed-profiles=minimal", 0x5eedUL) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(stats.seed_profiles, [MinimalSeedProfile])
  @debug.assert_eq(stats.seed_profile_attempts, [
    validate_invalid_ast_registry().length(),
  ])
}

///|
test "validate_invalid_ast_registry exposes the curated smoke-required strategies" {
  let registry = validate_invalid_ast_registry()
  @debug.assert_eq(registry.map(fn(spec) { spec.stable_id }), [
    "duplicate-export-name", "invalid-start-signature", "invalid-imported-start-func-param",
    "invalid-imported-start-func-result", "invalid-imported-start-func-param-result",
    "invalid-imported-start-func-multi-param", "invalid-imported-start-func-f32-param",
    "invalid-imported-start-func-externref-param", "invalid-imported-start-func-funcref-param",
    "missing-datacount", "undeclared-ref-func", "invalid-name-section-func-index",
    "invalid-local-name-section-index", "invalid-label-name-section-index", "invalid-func-type-index",
    "funcsec-without-codesec", "mutable-global-get-in-const-init", "non-constant-data-offset",
    "invalid-imported-func-type-index", "invalid-imported-tag-type-index", "mutable-global-get-in-table-init",
    "non-constant-elem-offset", "shared-memory-without-max", "shared-memory64-without-max",
    "invalid-tag-type-index", "invalid-subtype-super-index", "invalid-subtype-super-shape",
    "descriptor-on-func-type", "datacount-without-data-sec", "invalid-export-func-index",
    "start-func-out-of-range", "missing-datacount-data-drop", "invalid-function-body-local-index",
    "invalid-function-body-global-index", "invalid-function-body-table-index", "invalid-function-body-memory-index",
    "invalid-function-body-call-index", "invalid-function-body-branch-label-index",
    "invalid-function-body-branch-payload-mismatch", "invalid-function-body-call-payload-mismatch",
    "invalid-function-body-br-if-payload-mismatch", "invalid-function-body-br-table-payload-mismatch",
    "invalid-function-body-throw-payload-mismatch", "invalid-function-body-try-table-catch-payload-mismatch",
    "invalid-function-body-memory-address-type", "invalid-function-body-memory64-address-type",
    "invalid-function-body-memory-store-value-type", "invalid-function-body-memory-grow-delta-type",
    "invalid-function-body-memory-fill-value-type", "invalid-function-body-memory-copy-length-type",
    "invalid-function-body-memory-copy-source-type", "invalid-function-body-memory-copy-dest-type",
    "invalid-function-body-memory-init-length-type", "invalid-function-body-memory-init-source-type",
    "invalid-function-body-memory-init-dest-type", "invalid-function-body-local-set-value-type",
    "invalid-function-body-local-tee-value-type", "invalid-function-body-return-value-type",
    "invalid-function-body-table-get-index-type", "invalid-function-body-table-grow-value-type",
    "invalid-function-body-table-grow-delta-type", "invalid-function-body-table-fill-value-type",
    "invalid-function-body-table-fill-dest-type", "invalid-function-body-table-fill-length-type",
    "invalid-function-body-table-copy-length-type", "invalid-function-body-table-copy-source-type",
    "invalid-function-body-table-copy-dest-type", "invalid-function-body-table-init-length-type",
    "invalid-function-body-table-init-source-type", "invalid-function-body-table-init-dest-type",
    "invalid-function-body-data-drop-index", "invalid-function-body-elem-drop-index",
    "invalid-function-body-table-size-index", "invalid-function-body-table-set-index-type",
    "invalid-function-body-call-indirect-index-type", "invalid-function-body-return-call-indirect-index-type",
    "invalid-function-body-return-call-ref-type", "invalid-function-body-call-ref-type",
    "invalid-function-body-ref-cast-input-type", "invalid-function-body-ref-test-input-type",
    "invalid-function-body-ref-test-desc-input-type", "invalid-function-body-ref-cast-desc-eq-input-type",
    "invalid-function-body-table-set-value-type", "invalid-function-body-global-set-value-type",
    "invalid-memory-name-section-index", "codesec-without-funcsec", "invalid-table-name-section-index",
    "invalid-global-name-section-index", "invalid-type-name-section-index", "invalid-field-name-section-index",
    "invalid-elem-name-section-index", "invalid-data-name-section-index", "invalid-export-table-index",
    "invalid-export-global-index", "invalid-export-memory-index", "invalid-export-tag-index",
    "invalid-tag-name-section-index", "datacount-mismatch-too-small", "datacount-mismatch-too-large",
  ])
  let smoke_required = registry.filter(fn(spec) { spec.required_in_smoke })
  @debug.assert_eq(smoke_required.length(), 19)
}

///|
fn invalid_ast_test_base_module(seed : UInt64) -> Module {
  gen_valid_module_with_config(
    @splitmix.new(seed~),
    gen_invalid_coverage_seed_generator_config(),
  )
}

///|
fn invalid_ast_expect_strategy_rejects_with_family(
  strategy : ValidateInvalidAstStrategyId,
  seed : UInt64,
  expected_family : ValidationIssueFamily,
) -> Result[Unit, String] {
  let base = invalid_ast_test_base_module(seed)
  match validate_module(base) {
    Ok(_) => ()
    Err(err) =>
      return Err(
        "expected base gen-valid module to validate before AST mutation: \{validation_error_message(err)}",
      )
  }
  let mutation = match apply_validate_invalid_ast_strategy(strategy, base) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  if !mutation.applicable {
    return Err("expected AST mutation to be applicable")
  }
  match validate_module(mutation.mutated_module) {
    Ok(_) => return Err("expected mutated module to fail validation")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      if family != expected_family {
        return Err(
          "expected family=\{validation_issue_family_label(expected_family)} actual=\{validation_issue_family_label(family)} message=\{validation_error_message(err)}",
        )
      }
    }
  }
  Ok(())
}

///|
test "duplicate export strategy rejects with ExportSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      DuplicateExportName,
      0x5eedUL,
      ExportSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid start signature strategy rejects with StartSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidStartSignature,
      0x5eeeUL,
      StartSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid imported start func param strategy rejects with StartSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidImportedStartFuncParam,
      0x5eee1UL,
      StartSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid imported start func result strategy rejects with StartSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidImportedStartFuncResult,
      0x5eee2UL,
      StartSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid imported start func param-result strategy rejects with StartSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidImportedStartFuncParamResult,
      0x5eee21UL,
      StartSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid imported start func multi-param strategy rejects with StartSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidImportedStartFuncMultiParam,
      0x5eee22UL,
      StartSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid imported start func f32-param strategy rejects with StartSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidImportedStartFuncF32Param,
      0x5eee23UL,
      StartSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid imported start func externref-param strategy rejects with StartSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidImportedStartFuncExternrefParam,
      0x5eee24UL,
      StartSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid imported start func funcref-param strategy rejects with StartSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidImportedStartFuncFuncrefParam,
      0x5eee25UL,
      StartSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "missing datacount strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      MissingDataCount,
      0x5eefUL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "undeclared ref.func strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      UndeclaredRefFunc,
      0x5ef0UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid name-section func index strategy rejects with NameSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidNameSectionFuncIndex,
      0x5ef1UL,
      NameSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid local name index strategy rejects with NameSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidLocalNameSectionIndex,
      0x5ef11UL,
      NameSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid label name index strategy rejects with NameSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidLabelNameSectionIndex,
      0x5ef12UL,
      NameSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid func type index strategy rejects with FunctionSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFuncTypeIndex,
      0x5ef2UL,
      FunctionSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "funcsec without codesec strategy rejects with CodeSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      FuncSecWithoutCodeSec,
      0x5ef3UL,
      CodeSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "mutable global.get const-init strategy rejects with GlobalSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      MutableGlobalGetInConstInit,
      0x5ef4UL,
      GlobalSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "non-constant data offset strategy rejects with DataSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      NonConstantDataOffset,
      0x5ef5UL,
      DataSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid imported func type index strategy rejects with ImportSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidImportedFuncTypeIndex,
      0x5ef6UL,
      ImportSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid imported tag type index strategy rejects with ImportSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidImportedTagTypeIndex,
      0x5ef61UL,
      ImportSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "mutable global.get table-init strategy rejects with TableSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      MutableGlobalGetInTableInit,
      0x5ef7UL,
      TableSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "non-constant elem offset strategy rejects with ElementSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      NonConstantElemOffset,
      0x5ef8UL,
      ElementSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "shared memory without max strategy rejects with MemorySection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      SharedMemoryWithoutMax,
      0x5ef9UL,
      MemorySectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "shared memory64 without max strategy rejects with MemorySection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      SharedMemory64WithoutMax,
      0x5ef91UL,
      MemorySectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid tag type index strategy rejects with TagSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidTagTypeIndex,
      0x5efaUL,
      TagSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid subtype super index strategy rejects with TypeSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidSubtypeSuperIndex,
      0x5efa1UL,
      TypeSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid subtype super shape strategy rejects with TypeSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidSubtypeSuperShape,
      0x5efa2UL,
      TypeSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "descriptor-on-func type strategy rejects with TypeSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      DescriptorOnFuncType,
      0x5efbUL,
      TypeSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "datacount without data section strategy rejects with DataCountSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      DataCountWithoutDataSec,
      0x5efcUL,
      DataCountSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid export func index strategy rejects with ExportSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidExportFuncIndex,
      0x5efdUL,
      ExportSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "start func out of range strategy rejects with StartSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      StartFuncOutOfRange,
      0x5efeUL,
      StartSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "missing datacount data.drop strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      MissingDataCountDataDrop,
      0x5effUL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid local index strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyLocalIndex,
      0x5f0dUL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid global index strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyGlobalIndex,
      0x5f0eUL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid table index strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyTableIndex,
      0x5f0fUL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid memory index strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyMemoryIndex,
      0x5f10UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid function index strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyCallIndex,
      0x5f11UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid branch label strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyBrLabelIndex,
      0x5f12UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid branch payload strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyBrPayloadMismatch,
      0x5f13UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid call payload strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyCallPayloadMismatch,
      0x5f14UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid br_if payload strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyBrIfPayloadMismatch,
      0x5f15UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid br_table payload strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyBrTablePayloadMismatch,
      0x5f16UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid throw payload strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyThrowPayloadMismatch,
      0x5f17UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid try_table catch payload strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyTryTableCatchPayloadMismatch,
      0x5f18UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid memory address type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyMemoryAddressType,
      0x5f19UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body memory address mutation repairs by using i32 memory addresses" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_memory_address_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched memory address type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let with_memory = validate_invalid_ast_ensure_memory(Module::new())
  let repaired_body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::i32_load(MemArg::new(2U, None, 0UL)),
    Instruction::drop(),
  ])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    with_memory,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired memory address module to validate: \{err}")
  }
}

///|
test "invalid memory64 address type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyMemory64AddressType,
      0x5f1aUL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body memory64 address mutation repairs by using i64 memory addresses" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_memory64_address_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched memory64 address type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let with_memory64 = Module::new().with_mem_sec(
    MemSec::new([MemType::new(Limits::i64(1UL, Some(1UL)))]),
  )
  let repaired_body = Expr::new([
    Instruction::i64_const(I64(0)),
    Instruction::i32_load(MemArg::new(2U, None, 0UL)),
    Instruction::drop(),
  ])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    with_memory64,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired memory64 address module to validate: \{err}")
  }
}

///|
test "invalid memory store value type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyMemoryStoreValueType,
      0x5f1bUL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body memory store value mutation repairs by using i32 stored values" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_memory_store_value_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched memory store value type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let with_memory = validate_invalid_ast_ensure_memory(Module::new())
  let repaired_body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(7)),
    Instruction::i32_store(MemArg::new(2U, None, 0UL)),
  ])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    with_memory,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired memory store value module to validate: \{err}")
  }
}

///|
test "invalid table.set value type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyTableSetValueType,
      0x5f1cUL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body table.set value mutation repairs by using matching table refs" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_table_set_value_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched table.set value type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let with_table = Module::new().with_table_sec(
    TableSec::new([
      Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
    ]),
  )
  let repaired_body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::ref_null(HeapType::abs(AbsHeapType::func())),
    Instruction::table_set(TableIdx::new(0U)),
  ])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    with_table,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired table.set value module to validate: \{err}")
  }
}

///|
test "invalid table.set index type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyTableSetIndexType,
      0x10cfbUL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body table.set index mutation repairs by using i32 table indices" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_table_set_index_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched table.set index type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let with_table = Module::new().with_table_sec(
    TableSec::new([
      Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
    ]),
  )
  let repaired_body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::ref_null(HeapType::abs(AbsHeapType::func())),
    Instruction::table_set(TableIdx::new(0U)),
  ])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    with_table,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired table.set index module to validate: \{err}")
  }
}

///|
test "invalid call_indirect index type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyCallIndirectIndexType,
      0x10cfcUL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body call_indirect index mutation repairs by using i32 table indices" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_call_indirect_index_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) =>
      fail("expected mismatched call_indirect table index type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let with_table = Module::new()
    .with_type_sec(
      TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
    )
    .with_table_sec(
      TableSec::new([
        Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
      ]),
    )
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_table,
    [],
    [],
    Locals::empty(),
    Expr::new([
      Instruction::i32_const(I32(0)),
      Instruction::call_indirect(TypeIdx::new(0U), TableIdx::new(0U)),
    ]),
  )
  match validate_module(with_func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired call_indirect index module to validate: \{err}")
  }
}

///|
test "invalid return_call_indirect index type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyReturnCallIndirectIndexType,
      0x10cfdUL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body return_call_indirect index mutation repairs by using i32 table indices" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_return_call_indirect_index_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected mismatched return_call_indirect table index type to reject",
      )
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let with_table = Module::new()
    .with_type_sec(
      TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
    )
    .with_table_sec(
      TableSec::new([
        Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
      ]),
    )
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_table,
    [],
    [],
    Locals::empty(),
    Expr::new([
      Instruction::i32_const(I32(0)),
      Instruction::return_call_indirect(TypeIdx::new(0U), TableIdx::new(0U)),
    ]),
  )
  match validate_module(with_func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected repaired return_call_indirect index module to validate: \{err}",
      )
  }
}

///|
test "invalid return_call_ref ref type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyReturnCallRefType,
      0x10cfeUL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body return_call_ref ref mutation repairs by using a matching function ref" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_return_call_ref_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched return_call_ref ref type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let with_type = Module::new().with_type_sec(
    TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
  )
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_type,
    [],
    [],
    Locals::empty(),
    Expr::new([
      Instruction::ref_null(HeapType::new(TypeIdx::new(0))),
      Instruction::return_call_ref(TypeIdx::new(0U)),
    ]),
  )
  match validate_module(with_func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired return_call_ref ref module to validate: \{err}")
  }
}

///|
test "invalid call_ref ref type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyCallRefType,
      0x10cffUL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body call_ref ref mutation repairs by using a matching function ref" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_call_ref_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched call_ref ref type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let with_type = Module::new().with_type_sec(
    TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
  )
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    with_type,
    [],
    [],
    Locals::empty(),
    Expr::new([
      Instruction::ref_null(HeapType::new(TypeIdx::new(0))),
      Instruction::call_ref(TypeIdx::new(0U)),
    ]),
  )
  match validate_module(with_func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired call_ref ref module to validate: \{err}")
  }
}

///|
test "invalid ref.cast input type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyRefCastInputType,
      0x10d00UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid ref.test input type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyRefTestInputType,
      0x10d01UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid ref.test_desc input type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyRefTestDescInputType,
      0x10d02UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid ref.cast_desc_eq input type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyRefCastDescEqInputType,
      0x10d03UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body ref.cast input mutation repairs by using a reference operand" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_ref_cast_input_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched ref.cast input type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    Module::new(),
    [],
    [],
    Locals::empty(),
    Expr::new([
      Instruction::ref_null(HeapType::abs(AbsHeapType::any())),
      Instruction::ref_cast(true, HeapType::abs(AbsHeapType::eq())),
      Instruction::drop(),
    ]),
  )
  match validate_module(with_func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired ref.cast input module to validate: \{err}")
  }
}

///|
test "function-body ref.test input mutation repairs by using a reference operand" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_ref_test_input_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched ref.test input type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    Module::new(),
    [],
    [],
    Locals::empty(),
    Expr::new([
      Instruction::ref_null(HeapType::abs(AbsHeapType::any())),
      Instruction::ref_test(true, HeapType::abs(AbsHeapType::eq())),
      Instruction::drop(),
    ]),
  )
  match validate_module(with_func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired ref.test input module to validate: \{err}")
  }
}

///|
test "function-body ref.test_desc input mutation repairs by using a reference operand" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_ref_test_desc_input_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched ref.test_desc input type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    Module::new(),
    [],
    [],
    Locals::empty(),
    Expr::new([
      Instruction::ref_null(HeapType::abs(AbsHeapType::any())),
      Instruction::ref_test_desc(true, HeapType::abs(AbsHeapType::eq())),
      Instruction::drop(),
    ]),
  )
  match validate_module(with_func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired ref.test_desc input module to validate: \{err}")
  }
}

///|
test "function-body ref.cast_desc_eq input mutation repairs by using a reference operand" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_ref_cast_desc_eq_input_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched ref.cast_desc_eq input type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let (with_func, _, _) = validate_invalid_ast_append_defined_func(
    Module::new(),
    [],
    [],
    Locals::empty(),
    Expr::new([
      Instruction::ref_null(HeapType::abs(AbsHeapType::any())),
      Instruction::ref_cast_desc_eq(true, HeapType::abs(AbsHeapType::eq())),
      Instruction::drop(),
    ]),
  )
  match validate_module(with_func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected repaired ref.cast_desc_eq input module to validate: \{err}",
      )
  }
}

///|
test "invalid table.get index type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyTableGetIndexType,
      0x10ce4UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body table.get index mutation repairs by using i32 table indices" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_table_get_index_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched table.get index type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let with_table = Module::new().with_table_sec(
    TableSec::new([
      Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
    ]),
  )
  let repaired_body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::table_get(TableIdx::new(0U)),
    Instruction::drop(),
  ])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    with_table,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired table.get index module to validate: \{err}")
  }
}

///|
test "invalid table.grow value type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyTableGrowValueType,
      0x10ce5UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body table.grow value mutation repairs by using matching table refs" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_table_grow_value_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched table.grow value type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let with_table = Module::new().with_table_sec(
    TableSec::new([
      Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
    ]),
  )
  let repaired_body = Expr::new([
    Instruction::ref_null(HeapType::abs(AbsHeapType::func())),
    Instruction::i32_const(I32(1)),
    Instruction::table_grow(TableIdx::new(0U)),
    Instruction::drop(),
  ])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    with_table,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired table.grow value module to validate: \{err}")
  }
}

///|
test "invalid table.grow delta type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyTableGrowDeltaType,
      0x10cf8UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body table.grow delta mutation repairs by using i32 delta" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_table_grow_delta_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched table.grow delta type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let with_table = Module::new().with_table_sec(
    TableSec::new([
      Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
    ]),
  )
  let repaired_body = Expr::new([
    Instruction::ref_null(HeapType::abs(AbsHeapType::func())),
    Instruction::i32_const(I32(1)),
    Instruction::table_grow(TableIdx::new(0U)),
    Instruction::drop(),
  ])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    with_table,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired table.grow delta module to validate: \{err}")
  }
}

///|
test "invalid table.fill value type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyTableFillValueType,
      0x10ce6UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body table.fill value mutation repairs by using matching table refs" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_table_fill_value_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched table.fill value type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let with_table = Module::new().with_table_sec(
    TableSec::new([
      Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
    ]),
  )
  let repaired_body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::ref_null(HeapType::abs(AbsHeapType::func())),
    Instruction::i32_const(I32(1)),
    Instruction::table_fill(TableIdx::new(0U)),
  ])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    with_table,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired table.fill value module to validate: \{err}")
  }
}

///|
test "invalid table.fill dest type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyTableFillDestType,
      0x10cf9UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body table.fill dest mutation repairs by using i32 destination" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_table_fill_dest_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched table.fill dest type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let with_table = Module::new().with_table_sec(
    TableSec::new([
      Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
    ]),
  )
  let repaired_body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::ref_null(HeapType::abs(AbsHeapType::func())),
    Instruction::i32_const(I32(1)),
    Instruction::table_fill(TableIdx::new(0U)),
  ])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    with_table,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired table.fill dest module to validate: \{err}")
  }
}

///|
test "invalid table.fill length type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyTableFillLengthType,
      0x10cfaUL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body table.fill length mutation repairs by using i32 length" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_table_fill_length_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched table.fill length type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let with_table = Module::new().with_table_sec(
    TableSec::new([
      Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
    ]),
  )
  let repaired_body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::ref_null(HeapType::abs(AbsHeapType::func())),
    Instruction::i32_const(I32(1)),
    Instruction::table_fill(TableIdx::new(0U)),
  ])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    with_table,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired table.fill length module to validate: \{err}")
  }
}

///|
test "invalid table.copy length type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyTableCopyLengthType,
      0x10cefUL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid table.copy source type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyTableCopySourceType,
      0x10cf0UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body table.copy length mutation repairs by using i32 length" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_table_copy_length_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched table.copy length type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let with_table = Module::new().with_table_sec(
    TableSec::new([
      Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
    ]),
  )
  let repaired_body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(1)),
    Instruction::table_copy(TableIdx::new(0U), TableIdx::new(0U)),
  ])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    with_table,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired table.copy length module to validate: \{err}")
  }
}

///|
test "invalid table.copy dest type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyTableCopyDestType,
      0x10cf1UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body table.copy source mutation repairs by using i32 source" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_table_copy_source_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched table.copy source type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let with_table = Module::new().with_table_sec(
    TableSec::new([
      Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
    ]),
  )
  let repaired_body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(1)),
    Instruction::table_copy(TableIdx::new(0U), TableIdx::new(0U)),
  ])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    with_table,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired table.copy source module to validate: \{err}")
  }
}

///|
test "function-body table.copy dest mutation repairs by using i32 dest" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_table_copy_dest_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched table.copy dest type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let with_table = Module::new().with_table_sec(
    TableSec::new([
      Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
    ]),
  )
  let repaired_body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(1)),
    Instruction::table_copy(TableIdx::new(0U), TableIdx::new(0U)),
  ])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    with_table,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired table.copy dest module to validate: \{err}")
  }
}

///|
test "invalid table.init length type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyTableInitLengthType,
      0x10cf2UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body table.init length mutation repairs by using i32 length" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_table_init_length_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched table.init length type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let with_table = Module::new()
    .with_table_sec(
      TableSec::new([
        Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
      ]),
    )
    .with_elem_sec(
      ElemSec::new([Elem::new(ElemMode::passive(), ElemKind::funcs([]))]),
    )
  let repaired_body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(1)),
    Instruction::table_init(ElemIdx::new(0U), TableIdx::new(0U)),
  ])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    with_table,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired table.init length module to validate: \{err}")
  }
}

///|
test "invalid table.init source type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyTableInitSourceType,
      0x10cf3UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body table.init source mutation repairs by using i32 source offset" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_table_init_source_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched table.init source type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let with_table = Module::new()
    .with_table_sec(
      TableSec::new([
        Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
      ]),
    )
    .with_elem_sec(
      ElemSec::new([Elem::new(ElemMode::passive(), ElemKind::funcs([]))]),
    )
  let repaired_body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(1)),
    Instruction::table_init(ElemIdx::new(0U), TableIdx::new(0U)),
  ])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    with_table,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired table.init source module to validate: \{err}")
  }
}

///|
test "invalid table.init dest type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyTableInitDestType,
      0x10cf4UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body table.init dest mutation repairs by using i32 destination" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_table_init_dest_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched table.init destination type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let with_table = Module::new()
    .with_table_sec(
      TableSec::new([
        Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
      ]),
    )
    .with_elem_sec(
      ElemSec::new([Elem::new(ElemMode::passive(), ElemKind::funcs([]))]),
    )
  let repaired_body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(1)),
    Instruction::table_init(ElemIdx::new(0U), TableIdx::new(0U)),
  ])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    with_table,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired table.init dest module to validate: \{err}")
  }
}

///|
test "invalid data.drop index strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyDataDropIndex,
      0x10cf5UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body data.drop index mutation repairs by using declared data index" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_data_drop_index(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected out-of-range data.drop index to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let (with_data, data_idx) = validate_invalid_ast_append_passive_data(
    Module::new(),
  )
  let with_count = with_data.with_data_cnt_sec(DataCntSec::new(U32(1U)))
  let repaired_body = Expr::new([Instruction::data_drop(data_idx)])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    with_count,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired data.drop index module to validate: \{err}")
  }
}

///|
test "invalid elem.drop index strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyElemDropIndex,
      0x10cf6UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body elem.drop index mutation repairs by using declared elem index" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_elem_drop_index(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected out-of-range elem.drop index to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let with_elem = Module::new().with_elem_sec(
    ElemSec::new([Elem::new(ElemMode::passive(), ElemKind::funcs([]))]),
  )
  let repaired_body = Expr::new([Instruction::elem_drop(ElemIdx::new(0U))])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    with_elem,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired elem.drop index module to validate: \{err}")
  }
}

///|
test "invalid table.size index strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyTableSizeIndex,
      0x10cf7UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body table.size index mutation repairs by using declared table index" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_table_size_index(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected out-of-range table.size index to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let func_ref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let with_table = Module::new().with_table_sec(
    TableSec::new([
      Table::new(TableType::new(func_ref, Limits::i32(1, None)), None),
    ]),
  )
  let repaired_body = Expr::new([
    Instruction::table_size(TableIdx::new(0U)),
    Instruction::drop(),
  ])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    with_table,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired table.size index module to validate: \{err}")
  }
}

///|
test "invalid memory.fill value type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyMemoryFillValueType,
      0x10ce8UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body memory.fill value mutation repairs by using i32 byte values" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_memory_fill_value_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched memory.fill value type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let with_memory = Module::new().with_mem_sec(
    MemSec::new([MemType::new(Limits::i32(1U, Some(1U)))]),
  )
  let repaired_body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(7)),
    Instruction::i32_const(I32(1)),
    Instruction::memory_fill(MemIdx::new(0U)),
  ])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    with_memory,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired memory.fill value module to validate: \{err}")
  }
}

///|
test "invalid memory.copy length type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyMemoryCopyLengthType,
      0x10ce9UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body memory.copy length mutation repairs by using matching length type" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_memory_copy_length_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched memory.copy length type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let with_memory = Module::new().with_mem_sec(
    MemSec::new([MemType::new(Limits::i32(1U, Some(1U)))]),
  )
  let repaired_body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(1)),
    Instruction::memory_copy(MemIdx::new(0U), MemIdx::new(0U)),
  ])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    with_memory,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired memory.copy length module to validate: \{err}")
  }
}

///|
test "invalid memory.copy source type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyMemoryCopySourceType,
      0x10ceaUL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body memory.copy source mutation repairs by using matching source type" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_memory_copy_source_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched memory.copy source type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let with_memory = Module::new().with_mem_sec(
    MemSec::new([MemType::new(Limits::i32(1U, Some(1U)))]),
  )
  let repaired_body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(1)),
    Instruction::memory_copy(MemIdx::new(0U), MemIdx::new(0U)),
  ])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    with_memory,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired memory.copy source module to validate: \{err}")
  }
}

///|
test "invalid memory.copy dest type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyMemoryCopyDestType,
      0x10cebUL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body memory.copy dest mutation repairs by using matching dest type" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_memory_copy_dest_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched memory.copy dest type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let with_memory = Module::new().with_mem_sec(
    MemSec::new([MemType::new(Limits::i32(1U, Some(1U)))]),
  )
  let repaired_body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(1)),
    Instruction::memory_copy(MemIdx::new(0U), MemIdx::new(0U)),
  ])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    with_memory,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired memory.copy dest module to validate: \{err}")
  }
}

///|
test "invalid memory.init length type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyMemoryInitLengthType,
      0x10cecUL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body memory.init length mutation repairs by using matching length type" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_memory_init_length_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched memory.init length type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let with_memory = Module::new().with_mem_sec(
    MemSec::new([MemType::new(Limits::i32(1U, Some(1U)))]),
  )
  let (with_data, data_idx) = validate_invalid_ast_append_passive_data(
    with_memory,
  )
  let repaired_body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(1)),
    Instruction::memory_init(data_idx, MemIdx::new(0U)),
  ])
  let (repaired_without_count, _, _) = validate_invalid_ast_append_defined_func(
    with_data,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  let repaired = repaired_without_count.with_data_cnt_sec(
    DataCntSec::new(U32(1U)),
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired memory.init length module to validate: \{err}")
  }
}

///|
test "invalid memory.init source type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyMemoryInitSourceType,
      0x10cedUL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body memory.init source mutation repairs by using matching source type" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_memory_init_source_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched memory.init source type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let with_memory = Module::new().with_mem_sec(
    MemSec::new([MemType::new(Limits::i32(1U, Some(1U)))]),
  )
  let (with_data, data_idx) = validate_invalid_ast_append_passive_data(
    with_memory,
  )
  let repaired_body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(1)),
    Instruction::memory_init(data_idx, MemIdx::new(0U)),
  ])
  let (repaired_without_count, _, _) = validate_invalid_ast_append_defined_func(
    with_data,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  let repaired = repaired_without_count.with_data_cnt_sec(
    DataCntSec::new(U32(1U)),
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired memory.init source module to validate: \{err}")
  }
}

///|
test "invalid memory.init dest type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyMemoryInitDestType,
      0x10ceeUL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body memory.init dest mutation repairs by using matching dest type" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_memory_init_dest_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched memory.init dest type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let with_memory = Module::new().with_mem_sec(
    MemSec::new([MemType::new(Limits::i32(1U, Some(1U)))]),
  )
  let (with_data, data_idx) = validate_invalid_ast_append_passive_data(
    with_memory,
  )
  let repaired_body = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(1)),
    Instruction::memory_init(data_idx, MemIdx::new(0U)),
  ])
  let (repaired_without_count, _, _) = validate_invalid_ast_append_defined_func(
    with_data,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  let repaired = repaired_without_count.with_data_cnt_sec(
    DataCntSec::new(U32(1U)),
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired memory.init dest module to validate: \{err}")
  }
}

///|
test "invalid memory.grow delta type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyMemoryGrowDeltaType,
      0x10ce7UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body memory.grow delta mutation repairs by using matching page count type" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_memory_grow_delta_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched memory.grow delta type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let with_memory = Module::new().with_mem_sec(
    MemSec::new([MemType::new(Limits::i32(1U, Some(1U)))]),
  )
  let repaired_body = Expr::new([
    Instruction::i32_const(I32(1)),
    Instruction::memory_grow(MemIdx::new(0U)),
    Instruction::drop(),
  ])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    with_memory,
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired memory.grow delta module to validate: \{err}")
  }
}

///|
test "invalid local.set value type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyLocalSetValueType,
      0x10ca1UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body local.set value mutation repairs by using matching local values" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_local_set_value_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched local.set value type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let repaired_body = Expr::new([
    Instruction::i32_const(I32(7)),
    Instruction::local_set(LocalIdx::new(0U)),
  ])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    Module::new(),
    [ValType::i32()],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired local.set value module to validate: \{err}")
  }
}

///|
test "invalid local.tee value type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyLocalTeeValueType,
      0x10ce2UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body local.tee value mutation repairs by using matching local values" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_local_tee_value_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched local.tee value type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let repaired_body = Expr::new([
    Instruction::i32_const(I32(7)),
    Instruction::local_tee(LocalIdx::new(0U)),
    Instruction::drop(),
  ])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    Module::new(),
    [ValType::i32()],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired local.tee value module to validate: \{err}")
  }
}

///|
test "invalid return value type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyReturnValueType,
      0x10ce3UL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body return value mutation repairs by using matching return values" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_return_value_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched return value type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let repaired_body = Expr::new([
    Instruction::i32_const(I32(7)),
    Instruction::return_(),
    Instruction::unreachable_(),
  ])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    Module::new(),
    [],
    [ValType::i32()],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired return value module to validate: \{err}")
  }
}

///|
test "invalid global.set value type strategy rejects with FunctionBody family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFunctionBodyGlobalSetValueType,
      0x5f1dUL,
      FunctionBodyFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "function-body global.set value mutation repairs by using matching global values" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_global_set_value_type(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched global.set value type to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let globals = [
    Global::new(
      GlobalType::new(ValType::i32(), true),
      Expr::new([Instruction::i32_const(I32(0))]),
    ),
  ]
  let repaired_body = Expr::new([
    Instruction::i32_const(I32(7)),
    Instruction::global_set(GlobalIdx::new(0U)),
  ])
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    Module::new().with_global_sec(GlobalSec::new(globals)),
    [],
    [],
    Locals::empty(),
    repaired_body,
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired global.set value module to validate: \{err}")
  }
}

///|
test "function-body call payload mutation repairs by using the callee parameter type" {
  let mutation = validate_invalid_ast_mutate_invalid_function_body_call_payload_mismatch(
    Module::new(),
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected mismatched call payload to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let (with_callee, callee_idx, _) = validate_invalid_ast_append_defined_func(
    Module::new(),
    [ValType::i32()],
    [],
    Locals::empty(),
    Expr::new([]),
  )
  let (repaired, _, _) = validate_invalid_ast_append_defined_func(
    with_callee,
    [],
    [],
    Locals::empty(),
    Expr::new([Instruction::i32_const(I32(0)), Instruction::call(callee_idx)]),
  )
  match validate_module(repaired) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired call payload module to validate: \{err}")
  }
}

///|
test "function-body exception payload mutations repair by matching tag and target types" {
  let throw_mutation = validate_invalid_ast_mutate_invalid_function_body_throw_payload_mismatch(
    Module::new(),
  )
  match validate_module(throw_mutation.mutated_module) {
    Ok(_) => fail("expected mismatched throw payload to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let catch_mutation = validate_invalid_ast_mutate_invalid_function_body_try_table_catch_payload_mismatch(
    Module::new(),
  )
  match validate_module(catch_mutation.mutated_module) {
    Ok(_) => fail("expected mismatched try_table catch payload to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let (with_i32_tag, tag_idx, _) = validate_invalid_ast_append_tag(
    Module::new(),
    [ValType::i32()],
  )
  let (repaired_throw, _, _) = validate_invalid_ast_append_defined_func(
    with_i32_tag,
    [],
    [],
    Locals::empty(),
    Expr::new([Instruction::i32_const(I32(0)), Instruction::throw_(tag_idx)]),
  )
  match validate_module(repaired_throw) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired throw payload module to validate: \{err}")
  }
  let (with_i64_tag, catch_tag_idx, _) = validate_invalid_ast_append_tag(
    Module::new(),
    [ValType::i64()],
  )
  let catch_body = Expr::new([
    Instruction::block(
      BlockType::val_type(ValType::i64()),
      Expr::new([
        Instruction::try_table(
          BlockType::void_(),
          [Catch::new(catch_tag_idx, LabelIdx::new(0U))],
          Expr::new([
            Instruction::i64_const(I64(0)),
            Instruction::throw_(catch_tag_idx),
          ]),
        ),
        Instruction::unreachable_(),
      ]),
    ),
    Instruction::drop(),
  ])
  let (repaired_catch, _, _) = validate_invalid_ast_append_defined_func(
    with_i64_tag,
    [],
    [],
    Locals::empty(),
    catch_body,
  )
  match validate_module(repaired_catch) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected repaired try_table catch payload module to validate: \{err}",
      )
  }
}

///|
test "function-body branch payload mutations repair by using target result types" {
  let br_if_mutation = validate_invalid_ast_mutate_invalid_function_body_br_if_payload_mismatch(
    Module::new(),
  )
  match validate_module(br_if_mutation.mutated_module) {
    Ok(_) => fail("expected mismatched br_if payload to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let br_table_mutation = validate_invalid_ast_mutate_invalid_function_body_br_table_payload_mismatch(
    Module::new(),
  )
  match validate_module(br_table_mutation.mutated_module) {
    Ok(_) => fail("expected mismatched br_table payload to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        FunctionBodyFamily,
      )
  }
  let br_if_body = Expr::new([
    Instruction::block(
      BlockType::val_type(ValType::i32()),
      Expr::new([
        Instruction::i32_const(I32(0)),
        Instruction::i32_const(I32(1)),
        Instruction::br_if(LabelIdx::new(0U)),
      ]),
    ),
    Instruction::drop(),
  ])
  let (repaired_br_if, _, _) = validate_invalid_ast_append_defined_func(
    Module::new(),
    [],
    [],
    Locals::empty(),
    br_if_body,
  )
  match validate_module(repaired_br_if) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired br_if payload module to validate: \{err}")
  }
  let br_table_body = Expr::new([
    Instruction::block(
      BlockType::val_type(ValType::i32()),
      Expr::new([
        Instruction::i32_const(I32(0)),
        Instruction::i32_const(I32(0)),
        Instruction::br_table([], LabelIdx::new(0U)),
      ]),
    ),
    Instruction::drop(),
  ])
  let (repaired_br_table, _, _) = validate_invalid_ast_append_defined_func(
    Module::new(),
    [],
    [],
    Locals::empty(),
    br_table_body,
  )
  match validate_module(repaired_br_table) {
    Ok(_) => ()
    Err(err) =>
      fail("expected repaired br_table payload module to validate: \{err}")
  }
}

///|
test "invalid memory name index strategy rejects with NameSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidMemoryNameSectionIndex,
      0x5f00UL,
      NameSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid memory name index strategy counts imported memories" {
  let base = Module::new().with_import_sec(
    ImportSec::new([
      Import::new(
        Name::new("env"),
        Name::new("mem0"),
        ExternType::mem(MemType::new(Limits::i32(1U, Some(1U)))),
      ),
      Import::new(
        Name::new("env"),
        Name::new("mem1"),
        ExternType::mem(MemType::new(Limits::i32(1U, Some(1U)))),
      ),
    ]),
  )
  match validate_module(base) {
    Ok(_) => ()
    Err(err) => fail("expected imported-memory base to validate: \{err}")
  }
  let mutation = validate_invalid_ast_mutate_invalid_memory_name_section_index(
    base,
  )
  match validate_module(mutation.mutated_module) {
    Ok(_) => fail("expected invalid memory name index mutation to reject")
    Err(err) =>
      assert_true(
        validation_issue_family(validation_error_diagnostic(err).issue) ==
        NameSectionFamily,
      )
  }
}

///|
test "codesec without funcsec strategy rejects with CodeSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      CodeSecWithoutFuncSec,
      0x5f01UL,
      CodeSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid table name index strategy rejects with NameSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidTableNameSectionIndex,
      0x5f02UL,
      NameSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid global name index strategy rejects with NameSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidGlobalNameSectionIndex,
      0x5f03UL,
      NameSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid type name index strategy rejects with NameSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidTypeNameSectionIndex,
      0x5f04UL,
      NameSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid field name index strategy rejects with NameSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidFieldNameSectionIndex,
      0x5f041UL,
      NameSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid elem name index strategy rejects with NameSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidElemNameSectionIndex,
      0x5f05UL,
      NameSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid data name index strategy rejects with NameSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidDataNameSectionIndex,
      0x5f06UL,
      NameSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid export table index strategy rejects with ExportSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidExportTableIndex,
      0x5f07UL,
      ExportSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid export global index strategy rejects with ExportSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidExportGlobalIndex,
      0x5f08UL,
      ExportSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid export memory index strategy rejects with ExportSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidExportMemoryIndex,
      0x5f091UL,
      ExportSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid export tag index strategy rejects with ExportSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidExportTagIndex,
      0x5f09UL,
      ExportSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid tag name index strategy rejects with NameSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      InvalidTagNameSectionIndex,
      0x5f0aUL,
      NameSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "datacount mismatch too-small strategy rejects with DataCountSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      DataCountMismatchTooSmall,
      0x5f0bUL,
      DataCountSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "datacount mismatch too-large strategy rejects with DataCountSection family" {
  match
    invalid_ast_expect_strategy_rejects_with_family(
      DataCountMismatchTooLarge,
      0x5f0cUL,
      DataCountSectionFamily,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "validate_invalid_ast_registry records default variants and exact issue kinds" {
  let registry = validate_invalid_ast_registry()
  for spec in registry {
    @debug.assert_eq(spec.variant_id, "default")
    @debug.assert_eq(spec.expected_issue_kind, spec.expected_family)
  }
}

///|
test "validate_invalid_ast_fuzz stats record variant attempts and exact issue matches" {
  let stats = match run_validate_invalid_ast_fuzz("smoke", 0x5eedUL) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  for stat in stats.strategy_stats {
    @debug.assert_eq(stat.variant_id, "default")
    assert_true(stat.variant_attempted > 0)
    assert_true(stat.variant_applicable > 0)
    assert_true(stat.variant_mutated > 0)
    assert_true(stat.variant_rejected > 0)
    assert_true(stat.rejected_exact_issue > 0)
  }
}

///|
test "validate_invalid_ast_registry covers every validation issue family" {
  let registry = validate_invalid_ast_registry()
  let expected = [
    TypeSectionFamily,
    ImportSectionFamily,
    FunctionSectionFamily,
    TableSectionFamily,
    MemorySectionFamily,
    TagSectionFamily,
    GlobalSectionFamily,
    ElementSectionFamily,
    DataSectionFamily,
    DataCountSectionFamily,
    StartSectionFamily,
    ExportSectionFamily,
    CodeSectionFamily,
    NameSectionFamily,
    FunctionBodyFamily,
  ]
  for family in expected {
    assert_true(
      registry.any(fn(spec) { spec.expected_family == family }),
      msg="missing family " + validation_issue_family_label(family),
    )
  }
}

///|
test "run_validate_invalid_ast_fuzz returns deterministic fixed-seed strategy stats" {
  let first = match run_validate_invalid_ast_fuzz("smoke", 0x5eedUL) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let second = match run_validate_invalid_ast_fuzz("smoke", 0x5eedUL) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  assert_true(first == second)
  @debug.assert_eq(first.attempts, validate_invalid_ast_registry().length())
  for stat in first.strategy_stats {
    assert_true(stat.attempted > 0)
    assert_true(stat.applicable > 0)
    assert_true(stat.mutated > 0)
    assert_true(stat.rejected > 0)
    assert_true(stat.rejected_expected > 0)
  }
}
