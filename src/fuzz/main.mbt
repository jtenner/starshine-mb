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
pub enum FuzzCliCommand {
  Run(FuzzCliArgs)
  Help
  ListSuites
  ListProfiles
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
fn fuzz_suite_names() -> Array[String] {
  [
    "wast-roundtrip", "wat-roundtrip", "validate-valid", "validate-invalid", "spec-seed",
    "binary-invalid", "text-invalid", "binary-roundtrip", "cmd-harness",
  ]
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
fn fuzz_usage_text() -> String {
  let suites = fuzz_join(fuzz_suite_names(), ", ")
  let profiles = fuzz_join(fuzz_profile_names(), ", ")
  "usage: moon run src/fuzz -- [suite] [profile] [seed] [--seed <int64>|--seed=<int64>] [--output text|jsonl|--jsonl]\ncommands: --help|-h | --list-suites | --list-profiles\nsuites: \{suites}\nprofiles: \{profiles}"
}

fn validate_invalid_fuzz_bytes(text : String) -> Bytes {
  let out = @buffer.new(size_hint=text.length())
  for c in text {
    out.write_byte(c.to_int().to_byte())
  }
  out.to_bytes()
}

fn validate_invalid_fuzz_slug(value : String) -> String {
  let out = StringBuilder::new()
  let mut wrote_dash = false
  for c in value {
    let lower = if c >= 'A' && c <= 'Z' {
      (c.to_int() + 32).unsafe_to_char()
    } else {
      c
    }
    let is_alnum = (lower >= 'a' && lower <= 'z') ||
      (lower >= '0' && lower <= '9') || lower == '_'
    if is_alnum {
      out.write_char(lower)
      wrote_dash = false
    } else if !wrote_dash {
      out.write_char('-')
      wrote_dash = true
    }
  }
  let raw = out.to_string()
  if raw.length() == 0 {
    "unknown"
  } else if raw[0] == '-' {
    raw.sub(start=1).to_string()
  } else {
    raw
  }
}

fn validate_invalid_fuzz_failure_meta(
  suite : String,
  report : ValidateInvalidFuzzFailure,
) -> String {
  let out = StringBuilder::new()
  out.write_string("suite=\{suite}\\n")
  out.write_string("profile=\{report.profile}\\n")
  out.write_string("seed=\{report.seed}\\n")
  out.write_string("module_attempt=\{report.module_attempt}\\n")
  out.write_string("strategy=\{report.strategy}\\n")
  out.write_string("expected_issue=\{report.expected_issue}\\n")
  out.write_string("actual_issue=\{report.actual_issue}\\n")
  out.to_string()
}

fn validate_invalid_fuzz_failure_writer(
  suite : String,
) -> ((ValidateInvalidFuzzFailure) -> Result[Unit, String]) {
  let report_suite = suite
  fn(report) {
    let base_dir = "fuzz-failures"
    match create_dir(base_dir) {
      Ok(_) => ()
      Err(e) => return Err("create_dir(\{base_dir}) failed: \{e}")
    }
    let strategy = validate_invalid_fuzz_slug(report.strategy)
    let prefix = "\{base_dir}/\{report_suite}-seed-\{report.seed}-attempt-\{report.module_attempt}-strategy-\{strategy}"
    let meta_path = "\{prefix}.meta.txt"
    let wat_path = "\{prefix}.wat.txt"
    match write_file_bytes(
      meta_path,
      validate_invalid_fuzz_bytes(
        validate_invalid_fuzz_failure_meta(report_suite, report),
      ),
    ) {
      Ok(_) => ()
      Err(e) => return Err("write_file_bytes(\{meta_path}) failed: \{e}")
    }
    match write_file_bytes(wat_path, validate_invalid_fuzz_bytes(report.module_text)) {
      Ok(_) => Ok(())
      Err(e) => Err("write_file_bytes(\{wat_path}) failed: \{e}")
    }
  }
}

fn run_validate_invalid_suite(
  suite : String,
  profile : String,
  seed : UInt64,
) -> Result[Int, String] {
  match run_validate_invalid_fuzz(
    profile,
    seed,
    Some(validate_invalid_fuzz_failure_writer(suite)),
  ) {
    Ok(stats) => Ok(stats.module_attempts)
    Err(e) => Err(e)
  }
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
      match run_validate_valid_fuzz(profile, seed) {
        Ok(stats) => stats.attempts
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed_i64}: \{e}")
      }
    "validate-invalid" =>
      match run_validate_invalid_suite("validate-invalid", profile, seed) {
        Ok(attempts) => attempts
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed_i64}: \{e}")
      }
    "spec-seed" =>
      match run_validate_invalid_suite("spec-seed", profile, seed) {
        Ok(attempts) => attempts
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed_i64}: \{e}")
      }
    "binary-invalid" =>
      match run_validate_invalid_suite("binary-invalid", profile, seed) {
        Ok(attempts) => attempts
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed_i64}: \{e}")
      }
    "text-invalid" =>
      match run_validate_invalid_suite("text-invalid", profile, seed) {
        Ok(attempts) => attempts
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed_i64}: \{e}")
      }
    "cmd-harness" =>
      match run_wasm_smith_fuzz_harness_profile(profile, seed) {
        Ok(stats) => stats.attempts
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
  })
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
    let suites = fuzz_suite_names()
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
      for suite in fuzz_suite_names() {
        println(suite)
      }
    FuzzCliCommand::ListProfiles =>
      for profile in fuzz_profile_names() {
        println(profile)
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
