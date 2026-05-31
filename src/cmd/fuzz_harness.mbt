///|
pub struct DifferentialAdapters {
  wasm_tools_validate : (Bytes) -> Result[Bool, String]
  binaryen_validate : (Bytes) -> Result[Bool, String]
  per_case_timeout_ms : Int?
}

///|
pub fn DifferentialAdapters::new(
  wasm_tools_validate? : (Bytes) -> Result[Bool, String] = fn(_) {
    Err("wasm-tools differential validator unavailable")
  },
  binaryen_validate? : (Bytes) -> Result[Bool, String] = fn(_) {
    Err("binaryen differential validator unavailable")
  },
  per_case_timeout_ms? : Int? = None,
) -> DifferentialAdapters {
  { wasm_tools_validate, binaryen_validate, per_case_timeout_ms }
}

///|
pub struct DifferentialValidationReport {
  internal_valid : Bool
  wasm_tools_valid : Bool?
  binaryen_valid : Bool?
  per_case_timeout_ms : Int?
  wasm_tools_timeout : Bool
  binaryen_timeout : Bool
} derive(Eq, Debug)

///|
pub impl Show for DifferentialValidationReport with output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
pub enum BinaryCanonicalityInputClass {
  CanonicalInput
  AcceptedNoncanonicalInput
  MalformedInput
} derive(Eq, Debug)

///|
pub enum BinaryCanonicalityClassification {
  CanonicalAccepted
  AcceptedNoncanonical
  MalformedRejected
  ExternalPolicyDisagreement
  DecoderBugDisagreement
} derive(Eq, Debug)

///|
pub fn BinaryCanonicalityInputClass::canonical() -> BinaryCanonicalityInputClass {
  CanonicalInput
}

///|
pub fn BinaryCanonicalityInputClass::accepted_noncanonical() -> BinaryCanonicalityInputClass {
  AcceptedNoncanonicalInput
}

///|
pub fn BinaryCanonicalityInputClass::malformed() -> BinaryCanonicalityInputClass {
  MalformedInput
}

///|
pub fn BinaryCanonicalityClassification::canonical_accepted() -> BinaryCanonicalityClassification {
  CanonicalAccepted
}

///|
pub fn BinaryCanonicalityClassification::accepted_noncanonical() -> BinaryCanonicalityClassification {
  AcceptedNoncanonical
}

///|
pub fn BinaryCanonicalityClassification::malformed_rejected() -> BinaryCanonicalityClassification {
  MalformedRejected
}

///|
pub fn BinaryCanonicalityClassification::external_policy_disagreement() -> BinaryCanonicalityClassification {
  ExternalPolicyDisagreement
}

///|
pub fn BinaryCanonicalityClassification::decoder_bug_disagreement() -> BinaryCanonicalityClassification {
  DecoderBugDisagreement
}

///|
fn binary_canonicality_external_disagrees(
  internal_valid : Bool,
  wasm_tools_valid : Bool?,
  binaryen_valid : Bool?,
) -> Bool {
  match wasm_tools_valid {
    Some(v) => if v != internal_valid { return true }
    None => ()
  }
  match binaryen_valid {
    Some(v) => if v != internal_valid { return true }
    None => ()
  }
  false
}

///|
pub fn classify_binary_canonicality_differential(
  input_class : BinaryCanonicalityInputClass,
  internal_valid : Bool,
  wasm_tools_valid : Bool?,
  binaryen_valid : Bool?,
) -> BinaryCanonicalityClassification {
  if binary_canonicality_external_disagrees(
      internal_valid, wasm_tools_valid, binaryen_valid,
    ) {
    match input_class {
      AcceptedNoncanonicalInput => ExternalPolicyDisagreement
      _ => DecoderBugDisagreement
    }
  } else {
    match input_class {
      CanonicalInput => CanonicalAccepted
      AcceptedNoncanonicalInput => AcceptedNoncanonical
      MalformedInput => MalformedRejected
    }
  }
}

///|
pub struct BinaryCanonicalitySummary {
  total : Int
  canonical : Int
  accepted_noncanonical : Int
  malformed_rejected : Int
  external_policy_disagreements : Int
  decoder_bug_disagreements : Int
} derive(Eq, Debug)

///|
pub fn summarize_binary_canonicality_classifications(
  classifications : Array[BinaryCanonicalityClassification],
) -> BinaryCanonicalitySummary {
  let mut canonical = 0
  let mut accepted_noncanonical = 0
  let mut malformed_rejected = 0
  let mut external_policy_disagreements = 0
  let mut decoder_bug_disagreements = 0
  for classification in classifications {
    match classification {
      CanonicalAccepted => canonical = canonical + 1
      AcceptedNoncanonical => accepted_noncanonical = accepted_noncanonical + 1
      MalformedRejected => malformed_rejected = malformed_rejected + 1
      ExternalPolicyDisagreement =>
        external_policy_disagreements = external_policy_disagreements + 1
      DecoderBugDisagreement =>
        decoder_bug_disagreements = decoder_bug_disagreements + 1
    }
  }
  {
    total: classifications.length(),
    canonical,
    accepted_noncanonical,
    malformed_rejected,
    external_policy_disagreements,
    decoder_bug_disagreements,
  }
}

///|
pub enum ExportInvocationResult {
  Value(String)
  Trap(String)
  UnsupportedRuntime(String)
  NondeterministicImport(String)
} derive(Eq, Debug)

///|
pub fn ExportInvocationResult::value(value : String) -> ExportInvocationResult {
  Value(value)
}

///|
pub fn ExportInvocationResult::trap(message : String) -> ExportInvocationResult {
  Trap(message)
}

///|
pub fn ExportInvocationResult::unsupported_runtime(
  message : String,
) -> ExportInvocationResult {
  UnsupportedRuntime(message)
}

///|
pub fn ExportInvocationResult::nondeterministic_import(
  import_name : String,
) -> ExportInvocationResult {
  NondeterministicImport(import_name)
}

///|
pub enum ExportInvocationClassification {
  EqualResult
  EqualTrap
  UnsupportedRuntime
  NondeterministicImport
  SemanticMismatch(String)
} derive(Eq, Debug)

///|
pub struct ExportInvocationComparisonReport {
  export_name : String
  args : Array[String]
  left_result : ExportInvocationResult
  right_result : ExportInvocationResult
  classification : ExportInvocationClassification
} derive(Eq, Debug)

