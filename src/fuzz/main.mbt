///|
pub enum FuzzOutputMode {
  Text
  Jsonl
} derive(Eq, Debug)

///|
pub struct FuzzCliArgs {
  suite : String
  profile : String
  seed : UInt64
  seed_i64 : Int64
  output_mode : FuzzOutputMode
  seed_count : Int
  shard_index : Int
  shard_count : Int
  report_json_path : String?
  out_dir : String?
} derive(Eq, Debug)

///|
pub struct FuzzRecipe {
  name : String
  suite : String
  profile : String
  seed_i64 : Int64
  output_mode : FuzzOutputMode
  seed_count : Int
  shard_count : Int
} derive(Eq, Debug)

///|
pub struct FuzzInterestingnessHashLayer {
  name : String
  digest : String
  description : String
} derive(Eq, Debug)

///|
pub struct FuzzInterestingnessHashSchema {
  schema_id : String
  layers : Array[FuzzInterestingnessHashLayer]
} derive(Eq, Debug)

///|
pub struct FuzzInterestingnessCaseKey {
  raw_hash : String
  decoded_shape_hash : String
  feature_fact_hash : String
  normalized_hash : String
  predicate_hash : String
  reduced_artifact_hash : String
} derive(Eq, Debug)

///|
pub struct FuzzCorpusHashMetadata {
  raw_artifact_hash : String
  reduced_artifact_hash : String
  predicate_hash : String
  feature_fact_hash : String
  interestingness_label : String
} derive(Eq, Debug)

///|
pub struct FuzzCorpusPromotionMetadata {
  id : String
  state : String
  source : String
  input : String
  created_at : String
  generator : String
  features : Array[String]
  expectation : String
  classification : String
  replay : String
  artifacts : Array[String]
  owner_or_task : String
  notes : String
  raw_artifact_hash : String
  reduced_artifact_hash : String
  normalized_shape_hash : String
  predicate_hash : String
  feature_fact_hash : String
  interestingness_label : String
} derive(Eq, Debug)

///|
pub struct FuzzCorpusReplayCommandMetadata {
  case_id : String
  suite : String
  profile : String
  seed : UInt64
  seed_index : Int
  strategy_or_artifact : String
  expected_outcome : String
  classification : String
  command : String
} derive(Eq, Debug)

///|
pub struct FuzzCorpusReplayAllPlan {
  planned_count : Int
  skipped_count : Int
  malformed_count : Int
  commands : Array[FuzzCorpusReplayCommandMetadata]
} derive(Eq, Debug)

///|
pub struct FuzzCorpusCaseIndexEntry {
  hash_kind : String
  hash : String
  case_ids : Array[String]
  seeds : Array[UInt64]
  profiles : Array[String]
  artifact_paths : Array[String]
} derive(Eq, Debug)

///|
pub struct FuzzCorpusCaseIndex {
  entries : Array[FuzzCorpusCaseIndexEntry]
} derive(Eq, Debug)

///|
pub struct FuzzCorpusDedupDryRunDecision {
  action : String
  hash_kind : String
  hash : String
  case_ids : Array[String]
  artifact_paths : Array[String]
  reason : String
} derive(Eq, Debug)

///|
pub struct FuzzCorpusDedupDryRunPlan {
  duplicate_count : Int
  compress_count : Int
  keep_count : Int
  decisions : Array[FuzzCorpusDedupDryRunDecision]
} derive(Eq, Debug)

///|
pub fn FuzzInterestingnessCaseKey::new(
  raw_hash : String,
  decoded_shape_hash : String,
  feature_fact_hash : String,
  normalized_hash : String,
  predicate_hash : String,
  reduced_artifact_hash : String,
) -> FuzzInterestingnessCaseKey {
  {
    raw_hash,
    decoded_shape_hash,
    feature_fact_hash,
    normalized_hash,
    predicate_hash,
    reduced_artifact_hash,
  }
}

///|
fn fuzz_fnv1a64_hex_digit(value : UInt64) -> Char {
  let nibble = value.to_int()
  if nibble < 10 {
    (48 + nibble).unsafe_to_char()
  } else {
    (87 + nibble).unsafe_to_char()
  }
}

///|
fn fuzz_fnv1a64_hex(hash : UInt64) -> String {
  let out = StringBuilder::new()
  let mut shift = 60
  while shift >= 0 {
    out.write_char(fuzz_fnv1a64_hex_digit((hash >> shift) & 0xFUL))
    shift -= 4
  }
  out.to_string()
}

///|
pub fn fuzz_corpus_hash_bytes(bytes : Bytes) -> String {
  let mut hash = 1469598103934665603UL
  let prime = 1099511628211UL
  let mut i = 0
  while i < bytes.length() {
    hash = (hash ^ bytes[i].to_uint64()) * prime
    i += 1
  }
  "fnv1a64-\{fuzz_fnv1a64_hex(hash)}"
}

///|
pub fn fuzz_corpus_hash_text(text : String) -> String {
  fuzz_corpus_hash_bytes(fuzz_string_to_bytes(text))
}

///|
fn fuzz_join_sorted_feature_facts(feature_facts : Array[String]) -> String {
  let sorted : Array[String] = []
  for fact in feature_facts {
    sorted.push(fact)
  }
  sorted.sort()
  let out = StringBuilder::new()
  for i in 0..<sorted.length() {
    if i > 0 {
      out.write_char('\n')
    }
    out.write_string(sorted[i])
  }
  out.to_string()
}

///|
pub fn build_fuzz_corpus_hash_metadata(
  raw_artifact : Bytes,
  reduced_artifact? : Bytes? = None,
  predicate : String,
  feature_facts : Array[String],
  interestingness_label : String,
) -> FuzzCorpusHashMetadata {
  let reduced_bytes = match reduced_artifact {
    Some(bytes) => bytes
    None => raw_artifact
  }
  FuzzCorpusHashMetadata::new(
    fuzz_corpus_hash_bytes(raw_artifact),
    fuzz_corpus_hash_bytes(reduced_bytes),
    fuzz_corpus_hash_text(predicate),
    fuzz_corpus_hash_text(fuzz_join_sorted_feature_facts(feature_facts)),
    interestingness_label,
  )
}

///|
pub fn FuzzCorpusPromotionMetadata::new(
  id : String,
  state : String,
  source : String,
  input : String,
  created_at : String,
  generator : String,
  features : Array[String],
  expectation : String,
  classification : String,
  replay : String,
  artifacts : Array[String],
  owner_or_task : String,
  notes : String,
  raw_artifact_hash? : String = "",
  reduced_artifact_hash? : String = "",
  normalized_shape_hash? : String = "",
  predicate_hash? : String = "",
  feature_fact_hash? : String = "",
  interestingness_label? : String = "unclassified",
) -> FuzzCorpusPromotionMetadata {
  {
    id,
    state,
    source,
    input,
    created_at,
    generator,
    features,
    expectation,
    classification,
    replay,
    artifacts,
    owner_or_task,
    notes,
    raw_artifact_hash,
    reduced_artifact_hash,
    normalized_shape_hash,
    predicate_hash,
    feature_fact_hash,
    interestingness_label,
  }
}

///|
pub fn FuzzCorpusHashMetadata::new(
  raw_artifact_hash : String,
  reduced_artifact_hash : String,
  predicate_hash : String,
  feature_fact_hash : String,
  interestingness_label : String,
) -> FuzzCorpusHashMetadata {
  {
    raw_artifact_hash,
    reduced_artifact_hash,
    predicate_hash,
    feature_fact_hash,
    interestingness_label,
  }
}

///|
pub fn FuzzCorpusReplayCommandMetadata::new(
  case_id : String,
  suite : String,
  profile : String,
  seed : UInt64,
  seed_index : Int,
  strategy_or_artifact : String,
  expected_outcome : String,
  classification : String,
  command : String,
) -> FuzzCorpusReplayCommandMetadata {
  {
    case_id,
    suite,
    profile,
    seed,
    seed_index,
    strategy_or_artifact,
    expected_outcome,
    classification,
    command,
  }
}

///|
pub fn FuzzCorpusCaseIndexEntry::new(
  hash_kind : String,
  hash : String,
  case_ids : Array[String],
  seeds : Array[UInt64],
  profiles : Array[String],
  artifact_paths : Array[String],
) -> FuzzCorpusCaseIndexEntry {
  { hash_kind, hash, case_ids, seeds, profiles, artifact_paths }
}

///|
pub fn FuzzCorpusCaseIndex::new(
  entries : Array[FuzzCorpusCaseIndexEntry],
) -> FuzzCorpusCaseIndex {
  { entries, }
}

///|
pub fn FuzzCorpusDedupDryRunDecision::new(
  action : String,
  hash_kind : String,
  hash : String,
  case_ids : Array[String],
  artifact_paths : Array[String],
  reason : String,
) -> FuzzCorpusDedupDryRunDecision {
  { action, hash_kind, hash, case_ids, artifact_paths, reason }
}

///|
pub fn FuzzCorpusDedupDryRunPlan::new(
  duplicate_count : Int,
  compress_count : Int,
  keep_count : Int,
  decisions : Array[FuzzCorpusDedupDryRunDecision],
) -> FuzzCorpusDedupDryRunPlan {
  { duplicate_count, compress_count, keep_count, decisions }
}

///|
pub fn fuzz_interestingness_hash_schema() -> FuzzInterestingnessHashSchema {
  {
    schema_id: "starshine.fuzz-interestingness.v1",
    layers: [
      {
        name: "raw",
        digest: "fnv1a64-hex",
        description: "Hash of original specimen bytes before decoding, normalization, or reduction.",
      },
      {
        name: "decoded-shape",
        digest: "fnv1a64-hex",
        description: "Hash of decoded module/script shape: section and instruction families without preserving incidental payload bytes.",
      },
      {
        name: "feature-fact",
        digest: "fnv1a64-hex",
        description: "Hash of sorted feature facts such as GC, exception, memory64, SIMD, string, import, export, and proposal markers.",
      },
      {
        name: "normalized",
        digest: "fnv1a64-hex",
        description: "Hash of canonical normalized comparison text or bytes after accepted representation-only cleanup.",
      },
      {
        name: "predicate",
        digest: "fnv1a64-hex",
        description: "Hash of the oracle outcome, interestingness predicate, failure class, pass name, and relevant tool verdicts.",
      },
      {
        name: "reduced-artifact",
        digest: "fnv1a64-hex",
        description: "Hash of the minimized or otherwise reduced artifact that still satisfies the predicate.",
      },
    ],
  }
}

///|
pub fn FuzzRecipe::new(
  name : String,
  suite : String,
  profile : String,
  seed_i64 : Int64,
  output_mode? : FuzzOutputMode = FuzzOutputMode::Text,
  seed_count? : Int = 1,
  shard_count? : Int = 1,
) -> FuzzRecipe {
  { name, suite, profile, seed_i64, output_mode, seed_count, shard_count }
}

///|
pub struct FuzzShardWorkItem {
  name : String
  suite : String
  profile : String
  seed_i64 : Int64
  output_mode : FuzzOutputMode
  seed_count : Int
  shard_index : Int
  shard_count : Int
  out_dir : String?
} derive(Eq, Debug)

///|
pub fn build_fuzz_shard_queue(
  recipe : FuzzRecipe,
  out_dir_root : String?,
) -> Result[Array[FuzzShardWorkItem], String] {
  if recipe.seed_count <= 0 {
    return Err("seed-count must be greater than zero")
  }
  if recipe.shard_count <= 0 {
    return Err("shard-count must be greater than zero")
  }
  let out : Array[FuzzShardWorkItem] = []
  let total_label = fuzz_zero_pad_decimal(recipe.shard_count, 3)
  let mut shard_index = 0
  while shard_index < recipe.shard_count {
    let shard_label = fuzz_zero_pad_decimal(shard_index, 3)
    let shard_name = "\{recipe.name}-shard-\{shard_label}-of-\{total_label}"
    let shard_out_dir = match out_dir_root {
      Some(root) => Some("\{root}/shard-\{shard_label}-of-\{total_label}")
      None => None
    }
    out.push({
      name: shard_name,
      suite: recipe.suite,
      profile: recipe.profile,
      seed_i64: recipe.seed_i64,
      output_mode: recipe.output_mode,
      seed_count: recipe.seed_count,
      shard_index,
      shard_count: recipe.shard_count,
      out_dir: shard_out_dir,
    })
    shard_index += 1
  }
  Ok(out)
}

///|
fn fuzz_output_manifest_is_complete(manifest_json : String) -> Bool {
  manifest_json.contains("starshine.fuzz-output.v1") &&
  manifest_json.contains("result.json") &&
  manifest_json.contains("cases.jsonl")
}

///|
pub fn build_fuzz_resume_shard_queue(
  recipe : FuzzRecipe,
  out_dir_root : String?,
  completed_manifests : Array[String],
) -> Result[Array[FuzzShardWorkItem], String] {
  let full_queue = match build_fuzz_shard_queue(recipe, out_dir_root) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let out : Array[FuzzShardWorkItem] = []
  let mut i = 0
  while i < full_queue.length() {
    let completed = i < completed_manifests.length() &&
      fuzz_output_manifest_is_complete(completed_manifests[i])
    if !completed {
      out.push(full_queue[i])
    }
    i += 1
  }
  Ok(out)
}

///|
pub fn fuzz_recipe_schema_version() -> String {
  "starshine.fuzz.recipe.v1"
}

///|
pub fn fuzz_standard_recipe_text_by_name(name : String) -> String? {
  let schema_line = "schema=\{fuzz_recipe_schema_version()}\n"
  match fuzz_ascii_lower(name) {
    "smoke" =>
      Some(
        schema_line +
        "name=smoke\nsuite=validate-valid\nprofile=smoke\nseed=0x5eed\nseed-count=1\nshard-count=1\noutput=text\n",
      )
    "default-smoke" =>
      Some(
        schema_line +
        "name=default-smoke\nsuite=all\nprofile=smoke\nseed=0x5eed\nseed-count=1\nshard-count=1\noutput=text\n",
      )
    "ci" =>
      Some(
        schema_line +
        "name=ci\nsuite=cmd-harness\nprofile=ci+gen-valid=natural-small+passes=common-clusters\nseed=0x5eed\nseed-count=4\nshard-count=1\noutput=jsonl\n",
      )
    "default-ci" =>
      Some(
        schema_line +
        "name=default-ci\nsuite=all\nprofile=ci\nseed=0x5eed\nseed-count=4\nshard-count=1\noutput=jsonl\n",
      )
    "nightly" =>
      Some(
        schema_line +
        "name=nightly\nsuite=validate-valid-metamorphic\nprofile=stress\nseed=0x1eed\nseed-count=32\nshard-count=8\noutput=jsonl\n",
      )
    "pass-signoff" =>
      Some(
        schema_line +
        "name=pass-signoff\nsuite=cmd-harness\nprofile=ci+gen-valid=binaryen-oracle-portable+passes=each-pass+check-idempotence\nseed=0x5eed\nseed-count=8\nshard-count=4\noutput=jsonl\n",
      )
    "validator-stress" =>
      Some(
        schema_line +
        "name=validator-stress\nsuite=validate-valid\nprofile=stress\nseed=0x10d69\nseed-count=16\nshard-count=4\noutput=jsonl\n",
      )
    "parser-stress" =>
      Some(
        schema_line +
        "name=parser-stress\nsuite=wast-roundtrip\nprofile=stress+parser-stress+scripts\nseed=0x5eed\nseed-count=16\nshard-count=4\noutput=jsonl\n",
      )
    "binaryen-oracle" =>
      Some(
        schema_line +
        "name=binaryen-oracle\nsuite=gen-valid-wat-validate-roundtrip\nprofile=binaryen-oracle-portable\nseed=0x5eed\nseed-count=8\nshard-count=4\noutput=jsonl\n",
      )
    "text-differential-smoke" =>
      Some(
        schema_line +
        "name=text-differential-smoke\nsuite=text-differential\nprofile=smoke\nseed=0x1045a7\nseed-count=1\nshard-count=1\noutput=jsonl\n",
      )
    _ => None
  }
}

///|
pub fn fuzz_standard_recipe_names() -> Array[String] {
  [
    "smoke", "default-smoke", "ci", "default-ci", "nightly", "pass-signoff", "validator-stress",
    "parser-stress", "binaryen-oracle", "text-differential-smoke",
  ]
}

///|
pub fn fuzz_standard_recipe_by_name(name : String) -> FuzzRecipe? {
  match fuzz_standard_recipe_text_by_name(name) {
    Some(text) =>
      match parse_fuzz_recipe_text(text) {
        Ok(recipe) => Some(recipe)
        Err(_) => None
      }
    None => None
  }
}

///|
pub struct EmitGenValidBatchArgs {
  count : Int
  seed : UInt64
  out_dir : String
  profile : String
  required_features : Array[ValidateValidFeatureFloor]
  excluded_features : Array[ValidateValidFeatureKey]
  max_attempts : Int
  manifest_path : String?
  metamorphic_transform_ids : Array[String]
} derive(Eq, Debug)

///|
pub fn EmitGenValidBatchArgs::new(
  count : Int,
  seed : UInt64,
  out_dir : String,
  profile? : String = "binaryen-oracle-portable",
  required_features? : Array[ValidateValidFeatureFloor] = [],
  excluded_features? : Array[ValidateValidFeatureKey] = [],
  max_attempts? : Int = count,
  manifest_path? : String? = None,
  metamorphic_transform_ids? : Array[String] = [],
) -> EmitGenValidBatchArgs {
  {
    count,
    seed,
    out_dir,
    profile,
    required_features,
    excluded_features,
    max_attempts,
    manifest_path,
    metamorphic_transform_ids,
  }
}

///|
pub struct EmitInvalidReproArgs {
  suite : String
  strategy_id : String
  seed : UInt64
  attempt : Int
  profile : String
  out_dir : String
} derive(Eq, Debug)

///|
pub fn EmitInvalidReproArgs::new(
  suite : String,
  strategy_id : String,
  seed : UInt64,
  attempt : Int,
  out_dir : String,
  profile? : String = "smoke",
) -> EmitInvalidReproArgs {
  { suite, strategy_id, seed, attempt, profile, out_dir }
}

///|
pub enum FuzzCliCommand {
  Run(FuzzCliArgs)
  Help
  ListSuites
  ListProfiles
  ListRecipes
  EmitGenValidBatch(EmitGenValidBatchArgs)
  EmitInvalidRepro(EmitInvalidReproArgs)
  ReplayCorpus(String)
  GoldenSeedSmoke
} derive(Eq, Debug)

///|
pub struct FuzzRunOutputIO {
  ensure_dir : (String) -> Result[Unit, String]
  write_file : (String, Bytes) -> Result[Unit, String]
}

///|
pub fn FuzzRunOutputIO::new(
  ensure_dir? : (String) -> Result[Unit, String] = fn(path) {
    Err("ensure_dir not configured: \{path}")
  },
  write_file? : (String, Bytes) -> Result[Unit, String] = fn(path, _) {
    Err("write_file not configured: \{path}")
  },
) -> FuzzRunOutputIO {
  { ensure_dir, write_file }
}

///|
pub struct FuzzSuiteResult {
  suite : String
  profile : String
  seed : Int64
  attempts : Int
  elapsed_ms : UInt64
  seed_index : Int
  seed_count : Int
  shard_index : Int
  shard_count : Int
  total_run_budget_ms : UInt64?
  total_run_budget_exceeded : Bool
  run_budget_classification : String
  details_json : String?
} derive(Eq, Debug)

///|
pub struct FuzzGoldenSeedSmokeCase {
  suite : String
  profile : String
  seed : Int64
  seed_index : Int
  attempts : Int
  details_required : Bool
  details_json : String?
  catalog_entry_id : String?
  expected_counter_count : Int
} derive(Eq, Debug)

///|
pub fn FuzzGoldenSeedSmokeCase::new(
  suite : String,
  profile : String,
  seed : Int64,
  seed_index : Int,
  attempts : Int,
  details_required : Bool,
  details_json? : String? = None,
  catalog_entry_id? : String? = None,
  expected_counter_count? : Int = 0,
) -> FuzzGoldenSeedSmokeCase {
  {
    suite,
    profile,
    seed,
    seed_index,
    attempts,
    details_required,
    details_json,
    catalog_entry_id,
    expected_counter_count,
  }
}

///|
pub fn FuzzGoldenSeedSmokeCase::details_json_contains(
  self : FuzzGoldenSeedSmokeCase,
  needle : String,
) -> Bool {
  match self.details_json {
    Some(details) => details.contains(needle)
    None => false
  }
}

///|
pub struct FuzzGoldenSeedSmokeReport {
  schema_id : String
  recipe_name : String
  seed : Int64
  cases : Array[FuzzGoldenSeedSmokeCase]
} derive(Eq, Debug)

///|
pub fn FuzzGoldenSeedSmokeReport::new(
  schema_id : String,
  recipe_name : String,
  seed : Int64,
  cases : Array[FuzzGoldenSeedSmokeCase],
) -> FuzzGoldenSeedSmokeReport {
  { schema_id, recipe_name, seed, cases }
}

///|
pub struct FuzzReplayCommand {
  suite : String
  profile : String
  seed : Int64
  seed_index : Int
} derive(Eq, Debug)

