///|
pub enum InvalidFuzzSourceKind {
  AstInvalidSource
  BinaryInvalidSource
  TextInvalidSource
  SpecSeedInvalidSource
} derive(Eq, Debug)

///|
pub fn invalid_fuzz_source_kind_name(kind : InvalidFuzzSourceKind) -> String {
  match kind {
    AstInvalidSource => "ast"
    BinaryInvalidSource => "binary"
    TextInvalidSource => "text"
    SpecSeedInvalidSource => "spec-seed"
  }
}

///|
pub fn invalid_fuzz_ast_source_kind() -> InvalidFuzzSourceKind {
  AstInvalidSource
}

///|
pub fn invalid_fuzz_binary_source_kind() -> InvalidFuzzSourceKind {
  BinaryInvalidSource
}

///|
pub fn invalid_fuzz_text_source_kind() -> InvalidFuzzSourceKind {
  TextInvalidSource
}

///|
pub fn invalid_fuzz_spec_seed_source_kind() -> InvalidFuzzSourceKind {
  SpecSeedInvalidSource
}

///|
pub fn build_fuz1026_two_fault_ast_stress_report(
  seed : UInt64,
  attempt : Int,
) -> InvalidFuzzFailureReport {
  InvalidFuzzFailureReport::new(
    "validate-invalid-ast-multifault",
    "stress",
    seed,
    attempt,
    "two-fault-ast-invalid-stress",
    invalid_fuzz_ast_source_kind(),
    "validate-rejected",
    actual_stage="validate-rejected",
    actual_diagnostic_family=Some("function-body"),
    source_feature_facts=["multi_fault:true"],
    multi_fault_mutation_ids=[
      "invalid-function-body-local-set-value-type", "invalid-function-body-branch-payload-type",
    ],
    multi_fault_broad_outcomes=["validate-rejected"],
    artifacts=[
      InvalidFuzzArtifact::new(
        "stress-summary",
        "two-fault-ast-invalid-stress.txt",
        invalid_fuzz_string_bytes(
          "multi_fault=true\nmutation=invalid-function-body-local-set-value-type\nmutation=invalid-function-body-branch-payload-type\nbroad_outcome=validate-rejected\n",
        ),
      ),
    ],
  )
}

///|
pub fn build_fuz1026_binary_text_multifault_stress_report(
  seed : UInt64,
  attempt : Int,
) -> InvalidFuzzFailureReport {
  InvalidFuzzFailureReport::new(
    "validate-invalid-binary-text-multifault",
    "stress",
    seed,
    attempt,
    "binary-text-multifault-invalid-stress",
    invalid_fuzz_binary_source_kind(),
    "decode-or-parse-rejected",
    actual_stage="decode-or-parse-rejected",
    source_feature_facts=["multi_fault:true"],
    multi_fault_mutation_ids=[
      "binary:trailing-garbage", "text:malformed-trailing-garbage",
    ],
    multi_fault_broad_outcomes=["decode-or-parse-rejected"],
    artifacts=[
      InvalidFuzzArtifact::new(
        "stress-summary",
        "binary-text-multifault-invalid-stress.txt",
        invalid_fuzz_string_bytes(
          "multi_fault=true\nmutation=binary:trailing-garbage\nmutation=text:malformed-trailing-garbage\nbroad_outcome=decode-or-parse-rejected\n",
        ),
      ),
    ],
  )
}

///|
fn fuz1055b4_unlinkable_metadata(
  seed : UInt64,
) -> (String, String, String, String, String) {
  match (seed % 10UL).to_int() {
    0 =>
      (
        "unknown import", "missing_f", "func()", "missing export", "func(result i32)",
      )
    1 =>
      (
        "unknown import", "missing_mem", "memory(1)", "missing export", "memory(1)",
      )
    2 =>
      (
        "unknown import", "missing_tab", "table(1 funcref)", "missing export", "table(1 funcref)",
      )
    3 =>
      (
        "unknown import", "missing_g", "global(i32)", "missing export", "global(i32)",
      )
    4 =>
      (
        "unknown import", "missing_tag", "tag(param i32)", "missing export", "tag(param i32)",
      )
    5 =>
      (
        "incompatible import type", "f", "func(param i32)", "func(result i32)", "func(result i32)",
      )
    6 =>
      (
        "incompatible import type", "mem", "memory(2 5)", "memory(1)", "memory(1)",
      )
    7 =>
      (
        "incompatible import type", "tab", "table(11 funcref)", "table(1 funcref)",
        "table(1 funcref)",
      )
    8 =>
      (
        "incompatible import type", "g", "global(f64)", "global(i32)", "global(i32)",
      )
    _ =>
      (
        "incompatible import type", "tag", "tag(param f32)", "tag(param i32)", "tag(param i32)",
      )
  }
}

///|
pub fn build_fuz1055b4_unlinkable_failure_report(
  seed : UInt64,
  attempt : Int,
) -> InvalidFuzzFailureReport {
  let case = gen_unlinkable_multi_module_wast_case(seed)
  let (
    reason,
    import_name,
    expected_import_type,
    provider_export_type,
    feature_type,
  ) = fuz1055b4_unlinkable_metadata(seed)
  InvalidFuzzFailureReport::new(
    "valid-multi-module-linking",
    "smoke",
    seed,
    attempt,
    "unlinkable-multi-module",
    invalid_fuzz_text_source_kind(),
    "valid-before-link",
    actual_stage="valid-before-link",
    source_path=Some(case.name + ".wast"),
    valid_before_link=Some(true),
    unlinkable_reason=Some(reason),
    registered_module_name=Some("provider"),
    import_module_name=Some("provider"),
    import_name=Some(import_name),
    expected_import_type=Some(expected_import_type),
    provider_export_type=Some(provider_export_type),
    pre_link_validation_status=Some("valid-before-link"),
    source_feature_facts=case.feature_facts +
      ["unlinkable-type:" + feature_type],
    artifacts=[
      InvalidFuzzArtifact::new(
        "unlinkable-wast",
        case.name + ".wast",
        invalid_fuzz_string_bytes(case.text),
      ),
    ],
  )
}

///|
pub enum FuzzReductionFailureKind {
  ValidationFailure
  ParseFailure
  PassMismatch
  Crash
  Timeout
  PropertyFailure
} derive(Eq, Debug)

///|
pub fn fuzz_reduction_validation_failure_kind() -> FuzzReductionFailureKind {
  ValidationFailure
}

///|
pub fn fuzz_reduction_parse_failure_kind() -> FuzzReductionFailureKind {
  ParseFailure
}

///|
pub fn fuzz_reduction_pass_mismatch_kind() -> FuzzReductionFailureKind {
  PassMismatch
}

///|
pub fn fuzz_reduction_crash_kind() -> FuzzReductionFailureKind {
  Crash
}

///|
pub fn fuzz_reduction_timeout_kind() -> FuzzReductionFailureKind {
  Timeout
}

///|
pub fn fuzz_reduction_property_failure_kind() -> FuzzReductionFailureKind {
  PropertyFailure
}

///|
pub fn fuzz_reduction_failure_kind_name(
  kind : FuzzReductionFailureKind,
) -> String {
  match kind {
    ValidationFailure => "validation-failure"
    ParseFailure => "parse-failure"
    PassMismatch => "pass-mismatch"
    Crash => "crash"
    Timeout => "timeout"
    PropertyFailure => "property-failure"
  }
}

///|
pub struct FuzzReductionPredicate {
  kind : FuzzReductionFailureKind
  expected_stage : String
  expected_family : String?
  property : String?
} derive(Eq, Debug)

///|
pub fn FuzzReductionPredicate::new(
  kind : FuzzReductionFailureKind,
  expected_stage : String,
  expected_family? : String? = None,
  property? : String? = None,
) -> FuzzReductionPredicate {
  { kind, expected_stage, expected_family, property }
}

///|
pub struct FuzzReductionReplayResult {
  stage : String
  family : String?
  property : String?
  message : String?
} derive(Eq, Debug)

///|
pub fn FuzzReductionReplayResult::new(
  stage : String,
  family? : String? = None,
  property? : String? = None,
  message? : String? = None,
) -> FuzzReductionReplayResult {
  { stage, family, property, message }
}

///|
pub fn fuzz_reduction_predicate_matches(
  predicate : FuzzReductionPredicate,
  replay : FuzzReductionReplayResult,
) -> Bool {
  if replay.stage != predicate.expected_stage {
    return false
  }
  match predicate.expected_family {
    Some(expected) => if replay.family != Some(expected) { return false }
    None => ()
  }
  match predicate.property {
    Some(expected) => if replay.property != Some(expected) { return false }
    None => ()
  }
  true
}

///|
pub fn invalid_fuzz_replay_result_as_reduction_result(
  replay : InvalidFuzzReplayResult,
) -> FuzzReductionReplayResult {
  FuzzReductionReplayResult::new(
    replay.stage,
    family=replay.diagnostic_family,
    message=replay.message,
  )
}

///|
pub fn fuzz_reduction_predicate_from_invalid_report(
  report : InvalidFuzzFailureReport,
) -> FuzzReductionPredicate {
  let kind = match report.actual_stage {
    "parse-or-lower-rejected" | "decode-rejected" =>
      FuzzReductionFailureKind::ParseFailure
    "valid-before-link" => FuzzReductionFailureKind::PropertyFailure
    _ => FuzzReductionFailureKind::ValidationFailure
  }
  FuzzReductionPredicate::new(
    kind,
    report.actual_stage,
    expected_family=report.actual_diagnostic_family,
  )
}

///|
pub fn invalid_fuzz_suite_name_for_source_kind(
  kind : InvalidFuzzSourceKind,
) -> String {
  match kind {
    AstInvalidSource => "validate-invalid-ast"
    BinaryInvalidSource => "validate-invalid-binary"
    TextInvalidSource => "validate-invalid-text"
    SpecSeedInvalidSource => "validate-invalid-spec-seed"
  }
}