///|
pub struct ExportInvocationMatrixSummary {
  total : Int
  equal_results : Int
  equal_traps : Int
  unsupported_runtimes : Int
  nondeterministic_imports : Int
  semantic_mismatches : Int
} derive(Eq, Debug)

///|
pub enum ExportInvocationMatrixOutcome {
  Empty
  AllEqual
  Blocked
  SemanticMismatch
} derive(Eq, Debug)

///|
pub fn ExportInvocationClassification::equal_result() -> ExportInvocationClassification {
  EqualResult
}

///|
pub fn ExportInvocationClassification::equal_trap() -> ExportInvocationClassification {
  EqualTrap
}

///|
pub fn ExportInvocationClassification::unsupported_runtime() -> ExportInvocationClassification {
  UnsupportedRuntime
}

///|
pub fn ExportInvocationClassification::nondeterministic_import() -> ExportInvocationClassification {
  NondeterministicImport
}

///|
pub fn ExportInvocationClassification::semantic_mismatch(
  message : String,
) -> ExportInvocationClassification {
  SemanticMismatch(message)
}

///|
pub fn ExportInvocationMatrixOutcome::empty() -> ExportInvocationMatrixOutcome {
  Empty
}

///|
pub fn ExportInvocationMatrixOutcome::all_equal() -> ExportInvocationMatrixOutcome {
  AllEqual
}

///|
pub fn ExportInvocationMatrixOutcome::blocked() -> ExportInvocationMatrixOutcome {
  Blocked
}

///|
pub fn ExportInvocationMatrixOutcome::semantic_mismatch() -> ExportInvocationMatrixOutcome {
  SemanticMismatch
}

///|
pub fn choose_simple_export_invocation_args(
  params : Array[@lib.ValType],
) -> Result[Array[String], String] {
  let args = Array::new(capacity=params.length())
  for param in params {
    match param {
      @lib.NumTypeValType(@lib.I32NumType) => args.push("i32:0")
      @lib.NumTypeValType(@lib.I64NumType) => args.push("i64:0")
      @lib.NumTypeValType(@lib.F32NumType) => args.push("f32:0")
      @lib.NumTypeValType(@lib.F64NumType) => args.push("f64:0")
      other =>
        return Err(
          "unsupported export param type for simple invocation: \{@debug.to_string(other)}",
        )
    }
  }
  Ok(args)
}

///|
pub fn classify_export_invocation_results(
  left : ExportInvocationResult,
  right : ExportInvocationResult,
) -> ExportInvocationClassification {
  match (left, right) {
    (UnsupportedRuntime(_), _) | (_, UnsupportedRuntime(_)) =>
      UnsupportedRuntime
    (NondeterministicImport(_), _) | (_, NondeterministicImport(_)) =>
      NondeterministicImport
    (Trap(_), Trap(_)) => EqualTrap
    (Value(a), Value(b)) =>
      if a == b {
        EqualResult
      } else {
        SemanticMismatch("value mismatch: left=\{a} right=\{b}")
      }
    (Trap(a), Value(b)) =>
      SemanticMismatch("trap/value mismatch: left=\{a} right=\{b}")
    (Value(a), Trap(b)) =>
      SemanticMismatch("value/trap mismatch: left=\{a} right=\{b}")
  }
}

///|
pub fn compare_export_invocation_results(
  export_name : String,
  args : Array[String],
  left : ExportInvocationResult,
  right : ExportInvocationResult,
) -> ExportInvocationComparisonReport {
  ExportInvocationComparisonReport::{
    export_name,
    args,
    left_result: left,
    right_result: right,
    classification: classify_export_invocation_results(left, right),
  }
}

///|
pub fn summarize_export_invocation_matrix(
  reports : Array[ExportInvocationComparisonReport],
) -> ExportInvocationMatrixSummary {
  let mut equal_results = 0
  let mut equal_traps = 0
  let mut unsupported_runtimes = 0
  let mut nondeterministic_imports = 0
  let mut semantic_mismatches = 0
  for report in reports {
    match report.classification {
      EqualResult => equal_results = equal_results + 1
      EqualTrap => equal_traps = equal_traps + 1
      UnsupportedRuntime => unsupported_runtimes = unsupported_runtimes + 1
      NondeterministicImport =>
        nondeterministic_imports = nondeterministic_imports + 1
      SemanticMismatch(_) => semantic_mismatches = semantic_mismatches + 1
    }
  }
  ExportInvocationMatrixSummary::{
    total: reports.length(),
    equal_results,
    equal_traps,
    unsupported_runtimes,
    nondeterministic_imports,
    semantic_mismatches,
  }
}

///|
pub fn export_invocation_summary_has_semantic_mismatch(
  summary : ExportInvocationMatrixSummary,
) -> Bool {
  summary.semantic_mismatches > 0
}

///|
pub fn classify_export_invocation_matrix(
  summary : ExportInvocationMatrixSummary,
) -> ExportInvocationMatrixOutcome {
  if summary.total == 0 {
    Empty
  } else if summary.semantic_mismatches > 0 {
    SemanticMismatch
  } else if summary.unsupported_runtimes > 0 ||
    summary.nondeterministic_imports > 0 {
    Blocked
  } else {
    AllEqual
  }
}

///|
pub fn export_invocation_semantic_mismatch_reports(
  reports : Array[ExportInvocationComparisonReport],
) -> Array[ExportInvocationComparisonReport] {
  let mismatches = Array::new()
  for report in reports {
    match report.classification {
      SemanticMismatch(_) => mismatches.push(report)
      _ => ()
    }
  }
  mismatches
}

///|
pub struct CmdFuzzStats {
  attempts : Int
  generated_valid : Int
  generated_invalid : Int
  pipeline_validated : Int
  optimized : Int
  roundtripped : Int
  differential_checked : Int
  optimize_idempotence_checked : Int
  encode_decode_idempotence_checked : Int
  generator_profile : String
  pass_profile : String
} derive(Eq, Debug)