///|
fn fuzz_ascii_lower(input : String) -> String {
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
pub fn fuzz_active_suite_names() -> Array[String] {
  [
    "wast-roundtrip", "wat-roundtrip", "wast-validate-roundtrip", "gen-valid-wat-validate-roundtrip",
    "valid-multi-module-linking", "validate-valid", "validate-valid-metamorphic",
    "validate-invalid-ast", "validate-invalid-binary", "validate-invalid-text", "validate-invalid-text-dynamic",
    "validate-invalid-spec-seed", "binary-roundtrip", "cmd-harness",
  ]
}

///|
pub fn fuzz_reserved_suite_names() -> Array[String] {
  []
}

///|
pub fn fuzz_suite_inventory_lines() -> Array[String] {
  let lines : Array[String] = []
  for suite in fuzz_active_suite_names() {
    lines.push("active\t\{suite}")
  }
  for suite in fuzz_reserved_suite_names() {
    lines.push("reserved\t\{suite}")
  }
  lines
}

///|
fn fuzz_profile_names() -> Array[String] {
  ["smoke", "ci", "stress"]
}

///|
fn fuzz_join(values : Array[String], sep : String) -> String {
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
pub fn fuzz_usage_text() -> String {
  let active_suites = fuzz_join(fuzz_active_suite_names(), ", ")
  let reserved = fuzz_reserved_suite_names()
  let reserved_suites = if reserved.is_empty() {
    "(none)"
  } else {
    fuzz_join(reserved, ", ")
  }
  let profiles = fuzz_join(fuzz_profile_names(), ", ")
  "usage: moon run src/fuzz -- [suite] [profile] [seed] [--recipe <name>] [--suite <name>] [--profile <name>] [--seed <int64>|--seed=<int64>] [--seed-count <n>] [--shard-index <i> --shard-count <n>] [--report-json <path>] [--output text|jsonl|--jsonl]\ncommands: --help|-h | --list-suites | --list-profiles | --list-recipes | --golden-seed-smoke | --emit-gen-valid-batch --count <n> --seed <uint64> --out-dir <dir> [--manifest <path>] (portable coverage-forced batch) | --emit-invalid-repro --suite <suite|ast|binary|text|spec-seed> --strategy <stable-id> --seed <uint64> --attempt <n> --out-dir <dir> [--profile <name>] | --replay-corpus <replay-manifest.json>\nactive suites: \{active_suites}\nreserved suite ids: \{reserved_suites}\nprofiles: \{profiles}\nopt-in recipes: text-differential-smoke"
}

///|
pub struct WastValidateRoundtripFuzzStats {
  profile : String
  seed : UInt64
  attempts : Int
  printed : Int
  print_failures : Int
  parsed : Int
  parse_failures : Int
  lowered : Int
  lower_failures : Int
  validated : Int
  validation_failures : Int
} derive(Eq, Debug)

///|
pub struct GenValidWatValidateRoundtripFuzzStats {
  profile : String
  seed : UInt64
  attempts : Int
  generated : Int
  printed : Int
  print_failures : Int
  parsed : Int
  parse_failures : Int
  lowered : Int
  lower_failures : Int
  validated : Int
  validation_failures : Int
} derive(Eq, Debug)

///|
pub struct TextDifferentialFuzzStats {
  profile : String
  seed : UInt64
  attempts : Int
  local_parse_ok : Int
  local_print_ok : Int
  local_reparse_lower_ok : Int
  local_lower_mismatch : Int
  adapter_unavailable : Int
  adapter_unavailable_classifications : Int
  accepted_classifications : Int
  external_adapters : Array[String]
} derive(Eq, Debug)

///|
pub struct ValidMultiModuleWastCase {
  name : String
  text : String
  feature_facts : Array[String]
} derive(Eq, Debug)

///|
pub enum MultiModuleWastClassification {
  ValidLinking
  Unlinkable
  DuplicateModuleName
  DuplicateRegisterName
  ParseFailure
  SingleModuleValidationFailure
  LinkFailure
  LinkSkipped
} derive(Eq, Debug)

///|
pub struct ValidMultiModuleLinkingFuzzStats {
  profile : String
  seed : UInt64
  attempts : Int
  generated : Int
  parsed_scripts : Int
  parse_failures : Int
  single_module_validated : Int
  single_module_validation_failures : Int
  link_passed : Int
  link_failed : Int
  link_skipped : Int
} derive(Eq, Debug)

///|
fn gen_valid_multi_module_wast_case_text(suffix : String) -> String {
  let provider_name = "provider_" + suffix
  let consumer_name = "consumer_" + suffix
  "(module $" +
  provider_name +
  "\n" +
  "  (func $f (export \"f\") (result i32) i32.const 7)\n" +
  "  (memory (export \"mem\") 1)\n" +
  "  (table (export \"tab\") 1 funcref)\n" +
  "  (global (export \"g\") i32 (i32.const 9)))\n" +
  "(register \"provider\" $" +
  provider_name +
  ")\n" +
  "(module $" +
  consumer_name +
  "\n" +
  "  (import \"provider\" \"f\" (func $f (result i32)))\n" +
  "  (import \"provider\" \"mem\" (memory 1))\n" +
  "  (import \"provider\" \"tab\" (table 1 funcref))\n" +
  "  (import \"provider\" \"g\" (global i32))\n" +
  "  (func (export \"use-func\") (result i32) call $f)\n" +
  "  (func (export \"use-global\") (result i32) global.get 0))\n" +
  "(register \"consumer\" $" +
  consumer_name +
  ")\n"
}

///|
pub fn gen_valid_multi_module_wast_case(
  seed : UInt64,
) -> ValidMultiModuleWastCase {
  let suffix = fuzz_zero_pad_decimal((seed % 100000UL).to_int(), 5)
  {
    name: "valid-multi-module-linking-\{suffix}",
    text: gen_valid_multi_module_wast_case_text(suffix),
    feature_facts: [
      "multi-module", "valid-linking", "register", "import:func", "import:memory",
      "import:table", "import:global", "export:func", "export:memory", "export:table",
      "export:global",
    ],
  }
}

///|
pub fn gen_valid_multi_module_wast_cases(
  seed : UInt64,
  count : Int,
) -> Array[ValidMultiModuleWastCase] {
  let cases : Array[ValidMultiModuleWastCase] = []
  if count <= 0 {
    return cases
  }
  for i = 0; i < count; i = i + 1 {
    cases.push(gen_valid_multi_module_wast_case(seed + i.to_uint64()))
  }
  cases
}

///|
fn gen_unlinkable_multi_module_provider_prefix(suffix : String) -> String {
  let provider_name = "unlinkable_provider_" + suffix
  "(module $" +
  provider_name +
  "\n" +
  "  (func (export \"f\") (result i32) i32.const 7)\n" +
  "  (memory (export \"mem\") 1)\n" +
  "  (table (export \"tab\") 1 funcref)\n" +
  "  (global (export \"g\") i32 (i32.const 9))\n" +
  "  (tag (export \"tag\") (param i32)))\n" +
  "(register \"provider\" $" +
  provider_name +
  ")\n"
}

///|
fn gen_unlinkable_multi_module_wast_case_body(
  variant : Int,
  suffix : String,
) -> (String, String, Array[String]) {
  let prefix = gen_unlinkable_multi_module_provider_prefix(suffix)
  match variant {
    0 =>
      (
        "missing-func",
        prefix +
        "(assert_unlinkable (module (import \"provider\" \"missing_f\" (func))) \"unknown import\")\n",
        ["import:func", "missing-import:func"],
      )
    1 =>
      (
        "missing-memory",
        prefix +
        "(assert_unlinkable (module (import \"provider\" \"missing_mem\" (memory 1))) \"unknown import\")\n",
        ["import:memory", "missing-import:memory"],
      )
    2 =>
      (
        "missing-table",
        prefix +
        "(assert_unlinkable (module (import \"provider\" \"missing_tab\" (table 1 funcref))) \"unknown import\")\n",
        ["import:table", "missing-import:table"],
      )
    3 =>
      (
        "missing-global",
        prefix +
        "(assert_unlinkable (module (import \"provider\" \"missing_g\" (global i32))) \"unknown import\")\n",
        ["import:global", "missing-import:global"],
      )
    4 =>
      (
        "missing-tag",
        prefix +
        "(assert_unlinkable (module (tag (import \"provider\" \"missing_tag\") (param i32))) \"unknown import\")\n",
        ["import:tag", "missing-import:tag"],
      )
    5 =>
      (
        "mismatch-func",
        prefix +
        "(assert_unlinkable (module (import \"provider\" \"f\" (func (param i32)))) \"incompatible import type\")\n",
        ["import:func", "type-mismatch:func"],
      )
    6 =>
      (
        "mismatch-memory",
        prefix +
        "(assert_unlinkable (module (import \"provider\" \"mem\" (memory 2 5))) \"incompatible import type\")\n",
        ["import:memory", "type-mismatch:memory"],
      )
    7 =>
      (
        "mismatch-table",
        prefix +
        "(assert_unlinkable (module (import \"provider\" \"tab\" (table 11 funcref))) \"incompatible import type\")\n",
        ["import:table", "type-mismatch:table"],
      )
    8 =>
      (
        "mismatch-global",
        prefix +
        "(assert_unlinkable (module (import \"provider\" \"g\" (global f64))) \"incompatible import type\")\n",
        ["import:global", "type-mismatch:global"],
      )
    _ =>
      (
        "mismatch-tag",
        prefix +
        "(assert_unlinkable (module (tag (import \"provider\" \"tag\") (param f32))) \"incompatible import type\")\n",
        ["import:tag", "type-mismatch:tag"],
      )
  }
}

///|
pub fn gen_unlinkable_multi_module_wast_case(
  seed : UInt64,
) -> ValidMultiModuleWastCase {
  let variant = (seed % 10UL).to_int()
  let suffix = fuzz_zero_pad_decimal((seed % 100000UL).to_int(), 5)
  let (variant_name, text, variant_facts) = gen_unlinkable_multi_module_wast_case_body(
    variant, suffix,
  )
  let facts = [
    "multi-module", "unlinkable", "assert_unlinkable", "valid-before-link", variant_name,
  ]
  facts.append(variant_facts)
  {
    name: "unlinkable-multi-module-\{suffix}-\{variant_name}",
    text,
    feature_facts: facts,
  }
}

///|
pub fn gen_unlinkable_multi_module_wast_cases(
  seed : UInt64,
  count : Int,
) -> Array[ValidMultiModuleWastCase] {
  let cases : Array[ValidMultiModuleWastCase] = []
  if count <= 0 {
    return cases
  }
  for i = 0; i < count; i = i + 1 {
    cases.push(gen_unlinkable_multi_module_wast_case(seed + i.to_uint64()))
  }
  cases
}

///|
fn gen_duplicate_module_name_wast_case(
  suffix : String,
) -> ValidMultiModuleWastCase {
  let module_name = "dup_module_" + suffix
  {
    name: "duplicate-module-name-multi-module-\{suffix}",
    text: "(module $" +
    module_name +
    " (func))\n" +
    "(module $" +
    module_name +
    " (func))\n",
    feature_facts: ["multi-module", "duplicate-module-name"],
  }
}

///|
fn gen_duplicate_register_name_wast_case(
  suffix : String,
) -> ValidMultiModuleWastCase {
  let first_module_name = "dup_register_a_" + suffix
  let second_module_name = "dup_register_b_" + suffix
  {
    name: "duplicate-register-name-multi-module-\{suffix}",
    text: "(module $" +
    first_module_name +
    " (func))\n" +
    "(register \"dupe\" $" +
    first_module_name +
    ")\n" +
    "(module $" +
    second_module_name +
    " (func))\n" +
    "(register \"dupe\" $" +
    second_module_name +
    ")\n",
    feature_facts: ["multi-module", "duplicate-register-name", "register"],
  }
}

///|
pub fn gen_duplicate_multi_module_wast_case(
  seed : UInt64,
) -> ValidMultiModuleWastCase {
  let suffix = fuzz_zero_pad_decimal((seed % 100000UL).to_int(), 5)
  if seed % 2UL == 1UL {
    gen_duplicate_module_name_wast_case(suffix)
  } else {
    gen_duplicate_register_name_wast_case(suffix)
  }
}

///|
fn fuzz_string_array_contains(items : Array[String], needle : String) -> Bool {
  for item in items {
    if item == needle {
      return true
    }
  }
  false
}

///|
fn classify_multi_module_note_module_id(
  seen : Array[String],
  id : String?,
) -> Bool {
  match id {
    Some(name) => {
      if fuzz_string_array_contains(seen, name) {
        return true
      }
      seen.push(name)
      false
    }
    None => false
  }
}

///|
pub fn classify_multi_module_wast_case(
  case : ValidMultiModuleWastCase,
) -> MultiModuleWastClassification {
  let script = match wast_to_script(case.text, filename=case.name + ".wast") {
    Ok(v) => v
    Err(_) => return ParseFailure
  }
  let seen_module_ids : Array[String] = []
  let seen_register_names : Array[String] = []
  let mut saw_unlinkable = false
  for cmd in script.commands {
    match cmd {
      WastCommand::Module(m) =>
        if classify_multi_module_note_module_id(seen_module_ids, m.id) {
          return DuplicateModuleName
        }
      WastCommand::ModuleBinary(id, _) =>
        if classify_multi_module_note_module_id(seen_module_ids, id) {
          return DuplicateModuleName
        }
      WastCommand::ModuleQuote(id, _) =>
        if classify_multi_module_note_module_id(seen_module_ids, id) {
          return DuplicateModuleName
        }
      WastCommand::Register(name, _) => {
        if fuzz_string_array_contains(seen_register_names, name) {
          return DuplicateRegisterName
        }
        seen_register_names.push(name)
      }
      WastCommand::AssertUnlinkable(_, _) => saw_unlinkable = true
      _ => ()
    }
  }
  if saw_unlinkable {
    return Unlinkable
  }
  match @wast.run_wast_spec_file(case.name + ".wast", case.text).status {
    @wast.WastSpecFileStatus::Passed => ValidLinking
    @wast.WastSpecFileStatus::Skipped(_) => LinkSkipped
    @wast.WastSpecFileStatus::Failed(msg) =>
      if msg.contains("validation failed:") ||
        msg.contains("module lower failed:") {
        SingleModuleValidationFailure
      } else {
        LinkFailure
      }
  }
}

///|
fn valid_multi_module_linking_attempts(profile : String) -> Result[Int, String] {
  let normalized = fuzz_ascii_lower(profile.trim().to_owned())
  match normalized {
    "smoke" => Ok(4)
    "ci" => Ok(16)
    "stress" => Ok(64)
    _ =>
      Err(
        "unknown valid-multi-module-linking fuzz profile '\{profile}'; expected smoke|ci|stress",
      )
  }
}

///|
pub fn run_valid_multi_module_linking_fuzz(
  profile : String,
  seed : UInt64,
) -> Result[ValidMultiModuleLinkingFuzzStats, String] {
  let normalized = fuzz_ascii_lower(profile.trim().to_owned())
  let attempts = match valid_multi_module_linking_attempts(profile) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let cases = gen_valid_multi_module_wast_cases(seed, attempts)
  let mut generated = 0
  let mut parsed_scripts = 0
  let mut parse_failures = 0
  let mut single_module_validated = 0
  let mut single_module_validation_failures = 0
  let mut link_passed = 0
  let mut link_failed = 0
  let mut link_skipped = 0
  let mut last_error = ""
  for case in cases {
    generated += 1
    let script = match wast_to_script(case.text, filename=case.name + ".wast") {
      Ok(v) => {
        parsed_scripts += 1
        v
      }
      Err(e) => {
        parse_failures += 1
        last_error = e
        continue
      }
    }
    for cmd in script.commands {
      match cmd {
        WastCommand::Module(m) =>
          match wast_ast_to_binary_module(m) {
            Ok(binary_module) =>
              match validate_module(binary_module) {
                Ok(_) => single_module_validated += 1
                Err(e) => {
                  single_module_validation_failures += 1
                  last_error = validation_error_message(e)
                }
              }
            Err(e) => {
              single_module_validation_failures += 1
              last_error = e
            }
          }
        _ => ()
      }
    }
    let report = @wast.run_wast_spec_file(case.name + ".wast", case.text)
    match report.status {
      @wast.WastSpecFileStatus::Passed => link_passed += 1
      @wast.WastSpecFileStatus::Failed(e) => {
        link_failed += 1
        last_error = e
      }
      @wast.WastSpecFileStatus::Skipped(e) => {
        link_skipped += 1
        last_error = e
      }
    }
  }
  if generated != attempts {
    return Err("valid multi-module linking generated count mismatch")
  }
  if parse_failures > 0 ||
    single_module_validation_failures > 0 ||
    link_failed > 0 ||
    link_skipped > 0 ||
    link_passed == 0 {
    return Err(
      "valid multi-module linking did not fully pass: profile=\{normalized} seed=\{seed} generated=\{generated} parsed=\{parsed_scripts} single_module_validated=\{single_module_validated} single_module_validation_failures=\{single_module_validation_failures} link_passed=\{link_passed} link_failed=\{link_failed} link_skipped=\{link_skipped} last_error=\{last_error}",
    )
  }
  Ok(ValidMultiModuleLinkingFuzzStats::{
    profile: normalized,
    seed,
    attempts,
    generated,
    parsed_scripts,
    parse_failures,
    single_module_validated,
    single_module_validation_failures,
    link_passed,
    link_failed,
    link_skipped,
  })
}

///|
fn gen_valid_wat_roundtrip_config() -> GenValidConfig {
  GenValidConfig::wat_text_roundtrip_default()
}

///|
pub fn run_gen_valid_wat_validate_roundtrip_fuzz(
  profile : String,
  seed : UInt64,
) -> Result[GenValidWatValidateRoundtripFuzzStats, String] {
  let normalized = fuzz_ascii_lower(profile.trim().to_owned())
  let attempts = match normalized {
    "smoke" => 32
    "ci" => 128
    "stress" => 512
    _ =>
      return Err(
        "unknown gen-valid-wat-validate fuzz profile '\{profile}'; expected smoke|ci|stress",
      )
  }
  let config = gen_valid_wat_roundtrip_config()
  let state = @splitmix.new(seed~)
  let mut generated = 0
  let mut printed = 0
  let mut print_failures = 0
  let mut parsed = 0
  let mut parse_failures = 0
  let mut lowered = 0
  let mut lower_failures = 0
  let mut validated = 0
  let mut validation_failures = 0
  let mut last_print_failure = ""
  let mut last_parse_failure = ""
  for _ in 0..<attempts {
    let mod_ = gen_valid_module_with_config(state, config)
    generated += 1
    let text = match lib_module_to_wat(mod_) {
      Ok(v) => {
        printed += 1
        v
      }
      Err(e) => {
        print_failures += 1
        last_print_failure = e
        continue
      }
    }
    let parsed_module = match
      wast_to_module(text, filename="gen-valid-wat-roundtrip.wat") {
      Ok(v) => {
        parsed += 1
        v
      }
      Err(e) => {
        parse_failures += 1
        last_parse_failure = e
        continue
      }
    }
    let lowered_module = match wast_ast_to_binary_module(parsed_module) {
      Ok(v) => {
        lowered += 1
        v
      }
      Err(_) => {
        lower_failures += 1
        continue
      }
    }
    match validate_module(lowered_module) {
      Ok(_) => validated += 1
      Err(_) => validation_failures += 1
    }
  }
  if generated != attempts {
    return Err("gen-valid wat roundtrip generated count mismatch")
  }
  if printed <= 0 || parsed <= 0 || lowered <= 0 || validated <= 0 {
    return Err(
      "gen-valid wat roundtrip made no validated progress: profile=\{normalized} seed=\{seed} generated=\{generated} printed=\{printed} parsed=\{parsed} lowered=\{lowered} validated=\{validated} last_print_failure=\{last_print_failure} last_parse_failure=\{last_parse_failure}",
    )
  }
  Ok(GenValidWatValidateRoundtripFuzzStats::{
    profile: normalized,
    seed,
    attempts,
    generated,
    printed,
    print_failures,
    parsed,
    parse_failures,
    lowered,
    lower_failures,
    validated,
    validation_failures,
  })
}

///|
fn text_differential_case(seed : UInt64, attempt : Int) -> String {
  let value = ((seed + attempt.to_uint64()) % 1000UL).to_int()
  "(module (func (export \"answer\") (result i32) i32.const \{value}))"
}

///|
fn text_differential_attempt_locally(source : String) -> Result[Bool, String] {
  let parsed = match wast_to_module(source, filename="text-differential.wat") {
    Ok(v) => v
    Err(e) => return Err("parse failed: \{e}")
  }
  let lowered = match wast_ast_to_binary_module(parsed) {
    Ok(v) => v
    Err(e) => return Err("lower failed: \{e}")
  }
  let lowered_bytes = match encode_module(lowered) {
    Ok(v) => v
    Err(e) => return Err("encode failed: \{e}")
  }
  let printed = match module_to_wast(parsed) {
    Ok(v) => v
    Err(e) => return Err("print failed: \{e}")
  }
  let reparsed = match
    wast_to_module(printed, filename="text-differential.printed.wat") {
    Ok(v) => v
    Err(e) => return Err("reparse failed: \{e}")
  }
  let relowered = match wast_ast_to_binary_module(reparsed) {
    Ok(v) => v
    Err(e) => return Err("reparse lower failed: \{e}")
  }
  let relowered_bytes = match encode_module(relowered) {
    Ok(v) => v
    Err(e) => return Err("reparse encode failed: \{e}")
  }
  Ok(lowered_bytes == relowered_bytes)
}

///|
pub fn run_text_differential_fuzz(
  profile : String,
  seed : UInt64,
) -> Result[TextDifferentialFuzzStats, String] {
  let normalized = fuzz_ascii_lower(profile.trim().to_owned())
  let attempts = match normalized {
    "smoke" => 1
    "ci" => 8
    "stress" => 32
    _ =>
      return Err(
        "unknown text-differential fuzz profile '\{profile}'; expected smoke|ci|stress",
      )
  }
  let external_adapters = ["wabt-unavailable", "wasm-tools-unavailable"]
  let mut local_parse_ok = 0
  let mut local_print_ok = 0
  let mut local_reparse_lower_ok = 0
  let mut local_lower_mismatch = 0
  let mut adapter_unavailable = 0
  let mut adapter_unavailable_classifications = 0
  let accepted_classifications = 0
  let mut last_local_error = ""
  for attempt in 0..<attempts {
    let source = text_differential_case(seed, attempt)
    match text_differential_attempt_locally(source) {
      Ok(bytes_equal) => {
        local_parse_ok += 1
        local_print_ok += 1
        if bytes_equal {
          local_reparse_lower_ok += 1
        } else {
          local_lower_mismatch += 1
        }
      }
      Err(e) => {
        last_local_error = e
        continue
      }
    }
    adapter_unavailable += external_adapters.length()
    adapter_unavailable_classifications += 1
  }
  if local_reparse_lower_ok == 0 {
    return Err(
      "text differential made no local parse/print/lower progress: profile=\{normalized} seed=\{seed} last_local_error=\{last_local_error}",
    )
  }
  Ok(TextDifferentialFuzzStats::{
    profile: normalized,
    seed,
    attempts,
    local_parse_ok,
    local_print_ok,
    local_reparse_lower_ok,
    local_lower_mismatch,
    adapter_unavailable,
    adapter_unavailable_classifications,
    accepted_classifications,
    external_adapters,
  })
}

///|
pub fn run_wast_validate_roundtrip_fuzz(
  profile : String,
  seed : UInt64,
) -> Result[WastValidateRoundtripFuzzStats, String] {
  let normalized = fuzz_ascii_lower(profile.trim().to_owned())
  let attempts = match normalized {
    "smoke" => 64
    "ci" => 256
    "stress" => 1024
    _ =>
      return Err(
        "unknown wast-validate fuzz profile '\{profile}'; expected smoke|ci|stress",
      )
  }
  let state = @splitmix.new(seed~)
  let mut printed = 0
  let mut print_failures = 0
  let mut parsed = 0
  let mut parse_failures = 0
  let mut lowered = 0
  let mut lower_failures = 0
  let mut validated = 0
  let mut validation_failures = 0
  let mut iteration = 0
  while iteration < attempts {
    iteration += 1
    let wmod : @wast.Module = if iteration == 1 {
      match wast_to_module("(module)", filename="wast-validate-seed.wat") {
        Ok(v) => v
        Err(e) => abort("unexpected fixed WAST seed parse failure: \{e}")
      }
    } else {
      Arbitrary::arbitrary(5, state)
    }
    let text = match module_to_wast(wmod) {
      Ok(v) => {
        printed += 1
        v
      }
      Err(_) => {
        print_failures += 1
        continue
      }
    }
    let parsed_module = match wast_to_module(text) {
      Ok(v) => {
        parsed += 1
        v
      }
      Err(_) => {
        parse_failures += 1
        continue
      }
    }
    let lowered_module = match wast_ast_to_binary_module(parsed_module) {
      Ok(v) => {
        lowered += 1
        v
      }
      Err(_) => {
        lower_failures += 1
        continue
      }
    }
    match validate_module(lowered_module) {
      Ok(_) => validated += 1
      Err(_) => validation_failures += 1
    }
  }
  if lowered <= 0 {
    return Err(
      "wast validate roundtrip lowered no modules: profile=\{normalized} seed=\{seed} attempts=\{attempts}",
    )
  }
  if validated <= 0 {
    return Err(
      "wast validate roundtrip validated no modules: profile=\{normalized} seed=\{seed} lowered=\{lowered}",
    )
  }
  Ok(WastValidateRoundtripFuzzStats::{
    profile: normalized,
    seed,
    attempts,
    printed,
    print_failures,
    parsed,
    parse_failures,
    lowered,
    lower_failures,
    validated,
    validation_failures,
  })
}

///|
fn validate_valid_text_companion_requirements(
  normalized : String,
) -> (Int, Int) {
  match normalized {
    "smoke" => (0, 0)
    "ci" => (20, 2)
    "stress" => (80, 8)
    _ => abort("unreachable validate-valid text companion profile")
  }
}

///|
fn run_validate_valid_suite_detailed(
  profile : String,
  seed : UInt64,
) -> Result[(Int, String?), String] {
  let run_config = match validate_valid_run_config(profile) {
    Ok(config) => config
    Err(e) => return Err(e)
  }
  let normalized = run_config.profile
  let (min_text_attempts, min_text_stable) = validate_valid_text_companion_requirements(
    normalized,
  )

  let direct_stats = match run_validate_valid_fuzz(normalized, seed) {
    Ok(stats) => stats
    Err(e) => return Err(e)
  }
  let attempts = direct_stats.attempts
  let validated = direct_stats.validated
  let mut roundtrip = 0
  let mut stable = 0
  if min_text_attempts > 0 {
    let text_seed = seed ^ 0x574154554c
    match run_wat_roundtrip_fuzz(normalized, text_seed) {
      Ok(stats) => {
        roundtrip = stats.successes
        stable = stats.stable
      }
      Err(e) =>
        return Err(
          "validate-valid fuzz text companion failed: profile=\{normalized} seed=\{text_seed} error=\{e}",
        )
    }
  }

  if validated != attempts {
    return Err(
      "validate-valid fuzz failed: profile=\{normalized} seed=\{seed} direct validate count mismatch: \{validated}/\{attempts}",
    )
  }
  if roundtrip < min_text_attempts {
    return Err(
      "validate-valid fuzz produced too few text roundtrips: profile=\{normalized} seed=\{seed} roundtrip=\{roundtrip} min=\{min_text_attempts}",
    )
  }
  if stable < min_text_stable {
    return Err(
      "validate-valid fuzz produced too few stable text roundtrips: profile=\{normalized} seed=\{seed} stable=\{stable} min=\{min_text_stable}",
    )
  }
  Ok((attempts, Some(format_validate_valid_details_json(direct_stats))))
}

///|
fn fuzz_seed_digit(c : UInt16, base : Int) -> Int? {
  let digit = if c >= '0' && c <= '9' {
    c.to_int() - 0x30
  } else if base == 16 && c >= 'a' && c <= 'f' {
    c.to_int() - 0x61 + 10
  } else if base == 16 && c >= 'A' && c <= 'F' {
    c.to_int() - 0x41 + 10
  } else {
    return None
  }
  if digit >= base {
    return None
  }
  Some(digit)
}

///|
fn fuzz_parse_seed(raw : String) -> Result[Int64, String] {
  let text = raw.trim().to_owned()
  if text.length() == 0 {
    return Err("seed must not be empty")
  }
  let mut negative = false
  let mut i = 0
  if text[0] == '+' {
    i = 1
  } else if text[0] == '-' {
    negative = true
    i = 1
  }
  if i >= text.length() {
    return Err("invalid seed '\{raw}'")
  }
  let mut base = 10
  if i + 1 < text.length() &&
    text[i] == '0' &&
    (text[i + 1] == 'x' || text[i + 1] == 'X') {
    base = 16
    i += 2
  }
  let mut result : UInt64 = 0UL
  let max_abs = if negative {
    0x8000000000000000UL
  } else {
    0x7FFFFFFFFFFFFFFFUL
  }
  let base_u = base.to_uint64()
  let mut saw_digit = false
  while i < text.length() {
    let c = text[i]
    if c == '_' {
      i += 1
      continue
    }
    let digit = match fuzz_seed_digit(c, base) {
      Some(v) => v
      None => return Err("invalid seed '\{raw}'")
    }
    saw_digit = true
    let digit_u = digit.to_uint64()
    if result > (max_abs - digit_u) / base_u {
      return Err("seed '\{raw}' is out of range for int64")
    }
    result = result * base_u + digit_u
    i += 1
  }
  if !saw_digit {
    return Err("invalid seed '\{raw}'")
  }
  if negative {
    if result == 0x8000000000000000UL {
      Ok(result.reinterpret_as_int64())
    } else {
      Ok(-result.reinterpret_as_int64())
    }
  } else {
    Ok(result.reinterpret_as_int64())
  }
}

///|
fn fuzz_parse_output_mode(raw : String) -> Result[FuzzOutputMode, String] {
  let normalized = fuzz_ascii_lower(raw.trim().to_owned())
  match normalized {
    "text" => Ok(FuzzOutputMode::Text)
    "jsonl" => Ok(FuzzOutputMode::Jsonl)
    _ => Err("unknown output mode '\{raw}'; expected text|jsonl")
  }
}

///|
fn fuzz_generate_seed_i64() -> Int64 {
  trace_now_us().reinterpret_as_int64()
}

///|
fn fuzz_has_seed_equals_flag(arg : String) -> Bool {
  arg.length() >= 7 &&
  arg[0] == '-' &&
  arg[1] == '-' &&
  arg[2] == 's' &&
  arg[3] == 'e' &&
  arg[4] == 'e' &&
  arg[5] == 'd' &&
  arg[6] == '='
}

///|
fn fuzz_has_output_equals_flag(arg : String) -> Bool {
  arg.length() >= 9 &&
  arg[0] == '-' &&
  arg[1] == '-' &&
  arg[2] == 'o' &&
  arg[3] == 'u' &&
  arg[4] == 't' &&
  arg[5] == 'p' &&
  arg[6] == 'u' &&
  arg[7] == 't' &&
  arg[8] == '='
}

///|
fn fuzz_has_prefix_text(arg : String, prefix : String) -> Bool {
  if arg.length() < prefix.length() {
    return false
  }
  let mut i = 0
  while i < prefix.length() {
    if arg[i] != prefix[i] {
      return false
    }
    i += 1
  }
  true
}

///|
fn fuzz_tail_string(input : String, start : Int) -> String {
  let out = StringBuilder::new()
  let mut i = start
  while i < input.length() {
    out.write_char(input[i].unsafe_to_char())
    i += 1
  }
  out.to_string()
}

///|
fn fuzz_parse_seed_or_abort(raw : String) -> Int64 {
  match fuzz_parse_seed(raw) {
    Ok(v) => v
    Err(e) => abort(e)
  }
}

///|
fn fuzz_parse_output_or_abort(raw : String) -> FuzzOutputMode {
  match fuzz_parse_output_mode(raw) {
    Ok(v) => v
    Err(e) => abort(e)
  }
}

///|
fn fuzz_parse_uint64_or_abort(raw : String) -> UInt64 {
  match fuzz_parse_seed(raw) {
    Ok(v) =>
      if v < 0L {
        abort("seed must be non-negative")
      } else {
        v.reinterpret_as_uint64()
      }
    Err(e) => abort(e)
  }
}

///|
fn fuzz_parse_non_negative_decimal_or_abort(
  label : String,
  raw : String,
) -> Int {
  let text = raw.trim().to_owned()
  if text.length() == 0 {
    abort("\{label} must not be empty")
  }
  let mut value = 0
  for c in text {
    if c < '0' || c > '9' {
      abort("invalid \{label} '\{raw}'")
    }
    let digit = c.to_int() - '0'.to_int()
    value = value * 10 + digit
  }
  value
}

///|
fn fuzz_parse_feature_floor_or_abort(raw : String) -> ValidateValidFeatureFloor {
  let parts : Array[String] = []
  for part in raw.split(":") {
    parts.push(part.to_owned())
  }
  if parts.length() > 2 {
    abort(
      "invalid --require-feature '\{raw}'; expected <label> or <label>:<min>",
    )
  }
  let label = parts[0].trim().to_owned()
  if label.length() == 0 {
    abort("--require-feature label must not be empty")
  }
  let min_count = if parts.length() == 1 {
    1
  } else {
    fuzz_parse_non_negative_decimal_or_abort(
      "require-feature min_count",
      parts[1],
    )
  }
  if min_count <= 0 {
    abort("--require-feature min_count must be greater than zero")
  }
  match validate_valid_feature_floor_by_label(label, min_count) {
    Ok(v) => v
    Err(e) => abort(e)
  }
}

///|
fn fuzz_parse_feature_key_or_abort(raw : String) -> ValidateValidFeatureKey {
  match validate_valid_feature_floor_by_label(raw, 1) {
    Ok(v) => v.key
    Err(e) => abort(e)
  }
}

///|
fn fuzz_parse_emit_gen_valid_batch_args(
  args : Array[String],
) -> EmitGenValidBatchArgs {
  let mut count : Int? = None
  let mut seed : UInt64? = None
  let mut out_dir : String? = None
  let mut profile : String? = None
  let required_features : Array[ValidateValidFeatureFloor] = []
  let excluded_features : Array[ValidateValidFeatureKey] = []
  let mut max_attempts : Int? = None
  let mut manifest_path : String? = None
  let metamorphic_transform_ids : Array[String] = []
  let mut i = 1
  while i < args.length() {
    let arg = args[i].trim().to_owned()
    if arg == "--count" {
      if i + 1 >= args.length() {
        abort("missing value for --count")
      }
      if count is Some(_) {
        abort("duplicate --count flag")
      }
      count = Some(
        fuzz_parse_non_negative_decimal_or_abort("count", args[i + 1]),
      )
      i += 2
      continue
    }
    if fuzz_has_prefix_text(arg, "--count=") {
      if count is Some(_) {
        abort("duplicate --count flag")
      }
      count = Some(
        fuzz_parse_non_negative_decimal_or_abort(
          "count",
          fuzz_tail_string(arg, 8),
        ),
      )
      i += 1
      continue
    }
    if arg == "--seed" {
      if i + 1 >= args.length() {
        abort("missing value for --seed")
      }
      if seed is Some(_) {
        abort("duplicate --seed flag")
      }
      seed = Some(fuzz_parse_uint64_or_abort(args[i + 1]))
      i += 2
      continue
    }
    if fuzz_has_seed_equals_flag(arg) {
      if seed is Some(_) {
        abort("duplicate --seed flag")
      }
      seed = Some(fuzz_parse_uint64_or_abort(fuzz_tail_string(arg, 7)))
      i += 1
      continue
    }
    if arg == "--out-dir" {
      if i + 1 >= args.length() {
        abort("missing value for --out-dir")
      }
      if out_dir is Some(_) {
        abort("duplicate --out-dir flag")
      }
      out_dir = Some(args[i + 1])
      i += 2
      continue
    }
    if fuzz_has_prefix_text(arg, "--out-dir=") {
      if out_dir is Some(_) {
        abort("duplicate --out-dir flag")
      }
      out_dir = Some(fuzz_tail_string(arg, 10))
      i += 1
      continue
    }
    if arg == "--gen-valid-profile" {
      if i + 1 >= args.length() {
        abort("missing value for --gen-valid-profile")
      }
      if profile is Some(_) {
        abort("duplicate --gen-valid-profile flag")
      }
      profile = Some(args[i + 1])
      i += 2
      continue
    }
    if fuzz_has_prefix_text(arg, "--gen-valid-profile=") {
      if profile is Some(_) {
        abort("duplicate --gen-valid-profile flag")
      }
      profile = Some(fuzz_tail_string(arg, 20))
      i += 1
      continue
    }
    if arg == "--require-feature" {
      if i + 1 >= args.length() {
        abort("missing value for --require-feature")
      }
      required_features.push(fuzz_parse_feature_floor_or_abort(args[i + 1]))
      i += 2
      continue
    }
    if fuzz_has_prefix_text(arg, "--require-feature=") {
      required_features.push(
        fuzz_parse_feature_floor_or_abort(fuzz_tail_string(arg, 18)),
      )
      i += 1
      continue
    }
    if arg == "--exclude-feature" {
      if i + 1 >= args.length() {
        abort("missing value for --exclude-feature")
      }
      excluded_features.push(fuzz_parse_feature_key_or_abort(args[i + 1]))
      i += 2
      continue
    }
    if fuzz_has_prefix_text(arg, "--exclude-feature=") {
      excluded_features.push(
        fuzz_parse_feature_key_or_abort(fuzz_tail_string(arg, 18)),
      )
      i += 1
      continue
    }
    if arg == "--max-attempts" {
      if i + 1 >= args.length() {
        abort("missing value for --max-attempts")
      }
      if max_attempts is Some(_) {
        abort("duplicate --max-attempts flag")
      }
      max_attempts = Some(
        fuzz_parse_non_negative_decimal_or_abort("max-attempts", args[i + 1]),
      )
      i += 2
      continue
    }
    if arg == "--manifest" {
      if i + 1 >= args.length() {
        abort("missing value for --manifest")
      }
      if manifest_path is Some(_) {
        abort("duplicate --manifest flag")
      }
      manifest_path = Some(args[i + 1])
      i += 2
      continue
    }
    if arg == "--metamorphic-transform" {
      if i + 1 >= args.length() {
        abort("missing value for --metamorphic-transform")
      }
      metamorphic_transform_ids.push(args[i + 1])
      i += 2
      continue
    }
    if fuzz_has_prefix_text(arg, "--max-attempts=") {
      if max_attempts is Some(_) {
        abort("duplicate --max-attempts flag")
      }
      max_attempts = Some(
        fuzz_parse_non_negative_decimal_or_abort(
          "max-attempts",
          fuzz_tail_string(arg, 15),
        ),
      )
      i += 1
      continue
    }
    if fuzz_has_prefix_text(arg, "--manifest=") {
      if manifest_path is Some(_) {
        abort("duplicate --manifest flag")
      }
      manifest_path = Some(fuzz_tail_string(arg, 11))
      i += 1
      continue
    }
    if fuzz_has_prefix_text(arg, "--metamorphic-transform=") {
      metamorphic_transform_ids.push(fuzz_tail_string(arg, 24))
      i += 1
      continue
    }
    abort("unknown flag '\{arg}'")
  }
  let resolved_count = match count {
    Some(v) => v
    None => abort("missing required --count for --emit-gen-valid-batch")
  }
  let resolved_seed = match seed {
    Some(v) => v
    None => abort("missing required --seed for --emit-gen-valid-batch")
  }
  let resolved_out_dir = match out_dir {
    Some(v) =>
      if v.trim().to_owned().length() == 0 {
        abort("--out-dir must not be empty")
      } else {
        v
      }
    None => abort("missing required --out-dir for --emit-gen-valid-batch")
  }
  let resolved_profile = match profile {
    Some(v) => v
    None => "binaryen-oracle-portable"
  }
  let resolved_max_attempts = match max_attempts {
    Some(v) => v
    None => resolved_count
  }
  EmitGenValidBatchArgs::new(
    resolved_count,
    resolved_seed,
    resolved_out_dir,
    profile=resolved_profile,
    required_features~,
    excluded_features~,
    max_attempts=resolved_max_attempts,
    manifest_path~,
    metamorphic_transform_ids~,
  )
}

///|
fn fuzz_parse_emit_invalid_repro_args(
  args : Array[String],
) -> EmitInvalidReproArgs {
  let mut suite : String? = None
  let mut strategy_id : String? = None
  let mut seed : UInt64? = None
  let mut attempt : Int? = None
  let mut profile : String? = None
  let mut out_dir : String? = None
  let mut i = 1
  while i < args.length() {
    let arg = args[i].trim().to_owned()
    if arg == "--suite" {
      if i + 1 >= args.length() {
        abort("missing value for --suite")
      }
      if suite is Some(_) {
        abort("duplicate --suite flag")
      }
      suite = Some(args[i + 1])
      i += 2
      continue
    }
    if fuzz_has_prefix_text(arg, "--suite=") {
      if suite is Some(_) {
        abort("duplicate --suite flag")
      }
      suite = Some(fuzz_tail_string(arg, 8))
      i += 1
      continue
    }
    if arg == "--strategy" {
      if i + 1 >= args.length() {
        abort("missing value for --strategy")
      }
      if strategy_id is Some(_) {
        abort("duplicate --strategy flag")
      }
      strategy_id = Some(args[i + 1])
      i += 2
      continue
    }
    if fuzz_has_prefix_text(arg, "--strategy=") {
      if strategy_id is Some(_) {
        abort("duplicate --strategy flag")
      }
      strategy_id = Some(fuzz_tail_string(arg, 11))
      i += 1
      continue
    }
    if arg == "--seed" {
      if i + 1 >= args.length() {
        abort("missing value for --seed")
      }
      if seed is Some(_) {
        abort("duplicate --seed flag")
      }
      seed = Some(fuzz_parse_uint64_or_abort(args[i + 1]))
      i += 2
      continue
    }
    if fuzz_has_seed_equals_flag(arg) {
      if seed is Some(_) {
        abort("duplicate --seed flag")
      }
      seed = Some(fuzz_parse_uint64_or_abort(fuzz_tail_string(arg, 7)))
      i += 1
      continue
    }
    if arg == "--attempt" {
      if i + 1 >= args.length() {
        abort("missing value for --attempt")
      }
      if attempt is Some(_) {
        abort("duplicate --attempt flag")
      }
      attempt = Some(
        fuzz_parse_non_negative_decimal_or_abort("attempt", args[i + 1]),
      )
      i += 2
      continue
    }
    if fuzz_has_prefix_text(arg, "--attempt=") {
      if attempt is Some(_) {
        abort("duplicate --attempt flag")
      }
      attempt = Some(
        fuzz_parse_non_negative_decimal_or_abort(
          "attempt",
          fuzz_tail_string(arg, 10),
        ),
      )
      i += 1
      continue
    }
    if arg == "--profile" {
      if i + 1 >= args.length() {
        abort("missing value for --profile")
      }
      if profile is Some(_) {
        abort("duplicate --profile flag")
      }
      profile = Some(fuzz_ascii_lower(args[i + 1].trim().to_owned()))
      i += 2
      continue
    }
    if fuzz_has_prefix_text(arg, "--profile=") {
      if profile is Some(_) {
        abort("duplicate --profile flag")
      }
      profile = Some(
        fuzz_ascii_lower(fuzz_tail_string(arg, 10).trim().to_owned()),
      )
      i += 1
      continue
    }
    if arg == "--out-dir" {
      if i + 1 >= args.length() {
        abort("missing value for --out-dir")
      }
      if out_dir is Some(_) {
        abort("duplicate --out-dir flag")
      }
      out_dir = Some(args[i + 1])
      i += 2
      continue
    }
    if fuzz_has_prefix_text(arg, "--out-dir=") {
      if out_dir is Some(_) {
        abort("duplicate --out-dir flag")
      }
      out_dir = Some(fuzz_tail_string(arg, 10))
      i += 1
      continue
    }
    abort("unknown flag '\{arg}'")
  }
  let resolved_suite = match suite {
    Some(v) =>
      if v.trim().to_owned().length() == 0 {
        abort("--suite must not be empty")
      } else {
        v
      }
    None => abort("missing required --suite for --emit-invalid-repro")
  }
  let resolved_strategy_id = match strategy_id {
    Some(v) =>
      if v.trim().to_owned().length() == 0 {
        abort("--strategy must not be empty")
      } else {
        v
      }
    None => abort("missing required --strategy for --emit-invalid-repro")
  }
  let resolved_seed = match seed {
    Some(v) => v
    None => abort("missing required --seed for --emit-invalid-repro")
  }
  let resolved_attempt = match attempt {
    Some(v) => v
    None => abort("missing required --attempt for --emit-invalid-repro")
  }
  let resolved_out_dir = match out_dir {
    Some(v) =>
      if v.trim().to_owned().length() == 0 {
        abort("--out-dir must not be empty")
      } else {
        v
      }
    None => abort("missing required --out-dir for --emit-invalid-repro")
  }
  let resolved_profile = match profile {
    Some(v) => v
    None => "smoke"
  }
  EmitInvalidReproArgs::new(
    resolved_suite,
    resolved_strategy_id,
    resolved_seed,
    resolved_attempt,
    resolved_out_dir,
    profile=resolved_profile,
  )
}

///|
fn fuzz_parse_control_command(arg : String) -> FuzzCliCommand? {
  let normalized = fuzz_ascii_lower(arg.trim().to_owned())
  match normalized {
    "--help" => Some(FuzzCliCommand::Help)
    "-h" => Some(FuzzCliCommand::Help)
    "--list-suites" => Some(FuzzCliCommand::ListSuites)
    "--list-profiles" => Some(FuzzCliCommand::ListProfiles)
    "--list-recipes" => Some(FuzzCliCommand::ListRecipes)
    _ => None
  }
}

///|
pub fn parse_fuzz_cli_command(args : Array[String]) -> FuzzCliCommand {
  if args.length() > 0 {
    let command = fuzz_ascii_lower(args[0].trim().to_owned())
    if command == "--emit-gen-valid-batch" {
      return FuzzCliCommand::EmitGenValidBatch(
        fuzz_parse_emit_gen_valid_batch_args(args),
      )
    }
    if command == "--emit-invalid-repro" {
      return FuzzCliCommand::EmitInvalidRepro(
        fuzz_parse_emit_invalid_repro_args(args),
      )
    }
    if command == "--replay-corpus" {
      if args.length() != 2 {
        abort("usage: --replay-corpus <replay-manifest.json>")
      }
      return FuzzCliCommand::ReplayCorpus(args[1])
    }
    if command == "--golden-seed-smoke" {
      if args.length() != 1 {
        abort("usage: --golden-seed-smoke")
      }
      return FuzzCliCommand::GoldenSeedSmoke
    }
  }
  let mut control : FuzzCliCommand? = None
  let mut i = 0
  while i < args.length() {
    match fuzz_parse_control_command(args[i]) {
      Some(cmd) => {
        if control is Some(_) {
          abort("control flags must be provided alone")
        }
        control = Some(cmd)
      }
      None => ()
    }
    i += 1
  }
  match control {
    Some(cmd) => {
      if args.length() != 1 {
        abort("control flags must be provided alone")
      }
      cmd
    }
    None => FuzzCliCommand::Run(parse_fuzz_cli_args(args))
  }
}

///|
pub fn parse_fuzz_recipe_text(text : String) -> Result[FuzzRecipe, String] {
  let mut schema : String? = None
  let mut name : String? = None
  let mut suite : String? = None
  let mut profile : String? = None
  let mut seed : Int64? = None
  let mut output_mode : FuzzOutputMode? = None
  let mut seed_count : Int? = None
  let mut shard_count : Int? = None
  for raw_line in text.split("\n") {
    let line = raw_line.trim().to_owned()
    if line.length() == 0 || line[0] == '#' {
      continue
    }
    let mut eq_index = -1
    let mut scan_index = 0
    while scan_index < line.length() {
      if line[scan_index] == '=' {
        eq_index = scan_index
        break
      }
      scan_index += 1
    }
    if eq_index < 0 {
      return Err("recipe lines must be key=value: \{line}")
    }
    let key = fuzz_ascii_lower(line[:eq_index].to_owned().trim().to_owned())
    let value = line[eq_index + 1:].to_owned().trim().to_owned()
    match key {
      "schema" => schema = Some(value)
      "name" => name = Some(value)
      "suite" => suite = Some(fuzz_ascii_lower(value))
      "profile" => profile = Some(fuzz_ascii_lower(value))
      "seed" =>
        match fuzz_parse_seed(value) {
          Ok(v) => seed = Some(v)
          Err(e) => return Err(e)
        }
      "output" =>
        match fuzz_parse_output_mode(value) {
          Ok(v) => output_mode = Some(v)
          Err(e) => return Err(e)
        }
      "seed-count" =>
        seed_count = Some(
          fuzz_parse_non_negative_decimal_or_abort("seed-count", value),
        )
      "shard-count" =>
        shard_count = Some(
          fuzz_parse_non_negative_decimal_or_abort("shard-count", value),
        )
      _ => return Err("unknown recipe key '\{key}'")
    }
  }
  let resolved_schema = match schema {
    Some(v) => v
    None => return Err("recipe missing schema")
  }
  if resolved_schema != fuzz_recipe_schema_version() {
    return Err("unsupported recipe schema '\{resolved_schema}'")
  }
  let resolved_name = match name {
    Some(v) => v
    None => return Err("recipe missing name")
  }
  let resolved_suite = match suite {
    Some(v) => v
    None => return Err("recipe missing suite")
  }
  let resolved_profile = match profile {
    Some(v) => v
    None => "smoke"
  }
  let resolved_seed = match seed {
    Some(v) => v
    None => 0L
  }
  let resolved_output = match output_mode {
    Some(v) => v
    None => FuzzOutputMode::Text
  }
  let resolved_seed_count = match seed_count {
    Some(v) => v
    None => 1
  }
  let resolved_shard_count = match shard_count {
    Some(v) => v
    None => 1
  }
  if resolved_seed_count <= 0 {
    return Err("seed-count must be greater than zero")
  }
  if resolved_shard_count <= 0 {
    return Err("shard-count must be greater than zero")
  }
  Ok(
    FuzzRecipe::new(
      resolved_name,
      resolved_suite,
      resolved_profile,
      resolved_seed,
      output_mode=resolved_output,
      seed_count=resolved_seed_count,
      shard_count=resolved_shard_count,
    ),
  )
}

///|
pub fn parse_fuzz_cli_args(args : Array[String]) -> FuzzCliArgs {
  let mut recipe : FuzzRecipe? = None
  let mut i = 0
  while i < args.length() {
    let arg = args[i].trim().to_owned()
    if arg == "--recipe" {
      if i + 1 >= args.length() {
        abort("missing value for --recipe")
      }
      if recipe is Some(_) {
        abort("duplicate --recipe flag")
      }
      let name = args[i + 1].trim().to_owned()
      recipe = match fuzz_standard_recipe_by_name(name) {
        Some(v) => Some(v)
        None => abort("unknown fuzz recipe '\{name}'")
      }
      i += 2
      continue
    }
    if fuzz_has_prefix_text(arg, "--recipe=") {
      if recipe is Some(_) {
        abort("duplicate --recipe flag")
      }
      let name = fuzz_tail_string(arg, 9)
      recipe = match fuzz_standard_recipe_by_name(name) {
        Some(v) => Some(v)
        None => abort("unknown fuzz recipe '\{name}'")
      }
    }
    i += 1
  }
  parse_fuzz_cli_args_with_recipe(args, recipe)
}

///|
pub fn parse_fuzz_cli_args_with_recipe(
  args : Array[String],
  recipe : FuzzRecipe?,
) -> FuzzCliArgs {
  let positional : Array[String] = []
  let mut flag_seed : Int64? = None
  let mut output_mode : FuzzOutputMode? = None
  let mut seed_count : Int? = None
  let mut shard_index : Int? = None
  let mut shard_count : Int? = None
  let mut report_json_path : String? = None
  let mut out_dir : String? = None
  let mut flag_suite : String? = None
  let mut flag_profile : String? = None
  let mut i = 0
  while i < args.length() {
    let arg = args[i].trim().to_owned()
    if arg == "--recipe" {
      if i + 1 >= args.length() {
        abort("missing value for --recipe")
      }
      i += 2
      continue
    }
    if fuzz_has_prefix_text(arg, "--recipe=") {
      i += 1
      continue
    }
    if arg == "--suite" {
      if i + 1 >= args.length() {
        abort("missing value for --suite")
      }
      if flag_suite is Some(_) {
        abort("duplicate --suite flag")
      }
      flag_suite = Some(fuzz_ascii_lower(args[i + 1].trim().to_owned()))
      i += 2
      continue
    }
    if fuzz_has_prefix_text(arg, "--suite=") {
      if flag_suite is Some(_) {
        abort("duplicate --suite flag")
      }
      flag_suite = Some(fuzz_ascii_lower(fuzz_tail_string(arg, 8)))
      i += 1
      continue
    }
    if arg == "--profile" {
      if i + 1 >= args.length() {
        abort("missing value for --profile")
      }
      if flag_profile is Some(_) {
        abort("duplicate --profile flag")
      }
      flag_profile = Some(fuzz_ascii_lower(args[i + 1].trim().to_owned()))
      i += 2
      continue
    }
    if fuzz_has_prefix_text(arg, "--profile=") {
      if flag_profile is Some(_) {
        abort("duplicate --profile flag")
      }
      flag_profile = Some(fuzz_ascii_lower(fuzz_tail_string(arg, 10)))
      i += 1
      continue
    }
    if arg == "--seed" {
      if i + 1 >= args.length() {
        abort("missing value for --seed")
      }
      if flag_seed is Some(_) {
        abort("duplicate --seed flag")
      }
      flag_seed = Some(fuzz_parse_seed_or_abort(args[i + 1]))
      i += 2
      continue
    }
    if fuzz_has_seed_equals_flag(arg) {
      if flag_seed is Some(_) {
        abort("duplicate --seed flag")
      }
      flag_seed = Some(fuzz_parse_seed_or_abort(fuzz_tail_string(arg, 7)))
      i += 1
      continue
    }
    if arg == "--output" {
      if i + 1 >= args.length() {
        abort("missing value for --output")
      }
      if output_mode is Some(_) {
        abort("duplicate output mode flag")
      }
      output_mode = Some(fuzz_parse_output_or_abort(args[i + 1]))
      i += 2
      continue
    }
    if fuzz_has_output_equals_flag(arg) {
      if output_mode is Some(_) {
        abort("duplicate output mode flag")
      }
      output_mode = Some(fuzz_parse_output_or_abort(fuzz_tail_string(arg, 9)))
      i += 1
      continue
    }
    if arg == "--jsonl" {
      if output_mode is Some(_) {
        abort("duplicate output mode flag")
      }
      output_mode = Some(FuzzOutputMode::Jsonl)
      i += 1
      continue
    }
    if arg == "--seed-count" {
      if i + 1 >= args.length() {
        abort("missing value for --seed-count")
      }
      if seed_count is Some(_) {
        abort("duplicate --seed-count flag")
      }
      seed_count = Some(
        fuzz_parse_non_negative_decimal_or_abort("seed-count", args[i + 1]),
      )
      i += 2
      continue
    }
    if fuzz_has_prefix_text(arg, "--seed-count=") {
      if seed_count is Some(_) {
        abort("duplicate --seed-count flag")
      }
      seed_count = Some(
        fuzz_parse_non_negative_decimal_or_abort(
          "seed-count",
          fuzz_tail_string(arg, 13),
        ),
      )
      i += 1
      continue
    }
    if arg == "--shard-index" {
      if i + 1 >= args.length() {
        abort("missing value for --shard-index")
      }
      if shard_index is Some(_) {
        abort("duplicate --shard-index flag")
      }
      shard_index = Some(
        fuzz_parse_non_negative_decimal_or_abort("shard-index", args[i + 1]),
      )
      i += 2
      continue
    }
    if fuzz_has_prefix_text(arg, "--shard-index=") {
      if shard_index is Some(_) {
        abort("duplicate --shard-index flag")
      }
      shard_index = Some(
        fuzz_parse_non_negative_decimal_or_abort(
          "shard-index",
          fuzz_tail_string(arg, 14),
        ),
      )
      i += 1
      continue
    }
    if arg == "--shard-count" {
      if i + 1 >= args.length() {
        abort("missing value for --shard-count")
      }
      if shard_count is Some(_) {
        abort("duplicate --shard-count flag")
      }
      shard_count = Some(
        fuzz_parse_non_negative_decimal_or_abort("shard-count", args[i + 1]),
      )
      i += 2
      continue
    }
    if fuzz_has_prefix_text(arg, "--shard-count=") {
      if shard_count is Some(_) {
        abort("duplicate --shard-count flag")
      }
      shard_count = Some(
        fuzz_parse_non_negative_decimal_or_abort(
          "shard-count",
          fuzz_tail_string(arg, 14),
        ),
      )
      i += 1
      continue
    }
    if arg == "--out-dir" {
      if i + 1 >= args.length() {
        abort("missing value for --out-dir")
      }
      if out_dir is Some(_) {
        abort("duplicate --out-dir flag")
      }
      out_dir = Some(args[i + 1])
      i += 2
      continue
    }
    if fuzz_has_prefix_text(arg, "--out-dir=") {
      if out_dir is Some(_) {
        abort("duplicate --out-dir flag")
      }
      out_dir = Some(fuzz_tail_string(arg, 10))
      i += 1
      continue
    }
    if arg == "--report-json" {
      if i + 1 >= args.length() {
        abort("missing value for --report-json")
      }
      if report_json_path is Some(_) {
        abort("duplicate --report-json flag")
      }
      report_json_path = Some(args[i + 1])
      i += 2
      continue
    }
    if fuzz_has_prefix_text(arg, "--report-json=") {
      if report_json_path is Some(_) {
        abort("duplicate --report-json flag")
      }
      report_json_path = Some(fuzz_tail_string(arg, 14))
      i += 1
      continue
    }
    if arg.length() >= 2 && arg[0] == '-' && arg[1] == '-' {
      abort("unknown flag '\{arg}'")
    }
    positional.push(arg)
    i += 1
  }
  if positional.length() > 3 {
    abort("\{fuzz_usage_text()}")
  }
  let recipe_suite = match recipe {
    Some(v) => Some(v.suite)
    None => None
  }
  let recipe_profile = match recipe {
    Some(v) => Some(v.profile)
    None => None
  }
  let suite = match flag_suite {
    Some(v) => v
    None =>
      if positional.length() >= 1 {
        fuzz_ascii_lower(positional[0].trim().to_owned())
      } else {
        match recipe_suite {
          Some(v) => v
          None => "all"
        }
      }
  }
  let profile = match flag_profile {
    Some(v) => v
    None =>
      if positional.length() >= 2 {
        fuzz_ascii_lower(positional[1].trim().to_owned())
      } else {
        match recipe_profile {
          Some(v) => v
          None => "smoke"
        }
      }
  }
  let positional_seed = if positional.length() >= 3 {
    Some(fuzz_parse_seed_or_abort(positional[2]))
  } else {
    None
  }
  let seed_i64 = match (flag_seed, positional_seed) {
    (Some(_), Some(_)) =>
      abort("seed provided both as positional argument and --seed flag")
    (Some(v), None) => v
    (None, Some(v)) => v
    (None, None) =>
      match recipe {
        Some(v) => v.seed_i64
        None => fuzz_generate_seed_i64()
      }
  }
  let seed = seed_i64.reinterpret_as_uint64()
  let out_mode = match output_mode {
    Some(mode) => mode
    None =>
      match recipe {
        Some(v) => v.output_mode
        None => FuzzOutputMode::Text
      }
  }
  let resolved_seed_count = match seed_count {
    Some(v) => v
    None =>
      match recipe {
        Some(v) => v.seed_count
        None => 1
      }
  }
  if resolved_seed_count <= 0 {
    abort("seed-count must be greater than zero")
  }
  let resolved_shard_count = match shard_count {
    Some(v) => v
    None =>
      match recipe {
        Some(v) => v.shard_count
        None => 1
      }
  }
  if resolved_shard_count <= 0 {
    abort("shard-count must be greater than zero")
  }
  let resolved_shard_index = match shard_index {
    Some(v) => v
    None => 0
  }
  if resolved_shard_index >= resolved_shard_count {
    abort("shard-index must be less than shard-count")
  }
  let resolved_report_json_path = match report_json_path {
    Some(v) =>
      if v.trim().to_owned().length() == 0 {
        abort("--report-json must not be empty")
      } else {
        Some(v)
      }
    None => None
  }
  let resolved_out_dir = match out_dir {
    Some(v) =>
      if v.trim().to_owned().length() == 0 {
        abort("--out-dir must not be empty")
      } else {
        Some(v)
      }
    None => None
  }
  FuzzCliArgs::{
    suite,
    profile,
    seed,
    seed_i64,
    output_mode: out_mode,
    seed_count: resolved_seed_count,
    shard_index: resolved_shard_index,
    shard_count: resolved_shard_count,
    report_json_path: resolved_report_json_path,
    out_dir: resolved_out_dir,
  }
}

///|
fn run_single_suite(
  suite : String,
  profile : String,
  seed_i64 : Int64,
) -> Result[FuzzSuiteResult, String] {
  let seed = seed_i64.reinterpret_as_uint64()
  let start_ms = trace_now_ms()
  let (attempts, details_json) = match suite {
    "binary-roundtrip" =>
      match run_binary_roundtrip_fuzz(profile, seed) {
        Ok(stats) =>
          (stats.attempts, Some(format_binary_roundtrip_details_json(stats)))
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed_i64}: \{e}")
      }
    "wast-roundtrip" =>
      match run_wast_roundtrip_fuzz(profile, seed) {
        Ok(stats) => (stats.attempts, None)
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed_i64}: \{e}")
      }
    "wat-roundtrip" =>
      match run_wat_roundtrip_fuzz(profile, seed) {
        Ok(stats) =>
          (stats.attempts, Some(format_wat_roundtrip_details_json(stats)))
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed_i64}: \{e}")
      }
    "wast-validate-roundtrip" =>
      match run_wast_validate_roundtrip_fuzz(profile, seed) {
        Ok(stats) =>
          (stats.attempts, Some(format_wast_validate_details_json(stats)))
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed_i64}: \{e}")
      }
    "gen-valid-wat-validate-roundtrip" =>
      match run_gen_valid_wat_validate_roundtrip_fuzz(profile, seed) {
        Ok(stats) =>
          (
            stats.attempts,
            Some(format_gen_valid_wat_validate_details_json(stats)),
          )
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed_i64}: \{e}")
      }
    "valid-multi-module-linking" =>
      match run_valid_multi_module_linking_fuzz(profile, seed) {
        Ok(stats) =>
          (
            stats.attempts,
            Some(format_valid_multi_module_linking_details_json(stats)),
          )
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed_i64}: \{e}")
      }
    "validate-valid" =>
      match run_validate_valid_suite_detailed(profile, seed) {
        Ok(v) => v
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed_i64}: \{e}")
      }
    "validate-valid-metamorphic" =>
      match run_validate_valid_metamorphic_fuzz(profile, seed) {
        Ok(stats) =>
          (
            stats.attempts,
            Some(format_validate_valid_metamorphic_details_json(stats)),
          )
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed_i64}: \{e}")
      }
    "validate-invalid-ast" =>
      match run_validate_invalid_ast_fuzz(profile, seed) {
        Ok(stats) =>
          (stats.attempts, Some(format_invalid_ast_details_json(stats)))
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed_i64}: \{e}")
      }
    "validate-invalid-binary" =>
      match run_validate_invalid_binary_fuzz(profile, seed) {
        Ok(stats) =>
          (stats.attempts, Some(format_invalid_binary_details_json(stats)))
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed_i64}: \{e}")
      }
    "validate-invalid-text" =>
      match run_validate_invalid_text_fuzz(profile, seed) {
        Ok(stats) =>
          (stats.attempts, Some(format_invalid_text_details_json(stats)))
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed_i64}: \{e}")
      }
    "validate-invalid-text-dynamic" =>
      match run_validate_invalid_text_dynamic_fuzz(profile, seed) {
        Ok(stats) =>
          (
            stats.attempts,
            Some(format_invalid_text_dynamic_details_json(stats)),
          )
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed_i64}: \{e}")
      }
    "validate-invalid-spec-seed" =>
      match run_validate_invalid_spec_seed_fuzz(profile, seed) {
        Ok(stats) =>
          (stats.attempts, Some(format_invalid_spec_seed_details_json(stats)))
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed_i64}: \{e}")
      }
    "cmd-harness" =>
      match run_fuzz_cmd_harness_profile(profile, seed) {
        Ok(attempts) => (attempts, None)
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed_i64}: \{e}")
      }
    "text-differential" =>
      match run_text_differential_fuzz(profile, seed) {
        Ok(stats) =>
          (stats.attempts, Some(format_text_differential_details_json(stats)))
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed_i64}: \{e}")
      }
    _ => return Err("unknown suite '\{suite}'")
  }
  Ok(FuzzSuiteResult::{
    suite,
    profile,
    seed: seed_i64,
    attempts,
    elapsed_ms: trace_elapsed_ms(start_ms),
    seed_index: 0,
    seed_count: 1,
    shard_index: 0,
    shard_count: 1,
    total_run_budget_ms: None,
    total_run_budget_exceeded: false,
    run_budget_classification: "within-budget",
    details_json,
  })
}

