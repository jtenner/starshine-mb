///|
pub struct FuzzCliArgs {
  suite : String
  profile : String
  seed : UInt64
} derive(Eq, Show, Debug)

///|
pub struct FuzzSuiteResult {
  suite : String
  profile : String
  seed : UInt64
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
fn fuzz_parse_seed(raw : String) -> Result[UInt64, String] {
  let text = raw.trim().to_string()
  if text.length() == 0 {
    return Err("seed must not be empty")
  }
  let mut result : UInt64 = 0UL
  let mut i = 0
  let mut base = 10
  if text.length() > 2 && text[0] == '0' && (text[1] == 'x' || text[1] == 'X') {
    base = 16
    i = 2
  }
  let mut saw_digit = false
  while i < text.length() {
    let c = text[i]
    if c == '_' {
      i += 1
      continue
    }
    let digit = if c >= '0' && c <= '9' {
      c.to_int() - 0x30
    } else if base == 16 && c >= 'a' && c <= 'f' {
      c.to_int() - 0x61 + 10
    } else if base == 16 && c >= 'A' && c <= 'F' {
      c.to_int() - 0x41 + 10
    } else {
      return Err("invalid seed '\{raw}'")
    }
    if digit >= base {
      return Err("invalid seed '\{raw}'")
    }
    saw_digit = true
    if base == 16 {
      result = result * 16UL + digit.to_uint64()
    } else {
      result = result * 10UL + digit.to_uint64()
    }
    i += 1
  }
  if !saw_digit {
    return Err("invalid seed '\{raw}'")
  }
  Ok(result)
}

///|
pub fn parse_fuzz_cli_args(args : Array[String]) -> FuzzCliArgs {
  if args.length() > 3 {
    abort("usage: moon run src/fuzz [suite] [profile] [seed]")
  }
  let suite = if args.length() >= 1 {
    fuzz_ascii_lower(args[0].trim().to_string())
  } else {
    "all"
  }
  let profile = if args.length() >= 2 {
    fuzz_ascii_lower(args[1].trim().to_string())
  } else {
    "smoke"
  }
  let seed = if args.length() >= 3 {
    match fuzz_parse_seed(args[2]) {
      Ok(v) => v
      Err(e) => abort(e)
    }
  } else {
    0x5eedUL
  }
  FuzzCliArgs::{ suite, profile, seed }
}

///|
fn run_single_suite(
  suite : String,
  profile : String,
  seed : UInt64,
) -> Result[FuzzSuiteResult, String] {
  let start_ms = trace_now_ms()
  let attempts = match suite {
    "wast-roundtrip" =>
      match run_wast_roundtrip_fuzz(profile, seed) {
        Ok(stats) => stats.attempts
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed}: \{e}")
      }
    "wat-roundtrip" =>
      match run_wat_roundtrip_fuzz(profile, seed) {
        Ok(stats) => stats.attempts
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed}: \{e}")
      }
    "validate-valid" =>
      match run_validate_valid_fuzz(profile, seed) {
        Ok(stats) => stats.attempts
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed}: \{e}")
      }
    "validate-invalid" =>
      match run_validate_invalid_fuzz(profile, seed) {
        Ok(stats) => stats.module_attempts
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed}: \{e}")
      }
    "cmd-harness" =>
      match run_wasm_smith_fuzz_harness_profile(profile, seed) {
        Ok(stats) => stats.attempts
        Err(e) =>
          return Err("suite=\{suite} profile=\{profile} seed=\{seed}: \{e}")
      }
    _ => return Err("unknown suite '\{suite}'")
  }
  Ok(FuzzSuiteResult::{
    suite,
    profile,
    seed,
    attempts,
    elapsed_ms: trace_elapsed_ms(start_ms),
  })
}

///|
pub fn run_fuzz_suite(
  suite : String,
  profile : String,
  seed : UInt64,
) -> Result[Array[FuzzSuiteResult], String] {
  let suite_name = fuzz_ascii_lower(suite.trim().to_string())
  let profile_name = fuzz_ascii_lower(profile.trim().to_string())
  if suite_name == "all" {
    let suites = [
      "wast-roundtrip", "wat-roundtrip", "validate-valid", "validate-invalid", "cmd-harness",
    ]
    let out : Array[FuzzSuiteResult] = []
    for name in suites {
      match run_single_suite(name, profile_name, seed) {
        Ok(result) => out.push(result)
        Err(e) => return Err(e)
      }
    }
    return Ok(out)
  }
  match run_single_suite(suite_name, profile_name, seed) {
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
  match run_fuzz_suite(parsed.suite, parsed.profile, parsed.seed) {
    Ok(results) =>
      for result in results {
        print_fuzz_suite_result(result)
      }
    Err(e) => abort(e)
  }
}