///|
pub impl Show for CmdFuzzStats with output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
pub fn CmdFuzzStats::new(
  attempts? : Int = 0,
  generated_valid? : Int = 0,
  generated_invalid? : Int = 0,
  pipeline_validated? : Int = 0,
  optimized? : Int = 0,
  roundtripped? : Int = 0,
  differential_checked? : Int = 0,
  optimize_idempotence_checked? : Int = 0,
  encode_decode_idempotence_checked? : Int = 0,
  generator_profile? : String = "natural-wide",
  pass_profile? : String = "custom",
) -> CmdFuzzStats {
  {
    attempts,
    generated_valid,
    generated_invalid,
    pipeline_validated,
    optimized,
    roundtripped,
    differential_checked,
    optimize_idempotence_checked,
    encode_decode_idempotence_checked,
    generator_profile,
    pass_profile,
  }
}

///|
pub struct FuzzFailureReport {
  seed : UInt64
  attempt : Int
  generated_valid : Int
  stage : String
  message : String
  optimize_passes : Array[String]
  minimized_passes : Array[String]
  generator_profile : String
  pass_profile : String
  generator_config_label : String
  generated_attempts : Int
  feature_facts : String
  wasm : Bytes?
} derive(Eq, Debug)

///|
pub struct FuzzCorpusSource {
  seed : UInt64
  attempt : Int
  generator_profile : String
  pass_profile : String
  stage : String
} derive(Eq, Debug)

///|
pub fn FuzzCorpusSource::new(
  seed : UInt64,
  attempt : Int,
  generator_profile : String,
  pass_profile : String,
  stage : String,
) -> FuzzCorpusSource {
  { seed, attempt, generator_profile, pass_profile, stage }
}

///|
pub struct FuzzCorpusDedupDecision {
  hash : String
  duplicate : Bool
  canonical_seed : UInt64?
} derive(Eq, Debug)

///|
struct FuzzCorpusDedupSourceEntry {
  source : FuzzCorpusSource
  duplicate : Bool
  canonical_seed : UInt64
} derive(Eq, Debug)

///|
struct FuzzCorpusDedupHashEntry {
  hash : String
  canonical_seed : UInt64
  sources : Array[FuzzCorpusDedupSourceEntry]
} derive(Eq, Debug)

///|
pub struct FuzzCorpusDedupIndex {
  entries : Array[FuzzCorpusDedupHashEntry]
  positions : @hashmap.HashMap[String, Int]
} derive(Debug)

///|
pub fn FuzzCorpusDedupIndex::new() -> FuzzCorpusDedupIndex {
  { entries: [], positions: @hashmap.new(capacity=64) }
}

///|
pub impl Show for FuzzFailureReport with output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
pub fn FuzzFailureReport::new(
  seed : UInt64,
  attempt : Int,
  generated_valid : Int,
  stage : String,
  message : String,
  optimize_passes? : Array[String] = [],
  minimized_passes? : Array[String] = [],
  generator_profile? : String = "natural-wide",
  pass_profile? : String = "custom",
  generator_config_label? : String = "unknown",
  generated_attempts? : Int = 0,
  feature_facts? : String = "unknown",
  wasm? : Bytes? = None,
) -> FuzzFailureReport {
  {
    seed,
    attempt,
    generated_valid,
    stage,
    message,
    optimize_passes,
    minimized_passes,
    generator_profile,
    pass_profile,
    generator_config_label,
    generated_attempts,
    feature_facts,
    wasm,
  }
}

///|
pub struct FuzzFailurePersistIO {
  ensure_dir : (String) -> Result[Unit, String]
  write_file : (String, Bytes) -> Result[Unit, String]
}

///|
pub fn FuzzFailurePersistIO::new(
  ensure_dir? : (String) -> Result[Unit, String] = fn(path) {
    Err("ensure_dir not configured: \{path}")
  },
  write_file? : (String, Bytes) -> Result[Unit, String] = fn(path, _) {
    Err("write_file not configured: \{path}")
  },
) -> FuzzFailurePersistIO {
  { ensure_dir, write_file }
}

///|
fn fuzz_clone_passes(values : Array[String]) -> Array[String] {
  let out = Array::new(capacity=values.length())
  for value in values {
    out.push(value)
  }
  out
}

///|
fn fuzz_without_pass_index(values : Array[String], skip : Int) -> Array[String] {
  let out = Array::new(capacity=values.length())
  let mut i = 0
  while i < values.length() {
    if i != skip {
      out.push(values[i])
    }
    i += 1
  }
  out
}

///|
fn fuzz_without_pass_range(
  values : Array[String],
  start : Int,
  len : Int,
) -> Array[String] {
  let out = Array::new(capacity=values.length())
  let end = start + len
  let mut i = 0
  while i < values.length() {
    if i < start || i >= end {
      out.push(values[i])
    }
    i += 1
  }
  out
}

