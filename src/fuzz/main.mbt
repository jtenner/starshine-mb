///|
pub enum FuzzOutputMode {
  Text
  Jsonl
} derive(Eq, Show, Debug)

///|
pub struct FuzzCliArgs {
  suite : String
  profile : String
  seed : UInt64
  seed_i64 : Int64
  output_mode : FuzzOutputMode
} derive(Eq, Show, Debug)

///|
pub struct EmitGenValidBatchArgs {
  count : Int
  seed : UInt64
  out_dir : String
} derive(Eq, Show, Debug)

///|
pub fn EmitGenValidBatchArgs::new(
  count : Int,
  seed : UInt64,
  out_dir : String,
) -> EmitGenValidBatchArgs {
  { count, seed, out_dir }
}

///|
pub enum FuzzCliCommand {
  Run(FuzzCliArgs)
  Help
  ListSuites
  ListProfiles
  EmitGenValidBatch(EmitGenValidBatchArgs)
} derive(Eq, Show, Debug)

///|
pub struct FuzzSuiteResult {
  suite : String
  profile : String
  seed : Int64
  attempts : Int
  elapsed_ms : UInt64
} derive(Eq, Show, Debug)

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
    "binary-roundtrip", "cmd-harness",
  ]
}

///|
pub fn fuzz_reserved_suite_names() -> Array[String] {
  [
    "validate-invalid-binary", "validate-invalid-text", "validate-invalid-spec-seed",
  ]
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
  let reserved_suites = fuzz_join(fuzz_reserved_suite_names(), ", ")
  let profiles = fuzz_join(fuzz_profile_names(), ", ")
  "usage: moon run src/fuzz -- [suite] [profile] [seed] [--seed <int64>|--seed=<int64>] [--output text|jsonl|--jsonl]\ncommands: --help|-h | --list-suites | --list-profiles | --emit-gen-valid-batch --count <n> --seed <uint64> --out-dir <dir> (coverage-forced batch)\nactive suites: \{active_suites}\nreserved suite ids: \{reserved_suites}\nprofiles: \{profiles}"
}

///|
fn run_validate_valid_suite(
  profile : String,
  seed : UInt64,
) -> Result[Int, String] {
  let normalized = fuzz_ascii_lower(profile.trim().to_string())
  let (_, min_text_attempts, min_text_stable) = match normalized {
    "smoke" => (128, 0, 0)
    "ci" => (5000, 20, 2)
    "stress" => (100000, 80, 8)
    _ =>
      return Err(
        "unknown validate-valid fuzz profile '\{profile}'; expected smoke|ci|stress",
      )
  }

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
  Ok(attempts)
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
  let text = raw.trim().to_string()
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
  let normalized = fuzz_ascii_lower(raw.trim().to_string())
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
  let text = raw.trim().to_string()
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
    let arg = args[i].trim().to_string()
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
      if v.trim().to_string().length() == 0 {
        abort("--out-dir must not be empty")
      } else {
        v
      }
    None => abort("missing required --out-dir for --emit-gen-valid-batch")
  }
  EmitGenValidBatchArgs::new(resolved_count, resolved_seed, resolved_out_dir)
}

