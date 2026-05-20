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
} derive(Eq, Debug)

///|
pub struct EmitGenValidBatchArgs {
  count : Int
  seed : UInt64
  out_dir : String
} derive(Eq, Debug)

///|
pub fn EmitGenValidBatchArgs::new(
  count : Int,
  seed : UInt64,
  out_dir : String,
) -> EmitGenValidBatchArgs {
  { count, seed, out_dir }
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
  EmitGenValidBatch(EmitGenValidBatchArgs)
  EmitInvalidRepro(EmitInvalidReproArgs)
} derive(Eq, Debug)

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
  details_json : String?
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
    "wast-roundtrip", "wat-roundtrip", "validate-valid", "validate-invalid-ast",
    "validate-invalid-binary", "validate-invalid-text", "validate-invalid-spec-seed",
    "binary-roundtrip", "cmd-harness",
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
  "usage: moon run src/fuzz -- [suite] [profile] [seed] [--seed <int64>|--seed=<int64>] [--seed-count <n>] [--shard-index <i> --shard-count <n>] [--report-json <path>] [--output text|jsonl|--jsonl]\ncommands: --help|-h | --list-suites | --list-profiles | --emit-gen-valid-batch --count <n> --seed <uint64> --out-dir <dir> (portable coverage-forced batch) | --emit-invalid-repro --suite <suite|ast|binary|text|spec-seed> --strategy <stable-id> --seed <uint64> --attempt <n> --out-dir <dir> [--profile <name>]\nactive suites: \{active_suites}\nreserved suite ids: \{reserved_suites}\nprofiles: \{profiles}"
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
fn fuzz_parse_emit_gen_valid_batch_args(
  args : Array[String],
) -> EmitGenValidBatchArgs {
  let mut count : Int? = None
  let mut seed : UInt64? = None
  let mut out_dir : String? = None
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
  EmitGenValidBatchArgs::new(resolved_count, resolved_seed, resolved_out_dir)
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
pub fn parse_fuzz_cli_args(args : Array[String]) -> FuzzCliArgs {
  let positional : Array[String] = []
  let mut flag_seed : Int64? = None
  let mut output_mode : FuzzOutputMode? = None
  let mut seed_count : Int? = None
  let mut shard_index : Int? = None
  let mut shard_count : Int? = None
  let mut report_json_path : String? = None
  let mut i = 0
  while i < args.length() {
    let arg = args[i].trim().to_owned()
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
  let suite = if positional.length() >= 1 {
    fuzz_ascii_lower(positional[0].trim().to_owned())
  } else {
    "all"
  }
  let profile = if positional.length() >= 2 {
    fuzz_ascii_lower(positional[1].trim().to_owned())
  } else {
    "smoke"
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
    (None, None) => fuzz_generate_seed_i64()
  }
  let seed = seed_i64.reinterpret_as_uint64()
  let out_mode = match output_mode {
    Some(mode) => mode
    None => FuzzOutputMode::Text
  }
  let resolved_seed_count = match seed_count {
    Some(v) => v
    None => 1
  }
  if resolved_seed_count <= 0 {
    abort("seed-count must be greater than zero")
  }
  let resolved_shard_count = match shard_count {
    Some(v) => v
    None => 1
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
        Ok(stats) => (stats.attempts, None)
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
        Ok(stats) => (stats.attempts, None)
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed_i64}: \{e}")
      }
    "validate-valid" =>
      match run_validate_valid_suite_detailed(profile, seed) {
        Ok(v) => v
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
} derive(Eq, Debug)

///|
pub struct GenValidBatchArtifacts {
  artifacts : Array[(String, Bytes)]
  manifest : Array[GenValidBatchManifestEntry]
} derive(Eq, Debug)

///|
pub fn emit_gen_valid_batch_artifacts_with_manifest(
  count : Int,
  seed : UInt64,
) -> Result[GenValidBatchArtifacts, String] {
  if count < 0 {
    return Err("count must be non-negative")
  }
  let rnd = @splitmix.new(seed~)
  let config = emit_gen_valid_batch_config()
  let artifacts : Array[(String, Bytes)] = []
  let manifest : Array[GenValidBatchManifestEntry] = []
  let mut i = 0
  while i < count {
    let generated = match gen_valid_module_result(rnd, config) {
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
  let rnd = @splitmix.new(seed~)
  let config = emit_gen_valid_batch_config()
  let artifacts : Array[(String, Bytes)] = []
  let mut i = 0
  while i < count {
    let mod = gen_valid_module_with_config(rnd, config)
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
fn emit_gen_valid_batch_to_dir(
  args : EmitGenValidBatchArgs,
) -> Result[Int, String] {
  let artifacts = match emit_gen_valid_batch_artifacts(args.count, args.seed) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  for artifact in artifacts {
    let path = fuzz_join_path(args.out_dir, artifact.0)
    match write_file_bytes(path, artifact.1) {
      Ok(_) => ()
      Err(e) => return Err("failed to write gen-valid artifact \{path}: \{e}")
    }
  }
  Ok(args.count)
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
fn format_invalid_ast_details_json(
  stats : ValidateInvalidAstFuzzStats,
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
  out.write_string("{\"strategy_stats\":[")
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
  out.write_string("]}")
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
pub fn format_fuzz_suite_result(
  result : FuzzSuiteResult,
  output_mode : FuzzOutputMode,
) -> String {
  let sweep_suffix = if result.seed_count == 1 && result.shard_count == 1 {
    ""
  } else {
    " seed_index=\{result.seed_index} seed_count=\{result.seed_count} shard_index=\{result.shard_index} shard_count=\{result.shard_count}"
  }
  match output_mode {
    FuzzOutputMode::Text =>
      "suite=\{result.suite} profile=\{result.profile} seed=\{result.seed} attempts=\{result.attempts} pass=true elapsed_ms=\{result.elapsed_ms}\{sweep_suffix}"
    FuzzOutputMode::Jsonl => {
      let details_suffix = match result.details_json {
        Some(details) => ",\"details\":\{details}"
        None => ""
      }
      "{\"suite\":\"\{fuzz_json_escape(result.suite)}\",\"profile\":\"\{fuzz_json_escape(result.profile)}\",\"seed\":\{result.seed},\"attempts\":\{result.attempts},\"pass\":true,\"elapsed_ms\":\{result.elapsed_ms},\"seed_index\":\{result.seed_index},\"seed_count\":\{result.seed_count},\"shard_index\":\{result.shard_index},\"shard_count\":\{result.shard_count}\{details_suffix}}"
    }
  }
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
  out.write_string(
    "{\"suite\":\"\{fuzz_json_escape(suite)}\",\"profile\":\"\{fuzz_json_escape(profile)}\",\"base_seed\":\{base_seed},\"seed_count\":\{seed_count},\"shard_index\":\{shard_index},\"shard_count\":\{shard_count},\"pass\":true,\"run_count\":\{results.length()},\"runs\":[",
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
    FuzzCliCommand::EmitGenValidBatch(args) =>
      match emit_gen_valid_batch_to_dir(args) {
        Ok(count) =>
          println(
            "generated=\{count} seed=\{args.seed} out_dir=\{args.out_dir}",
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
