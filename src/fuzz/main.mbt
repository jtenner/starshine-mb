///|
pub struct FuzzCliArgs {
  suite : String
  profile : String
  seed : UInt64
  seed_i64 : Int64
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
pub fn parse_fuzz_cli_args(args : Array[String]) -> FuzzCliArgs {
  let positional : Array[String] = []
  let mut flag_seed : Int64? = None
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
    if arg.length() >= 2 && arg[0] == '-' && arg[1] == '-' {
      abort("unknown flag '\{arg}'")
    }
    positional.push(arg)
    i += 1
  }
  if positional.length() > 3 {
    abort(
      "usage: moon run src/fuzz -- [suite] [profile] [seed] [--seed <int64>|--seed=<int64>]",
    )
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
  FuzzCliArgs::{ suite, profile, seed, seed_i64 }
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
      match run_validate_invalid_fuzz(profile, seed) {
        Ok(stats) => stats.module_attempts
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
    let suites = [
      "wast-roundtrip", "wat-roundtrip", "validate-valid", "validate-invalid", "binary-roundtrip",
      "cmd-harness",
    ]
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
fn print_fuzz_suite_result(result : FuzzSuiteResult) -> Unit {
  println(
    "suite=\{result.suite} profile=\{result.profile} seed=\{result.seed} attempts=\{result.attempts} pass=true elapsed_ms=\{result.elapsed_ms}",
  )
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
  let parsed = parse_fuzz_cli_args(fuzz_trim_program_name(@env.args()))
  match run_fuzz_suite(parsed.suite, parsed.profile, parsed.seed_i64) {
    Ok(results) =>
      for result in results {
        print_fuzz_suite_result(result)
      }
    Err(e) => abort(e)
  }
}
