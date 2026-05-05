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
pub struct ValidateInvalidAstStrategySpec {
  id : ValidateInvalidAstStrategyId
  stable_id : String
  display_name : String
  layer : String
  expected_family : ValidationIssueFamily
  required_in_smoke : Bool
} derive(Eq, Debug)

///|
pub struct ValidateInvalidAstRunConfig {
  profile : String
  attempts : Int
  generator_config : GenValidConfig
  required_strategies : Array[ValidateInvalidAstStrategyId]
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
  expected_family : ValidationIssueFamily
  attempted : Int
  applicable : Int
  mutated : Int
  rejected : Int
  rejected_expected : Int
} derive(Eq, Debug)

///|
pub struct ValidateInvalidAstFuzzStats {
  profile : String
  seed : UInt64
  attempts : Int
  generator_config : GenValidConfig
  required_strategies : Array[ValidateInvalidAstStrategyId]
  strategy_stats : Array[ValidateInvalidAstStrategyStats]
} derive(Eq, Debug)

///|
fn validate_invalid_ast_strategy_spec(
  id : ValidateInvalidAstStrategyId,
  stable_id : String,
  display_name : String,
  expected_family : ValidationIssueFamily,
  required_in_smoke? : Bool = true,
) -> ValidateInvalidAstStrategySpec {
  {
    id,
    stable_id,
    display_name,
    layer: "ast",
    expected_family,
    required_in_smoke,
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
    ),
    validate_invalid_ast_strategy_spec(
      DataCountMismatchTooLarge,
      "datacount-mismatch-too-large",
      "datacount section larger than data segment count",
      DataCountSectionFamily,
      required_in_smoke=false,
    ),
  ]
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
    InvalidMemoryNameSectionIndex => 32
    CodeSecWithoutFuncSec => 33
    InvalidTableNameSectionIndex => 34
    InvalidGlobalNameSectionIndex => 35
    InvalidTypeNameSectionIndex => 36
    InvalidFieldNameSectionIndex => 37
    InvalidElemNameSectionIndex => 38
    InvalidDataNameSectionIndex => 39
    InvalidExportTableIndex => 40
    InvalidExportGlobalIndex => 41
    InvalidExportMemoryIndex => 42
    InvalidExportTagIndex => 43
    InvalidTagNameSectionIndex => 44
    DataCountMismatchTooSmall => 45
    DataCountMismatchTooLarge => 46
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
pub fn validate_invalid_ast_run_config(
  profile : String,
) -> Result[ValidateInvalidAstRunConfig, String] {
  let normalized = validate_fuzz_ascii_lower(profile.trim().to_string())
  let attempts = match normalized {
    "smoke" => 47
    "ci" => 470
    "stress" => 4700
    _ =>
      return Err(
        "unknown validate-invalid-ast fuzz profile '\{profile}'; expected smoke|ci|stress",
      )
  }
  Ok({
    profile: normalized,
    attempts,
    generator_config: gen_invalid_coverage_seed_generator_config(),
    required_strategies: validate_invalid_ast_required_strategies(normalized),
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
      expected_family: spec.expected_family,
      attempted: 0,
      applicable: 0,
      mutated: 0,
      rejected: 0,
      rejected_expected: 0,
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
) -> Unit {
  let current = stats[idx]
  stats[idx] = {
    strategy: current.strategy,
    stable_id: current.stable_id,
    expected_family: current.expected_family,
    attempted,
    applicable,
    mutated,
    rejected,
    rejected_expected,
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
  let registry = validate_invalid_ast_registry()
  if registry.is_empty() {
    return Err("validate-invalid-ast registry must not be empty")
  }
  let rnd = @splitmix.new(seed~)
  let stats = validate_invalid_ast_empty_strategy_stats()
  let mut attempt = 0
  while attempt < attempts {
    let spec = registry[attempt % registry.length()]
    let stat_idx = validate_invalid_ast_strategy_index(spec.id)
    let current = stats[stat_idx]
    validate_invalid_ast_update_strategy_stats(
      stats,
      stat_idx,
      attempted=current.attempted + 1,
    )
    let generated = match
      gen_invalid_ast_generate(
        rnd,
        GenInvalidAstParams::new(spec.id, generator_config~),
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
          validate_invalid_ast_update_strategy_stats(
            stats,
            stat_idx,
            rejected=rejected_now,
            rejected_expected=rejected_expected_now,
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
    strategy_stats: stats,
  })
}

///|
test "validate_invalid_ast_registry exposes the curated smoke-required strategies" {
  let registry = validate_invalid_ast_registry()
  assert_eq(registry.map(fn(spec) { spec.stable_id }), [
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
    "start-func-out-of-range", "missing-datacount-data-drop", "invalid-memory-name-section-index",
    "codesec-without-funcsec", "invalid-table-name-section-index", "invalid-global-name-section-index",
    "invalid-type-name-section-index", "invalid-field-name-section-index", "invalid-elem-name-section-index",
    "invalid-data-name-section-index", "invalid-export-table-index", "invalid-export-global-index",
    "invalid-export-memory-index", "invalid-export-tag-index", "invalid-tag-name-section-index",
    "datacount-mismatch-too-small", "datacount-mismatch-too-large",
  ])
  let smoke_required = registry.filter(fn(spec) { spec.required_in_smoke })
  assert_eq(smoke_required.length(), 19)
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
  assert_eq(first.attempts, 47)
  for stat in first.strategy_stats {
    assert_true(stat.attempted > 0)
    assert_true(stat.applicable > 0)
    assert_true(stat.mutated > 0)
    assert_true(stat.rejected > 0)
    assert_true(stat.rejected_expected > 0)
  }
}
