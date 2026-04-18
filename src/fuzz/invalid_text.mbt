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
  MalformedTrailingGarbage
  InvalidMutableGlobalConstInit
  UnlinkableUnknownMemoryImport
  MalformedInvalidConstToken
  InvalidStartFuncParam
  UnlinkableUnknownGlobalImport
  MalformedInvalidF64ConstToken
  InvalidDuplicateExportName
  UnlinkableUnknownTableImport
  MalformedInvalidI64ConstToken
  InvalidStartFuncResult
  UnlinkableIncompatibleFuncImportType
  MalformedInvalidI32HexToken
  InvalidImportedStartFuncParam
  UnlinkableIncompatibleGlobalImportType
  MalformedInvalidI64HexToken
  InvalidImportedStartFuncResult
  UnlinkableIncompatibleTagImportType
  MalformedInvalidI32BadOpcode
  InvalidImportedStartFuncParamResult
  UnlinkableIncompatibleGlobalImportMutability
  MalformedInvalidF32BadOpcode
  InvalidImportedStartFuncMultiParam
  UnlinkableIncompatibleGlobalImportI64
  MalformedInvalidI64BadOpcode
  InvalidImportedStartFuncF32Param
  InvalidImportedStartFuncExternrefParam
  MalformedInvalidF64BadOpcode
  InvalidImportedStartFuncFuncrefParam
  UnlinkableIncompatibleGlobalImportF64
  UnlinkableIncompatibleMemoryImportMax
  InvalidStartFuncOutOfRange
  UnlinkableIncompatibleMemoryImportMin
  UnlinkableIncompatibleTableImportLimits
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
    validate_invalid_text_strategy_spec(
      MalformedTrailingGarbage,
      "malformed-trailing-garbage",
      "malformed text with trailing garbage after a module",
      ParseOrLowerRejectedStage,
    ),
    validate_invalid_text_strategy_spec(
      InvalidMutableGlobalConstInit,
      "invalid-mutable-global-const-init",
      "invalid mutable global.get in const initializer",
      ValidateRejectedStage,
    ),
    validate_invalid_text_strategy_spec(
      UnlinkableUnknownMemoryImport,
      "unlinkable-unknown-memory-import",
      "valid text module with unknown memory import",
      ValidBeforeLinkStage,
    ),
    validate_invalid_text_strategy_spec(
      MalformedInvalidConstToken,
      "malformed-invalid-const-token",
      "malformed text with an invalid const token",
      ParseOrLowerRejectedStage,
    ),
    validate_invalid_text_strategy_spec(
      InvalidStartFuncParam,
      "invalid-start-func-param",
      "invalid text module with a parameterized start function",
      ValidateRejectedStage,
    ),
    validate_invalid_text_strategy_spec(
      UnlinkableUnknownGlobalImport,
      "unlinkable-unknown-global-import",
      "valid text module with unknown global import",
      ValidBeforeLinkStage,
    ),
    validate_invalid_text_strategy_spec(
      MalformedInvalidF64ConstToken,
      "malformed-invalid-f64-const-token",
      "malformed text with an invalid f64 const token",
      ParseOrLowerRejectedStage,
    ),
    validate_invalid_text_strategy_spec(
      InvalidDuplicateExportName,
      "invalid-duplicate-export-name",
      "invalid text module with duplicate export names",
      ValidateRejectedStage,
    ),
    validate_invalid_text_strategy_spec(
      UnlinkableUnknownTableImport,
      "unlinkable-unknown-table-import",
      "valid text module with unknown table import",
      ValidBeforeLinkStage,
    ),
    validate_invalid_text_strategy_spec(
      MalformedInvalidI64ConstToken,
      "malformed-invalid-i64-const-token",
      "malformed text with an invalid i64 const token",
      ParseOrLowerRejectedStage,
    ),
    validate_invalid_text_strategy_spec(
      InvalidStartFuncResult,
      "invalid-start-func-result",
      "invalid text module with a result-returning start function",
      ValidateRejectedStage,
    ),
    validate_invalid_text_strategy_spec(
      UnlinkableIncompatibleFuncImportType,
      "unlinkable-incompatible-func-import-type",
      "valid text module with a typed function import that remains unlinkable",
      ValidBeforeLinkStage,
    ),
    validate_invalid_text_strategy_spec(
      MalformedInvalidI32HexToken,
      "malformed-invalid-i32-hex-token",
      "malformed text with an invalid i32 hex token",
      ParseOrLowerRejectedStage,
    ),
    validate_invalid_text_strategy_spec(
      InvalidImportedStartFuncParam,
      "invalid-imported-start-func-param",
      "invalid text module with an imported parameterized start function",
      ValidateRejectedStage,
    ),
    validate_invalid_text_strategy_spec(
      UnlinkableIncompatibleGlobalImportType,
      "unlinkable-incompatible-global-import-type",
      "valid text module with an incompatible global import type",
      ValidBeforeLinkStage,
    ),
    validate_invalid_text_strategy_spec(
      MalformedInvalidI64HexToken,
      "malformed-invalid-i64-hex-token",
      "malformed text with an invalid i64 hex token",
      ParseOrLowerRejectedStage,
    ),
    validate_invalid_text_strategy_spec(
      InvalidImportedStartFuncResult,
      "invalid-imported-start-func-result",
      "invalid text module with an imported result-bearing start function",
      ValidateRejectedStage,
    ),
    validate_invalid_text_strategy_spec(
      UnlinkableIncompatibleTagImportType,
      "unlinkable-incompatible-tag-import-type",
      "valid text module with an incompatible tag import type",
      ValidBeforeLinkStage,
    ),
    validate_invalid_text_strategy_spec(
      MalformedInvalidI32BadOpcode,
      "malformed-invalid-i32-bad-opcode",
      "malformed text with an invalid i32 opcode token",
      ParseOrLowerRejectedStage,
    ),
    validate_invalid_text_strategy_spec(
      InvalidImportedStartFuncParamResult,
      "invalid-imported-start-func-param-result",
      "invalid text module with an imported parameterized result-bearing start function",
      ValidateRejectedStage,
    ),
    validate_invalid_text_strategy_spec(
      UnlinkableIncompatibleGlobalImportMutability,
      "unlinkable-incompatible-global-import-mutability",
      "valid text module with an incompatible global import mutability",
      ValidBeforeLinkStage,
    ),
    validate_invalid_text_strategy_spec(
      MalformedInvalidF32BadOpcode,
      "malformed-invalid-f32-bad-opcode",
      "malformed text with an invalid f32 opcode token",
      ParseOrLowerRejectedStage,
    ),
    validate_invalid_text_strategy_spec(
      InvalidImportedStartFuncMultiParam,
      "invalid-imported-start-func-multi-param",
      "invalid text module with an imported multi-parameter start function",
      ValidateRejectedStage,
    ),
    validate_invalid_text_strategy_spec(
      UnlinkableIncompatibleGlobalImportI64,
      "unlinkable-incompatible-global-import-i64",
      "valid text module with an incompatible i64 global import type",
      ValidBeforeLinkStage,
    ),
    validate_invalid_text_strategy_spec(
      MalformedInvalidI64BadOpcode,
      "malformed-invalid-i64-bad-opcode",
      "malformed text with an invalid i64 opcode token",
      ParseOrLowerRejectedStage,
    ),
    validate_invalid_text_strategy_spec(
      InvalidImportedStartFuncF32Param,
      "invalid-imported-start-func-f32-param",
      "invalid text module with an imported f32-parameter start function",
      ValidateRejectedStage,
    ),
    validate_invalid_text_strategy_spec(
      InvalidImportedStartFuncExternrefParam,
      "invalid-imported-start-func-externref-param",
      "invalid text module with an imported externref-parameter start function",
      ValidateRejectedStage,
    ),
    validate_invalid_text_strategy_spec(
      MalformedInvalidF64BadOpcode,
      "malformed-invalid-f64-bad-opcode",
      "malformed text with an invalid f64 opcode token",
      ParseOrLowerRejectedStage,
    ),
    validate_invalid_text_strategy_spec(
      InvalidImportedStartFuncFuncrefParam,
      "invalid-imported-start-func-funcref-param",
      "invalid text module with an imported funcref-parameter start function",
      ValidateRejectedStage,
    ),
    validate_invalid_text_strategy_spec(
      UnlinkableIncompatibleGlobalImportF64,
      "unlinkable-incompatible-global-import-f64",
      "valid text module with an incompatible f64 global import type",
      ValidBeforeLinkStage,
    ),
    validate_invalid_text_strategy_spec(
      UnlinkableIncompatibleMemoryImportMax,
      "unlinkable-incompatible-memory-import-max",
      "valid text module with an incompatible memory import maximum",
      ValidBeforeLinkStage,
    ),
    validate_invalid_text_strategy_spec(
      InvalidStartFuncOutOfRange,
      "invalid-start-func-out-of-range",
      "invalid text module with an out-of-range start function index",
      ValidateRejectedStage,
    ),
    validate_invalid_text_strategy_spec(
      UnlinkableIncompatibleMemoryImportMin,
      "unlinkable-incompatible-memory-import-min",
      "valid text module with an incompatible memory import minimum",
      ValidBeforeLinkStage,
    ),
    validate_invalid_text_strategy_spec(
      UnlinkableIncompatibleTableImportLimits,
      "unlinkable-incompatible-table-import-limits",
      "valid text module with incompatible table import limits",
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
    MalformedTrailingGarbage => 3
    InvalidMutableGlobalConstInit => 4
    UnlinkableUnknownMemoryImport => 5
    MalformedInvalidConstToken => 6
    InvalidStartFuncParam => 7
    UnlinkableUnknownGlobalImport => 8
    MalformedInvalidF64ConstToken => 9
    InvalidDuplicateExportName => 10
    UnlinkableUnknownTableImport => 11
    MalformedInvalidI64ConstToken => 12
    InvalidStartFuncResult => 13
    UnlinkableIncompatibleFuncImportType => 14
    MalformedInvalidI32HexToken => 15
    InvalidImportedStartFuncParam => 16
    UnlinkableIncompatibleGlobalImportType => 17
    MalformedInvalidI64HexToken => 18
    InvalidImportedStartFuncResult => 19
    UnlinkableIncompatibleTagImportType => 20
    MalformedInvalidI32BadOpcode => 21
    InvalidImportedStartFuncParamResult => 22
    UnlinkableIncompatibleGlobalImportMutability => 23
    MalformedInvalidF32BadOpcode => 24
    InvalidImportedStartFuncMultiParam => 25
    UnlinkableIncompatibleGlobalImportI64 => 26
    MalformedInvalidI64BadOpcode => 27
    InvalidImportedStartFuncF32Param => 28
    InvalidImportedStartFuncExternrefParam => 29
    MalformedInvalidF64BadOpcode => 30
    InvalidImportedStartFuncFuncrefParam => 31
    UnlinkableIncompatibleGlobalImportF64 => 32
    UnlinkableIncompatibleMemoryImportMax => 33
    InvalidStartFuncOutOfRange => 34
    UnlinkableIncompatibleMemoryImportMin => 35
    UnlinkableIncompatibleTableImportLimits => 36
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
    "smoke" => 37
    "ci" => 370
    "stress" => 3700
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
    MalformedTrailingGarbage =>
      (
        "inline-text-invalid/malformed-trailing-garbage.wast",
        "(assert_malformed (module quote \"(module garbage)\") \"unexpected token\")",
        MalformedTextAssertion,
      )
    InvalidMutableGlobalConstInit =>
      (
        "inline-text-invalid/invalid-mutable-global-const-init.wast",
        "(assert_invalid (module (import \"env\" \"g\" (global (mut i32))) (global i32 (global.get 0))) \"constant\")",
        InvalidTextAssertion,
      )
    UnlinkableUnknownMemoryImport =>
      (
        "inline-text-invalid/unlinkable-unknown-memory-import.wast",
        "(assert_unlinkable (module (import \"env\" \"mem\" (memory 1))) \"unknown import\")",
        UnlinkableTextAssertion,
      )
    MalformedInvalidConstToken =>
      (
        "inline-text-invalid/malformed-invalid-const-token.wast",
        "(assert_malformed (module quote \"(func (result f32) (f32.const nan:arithmetic))\") \"unexpected token\")",
        MalformedTextAssertion,
      )
    InvalidStartFuncParam =>
      (
        "inline-text-invalid/invalid-start-func-param.wast",
        "(assert_invalid (module (func (param i32)) (start 0)) \"start\")",
        InvalidTextAssertion,
      )
    UnlinkableUnknownGlobalImport =>
      (
        "inline-text-invalid/unlinkable-unknown-global-import.wast",
        "(assert_unlinkable (module (import \"env\" \"g\" (global i32))) \"unknown import\")",
        UnlinkableTextAssertion,
      )
    MalformedInvalidF64ConstToken =>
      (
        "inline-text-invalid/malformed-invalid-f64-const-token.wast",
        "(assert_malformed (module quote \"(func (result f64) (f64.const nan:canonical))\") \"unexpected token\")",
        MalformedTextAssertion,
      )
    InvalidDuplicateExportName =>
      (
        "inline-text-invalid/invalid-duplicate-export-name.wast",
        "(assert_invalid (module (func) (export \"dup\" (func 0)) (export \"dup\" (func 0))) \"duplicate export name\")",
        InvalidTextAssertion,
      )
    UnlinkableUnknownTableImport =>
      (
        "inline-text-invalid/unlinkable-unknown-table-import.wast",
        "(assert_unlinkable (module (import \"env\" \"t\" (table 1 funcref))) \"unknown import\")",
        UnlinkableTextAssertion,
      )
    MalformedInvalidI64ConstToken =>
      (
        "inline-text-invalid/malformed-invalid-i64-const-token.wast",
        "(assert_malformed (module quote \"(func (i64.const 1x) drop)\") \"unknown operator\")",
        MalformedTextAssertion,
      )
    InvalidStartFuncResult =>
      (
        "inline-text-invalid/invalid-start-func-result.wast",
        "(assert_invalid (module (func (result i32) (i32.const 0)) (start 0)) \"start\")",
        InvalidTextAssertion,
      )
    UnlinkableIncompatibleFuncImportType =>
      (
        "inline-text-invalid/unlinkable-incompatible-func-import-type.wast",
        "(assert_unlinkable (module (import \"test\" \"func\" (func (param i32)))) \"incompatible import type\")",
        UnlinkableTextAssertion,
      )
    MalformedInvalidI32HexToken =>
      (
        "inline-text-invalid/malformed-invalid-i32-hex-token.wast",
        "(assert_malformed (module quote \"(func (i32.const 0xg) drop)\") \"unknown operator\")",
        MalformedTextAssertion,
      )
    InvalidImportedStartFuncParam =>
      (
        "inline-text-invalid/invalid-imported-start-func-param.wast",
        "(assert_invalid (module (import \"m\" \"f\" (func (param i32))) (start 0)) \"start\")",
        InvalidTextAssertion,
      )
    UnlinkableIncompatibleGlobalImportType =>
      (
        "inline-text-invalid/unlinkable-incompatible-global-import-type.wast",
        "(assert_unlinkable (module (import \"test\" \"global-i32\" (global f32))) \"incompatible import type\")",
        UnlinkableTextAssertion,
      )
    MalformedInvalidI64HexToken =>
      (
        "inline-text-invalid/malformed-invalid-i64-hex-token.wast",
        "(assert_malformed (module quote \"(func (i64.const 0xg) drop)\") \"unknown operator\")",
        MalformedTextAssertion,
      )
    InvalidImportedStartFuncResult =>
      (
        "inline-text-invalid/invalid-imported-start-func-result.wast",
        "(assert_invalid (module (import \"m\" \"f\" (func (result i32))) (start 0)) \"start\")",
        InvalidTextAssertion,
      )
    UnlinkableIncompatibleTagImportType =>
      (
        "inline-text-invalid/unlinkable-incompatible-tag-import-type.wast",
        "(assert_unlinkable (module (tag (import \"test\" \"tag-i32\") (param f32))) \"incompatible import type\")",
        UnlinkableTextAssertion,
      )
    MalformedInvalidI32BadOpcode =>
      (
        "inline-text-invalid/malformed-invalid-i32-bad-opcode.wast",
        "(assert_malformed (module quote \"(func (i32.conzt 0) drop)\") \"unknown operator\")",
        MalformedTextAssertion,
      )
    InvalidImportedStartFuncParamResult =>
      (
        "inline-text-invalid/invalid-imported-start-func-param-result.wast",
        "(assert_invalid (module (import \"m\" \"f\" (func (param i32) (result i32))) (start 0)) \"start\")",
        InvalidTextAssertion,
      )
    UnlinkableIncompatibleGlobalImportMutability =>
      (
        "inline-text-invalid/unlinkable-incompatible-global-import-mutability.wast",
        "(assert_unlinkable (module (import \"test\" \"global-i32\" (global (mut i32)))) \"incompatible import type\")",
        UnlinkableTextAssertion,
      )
    MalformedInvalidF32BadOpcode =>
      (
        "inline-text-invalid/malformed-invalid-f32-bad-opcode.wast",
        "(assert_malformed (module quote \"(func (f32.conzt 0) drop)\") \"unknown operator\")",
        MalformedTextAssertion,
      )
    InvalidImportedStartFuncMultiParam =>
      (
        "inline-text-invalid/invalid-imported-start-func-multi-param.wast",
        "(assert_invalid (module (import \"m\" \"f\" (func (param i32 i32))) (start 0)) \"start\")",
        InvalidTextAssertion,
      )
    UnlinkableIncompatibleGlobalImportI64 =>
      (
        "inline-text-invalid/unlinkable-incompatible-global-import-i64.wast",
        "(assert_unlinkable (module (import \"test\" \"global-i32\" (global i64))) \"incompatible import type\")",
        UnlinkableTextAssertion,
      )
    MalformedInvalidI64BadOpcode =>
      (
        "inline-text-invalid/malformed-invalid-i64-bad-opcode.wast",
        "(assert_malformed (module quote \"(func (i64.conzt 0) drop)\") \"unknown operator\")",
        MalformedTextAssertion,
      )
    InvalidImportedStartFuncF32Param =>
      (
        "inline-text-invalid/invalid-imported-start-func-f32-param.wast",
        "(assert_invalid (module (import \"m\" \"f\" (func (param f32))) (start 0)) \"start\")",
        InvalidTextAssertion,
      )
    InvalidImportedStartFuncExternrefParam =>
      (
        "inline-text-invalid/invalid-imported-start-func-externref-param.wast",
        "(assert_invalid (module (import \"m\" \"f\" (func (param externref))) (start 0)) \"start\")",
        InvalidTextAssertion,
      )
    MalformedInvalidF64BadOpcode =>
      (
        "inline-text-invalid/malformed-invalid-f64-bad-opcode.wast",
        "(assert_malformed (module quote \"(func (f64.conzt 0) drop)\") \"unknown operator\")",
        MalformedTextAssertion,
      )
    InvalidImportedStartFuncFuncrefParam =>
      (
        "inline-text-invalid/invalid-imported-start-func-funcref-param.wast",
        "(assert_invalid (module (import \"m\" \"f\" (func (param funcref))) (start 0)) \"start\")",
        InvalidTextAssertion,
      )
    UnlinkableIncompatibleGlobalImportF64 =>
      (
        "inline-text-invalid/unlinkable-incompatible-global-import-f64.wast",
        "(assert_unlinkable (module (import \"test\" \"global-i32\" (global f64))) \"incompatible import type\")",
        UnlinkableTextAssertion,
      )
    UnlinkableIncompatibleMemoryImportMax =>
      (
        "inline-text-invalid/unlinkable-incompatible-memory-import-max.wast",
        "(assert_unlinkable (module (import \"test-memory-2-4\" \"memory-2-4\" (memory 2 5))) \"incompatible import type\")",
        UnlinkableTextAssertion,
      )
    InvalidStartFuncOutOfRange =>
      (
        "inline-text-invalid/invalid-start-func-out-of-range.wast",
        "(assert_invalid (module (func) (start 1)) \"start\")",
        InvalidTextAssertion,
      )
    UnlinkableIncompatibleMemoryImportMin =>
      (
        "inline-text-invalid/unlinkable-incompatible-memory-import-min.wast",
        "(assert_unlinkable (module (import \"test-memory-2-inf\" \"memory-2-inf\" (memory 3))) \"incompatible import type\")",
        UnlinkableTextAssertion,
      )
    UnlinkableIncompatibleTableImportLimits =>
      (
        "inline-text-invalid/unlinkable-incompatible-table-import-limits.wast",
        "(assert_unlinkable (module (import \"test-table-10-inf\" \"table-10-inf\" (table 11 funcref))) \"incompatible import type\")",
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
  ConstMalformedQuote2
  F32InvalidTypeMismatch2
  ImportsUnlinkableUnknownImport2
  ConstMalformedQuote3
  F32InvalidTypeMismatch3
  ImportsUnlinkableIncompatibleImportType1
  ConstMalformedQuote4
  F32InvalidTypeMismatch4
  ImportsUnlinkableIncompatibleImportType2
  ConstMalformedQuote5
  F32InvalidTypeMismatch5
  ImportsUnlinkableIncompatibleImportType3
  ConstMalformedQuote6
  F32InvalidTypeMismatch6
  ImportsUnlinkableIncompatibleImportType4
  ConstMalformedQuote7
  F32InvalidTypeMismatch7
  ImportsUnlinkableIncompatibleImportType5
  ConstMalformedQuote8
  F32InvalidTypeMismatch8
  ImportsUnlinkableIncompatibleImportType6
  ConstMalformedQuote9
  F32InvalidTypeMismatch9
  ImportsUnlinkableIncompatibleImportType7
  ConstMalformedQuote10
  F32InvalidTypeMismatch10
  ImportsUnlinkableIncompatibleImportType8
  ConstMalformedQuote11
  F32InvalidTypeMismatch11
  ImportsUnlinkableIncompatibleImportType9
  ConstMalformedQuote12
  StoreInvalidTypeMismatch1
  ImportsUnlinkableIncompatibleImportType10
  ConstMalformedQuote13
  StoreInvalidTypeMismatch2
  ImportsUnlinkableIncompatibleImportType11
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
    validate_invalid_spec_seed_spec(
      ConstMalformedQuote2,
      "const-malformed-quote-2",
      "tests/spec const.wast second malformed quote assertion",
      "tests/spec/const.wast",
      MalformedTextAssertion,
      1,
      ParseOrLowerRejectedStage,
    ),
    validate_invalid_spec_seed_spec(
      F32InvalidTypeMismatch2,
      "f32-invalid-type-mismatch-2",
      "tests/spec f32.wast second invalid type-mismatch assertion",
      "tests/spec/f32.wast",
      InvalidTextAssertion,
      1,
      ValidateRejectedStage,
    ),
    validate_invalid_spec_seed_spec(
      ImportsUnlinkableUnknownImport2,
      "imports-unlinkable-unknown-import-2",
      "tests/spec imports.wast second unlinkable unknown-import assertion",
      "tests/spec/imports.wast",
      UnlinkableTextAssertion,
      1,
      ValidBeforeLinkStage,
    ),
    validate_invalid_spec_seed_spec(
      ConstMalformedQuote3,
      "const-malformed-quote-3",
      "tests/spec const.wast third malformed quote assertion",
      "tests/spec/const.wast",
      MalformedTextAssertion,
      2,
      ParseOrLowerRejectedStage,
    ),
    validate_invalid_spec_seed_spec(
      F32InvalidTypeMismatch3,
      "f32-invalid-type-mismatch-3",
      "tests/spec f32.wast third invalid type-mismatch assertion",
      "tests/spec/f32.wast",
      InvalidTextAssertion,
      2,
      ValidateRejectedStage,
    ),
    validate_invalid_spec_seed_spec(
      ImportsUnlinkableIncompatibleImportType1,
      "imports-unlinkable-incompatible-import-type-1",
      "tests/spec imports.wast first unlinkable incompatible-import-type assertion",
      "tests/spec/imports.wast",
      UnlinkableTextAssertion,
      2,
      ValidBeforeLinkStage,
    ),
    validate_invalid_spec_seed_spec(
      ConstMalformedQuote4,
      "const-malformed-quote-4",
      "tests/spec const.wast fourth malformed quote assertion",
      "tests/spec/const.wast",
      MalformedTextAssertion,
      3,
      ParseOrLowerRejectedStage,
    ),
    validate_invalid_spec_seed_spec(
      F32InvalidTypeMismatch4,
      "f32-invalid-type-mismatch-4",
      "tests/spec f32.wast fourth invalid type-mismatch assertion",
      "tests/spec/f32.wast",
      InvalidTextAssertion,
      3,
      ValidateRejectedStage,
    ),
    validate_invalid_spec_seed_spec(
      ImportsUnlinkableIncompatibleImportType2,
      "imports-unlinkable-incompatible-import-type-2",
      "tests/spec imports.wast second unlinkable incompatible-import-type assertion",
      "tests/spec/imports.wast",
      UnlinkableTextAssertion,
      3,
      ValidBeforeLinkStage,
    ),
    validate_invalid_spec_seed_spec(
      ConstMalformedQuote5,
      "const-malformed-quote-5",
      "tests/spec const.wast fifth malformed quote assertion",
      "tests/spec/const.wast",
      MalformedTextAssertion,
      4,
      ParseOrLowerRejectedStage,
    ),
    validate_invalid_spec_seed_spec(
      F32InvalidTypeMismatch5,
      "f32-invalid-type-mismatch-5",
      "tests/spec f32.wast fifth invalid type-mismatch assertion",
      "tests/spec/f32.wast",
      InvalidTextAssertion,
      4,
      ValidateRejectedStage,
    ),
    validate_invalid_spec_seed_spec(
      ImportsUnlinkableIncompatibleImportType3,
      "imports-unlinkable-incompatible-import-type-3",
      "tests/spec imports.wast third unlinkable incompatible-import-type assertion",
      "tests/spec/imports.wast",
      UnlinkableTextAssertion,
      4,
      ValidBeforeLinkStage,
    ),
    validate_invalid_spec_seed_spec(
      ConstMalformedQuote6,
      "const-malformed-quote-6",
      "tests/spec const.wast sixth malformed quote assertion",
      "tests/spec/const.wast",
      MalformedTextAssertion,
      5,
      ParseOrLowerRejectedStage,
    ),
    validate_invalid_spec_seed_spec(
      F32InvalidTypeMismatch6,
      "f32-invalid-type-mismatch-6",
      "tests/spec f32.wast sixth invalid type-mismatch assertion",
      "tests/spec/f32.wast",
      InvalidTextAssertion,
      5,
      ValidateRejectedStage,
    ),
    validate_invalid_spec_seed_spec(
      ImportsUnlinkableIncompatibleImportType4,
      "imports-unlinkable-incompatible-import-type-4",
      "tests/spec imports.wast fourth unlinkable incompatible-import-type assertion",
      "tests/spec/imports.wast",
      UnlinkableTextAssertion,
      5,
      ValidBeforeLinkStage,
    ),
    validate_invalid_spec_seed_spec(
      ConstMalformedQuote7,
      "const-malformed-quote-7",
      "tests/spec const.wast seventh malformed quote assertion",
      "tests/spec/const.wast",
      MalformedTextAssertion,
      6,
      ParseOrLowerRejectedStage,
    ),
    validate_invalid_spec_seed_spec(
      F32InvalidTypeMismatch7,
      "f32-invalid-type-mismatch-7",
      "tests/spec f32.wast seventh invalid type-mismatch assertion",
      "tests/spec/f32.wast",
      InvalidTextAssertion,
      6,
      ValidateRejectedStage,
    ),
    validate_invalid_spec_seed_spec(
      ImportsUnlinkableIncompatibleImportType5,
      "imports-unlinkable-incompatible-import-type-5",
      "tests/spec imports.wast fifth unlinkable incompatible-import-type assertion",
      "tests/spec/imports.wast",
      UnlinkableTextAssertion,
      6,
      ValidBeforeLinkStage,
    ),
    validate_invalid_spec_seed_spec(
      ConstMalformedQuote8,
      "const-malformed-quote-8",
      "tests/spec const.wast eighth malformed quote assertion",
      "tests/spec/const.wast",
      MalformedTextAssertion,
      7,
      ParseOrLowerRejectedStage,
    ),
    validate_invalid_spec_seed_spec(
      F32InvalidTypeMismatch8,
      "f32-invalid-type-mismatch-8",
      "tests/spec f32.wast eighth invalid type-mismatch assertion",
      "tests/spec/f32.wast",
      InvalidTextAssertion,
      7,
      ValidateRejectedStage,
    ),
    validate_invalid_spec_seed_spec(
      ImportsUnlinkableIncompatibleImportType6,
      "imports-unlinkable-incompatible-import-type-6",
      "tests/spec imports.wast sixth unlinkable incompatible-import-type assertion",
      "tests/spec/imports.wast",
      UnlinkableTextAssertion,
      7,
      ValidBeforeLinkStage,
    ),
    validate_invalid_spec_seed_spec(
      ConstMalformedQuote9,
      "const-malformed-quote-9",
      "tests/spec const.wast ninth malformed quote assertion",
      "tests/spec/const.wast",
      MalformedTextAssertion,
      8,
      ParseOrLowerRejectedStage,
    ),
    validate_invalid_spec_seed_spec(
      F32InvalidTypeMismatch9,
      "f32-invalid-type-mismatch-9",
      "tests/spec f32.wast ninth invalid type-mismatch assertion",
      "tests/spec/f32.wast",
      InvalidTextAssertion,
      8,
      ValidateRejectedStage,
    ),
    validate_invalid_spec_seed_spec(
      ImportsUnlinkableIncompatibleImportType7,
      "imports-unlinkable-incompatible-import-type-7",
      "tests/spec imports.wast seventh unlinkable incompatible-import-type assertion",
      "tests/spec/imports.wast",
      UnlinkableTextAssertion,
      8,
      ValidBeforeLinkStage,
    ),
    validate_invalid_spec_seed_spec(
      ConstMalformedQuote10,
      "const-malformed-quote-10",
      "tests/spec const.wast tenth malformed quote assertion",
      "tests/spec/const.wast",
      MalformedTextAssertion,
      9,
      ParseOrLowerRejectedStage,
    ),
    validate_invalid_spec_seed_spec(
      F32InvalidTypeMismatch10,
      "f32-invalid-type-mismatch-10",
      "tests/spec f32.wast tenth invalid type-mismatch assertion",
      "tests/spec/f32.wast",
      InvalidTextAssertion,
      9,
      ValidateRejectedStage,
    ),
    validate_invalid_spec_seed_spec(
      ImportsUnlinkableIncompatibleImportType8,
      "imports-unlinkable-incompatible-import-type-8",
      "tests/spec imports.wast eighth unlinkable incompatible-import-type assertion",
      "tests/spec/imports.wast",
      UnlinkableTextAssertion,
      9,
      ValidBeforeLinkStage,
    ),
    validate_invalid_spec_seed_spec(
      ConstMalformedQuote11,
      "const-malformed-quote-11",
      "tests/spec const.wast eleventh malformed quote assertion",
      "tests/spec/const.wast",
      MalformedTextAssertion,
      10,
      ParseOrLowerRejectedStage,
    ),
    validate_invalid_spec_seed_spec(
      F32InvalidTypeMismatch11,
      "f32-invalid-type-mismatch-11",
      "tests/spec f32.wast eleventh invalid type-mismatch assertion",
      "tests/spec/f32.wast",
      InvalidTextAssertion,
      10,
      ValidateRejectedStage,
    ),
    validate_invalid_spec_seed_spec(
      ImportsUnlinkableIncompatibleImportType9,
      "imports-unlinkable-incompatible-import-type-9",
      "tests/spec imports.wast ninth unlinkable incompatible-import-type assertion",
      "tests/spec/imports.wast",
      UnlinkableTextAssertion,
      10,
      ValidBeforeLinkStage,
    ),
    validate_invalid_spec_seed_spec(
      ConstMalformedQuote12,
      "const-malformed-quote-12",
      "tests/spec const.wast twelfth malformed quote assertion",
      "tests/spec/const.wast",
      MalformedTextAssertion,
      11,
      ParseOrLowerRejectedStage,
    ),
    validate_invalid_spec_seed_spec(
      StoreInvalidTypeMismatch1,
      "store-invalid-type-mismatch-1",
      "tests/spec store.wast first invalid type-mismatch assertion",
      "tests/spec/store.wast",
      InvalidTextAssertion,
      0,
      ValidateRejectedStage,
    ),
    validate_invalid_spec_seed_spec(
      ImportsUnlinkableIncompatibleImportType10,
      "imports-unlinkable-incompatible-import-type-10",
      "tests/spec imports.wast tenth unlinkable incompatible-import-type assertion",
      "tests/spec/imports.wast",
      UnlinkableTextAssertion,
      11,
      ValidBeforeLinkStage,
    ),
    validate_invalid_spec_seed_spec(
      ConstMalformedQuote13,
      "const-malformed-quote-13",
      "tests/spec const.wast thirteenth malformed quote assertion",
      "tests/spec/const.wast",
      MalformedTextAssertion,
      12,
      ParseOrLowerRejectedStage,
    ),
    validate_invalid_spec_seed_spec(
      StoreInvalidTypeMismatch2,
      "store-invalid-type-mismatch-2",
      "tests/spec store.wast second invalid type-mismatch assertion",
      "tests/spec/store.wast",
      InvalidTextAssertion,
      1,
      ValidateRejectedStage,
    ),
    validate_invalid_spec_seed_spec(
      ImportsUnlinkableIncompatibleImportType11,
      "imports-unlinkable-incompatible-import-type-11",
      "tests/spec imports.wast eleventh unlinkable incompatible-import-type assertion",
      "tests/spec/imports.wast",
      UnlinkableTextAssertion,
      12,
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
    ConstMalformedQuote2 => 3
    F32InvalidTypeMismatch2 => 4
    ImportsUnlinkableUnknownImport2 => 5
    ConstMalformedQuote3 => 6
    F32InvalidTypeMismatch3 => 7
    ImportsUnlinkableIncompatibleImportType1 => 8
    ConstMalformedQuote4 => 9
    F32InvalidTypeMismatch4 => 10
    ImportsUnlinkableIncompatibleImportType2 => 11
    ConstMalformedQuote5 => 12
    F32InvalidTypeMismatch5 => 13
    ImportsUnlinkableIncompatibleImportType3 => 14
    ConstMalformedQuote6 => 15
    F32InvalidTypeMismatch6 => 16
    ImportsUnlinkableIncompatibleImportType4 => 17
    ConstMalformedQuote7 => 18
    F32InvalidTypeMismatch7 => 19
    ImportsUnlinkableIncompatibleImportType5 => 20
    ConstMalformedQuote8 => 21
    F32InvalidTypeMismatch8 => 22
    ImportsUnlinkableIncompatibleImportType6 => 23
    ConstMalformedQuote9 => 24
    F32InvalidTypeMismatch9 => 25
    ImportsUnlinkableIncompatibleImportType7 => 26
    ConstMalformedQuote10 => 27
    F32InvalidTypeMismatch10 => 28
    ImportsUnlinkableIncompatibleImportType8 => 29
    ConstMalformedQuote11 => 30
    F32InvalidTypeMismatch11 => 31
    ImportsUnlinkableIncompatibleImportType9 => 32
    ConstMalformedQuote12 => 33
    StoreInvalidTypeMismatch1 => 34
    ImportsUnlinkableIncompatibleImportType10 => 35
    ConstMalformedQuote13 => 36
    StoreInvalidTypeMismatch2 => 37
    ImportsUnlinkableIncompatibleImportType11 => 38
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
    "smoke" => 39
    "ci" => 390
    "stress" => 3900
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