///|
fn invalid_fuzz_source_kind_from_name(name : String) -> InvalidFuzzSourceKind? {
  match name {
    "ast" => Some(AstInvalidSource)
    "validate-invalid-ast" => Some(AstInvalidSource)
    "binary" => Some(BinaryInvalidSource)
    "validate-invalid-binary" => Some(BinaryInvalidSource)
    "text" => Some(TextInvalidSource)
    "validate-invalid-text" => Some(TextInvalidSource)
    "spec-seed" => Some(SpecSeedInvalidSource)
    "validate-invalid-spec-seed" => Some(SpecSeedInvalidSource)
    _ => None
  }
}

///|
pub struct InvalidFuzzArtifact {
  label : String
  file_name : String
  bytes : Bytes
} derive(Eq, Debug)

///|
pub fn InvalidFuzzArtifact::new(
  label : String,
  file_name : String,
  bytes : Bytes,
) -> InvalidFuzzArtifact {
  { label, file_name, bytes }
}

///|
pub struct InvalidFuzzReductionStep {
  kind : String
  start : Int
  len : Int
  before_size : Int
  after_size : Int
} derive(Eq, Debug)

///|
pub fn InvalidFuzzReductionStep::new(
  kind : String,
  start : Int,
  len : Int,
  before_size : Int,
  after_size : Int,
) -> InvalidFuzzReductionStep {
  { kind, start, len, before_size, after_size }
}

///|
pub struct InvalidFuzzFailureReport {
  suite : String
  profile : String
  seed : UInt64
  attempt : Int
  strategy_id : String
  source_kind : InvalidFuzzSourceKind
  expected_stage : String
  expected_diagnostic_family : String?
  actual_stage : String
  actual_diagnostic_family : String?
  actual_diagnostic_location : String?
  timeout_budget_ms : Int?
  seed_profile : String?
  seed_mode : String?
  seed_require_strategy_prereqs : Bool?
  stream_label : String?
  stream_seed : UInt64?
  attempt_seed : UInt64?
  source_path : String?
  valid_before_link : Bool?
  unlinkable_reason : String?
  registered_module_name : String?
  import_module_name : String?
  import_name : String?
  expected_import_type : String?
  provider_export_type : String?
  pre_link_validation_status : String?
  source_feature_facts : Array[String]
  multi_fault_mutation_ids : Array[String]
  multi_fault_broad_outcomes : Array[String]
  artifacts : Array[InvalidFuzzArtifact]
  reduced_artifacts : Array[InvalidFuzzArtifact]
  reduction_original_size : Int?
  reduction_final_size : Int?
  reduction_predicate_evaluations : Int?
  reduction_steps : Array[InvalidFuzzReductionStep]
} derive(Eq, Debug)

///|
pub fn InvalidFuzzFailureReport::new(
  suite : String,
  profile : String,
  seed : UInt64,
  attempt : Int,
  strategy_id : String,
  source_kind : InvalidFuzzSourceKind,
  expected_stage : String,
  expected_diagnostic_family? : String? = None,
  actual_stage? : String = expected_stage,
  actual_diagnostic_family? : String? = expected_diagnostic_family,
  actual_diagnostic_location? : String? = None,
  timeout_budget_ms? : Int? = None,
  seed_profile? : String? = None,
  seed_mode? : String? = None,
  seed_require_strategy_prereqs? : Bool? = None,
  stream_label? : String? = None,
  stream_seed? : UInt64? = None,
  attempt_seed? : UInt64? = None,
  source_path? : String? = None,
  valid_before_link? : Bool? = None,
  unlinkable_reason? : String? = None,
  registered_module_name? : String? = None,
  import_module_name? : String? = None,
  import_name? : String? = None,
  expected_import_type? : String? = None,
  provider_export_type? : String? = None,
  pre_link_validation_status? : String? = None,
  source_feature_facts? : Array[String] = [],
  multi_fault_mutation_ids? : Array[String] = [],
  multi_fault_broad_outcomes? : Array[String] = [],
  artifacts? : Array[InvalidFuzzArtifact] = [],
  reduced_artifacts? : Array[InvalidFuzzArtifact] = [],
  reduction_original_size? : Int? = None,
  reduction_final_size? : Int? = None,
  reduction_predicate_evaluations? : Int? = None,
  reduction_steps? : Array[InvalidFuzzReductionStep] = [],
) -> InvalidFuzzFailureReport {
  {
    suite,
    profile,
    seed,
    attempt,
    strategy_id,
    source_kind,
    expected_stage,
    expected_diagnostic_family,
    actual_stage,
    actual_diagnostic_family,
    actual_diagnostic_location,
    timeout_budget_ms,
    seed_profile,
    seed_mode,
    seed_require_strategy_prereqs,
    stream_label,
    stream_seed,
    attempt_seed,
    source_path,
    valid_before_link,
    unlinkable_reason,
    registered_module_name,
    import_module_name,
    import_name,
    expected_import_type,
    provider_export_type,
    pre_link_validation_status,
    source_feature_facts,
    multi_fault_mutation_ids,
    multi_fault_broad_outcomes,
    artifacts,
    reduced_artifacts,
    reduction_original_size,
    reduction_final_size,
    reduction_predicate_evaluations,
    reduction_steps,
  }
}

///|
fn invalid_fuzz_failure_report_copy(
  report : InvalidFuzzFailureReport,
  source_path? : String? = report.source_path,
  reduced_artifacts? : Array[InvalidFuzzArtifact] = report.reduced_artifacts,
  reduction_original_size? : Int? = report.reduction_original_size,
  reduction_final_size? : Int? = report.reduction_final_size,
  reduction_predicate_evaluations? : Int? = report.reduction_predicate_evaluations,
  reduction_steps? : Array[InvalidFuzzReductionStep] = report.reduction_steps,
) -> InvalidFuzzFailureReport {
  InvalidFuzzFailureReport::new(
    report.suite,
    report.profile,
    report.seed,
    report.attempt,
    report.strategy_id,
    report.source_kind,
    report.expected_stage,
    expected_diagnostic_family=report.expected_diagnostic_family,
    actual_stage=report.actual_stage,
    actual_diagnostic_family=report.actual_diagnostic_family,
    actual_diagnostic_location=report.actual_diagnostic_location,
    timeout_budget_ms=report.timeout_budget_ms,
    seed_profile=report.seed_profile,
    seed_mode=report.seed_mode,
    seed_require_strategy_prereqs=report.seed_require_strategy_prereqs,
    stream_label=report.stream_label,
    stream_seed=report.stream_seed,
    attempt_seed=report.attempt_seed,
    source_path~,
    valid_before_link=report.valid_before_link,
    unlinkable_reason=report.unlinkable_reason,
    registered_module_name=report.registered_module_name,
    import_module_name=report.import_module_name,
    import_name=report.import_name,
    expected_import_type=report.expected_import_type,
    provider_export_type=report.provider_export_type,
    pre_link_validation_status=report.pre_link_validation_status,
    source_feature_facts=report.source_feature_facts,
    multi_fault_mutation_ids=report.multi_fault_mutation_ids,
    multi_fault_broad_outcomes=report.multi_fault_broad_outcomes,
    artifacts=report.artifacts,
    reduced_artifacts~,
    reduction_original_size~,
    reduction_final_size~,
    reduction_predicate_evaluations~,
    reduction_steps~,
  )
}

///|
pub struct InvalidFuzzReplayResult {
  stage : String
  diagnostic_family : String?
  diagnostic_location : String?
  message : String?
} derive(Eq, Debug)

///|
pub fn InvalidFuzzReplayResult::new(
  stage : String,
  diagnostic_family? : String? = None,
  diagnostic_location? : String? = None,
  message? : String? = None,
) -> InvalidFuzzReplayResult {
  { stage, diagnostic_family, diagnostic_location, message }
}

///|
pub struct InvalidFuzzPersistIO {
  ensure_dir : (String) -> Result[Unit, String]
  write_file : (String, Bytes) -> Result[Unit, String]
}

///|
pub fn InvalidFuzzPersistIO::new(
  ensure_dir? : (String) -> Result[Unit, String] = fn(path) {
    Err("ensure_dir not configured: \{path}")
  },
  write_file? : (String, Bytes) -> Result[Unit, String] = fn(path, _) {
    Err("write_file not configured: \{path}")
  },
) -> InvalidFuzzPersistIO {
  { ensure_dir, write_file }
}

