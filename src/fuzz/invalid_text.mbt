///|
fn validate_invalid_text_ascii_lower(input : String) -> String {
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
pub enum ValidateInvalidTextAssertionKind {
  MalformedTextAssertion
  InvalidTextAssertion
  UnlinkableTextAssertion
} derive(Eq, Debug)

///|
pub enum ValidateInvalidTextStage {
  ParseOrLowerRejectedStage
  ValidateRejectedStage
  ValidBeforeLinkStage
} derive(Eq, Debug)

///|
pub fn validate_invalid_text_stage_name(
  stage : ValidateInvalidTextStage,
) -> String {
  match stage {
    ParseOrLowerRejectedStage => "parse-or-lower-rejected"
    ValidateRejectedStage => "validate-rejected"
    ValidBeforeLinkStage => "valid-before-link"
  }
}

///|
fn validate_invalid_text_stage_from_wast(
  stage : WastStaticAssertionStage,
) -> ValidateInvalidTextStage {
  match stage {
    @wast.WastStaticAssertionStage::ParseOrLowerRejected =>
      ParseOrLowerRejectedStage
    @wast.WastStaticAssertionStage::ValidateRejected => ValidateRejectedStage
    @wast.WastStaticAssertionStage::ValidBeforeLink => ValidBeforeLinkStage
  }
}

///|
fn validate_invalid_text_matches_kind(
  cmd : WastCommand,
  expected_kind : ValidateInvalidTextAssertionKind,
) -> Bool {
  match (cmd, expected_kind) {
    (@wast.WastCommand::AssertMalformed(_, _), MalformedTextAssertion) => true
    (@wast.WastCommand::AssertInvalid(_, _), InvalidTextAssertion) => true
    (@wast.WastCommand::AssertUnlinkable(_, _), UnlinkableTextAssertion) => true
    _ => false
  }
}

///|
fn validate_invalid_text_result_matches_kind(
  result : WastStaticAssertionResult,
  expected_kind : ValidateInvalidTextAssertionKind,
) -> Bool {
  match (result.kind, expected_kind) {
    (@wast.WastStaticAssertionKind::Malformed, MalformedTextAssertion) => true
    (@wast.WastStaticAssertionKind::Invalid, InvalidTextAssertion) => true
    (@wast.WastStaticAssertionKind::Unlinkable, UnlinkableTextAssertion) => true
    _ => false
  }
}

///|
fn validate_invalid_text_extract_assertion(
  source : String,
  path : String,
  expected_kind : ValidateInvalidTextAssertionKind,
  occurrence : Int,
) -> Result[WastCommand, String] {
  if occurrence < 0 {
    return Err("assertion occurrence must be non-negative")
  }
  let script = match wast_to_script(source, filename=path) {
    Ok(v) => v
    Err(e) => return Err("script parse failed: \{e}")
  }
  let mut seen = 0
  for cmd in script.commands {
    if validate_invalid_text_matches_kind(cmd, expected_kind) {
      if seen == occurrence {
        return Ok(cmd)
      }
      seen += 1
    }
  }
  Err("missing expected assertion #\{occurrence + 1} in \{path}; found=\{seen}")
}

///|
fn validate_invalid_text_assertion_keyword(
  expected_kind : ValidateInvalidTextAssertionKind,
) -> String {
  match expected_kind {
    MalformedTextAssertion => "(assert_malformed"
    InvalidTextAssertion => "(assert_invalid"
    UnlinkableTextAssertion => "(assert_unlinkable"
  }
}

///|
fn validate_invalid_text_slice(
  source : String,
  start : Int,
  end_exclusive : Int,
) -> String {
  let out = StringBuilder::new()
  let mut i = start
  while i < end_exclusive {
    out.write_char(source[i].unsafe_to_char())
    i += 1
  }
  out.to_string()
}

///|
fn validate_invalid_text_extract_assertion_source_from_spec(
  source : String,
  path : String,
  expected_kind : ValidateInvalidTextAssertionKind,
  occurrence : Int,
) -> Result[String, String] {
  let keyword = validate_invalid_text_assertion_keyword(expected_kind)
  let mut found = 0
  let mut start = -1
  let limit = source.length() - keyword.length()
  let mut i = 0
  while i <= limit {
    let mut matches = true
    let mut j = 0
    while j < keyword.length() {
      if source[i + j] != keyword[j] {
        matches = false
        break
      }
      j += 1
    }
    if matches {
      if found == occurrence {
        start = i
        break
      }
      found += 1
      i += keyword.length()
      continue
    }
    i += 1
  }
  if start < 0 {
    return Err(
      "missing expected raw assertion #\{occurrence + 1} in \{path}; found=\{found}",
    )
  }

  let mut depth = 0
  let mut cursor = start
  let mut in_string = false
  let mut line_comment = false
  let mut block_comment_depth = 0
  while cursor < source.length() {
    let c = source[cursor]
    let next = if cursor + 1 < source.length() {
      source[cursor + 1]
    } else {
      '\u{0}'
    }
    if line_comment {
      if c == '\n' {
        line_comment = false
      }
      cursor += 1
      continue
    }
    if block_comment_depth > 0 {
      if c == '(' && next == ';' {
        block_comment_depth += 1
        cursor += 2
        continue
      }
      if c == ';' && next == ')' {
        block_comment_depth -= 1
        cursor += 2
        continue
      }
      cursor += 1
      continue
    }
    if in_string {
      if c == '\\' && cursor + 1 < source.length() {
        cursor += 2
        continue
      }
      if c == '"' {
        in_string = false
      }
      cursor += 1
      continue
    }
    if c == ';' && next == ';' {
      line_comment = true
      cursor += 2
      continue
    }
    if c == '(' && next == ';' {
      block_comment_depth = 1
      cursor += 2
      continue
    }
    if c == '"' {
      in_string = true
      cursor += 1
      continue
    }
    if c == '(' {
      depth += 1
    } else if c == ')' {
      depth -= 1
      if depth == 0 {
        return Ok(validate_invalid_text_slice(source, start, cursor + 1))
      }
    }
    cursor += 1
  }
  Err("unterminated raw assertion in \{path}")
}

///|
pub enum ValidateInvalidTextStrategyId {
  MalformedQuoteMissingParen
  InvalidResultStack
  UnlinkableUnknownImport
} derive(Eq, Debug)

///|
pub struct ValidateInvalidTextStrategySpec {
  id : ValidateInvalidTextStrategyId
  stable_id : String
  display_name : String
  layer : String
  expected_stage : ValidateInvalidTextStage
  required_in_smoke : Bool
} derive(Eq, Debug)

///|
pub struct ValidateInvalidTextRunConfig {
  profile : String
  attempts : Int
  required_strategies : Array[ValidateInvalidTextStrategyId]
} derive(Eq, Debug)

///|
pub struct ValidateInvalidTextStrategyStats {
  strategy : ValidateInvalidTextStrategyId
  stable_id : String
  expected_stage : ValidateInvalidTextStage
  attempted : Int
  applicable : Int
  parse_or_lower_rejected : Int
  validate_rejected : Int
  valid_before_link : Int
  matched_expected : Int
} derive(Eq, Debug)

///|
pub struct ValidateInvalidTextFuzzStats {
  profile : String
  seed : UInt64
  attempts : Int
  required_strategies : Array[ValidateInvalidTextStrategyId]
  strategy_stats : Array[ValidateInvalidTextStrategyStats]
} derive(Eq, Debug)

///|
fn validate_invalid_text_strategy_spec(
  id : ValidateInvalidTextStrategyId,
  stable_id : String,
  display_name : String,
  expected_stage : ValidateInvalidTextStage,
  required_in_smoke? : Bool = true,
) -> ValidateInvalidTextStrategySpec {
  {
    id,
    stable_id,
    display_name,
    layer: "text",
    expected_stage,
    required_in_smoke,
  }
}

///|
pub fn validate_invalid_text_registry() -> Array[
  ValidateInvalidTextStrategySpec,
] {
  [
    validate_invalid_text_strategy_spec(
      MalformedQuoteMissingParen,
      "malformed-quote-missing-paren",
      "malformed quoted module with a missing closing paren",
      ParseOrLowerRejectedStage,
    ),
    validate_invalid_text_strategy_spec(
      InvalidResultStack,
      "invalid-result-stack",
      "invalid result stack in inline module text",
      ValidateRejectedStage,
    ),
    validate_invalid_text_strategy_spec(
      UnlinkableUnknownImport,
      "unlinkable-unknown-import",
      "valid text module that should remain unlinkable",
      ValidBeforeLinkStage,
    ),
  ]
}

///|
fn validate_invalid_text_strategy_index(
  id : ValidateInvalidTextStrategyId,
) -> Int {
  match id {
    MalformedQuoteMissingParen => 0
    InvalidResultStack => 1
    UnlinkableUnknownImport => 2
  }
}

///|
fn validate_invalid_text_required_strategies(
  normalized : String,
) -> Array[ValidateInvalidTextStrategyId] {
  ignore(normalized)
  validate_invalid_text_registry()
  .filter(fn(spec) { spec.required_in_smoke })
  .map(fn(spec) { spec.id })
}

///|
pub fn validate_invalid_text_run_config(
  profile : String,
) -> Result[ValidateInvalidTextRunConfig, String] {
  let normalized = validate_invalid_text_ascii_lower(profile.trim().to_string())
  let attempts = match normalized {
    "smoke" => 12
    "ci" => 120
    "stress" => 1200
    _ =>
      return Err(
        "unknown validate-invalid-text fuzz profile '\{profile}'; expected smoke|ci|stress",
      )
  }
  Ok({
    profile: normalized,
    attempts,
    required_strategies: validate_invalid_text_required_strategies(normalized),
  })
}

///|
pub fn validate_invalid_text_strategy_by_stable_id(
  stable_id : String,
) -> ValidateInvalidTextStrategySpec? {
  for spec in validate_invalid_text_registry() {
    if spec.stable_id == stable_id {
      return Some(spec)
    }
  }
  None
}

///|
fn validate_invalid_text_strategy_source(
  strategy : ValidateInvalidTextStrategyId,
) -> (String, String, ValidateInvalidTextAssertionKind) {
  match strategy {
    MalformedQuoteMissingParen =>
      (
        "inline-text-invalid/malformed-quote-missing-paren.wast",
        "(assert_malformed (module quote \"(module (func\") \"expected closing paren\")",
        MalformedTextAssertion,
      )
    InvalidResultStack =>
      (
        "inline-text-invalid/invalid-result-stack.wast",
        "(assert_invalid (module (func (result i32) nop)) \"type mismatch\")",
        InvalidTextAssertion,
      )
    UnlinkableUnknownImport =>
      (
        "inline-text-invalid/unlinkable-unknown-import.wast",
        "(assert_unlinkable (module (import \"env\" \"f\" (func))) \"unknown import\")",
        UnlinkableTextAssertion,
      )
  }
}

///|
pub fn validate_invalid_text_source_by_stable_id(
  stable_id : String,
) -> Result[(String, String, ValidateInvalidTextAssertionKind), String] {
  let spec = match validate_invalid_text_strategy_by_stable_id(stable_id) {
    Some(v) => v
    None => return Err("unknown validate-invalid-text strategy '\{stable_id}'")
  }
  Ok(validate_invalid_text_strategy_source(spec.id))
}

///|
pub fn evaluate_validate_invalid_text_assertion_source(
  source : String,
  path : String,
  expected_kind : ValidateInvalidTextAssertionKind,
) -> Result[ValidateInvalidTextStage, String] {
  let cmd = match
    validate_invalid_text_extract_assertion(source, path, expected_kind, 0) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let result = match evaluate_wast_static_assertion(cmd, path) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  if !validate_invalid_text_result_matches_kind(result, expected_kind) {
    return Err("validate-invalid-text kind mismatch for \{path}")
  }
  Ok(validate_invalid_text_stage_from_wast(result.stage))
}

///|
pub fn run_validate_invalid_text_case(
  strategy : ValidateInvalidTextStrategyId,
) -> Result[ValidateInvalidTextStage, String] {
  let (path, source, expected_kind) = validate_invalid_text_strategy_source(
    strategy,
  )
  evaluate_validate_invalid_text_assertion_source(source, path, expected_kind)
}

///|
pub fn run_validate_invalid_text_case_by_stable_id(
  stable_id : String,
) -> Result[String, String] {
  let spec = match validate_invalid_text_strategy_by_stable_id(stable_id) {
    Some(v) => v
    None => return Err("unknown validate-invalid-text strategy '\{stable_id}'")
  }
  match run_validate_invalid_text_case(spec.id) {
    Ok(stage) => Ok(validate_invalid_text_stage_name(stage))
    Err(msg) => Err(msg)
  }
}

///|
fn validate_invalid_text_empty_strategy_stats() -> Array[
  ValidateInvalidTextStrategyStats,
] {
  let stats : Array[ValidateInvalidTextStrategyStats] = []
  for spec in validate_invalid_text_registry() {
    stats.push({
      strategy: spec.id,
      stable_id: spec.stable_id,
      expected_stage: spec.expected_stage,
      attempted: 0,
      applicable: 0,
      parse_or_lower_rejected: 0,
      validate_rejected: 0,
      valid_before_link: 0,
      matched_expected: 0,
    })
  }
  stats
}

///|
fn validate_invalid_text_update_strategy_stats(
  stats : Array[ValidateInvalidTextStrategyStats],
  idx : Int,
  attempted? : Int = stats[idx].attempted,
  applicable? : Int = stats[idx].applicable,
  parse_or_lower_rejected? : Int = stats[idx].parse_or_lower_rejected,
  validate_rejected? : Int = stats[idx].validate_rejected,
  valid_before_link? : Int = stats[idx].valid_before_link,
  matched_expected? : Int = stats[idx].matched_expected,
) -> Unit {
  let current = stats[idx]
  stats[idx] = {
    strategy: current.strategy,
    stable_id: current.stable_id,
    expected_stage: current.expected_stage,
    attempted,
    applicable,
    parse_or_lower_rejected,
    validate_rejected,
    valid_before_link,
    matched_expected,
  }
}

///|
fn validate_invalid_text_required_failure_messages(
  required_strategies : Array[ValidateInvalidTextStrategyId],
  stats : Array[ValidateInvalidTextStrategyStats],
) -> Array[String] {
  let failures : Array[String] = []
  for strategy in required_strategies {
    let stat = stats[validate_invalid_text_strategy_index(strategy)]
    if stat.applicable == 0 {
      failures.push("\{stat.stable_id}: applicable=0")
      continue
    }
    if stat.matched_expected == 0 {
      failures.push(
        "\{stat.stable_id}: matched_expected=0 expected=\{validate_invalid_text_stage_name(stat.expected_stage)} parse_or_lower=\{stat.parse_or_lower_rejected} validate=\{stat.validate_rejected} valid_before_link=\{stat.valid_before_link}",
      )
    }
  }
  failures
}

///|
fn validate_invalid_text_join(values : Array[String], sep : String) -> String {
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
pub fn run_validate_invalid_text_fuzz(
  profile : String,
  seed : UInt64,
) -> Result[ValidateInvalidTextFuzzStats, String] {
  let run_config = match validate_invalid_text_run_config(profile) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let normalized = run_config.profile
  let attempts = run_config.attempts
  let required_strategies = run_config.required_strategies
  let registry = validate_invalid_text_registry()
  if registry.is_empty() {
    return Err("validate-invalid-text registry must not be empty")
  }
  let stats = validate_invalid_text_empty_strategy_stats()
  let start_idx = (seed % registry.length().to_uint64()).to_int()
  let mut attempt = 0
  while attempt < attempts {
    let spec = registry[(start_idx + attempt) % registry.length()]
    let stat_idx = validate_invalid_text_strategy_index(spec.id)
    validate_invalid_text_update_strategy_stats(
      stats,
      stat_idx,
      attempted=stats[stat_idx].attempted + 1,
      applicable=stats[stat_idx].applicable + 1,
    )
    let stage = match run_validate_invalid_text_case(spec.id) {
      Ok(v) => v
      Err(msg) =>
        return Err(
          "validate-invalid-text execution failed: profile=\{normalized} seed=\{seed} attempt=\{attempt + 1} strategy=\{spec.stable_id} error=\{msg}",
        )
    }
    let parse_or_lower_rejected = stats[stat_idx].parse_or_lower_rejected +
      (if stage == ParseOrLowerRejectedStage { 1 } else { 0 })
    let validate_rejected = stats[stat_idx].validate_rejected +
      (if stage == ValidateRejectedStage { 1 } else { 0 })
    let valid_before_link = stats[stat_idx].valid_before_link +
      (if stage == ValidBeforeLinkStage { 1 } else { 0 })
    let matched_expected = stats[stat_idx].matched_expected +
      (if stage == spec.expected_stage { 1 } else { 0 })
    validate_invalid_text_update_strategy_stats(
      stats,
      stat_idx,
      parse_or_lower_rejected~,
      validate_rejected~,
      valid_before_link~,
      matched_expected~,
    )
    attempt += 1
  }
  let required_failures = validate_invalid_text_required_failure_messages(
    required_strategies, stats,
  )
  if !required_failures.is_empty() {
    let joined_failures = validate_invalid_text_join(required_failures, "; ")
    return Err(
      "validate-invalid-text required strategy floors failed: profile=\{normalized} seed=\{seed} \{joined_failures}",
    )
  }
  Ok({
    profile: normalized,
    seed,
    attempts,
    required_strategies,
    strategy_stats: stats,
  })
}

///|
pub enum ValidateInvalidSpecSeedId {
  ConstMalformedQuote1
  F32InvalidTypeMismatch1
  ImportsUnlinkableUnknownImport1
} derive(Eq, Debug)

///|
pub struct ValidateInvalidSpecSeedSpec {
  id : ValidateInvalidSpecSeedId
  stable_id : String
  display_name : String
  layer : String
  path : String
  assertion_kind : ValidateInvalidTextAssertionKind
  assertion_occurrence : Int
  expected_stage : ValidateInvalidTextStage
  required_in_smoke : Bool
} derive(Eq, Debug)

///|
pub struct ValidateInvalidSpecSeedRunConfig {
  profile : String
  attempts : Int
  required_seeds : Array[ValidateInvalidSpecSeedId]
} derive(Eq, Debug)

///|
pub struct ValidateInvalidSpecSeedStats {
  seed_case : ValidateInvalidSpecSeedId
  stable_id : String
  path : String
  expected_stage : ValidateInvalidTextStage
  attempted : Int
  applicable : Int
  parse_or_lower_rejected : Int
  validate_rejected : Int
  valid_before_link : Int
  matched_expected : Int
} derive(Eq, Debug)

///|
pub struct ValidateInvalidSpecSeedFuzzStats {
  profile : String
  seed : UInt64
  attempts : Int
  required_seeds : Array[ValidateInvalidSpecSeedId]
  seed_stats : Array[ValidateInvalidSpecSeedStats]
} derive(Eq, Debug)

///|
fn validate_invalid_spec_seed_spec(
  id : ValidateInvalidSpecSeedId,
  stable_id : String,
  display_name : String,
  path : String,
  assertion_kind : ValidateInvalidTextAssertionKind,
  assertion_occurrence : Int,
  expected_stage : ValidateInvalidTextStage,
  required_in_smoke? : Bool = true,
) -> ValidateInvalidSpecSeedSpec {
  {
    id,
    stable_id,
    display_name,
    layer: "spec-seed",
    path,
    assertion_kind,
    assertion_occurrence,
    expected_stage,
    required_in_smoke,
  }
}

///|
pub fn validate_invalid_spec_seed_registry() -> Array[
  ValidateInvalidSpecSeedSpec,
] {
  [
    validate_invalid_spec_seed_spec(
      ConstMalformedQuote1,
      "const-malformed-quote-1",
      "tests/spec const.wast first malformed quote assertion",
      "tests/spec/const.wast",
      MalformedTextAssertion,
      0,
      ParseOrLowerRejectedStage,
    ),
    validate_invalid_spec_seed_spec(
      F32InvalidTypeMismatch1,
      "f32-invalid-type-mismatch-1",
      "tests/spec f32.wast first invalid type-mismatch assertion",
      "tests/spec/f32.wast",
      InvalidTextAssertion,
      0,
      ValidateRejectedStage,
    ),
    validate_invalid_spec_seed_spec(
      ImportsUnlinkableUnknownImport1,
      "imports-unlinkable-unknown-import-1",
      "tests/spec imports.wast first unlinkable unknown-import assertion",
      "tests/spec/imports.wast",
      UnlinkableTextAssertion,
      0,
      ValidBeforeLinkStage,
    ),
  ]
}

///|
pub fn validate_invalid_spec_seed_by_stable_id(
  stable_id : String,
) -> ValidateInvalidSpecSeedSpec? {
  for spec in validate_invalid_spec_seed_registry() {
    if spec.stable_id == stable_id {
      return Some(spec)
    }
  }
  None
}

///|
fn validate_invalid_spec_seed_index(id : ValidateInvalidSpecSeedId) -> Int {
  match id {
    ConstMalformedQuote1 => 0
    F32InvalidTypeMismatch1 => 1
    ImportsUnlinkableUnknownImport1 => 2
  }
}

///|
fn validate_invalid_spec_seed_required_seeds(
  normalized : String,
) -> Array[ValidateInvalidSpecSeedId] {
  ignore(normalized)
  validate_invalid_spec_seed_registry()
  .filter(fn(spec) { spec.required_in_smoke })
  .map(fn(spec) { spec.id })
}

///|
pub fn validate_invalid_spec_seed_run_config(
  profile : String,
) -> Result[ValidateInvalidSpecSeedRunConfig, String] {
  let normalized = validate_invalid_text_ascii_lower(profile.trim().to_string())
  let attempts = match normalized {
    "smoke" => 12
    "ci" => 120
    "stress" => 1200
    _ =>
      return Err(
        "unknown validate-invalid-spec-seed fuzz profile '\{profile}'; expected smoke|ci|stress",
      )
  }
  Ok({
    profile: normalized,
    attempts,
    required_seeds: validate_invalid_spec_seed_required_seeds(normalized),
  })
}

///|
pub fn validate_invalid_spec_seed_assertion_source(
  seed_case : ValidateInvalidSpecSeedId,
) -> Result[(String, String, ValidateInvalidTextAssertionKind), String] {
  let registry = validate_invalid_spec_seed_registry()
  let spec = registry[validate_invalid_spec_seed_index(seed_case)]
  let source = match read_file_sync(spec.path) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let assertion_source = match
    validate_invalid_text_extract_assertion_source_from_spec(
      source,
      spec.path,
      spec.assertion_kind,
      spec.assertion_occurrence,
    ) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  Ok((spec.path, assertion_source, spec.assertion_kind))
}

///|
pub fn validate_invalid_spec_seed_assertion_source_by_stable_id(
  stable_id : String,
) -> Result[(String, String, ValidateInvalidTextAssertionKind), String] {
  let spec = match validate_invalid_spec_seed_by_stable_id(stable_id) {
    Some(v) => v
    None => return Err("unknown validate-invalid-spec-seed case '\{stable_id}'")
  }
  validate_invalid_spec_seed_assertion_source(spec.id)
}

///|
pub fn run_validate_invalid_spec_seed_case(
  seed_case : ValidateInvalidSpecSeedId,
) -> Result[ValidateInvalidTextStage, String] {
  let (path, assertion_source, assertion_kind) = match
    validate_invalid_spec_seed_assertion_source(seed_case) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  evaluate_validate_invalid_text_assertion_source(
    assertion_source, path, assertion_kind,
  )
}

///|
pub fn run_validate_invalid_spec_seed_case_by_stable_id(
  stable_id : String,
) -> Result[String, String] {
  let spec = match validate_invalid_spec_seed_by_stable_id(stable_id) {
    Some(v) => v
    None => return Err("unknown validate-invalid-spec-seed case '\{stable_id}'")
  }
  match run_validate_invalid_spec_seed_case(spec.id) {
    Ok(stage) => Ok(validate_invalid_text_stage_name(stage))
    Err(msg) => Err(msg)
  }
}

///|
fn validate_invalid_spec_seed_empty_stats() -> Array[
  ValidateInvalidSpecSeedStats,
] {
  let stats : Array[ValidateInvalidSpecSeedStats] = []
  for spec in validate_invalid_spec_seed_registry() {
    stats.push({
      seed_case: spec.id,
      stable_id: spec.stable_id,
      path: spec.path,
      expected_stage: spec.expected_stage,
      attempted: 0,
      applicable: 0,
      parse_or_lower_rejected: 0,
      validate_rejected: 0,
      valid_before_link: 0,
      matched_expected: 0,
    })
  }
  stats
}

///|
fn validate_invalid_spec_seed_update_stats(
  stats : Array[ValidateInvalidSpecSeedStats],
  idx : Int,
  attempted? : Int = stats[idx].attempted,
  applicable? : Int = stats[idx].applicable,
  parse_or_lower_rejected? : Int = stats[idx].parse_or_lower_rejected,
  validate_rejected? : Int = stats[idx].validate_rejected,
  valid_before_link? : Int = stats[idx].valid_before_link,
  matched_expected? : Int = stats[idx].matched_expected,
) -> Unit {
  let current = stats[idx]
  stats[idx] = {
    seed_case: current.seed_case,
    stable_id: current.stable_id,
    path: current.path,
    expected_stage: current.expected_stage,
    attempted,
    applicable,
    parse_or_lower_rejected,
    validate_rejected,
    valid_before_link,
    matched_expected,
  }
}

///|
fn validate_invalid_spec_seed_required_failure_messages(
  required_seeds : Array[ValidateInvalidSpecSeedId],
  stats : Array[ValidateInvalidSpecSeedStats],
) -> Array[String] {
  let failures : Array[String] = []
  for seed_case in required_seeds {
    let stat = stats[validate_invalid_spec_seed_index(seed_case)]
    if stat.applicable == 0 {
      failures.push("\{stat.stable_id}: applicable=0")
      continue
    }
    if stat.matched_expected == 0 {
      failures.push(
        "\{stat.stable_id}: matched_expected=0 expected=\{validate_invalid_text_stage_name(stat.expected_stage)} parse_or_lower=\{stat.parse_or_lower_rejected} validate=\{stat.validate_rejected} valid_before_link=\{stat.valid_before_link}",
      )
    }
  }
  failures
}

///|
pub fn run_validate_invalid_spec_seed_fuzz(
  profile : String,
  seed : UInt64,
) -> Result[ValidateInvalidSpecSeedFuzzStats, String] {
  let run_config = match validate_invalid_spec_seed_run_config(profile) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let normalized = run_config.profile
  let attempts = run_config.attempts
  let required_seeds = run_config.required_seeds
  let registry = validate_invalid_spec_seed_registry()
  if registry.is_empty() {
    return Err("validate-invalid-spec-seed registry must not be empty")
  }
  let stats = validate_invalid_spec_seed_empty_stats()
  let start_idx = (seed % registry.length().to_uint64()).to_int()
  let mut attempt = 0
  while attempt < attempts {
    let spec = registry[(start_idx + attempt) % registry.length()]
    let stat_idx = validate_invalid_spec_seed_index(spec.id)
    validate_invalid_spec_seed_update_stats(
      stats,
      stat_idx,
      attempted=stats[stat_idx].attempted + 1,
      applicable=stats[stat_idx].applicable + 1,
    )
    let stage = match run_validate_invalid_spec_seed_case(spec.id) {
      Ok(v) => v
      Err(msg) =>
        return Err(
          "validate-invalid-spec-seed execution failed: profile=\{normalized} seed=\{seed} attempt=\{attempt + 1} seed_case=\{spec.stable_id} error=\{msg}",
        )
    }
    let parse_or_lower_rejected = stats[stat_idx].parse_or_lower_rejected +
      (if stage == ParseOrLowerRejectedStage { 1 } else { 0 })
    let validate_rejected = stats[stat_idx].validate_rejected +
      (if stage == ValidateRejectedStage { 1 } else { 0 })
    let valid_before_link = stats[stat_idx].valid_before_link +
      (if stage == ValidBeforeLinkStage { 1 } else { 0 })
    let matched_expected = stats[stat_idx].matched_expected +
      (if stage == spec.expected_stage { 1 } else { 0 })
    validate_invalid_spec_seed_update_stats(
      stats,
      stat_idx,
      parse_or_lower_rejected~,
      validate_rejected~,
      valid_before_link~,
      matched_expected~,
    )
    attempt += 1
  }
  let required_failures = validate_invalid_spec_seed_required_failure_messages(
    required_seeds, stats,
  )
  if !required_failures.is_empty() {
    let joined_failures = validate_invalid_text_join(required_failures, "; ")
    return Err(
      "validate-invalid-spec-seed required seed floors failed: profile=\{normalized} seed=\{seed} \{joined_failures}",
    )
  }
  Ok({ profile: normalized, seed, attempts, required_seeds, seed_stats: stats })
}