///|
fn fuzz_zero_pad_decimal(value : Int, width : Int) -> String {
  let raw = value.to_string()
  if raw.length() >= width {
    return raw
  }
  let out = StringBuilder::new()
  let mut i = raw.length()
  while i < width {
    out.write_char('0')
    i += 1
  }
  out.write_string(raw)
  out.to_string()
}

///|
fn fuzz_join_path(dir : String, name : String) -> String {
  if dir.length() == 0 || dir == "." {
    return name
  }
  let last = dir[dir.length() - 1]
  if last == '/' || last == '\\' {
    "\{dir}\{name}"
  } else {
    "\{dir}/\{name}"
  }
}

///|
fn emit_gen_valid_batch_config() -> GenValidConfig {
  GenValidConfig::binaryen_oracle_coverage_forced_default()
}

///|
pub struct GenValidBatchManifestEntry {
  file_name : String
  seed : UInt64
  index : Int
  config_label : String
  attempts : Int
  validated : Bool
  validation_error_message : String?
  facts : GenValidFeatureFacts
  transform_id : String?
} derive(Eq, Debug)

///|
pub struct GenValidBatchArtifacts {
  artifacts : Array[(String, Bytes)]
  manifest : Array[GenValidBatchManifestEntry]
} derive(Eq, Debug)

