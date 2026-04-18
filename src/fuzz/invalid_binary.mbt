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
  WrongSectionOrder
  InvalidFuncTypeIndex
  InvalidStartSignatureModule
  DuplicateExportNameModule
  FuncSecWithoutCodeSecModule
  DataCountWithoutDataSecModule
  InvalidNameSectionFuncIndexModule
} derive(Eq, Debug)

///|
pub struct ValidateInvalidBinaryStrategySpec {
  id : ValidateInvalidBinaryStrategyId
  stable_id : String
  display_name : String
  layer : String
  expected_result : ValidateInvalidBinaryExpectedResult
  required_in_smoke : Bool
} derive(Eq, Debug)

///|
pub struct ValidateInvalidBinaryRunConfig {
  profile : String
  attempts : Int
  generator_config : GenValidConfig
  required_strategies : Array[ValidateInvalidBinaryStrategyId]
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
pub fn GenInvalidBinaryParams::new(
  strategy : ValidateInvalidBinaryStrategyId,
  seed_mode? : GenInvalidBinarySeedMode = RandomValidSeed,
  generator_config? : GenValidConfig = GenValidConfig::coverage_forced_default(),
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
  generator_config? : GenValidConfig = GenValidConfig::coverage_forced_default(),
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
  generator_config? : GenValidConfig = GenValidConfig::coverage_forced_default(),
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
  generator_config? : GenValidConfig = GenValidConfig::coverage_forced_default(),
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
  generator_config? : GenValidConfig = GenValidConfig::coverage_forced_default(),
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
  expected_result : ValidateInvalidBinaryExpectedResult
  attempted : Int
  applicable : Int
  mutated : Int
  decode_rejected : Int
  validate_rejected : Int
  rejected_expected : Int
  accepted : Int
} derive(Eq, Debug)

///|
pub struct ValidateInvalidBinaryFuzzStats {
  profile : String
  seed : UInt64
  attempts : Int
  generator_config : GenValidConfig
  required_strategies : Array[ValidateInvalidBinaryStrategyId]
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
    WrongSectionOrder => "wrong-section-order"
    InvalidFuncTypeIndex => "invalid-func-type-index"
    InvalidStartSignatureModule => "invalid-start-signature-module"
    DuplicateExportNameModule => "duplicate-export-name-module"
    FuncSecWithoutCodeSecModule => "funcsec-without-codesec-module"
    DataCountWithoutDataSecModule => "datacount-without-data-sec-module"
    InvalidNameSectionFuncIndexModule =>
      "invalid-name-section-func-index-module"
  }
}

///|
pub fn gen_invalid_binary_seed_config(
  params : GenInvalidBinaryParams,
) -> GenValidConfig {
  if !params.require_strategy_prereqs {
    return params.generator_config
  }
  let config = params.generator_config
  match params.strategy {
    InvalidFuncTypeIndex =>
      @validate.gen_invalid_require_defined_func_gen_valid_config(config)
    InvalidStartSignatureModule =>
      @validate.gen_invalid_require_defined_func_gen_valid_config(config)
    FuncSecWithoutCodeSecModule =>
      @validate.gen_invalid_require_defined_func_gen_valid_config(config)
    _ => config
  }
}

///|
fn validate_invalid_binary_strategy_spec(
  id : ValidateInvalidBinaryStrategyId,
  stable_id : String,
  display_name : String,
  expected_result : ValidateInvalidBinaryExpectedResult,
  required_in_smoke? : Bool = true,
) -> ValidateInvalidBinaryStrategySpec {
  {
    id,
    stable_id,
    display_name,
    layer: "binary",
    expected_result,
    required_in_smoke,
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
    ),
    validate_invalid_binary_strategy_spec(
      InvalidStartSignatureModule,
      "invalid-start-signature-module",
      "encoded module with invalid start signature",
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
  match id {
    TrailingGarbage => 0
    TruncatedModule => 1
    DuplicateTypeSection => 2
    WrongSectionOrder => 3
    InvalidFuncTypeIndex => 4
    InvalidStartSignatureModule => 5
    DuplicateExportNameModule => 6
    FuncSecWithoutCodeSecModule => 7
    DataCountWithoutDataSecModule => 8
    InvalidNameSectionFuncIndexModule => 9
  }
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
pub fn validate_invalid_binary_run_config(
  profile : String,
) -> Result[ValidateInvalidBinaryRunConfig, String] {
  let normalized = validate_invalid_binary_ascii_lower(
    profile.trim().to_string(),
  )
  let attempts = match normalized {
    "smoke" => 20
    "ci" => 200
    "stress" => 2000
    _ =>
      return Err(
        "unknown validate-invalid-binary fuzz profile '\{profile}'; expected smoke|ci|stress",
      )
  }
  Ok({
    profile: normalized,
    attempts,
    generator_config: GenValidConfig::coverage_forced_default(),
    required_strategies: validate_invalid_binary_required_strategies(normalized),
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
fn validate_invalid_binary_mutate_duplicate_type_section(
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
          DuplicateTypeSection,
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
    type_span.header_start,
    type_span.end,
  )
  Ok(
    validate_invalid_binary_mutation(
      DuplicateTypeSection,
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
    WrongSectionOrder =>
      validate_invalid_binary_mutate_wrong_section_order(base)
    InvalidFuncTypeIndex =>
      validate_invalid_binary_mutate_invalid_func_type_index(base)
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
      expected_result: spec.expected_result,
      attempted: 0,
      applicable: 0,
      mutated: 0,
      decode_rejected: 0,
      validate_rejected: 0,
      rejected_expected: 0,
      accepted: 0,
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
) -> Unit {
  let current = stats[idx]
  stats[idx] = {
    strategy: current.strategy,
    stable_id: current.stable_id,
    expected_result: current.expected_result,
    attempted,
    applicable,
    mutated,
    decode_rejected,
    validate_rejected,
    rejected_expected,
    accepted,
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
  let registry = validate_invalid_binary_registry()
  if registry.is_empty() {
    return Err("validate-invalid-binary registry must not be empty")
  }
  let rnd = @splitmix.new(seed~)
  let stats = validate_invalid_binary_empty_strategy_stats()
  let mut attempt = 0
  while attempt < attempts {
    let spec = registry[attempt % registry.length()]
    let stat_idx = validate_invalid_binary_strategy_index(spec.id)
    validate_invalid_binary_update_strategy_stats(
      stats,
      stat_idx,
      attempted=stats[stat_idx].attempted + 1,
    )
    let generated = match
      gen_invalid_binary_generate(
        rnd,
        GenInvalidBinaryParams::new(spec.id, generator_config~),
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
      )
      match decode_module(mutation.mutated_bytes) {
        Err(_) => {
          let rejected_expected_now = match mutation.expected_result {
            DecodeRejected => stats[stat_idx].rejected_expected + 1
            ValidateRejected(_) => stats[stat_idx].rejected_expected
          }
          validate_invalid_binary_update_strategy_stats(
            stats,
            stat_idx,
            decode_rejected=stats[stat_idx].decode_rejected + 1,
            rejected_expected=rejected_expected_now,
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
              validate_invalid_binary_update_strategy_stats(
                stats,
                stat_idx,
                validate_rejected=stats[stat_idx].validate_rejected + 1,
                rejected_expected=rejected_expected_now,
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
    strategy_stats: stats,
  })
}