///|
pub fn minimize_fuzz_passes(
  passes : Array[String],
  reproduces : (Array[String]) -> Bool,
) -> Array[String] {
  if !reproduces(passes) {
    return fuzz_clone_passes(passes)
  }
  let mut current = fuzz_clone_passes(passes)
  let mut chunk = current.length() / 2
  while chunk > 0 {
    let mut changed = false
    let mut i = 0
    while i + chunk <= current.length() {
      let candidate = fuzz_without_pass_range(current, i, chunk)
      if reproduces(candidate) {
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
  let mut i = 0
  while i < current.length() {
    let candidate = fuzz_without_pass_index(current, i)
    if reproduces(candidate) {
      current = candidate
    } else {
      i += 1
    }
  }
  current
}

///|
pub struct CmdFuzzHarnessProfileConfig {
  valid_target : Int
  generator_profile : String
  generator_config : GenValidConfig
  pass_profile : String
  optimize_passes : Array[String]
  check_optimize_idempotence : Bool
  check_encode_decode_idempotence : Bool
} derive(Eq, Debug)

///|
fn cmd_fuzz_is_policy_pass(name : String) -> Bool {
  name == "no-inline" || name == "no-full-inline" || name == "no-partial-inline"
}

///|
fn cmd_fuzz_each_pass_profile() -> Array[String] {
  let passes : Array[String] = []
  for entry in @passes.pass_registry_all() {
    match entry.category {
      @passes.HotPassRegistryCategory::HotPass
      | @passes.HotPassRegistryCategory::ModulePass =>
        if !cmd_fuzz_is_policy_pass(entry.name) {
          passes.push(entry.name)
        }
      _ => ()
    }
  }
  passes
}

///|
fn cmd_fuzz_default_pipeline_profile() -> Result[Array[String], String] {
  match @passes.pass_registry_lookup("optimize") {
    Some(entry) => Ok(entry.expanded_passes)
    None =>
      Err("cmd-harness default-pipeline profile could not find optimize preset")
  }
}

///|
fn cmd_fuzz_common_cluster_profile() -> Array[String] {
  [
    "dead-code-elimination", "remove-unused-names", "remove-unused-brs", "vacuum",
    "merge-blocks", "remove-unused-brs", "vacuum",
  ]
}

///|
fn cmd_fuzz_pass_profile(profile : String) -> Result[Array[String], String] {
  match profile {
    "none" => Ok([])
    "cleanup" => Ok(["vacuum", "remove-unused-brs"])
    "optimize-core" => Ok(["optimize-instructions", "precompute", "vacuum"])
    "each-pass" => Ok(cmd_fuzz_each_pass_profile())
    "common-cluster" | "common-clusters" =>
      Ok(cmd_fuzz_common_cluster_profile())
    "default-pipeline" => cmd_fuzz_default_pipeline_profile()
    _ =>
      Err(
        "unknown cmd-harness pass profile '\{profile}'; expected none|cleanup|optimize-core|each-pass|common-clusters|default-pipeline",
      )
  }
}

///|
pub fn cmd_fuzz_harness_profile_config(
  profile : String,
) -> Result[CmdFuzzHarnessProfileConfig, String] {
  let raw = profile.trim().to_owned()
  let parts : Array[String] = []
  for part in raw.split("+") {
    parts.push(part.to_owned())
  }
  let base = if parts.length() == 0 || parts[0].trim().to_owned().length() == 0 {
    "smoke"
  } else {
    fuzz_profile_ascii_lower(parts[0].trim().to_owned())
  }
  let valid_target = match base {
    "smoke" => 128
    "ci" => 4096
    "stress" => 100000
    _ =>
      return Err(
        "unknown cmd-harness fuzz profile '\{profile}'; expected smoke|ci|stress",
      )
  }
  let mut generator_profile = "natural-wide"
  let mut pass_profile = "none"
  let mut check_optimize_idempotence = false
  let mut check_encode_decode_idempotence = false
  let mut i = 1
  while i < parts.length() {
    let part = fuzz_profile_ascii_lower(parts[i].trim().to_owned())
    if part.length() == 0 {
      ()
    } else if fuzz_has_prefix(part, "gen=") {
      generator_profile = part.sub(start=4).to_owned()
    } else if fuzz_has_prefix(part, "generator=") {
      generator_profile = part.sub(start=10).to_owned()
    } else if fuzz_has_prefix(part, "passes=") {
      pass_profile = part.sub(start=7).to_owned()
    } else if part == "idempotence" || part == "opt-idempotence" {
      check_optimize_idempotence = true
    } else if part == "codec-idempotence" || part == "encode-decode-idempotence" {
      check_encode_decode_idempotence = true
    } else {
      return Err(
        "unknown cmd-harness profile modifier '\{parts[i]}' in '\{profile}'",
      )
    }
    i += 1
  }
  let generator_config = match GenValidConfig::profile(generator_profile) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let pass_profile = match pass_profile {
    "common-cluster" => "common-clusters"
    _ => pass_profile
  }
  let optimize_passes = match cmd_fuzz_pass_profile(pass_profile) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  Ok({
    valid_target,
    generator_profile,
    generator_config,
    pass_profile,
    optimize_passes,
    check_optimize_idempotence,
    check_encode_decode_idempotence,
  })
}

///|
fn fuzz_has_prefix(text : String, prefix : String) -> Bool {
  if text.length() < prefix.length() {
    return false
  }
  let head = text.sub(end=prefix.length()).to_owned()
  head == prefix
}

///|
fn fuzz_has_suffix(text : String, suffix : String) -> Bool {
  if text.length() < suffix.length() {
    return false
  }
  let start = text.length() - suffix.length()
  let tail = text.sub(start~).to_owned()
  tail == suffix
}

///|
fn fuzz_bytes_from_string(text : String) -> Bytes {
  let buf = @buffer.new(size_hint=text.length())
  for c in text {
    buf.write_byte(c.to_int().to_byte())
  }
  buf.to_bytes()
}

///|
fn fuzz_corpus_hash_bytes(bytes : Bytes) -> String {
  let mut hash = 1469598103934665603UL
  let prime = 1099511628211UL
  let mut i = 0
  while i < bytes.length() {
    hash = (hash ^ bytes[i].to_uint64()) * prime
    i += 1
  }
  "fnv1a64-\{hash}"
}

///|
pub fn FuzzCorpusDedupIndex::record(
  self : FuzzCorpusDedupIndex,
  wasm : Bytes,
  source : FuzzCorpusSource,
) -> FuzzCorpusDedupDecision {
  let hash = fuzz_corpus_hash_bytes(wasm)
  match self.positions.get(hash) {
    Some(pos) => {
      let canonical_seed = self.entries[pos].canonical_seed
      self.entries[pos].sources.push({ source, duplicate: true, canonical_seed })
      { hash, duplicate: true, canonical_seed: Some(canonical_seed) }
    }
    None => {
      let canonical_seed = source.seed
      let sources = [{ source, duplicate: false, canonical_seed }]
      self.positions.set(hash, self.entries.length())
      self.entries.push({ hash, canonical_seed, sources })
      { hash, duplicate: false, canonical_seed: Some(canonical_seed) }
    }
  }
}

///|
pub fn FuzzCorpusDedupIndex::to_text(self : FuzzCorpusDedupIndex) -> String {
  let out = StringBuilder::new()
  out.write_string("version=1\n")
  for entry in self.entries {
    out.write_string(
      "hash=\{entry.hash} canonical_seed=\{entry.canonical_seed}\n",
    )
    for source_entry in entry.sources {
      let source = source_entry.source
      out.write_string(
        "source seed=\{source.seed} attempt=\{source.attempt} generator_profile=\{source.generator_profile} pass_profile=\{source.pass_profile} stage=\{source.stage} duplicate=\{source_entry.duplicate} canonical_seed=\{source_entry.canonical_seed}\n",
      )
    }
  }
  out.to_string()
}

///|
fn fuzz_single_line(text : String) -> String {
  let out = StringBuilder::new()
  for c in text {
    if c == '\n' || c == '\r' {
      out.write_char(' ')
    } else {
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
fn fuzz_join_csv(values : Array[String]) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  while i < values.length() {
    if i > 0 {
      out.write_char(',')
    }
    out.write_string(values[i])
    i += 1
  }
  out.to_string()
}

///|
fn fuzz_slug(value : String) -> String {
  let out = StringBuilder::new()
  let mut wrote_dash = false
  for c in value {
    let lower = if c >= 'A' && c <= 'Z' {
      (c.to_int() + 32).unsafe_to_char()
    } else {
      c
    }
    let is_alnum = (lower >= 'a' && lower <= 'z') ||
      (lower >= '0' && lower <= '9')
    if is_alnum {
      out.write_char(lower)
      wrote_dash = false
    } else if !wrote_dash {
      out.write_char('-')
      wrote_dash = true
    }
  }
  let raw = out.to_string()
  let trimmed = if fuzz_has_prefix(raw, "-") {
    raw.sub(start=1).to_owned()
  } else {
    raw
  }
  let cleaned = if fuzz_has_suffix(trimmed, "-") {
    trimmed.sub(end=trimmed.length() - 1).to_owned()
  } else {
    trimmed
  }
  if cleaned.length() == 0 {
    "unknown"
  } else {
    cleaned
  }
}

///|
fn fuzz_failure_meta_text(report : FuzzFailureReport) -> String {
  let out = StringBuilder::new()
  out.write_string("seed=\{report.seed}\n")
  out.write_string("attempt=\{report.attempt}\n")
  out.write_string("generated_valid=\{report.generated_valid}\n")
  out.write_string("stage=\{fuzz_single_line(report.stage)}\n")
  out.write_string("message=\{fuzz_single_line(report.message)}\n")
  out.write_string("optimize_passes=\{fuzz_join_csv(report.optimize_passes)}\n")
  out.write_string(
    "minimized_passes=\{fuzz_join_csv(report.minimized_passes)}\n",
  )
  out.write_string("generator_profile=\{report.generator_profile}\n")
  out.write_string("pass_profile=\{report.pass_profile}\n")
  out.write_string("generator_config_label=\{report.generator_config_label}\n")
  out.write_string("generated_attempts=\{report.generated_attempts}\n")
  out.write_string("feature_facts=\{fuzz_single_line(report.feature_facts)}\n")
  out.to_string()
}

///|
pub fn persist_fuzz_failure_report(
  report : FuzzFailureReport,
  io : FuzzFailurePersistIO,
  corpus_dir? : String = "fuzz-corpus",
) -> Result[(String, String?), String] {
  let trimmed = corpus_dir.trim().to_owned()
  let dir = if trimmed.length() == 0 { "fuzz-corpus" } else { trimmed }
  match (io.ensure_dir)(dir) {
    Ok(_) => ()
    Err(e) => return Err("failed to ensure corpus dir \{dir}: \{e}")
  }
  let slug = fuzz_slug(report.stage)
  let prefix = "\{dir}/seed-\{report.seed}-attempt-\{report.attempt}-valid-\{report.generated_valid}-\{slug}"
  let meta_path = "\{prefix}.meta.txt"
  let meta_bytes = fuzz_bytes_from_string(fuzz_failure_meta_text(report))
  match (io.write_file)(meta_path, meta_bytes) {
    Ok(_) => ()
    Err(e) => return Err("failed to write corpus metadata \{meta_path}: \{e}")
  }
  let wasm_path = match report.wasm {
    Some(bytes) => {
      let path = "\{prefix}.wasm"
      match (io.write_file)(path, bytes) {
        Ok(_) => Some(path)
        Err(e) => return Err("failed to write corpus wasm \{path}: \{e}")
      }
    }
    None => None
  }
  Ok((meta_path, wasm_path))
}

///|
fn fuzz_finalize_failure(
  on_failure : ((FuzzFailureReport) -> Result[Unit, String])?,
  report : FuzzFailureReport,
  message : String,
) -> String {
  match on_failure {
    Some(cb) =>
      match cb(report) {
        Ok(_) => message
        Err(e) => "\{message}; failure callback error: \{e}"
      }
    None => message
  }
}

///|
fn fuzz_bytes_equal(lhs : Bytes, rhs : Bytes) -> Bool {
  if lhs.length() != rhs.length() {
    return false
  }
  let mut i = 0
  while i < lhs.length() {
    if lhs[i] != rhs[i] {
      return false
    }
    i += 1
  }
  true
}

///|
fn decode_then_validate(bytes : Bytes) -> Result[Bool, String] {
  match decode_module(bytes) {
    Ok(mod) =>
      match validate_module(mod) {
        Ok(_) => Ok(true)
        Err(_) => Ok(false)
      }
    Err(_) => Ok(false)
  }
}

///|
fn fuzz_minimize_optimize_failure(
  bytes : Bytes,
  passes : Array[String],
) -> Array[String] {
  minimize_fuzz_passes(passes, fn(candidate) {
    match decode_module(bytes) {
      Ok(mod) =>
        match
          optimize_module_with_pass_flags(
            mod,
            candidate,
            OptimizeOptions::new(),
          ) {
          Ok(_) => false
          Err(_) => true
        }
      Err(_) => false
    }
  })
}

///|
fn differential_adapter_ascii_lower(input : String) -> String {
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
fn differential_adapter_error_is_timeout(msg : String) -> Bool {
  let lower = differential_adapter_ascii_lower(msg)
  lower.contains("timeout") ||
  lower.contains("timed out") ||
  lower.contains("resource limit")
}

///|
pub fn differential_validate_wasm(
  bytes : Bytes,
  adapters? : DifferentialAdapters = default_differential_adapters(),
) -> Result[DifferentialValidationReport, String] {
  let internal_valid = match decode_then_validate(bytes) {
    Ok(v) => v
    Err(e) => return Err("internal validation execution failed: \{e}")
  }
  let mut wasm_tools_timeout = false
  let wasm_tools_valid = match (adapters.wasm_tools_validate)(bytes) {
    Ok(v) => Some(v)
    Err(msg) => {
      wasm_tools_timeout = differential_adapter_error_is_timeout(msg)
      None
    }
  }
  let mut binaryen_timeout = false
  let binaryen_valid = match (adapters.binaryen_validate)(bytes) {
    Ok(v) => Some(v)
    Err(msg) => {
      binaryen_timeout = differential_adapter_error_is_timeout(msg)
      None
    }
  }

  match wasm_tools_valid {
    Some(v) =>
      if v != internal_valid {
        return Err(
          "differential mismatch against wasm-tools: internal=\{internal_valid} wasm-tools=\{v}",
        )
      }
    None => ()
  }
  match binaryen_valid {
    Some(v) =>
      if v != internal_valid {
        return Err(
          "differential mismatch against binaryen: internal=\{internal_valid} binaryen=\{v}",
        )
      }
    None => ()
  }
  Ok(DifferentialValidationReport::{
    internal_valid,
    wasm_tools_valid,
    binaryen_valid,
    per_case_timeout_ms: adapters.per_case_timeout_ms,
    wasm_tools_timeout,
    binaryen_timeout,
  })
}

///|
pub fn run_cmd_fuzz_harness(
  valid_target : Int,
  seed? : UInt64 = 0x5eedUL,
  optimize_passes? : Array[String] = [],
  generator_profile? : String = "natural-wide",
  generator_config? : GenValidConfig? = None,
  pass_profile? : String = "custom",
  check_optimize_idempotence? : Bool = false,
  check_encode_decode_idempotence? : Bool = false,
  differential_adapters? : DifferentialAdapters? = None,
  differential_every? : Int = 0,
  on_failure? : ((FuzzFailureReport) -> Result[Unit, String])? = None,
) -> Result[CmdFuzzStats, String] {
  let pass_names = fuzz_clone_passes(optimize_passes)
  let gen_config = match generator_config {
    Some(config) => config
    None =>
      match GenValidConfig::profile(generator_profile) {
        Ok(config) => config
        Err(msg) => return Err(msg)
      }
  }
  let gen_profile_label = generator_profile
  if valid_target < 0 {
    let report = FuzzFailureReport::new(
      seed,
      0,
      0,
      "config",
      "valid_target must be non-negative",
      optimize_passes=pass_names,
      minimized_passes=pass_names,
      generator_profile=gen_profile_label,
      pass_profile~,
    )
    return Err(
      fuzz_finalize_failure(
        on_failure, report, "valid_target must be non-negative",
      ),
    )
  }
  let rnd = @splitmix.new(seed~)
  let mut attempts = 0
  let mut generated_valid = 0
  let mut generated_invalid = 0
  let mut pipeline_validated = 0
  let mut optimized_count = 0
  let mut roundtripped = 0
  let mut differential_checked = 0
  let mut optimize_idempotence_checked = 0
  let mut encode_decode_idempotence_checked = 0
  let max_attempts = if valid_target <= 0 { 0 } else { valid_target * 25 }

  while generated_valid < valid_target {
    if attempts >= max_attempts {
      let msg = "failed to reach valid target: target=\{valid_target} attempts=\{attempts} valid=\{generated_valid} invalid=\{generated_invalid}"
      let report = FuzzFailureReport::new(
        seed,
        attempts,
        generated_valid,
        "generation-target",
        msg,
        optimize_passes=pass_names,
        minimized_passes=pass_names,
        generator_profile=gen_profile_label,
        pass_profile~,
      )
      return Err(fuzz_finalize_failure(on_failure, report, msg))
    }
    attempts += 1
    let generated = match gen_valid_module_result(rnd, gen_config) {
      Ok(v) => v
      Err(_) => {
        generated_invalid += 1
        continue
      }
    }
    let generated_config_label = generated.config_label
    let generated_attempts = generated.attempts
    let feature_facts = @debug.to_string(generated.facts)
    let mod = generated.wasm_module
    match validate_module(mod) {
      Ok(_) => ()
      Err(_) => {
        generated_invalid += 1
        continue
      }
    }
    let encoded = match encode_module(mod) {
      Ok(bytes) => bytes
      Err(_) => {
        generated_invalid += 1
        continue
      }
    }
    let decoded = match decode_module(encoded) {
      Ok(decoded_mod) => decoded_mod
      Err(e) => {
        let msg = "decode failed at attempt #\{attempts}: \{e}"
        let report = FuzzFailureReport::new(
          seed,
          attempts,
          generated_valid,
          "decode",
          "\{e}",
          optimize_passes=pass_names,
          minimized_passes=pass_names,
          generator_profile=gen_profile_label,
          pass_profile~,
          generator_config_label=generated_config_label,
          generated_attempts~,
          feature_facts~,
          wasm=Some(encoded),
        )
        return Err(fuzz_finalize_failure(on_failure, report, msg))
      }
    }
    if check_encode_decode_idempotence {
      let recoded = match encode_module(decoded) {
        Ok(bytes) => bytes
        Err(e) => {
          let msg = "encode/decode idempotence encode failed at attempt #\{attempts}: \{e}"
          let report = FuzzFailureReport::new(
            seed,
            attempts,
            generated_valid,
            "encode-decode-idempotence",
            "\{e}",
            optimize_passes=pass_names,
            minimized_passes=pass_names,
            generator_profile=gen_profile_label,
            pass_profile~,
            generator_config_label=generated_config_label,
            generated_attempts~,
            feature_facts~,
            wasm=Some(encoded),
          )
          return Err(fuzz_finalize_failure(on_failure, report, msg))
        }
      }
      let recoded_mod = match decode_module(recoded) {
        Ok(v) => v
        Err(e) => {
          let msg = "encode/decode idempotence recode failed to decode at attempt #\{attempts}: \{e}"
          let report = FuzzFailureReport::new(
            seed,
            attempts,
            generated_valid,
            "encode-decode-idempotence",
            "\{e}",
            optimize_passes=pass_names,
            minimized_passes=pass_names,
            generator_profile=gen_profile_label,
            pass_profile~,
            generator_config_label=generated_config_label,
            generated_attempts~,
            feature_facts~,
            wasm=Some(recoded),
          )
          return Err(fuzz_finalize_failure(on_failure, report, msg))
        }
      }
      let recoded_again = match encode_module(recoded_mod) {
        Ok(v) => v
        Err(e) => {
          let msg = "encode/decode idempotence second encode failed at attempt #\{attempts}: \{e}"
          let report = FuzzFailureReport::new(
            seed,
            attempts,
            generated_valid,
            "encode-decode-idempotence",
            "\{e}",
            optimize_passes=pass_names,
            minimized_passes=pass_names,
            generator_profile=gen_profile_label,
            pass_profile~,
            generator_config_label=generated_config_label,
            generated_attempts~,
            feature_facts~,
            wasm=Some(recoded),
          )
          return Err(fuzz_finalize_failure(on_failure, report, msg))
        }
      }
      if !fuzz_bytes_equal(recoded, recoded_again) {
        let msg = "encode/decode idempotence changed canonical bytes at attempt #\{attempts}"
        let report = FuzzFailureReport::new(
          seed,
          attempts,
          generated_valid,
          "encode-decode-idempotence",
          msg,
          optimize_passes=pass_names,
          minimized_passes=pass_names,
          generator_profile=gen_profile_label,
          pass_profile~,
          generator_config_label=generated_config_label,
          generated_attempts~,
          feature_facts~,
          wasm=Some(recoded_again),
        )
        return Err(fuzz_finalize_failure(on_failure, report, msg))
      }
      encode_decode_idempotence_checked += 1
    }
    match validate_module(decoded) {
      Ok(_) => pipeline_validated += 1
      Err(e) => {
        let msg = "decoded module failed validation at attempt #\{attempts}: \{e}"
        let report = FuzzFailureReport::new(
          seed,
          attempts,
          generated_valid,
          "post-decode-validate",
          "\{e}",
          optimize_passes=pass_names,
          minimized_passes=pass_names,
          generator_profile=gen_profile_label,
          pass_profile~,
          generator_config_label=generated_config_label,
          generated_attempts~,
          feature_facts~,
          wasm=Some(encoded),
        )
        return Err(fuzz_finalize_failure(on_failure, report, msg))
      }
    }

    let optimized = match
      optimize_module_with_pass_flags(
        decoded,
        optimize_passes,
        OptimizeOptions::new(),
      ) {
      Ok(v) => v
      Err(e) => {
        let msg = "optimize failed at attempt #\{attempts}: \{e}"
        let minimized = fuzz_minimize_optimize_failure(encoded, pass_names)
        let report = FuzzFailureReport::new(
          seed,
          attempts,
          generated_valid,
          "optimize",
          "\{e}",
          optimize_passes=pass_names,
          minimized_passes=minimized,
          generator_profile=gen_profile_label,
          pass_profile~,
          generator_config_label=generated_config_label,
          generated_attempts~,
          feature_facts~,
          wasm=Some(encoded),
        )
        return Err(fuzz_finalize_failure(on_failure, report, msg))
      }
    }
    optimized_count += 1

    let roundtrip_bytes = match encode_module(optimized) {
      Ok(bytes) => bytes
      Err(e) => {
        let msg = "post-opt encode failed at attempt #\{attempts}: \{e}"
        let report = FuzzFailureReport::new(
          seed,
          attempts,
          generated_valid,
          "post-opt-encode",
          "\{e}",
          optimize_passes=pass_names,
          minimized_passes=pass_names,
          generator_profile=gen_profile_label,
          pass_profile~,
          generator_config_label=generated_config_label,
          generated_attempts~,
          feature_facts~,
          wasm=Some(encoded),
        )
        return Err(fuzz_finalize_failure(on_failure, report, msg))
      }
    }
    let roundtrip_mod = match decode_module(roundtrip_bytes) {
      Ok(decoded_mod) => decoded_mod
      Err(e) => {
        let msg = "post-opt decode failed at attempt #\{attempts}: \{e}"
        let report = FuzzFailureReport::new(
          seed,
          attempts,
          generated_valid,
          "post-opt-decode",
          "\{e}",
          optimize_passes=pass_names,
          minimized_passes=pass_names,
          generator_profile=gen_profile_label,
          pass_profile~,
          generator_config_label=generated_config_label,
          generated_attempts~,
          feature_facts~,
          wasm=Some(roundtrip_bytes),
        )
        return Err(fuzz_finalize_failure(on_failure, report, msg))
      }
    }
    if check_optimize_idempotence {
      let optimized_again = match
        optimize_module_with_pass_flags(
          roundtrip_mod,
          optimize_passes,
          OptimizeOptions::new(),
        ) {
        Ok(v) => v
        Err(e) => {
          let msg = "optimize idempotence rerun failed at attempt #\{attempts}: \{e}"
          let report = FuzzFailureReport::new(
            seed,
            attempts,
            generated_valid,
            "optimize-idempotence",
            "\{e}",
            optimize_passes=pass_names,
            minimized_passes=pass_names,
            generator_profile=gen_profile_label,
            pass_profile~,
            generator_config_label=generated_config_label,
            generated_attempts~,
            feature_facts~,
            wasm=Some(roundtrip_bytes),
          )
          return Err(fuzz_finalize_failure(on_failure, report, msg))
        }
      }
      let optimized_again_bytes = match encode_module(optimized_again) {
        Ok(bytes) => bytes
        Err(e) => {
          let msg = "optimize idempotence encode failed at attempt #\{attempts}: \{e}"
          let report = FuzzFailureReport::new(
            seed,
            attempts,
            generated_valid,
            "optimize-idempotence",
            "\{e}",
            optimize_passes=pass_names,
            minimized_passes=pass_names,
            generator_profile=gen_profile_label,
            pass_profile~,
            generator_config_label=generated_config_label,
            generated_attempts~,
            feature_facts~,
            wasm=Some(roundtrip_bytes),
          )
          return Err(fuzz_finalize_failure(on_failure, report, msg))
        }
      }
      if !fuzz_bytes_equal(roundtrip_bytes, optimized_again_bytes) {
        let msg = "optimize idempotence changed bytes at attempt #\{attempts}"
        let report = FuzzFailureReport::new(
          seed,
          attempts,
          generated_valid,
          "optimize-idempotence",
          msg,
          optimize_passes=pass_names,
          minimized_passes=pass_names,
          generator_profile=gen_profile_label,
          pass_profile~,
          generator_config_label=generated_config_label,
          generated_attempts~,
          feature_facts~,
          wasm=Some(optimized_again_bytes),
        )
        return Err(fuzz_finalize_failure(on_failure, report, msg))
      }
      optimize_idempotence_checked += 1
    }
    let roundtrip_validate_mod = match decode_module(roundtrip_bytes) {
      Ok(decoded_mod) => decoded_mod
      Err(e) => {
        let msg = "post-opt validation decode failed at attempt #\{attempts}: \{e}"
        let report = FuzzFailureReport::new(
          seed,
          attempts,
          generated_valid,
          "post-opt-decode",
          "\{e}",
          optimize_passes=pass_names,
          minimized_passes=pass_names,
          generator_profile=gen_profile_label,
          pass_profile~,
          generator_config_label=generated_config_label,
          generated_attempts~,
          feature_facts~,
          wasm=Some(roundtrip_bytes),
        )
        return Err(fuzz_finalize_failure(on_failure, report, msg))
      }
    }
    match validate_module(roundtrip_validate_mod) {
      Ok(_) => roundtripped += 1
      Err(e) => {
        let msg = "roundtripped module failed validation at attempt #\{attempts}: \{e}"
        let report = FuzzFailureReport::new(
          seed,
          attempts,
          generated_valid,
          "post-opt-validate",
          "\{e}",
          optimize_passes=pass_names,
          minimized_passes=pass_names,
          generator_profile=gen_profile_label,
          pass_profile~,
          generator_config_label=generated_config_label,
          generated_attempts~,
          feature_facts~,
          wasm=Some(roundtrip_bytes),
        )
        return Err(fuzz_finalize_failure(on_failure, report, msg))
      }
    }

    generated_valid += 1

    if differential_every > 0 && generated_valid % differential_every == 0 {
      let adapters = match differential_adapters {
        Some(v) => v
        None => default_differential_adapters()
      }
      match differential_validate_wasm(roundtrip_bytes, adapters~) {
        Ok(_) => differential_checked += 1
        Err(e) => {
          let msg = "differential validation failed at module #\{generated_valid}: \{e}"
          let report = FuzzFailureReport::new(
            seed,
            attempts,
            generated_valid,
            "differential",
            "\{e}",
            optimize_passes=pass_names,
            minimized_passes=pass_names,
            generator_profile=gen_profile_label,
            pass_profile~,
            generator_config_label=generated_config_label,
            generated_attempts~,
            feature_facts~,
            wasm=Some(roundtrip_bytes),
          )
          return Err(fuzz_finalize_failure(on_failure, report, msg))
        }
      }
    }
  }
  Ok(
    CmdFuzzStats::new(
      attempts~,
      generated_valid~,
      generated_invalid~,
      pipeline_validated~,
      optimized=optimized_count,
      roundtripped~,
      differential_checked~,
      optimize_idempotence_checked~,
      encode_decode_idempotence_checked~,
      generator_profile=gen_profile_label,
      pass_profile~,
    ),
  )
}

///|
fn fuzz_profile_ascii_lower(input : String) -> String {
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
pub fn run_cmd_fuzz_harness_profile(
  profile : String,
  seed : UInt64,
) -> Result[CmdFuzzStats, String] {
  let config = match cmd_fuzz_harness_profile_config(profile) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  run_cmd_fuzz_harness(
    config.valid_target,
    seed~,
    optimize_passes=config.optimize_passes,
    generator_profile=config.generator_profile,
    generator_config=Some(config.generator_config),
    pass_profile=config.pass_profile,
    check_optimize_idempotence=config.check_optimize_idempotence,
    check_encode_decode_idempotence=config.check_encode_decode_idempotence,
  )
}

///|
#cfg(target="native")
fn cmd_native_has_command(name : String) -> Bool {
  let command = "command -v \{cmd_native_shell_quote(name)} >/dev/null 2>&1"
  cmd_native_system(cmd_native_c_string(command)) == 0
}

///|
#cfg(target="native")
fn cmd_native_validate_wasm_with(
  executable : String,
  command : String,
  bytes : Bytes,
) -> Result[Bool, String] {
  if !cmd_native_has_command(executable) {
    return Err("\{executable} not available")
  }
  let path = cmd_native_tmp_path("differential", ".wasm")
  if cmd_native_write_file(path, bytes) is Err(e) {
    cmd_native_remove_file(path)
    return Err("failed to stage wasm for \{command}: \{e}")
  }
  let run = "\{command} \{cmd_native_shell_quote(path)} >/dev/null 2>&1"
  let code = cmd_native_system(cmd_native_c_string(run))
  cmd_native_remove_file(path)
  Ok(code == 0)
}

///|
#cfg(target="native")
pub fn native_differential_tools_available() -> (Bool, Bool) {
  (
    cmd_native_has_command("wasm-tools"),
    cmd_native_has_command("wasm-validate"),
  )
}

///|
#cfg(target="wasm-gc")
pub fn native_differential_tools_available() -> (Bool, Bool) {
  (false, false)
}

///|
#cfg(target="wasm")
pub fn native_differential_tools_available() -> (Bool, Bool) {
  (false, false)
}

///|
#cfg(target="js")
pub fn native_differential_tools_available() -> (Bool, Bool) {
  (false, false)
}

///|
#cfg(target="llvm")
pub fn native_differential_tools_available() -> (Bool, Bool) {
  (false, false)
}

///|
#cfg(target="native")
fn default_differential_adapters() -> DifferentialAdapters {
  DifferentialAdapters::new(
    wasm_tools_validate=fn(bytes) {
      cmd_native_validate_wasm_with("wasm-tools", "wasm-tools validate", bytes)
    },
    binaryen_validate=fn(bytes) {
      cmd_native_validate_wasm_with("wasm-validate", "wasm-validate", bytes)
    },
  )
}

///|
#cfg(target="wasm-gc")
fn default_differential_adapters() -> DifferentialAdapters {
  DifferentialAdapters::new()
}

///|
#cfg(target="wasm")
fn default_differential_adapters() -> DifferentialAdapters {
  DifferentialAdapters::new()
}

///|
#cfg(target="js")
fn default_differential_adapters() -> DifferentialAdapters {
  DifferentialAdapters::new()
}

///|
#cfg(target="llvm")
fn default_differential_adapters() -> DifferentialAdapters {
  DifferentialAdapters::new()
}