///|
pub struct GenValidCoverageSelection {
  artifacts : Array[(String, Bytes)]
  manifest : Array[GenValidBatchManifestEntry]
  feature_stats : GenValidFeatureStats
  floor_failures : Array[ValidateValidFeatureFloorFailure]
  selected : Int
  attempts : Int
  skipped_candidates : Int
} derive(Eq, Debug)

///|
pub enum GoldenSeedCounterKind {
  Exact
  Minimum
} derive(Eq, Debug)

///|
pub struct GoldenSeedExpectedCounter {
  name : String
  kind : GoldenSeedCounterKind
  value : Int
} derive(Eq, Debug)

///|
pub fn GoldenSeedExpectedCounter::exact(
  name : String,
  value : Int,
) -> GoldenSeedExpectedCounter {
  { name, kind: GoldenSeedCounterKind::Exact, value }
}

///|
pub fn GoldenSeedExpectedCounter::minimum(
  name : String,
  value : Int,
) -> GoldenSeedExpectedCounter {
  { name, kind: GoldenSeedCounterKind::Minimum, value }
}

///|
pub struct GoldenSeedCatalogEntry {
  id : String
  suite : String
  profile : String
  seed : UInt64
  expected_counters : Array[GoldenSeedExpectedCounter]
  covered_surfaces : Array[String]
  artifacts : Array[String]
  notes : String
} derive(Eq, Debug)

///|
pub fn GoldenSeedCatalogEntry::new(
  id : String,
  suite : String,
  profile : String,
  seed : UInt64,
  expected_counters? : Array[GoldenSeedExpectedCounter] = [],
  covered_surfaces? : Array[String] = [],
  artifacts? : Array[String] = [],
  notes? : String = "",
) -> GoldenSeedCatalogEntry {
  {
    id,
    suite,
    profile,
    seed,
    expected_counters,
    covered_surfaces,
    artifacts,
    notes,
  }
}

///|
pub fn golden_seed_smoke_suite_catalog() -> Array[GoldenSeedCatalogEntry] {
  [
    GoldenSeedCatalogEntry::new(
      "gen-valid-coverage-forced-smoke",
      "validate-valid",
      "smoke",
      0xf71004UL,
      expected_counters=[
        GoldenSeedExpectedCounter::minimum("validated", 1),
        GoldenSeedExpectedCounter::minimum("features.v128", 1),
      ],
      covered_surfaces=["GenValid", "valid-generation", "coverage-forced"],
      artifacts=["inputs/gen-valid/manifest.json", "result.json"],
      notes="coverage-forced GenValid seed that anchors the portable valid-module smoke lane",
    ),
    GoldenSeedCatalogEntry::new(
      "invalid-ast-repro-smoke",
      "validate-invalid-ast",
      "smoke",
      0x10d69UL,
      expected_counters=[
        GoldenSeedExpectedCounter::minimum("rejected_expected", 1),
      ],
      covered_surfaces=["invalid-ast", "validator", "repro-metadata"],
      artifacts=["failure.json", "input.wasm"],
      notes="deterministic invalid-AST repro seed covering strategy metadata and validator rejection",
    ),
    GoldenSeedCatalogEntry::new(
      "invalid-binary-repro-smoke",
      "validate-invalid-binary",
      "smoke",
      0xb1a27UL,
      expected_counters=[
        GoldenSeedExpectedCounter::minimum("decode_or_validate_failures", 1),
      ],
      covered_surfaces=["invalid-binary", "decoder", "validator"],
      artifacts=["failure.json", "input.wasm"],
      notes="binary-invalid seed for decode and validation-stage repro metadata",
    ),
    GoldenSeedCatalogEntry::new(
      "invalid-text-repro-smoke",
      "validate-invalid-text",
      "smoke",
      0x7e57UL,
      expected_counters=[
        GoldenSeedExpectedCounter::minimum("rejected_expected", 1),
      ],
      covered_surfaces=["invalid-text", "parser", "lowerer"],
      artifacts=["failure.json", "input.wat"],
      notes="text-invalid seed spanning parse/lower/validate diagnostics",
    ),
    GoldenSeedCatalogEntry::new(
      "pass-fuzz-metadata-smoke",
      "pass-fuzz-compare",
      "smoke",
      0x5eedUL,
      expected_counters=[GoldenSeedExpectedCounter::minimum("compared", 1)],
      covered_surfaces=[
        "pass-fuzz-metadata", "Binaryen-oracle", "normalization",
      ],
      artifacts=["result.json", "cases.jsonl"],
      notes="pass-fuzz metadata seed used by optimizer parity smoke checks",
    ),
    GoldenSeedCatalogEntry::new(
      "minimization-repro-smoke",
      "reducer",
      "smoke",
      0x1043UL,
      expected_counters=[
        GoldenSeedExpectedCounter::minimum("predicate_reproduced", 1),
      ],
      covered_surfaces=["minimization", "replay", "failure-predicate"],
      artifacts=["reduced.wasm", "reduction.json"],
      notes="reserved deterministic minimization surface for reducer smoke replay",
    ),
    GoldenSeedCatalogEntry::new(
      "wast-roundtrip-smoke",
      "wast-roundtrip",
      "smoke",
      0x51a7UL,
      expected_counters=[GoldenSeedExpectedCounter::minimum("parsed", 1)],
      covered_surfaces=["text", "wast", "roundtrip"],
      artifacts=["result.json"],
      notes="text/WAST roundtrip seed covering non-binary fuzz infrastructure",
    ),
  ]
}

///|
fn gen_valid_coverage_feature_label(key : ValidateValidFeatureKey) -> String {
  match key {
    @validate.ValidateValidFeatureKey::Imports => "imports"
    @validate.ValidateValidFeatureKey::FuncExports => "func_exports"
    @validate.ValidateValidFeatureKey::TableExports => "table_exports"
    @validate.ValidateValidFeatureKey::MemExports => "mem_exports"
    @validate.ValidateValidFeatureKey::GlobalExports => "global_exports"
    @validate.ValidateValidFeatureKey::TagExports => "tag_exports"
    @validate.ValidateValidFeatureKey::Starts => "starts"
    @validate.ValidateValidFeatureKey::LacksStart => "lacks_start"
    @validate.ValidateValidFeatureKey::Tables => "tables"
    @validate.ValidateValidFeatureKey::Mems => "mems"
    @validate.ValidateValidFeatureKey::Globals => "globals"
    @validate.ValidateValidFeatureKey::Tags => "tags"
    @validate.ValidateValidFeatureKey::Elems => "elems"
    @validate.ValidateValidFeatureKey::Datas => "datas"
    @validate.ValidateValidFeatureKey::DataCount => "data_count"
    @validate.ValidateValidFeatureKey::RefTypes => "ref_types"
    @validate.ValidateValidFeatureKey::V128 => "v128"
    @validate.ValidateValidFeatureKey::Calls => "calls"
    @validate.ValidateValidFeatureKey::CallIndirect => "call_indirect"
    @validate.ValidateValidFeatureKey::BranchHeavyControl =>
      "branch_heavy_control"
    @validate.ValidateValidFeatureKey::PayloadControlFlow =>
      "payload_control_flow"
    @validate.ValidateValidFeatureKey::MultivalueControlFlow =>
      "multivalue_control_flow"
    @validate.ValidateValidFeatureKey::NumericFullOps => "numeric_full_ops"
    @validate.ValidateValidFeatureKey::BrTable => "br_table"
    @validate.ValidateValidFeatureKey::StandaloneUnreachable =>
      "standalone_unreachable"
    @validate.ValidateValidFeatureKey::LocalTee => "local_tee"
    @validate.ValidateValidFeatureKey::TypedSelect => "typed_select"
    @validate.ValidateValidFeatureKey::TailCalls => "tail_calls"
    @validate.ValidateValidFeatureKey::ScalarMemoryWidths =>
      "scalar_memory_widths"
    @validate.ValidateValidFeatureKey::NonzeroMemarg => "nonzero_memarg"
    @validate.ValidateValidFeatureKey::MemoryLimitVariants =>
      "memory_limit_variants"
    @validate.ValidateValidFeatureKey::TableLimitVariants =>
      "table_limit_variants"
    @validate.ValidateValidFeatureKey::ConstExprVariants =>
      "const_expr_variants"
    @validate.ValidateValidFeatureKey::BasicRefInstructions =>
      "basic_ref_instructions"
    @validate.ValidateValidFeatureKey::I31ExternConversions =>
      "i31_extern_conversions"
    @validate.ValidateValidFeatureKey::GcConstructors => "gc_constructors"
    @validate.ValidateValidFeatureKey::GcAccessors => "gc_accessors"
    @validate.ValidateValidFeatureKey::StringOps => "string_ops"
    @validate.ValidateValidFeatureKey::ExceptionTryTableMatrix =>
      "exception_try_table_matrix"
    @validate.ValidateValidFeatureKey::SimdPhase1 => "simd_phase1"
    @validate.ValidateValidFeatureKey::SimdPhase2 => "simd_phase2"
    @validate.ValidateValidFeatureKey::SimdPhase3 => "simd_phase3"
    @validate.ValidateValidFeatureKey::Atomics => "atomics"
    @validate.ValidateValidFeatureKey::SubtypingTopology => "subtyping_topology"
    @validate.ValidateValidFeatureKey::RichGcFieldPlans => "rich_gc_field_plans"
    @validate.ValidateValidFeatureKey::ImportExportTopology =>
      "import_export_topology"
    @validate.ValidateValidFeatureKey::ElementSegmentRange =>
      "element_segment_range"
    @validate.ValidateValidFeatureKey::DataSegmentRange => "data_segment_range"
    @validate.ValidateValidFeatureKey::NameCustomSections =>
      "name_custom_sections"
    @validate.ValidateValidFeatureKey::GcExceptionCombo => "gc_exception_combo"
    @validate.ValidateValidFeatureKey::GcTailCallCombo => "gc_tail_call_combo"
    @validate.ValidateValidFeatureKey::SharedMemoryAtomics =>
      "shared_memory_atomics"
    @validate.ValidateValidFeatureKey::ImportsStartExports =>
      "imports_start_exports"
    @validate.ValidateValidFeatureKey::InvalidAstStrategies =>
      "invalid_ast_strategies"
    @validate.ValidateValidFeatureKey::InvalidBinaryStrategies =>
      "invalid_binary_strategies"
    @validate.ValidateValidFeatureKey::WastArbitraryParity =>
      "wast_arbitrary_parity"
    @validate.ValidateValidFeatureKey::SsaStraightLineLocalChain =>
      "ssa-straight-line-local-chain"
    @validate.ValidateValidFeatureKey::SsaAlreadySsaLocal =>
      "ssa-already-ssa-local"
    @validate.ValidateValidFeatureKey::SsaMultiDefSameLocal =>
      "ssa-multi-def-same-local"
    @validate.ValidateValidFeatureKey::SsaParamEntryRead =>
      "ssa-param-entry-read"
    @validate.ValidateValidFeatureKey::SsaLocalTeeDefUse =>
      "ssa-local-tee-def-use"
    @validate.ValidateValidFeatureKey::SsaTeeFreshenCandidate =>
      "ssa-tee-freshen-candidate"
    @validate.ValidateValidFeatureKey::SsaTeeMergeFeedingCandidate =>
      "ssa-tee-merge-feeding-candidate"
    @validate.ValidateValidFeatureKey::SsaTeeChildExpression =>
      "ssa-tee-child-expression"
    @validate.ValidateValidFeatureKey::SsaParamWrite => "ssa-param-write"
    @validate.ValidateValidFeatureKey::SsaDeadLocalSet => "ssa-dead-local-set"
    @validate.ValidateValidFeatureKey::SsaDeadLocalTee => "ssa-dead-local-tee"
    @validate.ValidateValidFeatureKey::SsaIfJoinPhiCandidate =>
      "ssa-if-join-phi-candidate"
    @validate.ValidateValidFeatureKey::SsaLoopBackedgePhiCandidate =>
      "ssa-loop-backedge-phi-candidate"
    @validate.ValidateValidFeatureKey::SsaBrTablePhiCandidate =>
      "ssa-br-table-phi-candidate"
    @validate.ValidateValidFeatureKey::SsaParallelCopyCandidate =>
      "ssa-parallel-copy-candidate"
    @validate.ValidateValidFeatureKey::SsaParallelCopyCycleCandidate =>
      "ssa-parallel-copy-cycle-candidate"
    @validate.ValidateValidFeatureKey::SsaDefaultLocalMerge =>
      "ssa-default-local-merge"
    @validate.ValidateValidFeatureKey::SsaOneArmDefaultMerge =>
      "ssa-one-arm-default-merge"
    @validate.ValidateValidFeatureKey::SsaOneArmParamMerge =>
      "ssa-one-arm-param-merge"
    @validate.ValidateValidFeatureKey::SsaBothArmLocalMerge =>
      "ssa-both-arm-local-merge"
    @validate.ValidateValidFeatureKey::SsaLoopCarriedLocalMerge =>
      "ssa-loop-carried-local-merge"
    @validate.ValidateValidFeatureKey::SsaMixedFreshCanonicalWrites =>
      "ssa-mixed-fresh-canonical-writes"
    @validate.ValidateValidFeatureKey::SsaUnreachableLocalCarrier =>
      "ssa-unreachable-local-carrier"
    @validate.ValidateValidFeatureKey::SsaDroppedIncrementGuardShape =>
      "ssa-dropped-increment-guard-shape"
    @validate.ValidateValidFeatureKey::SsaDroppedIncrementReversedBoundary =>
      "ssa-dropped-increment-reversed-boundary"
    @validate.ValidateValidFeatureKey::SsaExceptionalFailClosedShape =>
      "ssa-exceptional-fail-closed-shape"
    @validate.ValidateValidFeatureKey::SsaTypedLoopParamFailClosedShape =>
      "ssa-typed-loop-param-fail-closed-shape"
    @validate.ValidateValidFeatureKey::SsaNestedCfgFailClosedShape =>
      "ssa-nested-cfg-fail-closed-shape"
    @validate.ValidateValidFeatureKey::SsaNestedResultIfSupportedShape =>
      "ssa-nested-result-if-supported-shape"
    @validate.ValidateValidFeatureKey::SsaNestedResultIfConditionWrite =>
      "ssa-nested-result-if-condition-write"
    @validate.ValidateValidFeatureKey::SsaNestedResultIfConditionValueBlock =>
      "ssa-nested-result-if-condition-value-block"
    @validate.ValidateValidFeatureKey::SsaNestedResultIfArmValueBlock =>
      "ssa-nested-result-if-arm-value-block"
    @validate.ValidateValidFeatureKey::SsaNestedResultIfMixedArmValueBlock =>
      "ssa-nested-result-if-mixed-arm-value-block"
    @validate.ValidateValidFeatureKey::SsaNestedResultIfScalarResult =>
      "ssa-nested-result-if-scalar-result"
    @validate.ValidateValidFeatureKey::SsaStructuredEarlyReturnLocal =>
      "ssa-structured-early-return-local"
    @validate.ValidateValidFeatureKey::SsaBlockBranchMergeCopy =>
      "ssa-block-branch-merge-copy"
    @validate.ValidateValidFeatureKey::SsaBlockBrIfMergeCopy =>
      "ssa-block-br-if-merge-copy"
    @validate.ValidateValidFeatureKey::SsaStructuredParamMerge =>
      "ssa-structured-param-merge"
    @validate.ValidateValidFeatureKey::SsaBranchLocalNotReadLater =>
      "ssa-branch-local-not-read-later"
    @validate.ValidateValidFeatureKey::SsaDefaultLocalReadAfterBranchyControl =>
      "ssa-default-local-read-after-branchy-control"
    @validate.ValidateValidFeatureKey::SsaDroppedUnreachableDebrisBeforeHardUnreachable =>
      "ssa-dropped-unreachable-debris-before-hard-unreachable"
    @validate.ValidateValidFeatureKey::SsaCanonicalBodyLocalNextRead =>
      "ssa-canonical-body-local-next-read"
    @validate.ValidateValidFeatureKey::SsaImmediateBlockExitCanonicalSetBr =>
      "ssa-immediate-block-exit-canonical-set-br"
    @validate.ValidateValidFeatureKey::SsaEnclosingLabelCopyBeforeExit =>
      "ssa-enclosing-label-copy-before-exit"
    @validate.ValidateValidFeatureKey::SsaVoidBrTableCanonicalCopies =>
      "ssa-void-br-table-canonical-copies"
  }
}

