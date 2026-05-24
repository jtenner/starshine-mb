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
  seed_profile : String?
  seed_mode : String?
  seed_require_strategy_prereqs : Bool?
  stream_label : String?
  stream_seed : UInt64?
  source_path : String?
  artifacts : Array[InvalidFuzzArtifact]
  reduced_artifacts : Array[InvalidFuzzArtifact]
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
  seed_profile? : String? = None,
  seed_mode? : String? = None,
  seed_require_strategy_prereqs? : Bool? = None,
  stream_label? : String? = None,
  stream_seed? : UInt64? = None,
  source_path? : String? = None,
  artifacts? : Array[InvalidFuzzArtifact] = [],
  reduced_artifacts? : Array[InvalidFuzzArtifact] = [],
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
    seed_profile,
    seed_mode,
    seed_require_strategy_prereqs,
    stream_label,
    stream_seed,
    source_path,
    artifacts,
    reduced_artifacts,
  }
}

///|
fn invalid_fuzz_failure_report_copy(
  report : InvalidFuzzFailureReport,
  source_path? : String? = report.source_path,
  reduced_artifacts? : Array[InvalidFuzzArtifact] = report.reduced_artifacts,
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
    seed_profile=report.seed_profile,
    seed_mode=report.seed_mode,
    seed_require_strategy_prereqs=report.seed_require_strategy_prereqs,
    stream_label=report.stream_label,
    stream_seed=report.stream_seed,
    source_path~,
    artifacts=report.artifacts,
    reduced_artifacts~,
  )
}

///|
pub struct InvalidFuzzReplayResult {
  stage : String
  diagnostic_family : String?
  message : String?
} derive(Eq, Debug)

///|
pub fn InvalidFuzzReplayResult::new(
  stage : String,
  diagnostic_family? : String? = None,
  message? : String? = None,
) -> InvalidFuzzReplayResult {
  { stage, diagnostic_family, message }
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
  match invalid_fuzz_optional_meta_line("source_path", report.source_path) {
    Some(line) => lines.push(line)
    None => ()
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
  for artifact in report.artifacts {
    let path = invalid_fuzz_join_path(repro_dir, artifact.file_name)
    match (io.write_file)(path, artifact.bytes) {
      Ok(_) => artifact_paths.push(path)
      Err(msg) =>
        return Err("failed to write invalid repro artifact \{path}: \{msg}")
    }
  }
  for artifact in report.reduced_artifacts {
    let path = invalid_fuzz_join_path(repro_dir, artifact.file_name)
    match (io.write_file)(path, artifact.bytes) {
      Ok(_) => artifact_paths.push(path)
      Err(msg) =>
        return Err("failed to write invalid repro artifact \{path}: \{msg}")
    }
  }
  let meta_path = invalid_fuzz_join_path(repro_dir, "repro.meta.txt")
  match
    (io.write_file)(
      meta_path,
      invalid_fuzz_string_bytes(invalid_fuzz_failure_meta_text(report)),
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
  let mut seed_profile : String? = None
  let mut seed_mode : String? = None
  let mut seed_require_strategy_prereqs : Bool? = None
  let mut stream_label : String? = None
  let mut stream_seed : UInt64? = None
  let mut source_path : String? = None
  let artifacts : Array[InvalidFuzzArtifact] = []
  let reduced_artifacts : Array[InvalidFuzzArtifact] = []
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
      "source_path" => source_path = Some(value)
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
      seed_profile~,
      seed_mode~,
      seed_require_strategy_prereqs~,
      stream_label~,
      stream_seed~,
      source_path~,
      artifacts~,
      reduced_artifacts~,
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
  let generated = match
    @validate.gen_invalid_ast_generate(@splitmix.new(seed~), resolved_params) {
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
      seed_profile=Some(
        @validate.gen_invalid_ast_params_profile_name(resolved_params),
      ),
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
  let generated = match
    gen_invalid_binary_generate(@splitmix.new(seed~), resolved_params) {
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
      seed_profile=Some(gen_invalid_binary_params_profile_name(resolved_params)),
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
pub fn shrink_invalid_fuzz_failure_report(
  report : InvalidFuzzFailureReport,
) -> Result[InvalidFuzzFailureReport, String] {
  match report.source_kind {
    AstInvalidSource => {
      let reduced = match invalid_fuzz_ast_strategy_reduce(report.strategy_id) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      Ok(invalid_fuzz_failure_report_copy(report, reduced_artifacts=[reduced]))
    }
    BinaryInvalidSource => {
      let reduced = match
        invalid_fuzz_binary_strategy_reduce(report.strategy_id) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      Ok(invalid_fuzz_failure_report_copy(report, reduced_artifacts=[reduced]))
    }
    TextInvalidSource => {
      let (reduced, path) = match
        invalid_fuzz_text_strategy_reduce(report.strategy_id) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      Ok(
        invalid_fuzz_failure_report_copy(report, source_path=Some(path), reduced_artifacts=[
          reduced,
        ]),
      )
    }
    SpecSeedInvalidSource => {
      let (reduced, path) = match
        invalid_fuzz_spec_seed_reduce(report.strategy_id) {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      Ok(
        invalid_fuzz_failure_report_copy(report, source_path=Some(path), reduced_artifacts=[
          reduced,
        ]),
      )
    }
  }
}

///|
fn invalid_fuzz_replay_binary_like(bytes : Bytes) -> InvalidFuzzReplayResult {
  match decode_module(bytes) {
    Err(msg) =>
      InvalidFuzzReplayResult::new("decode-rejected", message=Some("\{msg}"))
    Ok(decoded) =>
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