///|
fn invalid_fuzz_family_label(
  family : @validate.ValidationIssueFamily,
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
fn invalid_fuzz_string_bytes(text : String) -> Bytes {
  let out : Array[Byte] = []
  for c in text {
    let code = c.to_int()
    if code >= 0 && code <= 255 {
      out.push(code.to_byte())
    } else {
      out.push('?'.to_int().to_byte())
    }
  }
  Bytes::from_array(out)
}

///|
fn invalid_fuzz_bytes_string(bytes : Bytes) -> Result[String, String] {
  let out = StringBuilder::new()
  for byte in bytes {
    out.write_char(byte.to_int().unsafe_to_char())
  }
  Ok(out.to_string())
}

///|
fn invalid_fuzz_join(values : Array[String], sep : String) -> String {
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
fn invalid_fuzz_ascii_lower(input : String) -> String {
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
fn invalid_fuzz_artifact_meta_lines(
  prefix : String,
  artifacts : Array[InvalidFuzzArtifact],
) -> Array[String] {
  let lines : Array[String] = []
  for artifact in artifacts {
    lines.push(prefix + "=" + artifact.label + "|" + artifact.file_name)
  }
  lines
}

///|
fn invalid_fuzz_reduction_step_text(step : InvalidFuzzReductionStep) -> String {
  step.kind +
  "|" +
  step.start.to_string() +
  "|" +
  step.len.to_string() +
  "|" +
  step.before_size.to_string() +
  "|" +
  step.after_size.to_string()
}

///|
fn invalid_fuzz_reduction_has_log(report : InvalidFuzzFailureReport) -> Bool {
  report.reduction_steps.length() > 0 ||
  report.reduction_original_size != None ||
  report.reduction_final_size != None ||
  report.reduction_predicate_evaluations != None
}

///|
fn invalid_fuzz_reduction_log_text(report : InvalidFuzzFailureReport) -> String {
  let out = StringBuilder::new()
  match report.reduction_original_size {
    Some(v) => out.write_string("original_size=" + v.to_string() + "\n")
    None => out.write_string("original_size=\n")
  }
  match report.reduction_final_size {
    Some(v) => out.write_string("final_size=" + v.to_string() + "\n")
    None => out.write_string("final_size=\n")
  }
  match report.reduction_predicate_evaluations {
    Some(v) => out.write_string("predicate_evaluations=" + v.to_string() + "\n")
    None => out.write_string("predicate_evaluations=\n")
  }
  for step in report.reduction_steps {
    out.write_string("step=" + invalid_fuzz_reduction_step_text(step) + "\n")
  }
  out.to_string()
}

///|
fn invalid_fuzz_optional_meta_line(label : String, value : String?) -> String? {
  match value {
    Some(v) => Some(label + "=" + v)
    None => None
  }
}

///|
fn invalid_fuzz_optional_bool_meta_line(
  label : String,
  value : Bool?,
) -> String? {
  match value {
    Some(v) => {
      let text = if v { "true" } else { "false" }
      Some(label + "=" + text)
    }
    None => None
  }
}

///|
fn invalid_fuzz_failure_meta_text(report : InvalidFuzzFailureReport) -> String {
  let lines : Array[String] = [
    "suite=" + report.suite,
    "profile=" + report.profile,
    "seed=" + report.seed.to_string(),
    "attempt=" + report.attempt.to_string(),
    "strategy_id=" + report.strategy_id,
    "source_kind=" + invalid_fuzz_source_kind_name(report.source_kind),
    "expected_stage=" + report.expected_stage,
    "actual_stage=" + report.actual_stage,
  ]
  match
    invalid_fuzz_optional_meta_line(
      "expected_diagnostic_family",
      report.expected_diagnostic_family,
    ) {
    Some(line) => lines.push(line)
    None => ()
  }
  match
    invalid_fuzz_optional_meta_line(
      "actual_diagnostic_family",
      report.actual_diagnostic_family,
    ) {
    Some(line) => lines.push(line)
    None => ()
  }
  match
    invalid_fuzz_optional_meta_line(
      "actual_diagnostic_location",
      report.actual_diagnostic_location,
    ) {
    Some(line) => lines.push(line)
    None => ()
  }
  match report.timeout_budget_ms {
    Some(v) => lines.push("timeout_budget_ms=" + v.to_string())
    None => ()
  }
  match invalid_fuzz_optional_meta_line("seed_profile", report.seed_profile) {
    Some(line) => lines.push(line)
    None => ()
  }
  match invalid_fuzz_optional_meta_line("seed_mode", report.seed_mode) {
    Some(line) => lines.push(line)
    None => ()
  }
  match
    invalid_fuzz_optional_bool_meta_line(
      "seed_require_strategy_prereqs",
      report.seed_require_strategy_prereqs,
    ) {
    Some(line) => lines.push(line)
    None => ()
  }
  match invalid_fuzz_optional_meta_line("stream_label", report.stream_label) {
    Some(line) => lines.push(line)
    None => ()
  }
  match report.stream_seed {
    Some(v) => lines.push("stream_seed=" + v.to_string())
    None => ()
  }
  match report.attempt_seed {
    Some(v) => lines.push("attempt_seed=" + v.to_string())
    None => ()
  }
  match invalid_fuzz_optional_meta_line("source_path", report.source_path) {
    Some(line) => lines.push(line)
    None => ()
  }
  match
    invalid_fuzz_optional_bool_meta_line(
      "valid_before_link",
      report.valid_before_link,
    ) {
    Some(line) => lines.push(line)
    None => ()
  }
  match
    invalid_fuzz_optional_meta_line(
      "unlinkable_reason",
      report.unlinkable_reason,
    ) {
    Some(line) => lines.push(line)
    None => ()
  }
  match
    invalid_fuzz_optional_meta_line(
      "registered_module_name",
      report.registered_module_name,
    ) {
    Some(line) => lines.push(line)
    None => ()
  }
  match
    invalid_fuzz_optional_meta_line(
      "import_module_name",
      report.import_module_name,
    ) {
    Some(line) => lines.push(line)
    None => ()
  }
  match invalid_fuzz_optional_meta_line("import_name", report.import_name) {
    Some(line) => lines.push(line)
    None => ()
  }
  match
    invalid_fuzz_optional_meta_line(
      "expected_import_type",
      report.expected_import_type,
    ) {
    Some(line) => lines.push(line)
    None => ()
  }
  match
    invalid_fuzz_optional_meta_line(
      "provider_export_type",
      report.provider_export_type,
    ) {
    Some(line) => lines.push(line)
    None => ()
  }
  match
    invalid_fuzz_optional_meta_line(
      "pre_link_validation_status",
      report.pre_link_validation_status,
    ) {
    Some(line) => lines.push(line)
    None => ()
  }
  for fact in report.source_feature_facts {
    lines.push("source_feature_fact=" + fact)
  }
  for id in report.multi_fault_mutation_ids {
    lines.push("multi_fault_mutation_id=" + id)
  }
  for outcome in report.multi_fault_broad_outcomes {
    lines.push("multi_fault_broad_outcome=" + outcome)
  }
  for line in invalid_fuzz_artifact_meta_lines("artifact", report.artifacts) {
    lines.push(line)
  }
  for
    line in invalid_fuzz_artifact_meta_lines(
      "reduced",
      report.reduced_artifacts,
    ) {
    lines.push(line)
  }
  match report.reduction_original_size {
    Some(v) => lines.push("reduction_original_size=" + v.to_string())
    None => ()
  }
  match report.reduction_final_size {
    Some(v) => lines.push("reduction_final_size=" + v.to_string())
    None => ()
  }
  match report.reduction_predicate_evaluations {
    Some(v) => lines.push("reduction_predicate_evaluations=" + v.to_string())
    None => ()
  }
  for step in report.reduction_steps {
    lines.push("reduction_step=" + invalid_fuzz_reduction_step_text(step))
  }
  if invalid_fuzz_reduction_has_log(report) {
    lines.push("reduction_log=reduction.txt")
  }
  invalid_fuzz_join(lines, "\n") + "\n"
}

///|
fn invalid_fuzz_join_path(left : String, right : String) -> String {
  if left.length() == 0 || left == "." {
    return right
  }
  let last = left[left.length() - 1]
  if last == '/' || last == '\\' {
    left + right
  } else {
    left + "/" + right
  }
}

///|
fn invalid_fuzz_ensure_dir(
  io : InvalidFuzzPersistIO,
  path : String,
) -> Result[Unit, String] {
  match (io.ensure_dir)(path) {
    Ok(_) => Ok(())
    Err(msg) => Err("failed to ensure invalid repro dir \{path}: \{msg}")
  }
}

///|
fn invalid_fuzz_report_allows_partial_artifacts(
  report : InvalidFuzzFailureReport,
) -> Bool {
  report.actual_stage == "timeout" ||
  report.actual_stage == "resource-limit" ||
  report.actual_stage == "resource-limited"
}

///|
pub fn persist_invalid_fuzz_failure_report(
  report : InvalidFuzzFailureReport,
  io : InvalidFuzzPersistIO,
  corpus_dir? : String = "fuzz-corpus/invalid",
) -> Result[(String, Array[String]), String] {
  let root = corpus_dir.trim().to_owned()
  let corpus_root = if root.length() == 0 {
    "fuzz-corpus/invalid"
  } else {
    root
  }
  let suite_dir = invalid_fuzz_join_path(corpus_root, report.suite)
  let strategy_dir = invalid_fuzz_join_path(suite_dir, report.strategy_id)
  let repro_dir = invalid_fuzz_join_path(
    strategy_dir,
    "seed-\{report.seed}-attempt-\{report.attempt}",
  )
  match invalid_fuzz_ensure_dir(io, corpus_root) {
    Ok(_) => ()
    Err(msg) => return Err(msg)
  }
  match invalid_fuzz_ensure_dir(io, suite_dir) {
    Ok(_) => ()
    Err(msg) => return Err(msg)
  }
  match invalid_fuzz_ensure_dir(io, strategy_dir) {
    Ok(_) => ()
    Err(msg) => return Err(msg)
  }
  match invalid_fuzz_ensure_dir(io, repro_dir) {
    Ok(_) => ()
    Err(msg) => return Err(msg)
  }
  let artifact_paths : Array[String] = []
  let partial_failures : Array[String] = []
  let allow_partial_artifacts = invalid_fuzz_report_allows_partial_artifacts(
    report,
  )
  for artifact in report.artifacts {
    let path = invalid_fuzz_join_path(repro_dir, artifact.file_name)
    match (io.write_file)(path, artifact.bytes) {
      Ok(_) => artifact_paths.push(path)
      Err(msg) =>
        if allow_partial_artifacts {
          partial_failures.push(
            "partial_artifact_write_failure=" + artifact.file_name + "|" + msg,
          )
        } else {
          return Err("failed to write invalid repro artifact \{path}: \{msg}")
        }
    }
  }
  for artifact in report.reduced_artifacts {
    let path = invalid_fuzz_join_path(repro_dir, artifact.file_name)
    match (io.write_file)(path, artifact.bytes) {
      Ok(_) => artifact_paths.push(path)
      Err(msg) =>
        if allow_partial_artifacts {
          partial_failures.push(
            "partial_artifact_write_failure=" + artifact.file_name + "|" + msg,
          )
        } else {
          return Err("failed to write invalid repro artifact \{path}: \{msg}")
        }
    }
  }
  if invalid_fuzz_reduction_has_log(report) {
    let reduction_log_path = invalid_fuzz_join_path(repro_dir, "reduction.txt")
    match
      (io.write_file)(
        reduction_log_path,
        invalid_fuzz_string_bytes(invalid_fuzz_reduction_log_text(report)),
      ) {
      Ok(_) => artifact_paths.push(reduction_log_path)
      Err(msg) =>
        if allow_partial_artifacts {
          partial_failures.push(
            "partial_artifact_write_failure=reduction.txt|" + msg,
          )
        } else {
          return Err(
            "failed to write invalid repro artifact \{reduction_log_path}: \{msg}",
          )
        }
    }
  }
  let meta_path = invalid_fuzz_join_path(repro_dir, "repro.meta.txt")
  let partial_manifest = if partial_failures.length() == 0 {
    ""
  } else {
    invalid_fuzz_join(partial_failures, "\n") + "\n"
  }
  match
    (io.write_file)(
      meta_path,
      invalid_fuzz_string_bytes(
        invalid_fuzz_failure_meta_text(report) + partial_manifest,
      ),
    ) {
    Ok(_) => Ok((meta_path, artifact_paths))
    Err(msg) =>
      Err("failed to write invalid repro metadata \{meta_path}: \{msg}")
  }
}

///|
fn invalid_fuzz_parse_meta_line(line : String) -> (String, String)? {
  let mut idx = -1
  let mut i = 0
  while i < line.length() {
    if line[i] == '=' {
      idx = i
      break
    }
    i += 1
  }
  if idx < 0 {
    return None
  }
  Some((line.sub(end=idx).to_owned(), line.sub(start=idx + 1).to_owned()))
}

///|
fn invalid_fuzz_parse_uint64(
  raw : String,
  field : String,
) -> Result[UInt64, String] {
  let text = raw.trim().to_owned()
  if text.length() == 0 {
    return Err("missing \{field}")
  }
  let mut value : UInt64 = 0UL
  for c in text {
    if c < '0' || c > '9' {
      return Err("invalid \{field} '\{raw}'")
    }
    value = value * 10UL + (c.to_int() - '0'.to_int()).to_uint64()
  }
  Ok(value)
}

///|
fn invalid_fuzz_parse_int(raw : String, field : String) -> Result[Int, String] {
  let text = raw.trim().to_owned()
  if text.length() == 0 {
    return Err("missing \{field}")
  }
  let mut value = 0
  for c in text {
    if c < '0' || c > '9' {
      return Err("invalid \{field} '\{raw}'")
    }
    value = value * 10 + (c.to_int() - '0'.to_int())
  }
  Ok(value)
}

///|
fn invalid_fuzz_parse_bool(
  raw : String,
  field : String,
) -> Result[Bool, String] {
  let text = raw.trim().to_owned()
  match text {
    "true" => Ok(true)
    "false" => Ok(false)
    _ => Err("invalid \{field} '\{raw}'")
  }
}

///|
fn invalid_fuzz_parse_artifact_entry(
  raw : String,
  load_artifact : (String) -> Result[Bytes, String],
) -> Result[InvalidFuzzArtifact, String] {
  let mut sep = -1
  let mut i = 0
  while i < raw.length() {
    if raw[i] == '|' {
      sep = i
      break
    }
    i += 1
  }
  if sep <= 0 || sep + 1 >= raw.length() {
    return Err("invalid artifact entry '\{raw}'")
  }
  let label = raw.sub(end=sep).trim().to_owned()
  let file_name = raw.sub(start=sep + 1).trim().to_owned()
  if label.length() == 0 || file_name.length() == 0 {
    return Err("invalid artifact entry '\{raw}'")
  }
  match load_artifact(file_name) {
    Ok(bytes) => Ok(InvalidFuzzArtifact::new(label, file_name, bytes))
    Err(msg) => Err(msg)
  }
}

///|
fn invalid_fuzz_parse_reduction_step(
  raw : String,
) -> Result[InvalidFuzzReductionStep, String] {
  let parts : Array[String] = []
  for part in raw.split("|") {
    parts.push(part.to_owned())
  }
  if parts.length() != 5 {
    return Err("invalid reduction step entry '\{raw}'")
  }
  let start = match invalid_fuzz_parse_int(parts[1], "reduction_step.start") {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let len = match invalid_fuzz_parse_int(parts[2], "reduction_step.len") {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let before_size = match
    invalid_fuzz_parse_int(parts[3], "reduction_step.before_size") {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let after_size = match
    invalid_fuzz_parse_int(parts[4], "reduction_step.after_size") {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  Ok(
    InvalidFuzzReductionStep::new(parts[0], start, len, before_size, after_size),
  )
}

///|
pub fn parse_invalid_fuzz_failure_report(
  meta_text : String,
  load_artifact : (String) -> Result[Bytes, String],
) -> Result[InvalidFuzzFailureReport, String] {
  let mut suite : String? = None
  let mut profile : String? = None
  let mut seed : UInt64? = None
  let mut attempt : Int? = None
  let mut strategy_id : String? = None
  let mut source_kind : InvalidFuzzSourceKind? = None
  let mut expected_stage : String? = None
  let mut expected_diagnostic_family : String? = None
  let mut actual_stage : String? = None
  let mut actual_diagnostic_family : String? = None
  let mut actual_diagnostic_location : String? = None
  let mut timeout_budget_ms : Int? = None
  let mut seed_profile : String? = None
  let mut seed_mode : String? = None
  let mut seed_require_strategy_prereqs : Bool? = None
  let mut stream_label : String? = None
  let mut stream_seed : UInt64? = None
  let mut attempt_seed : UInt64? = None
  let mut source_path : String? = None
  let mut valid_before_link : Bool? = None
  let mut unlinkable_reason : String? = None
  let mut registered_module_name : String? = None
  let mut import_module_name : String? = None
  let mut import_name : String? = None
  let mut expected_import_type : String? = None
  let mut provider_export_type : String? = None
  let mut pre_link_validation_status : String? = None
  let source_feature_facts : Array[String] = []
  let multi_fault_mutation_ids : Array[String] = []
  let multi_fault_broad_outcomes : Array[String] = []
  let artifacts : Array[InvalidFuzzArtifact] = []
  let reduced_artifacts : Array[InvalidFuzzArtifact] = []
  let mut reduction_original_size : Int? = None
  let mut reduction_final_size : Int? = None
  let mut reduction_predicate_evaluations : Int? = None
  let reduction_steps : Array[InvalidFuzzReductionStep] = []
  for raw_line in meta_text.split("\n") {
    let line = raw_line.trim().to_owned()
    if line.length() == 0 {
      continue
    }
    let (key, value) = match invalid_fuzz_parse_meta_line(line) {
      Some(v) => v
      None => return Err("invalid metadata line '\{line}'")
    }
    match key {
      "suite" => suite = Some(value)
      "profile" => profile = Some(value)
      "seed" =>
        match invalid_fuzz_parse_uint64(value, "seed") {
          Ok(v) => seed = Some(v)
          Err(msg) => return Err(msg)
        }
      "attempt" =>
        match invalid_fuzz_parse_int(value, "attempt") {
          Ok(v) => attempt = Some(v)
          Err(msg) => return Err(msg)
        }
      "strategy_id" => strategy_id = Some(value)
      "source_kind" =>
        match invalid_fuzz_source_kind_from_name(value) {
          Some(v) => source_kind = Some(v)
          None => return Err("unknown source_kind '\{value}'")
        }
      "expected_stage" => expected_stage = Some(value)
      "expected_diagnostic_family" => expected_diagnostic_family = Some(value)
      "actual_stage" => actual_stage = Some(value)
      "actual_diagnostic_family" => actual_diagnostic_family = Some(value)
      "actual_diagnostic_location" => actual_diagnostic_location = Some(value)
      "timeout_budget_ms" =>
        match invalid_fuzz_parse_int(value, "timeout_budget_ms") {
          Ok(v) => timeout_budget_ms = Some(v)
          Err(msg) => return Err(msg)
        }
      "seed_profile" => seed_profile = Some(value)
      "seed_mode" => seed_mode = Some(value)
      "seed_require_strategy_prereqs" =>
        match invalid_fuzz_parse_bool(value, "seed_require_strategy_prereqs") {
          Ok(v) => seed_require_strategy_prereqs = Some(v)
          Err(msg) => return Err(msg)
        }
      "stream_label" => stream_label = Some(value)
      "stream_seed" =>
        match invalid_fuzz_parse_uint64(value, "stream_seed") {
          Ok(v) => stream_seed = Some(v)
          Err(msg) => return Err(msg)
        }
      "attempt_seed" =>
        match invalid_fuzz_parse_uint64(value, "attempt_seed") {
          Ok(v) => attempt_seed = Some(v)
          Err(msg) => return Err(msg)
        }
      "source_path" => source_path = Some(value)
      "valid_before_link" =>
        match invalid_fuzz_parse_bool(value, "valid_before_link") {
          Ok(v) => valid_before_link = Some(v)
          Err(msg) => return Err(msg)
        }
      "unlinkable_reason" => unlinkable_reason = Some(value)
      "registered_module_name" => registered_module_name = Some(value)
      "import_module_name" => import_module_name = Some(value)
      "import_name" => import_name = Some(value)
      "expected_import_type" => expected_import_type = Some(value)
      "provider_export_type" => provider_export_type = Some(value)
      "pre_link_validation_status" => pre_link_validation_status = Some(value)
      "source_feature_fact" => source_feature_facts.push(value)
      "multi_fault_mutation_id" => multi_fault_mutation_ids.push(value)
      "multi_fault_broad_outcome" => multi_fault_broad_outcomes.push(value)
      "artifact" =>
        match invalid_fuzz_parse_artifact_entry(value, load_artifact) {
          Ok(v) => artifacts.push(v)
          Err(msg) => return Err(msg)
        }
      "reduced" =>
        match invalid_fuzz_parse_artifact_entry(value, load_artifact) {
          Ok(v) => reduced_artifacts.push(v)
          Err(msg) => return Err(msg)
        }
      "reduction_original_size" =>
        match invalid_fuzz_parse_int(value, "reduction_original_size") {
          Ok(v) => reduction_original_size = Some(v)
          Err(msg) => return Err(msg)
        }
      "reduction_final_size" =>
        match invalid_fuzz_parse_int(value, "reduction_final_size") {
          Ok(v) => reduction_final_size = Some(v)
          Err(msg) => return Err(msg)
        }
      "reduction_predicate_evaluations" =>
        match invalid_fuzz_parse_int(value, "reduction_predicate_evaluations") {
          Ok(v) => reduction_predicate_evaluations = Some(v)
          Err(msg) => return Err(msg)
        }
      "reduction_step" =>
        match invalid_fuzz_parse_reduction_step(value) {
          Ok(v) => reduction_steps.push(v)
          Err(msg) => return Err(msg)
        }
      "reduction_log" => ()
      "partial_artifact_write_failure" => ()
      _ => return Err("unknown invalid repro metadata key '\{key}'")
    }
  }
  let resolved_suite = match suite {
    Some(v) => v
    None => return Err("missing suite")
  }
  let resolved_profile = match profile {
    Some(v) => v
    None => return Err("missing profile")
  }
  let resolved_seed = match seed {
    Some(v) => v
    None => return Err("missing seed")
  }
  let resolved_attempt = match attempt {
    Some(v) => v
    None => return Err("missing attempt")
  }
  let resolved_strategy_id = match strategy_id {
    Some(v) => v
    None => return Err("missing strategy_id")
  }
  let resolved_source_kind = match source_kind {
    Some(v) => v
    None => return Err("missing source_kind")
  }
  let resolved_expected_stage = match expected_stage {
    Some(v) => v
    None => return Err("missing expected_stage")
  }
  let resolved_actual_stage = match actual_stage {
    Some(v) => v
    None => return Err("missing actual_stage")
  }
  Ok(
    InvalidFuzzFailureReport::new(
      resolved_suite,
      resolved_profile,
      resolved_seed,
      resolved_attempt,
      resolved_strategy_id,
      resolved_source_kind,
      resolved_expected_stage,
      expected_diagnostic_family~,
      actual_stage=resolved_actual_stage,
      actual_diagnostic_family~,
      actual_diagnostic_location~,
      timeout_budget_ms~,
      seed_profile~,
      seed_mode~,
      seed_require_strategy_prereqs~,
      stream_label~,
      stream_seed~,
      attempt_seed~,
      source_path~,
      valid_before_link~,
      unlinkable_reason~,
      registered_module_name~,
      import_module_name~,
      import_name~,
      expected_import_type~,
      provider_export_type~,
      pre_link_validation_status~,
      source_feature_facts~,
      multi_fault_mutation_ids~,
      multi_fault_broad_outcomes~,
      artifacts~,
      reduced_artifacts~,
      reduction_original_size~,
      reduction_final_size~,
      reduction_predicate_evaluations~,
      reduction_steps~,
    ),
  )
}

///|
fn invalid_fuzz_encode_module_artifact(
  label : String,
  file_name : String,
  mod : @lib.Module,
) -> Result[InvalidFuzzArtifact, String] {
  match encode_module(mod) {
    Ok(bytes) => Ok(InvalidFuzzArtifact::new(label, file_name, bytes))
    Err(msg) => Err("\{msg}")
  }
}

///|
fn invalid_fuzz_expected_binary_outcome(
  expected_result : ValidateInvalidBinaryExpectedResult,
) -> (String, String?) {
  match expected_result {
    DecodeRejected => ("decode-rejected", None)
    ValidateRejected(family_label) => ("validate-rejected", Some(family_label))
  }
}

///|
fn invalid_fuzz_report_outcome_matches(
  replay : InvalidFuzzReplayResult,
  expected_stage : String,
  expected_diagnostic_family : String?,
) -> Bool {
  if replay.stage != expected_stage {
    return false
  }
  replay.diagnostic_family == expected_diagnostic_family
}

///|
fn invalid_fuzz_stream_seed_by_label(seed : UInt64, wanted : String) -> UInt64? {
  for label in gen_valid_random_stream_labels() {
    if gen_valid_random_stream_label_name(label) == wanted {
      return Some(gen_valid_derive_stream_seed(seed, label))
    }
  }
  None
}

///|
pub fn build_invalid_fuzz_failure_report_by_suite_and_stable_id(
  suite : String,
  strategy_id : String,
  seed : UInt64,
  attempt : Int,
  profile? : String = "smoke",
) -> Result[InvalidFuzzFailureReport, String] {
  let normalized = invalid_fuzz_ascii_lower(suite.trim().to_owned())
  if normalized == "validate-invalid-text-dynamic" ||
    normalized == "dynamic-text" {
    return build_invalid_fuzz_dynamic_text_failure_report_by_stable_id(
      strategy_id,
      seed,
      attempt,
      profile~,
    )
  }
  if normalized == "valid-multi-module-linking" ||
    normalized == "multi-module-linking" {
    if strategy_id != "unlinkable-multi-module" {
      return Err("unknown multi-module invalid strategy '\{strategy_id}'")
    }
    ignore(profile)
    return Ok(build_fuz1055b4_unlinkable_failure_report(seed, attempt))
  }
  let source_kind = match invalid_fuzz_source_kind_from_name(normalized) {
    Some(v) => v
    None => return Err("unknown invalid fuzz suite '\{suite}'")
  }
  match source_kind {
    AstInvalidSource =>
      build_invalid_fuzz_ast_failure_report_by_stable_id(
        strategy_id,
        seed,
        attempt,
        profile~,
      )
    BinaryInvalidSource =>
      build_invalid_fuzz_binary_failure_report_by_stable_id(
        strategy_id,
        seed,
        attempt,
        profile~,
      )
    TextInvalidSource =>
      build_invalid_fuzz_text_failure_report_by_stable_id(
        strategy_id,
        seed,
        attempt,
        profile~,
      )
    SpecSeedInvalidSource =>
      build_invalid_fuzz_spec_seed_failure_report_by_stable_id(
        strategy_id,
        seed,
        attempt,
        profile~,
      )
  }
}

///|
pub fn build_invalid_fuzz_ast_failure_report_by_stable_id(
  strategy_id : String,
  seed : UInt64,
  attempt : Int,
  profile? : String = "smoke",
  params? : @validate.GenInvalidAstParams? = None,
) -> Result[InvalidFuzzFailureReport, String] {
  let spec = match
    @validate.validate_invalid_ast_strategy_by_stable_id(strategy_id) {
    Some(v) => v
    None => return Err("unknown AST invalid strategy '\{strategy_id}'")
  }
  let resolved_params = match params {
    Some(v) => v
    None => @validate.GenInvalidAstParams::repro_seed(spec.id)
  }
  let seed_profile_name = @validate.gen_invalid_ast_params_profile_name(
    resolved_params,
  )
  let attempt_seed = @validate.validate_invalid_ast_attempt_seed_for_profile(
    seed, strategy_id, seed_profile_name,
  )
  let generated = match
    @validate.gen_invalid_ast_generate_from_seed(attempt_seed, resolved_params) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let artifact = match
    invalid_fuzz_encode_module_artifact(
      "original",
      "original.wasm",
      generated.mutation.mutated_module,
    ) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let seed_artifact = match
    invalid_fuzz_encode_module_artifact(
      "seed",
      "seed.wasm",
      generated.base_module,
    ) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let replay = invalid_fuzz_replay_binary_like(artifact.bytes)
  let expected_family = Some(invalid_fuzz_family_label(spec.expected_family))
  if !invalid_fuzz_report_outcome_matches(
      replay, "validate-rejected", expected_family,
    ) {
    let expected_family_text = expected_family.unwrap_or("")
    let actual_family_text = replay.diagnostic_family.unwrap_or("")
    return Err(
      "AST invalid report outcome mismatch: strategy=\{strategy_id} expected_stage=validate-rejected expected_family=\{expected_family_text} actual_stage=\{replay.stage} actual_family=\{actual_family_text}",
    )
  }
  Ok(
    InvalidFuzzFailureReport::new(
      "validate-invalid-ast",
      profile,
      seed,
      attempt,
      strategy_id,
      invalid_fuzz_ast_source_kind(),
      "validate-rejected",
      expected_diagnostic_family=expected_family,
      actual_stage=replay.stage,
      actual_diagnostic_family=replay.diagnostic_family,
      actual_diagnostic_location=replay.diagnostic_location,
      seed_profile=Some(seed_profile_name),
      seed_mode=Some(
        @validate.gen_invalid_seed_mode_name(resolved_params.seed_mode),
      ),
      seed_require_strategy_prereqs=Some(
        resolved_params.require_strategy_prereqs,
      ),
      stream_label=Some("invalid-mutation-choice"),
      stream_seed=invalid_fuzz_stream_seed_by_label(
        seed, "invalid-mutation-choice",
      ),
      attempt_seed=Some(attempt_seed),
      artifacts=[artifact, seed_artifact],
    ),
  )
}

///|
pub fn build_invalid_fuzz_binary_failure_report_by_stable_id(
  strategy_id : String,
  seed : UInt64,
  attempt : Int,
  profile? : String = "smoke",
  params? : GenInvalidBinaryParams? = None,
) -> Result[InvalidFuzzFailureReport, String] {
  let spec = match validate_invalid_binary_strategy_by_stable_id(strategy_id) {
    Some(v) => v
    None => return Err("unknown binary invalid strategy '\{strategy_id}'")
  }
  let resolved_params = match params {
    Some(v) => v
    None => GenInvalidBinaryParams::repro_seed(spec.id)
  }
  let seed_profile_name = gen_invalid_binary_params_profile_name(
    resolved_params,
  )
  let attempt_seed = validate_invalid_binary_attempt_seed(
    seed, strategy_id, seed_profile_name,
  )
  let generated = match
    gen_invalid_binary_generate(
      @splitmix.new(seed=attempt_seed),
      resolved_params,
    ) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let artifact = InvalidFuzzArtifact::new(
    "original",
    "original.wasm",
    generated.mutation.mutated_bytes,
  )
  let seed_artifact = match
    invalid_fuzz_encode_module_artifact(
      "seed",
      "seed.wasm",
      generated.base_module,
    ) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let replay = invalid_fuzz_replay_binary_like(artifact.bytes)
  let (expected_stage, expected_family) = invalid_fuzz_expected_binary_outcome(
    spec.expected_result,
  )
  if !invalid_fuzz_report_outcome_matches(
      replay, expected_stage, expected_family,
    ) {
    let expected_family_text = expected_family.unwrap_or("")
    let actual_family_text = replay.diagnostic_family.unwrap_or("")
    return Err(
      "binary invalid report outcome mismatch: strategy=\{strategy_id} expected_stage=\{expected_stage} expected_family=\{expected_family_text} actual_stage=\{replay.stage} actual_family=\{actual_family_text}",
    )
  }
  Ok(
    InvalidFuzzFailureReport::new(
      "validate-invalid-binary",
      profile,
      seed,
      attempt,
      strategy_id,
      invalid_fuzz_binary_source_kind(),
      expected_stage,
      expected_diagnostic_family=expected_family,
      actual_stage=replay.stage,
      actual_diagnostic_family=replay.diagnostic_family,
      actual_diagnostic_location=replay.diagnostic_location,
      seed_profile=Some(seed_profile_name),
      seed_mode=Some(
        gen_invalid_binary_seed_mode_name(resolved_params.seed_mode),
      ),
      seed_require_strategy_prereqs=Some(
        resolved_params.require_strategy_prereqs,
      ),
      stream_label=Some("invalid-mutation-choice"),
      stream_seed=invalid_fuzz_stream_seed_by_label(
        seed, "invalid-mutation-choice",
      ),
      attempt_seed=Some(attempt_seed),
      artifacts=[artifact, seed_artifact],
    ),
  )
}

///|
pub fn build_invalid_fuzz_text_failure_report_by_stable_id(
  strategy_id : String,
  seed : UInt64,
  attempt : Int,
  profile? : String = "smoke",
) -> Result[InvalidFuzzFailureReport, String] {
  ignore(seed)
  let spec = match validate_invalid_text_strategy_by_stable_id(strategy_id) {
    Some(v) => v
    None =>
      return Err("unknown validate-invalid-text strategy '\{strategy_id}'")
  }
  let (path, source, assertion_kind) = match
    validate_invalid_text_source_by_stable_id(strategy_id) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let artifact = InvalidFuzzArtifact::new(
    "original",
    "original.wast",
    invalid_fuzz_string_bytes(source),
  )
  let stage = match
    evaluate_validate_invalid_text_assertion_source(
      source, path, assertion_kind,
    ) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let expected_stage = validate_invalid_text_stage_name(spec.expected_stage)
  let actual_stage = validate_invalid_text_stage_name(stage)
  if expected_stage != actual_stage {
    return Err(
      "text invalid report outcome mismatch: strategy=\{strategy_id} expected_stage=\{expected_stage} actual_stage=\{actual_stage}",
    )
  }
  Ok(
    InvalidFuzzFailureReport::new(
      "validate-invalid-text",
      profile,
      seed,
      attempt,
      strategy_id,
      invalid_fuzz_text_source_kind(),
      expected_stage,
      actual_stage~,
      source_path=Some(path),
      artifacts=[artifact],
    ),
  )
}

///|
pub fn build_invalid_fuzz_dynamic_text_failure_report_by_stable_id(
  strategy_id : String,
  seed : UInt64,
  attempt : Int,
  profile? : String = "smoke",
) -> Result[InvalidFuzzFailureReport, String] {
  let attempt_seed = validate_invalid_text_dynamic_attempt_seed(
    seed, strategy_id, attempt,
  )
  let generated = match
    validate_invalid_text_dynamic_case(attempt_seed, strategy_id) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let stage = match
    evaluate_validate_invalid_text_assertion_source(
      generated.assertion_source,
      "dynamic-text-invalid/\{generated.stable_id}.wast",
      generated.assertion_kind,
    ) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let expected_stage = validate_invalid_text_stage_name(
    generated.expected_stage,
  )
  let actual_stage = validate_invalid_text_stage_name(stage)
  if expected_stage != actual_stage {
    return Err(
      "dynamic text invalid report outcome mismatch: strategy=\{strategy_id} expected_stage=\{expected_stage} actual_stage=\{actual_stage}",
    )
  }
  Ok(
    InvalidFuzzFailureReport::new(
      "validate-invalid-text-dynamic",
      profile,
      seed,
      attempt,
      strategy_id,
      invalid_fuzz_text_source_kind(),
      expected_stage,
      actual_stage~,
      seed_profile=Some("dynamic-gen-valid"),
      seed_mode=Some("gen-valid-wat"),
      stream_label=Some("text-mutation-choice"),
      stream_seed=Some(validate_invalid_text_dynamic_stream_seed(seed)),
      attempt_seed=Some(attempt_seed),
      source_path=Some("dynamic-text-invalid/\{generated.stable_id}.wast"),
      valid_before_link=Some(stage == ValidBeforeLinkStage),
      source_feature_facts=generated.source_feature_facts,
      artifacts=[
        InvalidFuzzArtifact::new(
          "base",
          "base.wat",
          invalid_fuzz_string_bytes(generated.base_source),
        ),
        InvalidFuzzArtifact::new(
          "assertion",
          "assertion.wast",
          invalid_fuzz_string_bytes(generated.assertion_source),
        ),
      ],
    ),
  )
}

///|
pub fn build_invalid_fuzz_spec_seed_failure_report_by_stable_id(
  strategy_id : String,
  seed : UInt64,
  attempt : Int,
  profile? : String = "smoke",
) -> Result[InvalidFuzzFailureReport, String] {
  ignore(seed)
  let spec = match validate_invalid_spec_seed_by_stable_id(strategy_id) {
    Some(v) => v
    None =>
      return Err("unknown validate-invalid-spec-seed case '\{strategy_id}'")
  }
  let (path, assertion_source, assertion_kind) = match
    validate_invalid_spec_seed_assertion_source_by_stable_id(strategy_id) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let full_source = match read_file_sync(path) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let artifact = InvalidFuzzArtifact::new(
    "original",
    "original.wast",
    invalid_fuzz_string_bytes(full_source),
  )
  let stage = match
    evaluate_validate_invalid_text_assertion_source(
      assertion_source, path, assertion_kind,
    ) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let expected_stage = validate_invalid_text_stage_name(spec.expected_stage)
  let actual_stage = validate_invalid_text_stage_name(stage)
  if expected_stage != actual_stage {
    return Err(
      "spec-seed invalid report outcome mismatch: strategy=\{strategy_id} expected_stage=\{expected_stage} actual_stage=\{actual_stage}",
    )
  }
  Ok(
    InvalidFuzzFailureReport::new(
      "validate-invalid-spec-seed",
      profile,
      seed,
      attempt,
      strategy_id,
      invalid_fuzz_spec_seed_source_kind(),
      expected_stage,
      actual_stage~,
      source_path=Some(path),
      artifacts=[artifact],
    ),
  )
}

///|
fn invalid_fuzz_binary_strategy_reduce(
  strategy_id : String,
) -> Result[InvalidFuzzArtifact, String] {
  let bytes = match
    build_validate_invalid_binary_minimal_repro_by_stable_id(strategy_id) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  Ok(InvalidFuzzArtifact::new("reduced", "reduced.wasm", bytes))
}

///|
fn invalid_fuzz_ast_strategy_reduce(
  strategy_id : String,
) -> Result[InvalidFuzzArtifact, String] {
  let mod = match
    @validate.build_validate_invalid_ast_minimal_repro_by_stable_id(strategy_id) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  invalid_fuzz_encode_module_artifact("reduced", "reduced.wasm", mod)
}

///|
fn invalid_fuzz_text_strategy_reduce(
  strategy_id : String,
) -> Result[(InvalidFuzzArtifact, String), String] {
  let (path, source, _) = match
    validate_invalid_text_source_by_stable_id(strategy_id) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  Ok(
    (
      InvalidFuzzArtifact::new(
        "reduced",
        "reduced.wast",
        invalid_fuzz_string_bytes(source),
      ),
      path,
    ),
  )
}

///|
fn invalid_fuzz_spec_seed_reduce(
  strategy_id : String,
) -> Result[(InvalidFuzzArtifact, String), String] {
  let (path, source, _) = match
    validate_invalid_spec_seed_assertion_source_by_stable_id(strategy_id) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  Ok(
    (
      InvalidFuzzArtifact::new(
        "reduced",
        "reduced.wast",
        invalid_fuzz_string_bytes(source),
      ),
      path,
    ),
  )
}

///|
fn invalid_fuzz_first_artifact_size(
  artifacts : Array[InvalidFuzzArtifact],
) -> Int? {
  if artifacts.length() == 0 {
    None
  } else {
    Some(artifacts[0].bytes.length())
  }
}

///|
fn invalid_fuzz_text_is_space(c : Int) -> Bool {
  c == 0x20 || c == 0x0a || c == 0x0d || c == 0x09
}

///|
fn invalid_fuzz_text_slice(text : String, start : Int, end : Int) -> String {
  let len = end - start
  let chars : Array[Char] = Array::make(len, '\u{00}')
  for i = 0; i < len; i = i + 1 {
    chars[i] = text[start + i].to_int().unsafe_to_char()
  }
  String::from_array(chars)
}

///|
fn invalid_fuzz_text_tokens(text : String) -> Array[String] {
  let tokens : Array[String] = []
  let mut start = 0
  let mut in_token = false
  for i = 0; i < text.length(); i = i + 1 {
    if invalid_fuzz_text_is_space(text[i].to_int()) {
      if in_token {
        tokens.push(invalid_fuzz_text_slice(text, start, i))
        in_token = false
      }
    } else if !in_token {
      start = i
      in_token = true
    }
  }
  if in_token {
    tokens.push(invalid_fuzz_text_slice(text, start, text.length()))
  }
  tokens
}

///|
fn invalid_fuzz_text_join_tokens(tokens : Array[String]) -> String {
  let out = StringBuilder::new()
  for i = 0; i < tokens.length(); i = i + 1 {
    if i > 0 {
      out.write_string(" ")
    }
    out.write_string(tokens[i])
  }
  out.to_string()
}

///|
fn invalid_fuzz_without_text_token_range(
  tokens : Array[String],
  start : Int,
  len : Int,
) -> Array[String] {
  let out : Array[String] = []
  let end = start + len
  for i = 0; i < tokens.length(); i = i + 1 {
    if i < start || i >= end {
      out.push(tokens[i])
    }
  }
  out
}

///|
fn invalid_fuzz_clone_text_tokens(tokens : Array[String]) -> Array[String] {
  invalid_fuzz_without_text_token_range(tokens, tokens.length(), 0)
}

///|
fn reduce_fuzz_text_tokens_by_deletion(
  text : String,
  reproduces : (String) -> Bool,
) -> (String, Int, Int, Int, Array[InvalidFuzzReductionStep]) {
  let tokens = invalid_fuzz_text_tokens(text)
  let mut predicate_evaluations = 1
  let steps : Array[InvalidFuzzReductionStep] = []
  if !reproduces(text) {
    return (
      text,
      tokens.length(),
      tokens.length(),
      predicate_evaluations,
      steps,
    )
  }
  let mut current = invalid_fuzz_clone_text_tokens(tokens)
  let mut chunk = current.length() / 2
  while chunk > 0 {
    let mut changed = false
    let mut i = 0
    while i + chunk <= current.length() {
      let candidate = invalid_fuzz_without_text_token_range(current, i, chunk)
      let candidate_text = invalid_fuzz_text_join_tokens(candidate)
      predicate_evaluations = predicate_evaluations + 1
      if reproduces(candidate_text) {
        steps.push(
          InvalidFuzzReductionStep::new(
            "delete-text-token-range",
            i,
            chunk,
            current.length(),
            candidate.length(),
          ),
        )
        current = candidate
        changed = true
      } else {
        i += 1
      }
    }
    if !changed {
      chunk = chunk / 2
    } else if chunk > current.length() {
      chunk = current.length()
    }
  }
  let result = invalid_fuzz_text_join_tokens(current)
  (result, tokens.length(), current.length(), predicate_evaluations, steps)
}

///|
fn invalid_fuzz_without_module_field_range(
  fields : Array[ModuleField],
  start : Int,
  len : Int,
) -> Array[ModuleField] {
  let out : Array[ModuleField] = []
  let end = start + len
  for i = 0; i < fields.length(); i = i + 1 {
    if i < start || i >= end {
      out.push(fields[i])
    }
  }
  out
}

///|
fn invalid_fuzz_clone_module_fields(
  fields : Array[ModuleField],
) -> Array[ModuleField] {
  invalid_fuzz_without_module_field_range(fields, fields.length(), 0)
}

///|
fn invalid_fuzz_wast_quote(text : String) -> String {
  let out = StringBuilder::new()
  out.write_char('"')
  for c in text {
    if c == '\\' {
      out.write_string("\\\\")
    } else if c == '"' {
      out.write_string("\\\"")
    } else {
      out.write_char(c)
    }
  }
  out.write_char('"')
  out.to_string()
}

///|
fn invalid_fuzz_assertion_keyword(
  assertion_kind : ValidateInvalidTextAssertionKind,
) -> String {
  match assertion_kind {
    MalformedTextAssertion => "assert_malformed"
    InvalidTextAssertion => "assert_invalid"
    UnlinkableTextAssertion => "assert_unlinkable"
  }
}

///|
fn invalid_fuzz_inline_assertion_source(
  fields : Array[ModuleField],
  assertion_kind : ValidateInvalidTextAssertionKind,
  message : String,
) -> Result[String, String] {
  let module_text = match module_to_wast(@wast.Module::new(fields)) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  Ok(
    "(\{invalid_fuzz_assertion_keyword(assertion_kind)} \{module_text} \{invalid_fuzz_wast_quote(message)})",
  )
}

///|
fn invalid_fuzz_first_inline_assertion_fields(
  source : String,
  path : String,
  assertion_kind : ValidateInvalidTextAssertionKind,
) -> Result[(Array[ModuleField], String), String] {
  let script = match wast_to_script(source, filename=path) {
    Ok(v) => v
    Err(msg) => return Err("script parse failed: \{msg}")
  }
  for cmd in script.commands {
    match (cmd, assertion_kind) {
      (
        @wast.WastCommand::AssertMalformed(
          @wast.WastModuleDef::Inline(mod),
          msg
        ),
        MalformedTextAssertion,
      ) => return Ok((mod.fields, msg))
      (
        @wast.WastCommand::AssertInvalid(@wast.WastModuleDef::Inline(mod), msg),
        InvalidTextAssertion,
      ) => return Ok((mod.fields, msg))
      (
        @wast.WastCommand::AssertUnlinkable(
          @wast.WastModuleDef::Inline(mod),
          msg
        ),
        UnlinkableTextAssertion,
      ) => return Ok((mod.fields, msg))
      _ => ()
    }
  }
  Err("missing inline assertion module in \{path}")
}

///|
fn reduce_fuzz_module_fields_by_deletion(
  fields : Array[ModuleField],
  reproduces : (Array[ModuleField]) -> Bool,
) -> (Array[ModuleField], Int, Int, Int, Array[InvalidFuzzReductionStep]) {
  let mut predicate_evaluations = 1
  let steps : Array[InvalidFuzzReductionStep] = []
  if !reproduces(fields) {
    return (
      fields,
      fields.length(),
      fields.length(),
      predicate_evaluations,
      steps,
    )
  }
  let mut current = invalid_fuzz_clone_module_fields(fields)
  let mut chunk = current.length() / 2
  while chunk > 0 {
    let mut changed = false
    let mut i = 0
    while i + chunk <= current.length() {
      let candidate = invalid_fuzz_without_module_field_range(current, i, chunk)
      predicate_evaluations = predicate_evaluations + 1
      if reproduces(candidate) {
        steps.push(
          InvalidFuzzReductionStep::new(
            "delete-module-field-range",
            i,
            chunk,
            current.length(),
            candidate.length(),
          ),
        )
        current = candidate
        changed = true
      } else {
        i += 1
      }
    }
    if !changed {
      chunk = chunk / 2
    } else if chunk > current.length() {
      chunk = current.length()
    }
  }
  (current, fields.length(), current.length(), predicate_evaluations, steps)
}

///|
fn invalid_fuzz_replay_matches_report(
  replay : InvalidFuzzReplayResult,
  report : InvalidFuzzFailureReport,
) -> Bool {
  replay.stage == report.actual_stage &&
  replay.diagnostic_family == report.actual_diagnostic_family
}

///|
fn invalid_fuzz_report_with_module_field_reduction(
  report : InvalidFuzzFailureReport,
  source_path : String,
  assertion_kind : ValidateInvalidTextAssertionKind,
) -> Result[InvalidFuzzFailureReport?, String] {
  let artifact = match invalid_fuzz_choose_replay_artifact(report.artifacts) {
    Some(v) => v
    None => return Ok(None)
  }
  let source = match invalid_fuzz_bytes_string(artifact.bytes) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let (fields, message) = match
    invalid_fuzz_first_inline_assertion_fields(
      source, source_path, assertion_kind,
    ) {
    Ok(v) => v
    Err(_) => return Ok(None)
  }
  let (
    reduced_fields,
    _original_field_size,
    _final_field_size,
    predicate_evaluations,
    steps,
  ) = reduce_fuzz_module_fields_by_deletion(fields, fn(candidate_fields) {
    let candidate = match
      invalid_fuzz_inline_assertion_source(
        candidate_fields, assertion_kind, message,
      ) {
      Ok(v) => v
      Err(_) => return false
    }
    match
      invalid_fuzz_replay_text_like(
        invalid_fuzz_string_bytes(candidate),
        source_path,
        assertion_kind,
      ) {
      Ok(replay) => invalid_fuzz_replay_matches_report(replay, report)
      Err(_) => false
    }
  })
  if steps.length() == 0 {
    return Ok(None)
  }
  let reduced_text = match
    invalid_fuzz_inline_assertion_source(
      reduced_fields, assertion_kind, message,
    ) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let reduced_bytes = invalid_fuzz_string_bytes(reduced_text)
  if reduced_bytes.length() >= artifact.bytes.length() {
    return Ok(None)
  }
  let reduced = InvalidFuzzArtifact::new(
    "reduced", "reduced.wast", reduced_bytes,
  )
  Ok(
    Some(
      invalid_fuzz_failure_report_copy(
        report,
        source_path=Some(source_path),
        reduced_artifacts=[reduced],
        reduction_original_size=Some(artifact.bytes.length()),
        reduction_final_size=Some(reduced_bytes.length()),
        reduction_predicate_evaluations=Some(predicate_evaluations),
        reduction_steps=steps,
      ),
    ),
  )
}

///|
fn invalid_fuzz_report_with_text_token_reduction(
  report : InvalidFuzzFailureReport,
  source_path : String,
  assertion_kind : ValidateInvalidTextAssertionKind,
) -> Result[InvalidFuzzFailureReport?, String] {
  let artifact = match invalid_fuzz_choose_replay_artifact(report.artifacts) {
    Some(v) => v
    None => return Ok(None)
  }
  let source = match invalid_fuzz_bytes_string(artifact.bytes) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let (
    reduced_text,
    _original_token_size,
    _final_token_size,
    predicate_evaluations,
    steps,
  ) = reduce_fuzz_text_tokens_by_deletion(source, fn(candidate) {
    match
      invalid_fuzz_replay_text_like(
        invalid_fuzz_string_bytes(candidate),
        source_path,
        assertion_kind,
      ) {
      Ok(replay) => invalid_fuzz_replay_matches_report(replay, report)
      Err(_) => false
    }
  })
  let reduced_bytes = invalid_fuzz_string_bytes(reduced_text)
  if reduced_bytes.length() >= artifact.bytes.length() || steps.length() == 0 {
    return Ok(None)
  }
  let reduced = InvalidFuzzArtifact::new(
    "reduced", "reduced.wast", reduced_bytes,
  )
  Ok(
    Some(
      invalid_fuzz_failure_report_copy(
        report,
        source_path=Some(source_path),
        reduced_artifacts=[reduced],
        reduction_original_size=Some(artifact.bytes.length()),
        reduction_final_size=Some(reduced_bytes.length()),
        reduction_predicate_evaluations=Some(predicate_evaluations),
        reduction_steps=steps,
      ),
    ),
  )
}

///|
fn invalid_fuzz_report_with_reduction(
  report : InvalidFuzzFailureReport,
  reduced : InvalidFuzzArtifact,
  source_path? : String? = report.source_path,
) -> InvalidFuzzFailureReport {
  let original_size = invalid_fuzz_first_artifact_size(report.artifacts)
  let final_size = Some(reduced.bytes.length())
  let step = InvalidFuzzReductionStep::new(
    "strategy-minimal-repro",
    0,
    match (original_size, final_size) {
      (Some(before), Some(after)) =>
        if before > after {
          before - after
        } else {
          0
        }
      _ => 0
    },
    match original_size {
      Some(v) => v
      None => 0
    },
    reduced.bytes.length(),
  )
  invalid_fuzz_failure_report_copy(
    report,
    source_path~,
    reduced_artifacts=[reduced],
    reduction_original_size=original_size,
    reduction_final_size=final_size,
    reduction_predicate_evaluations=Some(2),
    reduction_steps=[step],
  )
}

///|
pub fn shrink_invalid_fuzz_failure_report(
  report : InvalidFuzzFailureReport,
) -> Result[InvalidFuzzFailureReport, String] {
  match report.source_kind {
    AstInvalidSource => {
      let reduced = match invalid_fuzz_ast_strategy_reduce(report.strategy_id) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      Ok(invalid_fuzz_report_with_reduction(report, reduced))
    }
    BinaryInvalidSource => {
      let reduced = match
        invalid_fuzz_binary_strategy_reduce(report.strategy_id) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      Ok(invalid_fuzz_report_with_reduction(report, reduced))
    }
    TextInvalidSource => {
      let (path, _, assertion_kind) = match
        validate_invalid_text_source_by_stable_id(report.strategy_id) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      let replay_path = match report.source_path {
        Some(v) => v
        None => path
      }
      match
        invalid_fuzz_report_with_module_field_reduction(
          report, replay_path, assertion_kind,
        ) {
        Ok(Some(reduced_report)) => Ok(reduced_report)
        Ok(None) =>
          match
            invalid_fuzz_report_with_text_token_reduction(
              report, replay_path, assertion_kind,
            ) {
            Ok(Some(reduced_report)) => Ok(reduced_report)
            Ok(None) => {
              let (reduced, path) = match
                invalid_fuzz_text_strategy_reduce(report.strategy_id) {
                Ok(v) => v
                Err(msg) => return Err(msg)
              }
              Ok(
                invalid_fuzz_report_with_reduction(
                  report,
                  reduced,
                  source_path=Some(path),
                ),
              )
            }
            Err(msg) => return Err(msg)
          }
        Err(msg) => return Err(msg)
      }
    }
    SpecSeedInvalidSource => {
      let (path, _, assertion_kind) = match
        validate_invalid_spec_seed_assertion_source_by_stable_id(
          report.strategy_id,
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      let replay_path = match report.source_path {
        Some(v) => v
        None => path
      }
      match
        invalid_fuzz_report_with_module_field_reduction(
          report, replay_path, assertion_kind,
        ) {
        Ok(Some(reduced_report)) => Ok(reduced_report)
        Ok(None) =>
          match
            invalid_fuzz_report_with_text_token_reduction(
              report, replay_path, assertion_kind,
            ) {
            Ok(Some(reduced_report)) => Ok(reduced_report)
            Ok(None) => {
              let (reduced, path) = match
                invalid_fuzz_spec_seed_reduce(report.strategy_id) {
                Ok(v) => v
                Err(msg) => return Err(msg)
              }
              Ok(
                invalid_fuzz_report_with_reduction(
                  report,
                  reduced,
                  source_path=Some(path),
                ),
              )
            }
            Err(msg) => return Err(msg)
          }
        Err(msg) => return Err(msg)
      }
    }
  }
}

///|
fn invalid_fuzz_binary_decode_location(
  detail : @binary.ModuleDecodeErrorDetail,
) -> String? {
  match (detail.section_offset, detail.section_len) {
    (Some(offset), Some(len)) => {
      let section_prefix = match detail.section_id {
        Some(id) => "section=\{id}:"
        None => ""
      }
      Some("binary:\{section_prefix}offset=\{offset}:length=\{len}")
    }
    _ => None
  }
}

///|
fn invalid_fuzz_replay_binary_like(bytes : Bytes) -> InvalidFuzzReplayResult {
  match decode_module_with_detail(bytes, 0) {
    Err(detail) =>
      InvalidFuzzReplayResult::new(
        "decode-rejected",
        diagnostic_location=invalid_fuzz_binary_decode_location(detail),
        message=Some("\{detail.err}"),
      )
    Ok((decoded, next)) if next != bytes.length() =>
      InvalidFuzzReplayResult::new(
        "decode-rejected",
        diagnostic_location=Some("binary:offset=\{next}:length=\{bytes.length() - next}"),
        message=Some("trailing bytes"),
      )
    Ok((decoded, _)) =>
      match validate_module(decoded) {
        Ok(_) => InvalidFuzzReplayResult::new("accepted")
        Err(err) => {
          let family = @validate.validation_issue_family(
            @validate.validation_error_diagnostic(err).issue,
          )
          InvalidFuzzReplayResult::new(
            "validate-rejected",
            diagnostic_family=Some(invalid_fuzz_family_label(family)),
            message=Some(validation_error_message(err)),
          )
        }
      }
  }
}

///|
fn invalid_fuzz_replay_text_like(
  bytes : Bytes,
  path : String,
  assertion_kind : ValidateInvalidTextAssertionKind,
) -> Result[InvalidFuzzReplayResult, String] {
  let source = match invalid_fuzz_bytes_string(bytes) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let stage = match
    evaluate_validate_invalid_text_assertion_source(
      source, path, assertion_kind,
    ) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  Ok(InvalidFuzzReplayResult::new(validate_invalid_text_stage_name(stage)))
}

///|
fn invalid_fuzz_choose_replay_artifact(
  artifacts : Array[InvalidFuzzArtifact],
) -> InvalidFuzzArtifact? {
  for artifact in artifacts {
    if artifact.label == "reduced" || artifact.label == "original" {
      return Some(artifact)
    }
  }
  if artifacts.is_empty() {
    None
  } else {
    Some(artifacts[0])
  }
}

///|
pub fn replay_invalid_fuzz_failure_report(
  report : InvalidFuzzFailureReport,
  prefer_reduced? : Bool = true,
) -> Result[InvalidFuzzReplayResult, String] {
  let candidates = if prefer_reduced && !report.reduced_artifacts.is_empty() {
    report.reduced_artifacts
  } else {
    report.artifacts
  }
  let artifact = match invalid_fuzz_choose_replay_artifact(candidates) {
    Some(v) => v
    None => return Err("invalid repro report has no artifacts to replay")
  }
  match report.source_kind {
    AstInvalidSource => Ok(invalid_fuzz_replay_binary_like(artifact.bytes))
    BinaryInvalidSource => Ok(invalid_fuzz_replay_binary_like(artifact.bytes))
    TextInvalidSource => {
      let (path, _, assertion_kind) = match
        validate_invalid_text_source_by_stable_id(report.strategy_id) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      let replay_path = match report.source_path {
        Some(v) => v
        None => path
      }
      invalid_fuzz_replay_text_like(artifact.bytes, replay_path, assertion_kind)
    }
    SpecSeedInvalidSource => {
      let (path, _, assertion_kind) = match
        validate_invalid_spec_seed_assertion_source_by_stable_id(
          report.strategy_id,
        ) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      let replay_path = match report.source_path {
        Some(v) => v
        None => path
      }
      invalid_fuzz_replay_text_like(artifact.bytes, replay_path, assertion_kind)
    }
  }
}