///|
fn gen_valid_coverage_floor_failures_message(
  failures : Array[ValidateValidFeatureFloorFailure],
) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  while i < failures.length() {
    if i > 0 {
      out.write_string(", ")
    }
    let failure = failures[i]
    out.write_string(
      "\{gen_valid_coverage_feature_label(failure.key)} actual=\{failure.actual_count} min=\{failure.min_count}",
    )
    i += 1
  }
  out.to_string()
}

///|
fn gen_valid_coverage_facts_has_excluded(
  facts : GenValidFeatureFacts,
  mode : GenValidMode,
  excluded_features : Array[ValidateValidFeatureKey],
) -> Bool {
  if excluded_features.is_empty() {
    return false
  }
  let candidate_stats = GenValidFeatureStats::empty(mode).record(facts)
  for key in excluded_features {
    if validate_valid_feature_actual_count(candidate_stats, key) > 0 {
      return true
    }
  }
  false
}

///|
fn gen_valid_coverage_contributes(
  current : GenValidFeatureStats,
  next : GenValidFeatureStats,
  required_floors : Array[ValidateValidFeatureFloor],
) -> Bool {
  if required_floors.is_empty() {
    return true
  }
  let mut all_met = true
  for floor in required_floors {
    let before = validate_valid_feature_actual_count(current, floor.key)
    if before < floor.min_count {
      all_met = false
      let after = validate_valid_feature_actual_count(next, floor.key)
      if after > before {
        return true
      }
    }
  }
  all_met
}

///|
fn emit_gen_valid_batch_harness_stream_seed(seed : UInt64) -> UInt64 {
  let mut stream_seed = seed
  for label in gen_valid_random_stream_labels() {
    if gen_valid_random_stream_label_name(label) == "harness-shuffling" {
      stream_seed = gen_valid_derive_stream_seed(seed, label)
    }
  }
  stream_seed
}

///|
fn emit_gen_valid_batch_candidate_seed(seed : UInt64, index : Int) -> UInt64 {
  emit_gen_valid_batch_harness_stream_seed(seed) ^
  (index.to_uint64() * 0x9e3779b97f4a7c15UL)
}

///|
fn gen_valid_coverage_candidate_transform_applicable(
  mod : @lib.Module,
  transform : MetamorphicValidTransform,
) -> Bool {
  match transform {
    AddLeadingMemorySizeDropToDefinedFunctions
    | AddTrailingMemorySizeDropToDefinedFunctions =>
      metamorphic_total_memory_count(mod) > 0
    AddLeadingTableSizeDropToDefinedFunctions
    | AddTrailingTableSizeDropToDefinedFunctions =>
      metamorphic_total_table_count(mod) > 0
    _ => true
  }
}

///|
pub fn emit_gen_valid_batch_artifacts_until_features(
  count : Int,
  seed : UInt64,
  config : GenValidConfig,
  required_floors : Array[ValidateValidFeatureFloor],
  excluded_features : Array[ValidateValidFeatureKey],
  max_attempts : Int,
  metamorphic_transform_ids? : Array[String] = [],
) -> Result[GenValidCoverageSelection, String] {
  if count < 0 {
    return Err("count must be non-negative")
  }
  if max_attempts < 0 {
    return Err("max_attempts must be non-negative")
  }
  let artifacts : Array[(String, Bytes)] = []
  let manifest : Array[GenValidBatchManifestEntry] = []
  let mut feature_stats = GenValidFeatureStats::empty(config.mode)
  let mut selected = 0
  let mut attempts = 0
  let mut skipped_candidates = 0
  while attempts < max_attempts && selected < count {
    attempts += 1
    let generated = match
      gen_valid_module_result_from_seed(
        emit_gen_valid_batch_candidate_seed(seed, attempts),
        config,
      ) {
      Ok(v) => v
      Err(failure) =>
        return Err(
          "gen-valid coverage selection failed at attempt \{attempts} after \{failure.attempts} generator attempts: \{failure.validation_error_message}",
        )
    }
    if gen_valid_coverage_facts_has_excluded(
        generated.facts,
        config.mode,
        excluded_features,
      ) {
      skipped_candidates += 1
      continue
    }
    let next_stats = feature_stats.record(generated.facts)
    if !gen_valid_coverage_contributes(
        feature_stats, next_stats, required_floors,
      ) {
      skipped_candidates += 1
      continue
    }
    match validate_module(generated.wasm_module) {
      Ok(_) => ()
      Err(err) =>
        return Err(
          "gen-valid coverage selection produced invalid module at attempt \{attempts}: \{validation_error_message(err)}",
        )
    }
    let mut artifact_module = generated.wasm_module
    let mut artifact_transform_id : String? = None
    if metamorphic_transform_ids.length() > 0 {
      let requested_id = metamorphic_transform_ids[selected %
        metamorphic_transform_ids.length()]
      let transform = match metamorphic_valid_transform_by_id(requested_id) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      if !gen_valid_coverage_candidate_transform_applicable(
          generated.wasm_module,
          transform,
        ) {
        skipped_candidates += 1
        continue
      }
      let transformed = match
        metamorphic_apply_transform(generated.wasm_module, transform) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      artifact_module = transformed.wasm_module
      artifact_transform_id = Some(transformed.transform_id)
    }
    let bytes = match encode_module(artifact_module) {
      Ok(v) => v
      Err(err) =>
        return Err(
          "gen-valid coverage selection encode failed at attempt \{attempts}: \{err}",
        )
    }
    selected += 1
    let file_name = "gen-valid-\{fuzz_zero_pad_decimal(selected, 6)}.wasm"
    artifacts.push((file_name, bytes))
    manifest.push({
      file_name,
      seed,
      index: selected,
      config_label: generated.config_label,
      attempts: generated.attempts,
      validated: true,
      validation_error_message: None,
      facts: generated.facts,
      transform_id: artifact_transform_id,
    })
    feature_stats = next_stats
  }
  let floor_failures = check_validate_valid_feature_floors(
    feature_stats, required_floors,
  )
  if selected < count || !floor_failures.is_empty() {
    return Err(
      "gen-valid coverage selection unmet feature floors after \{attempts} attempts: selected=\{selected}/\{count} skipped=\{skipped_candidates} \{gen_valid_coverage_floor_failures_message(floor_failures)}",
    )
  }
  Ok({
    artifacts,
    manifest,
    feature_stats,
    floor_failures,
    selected,
    attempts,
    skipped_candidates,
  })
}

///|
pub fn emit_gen_valid_batch_artifacts_with_manifest(
  count : Int,
  seed : UInt64,
) -> Result[GenValidBatchArtifacts, String] {
  if count < 0 {
    return Err("count must be non-negative")
  }
  let config = emit_gen_valid_batch_config()
  let artifacts : Array[(String, Bytes)] = []
  let manifest : Array[GenValidBatchManifestEntry] = []
  let mut i = 0
  while i < count {
    let generated = match
      gen_valid_module_result_from_seed(
        emit_gen_valid_batch_candidate_seed(seed, i + 1),
        config,
      ) {
      Ok(v) => v
      Err(failure) =>
        return Err(
          "gen-valid batch failed at index \{i + 1} after \{failure.attempts} attempts: \{failure.validation_error_message}",
        )
    }
    match validate_module(generated.wasm_module) {
      Ok(_) => ()
      Err(err) =>
        return Err(
          "gen-valid batch produced invalid module at index \{i + 1}: \{validation_error_message(err)}",
        )
    }
    let bytes = match encode_module(generated.wasm_module) {
      Ok(v) => v
      Err(err) =>
        return Err("gen-valid batch encode failed at index \{i + 1}: \{err}")
    }
    let file_name = "gen-valid-\{fuzz_zero_pad_decimal(i + 1, 6)}.wasm"
    artifacts.push((file_name, bytes))
    manifest.push({
      file_name,
      seed,
      index: i + 1,
      config_label: generated.config_label,
      attempts: generated.attempts,
      validated: true,
      validation_error_message: None,
      facts: generated.facts,
      transform_id: None,
    })
    i += 1
  }
  Ok({ artifacts, manifest })
}

///|
pub fn emit_gen_valid_batch_artifacts(
  count : Int,
  seed : UInt64,
) -> Result[Array[(String, Bytes)], String] {
  if count < 0 {
    return Err("count must be non-negative")
  }
  let config = emit_gen_valid_batch_config()
  let artifacts : Array[(String, Bytes)] = []
  let mut i = 0
  while i < count {
    let mod = match
      gen_valid_module_result_from_seed(
        emit_gen_valid_batch_candidate_seed(seed, i + 1),
        config,
      ) {
      Ok(generated) => generated.wasm_module
      Err(failure) => failure.last_candidate
    }
    match validate_module(mod) {
      Ok(_) => ()
      Err(err) =>
        return Err(
          "gen-valid batch produced invalid module at index \{i + 1}: \{validation_error_message(err)}",
        )
    }
    let bytes = match encode_module(mod) {
      Ok(v) => v
      Err(err) =>
        return Err("gen-valid batch encode failed at index \{i + 1}: \{err}")
    }
    artifacts.push(("gen-valid-\{fuzz_zero_pad_decimal(i + 1, 6)}.wasm", bytes))
    i += 1
  }
  Ok(artifacts)
}

///|
fn format_gen_valid_batch_feature_facts_json(
  facts : GenValidFeatureFacts,
) -> String {
  "{\"mode\":\"\{fuzz_json_escape(@debug.to_string(facts.mode))}\",\"imports\":\{facts.has_imports},\"func_exports\":\{facts.has_func_exports},\"table_exports\":\{facts.has_table_exports},\"mem_exports\":\{facts.has_mem_exports},\"global_exports\":\{facts.has_global_exports},\"tag_exports\":\{facts.has_tag_exports},\"start\":\{facts.has_start},\"lacks_start\":\{facts.lacks_start},\"tables\":\{facts.has_tables},\"mems\":\{facts.has_mems},\"globals\":\{facts.has_globals},\"tags\":\{facts.has_tags},\"elems\":\{facts.has_elems},\"datas\":\{facts.has_datas},\"data_count\":\{facts.has_data_count},\"ref_types\":\{facts.uses_ref_types},\"v128\":\{facts.uses_v128},\"calls\":\{facts.has_call},\"call_indirect\":\{facts.has_call_indirect},\"branch_heavy_control\":\{facts.has_branch_heavy_control},\"payload_control_flow\":\{facts.has_payload_control_flow},\"multivalue_control_flow\":\{facts.has_multivalue_control_flow},\"numeric_full_ops\":\{facts.has_numeric_full_ops},\"br_table\":\{facts.has_br_table},\"standalone_unreachable\":\{facts.has_standalone_unreachable},\"local_tee\":\{facts.has_local_tee},\"typed_select\":\{facts.has_typed_select},\"tail_calls\":\{facts.has_tail_calls},\"scalar_memory_widths\":\{facts.has_scalar_memory_widths},\"nonzero_memarg\":\{facts.has_nonzero_memarg},\"memory_limit_variants\":\{facts.has_memory_limit_variants},\"table_limit_variants\":\{facts.has_table_limit_variants},\"const_expr_variants\":\{facts.has_const_expr_variants},\"basic_ref_instructions\":\{facts.has_basic_ref_instructions},\"i31_extern_conversions\":\{facts.has_i31_extern_conversions},\"simd_phase1\":\{facts.has_simd_phase1},\"simd_phase2\":\{facts.has_simd_phase2},\"simd_phase3\":\{facts.has_simd_phase3},\"atomics\":\{facts.has_atomics},\"gc_constructors\":\{facts.has_gc_constructors},\"gc_accessors\":\{facts.has_gc_accessors},\"string_ops\":\{facts.has_string_ops},\"exception_try_table_matrix\":\{facts.has_exception_try_table_matrix},\"subtyping_topology\":\{facts.has_subtyping_topology},\"rich_gc_field_plans\":\{facts.has_rich_gc_field_plans},\"import_export_topology\":\{facts.has_import_export_topology},\"element_segment_range\":\{facts.has_element_segment_range},\"data_segment_range\":\{facts.has_data_segment_range},\"name_custom_sections\":\{facts.has_name_custom_sections},\"gc_exception_combo\":\{facts.has_gc_exception_combo},\"gc_tail_call_combo\":\{facts.has_gc_tail_call_combo},\"shared_memory_atomics\":\{facts.has_shared_memory_atomics},\"imports_start_exports\":\{facts.has_imports_start_exports},\"ssa_straight_line_local_chain\":\{facts.has_ssa_straight_line_local_chain},\"ssa_already_ssa_local\":\{facts.has_ssa_already_ssa_local},\"ssa_multi_def_same_local\":\{facts.has_ssa_multi_def_same_local},\"ssa_param_entry_read\":\{facts.has_ssa_param_entry_read},\"ssa_local_tee_def_use\":\{facts.has_ssa_local_tee_def_use},\"ssa_tee_freshen_candidate\":\{facts.has_ssa_tee_freshen_candidate},\"ssa_tee_merge_feeding_candidate\":\{facts.has_ssa_tee_merge_feeding_candidate},\"ssa_tee_child_expression\":\{facts.has_ssa_tee_child_expression},\"ssa_param_write\":\{facts.has_ssa_param_write},\"ssa_dead_local_set\":\{facts.has_ssa_dead_local_set},\"ssa_dead_local_tee\":\{facts.has_ssa_dead_local_tee},\"ssa_if_join_phi_candidate\":\{facts.has_ssa_if_join_phi_candidate},\"ssa_loop_backedge_phi_candidate\":\{facts.has_ssa_loop_backedge_phi_candidate},\"ssa_br_table_phi_candidate\":\{facts.has_ssa_br_table_phi_candidate},\"ssa_parallel_copy_candidate\":\{facts.has_ssa_parallel_copy_candidate},\"ssa_parallel_copy_cycle_candidate\":\{facts.has_ssa_parallel_copy_cycle_candidate},\"ssa_default_local_merge\":\{facts.has_ssa_default_local_merge},\"ssa_one_arm_default_merge\":\{facts.has_ssa_one_arm_default_merge},\"ssa_one_arm_param_merge\":\{facts.has_ssa_one_arm_param_merge},\"ssa_both_arm_local_merge\":\{facts.has_ssa_both_arm_local_merge},\"ssa_loop_carried_local_merge\":\{facts.has_ssa_loop_carried_local_merge},\"ssa_mixed_fresh_canonical_writes\":\{facts.has_ssa_mixed_fresh_canonical_writes},\"ssa_unreachable_local_carrier\":\{facts.has_ssa_unreachable_local_carrier},\"ssa_dropped_increment_guard_shape\":\{facts.has_ssa_dropped_increment_guard_shape},\"ssa_dropped_increment_reversed_boundary\":\{facts.has_ssa_dropped_increment_reversed_boundary},\"ssa_exceptional_fail_closed_shape\":\{facts.has_ssa_exceptional_fail_closed_shape},\"ssa_typed_loop_param_fail_closed_shape\":\{facts.has_ssa_typed_loop_param_fail_closed_shape},\"ssa_nested_cfg_fail_closed_shape\":\{facts.has_ssa_nested_cfg_fail_closed_shape},\"ssa_nested_result_if_supported_shape\":\{facts.has_ssa_nested_result_if_supported_shape},\"ssa_nested_result_if_condition_write\":\{facts.has_ssa_nested_result_if_condition_write},\"ssa_nested_result_if_condition_value_block\":\{facts.has_ssa_nested_result_if_condition_value_block},\"ssa_nested_result_if_arm_value_block\":\{facts.has_ssa_nested_result_if_arm_value_block},\"ssa_nested_result_if_mixed_arm_value_block\":\{facts.has_ssa_nested_result_if_mixed_arm_value_block},\"ssa_nested_result_if_scalar_result\":\{facts.has_ssa_nested_result_if_scalar_result},\"ssa_structured_early_return_local\":\{facts.has_ssa_structured_early_return_local},\"ssa_block_branch_merge_copy\":\{facts.has_ssa_block_branch_merge_copy},\"ssa_block_br_if_merge_copy\":\{facts.has_ssa_block_br_if_merge_copy},\"ssa_structured_param_merge\":\{facts.has_ssa_structured_param_merge},\"ssa_branch_local_not_read_later\":\{facts.has_ssa_branch_local_not_read_later},\"ssa_default_local_read_after_branchy_control\":\{facts.has_ssa_default_local_read_after_branchy_control},\"ssa_dropped_unreachable_debris_before_hard_unreachable\":\{facts.has_ssa_dropped_unreachable_debris_before_hard_unreachable},\"ssa_canonical_body_local_next_read\":\{facts.has_ssa_canonical_body_local_next_read},\"ssa_immediate_block_exit_canonical_set_br\":\{facts.has_ssa_immediate_block_exit_canonical_set_br},\"ssa_enclosing_label_copy_before_exit\":\{facts.has_ssa_enclosing_label_copy_before_exit},\"ssa_void_br_table_canonical_copies\":\{facts.has_ssa_void_br_table_canonical_copies}}"
}

///|
fn format_gen_valid_batch_feature_keys_json(
  keys : Array[ValidateValidFeatureKey],
) -> String {
  let out = StringBuilder::new()
  out.write_char('[')
  let mut i = 0
  while i < keys.length() {
    if i > 0 {
      out.write_char(',')
    }
    out.write_string(
      "\"\{fuzz_json_escape(gen_valid_coverage_feature_label(keys[i]))}\"",
    )
    i += 1
  }
  out.write_char(']')
  out.to_string()
}

///|
pub struct GenValidStreamDerivation {
  label : String
  derived_seed : UInt64
} derive(Eq, Debug)

///|
fn fuzz_find_text_from(text : String, needle : String, start : Int) -> Int {
  if needle.length() == 0 {
    return start
  }
  let mut i = start
  while i + needle.length() <= text.length() {
    let mut matches = true
    let mut j = 0
    while j < needle.length() {
      if text[i + j] != needle[j] {
        matches = false
        break
      }
      j += 1
    }
    if matches {
      return i
    }
    i += 1
  }
  -1
}

///|
fn fuzz_find_text_last_from(text : String, needle : String, start : Int) -> Int {
  if needle.length() == 0 {
    return text.length()
  }
  let mut last = -1
  let mut pos = start
  while pos >= 0 {
    let found = fuzz_find_text_from(text, needle, pos)
    if found < 0 {
      break
    }
    last = found
    pos = found + 1
  }
  last
}

///|
fn fuzz_parse_uint64_decimal_at(text : String, start : Int) -> (UInt64, Int)? {
  let mut i = start
  let mut value = 0UL
  let mut digits = 0
  while i < text.length() {
    let c = text[i]
    if c < '0' || c > '9' {
      break
    }
    value = value * 10UL + (c.to_int() - '0'.to_int()).to_uint64()
    digits += 1
    i += 1
  }
  if digits == 0 {
    None
  } else {
    Some((value, i))
  }
}

///|
fn fuzz_parse_simple_json_string_at(
  text : String,
  start : Int,
) -> (String, Int)? {
  if start >= text.length() || text[start] != '"' {
    return None
  }
  let mut i = start + 1
  while i < text.length() {
    if text[i] == '\\' {
      return None
    }
    if text[i] == '"' {
      return Some((text.sub(start=start + 1, end=i).to_owned(), i + 1))
    }
    i += 1
  }
  None
}

///|
pub fn parse_gen_valid_batch_manifest_stream_derivations(
  manifest_json : String,
) -> Result[Array[GenValidStreamDerivation], String] {
  let array_key = "\"stream_derivations\":["
  let array_start = fuzz_find_text_from(manifest_json, array_key, 0)
  if array_start < 0 {
    return Err("missing stream_derivations array")
  }
  let body_start = array_start + array_key.length()
  let array_end = fuzz_find_text_from(manifest_json, "]", body_start)
  if array_end < 0 {
    return Err("unterminated stream_derivations array")
  }
  let label_key = "\"label\":"
  let seed_key = "\"derived_seed\":"
  let out : Array[GenValidStreamDerivation] = []
  let mut pos = body_start
  while pos < array_end {
    let label_pos = fuzz_find_text_from(manifest_json, label_key, pos)
    if label_pos < 0 || label_pos >= array_end {
      break
    }
    let parsed_label = match
      fuzz_parse_simple_json_string_at(
        manifest_json,
        label_pos + label_key.length(),
      ) {
      Some(v) => v
      None => return Err("malformed stream derivation label")
    }
    let seed_pos = fuzz_find_text_from(manifest_json, seed_key, parsed_label.1)
    if seed_pos < 0 || seed_pos >= array_end {
      return Err("missing stream derivation derived_seed for \{parsed_label.0}")
    }
    let parsed_seed = match
      fuzz_parse_uint64_decimal_at(manifest_json, seed_pos + seed_key.length()) {
      Some(v) => v
      None =>
        return Err(
          "malformed stream derivation derived_seed for \{parsed_label.0}",
        )
    }
    out.push({ label: parsed_label.0, derived_seed: parsed_seed.0 })
    pos = parsed_seed.1
  }
  if out.is_empty() {
    Err("empty stream_derivations array")
  } else {
    Ok(out)
  }
}

///|
fn format_gen_valid_stream_derivations_json(seed : UInt64) -> String {
  let labels = gen_valid_random_stream_labels()
  let out = StringBuilder::new()
  out.write_char('[')
  let mut i = 0
  while i < labels.length() {
    if i > 0 {
      out.write_char(',')
    }
    let label = labels[i]
    out.write_string(
      "{\"label\":\"\{fuzz_json_escape(gen_valid_random_stream_label_name(label))}\",\"derived_seed\":\{gen_valid_derive_stream_seed(seed, label)}}",
    )
    i += 1
  }
  out.write_char(']')
  out.to_string()
}

///|
fn format_fuzz_string_array_json(items : Array[String]) -> String {
  let out = StringBuilder::new()
  out.write_char('[')
  let mut i = 0
  while i < items.length() {
    if i > 0 {
      out.write_char(',')
    }
    out.write_char('"')
    out.write_string(fuzz_json_escape(items[i]))
    out.write_char('"')
    i += 1
  }
  out.write_char(']')
  out.to_string()
}

///|
fn fuzz_corpus_promotion_state_is_known(state : String) -> Bool {
  state == "promoted-valid" ||
  state == "promoted-invalid" ||
  state == "pass-mismatch" ||
  state == "tool-failure" ||
  state == "accepted-divergence" ||
  state == "quarantine"
}

///|
pub fn fuzz_corpus_promotion_metadata_schema_json() -> String {
  "{\"schema\":\"starshine.fuzz-corpus-entry.v1\",\"states\":[\"promoted-valid\",\"promoted-invalid\",\"pass-mismatch\",\"tool-failure\",\"accepted-divergence\",\"quarantine\"],\"required\":[\"id\",\"state\",\"source\",\"input\",\"created_at\",\"generator\",\"features\",\"expectation\",\"classification\",\"replay\",\"artifacts\",\"owner_or_task\",\"notes\",\"raw_artifact_hash\",\"reduced_artifact_hash\",\"normalized_shape_hash\",\"predicate_hash\",\"feature_fact_hash\",\"interestingness_label\"]}"
}

///|
pub fn format_fuzz_corpus_promotion_metadata_json(
  entry : FuzzCorpusPromotionMetadata,
) -> String {
  let out = StringBuilder::new()
  out.write_string("{\"schema\":\"starshine.fuzz-corpus-entry.v1\",\"id\":\"")
  out.write_string(fuzz_json_escape(entry.id))
  out.write_string("\",\"state\":\"")
  out.write_string(fuzz_json_escape(entry.state))
  out.write_string("\",\"source\":\"")
  out.write_string(fuzz_json_escape(entry.source))
  out.write_string("\",\"input\":\"")
  out.write_string(fuzz_json_escape(entry.input))
  out.write_string("\",\"created_at\":\"")
  out.write_string(fuzz_json_escape(entry.created_at))
  out.write_string("\",\"generator\":\"")
  out.write_string(fuzz_json_escape(entry.generator))
  out.write_string("\",\"features\":")
  out.write_string(format_fuzz_string_array_json(entry.features))
  out.write_string(",\"expectation\":\"")
  out.write_string(fuzz_json_escape(entry.expectation))
  out.write_string("\",\"classification\":\"")
  out.write_string(fuzz_json_escape(entry.classification))
  out.write_string("\",\"replay\":\"")
  out.write_string(fuzz_json_escape(entry.replay))
  out.write_string("\",\"artifacts\":")
  out.write_string(format_fuzz_string_array_json(entry.artifacts))
  out.write_string(",\"owner_or_task\":\"")
  out.write_string(fuzz_json_escape(entry.owner_or_task))
  out.write_string("\",\"notes\":\"")
  out.write_string(fuzz_json_escape(entry.notes))
  out.write_string("\",\"raw_artifact_hash\":\"")
  out.write_string(fuzz_json_escape(entry.raw_artifact_hash))
  out.write_string("\",\"reduced_artifact_hash\":\"")
  out.write_string(fuzz_json_escape(entry.reduced_artifact_hash))
  out.write_string("\",\"normalized_shape_hash\":\"")
  out.write_string(fuzz_json_escape(entry.normalized_shape_hash))
  out.write_string("\",\"predicate_hash\":\"")
  out.write_string(fuzz_json_escape(entry.predicate_hash))
  out.write_string("\",\"feature_fact_hash\":\"")
  out.write_string(fuzz_json_escape(entry.feature_fact_hash))
  out.write_string("\",\"interestingness_label\":\"")
  out.write_string(fuzz_json_escape(entry.interestingness_label))
  out.write_string("\"}")
  out.to_string()
}