///|
fn fuzz_parse_control_command(arg : String) -> FuzzCliCommand? {
  let normalized = fuzz_ascii_lower(arg.trim().to_string())
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
  if args.length() > 0 &&
    fuzz_ascii_lower(args[0].trim().to_string()) == "--emit-gen-valid-batch" {
    return FuzzCliCommand::EmitGenValidBatch(
      fuzz_parse_emit_gen_valid_batch_args(args),
    )
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
  let mut i = 0
  while i < args.length() {
    let arg = args[i].trim().to_string()
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
    fuzz_ascii_lower(positional[0].trim().to_string())
  } else {
    "all"
  }
  let profile = if positional.length() >= 2 {
    fuzz_ascii_lower(positional[1].trim().to_string())
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
  FuzzCliArgs::{ suite, profile, seed, seed_i64, output_mode: out_mode }
}

///|
fn run_single_suite(
  suite : String,
  profile : String,
  seed_i64 : Int64,
) -> Result[FuzzSuiteResult, String] {
  let seed = seed_i64.reinterpret_as_uint64()
  let start_ms = trace_now_ms()
  let attempts = match suite {
    "binary-roundtrip" =>
      match run_binary_roundtrip_fuzz(profile, seed) {
        Ok(stats) => stats.attempts
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed_i64}: \{e}")
      }
    "wast-roundtrip" =>
      match run_wast_roundtrip_fuzz(profile, seed) {
        Ok(stats) => stats.attempts
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed_i64}: \{e}")
      }
    "wat-roundtrip" =>
      match run_wat_roundtrip_fuzz(profile, seed) {
        Ok(stats) => stats.attempts
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed_i64}: \{e}")
      }
    "validate-valid" =>
      match run_validate_valid_suite(profile, seed) {
        Ok(attempts) => attempts
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed_i64}: \{e}")
      }
    "validate-invalid-ast" =>
      match run_validate_invalid_ast_fuzz(profile, seed) {
        Ok(stats) => stats.attempts
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed_i64}: \{e}")
      }
    "cmd-harness" =>
      match run_cmd_fuzz_harness_profile(profile, seed) {
        Ok(stats) => stats.attempts
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed_i64}: \{e}")
      }
    "validate-invalid-binary"
    | "validate-invalid-text"
    | "validate-invalid-spec-seed" =>
      return Err(
        "suite '\{suite}' is reserved for a planned validator rejection lane and is not implemented yet",
      )
    _ => return Err("unknown suite '\{suite}'")
  }
  Ok(FuzzSuiteResult::{
    suite,
    profile,
    seed: seed_i64,
    attempts,
    elapsed_ms: trace_elapsed_ms(start_ms),
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
pub fn emit_gen_valid_batch_artifacts(
  count : Int,
  seed : UInt64,
) -> Result[Array[(String, Bytes)], String] {
  if count < 0 {
    return Err("count must be non-negative")
  }
  let rnd = @splitmix.new(seed~)
  let artifacts : Array[(String, Bytes)] = []
  let mut i = 0
  while i < count {
    let mod = gen_valid_module_with_config(
      rnd,
      GenValidConfig::coverage_forced_default(),
    )
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
pub fn run_fuzz_suite(
  suite : String,
  profile : String,
  seed_i64 : Int64,
) -> Result[Array[FuzzSuiteResult], String] {
  let suite_name = fuzz_ascii_lower(suite.trim().to_string())
  let profile_name = fuzz_ascii_lower(profile.trim().to_string())
  if suite_name == "all" {
    let suites = fuzz_active_suite_names()
    let out : Array[FuzzSuiteResult] = []
    for name in suites {
      match run_single_suite(name, profile_name, seed_i64) {
        Ok(result) => out.push(result)
        Err(e) => return Err(e)
      }
    }
    return Ok(out)
  }
  match run_single_suite(suite_name, profile_name, seed_i64) {
    Ok(result) => Ok([result])
    Err(e) => Err(e)
  }
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
  match output_mode {
    FuzzOutputMode::Text =>
      "suite=\{result.suite} profile=\{result.profile} seed=\{result.seed} attempts=\{result.attempts} pass=true elapsed_ms=\{result.elapsed_ms}"
    FuzzOutputMode::Jsonl =>
      "{\"suite\":\"\{fuzz_json_escape(result.suite)}\",\"profile\":\"\{fuzz_json_escape(result.profile)}\",\"seed\":\{result.seed},\"attempts\":\{result.attempts},\"pass\":true,\"elapsed_ms\":\{result.elapsed_ms}}"
  }
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
    FuzzCliCommand::Run(parsed) => {
      let output_mode = parsed.output_mode
      match run_fuzz_suite(parsed.suite, parsed.profile, parsed.seed_i64) {
        Ok(results) =>
          for result in results {
            print_fuzz_suite_result(result, output_mode)
          }
        Err(e) => abort(e)
      }
    }
  }
}
