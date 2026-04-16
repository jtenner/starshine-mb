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
  MissingDataCount
  UndeclaredRefFunc
  InvalidNameSectionFuncIndex
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
    MissingDataCount => 2
    UndeclaredRefFunc => 3
    InvalidNameSectionFuncIndex => 4
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
    "smoke" => 20
    "ci" => 200
    "stress" => 2000
    _ =>
      return Err(
        "unknown validate-invalid-ast fuzz profile '\{profile}'; expected smoke|ci|stress",
      )
  }
  Ok({
    profile: normalized,
    attempts,
    generator_config: GenValidConfig::coverage_forced_default(),
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
fn validate_invalid_ast_data_entries(mod : Module) -> Array[Data] {
  match mod.data_sec {
    Some(DataSec(entries)) => entries.copy()
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
fn validate_invalid_ast_total_func_count(mod : Module) -> Int {
  validate_invalid_ast_imported_func_count(mod) +
  validate_invalid_ast_defined_func_count(mod)
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
  let type_idx = TypeIdx::new(types.length().reinterpret_as_uint())
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
      InvalidStartSignature =>
        validate_invalid_ast_mutate_invalid_start_signature(base)
      MissingDataCount => validate_invalid_ast_mutate_missing_datacount(base)
      UndeclaredRefFunc => validate_invalid_ast_mutate_undeclared_ref_func(base)
      InvalidNameSectionFuncIndex =>
        validate_invalid_ast_mutate_invalid_name_section_func_index(base)
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
    let base = gen_valid_module_with_config(rnd, generator_config)
    match validate_module(base) {
      Ok(_) => ()
      Err(err) =>
        return Err(
          "validate-invalid-ast base generation failed before mutation: profile=\{normalized} seed=\{seed} attempt=\{attempt + 1} strategy=\{spec.stable_id} error=\{validation_error_message(err)}",
        )
    }
    let mutation = match apply_validate_invalid_ast_strategy(spec.id, base) {
      Ok(v) => v
      Err(msg) => return Err(msg)
    }
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
    "duplicate-export-name", "invalid-start-signature", "missing-datacount", "undeclared-ref-func",
    "invalid-name-section-func-index",
  ])
  let smoke_required = registry.filter(fn(spec) { spec.required_in_smoke })
  assert_eq(smoke_required.length(), 5)
}

///|
fn invalid_ast_test_base_module(seed : UInt64) -> Module {
  gen_valid_module_with_config(
    @splitmix.new(seed~),
    GenValidConfig::coverage_forced_default(),
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
  assert_eq(first.attempts, 20)
  for stat in first.strategy_stats {
    assert_true(stat.attempted > 0)
    assert_true(stat.applicable > 0)
    assert_true(stat.mutated > 0)
    assert_true(stat.rejected > 0)
    assert_true(stat.rejected_expected > 0)
  }
}