///|
fn fuzz_parse_json_string_with_escapes_at(
  text : String,
  start : Int,
) -> (String, Int)? {
  if start >= text.length() || text[start] != '"' {
    return None
  }
  let out = StringBuilder::new()
  let mut i = start + 1
  while i < text.length() {
    let c = text[i]
    if c == '"' {
      return Some((out.to_string(), i + 1))
    }
    if c == '\\' {
      i += 1
      if i >= text.length() {
        return None
      }
      match text[i] {
        '"' => out.write_char('"')
        '\\' => out.write_char('\\')
        'n' => out.write_char('\n')
        'r' => out.write_char('\r')
        't' => out.write_char('\t')
        _ => return None
      }
    } else {
      out.write_char(c.unsafe_to_char())
    }
    i += 1
  }
  None
}

///|
fn fuzz_parse_corpus_metadata_string_field(
  json : String,
  field : String,
) -> Result[String, String] {
  let key = "\"\{field}\":"
  let pos = fuzz_find_text_from(json, key, 0)
  if pos < 0 {
    return Err("missing corpus metadata field \{field}")
  }
  match fuzz_parse_json_string_with_escapes_at(json, pos + key.length()) {
    Some(v) => Ok(v.0)
    None => Err("malformed corpus metadata field \{field}")
  }
}

///|
fn fuzz_parse_corpus_metadata_string_array_field(
  json : String,
  field : String,
) -> Result[Array[String], String] {
  let key = "\"\{field}\":["
  let pos = fuzz_find_text_from(json, key, 0)
  if pos < 0 {
    return Err("missing corpus metadata field \{field}")
  }
  let end = fuzz_find_text_from(json, "]", pos + key.length())
  if end < 0 {
    return Err("unterminated corpus metadata array \{field}")
  }
  let out : Array[String] = []
  let mut cursor = pos + key.length()
  while cursor < end {
    let parsed = match fuzz_parse_json_string_with_escapes_at(json, cursor) {
      Some(v) => v
      None => return Err("malformed corpus metadata array \{field}")
    }
    out.push(parsed.0)
    cursor = parsed.1
    if cursor < end {
      if json[cursor] != ',' {
        return Err("malformed corpus metadata array \{field}")
      }
      cursor += 1
    }
  }
  Ok(out)
}

///|
pub fn parse_fuzz_corpus_promotion_metadata_json(
  json : String,
) -> Result[FuzzCorpusPromotionMetadata, String] {
  let schema = match fuzz_parse_corpus_metadata_string_field(json, "schema") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if schema != "starshine.fuzz-corpus-entry.v1" {
    return Err("unsupported corpus metadata schema \{schema}")
  }
  let id = match fuzz_parse_corpus_metadata_string_field(json, "id") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let state = match fuzz_parse_corpus_metadata_string_field(json, "state") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if !fuzz_corpus_promotion_state_is_known(state) {
    return Err("unknown corpus state \{state}")
  }
  let source = match fuzz_parse_corpus_metadata_string_field(json, "source") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let input = match fuzz_parse_corpus_metadata_string_field(json, "input") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let created_at = match
    fuzz_parse_corpus_metadata_string_field(json, "created_at") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let generator = match
    fuzz_parse_corpus_metadata_string_field(json, "generator") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let features = match
    fuzz_parse_corpus_metadata_string_array_field(json, "features") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let expectation = match
    fuzz_parse_corpus_metadata_string_field(json, "expectation") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let classification = match
    fuzz_parse_corpus_metadata_string_field(json, "classification") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let replay = match fuzz_parse_corpus_metadata_string_field(json, "replay") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let artifacts = match
    fuzz_parse_corpus_metadata_string_array_field(json, "artifacts") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let owner_or_task = match
    fuzz_parse_corpus_metadata_string_field(json, "owner_or_task") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let notes = match fuzz_parse_corpus_metadata_string_field(json, "notes") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let raw_artifact_hash = match
    fuzz_parse_corpus_metadata_string_field(json, "raw_artifact_hash") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let reduced_artifact_hash = match
    fuzz_parse_corpus_metadata_string_field(json, "reduced_artifact_hash") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let normalized_shape_hash = match
    fuzz_parse_corpus_metadata_string_field(json, "normalized_shape_hash") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let predicate_hash = match
    fuzz_parse_corpus_metadata_string_field(json, "predicate_hash") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let feature_fact_hash = match
    fuzz_parse_corpus_metadata_string_field(json, "feature_fact_hash") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let interestingness_label = match
    fuzz_parse_corpus_metadata_string_field(json, "interestingness_label") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(
    FuzzCorpusPromotionMetadata::new(
      id,
      state,
      source,
      input,
      created_at,
      generator,
      features,
      expectation,
      classification,
      replay,
      artifacts,
      owner_or_task,
      notes,
      raw_artifact_hash~,
      reduced_artifact_hash~,
      normalized_shape_hash~,
      predicate_hash~,
      feature_fact_hash~,
      interestingness_label~,
    ),
  )
}

///|
fn fuzz_parse_space_delimited_kv_token(text : String, key : String) -> String? {
  let needle = "\{key}="
  let pos = fuzz_find_text_from(text, needle, 0)
  if pos < 0 {
    return None
  }
  let start = pos + needle.length()
  let mut end = start
  while end < text.length() &&
        text[end] != ' ' &&
        text[end] != '\t' &&
        text[end] != '\n' &&
        text[end] != '\r' {
    end += 1
  }
  Some(text.sub(start~, end~).to_owned())
}

///|
fn fuzz_parse_required_kv_token(
  text : String,
  key : String,
  case_id : String,
) -> Result[String, String] {
  match fuzz_parse_space_delimited_kv_token(text, key) {
    Some(v) => Ok(v)
    None => Err("missing replay metadata token \{key}= for \{case_id}")
  }
}

///|
fn fuzz_corpus_replay_strategy_or_artifact(
  entry : FuzzCorpusPromotionMetadata,
) -> String {
  match fuzz_parse_space_delimited_kv_token(entry.generator, "strategy") {
    Some(v) => v
    None =>
      if entry.artifacts.length() > 0 {
        entry.artifacts[0]
      } else {
        entry.input
      }
  }
}

///|
pub fn build_fuzz_corpus_replay_command_metadata(
  entry : FuzzCorpusPromotionMetadata,
) -> Result[FuzzCorpusReplayCommandMetadata, String] {
  let suite = match
    fuzz_parse_required_kv_token(entry.generator, "suite", entry.id) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let profile = match
    fuzz_parse_required_kv_token(entry.generator, "profile", entry.id) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let seed_text = match
    fuzz_parse_required_kv_token(entry.generator, "seed", entry.id) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let seed = match fuzz_parse_uint64_decimal_at(seed_text, 0) {
    Some(v) =>
      if v.1 == seed_text.length() {
        v.0
      } else {
        return Err("malformed replay seed for \{entry.id}")
      }
    None => return Err("malformed replay seed for \{entry.id}")
  }
  let seed_index = match
    fuzz_parse_space_delimited_kv_token(entry.generator, "seed_index") {
    Some(text) =>
      match fuzz_parse_uint64_decimal_at(text, 0) {
        Some(v) =>
          if v.1 == text.length() {
            v.0.to_int()
          } else {
            return Err("malformed replay seed_index for \{entry.id}")
          }
        None => return Err("malformed replay seed_index for \{entry.id}")
      }
    None => 0
  }
  Ok(
    FuzzCorpusReplayCommandMetadata::new(
      entry.id,
      suite,
      profile,
      seed,
      seed_index,
      fuzz_corpus_replay_strategy_or_artifact(entry),
      entry.expectation,
      entry.classification,
      entry.replay,
    ),
  )
}

///|
pub fn format_fuzz_corpus_replay_command_metadata_json(
  replay : FuzzCorpusReplayCommandMetadata,
) -> String {
  let out = StringBuilder::new()
  out.write_string(
    "{\"schema\":\"starshine.fuzz-replay-command.v1\",\"case_id\":\"",
  )
  out.write_string(fuzz_json_escape(replay.case_id))
  out.write_string("\",\"suite\":\"")
  out.write_string(fuzz_json_escape(replay.suite))
  out.write_string("\",\"profile\":\"")
  out.write_string(fuzz_json_escape(replay.profile))
  out.write_string(
    "\",\"seed\":\{replay.seed},\"seed_index\":\{replay.seed_index},\"strategy_or_artifact\":\"",
  )
  out.write_string(fuzz_json_escape(replay.strategy_or_artifact))
  out.write_string("\",\"expected_outcome\":\"")
  out.write_string(fuzz_json_escape(replay.expected_outcome))
  out.write_string("\",\"classification\":\"")
  out.write_string(fuzz_json_escape(replay.classification))
  out.write_string("\",\"command\":\"")
  out.write_string(fuzz_json_escape(replay.command))
  out.write_string("\"}")
  out.to_string()
}

///|
fn fuzz_parse_corpus_metadata_uint_field(
  json : String,
  field : String,
) -> Result[UInt64, String] {
  let key = "\"\{field}\":"
  let pos = fuzz_find_text_from(json, key, 0)
  if pos < 0 {
    return Err("missing corpus metadata field \{field}")
  }
  match fuzz_parse_uint64_decimal_at(json, pos + key.length()) {
    Some(v) =>
      if v.1 == json.length() || json[v.1] == ',' || json[v.1] == '}' {
        Ok(v.0)
      } else {
        Err("malformed corpus metadata field \{field}")
      }
    None => Err("malformed corpus metadata field \{field}")
  }
}

///|
fn fuzz_parse_corpus_metadata_uint_array_field(
  json : String,
  field : String,
) -> Result[Array[UInt64], String] {
  let key = "\"\{field}\":["
  let pos = fuzz_find_text_from(json, key, 0)
  if pos < 0 {
    return Err("missing corpus metadata field \{field}")
  }
  let end = fuzz_find_text_from(json, "]", pos + key.length())
  if end < 0 {
    return Err("unterminated corpus metadata array \{field}")
  }
  let out : Array[UInt64] = []
  let mut cursor = pos + key.length()
  while cursor < end {
    match fuzz_parse_uint64_decimal_at(json, cursor) {
      Some(v) => {
        out.push(v.0)
        cursor = v.1
      }
      None => return Err("malformed corpus metadata array \{field}")
    }
    if cursor < end {
      if json[cursor] != ',' {
        return Err("malformed corpus metadata array \{field}")
      }
      cursor += 1
    }
  }
  Ok(out)
}

///|
pub fn parse_fuzz_corpus_replay_command_metadata_json(
  json : String,
) -> Result[FuzzCorpusReplayCommandMetadata, String] {
  let schema = match fuzz_parse_corpus_metadata_string_field(json, "schema") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if schema != "starshine.fuzz-replay-command.v1" {
    return Err("unsupported replay command schema \{schema}")
  }
  let case_id = match fuzz_parse_corpus_metadata_string_field(json, "case_id") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let suite = match fuzz_parse_corpus_metadata_string_field(json, "suite") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let profile = match fuzz_parse_corpus_metadata_string_field(json, "profile") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let seed = match fuzz_parse_corpus_metadata_uint_field(json, "seed") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let seed_index = match
    fuzz_parse_corpus_metadata_uint_field(json, "seed_index") {
    Ok(v) => v.to_int()
    Err(e) => return Err(e)
  }
  let strategy_or_artifact = match
    fuzz_parse_corpus_metadata_string_field(json, "strategy_or_artifact") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let expected_outcome = match
    fuzz_parse_corpus_metadata_string_field(json, "expected_outcome") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let classification = match
    fuzz_parse_corpus_metadata_string_field(json, "classification") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let command = match fuzz_parse_corpus_metadata_string_field(json, "command") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(
    FuzzCorpusReplayCommandMetadata::new(
      case_id, suite, profile, seed, seed_index, strategy_or_artifact, expected_outcome,
      classification, command,
    ),
  )
}

///|
fn fuzz_corpus_case_index_seed(entry : FuzzCorpusPromotionMetadata) -> UInt64 {
  match fuzz_parse_space_delimited_kv_token(entry.generator, "seed") {
    Some(text) =>
      match fuzz_parse_uint64_decimal_at(text, 0) {
        Some(v) => if v.1 == text.length() { v.0 } else { 0UL }
        None => 0UL
      }
    None => 0UL
  }
}

///|
fn fuzz_corpus_case_index_profile(
  entry : FuzzCorpusPromotionMetadata,
) -> String {
  match fuzz_parse_space_delimited_kv_token(entry.generator, "profile") {
    Some(v) => v
    None => "unknown"
  }
}

///|
fn fuzz_corpus_case_index_artifact(
  entry : FuzzCorpusPromotionMetadata,
  hash_kind : String,
) -> String {
  if hash_kind == "reduced" && entry.artifacts.length() > 1 {
    return entry.artifacts[1]
  }
  if entry.artifacts.length() > 0 {
    entry.artifacts[0]
  } else {
    entry.input
  }
}

///|
fn fuzz_corpus_case_index_entry_pos(
  entries : Array[FuzzCorpusCaseIndexEntry],
  hash_kind : String,
  hash : String,
) -> Int {
  let mut i = 0
  while i < entries.length() {
    if entries[i].hash_kind == hash_kind && entries[i].hash == hash {
      return i
    }
    i += 1
  }
  -1
}

///|
fn fuzz_corpus_case_index_add(
  entries : Array[FuzzCorpusCaseIndexEntry],
  entry : FuzzCorpusPromotionMetadata,
  hash_kind : String,
  hash : String,
) -> Unit {
  if hash == "" {
    return
  }
  let seed = fuzz_corpus_case_index_seed(entry)
  let profile = fuzz_corpus_case_index_profile(entry)
  let artifact = fuzz_corpus_case_index_artifact(entry, hash_kind)
  let pos = fuzz_corpus_case_index_entry_pos(entries, hash_kind, hash)
  if pos >= 0 {
    entries[pos].case_ids.push(entry.id)
    entries[pos].seeds.push(seed)
    entries[pos].profiles.push(profile)
    entries[pos].artifact_paths.push(artifact)
  } else {
    entries.push(
      FuzzCorpusCaseIndexEntry::new(
        hash_kind,
        hash,
        [entry.id],
        [seed],
        [profile],
        [artifact],
      ),
    )
  }
}

///|
pub fn build_fuzz_corpus_case_index(
  corpus_entries : Array[FuzzCorpusPromotionMetadata],
) -> FuzzCorpusCaseIndex {
  let entries : Array[FuzzCorpusCaseIndexEntry] = []
  for entry in corpus_entries {
    fuzz_corpus_case_index_add(entries, entry, "raw", entry.raw_artifact_hash)
    fuzz_corpus_case_index_add(
      entries,
      entry,
      "reduced",
      entry.reduced_artifact_hash,
    )
    fuzz_corpus_case_index_add(
      entries,
      entry,
      "normalized-shape",
      entry.normalized_shape_hash,
    )
  }
  FuzzCorpusCaseIndex::new(entries)
}

///|
fn format_fuzz_uint64_array_json(items : Array[UInt64]) -> String {
  let out = StringBuilder::new()
  out.write_char('[')
  let mut i = 0
  while i < items.length() {
    if i > 0 {
      out.write_char(',')
    }
    out.write_string("\{items[i]}")
    i += 1
  }
  out.write_char(']')
  out.to_string()
}

///|
pub fn format_fuzz_corpus_case_index_json(
  index : FuzzCorpusCaseIndex,
) -> String {
  let out = StringBuilder::new()
  out.write_string(
    "{\"schema\":\"starshine.fuzz-corpus-case-index.v1\",\"entries\":[",
  )
  let mut i = 0
  while i < index.entries.length() {
    if i > 0 {
      out.write_char(',')
    }
    let entry = index.entries[i]
    out.write_string("{\"hash_kind\":\"")
    out.write_string(fuzz_json_escape(entry.hash_kind))
    out.write_string("\",\"hash\":\"")
    out.write_string(fuzz_json_escape(entry.hash))
    out.write_string("\",\"case_ids\":")
    out.write_string(format_fuzz_string_array_json(entry.case_ids))
    out.write_string(",\"seeds\":")
    out.write_string(format_fuzz_uint64_array_json(entry.seeds))
    out.write_string(",\"profiles\":")
    out.write_string(format_fuzz_string_array_json(entry.profiles))
    out.write_string(",\"artifact_paths\":")
    out.write_string(format_fuzz_string_array_json(entry.artifact_paths))
    out.write_char('}')
    i += 1
  }
  out.write_string("]}")
  out.to_string()
}

///|
fn parse_fuzz_corpus_case_index_entry_json(
  json : String,
) -> Result[FuzzCorpusCaseIndexEntry, String] {
  let hash_kind = match
    fuzz_parse_corpus_metadata_string_field(json, "hash_kind") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let hash = match fuzz_parse_corpus_metadata_string_field(json, "hash") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let case_ids = match
    fuzz_parse_corpus_metadata_string_array_field(json, "case_ids") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let seeds = match fuzz_parse_corpus_metadata_uint_array_field(json, "seeds") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let profiles = match
    fuzz_parse_corpus_metadata_string_array_field(json, "profiles") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let artifact_paths = match
    fuzz_parse_corpus_metadata_string_array_field(json, "artifact_paths") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(
    FuzzCorpusCaseIndexEntry::new(
      hash_kind, hash, case_ids, seeds, profiles, artifact_paths,
    ),
  )
}

///|
pub fn classify_fuzz_corpus_dedup_dry_run(
  index : FuzzCorpusCaseIndex,
) -> FuzzCorpusDedupDryRunPlan {
  let decisions : Array[FuzzCorpusDedupDryRunDecision] = []
  let mut duplicate_count = 0
  let mut compress_count = 0
  let mut keep_count = 0
  for entry in index.entries {
    let duplicate_cases = entry.case_ids.length() > 1
    if entry.hash_kind == "reduced" && duplicate_cases {
      compress_count += 1
      decisions.push(
        FuzzCorpusDedupDryRunDecision::new(
          "compress",
          entry.hash_kind,
          entry.hash,
          entry.case_ids,
          entry.artifact_paths,
          "duplicate reduced artifacts can be compressed later; dry-run only, no files are deleted",
        ),
      )
    } else if entry.hash_kind == "raw" {
      keep_count += 1
      let reason = if duplicate_cases {
        "raw artifacts are originals; report duplicate raw hash only and never delete sole artifact for an unreduced failure"
      } else {
        "raw artifact is the sole artifact for this unreduced failure; never delete it"
      }
      decisions.push(
        FuzzCorpusDedupDryRunDecision::new(
          "keep",
          entry.hash_kind,
          entry.hash,
          entry.case_ids,
          entry.artifact_paths,
          reason,
        ),
      )
    } else if duplicate_cases {
      duplicate_count += 1
      decisions.push(
        FuzzCorpusDedupDryRunDecision::new(
          "duplicate",
          entry.hash_kind,
          entry.hash,
          entry.case_ids,
          entry.artifact_paths,
          "duplicate non-raw hash group reported by dry-run only",
        ),
      )
    } else {
      keep_count += 1
      decisions.push(
        FuzzCorpusDedupDryRunDecision::new(
          "keep",
          entry.hash_kind,
          entry.hash,
          entry.case_ids,
          entry.artifact_paths,
          "unique hash group has no dedup action",
        ),
      )
    }
  }
  FuzzCorpusDedupDryRunPlan::new(
    duplicate_count, compress_count, keep_count, decisions,
  )
}

///|
pub fn format_fuzz_corpus_dedup_dry_run_json(
  plan : FuzzCorpusDedupDryRunPlan,
) -> String {
  let out = StringBuilder::new()
  out.write_string(
    "{\"schema\":\"starshine.fuzz-corpus-dedup-dry-run.v1\",\"duplicate_count\":",
  )
  out.write_string("\{plan.duplicate_count}")
  out.write_string(",\"compress_count\":")
  out.write_string("\{plan.compress_count}")
  out.write_string(",\"keep_count\":")
  out.write_string("\{plan.keep_count}")
  out.write_string(",\"decisions\":[")
  let mut i = 0
  while i < plan.decisions.length() {
    if i > 0 {
      out.write_char(',')
    }
    let decision = plan.decisions[i]
    out.write_string("{\"action\":\"")
    out.write_string(fuzz_json_escape(decision.action))
    out.write_string("\",\"hash_kind\":\"")
    out.write_string(fuzz_json_escape(decision.hash_kind))
    out.write_string("\",\"hash\":\"")
    out.write_string(fuzz_json_escape(decision.hash))
    out.write_string("\",\"case_ids\":")
    out.write_string(format_fuzz_string_array_json(decision.case_ids))
    out.write_string(",\"artifact_paths\":")
    out.write_string(format_fuzz_string_array_json(decision.artifact_paths))
    out.write_string(",\"reason\":\"")
    out.write_string(fuzz_json_escape(decision.reason))
    out.write_string("\"}")
    i += 1
  }
  out.write_string("]}")
  out.to_string()
}

///|
pub fn parse_fuzz_corpus_case_index_json(
  index_json : String,
) -> Result[FuzzCorpusCaseIndex, String] {
  let schema = match
    fuzz_parse_corpus_metadata_string_field(index_json, "schema") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if schema != "starshine.fuzz-corpus-case-index.v1" {
    return Err("unsupported corpus case-index schema \{schema}")
  }
  let entries_key = "\"entries\":["
  let entries_start = fuzz_find_text_from(index_json, entries_key, 0)
  if entries_start < 0 {
    return Err("missing corpus case-index entries array")
  }
  let body_start = entries_start + entries_key.length()
  let entries_end = fuzz_find_text_last_from(index_json, "]", body_start)
  if entries_end < 0 {
    return Err("unterminated corpus case-index entries array")
  }
  let entries : Array[FuzzCorpusCaseIndexEntry] = []
  let mut pos = fuzz_skip_manifest_ws_and_commas(
    index_json, body_start, entries_end,
  )
  while pos < entries_end {
    if index_json[pos] != '{' {
      return Err("malformed corpus case-index entry")
    }
    match fuzz_find_json_object_end(index_json, pos, entries_end) {
      Some(end_pos) => {
        let entry_json = index_json.sub(start=pos, end=end_pos).to_owned()
        match parse_fuzz_corpus_case_index_entry_json(entry_json) {
          Ok(entry) => entries.push(entry)
          Err(e) => return Err(e)
        }
        pos = end_pos
      }
      None => return Err("malformed corpus case-index entry")
    }
    pos = fuzz_skip_manifest_ws_and_commas(index_json, pos, entries_end)
  }
  Ok(FuzzCorpusCaseIndex::new(entries))
}

///|
fn fuzz_find_json_object_end(text : String, start : Int, limit : Int) -> Int? {
  if start >= limit || text[start] != '{' {
    return None
  }
  let mut depth = 0
  let mut in_string = false
  let mut escaped = false
  let mut i = start
  while i < limit {
    let c = text[i]
    if in_string {
      if escaped {
        escaped = false
      } else if c == '\\' {
        escaped = true
      } else if c == '"' {
        in_string = false
      }
    } else if c == '"' {
      in_string = true
    } else if c == '{' {
      depth += 1
    } else if c == '}' {
      depth -= 1
      if depth == 0 {
        return Some(i + 1)
      }
    }
    i += 1
  }
  None
}

///|
fn fuzz_skip_manifest_ws_and_commas(
  text : String,
  pos : Int,
  limit : Int,
) -> Int {
  let mut i = pos
  while i < limit &&
        (
          text[i] == ' ' ||
          text[i] == '\n' ||
          text[i] == '\r' ||
          text[i] == '\t' ||
          text[i] == ','
        ) {
    i += 1
  }
  i
}

///|
pub fn plan_fuzz_corpus_replay_manifest(
  manifest_json : String,
) -> Result[FuzzCorpusReplayAllPlan, String] {
  let schema = match
    fuzz_parse_corpus_metadata_string_field(manifest_json, "schema") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if schema != "starshine.fuzz-corpus-replay-all-manifest.v1" {
    return Err("unsupported replay-all manifest schema \{schema}")
  }
  let entries_key = "\"entries\":["
  let entries_start = fuzz_find_text_from(manifest_json, entries_key, 0)
  if entries_start < 0 {
    return Err("missing replay-all entries array")
  }
  let body_start = entries_start + entries_key.length()
  let entries_end = fuzz_find_text_last_from(manifest_json, "]", body_start)
  if entries_end < 0 {
    return Err("unterminated replay-all entries array")
  }
  let commands : Array[FuzzCorpusReplayCommandMetadata] = []
  let mut planned_count = 0
  let mut skipped_count = 0
  let mut malformed_count = 0
  let mut pos = fuzz_skip_manifest_ws_and_commas(
    manifest_json, body_start, entries_end,
  )
  while pos < entries_end {
    if manifest_json[pos] != '{' {
      malformed_count += 1
      pos += 1
    } else {
      match fuzz_find_json_object_end(manifest_json, pos, entries_end) {
        Some(end_pos) => {
          let entry_json = manifest_json.sub(start=pos, end=end_pos).to_owned()
          match parse_fuzz_corpus_promotion_metadata_json(entry_json) {
            Ok(entry) =>
              match build_fuzz_corpus_replay_command_metadata(entry) {
                Ok(command) => {
                  commands.push(command)
                  planned_count += 1
                }
                Err(_) => skipped_count += 1
              }
            Err(_) => malformed_count += 1
          }
          pos = end_pos
        }
        None => {
          malformed_count += 1
          pos = entries_end
        }
      }
    }
    pos = fuzz_skip_manifest_ws_and_commas(manifest_json, pos, entries_end)
  }
  Ok({ planned_count, skipped_count, malformed_count, commands })
}

///|
fn format_golden_seed_counter_kind(kind : GoldenSeedCounterKind) -> String {
  match kind {
    GoldenSeedCounterKind::Exact => "exact"
    GoldenSeedCounterKind::Minimum => "minimum"
  }
}

///|
pub fn format_golden_seed_catalog_entry_json(
  entry : GoldenSeedCatalogEntry,
) -> String {
  let out = StringBuilder::new()
  out.write_string("{\"id\":\"")
  out.write_string(fuzz_json_escape(entry.id))
  out.write_string("\",\"suite\":\"")
  out.write_string(fuzz_json_escape(entry.suite))
  out.write_string("\",\"profile\":\"")
  out.write_string(fuzz_json_escape(entry.profile))
  out.write_string("\",\"seed\":\{entry.seed},\"expected_counters\":[")
  let mut i = 0
  while i < entry.expected_counters.length() {
    if i > 0 {
      out.write_char(',')
    }
    let counter = entry.expected_counters[i]
    out.write_string("{\"name\":\"")
    out.write_string(fuzz_json_escape(counter.name))
    out.write_string("\",\"kind\":\"")
    out.write_string(format_golden_seed_counter_kind(counter.kind))
    out.write_string("\",\"value\":\{counter.value}}")
    i += 1
  }
  out.write_string("],\"covered_surfaces\":")
  out.write_string(format_fuzz_string_array_json(entry.covered_surfaces))
  out.write_string(",\"artifacts\":")
  out.write_string(format_fuzz_string_array_json(entry.artifacts))
  out.write_string(",\"notes\":\"")
  out.write_string(fuzz_json_escape(entry.notes))
  out.write_string("\"}")
  out.to_string()
}

///|
pub fn format_golden_seed_catalog_json(
  entries : Array[GoldenSeedCatalogEntry],
) -> String {
  let out = StringBuilder::new()
  out.write_string(
    "{\"schema\":\"starshine.fuzz.golden-seed-catalog.v1\",\"entries\":[",
  )
  let mut i = 0
  while i < entries.length() {
    if i > 0 {
      out.write_char(',')
    }
    out.write_string(format_golden_seed_catalog_entry_json(entries[i]))
    i += 1
  }
  out.write_string("]}")
  out.to_string()
}

///|
pub fn golden_seed_catalog_schema_json() -> String {
  "{\"schema\":\"starshine.fuzz.golden-seed-catalog.v1\",\"entry\":{\"required\":[\"id\",\"suite\",\"profile\",\"seed\",\"expected_counters\",\"covered_surfaces\"],\"optional\":[\"artifacts\",\"notes\"],\"fields\":{\"id\":\"stable unique catalog id\",\"suite\":\"fuzz suite or adapter name\",\"profile\":\"suite profile or recipe profile\",\"seed\":\"unsigned 64-bit deterministic root seed\",\"expected_counters\":\"array of named exact or minimum counters\",\"covered_surfaces\":\"maintained feature/strategy surfaces this seed exercises\",\"artifacts\":\"expected artifact file names or logical outputs\",\"notes\":\"human maintenance note\"}},\"counter_value_kind\":\"exact-or-minimum-nonnegative-integer\"}"
}

///|
fn format_gen_valid_batch_transform_ids_json(ids : Array[String]) -> String {
  let out = StringBuilder::new()
  out.write_char('[')
  let mut i = 0
  while i < ids.length() {
    if i > 0 {
      out.write_char(',')
    }
    out.write_string("\"\{fuzz_json_escape(ids[i])}\"")
    i += 1
  }
  out.write_char(']')
  out.to_string()
}

///|
fn format_gen_valid_batch_manifest_json(
  args : EmitGenValidBatchArgs,
  selection : GenValidCoverageSelection,
) -> String {
  let out = StringBuilder::new()
  out.write_string(
    "{\"generator\":\"gen-valid\",\"seed\":\{args.seed},\"count\":\{args.count},\"profile\":\"\{fuzz_json_escape(args.profile)}\",\"max_attempts\":\{args.max_attempts},\"attempts\":\{selection.attempts},\"selected\":\{selection.selected},\"skipped_candidates\":\{selection.skipped_candidates},\"metamorphic_transform_ids\":\{format_gen_valid_batch_transform_ids_json(args.metamorphic_transform_ids)},\"required_features\":\{format_validate_valid_feature_floors_json(args.required_features)},\"excluded_features\":\{format_gen_valid_batch_feature_keys_json(args.excluded_features)},\"feature_stats\":\{format_gen_valid_feature_stats_json(selection.feature_stats)},\"stream_derivations\":\{format_gen_valid_stream_derivations_json(args.seed)},\"records\":[",
  )
  let mut i = 0
  while i < selection.manifest.length() {
    if i > 0 {
      out.write_char(',')
    }
    let item = selection.manifest[i]
    let error_json = match item.validation_error_message {
      Some(msg) => "\"\{fuzz_json_escape(msg)}\""
      None => "null"
    }
    let transform_json = match item.transform_id {
      Some(id) => "\"\{fuzz_json_escape(id)}\""
      None => "null"
    }
    out.write_string(
      "{\"file_name\":\"\{fuzz_json_escape(item.file_name)}\",\"seed\":\{item.seed},\"index\":\{item.index},\"config_label\":\"\{fuzz_json_escape(item.config_label)}\",\"attempts\":\{item.attempts},\"validated\":\{item.validated},\"validation_error_message\":\{error_json},\"transform_id\":\{transform_json},\"feature_facts\":\{format_gen_valid_batch_feature_facts_json(item.facts)}}",
    )
    i += 1
  }
  out.write_string("]}")
  out.to_string()
}

///|
fn emit_gen_valid_batch_selection(
  args : EmitGenValidBatchArgs,
) -> Result[GenValidCoverageSelection, String] {
  let config = match GenValidConfig::profile(args.profile) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let selection = match
    emit_gen_valid_batch_artifacts_until_features(
      args.count,
      args.seed,
      config,
      args.required_features,
      args.excluded_features,
      args.max_attempts,
      metamorphic_transform_ids=args.metamorphic_transform_ids,
    ) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(selection)
}

///|
fn emit_gen_valid_batch_to_dir(
  args : EmitGenValidBatchArgs,
) -> Result[GenValidCoverageSelection, String] {
  let selection = match emit_gen_valid_batch_selection(args) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  match create_dir(args.out_dir) {
    Ok(_) => ()
    Err(e) =>
      return Err("failed to create gen-valid output dir \{args.out_dir}: \{e}")
  }
  for artifact in selection.artifacts {
    let path = fuzz_join_path(args.out_dir, artifact.0)
    match write_file_bytes(path, artifact.1) {
      Ok(_) => ()
      Err(e) => return Err("failed to write gen-valid artifact \{path}: \{e}")
    }
  }
  match args.manifest_path {
    Some(path) => {
      let manifest_json = format_gen_valid_batch_manifest_json(args, selection)
      match write_file_bytes(path, fuzz_string_to_bytes(manifest_json)) {
        Ok(_) => ()
        Err(e) => return Err("failed to write gen-valid manifest \{path}: \{e}")
      }
    }
    None => ()
  }
  Ok(selection)
}

///|
fn emit_invalid_repro_report(
  args : EmitInvalidReproArgs,
) -> Result[InvalidFuzzFailureReport, String] {
  build_invalid_fuzz_failure_report_by_suite_and_stable_id(
    args.suite,
    args.strategy_id,
    args.seed,
    args.attempt,
    profile=args.profile,
  )
}

///|
fn emit_invalid_repro_to_dir(
  args : EmitInvalidReproArgs,
) -> Result[(String, Int), String] {
  let report = match emit_invalid_repro_report(args) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let io = InvalidFuzzPersistIO::new(ensure_dir=fn(path) { create_dir(path) }, write_file=fn(
    path,
    bytes,
  ) {
    write_file_bytes(path, bytes)
  })
  let (meta_path, artifact_paths) = match
    persist_invalid_fuzz_failure_report(report, io, corpus_dir=args.out_dir) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((meta_path, artifact_paths.length()))
}

///|
pub fn run_fuzz_suite(
  suite : String,
  profile : String,
  seed_i64 : Int64,
) -> Result[Array[FuzzSuiteResult], String] {
  run_fuzz_suite_sweep(suite, profile, seed_i64, 1, 0, 1)
}

///|
fn golden_seed_validate_valid_counter_present(
  details : String,
  counter : GoldenSeedExpectedCounter,
) -> Bool {
  let field = match counter.name {
    "features.v128" => "v128"
    name => name
  }
  if counter.value <= 0 {
    return true
  }
  if details.contains("\"\{field}\":0") {
    return false
  }
  details.contains("\"\{field}\":")
}

///|
fn run_fuzz_golden_seed_catalog_validate_valid_case() -> Result[
  FuzzGoldenSeedSmokeCase,
  String,
] {
  let mut entry : GoldenSeedCatalogEntry? = None
  for candidate in golden_seed_smoke_suite_catalog() {
    if candidate.id == "gen-valid-coverage-forced-smoke" {
      entry = Some(candidate)
    }
  }
  let entry = match entry {
    Some(v) => v
    None => return Err("missing gen-valid golden seed catalog entry")
  }
  let results = match
    run_fuzz_suite_sweep(
      entry.suite,
      entry.profile,
      entry.seed.reinterpret_as_int64(),
      1,
      0,
      1,
    ) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if results.length() != 1 {
    return Err(
      "golden seed catalog smoke expected one result for \{entry.id}, got \{results.length()}",
    )
  }
  let result = results[0]
  if result.attempts != 128 {
    return Err(
      "golden seed catalog counter drift: id=\{entry.id} expected attempts=128 got \{result.attempts}",
    )
  }
  let details = match result.details_json {
    Some(v) => v
    None => return Err("golden seed catalog missing details: id=\{entry.id}")
  }
  for counter in entry.expected_counters {
    if !golden_seed_validate_valid_counter_present(details, counter) {
      return Err(
        "golden seed catalog expected counter missing: id=\{entry.id} counter=\{counter.name}",
      )
    }
  }
  Ok(
    FuzzGoldenSeedSmokeCase::new(
      result.suite,
      result.profile,
      result.seed,
      result.seed_index,
      result.attempts,
      true,
      details_json=result.details_json,
      catalog_entry_id=Some(entry.id),
      expected_counter_count=entry.expected_counters.length(),
    ),
  )
}

///|
pub fn format_fuzz_golden_seed_smoke_report(
  report : FuzzGoldenSeedSmokeReport,
) -> String {
  let out = StringBuilder::new()
  out.write_string(
    "schema=\{report.schema_id} recipe=\{report.recipe_name} seed=\{report.seed}\n",
  )
  for case in report.cases {
    let catalog_suffix = match case.catalog_entry_id {
      Some(id) => " catalog_entry_id=\{id}"
      None => ""
    }
    let counter_suffix = if case.expected_counter_count > 0 {
      " expected_counters=\{case.expected_counter_count}"
    } else {
      ""
    }
    out.write_string(
      "suite=\{case.suite} profile=\{case.profile} seed=\{case.seed} seed_index=\{case.seed_index} attempts=\{case.attempts} details_required=\{case.details_required}\{catalog_suffix}\{counter_suffix}\n",
    )
  }
  out.to_string()
}

///|
pub fn run_fuzz_golden_seed_smoke() -> Result[FuzzGoldenSeedSmokeReport, String] {
  let recipe = match fuzz_standard_recipe_by_name("smoke") {
    Some(v) => v
    None => return Err("missing smoke recipe")
  }
  let results = match
    run_fuzz_suite_sweep(
      recipe.suite,
      recipe.profile,
      recipe.seed_i64,
      recipe.seed_count,
      0,
      recipe.shard_count,
    ) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let cases : Array[FuzzGoldenSeedSmokeCase] = []
  for result in results {
    if result.attempts != 128 {
      return Err(
        "golden seed smoke counter drift: suite=\{result.suite} seed_index=\{result.seed_index} expected attempts=128 got \{result.attempts}",
      )
    }
    let details_required = result.suite == "validate-valid"
    if details_required {
      match result.details_json {
        Some(details) =>
          if !details.contains("\"validated\":128") ||
            !details.contains("\"generator_config\":\"coverage-forced\"") {
            return Err(
              "golden seed smoke detail drift: suite=\{result.suite} seed_index=\{result.seed_index}",
            )
          }
        None =>
          return Err(
            "golden seed smoke missing details: suite=\{result.suite} seed_index=\{result.seed_index}",
          )
      }
    }
    cases.push(
      FuzzGoldenSeedSmokeCase::new(
        result.suite,
        result.profile,
        result.seed,
        result.seed_index,
        result.attempts,
        details_required,
        details_json=result.details_json,
      ),
    )
  }
  match run_fuzz_golden_seed_catalog_validate_valid_case() {
    Ok(case) => cases.push(case)
    Err(e) => return Err(e)
  }
  Ok(
    FuzzGoldenSeedSmokeReport::new(
      "starshine.fuzz-golden-seed-smoke.v1",
      recipe.name,
      recipe.seed_i64,
      cases,
    ),
  )
}

///|
fn fuzz_seed_add(base : Int64, offset : Int) -> Int64 {
  (base.reinterpret_as_uint64() + offset.to_uint64()).reinterpret_as_int64()
}

///|
fn format_gen_valid_feature_stats_json(stats : GenValidFeatureStats) -> String {
  "{\"mode\":\"\{fuzz_json_escape(@debug.to_string(stats.mode))}\",\"modules\":\{stats.modules},\"imports\":\{stats.imports},\"func_exports\":\{stats.func_exports},\"tables\":\{stats.tables},\"mems\":\{stats.mems},\"globals\":\{stats.globals},\"tags\":\{stats.tags},\"elems\":\{stats.elems},\"datas\":\{stats.datas},\"data_count\":\{stats.data_count},\"ref_types\":\{stats.ref_types},\"v128\":\{stats.v128},\"calls\":\{stats.calls},\"call_indirect\":\{stats.call_indirect},\"branch_heavy_control\":\{stats.branch_heavy_control},\"numeric_full_ops\":\{stats.numeric_full_ops},\"br_table\":\{stats.br_table},\"local_tee\":\{stats.local_tee},\"typed_select\":\{stats.typed_select},\"tail_calls\":\{stats.tail_calls},\"atomics\":\{stats.atomics},\"gc_constructors\":\{stats.gc_constructors},\"gc_accessors\":\{stats.gc_accessors},\"string_ops\":\{stats.string_ops},\"exception_try_table_matrix\":\{stats.exception_try_table_matrix},\"subtyping_topology\":\{stats.subtyping_topology},\"import_export_topology\":\{stats.import_export_topology}}"
}

///|
fn format_validate_valid_feature_floors_json(
  floors : Array[ValidateValidFeatureFloor],
) -> String {
  let out = StringBuilder::new()
  out.write_char('[')
  let mut i = 0
  while i < floors.length() {
    if i > 0 {
      out.write_char(',')
    }
    let floor = floors[i]
    out.write_string(
      "{\"key\":\"\{fuzz_json_escape(@debug.to_string(floor.key))}\",\"min_count\":\{floor.min_count}}",
    )
    i += 1
  }
  out.write_char(']')
  out.to_string()
}

///|
fn format_validate_valid_details_json(stats : ValidateValidFuzzStats) -> String {
  "{\"validated\":\{stats.validated},\"generator_config\":\"\{fuzz_json_escape(gen_valid_config_label(stats.generator_config))}\",\"feature_stats\":\{format_gen_valid_feature_stats_json(stats.feature_stats)},\"feature_floors\":\{format_validate_valid_feature_floors_json(stats.feature_floors)}}"
}

///|
fn format_validate_valid_metamorphic_details_json(
  stats : ValidateValidMetamorphicFuzzStats,
) -> String {
  let out = StringBuilder::new()
  out.write_string(
    "{\"generated\":\{stats.generated},\"transformed\":\{stats.transformed},\"validated\":\{stats.validated},\"transform_ids\":[",
  )
  let mut i = 0
  while i < stats.transform_ids.length() {
    if i > 0 {
      out.write_char(',')
    }
    out.write_string("\"\{fuzz_json_escape(stats.transform_ids[i])}\"")
    i += 1
  }
  out.write_string("]}")
  out.to_string()
}

///|
fn format_binary_roundtrip_details_json(
  stats : BinaryRoundtripFuzzStats,
) -> String {
  "{\"arbitrary_roundtrips\":\{stats.arbitrary_roundtrips},\"gen_valid_modules\":\{stats.gen_valid_modules},\"gen_valid_validated\":\{stats.gen_valid_validated},\"byte_fuzz_cases\":\{stats.byte_fuzz_cases},\"byte_fuzz_decode_rejections\":\{stats.byte_fuzz_decode_rejections},\"byte_fuzz_decode_accepts\":\{stats.byte_fuzz_decode_accepts},\"byte_fuzz_validate_rejections\":\{stats.byte_fuzz_validate_rejections},\"byte_fuzz_stable_roundtrips\":\{stats.byte_fuzz_stable_roundtrips},\"boundary_roundtrips\":\{stats.boundary_roundtrips},\"instruction_roundtrips\":\{stats.instruction_roundtrips},\"section_roundtrips\":\{stats.section_roundtrips},\"immediate_roundtrips\":\{stats.immediate_roundtrips}}"
}

///|
fn format_wat_roundtrip_details_json(stats : WatRoundtripFuzzStats) -> String {
  "{\"successes\":\{stats.successes},\"stable\":\{stats.stable},\"module_print_failures\":\{stats.module_print_failures},\"parse_failures\":\{stats.parse_failures},\"roundtrip_print_failures\":\{stats.roundtrip_print_failures},\"unstable_text\":\{stats.unstable_text},\"script_iterations\":\{stats.script_iterations},\"module_commands\":\{stats.module_commands},\"rendered_scripts\":\{stats.rendered_scripts},\"script_render_failures\":\{stats.script_render_failures},\"script_no_module_commands\":\{stats.script_no_module_commands}}"
}

///|
fn format_wast_validate_details_json(
  stats : WastValidateRoundtripFuzzStats,
) -> String {
  "{\"printed\":\{stats.printed},\"print_failures\":\{stats.print_failures},\"parsed\":\{stats.parsed},\"parse_failures\":\{stats.parse_failures},\"lowered\":\{stats.lowered},\"lower_failures\":\{stats.lower_failures},\"validated\":\{stats.validated},\"validation_failures\":\{stats.validation_failures}}"
}

///|
fn format_gen_valid_wat_validate_details_json(
  stats : GenValidWatValidateRoundtripFuzzStats,
) -> String {
  "{\"generated\":\{stats.generated},\"printed\":\{stats.printed},\"print_failures\":\{stats.print_failures},\"parsed\":\{stats.parsed},\"parse_failures\":\{stats.parse_failures},\"lowered\":\{stats.lowered},\"lower_failures\":\{stats.lower_failures},\"validated\":\{stats.validated},\"validation_failures\":\{stats.validation_failures}}"
}

///|
fn format_text_differential_adapter_names_json(names : Array[String]) -> String {
  let out = StringBuilder::new()
  out.write_char('[')
  let mut i = 0
  while i < names.length() {
    if i > 0 {
      out.write_char(',')
    }
    out.write_string("\"\{fuzz_json_escape(names[i])}\"")
    i += 1
  }
  out.write_char(']')
  out.to_string()
}

///|
fn format_text_differential_details_json(
  stats : TextDifferentialFuzzStats,
) -> String {
  "{\"local_parse_ok\":\{stats.local_parse_ok},\"local_print_ok\":\{stats.local_print_ok},\"local_reparse_lower_ok\":\{stats.local_reparse_lower_ok},\"local_lower_mismatch\":\{stats.local_lower_mismatch},\"adapter_unavailable\":\{stats.adapter_unavailable},\"adapter_unavailable_classifications\":\{stats.adapter_unavailable_classifications},\"accepted_classifications\":\{stats.accepted_classifications},\"external_adapters\":\{format_text_differential_adapter_names_json(stats.external_adapters)}}"
}

///|
fn format_valid_multi_module_linking_details_json(
  stats : ValidMultiModuleLinkingFuzzStats,
) -> String {
  "{\"generated\":\{stats.generated},\"parsed_scripts\":\{stats.parsed_scripts},\"parse_failures\":\{stats.parse_failures},\"single_module_validated\":\{stats.single_module_validated},\"single_module_validation_failures\":\{stats.single_module_validation_failures},\"link_passed\":\{stats.link_passed},\"link_failed\":\{stats.link_failed},\"link_skipped\":\{stats.link_skipped}}"
}

///|
fn format_invalid_ast_details_json(
  stats : ValidateInvalidAstFuzzStats,
) -> String {
  let out = StringBuilder::new()
  out.write_string("{\"seed_profiles\":[")
  let mut p = 0
  while p < stats.seed_profiles.length() {
    if p > 0 {
      out.write_char(',')
    }
    out.write_string(
      "{\"profile\":\"\{fuzz_json_escape(gen_invalid_named_seed_profile_name(stats.seed_profiles[p]))}\",\"attempts\":\{stats.seed_profile_attempts[p]}}",
    )
    p += 1
  }
  out.write_string("],\"strategy_stats\":[")
  let mut i = 0
  while i < stats.strategy_stats.length() {
    if i > 0 {
      out.write_char(',')
    }
    let item = stats.strategy_stats[i]
    out.write_string(
      "{\"stable_id\":\"\{fuzz_json_escape(item.stable_id)}\",\"attempted\":\{item.attempted},\"applicable\":\{item.applicable},\"mutated\":\{item.mutated},\"rejected\":\{item.rejected},\"rejected_expected\":\{item.rejected_expected}}",
    )
    i += 1
  }
  out.write_string("]}")
  out.to_string()
}

///|
fn format_invalid_binary_details_json(
  stats : ValidateInvalidBinaryFuzzStats,
) -> String {
  let out = StringBuilder::new()
  out.write_string("{\"seed_profiles\":[")
  let mut p = 0
  while p < stats.seed_profiles.length() {
    if p > 0 {
      out.write_char(',')
    }
    out.write_string(
      "{\"profile\":\"\{fuzz_json_escape(stats.seed_profiles[p])}\",\"attempts\":\{stats.seed_profile_attempts[p]}}",
    )
    p += 1
  }
  out.write_string("],\"strategy_stats\":[")
  let mut i = 0
  while i < stats.strategy_stats.length() {
    if i > 0 {
      out.write_char(',')
    }
    let item = stats.strategy_stats[i]
    out.write_string(
      "{\"stable_id\":\"\{fuzz_json_escape(item.stable_id)}\",\"attempted\":\{item.attempted},\"applicable\":\{item.applicable},\"mutated\":\{item.mutated},\"decode_rejected\":\{item.decode_rejected},\"validate_rejected\":\{item.validate_rejected},\"rejected_expected\":\{item.rejected_expected},\"accepted\":\{item.accepted}}",
    )
    i += 1
  }
  out.write_string("]}")
  out.to_string()
}

///|
fn format_invalid_text_details_json(
  stats : ValidateInvalidTextFuzzStats,
) -> String {
  let out = StringBuilder::new()
  out.write_string("{\"strategy_stats\":[")
  let mut i = 0
  while i < stats.strategy_stats.length() {
    if i > 0 {
      out.write_char(',')
    }
    let item = stats.strategy_stats[i]
    out.write_string(
      "{\"stable_id\":\"\{fuzz_json_escape(item.stable_id)}\",\"attempted\":\{item.attempted},\"applicable\":\{item.applicable},\"parse_or_lower_rejected\":\{item.parse_or_lower_rejected},\"validate_rejected\":\{item.validate_rejected},\"valid_before_link\":\{item.valid_before_link},\"matched_expected\":\{item.matched_expected}}",
    )
    i += 1
  }
  out.write_string("]}")
  out.to_string()
}

///|
fn format_invalid_text_dynamic_details_json(
  stats : ValidateInvalidTextDynamicFuzzStats,
) -> String {
  let out = StringBuilder::new()
  out.write_string(
    "{\"stream_label\":\"\{fuzz_json_escape(stats.stream_label)}\",\"stream_seed\":\{stats.stream_seed},\"generated\":\{stats.generated},\"mutated\":\{stats.mutated},\"parse_or_lower_rejected\":\{stats.parse_or_lower_rejected},\"validate_rejected\":\{stats.validate_rejected},\"valid_before_link\":\{stats.valid_before_link},\"matched_expected\":\{stats.matched_expected},\"strategy_stats\":[",
  )
  let mut i = 0
  while i < stats.strategy_stats.length() {
    if i > 0 {
      out.write_char(',')
    }
    let item = stats.strategy_stats[i]
    out.write_string(
      "{\"stable_id\":\"\{fuzz_json_escape(item.stable_id)}\",\"variant_id\":\"\{fuzz_json_escape(item.variant_id)}\",\"expected_stage\":\"\{validate_invalid_text_stage_name(item.expected_stage)}\",\"attempted\":\{item.attempted},\"generated\":\{item.generated},\"mutated\":\{item.mutated},\"parse_or_lower_rejected\":\{item.parse_or_lower_rejected},\"validate_rejected\":\{item.validate_rejected},\"valid_before_link\":\{item.valid_before_link},\"matched_expected\":\{item.matched_expected},\"source_feature_facts\":[",
    )
    let mut fact_idx = 0
    while fact_idx < item.source_feature_facts.length() {
      if fact_idx > 0 {
        out.write_char(',')
      }
      out.write_string(
        "\"\{fuzz_json_escape(item.source_feature_facts[fact_idx])}\"",
      )
      fact_idx += 1
    }
    out.write_string("]}")
    i += 1
  }
  out.write_string("]}")
  out.to_string()
}

///|
fn format_invalid_spec_seed_details_json(
  stats : ValidateInvalidSpecSeedFuzzStats,
) -> String {
  let out = StringBuilder::new()
  out.write_string("{\"seed_stats\":[")
  let mut i = 0
  while i < stats.seed_stats.length() {
    if i > 0 {
      out.write_char(',')
    }
    let item = stats.seed_stats[i]
    out.write_string(
      "{\"stable_id\":\"\{fuzz_json_escape(item.stable_id)}\",\"path\":\"\{fuzz_json_escape(item.path)}\",\"attempted\":\{item.attempted},\"applicable\":\{item.applicable},\"parse_or_lower_rejected\":\{item.parse_or_lower_rejected},\"validate_rejected\":\{item.validate_rejected},\"valid_before_link\":\{item.valid_before_link},\"matched_expected\":\{item.matched_expected}}",
    )
    i += 1
  }
  out.write_string("],\"dynamic\":{")
  out.write_string(
    "\"scanned\":\{stats.dynamic_scanned},\"attempted\":\{stats.dynamic_attempted},\"matched_expected\":\{stats.dynamic_matched_expected},\"malformed_matched\":\{stats.dynamic_malformed_matched},\"invalid_matched\":\{stats.dynamic_invalid_matched},\"unlinkable_matched\":\{stats.dynamic_unlinkable_matched},\"feature_families_matched\":[",
  )
  let mut family_idx = 0
  while family_idx < stats.dynamic_feature_families_matched.length() {
    if family_idx > 0 {
      out.write_char(',')
    }
    out.write_string(
      "\"\{fuzz_json_escape(stats.dynamic_feature_families_matched[family_idx])}\"",
    )
    family_idx += 1
  }
  out.write_string("]}}")
  out.to_string()
}

///|
fn fuzz_suite_result_with_sweep_metadata(
  result : FuzzSuiteResult,
  seed_index : Int,
  seed_count : Int,
  shard_index : Int,
  shard_count : Int,
) -> FuzzSuiteResult {
  FuzzSuiteResult::{
    suite: result.suite,
    profile: result.profile,
    seed: result.seed,
    attempts: result.attempts,
    elapsed_ms: result.elapsed_ms,
    seed_index,
    seed_count,
    shard_index,
    shard_count,
    total_run_budget_ms: result.total_run_budget_ms,
    total_run_budget_exceeded: result.total_run_budget_exceeded,
    run_budget_classification: result.run_budget_classification,
    details_json: result.details_json,
  }
}

///|
fn fuzz_suite_result_less(a : FuzzSuiteResult, b : FuzzSuiteResult) -> Bool {
  if a.seed_index != b.seed_index {
    return a.seed_index < b.seed_index
  }
  if a.suite != b.suite {
    return a.suite < b.suite
  }
  if a.profile != b.profile {
    return a.profile < b.profile
  }
  if a.shard_index != b.shard_index {
    return a.shard_index < b.shard_index
  }
  a.seed < b.seed
}

///|
pub fn merge_fuzz_shard_results(
  shard_results : Array[Array[FuzzSuiteResult]],
) -> Array[FuzzSuiteResult] {
  let remaining : Array[FuzzSuiteResult] = []
  for shard in shard_results {
    for result in shard {
      remaining.push(result)
    }
  }
  let merged : Array[FuzzSuiteResult] = []
  while !remaining.is_empty() {
    let mut best = 0
    let mut i = 1
    while i < remaining.length() {
      if fuzz_suite_result_less(remaining[i], remaining[best]) {
        best = i
      }
      i += 1
    }
    merged.push(remaining[best])
    remaining[best] = remaining[remaining.length() - 1]
    ignore(remaining.pop())
  }
  merged
}

///|
pub fn fuzz_suite_result_with_total_run_budget(
  result : FuzzSuiteResult,
  total_run_budget_ms : UInt64,
) -> FuzzSuiteResult {
  let exceeded = result.elapsed_ms > total_run_budget_ms
  {
    suite: result.suite,
    profile: result.profile,
    seed: result.seed,
    attempts: result.attempts,
    elapsed_ms: result.elapsed_ms,
    seed_index: result.seed_index,
    seed_count: result.seed_count,
    shard_index: result.shard_index,
    shard_count: result.shard_count,
    total_run_budget_ms: Some(total_run_budget_ms),
    total_run_budget_exceeded: exceeded,
    run_budget_classification: if exceeded {
      "run-budget-timeout"
    } else {
      "within-budget"
    },
    details_json: result.details_json,
  }
}

///|
pub fn run_fuzz_suite_sweep(
  suite : String,
  profile : String,
  seed_i64 : Int64,
  seed_count : Int,
  shard_index : Int,
  shard_count : Int,
) -> Result[Array[FuzzSuiteResult], String] {
  if seed_count <= 0 {
    return Err("seed-count must be greater than zero")
  }
  if shard_count <= 0 {
    return Err("shard-count must be greater than zero")
  }
  if shard_index < 0 || shard_index >= shard_count {
    return Err("shard-index must be non-negative and less than shard-count")
  }
  let suite_name = fuzz_ascii_lower(suite.trim().to_owned())
  let profile_name = fuzz_ascii_lower(profile.trim().to_owned())
  let out : Array[FuzzSuiteResult] = []
  let mut seed_index = 0
  while seed_index < seed_count {
    if seed_index % shard_count == shard_index {
      let run_seed = fuzz_seed_add(seed_i64, seed_index)
      if suite_name == "all" {
        let suites = fuzz_active_suite_names()
        for name in suites {
          match run_single_suite(name, profile_name, run_seed) {
            Ok(result) =>
              out.push(
                fuzz_suite_result_with_sweep_metadata(
                  result, seed_index, seed_count, shard_index, shard_count,
                ),
              )
            Err(e) => return Err(e)
          }
        }
      } else {
        match run_single_suite(suite_name, profile_name, run_seed) {
          Ok(result) =>
            out.push(
              fuzz_suite_result_with_sweep_metadata(
                result, seed_index, seed_count, shard_index, shard_count,
              ),
            )
          Err(e) => return Err(e)
        }
      }
    }
    seed_index += 1
  }
  Ok(out)
}

///|
fn fuzz_json_escape(input : String) -> String {
  let out = StringBuilder::new()
  for c in input {
    match c {
      '"' => out.write_string("\\\"")
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      '\r' => out.write_string("\\r")
      '\t' => out.write_string("\\t")
      _ => out.write_char(c)
    }
  }
  out.to_string()
}

///|
pub fn parse_fuzz_replay_manifest_commands(
  manifest_json : String,
) -> Result[Array[FuzzReplayCommand], String] {
  let array_key = "\"commands\":["
  let array_start = fuzz_find_text_from(manifest_json, array_key, 0)
  if array_start < 0 {
    return Err("missing commands array")
  }
  let body_start = array_start + array_key.length()
  let array_end = fuzz_find_text_last_from(manifest_json, "]", body_start)
  if array_end < 0 {
    return Err("unterminated commands array")
  }
  let suite_key = "\"suite\":"
  let profile_key = "\"profile\":"
  let seed_key = "\"seed\":"
  let index_key = "\"seed_index\":"
  let commands : Array[FuzzReplayCommand] = []
  let mut pos = body_start
  while pos < array_end {
    let suite_pos = fuzz_find_text_from(manifest_json, suite_key, pos)
    if suite_pos < 0 || suite_pos >= array_end {
      break
    }
    let suite = match
      fuzz_parse_simple_json_string_at(
        manifest_json,
        suite_pos + suite_key.length(),
      ) {
      Some(v) => v
      None => return Err("malformed replay suite")
    }
    let profile_pos = fuzz_find_text_from(manifest_json, profile_key, suite.1)
    if profile_pos < 0 || profile_pos >= array_end {
      return Err("missing replay profile for \{suite.0}")
    }
    let profile = match
      fuzz_parse_simple_json_string_at(
        manifest_json,
        profile_pos + profile_key.length(),
      ) {
      Some(v) => v
      None => return Err("malformed replay profile")
    }
    let seed_pos = fuzz_find_text_from(manifest_json, seed_key, profile.1)
    if seed_pos < 0 || seed_pos >= array_end {
      return Err("missing replay seed for \{suite.0}")
    }
    let seed = match
      fuzz_parse_uint64_decimal_at(manifest_json, seed_pos + seed_key.length()) {
      Some(v) => v
      None => return Err("malformed replay seed")
    }
    let index_pos = fuzz_find_text_from(manifest_json, index_key, seed.1)
    if index_pos < 0 || index_pos >= array_end {
      return Err("missing replay seed_index for \{suite.0}")
    }
    let seed_index = match
      fuzz_parse_uint64_decimal_at(
        manifest_json,
        index_pos + index_key.length(),
      ) {
      Some(v) => v
      None => return Err("malformed replay seed_index")
    }
    commands.push({
      suite: suite.0,
      profile: profile.0,
      seed: seed.0.reinterpret_as_int64(),
      seed_index: seed_index.0.to_int(),
    })
    pos = seed_index.1
  }
  if commands.is_empty() {
    return Err("replay manifest has no commands")
  }
  Ok(commands)
}

///|
pub fn run_fuzz_replay_manifest(
  manifest_json : String,
) -> Result[Array[FuzzSuiteResult], String] {
  let commands = match parse_fuzz_replay_manifest_commands(manifest_json) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let out : Array[FuzzSuiteResult] = []
  for command in commands {
    match run_single_suite(command.suite, command.profile, command.seed) {
      Ok(result) =>
        out.push(
          fuzz_suite_result_with_sweep_metadata(
            result,
            command.seed_index,
            1,
            0,
            1,
          ),
        )
      Err(e) => return Err(e)
    }
  }
  Ok(out)
}

///|
pub fn format_fuzz_suite_result(
  result : FuzzSuiteResult,
  output_mode : FuzzOutputMode,
) -> String {
  let sweep_suffix = if result.seed_count == 1 && result.shard_count == 1 {
    ""
  } else {
    " seed_index=\{result.seed_index} seed_count=\{result.seed_count} shard_index=\{result.shard_index} shard_count=\{result.shard_count}"
  }
  let budget_suffix = match result.total_run_budget_ms {
    Some(budget) =>
      " total_run_budget_ms=\{budget} run_budget_classification=\{result.run_budget_classification}"
    None => ""
  }
  let pass = !result.total_run_budget_exceeded
  match output_mode {
    FuzzOutputMode::Text =>
      "suite=\{result.suite} profile=\{result.profile} seed=\{result.seed} attempts=\{result.attempts} pass=\{pass} elapsed_ms=\{result.elapsed_ms}\{budget_suffix}\{sweep_suffix}"
    FuzzOutputMode::Jsonl => {
      let details_suffix = match result.details_json {
        Some(details) => ",\"details\":\{details}"
        None => ""
      }
      let budget_json = match result.total_run_budget_ms {
        Some(budget) =>
          ",\"total_run_budget_ms\":\{budget},\"run_budget_classification\":\"\{fuzz_json_escape(result.run_budget_classification)}\""
        None => ""
      }
      "{\"suite\":\"\{fuzz_json_escape(result.suite)}\",\"profile\":\"\{fuzz_json_escape(result.profile)}\",\"seed\":\{result.seed},\"attempts\":\{result.attempts},\"pass\":\{pass},\"elapsed_ms\":\{result.elapsed_ms}\{budget_json},\"seed_index\":\{result.seed_index},\"seed_count\":\{result.seed_count},\"shard_index\":\{result.shard_index},\"shard_count\":\{result.shard_count}\{details_suffix}}"
    }
  }
}

///|
fn fuzz_uint64_to_lower_hex(value : UInt64) -> String {
  if value == 0UL {
    return "0"
  }
  let digits = "0123456789abcdef"
  let out = StringBuilder::new()
  let mut started = false
  let mut shift = 60
  while shift >= 0 {
    let nibble = ((value >> shift) & 0xfUL).to_int()
    if nibble != 0 || started {
      started = true
      out.write_char(digits[nibble].unsafe_to_char())
    }
    shift -= 4
  }
  out.to_string()
}

///|
fn fuzz_json_number_field_or_zero(json : String, field : String) -> UInt64 {
  let key = "\"\{field}\":"
  let pos = fuzz_find_text_from(json, key, 0)
  if pos < 0 {
    return 0UL
  }
  match fuzz_parse_uint64_decimal_at(json, pos + key.length()) {
    Some(v) => v.0
    None => 0UL
  }
}

///|
fn fuzz_validate_valid_summary_feature_counter(
  results : Array[FuzzSuiteResult],
  field : String,
) -> UInt64 {
  let mut total = 0UL
  for result in results {
    match result.details_json {
      Some(details) => total += fuzz_json_number_field_or_zero(details, field)
      None => ()
    }
  }
  total
}

///|
fn format_validate_valid_fuzz_summary_report_json(
  profile : String,
  base_seed : Int64,
  results : Array[FuzzSuiteResult],
) -> String {
  let mut total_attempts = 0
  let mut total_elapsed_ms = 0UL
  for result in results {
    total_attempts += result.attempts
    total_elapsed_ms += result.elapsed_ms
  }
  let modules = fuzz_validate_valid_summary_feature_counter(results, "modules")
  let imports = fuzz_validate_valid_summary_feature_counter(results, "imports")
  let ref_types = fuzz_validate_valid_summary_feature_counter(
    results, "ref_types",
  )
  let v128 = fuzz_validate_valid_summary_feature_counter(results, "v128")
  let smoke_required_suffix = if profile == "smoke" {
    ",\"required_imports\":\{imports},\"required_ref_types\":\{ref_types},\"required_v128\":\{v128}"
  } else {
    ",\"optional_imports\":\{imports},\"optional_ref_types\":\{ref_types},\"optional_v128\":\{v128}"
  }
  "{\"schema\":\"starshine.fuzz-summary-report.v1\",\"suite\":\"validate-valid\",\"profile\":\"\{fuzz_json_escape(profile)}\",\"seed\":\"0x\{fuzz_uint64_to_lower_hex(base_seed.reinterpret_as_uint64())}\",\"summary\":{\"features\":{\"required_modules\":\{modules}\{smoke_required_suffix}},\"opcodes\":{},\"strategies\":{\"required_validate_valid\":\{total_attempts}},\"statuses\":{\"validate-valid\":\{results.length()}},\"failures\":{\"validation\":0},\"timings\":{\"wall_ms\":\{total_elapsed_ms}},\"artifacts\":{\"runs\":\{results.length()}}}}"
}

///|
pub fn format_fuzz_run_report_json(
  suite : String,
  profile : String,
  base_seed : Int64,
  seed_count : Int,
  shard_index : Int,
  shard_count : Int,
  results : Array[FuzzSuiteResult],
) -> String {
  let out = StringBuilder::new()
  let mut total_attempts = 0
  let mut total_elapsed_ms = 0UL
  let mut run_budget_timeout_count = 0
  let mut summary_i = 0
  while summary_i < results.length() {
    total_attempts += results[summary_i].attempts
    total_elapsed_ms += results[summary_i].elapsed_ms
    if results[summary_i].total_run_budget_exceeded {
      run_budget_timeout_count += 1
    }
    summary_i += 1
  }
  let failure_classes = if run_budget_timeout_count > 0 {
    "{\"run-budget-timeout\":\{run_budget_timeout_count}}"
  } else {
    "{}"
  }
  let pass = run_budget_timeout_count == 0
  out.write_string(
    "{\"schema\":\"starshine.fuzz.summary.v1\",\"suite\":\"\{fuzz_json_escape(suite)}\",\"profile\":\"\{fuzz_json_escape(profile)}\",\"base_seed\":\{base_seed},\"seed_count\":\{seed_count},\"shard_index\":\{shard_index},\"shard_count\":\{shard_count},\"pass\":\{pass},\"run_count\":\{results.length()},\"summary\":{\"total_attempts\":\{total_attempts},\"total_elapsed_ms\":\{total_elapsed_ms},\"failure_classes\":\{failure_classes},\"strategy_outcomes\":{},\"artifact_counts\":{\"runs\":\{results.length()},\"ledgers\":1,\"replay_manifests\":1,\"inputs\":0,\"failures\":\{run_budget_timeout_count}}},\"runs\":[",
  )
  let mut i = 0
  while i < results.length() {
    if i > 0 {
      out.write_string(",")
    }
    out.write_string(
      format_fuzz_suite_result(results[i], FuzzOutputMode::Jsonl),
    )
    i += 1
  }
  out.write_string("]}")
  out.to_string()
}

///|
fn format_fuzz_suite_ledger_json(
  suite : String,
  profile : String,
  base_seed : Int64,
  seed_count : Int,
  shard_index : Int,
  shard_count : Int,
  results : Array[FuzzSuiteResult],
) -> String {
  let out = StringBuilder::new()
  out.write_string(
    "{\"schema\":\"starshine.fuzz-suite-ledger.v1\",\"suite\":\"\{fuzz_json_escape(suite)}\",\"profile\":\"\{fuzz_json_escape(profile)}\",\"base_seed\":\{base_seed},\"seed_count\":\{seed_count},\"shard_index\":\{shard_index},\"shard_count\":\{shard_count},\"run_count\":\{results.length()},\"runs\":[",
  )
  let mut i = 0
  while i < results.length() {
    if i > 0 {
      out.write_string(",")
    }
    let result = results[i]
    out.write_string(
      "{\"suite\":\"\{fuzz_json_escape(result.suite)}\",\"profile\":\"\{fuzz_json_escape(result.profile)}\",\"seed\":\{result.seed},\"seed_index\":\{result.seed_index},\"attempts\":\{result.attempts},\"elapsed_ms\":\{result.elapsed_ms},\"details\":",
    )
    match result.details_json {
      Some(details) => out.write_string(details)
      None => out.write_string("null")
    }
    out.write_string("}")
    i += 1
  }
  out.write_string("]}")
  out.to_string()
}

///|
fn format_fuzz_replay_manifest_json(
  suite : String,
  profile : String,
  base_seed : Int64,
  seed_count : Int,
  shard_index : Int,
  shard_count : Int,
  results : Array[FuzzSuiteResult],
) -> String {
  let out = StringBuilder::new()
  out.write_string(
    "{\"schema\":\"starshine.fuzz-replay-manifest.v1\",\"suite\":\"\{fuzz_json_escape(suite)}\",\"profile\":\"\{fuzz_json_escape(profile)}\",\"base_seed\":\{base_seed},\"seed_count\":\{seed_count},\"shard_index\":\{shard_index},\"shard_count\":\{shard_count},\"commands\":[",
  )
  let mut i = 0
  while i < results.length() {
    if i > 0 {
      out.write_string(",")
    }
    let result = results[i]
    out.write_string(
      "{\"suite\":\"\{fuzz_json_escape(result.suite)}\",\"profile\":\"\{fuzz_json_escape(result.profile)}\",\"seed\":\{result.seed},\"seed_index\":\{result.seed_index},\"command\":\"moon run src/fuzz --\",\"args\":[\"\{fuzz_json_escape(result.suite)}\",\"\{fuzz_json_escape(result.profile)}\",\"--seed\",\"\{result.seed}\",\"--seed-count\",\"1\",\"--shard-index\",\"0\",\"--shard-count\",\"1\"]}",
    )
    i += 1
  }
  out.write_string("]}")
  out.to_string()
}

///|
pub fn persist_fuzz_run_output(
  out_dir : String,
  suite : String,
  profile : String,
  base_seed : Int64,
  seed_count : Int,
  shard_index : Int,
  shard_count : Int,
  results : Array[FuzzSuiteResult],
  io : FuzzRunOutputIO,
) -> Result[Unit, String] {
  let dir = out_dir.trim().to_owned()
  if dir.length() == 0 {
    return Err("fuzz output dir must not be empty")
  }
  match (io.ensure_dir)(dir) {
    Ok(_) => ()
    Err(e) => return Err("failed to create fuzz output dir \{dir}: \{e}")
  }
  let ledger_dir = fuzz_join_path(dir, "ledgers")
  match (io.ensure_dir)(ledger_dir) {
    Ok(_) => ()
    Err(e) => return Err("failed to create fuzz ledger dir \{ledger_dir}: \{e}")
  }
  let replay_dir = fuzz_join_path(dir, "replay")
  match (io.ensure_dir)(replay_dir) {
    Ok(_) => ()
    Err(e) => return Err("failed to create fuzz replay dir \{replay_dir}: \{e}")
  }
  let result_json = format_fuzz_run_report_json(
    suite, profile, base_seed, seed_count, shard_index, shard_count, results,
  )
  let cases = StringBuilder::new()
  let mut i = 0
  while i < results.length() {
    cases.write_string(
      format_fuzz_suite_result(results[i], FuzzOutputMode::Jsonl),
    )
    cases.write_char('\n')
    i += 1
  }
  let ledger_path = "ledgers/\{suite}-ledger.json"
  let replay_path = "replay/\{suite}-replay.json"
  let suite_ledger = format_fuzz_suite_ledger_json(
    suite, profile, base_seed, seed_count, shard_index, shard_count, results,
  )
  let replay_manifest = format_fuzz_replay_manifest_json(
    suite, profile, base_seed, seed_count, shard_index, shard_count, results,
  )
  let summary_json = if suite == "validate-valid" {
    Some(
      format_validate_valid_fuzz_summary_report_json(
        profile, base_seed, results,
      ),
    )
  } else {
    None
  }
  let summary_file = match summary_json {
    Some(_) => ",\"summary.json\""
    None => ""
  }
  let manifest = "{\"schema\":\"starshine.fuzz-output.v1\",\"files\":[\"result.json\",\"cases.jsonl\",\"\{ledger_path}\",\"\{replay_path}\"\{summary_file}],\"artifact_dirs\":[\"inputs\",\"failures\",\"ledgers\",\"replay\"]}"
  let writes = [
    ("result.json", fuzz_string_to_bytes(result_json)),
    ("cases.jsonl", fuzz_string_to_bytes(cases.to_string())),
    ("manifest.json", fuzz_string_to_bytes(manifest)),
    (ledger_path, fuzz_string_to_bytes(suite_ledger)),
    (replay_path, fuzz_string_to_bytes(replay_manifest)),
  ]
  for item in writes {
    let path = fuzz_join_path(dir, item.0)
    match (io.write_file)(path, item.1) {
      Ok(_) => ()
      Err(e) => return Err("failed to write fuzz output \{path}: \{e}")
    }
  }
  match summary_json {
    Some(json) => {
      let path = fuzz_join_path(dir, "summary.json")
      match (io.write_file)(path, fuzz_string_to_bytes(json)) {
        Ok(_) => ()
        Err(e) => return Err("failed to write fuzz output \{path}: \{e}")
      }
    }
    None => ()
  }
  Ok(())
}

///|
fn fuzz_string_to_bytes(text : String) -> Bytes {
  let buf = @buffer.new(size_hint=text.length())
  for c in text {
    let code = c.to_int()
    if code >= 0 && code <= 255 {
      buf.write_byte(code.to_byte())
    } else {
      buf.write_byte('?'.to_int().to_byte())
    }
  }
  buf.to_bytes()
}

///|
fn print_fuzz_suite_result(
  result : FuzzSuiteResult,
  output_mode : FuzzOutputMode,
) -> Unit {
  println(format_fuzz_suite_result(result, output_mode))
}

///|
fn fuzz_trim_program_name(argv : Array[String]) -> Array[String] {
  if argv.length() == 0 {
    return []
  }
  let head = argv[0]
  let should_trim = head.contains("/") ||
    head.contains("\\") ||
    head.contains(".wasm") ||
    head.contains(".exe")
  if !should_trim {
    return argv
  }
  let out = Array::new(capacity=argv.length() - 1)
  let mut i = 1
  while i < argv.length() {
    out.push(argv[i])
    i += 1
  }
  out
}

///|
fn main {
  let args = fuzz_trim_program_name(@env.args())
  match parse_fuzz_cli_command(args) {
    FuzzCliCommand::Help => println(fuzz_usage_text())
    FuzzCliCommand::ListSuites =>
      for line in fuzz_suite_inventory_lines() {
        println(line)
      }
    FuzzCliCommand::ListProfiles =>
      for profile in fuzz_profile_names() {
        println(profile)
      }
    FuzzCliCommand::ListRecipes =>
      for recipe in fuzz_standard_recipe_names() {
        println(recipe)
      }
    FuzzCliCommand::EmitGenValidBatch(args) =>
      match emit_gen_valid_batch_to_dir(args) {
        Ok(selection) =>
          println(
            "generated=\{selection.selected} seed=\{args.seed} out_dir=\{args.out_dir} profile=\{args.profile} attempts=\{selection.attempts} skipped=\{selection.skipped_candidates}",
          )
        Err(e) => abort(e)
      }
    FuzzCliCommand::EmitInvalidRepro(args) =>
      match emit_invalid_repro_to_dir(args) {
        Ok((meta_path, artifact_count)) =>
          println(
            "meta_path=\{meta_path} artifacts=\{artifact_count} seed=\{args.seed} out_dir=\{args.out_dir}",
          )
        Err(e) => abort(e)
      }
    FuzzCliCommand::ReplayCorpus(path) => {
      let manifest = match read_file_sync(path) {
        Ok(text) => text
        Err(e) => abort("failed to read replay manifest \{path}: \{e}")
      }
      match run_fuzz_replay_manifest(manifest) {
        Ok(results) =>
          for result in results {
            print_fuzz_suite_result(result, FuzzOutputMode::Text)
          }
        Err(e) => abort(e)
      }
    }
    FuzzCliCommand::GoldenSeedSmoke =>
      match run_fuzz_golden_seed_smoke() {
        Ok(report) => println(format_fuzz_golden_seed_smoke_report(report))
        Err(e) => abort(e)
      }
    FuzzCliCommand::Run(parsed) => {
      let output_mode = parsed.output_mode
      match
        run_fuzz_suite_sweep(
          parsed.suite,
          parsed.profile,
          parsed.seed_i64,
          parsed.seed_count,
          parsed.shard_index,
          parsed.shard_count,
        ) {
        Ok(results) => {
          for result in results {
            print_fuzz_suite_result(result, output_mode)
          }
          match parsed.out_dir {
            Some(dir) => {
              let io = FuzzRunOutputIO::new(
                ensure_dir=create_dir,
                write_file=write_file_bytes,
              )
              match
                persist_fuzz_run_output(
                  dir,
                  parsed.suite,
                  parsed.profile,
                  parsed.seed_i64,
                  parsed.seed_count,
                  parsed.shard_index,
                  parsed.shard_count,
                  results,
                  io,
                ) {
                Ok(_) => ()
                Err(e) => abort(e)
              }
            }
            None => ()
          }
          match parsed.report_json_path {
            Some(path) => {
              let report = format_fuzz_run_report_json(
                parsed.suite,
                parsed.profile,
                parsed.seed_i64,
                parsed.seed_count,
                parsed.shard_index,
                parsed.shard_count,
                results,
              )
              match write_file_bytes(path, fuzz_string_to_bytes(report)) {
                Ok(_) => ()
                Err(e) =>
                  abort("failed to write fuzz JSON report \{path}: \{e}")
              }
            }
            None => ()
          }
        }
        Err(e) => abort(e)
      }
    }
  }
}
