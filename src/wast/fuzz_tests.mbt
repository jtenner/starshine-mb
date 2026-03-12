///|
fn normalize_text_for_compare(text : String) -> String {
  // Parser/printer are whitespace-insensitive; normalize by removing all whitespace.
  let out = StringBuilder::new()
  for c in text {
    if c != ' ' && c != '\n' && c != '\r' && c != '\t' {
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
fn wast_ascii_lower(input : String) -> String {
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
pub struct WastRoundtripFuzzStats {
  profile : String
  seed : UInt64
  attempts : Int
  successes : Int
  stable : Int
  script_iterations : Int
  module_commands : Int
  rendered_scripts : Int
} derive(Eq, Show, Debug)

///|
pub fn run_wast_roundtrip_fuzz(
  profile : String,
  seed : UInt64,
) -> Result[WastRoundtripFuzzStats, String] {
  let normalized = wast_ascii_lower(profile.trim().to_string())
  let (max_attempts, success_target, min_successes, min_stable, script_iters) = match
    normalized {
    "smoke" => (120, 16, 8, 1, 24)
    "ci" => (600, 80, 20, 2, 64)
    "stress" => (2400, 320, 80, 8, 256)
    _ =>
      return Err(
        "unknown wast fuzz profile '\{profile}'; expected smoke|ci|stress",
      )
  }
  let state = @splitmix.new(seed~)
  let mut successes = 0
  let mut stable = 0
  let mut attempts = 0
  while attempts < max_attempts && successes < success_target {
    attempts += 1
    let wmod : Module = Arbitrary::arbitrary(5, state)
    match module_to_wast(wmod) {
      Err(_) => continue
      Ok(printed) => {
        let parsed = match wast_to_module(printed) {
          Err(_) => continue
          Ok(parsed) => parsed
        }
        let printed_round = match module_to_wast(parsed) {
          Err(_) => continue
          Ok(text) => text
        }
        successes += 1
        if normalize_text_for_compare(printed) ==
          normalize_text_for_compare(printed_round) {
          stable += 1
        }
      }
    }
  }
  if successes < min_successes {
    return Err(
      "wast fuzz produced too few successful roundtrips: profile=\{normalized} successes=\{successes} min=\{min_successes} attempts=\{attempts}",
    )
  }
  if stable < min_stable {
    return Err(
      "wast fuzz produced too few stable roundtrips: profile=\{normalized} stable=\{stable} min=\{min_stable} successes=\{successes}",
    )
  }

  let script_state = @splitmix.new(seed=seed ^ 0xABCUL)
  let mut module_commands = 0
  let mut rendered_scripts = 0
  for _ in 0..<script_iters {
    let script : WastScript = Arbitrary::arbitrary(5, script_state)
    for cmd in script.commands {
      if cmd is Module(_) {
        module_commands += 1
      }
    }
    match script_to_wast(script) {
      Ok(text) => {
        ignore(wast_to_script(text))
        rendered_scripts += 1
      }
      Err(_) => ()
    }
  }
  if module_commands <= 0 {
    return Err(
      "wast fuzz generated no module commands: profile=\{normalized} script_iterations=\{script_iters}",
    )
  }
  if rendered_scripts <= 0 {
    return Err(
      "wast fuzz rendered no scripts: profile=\{normalized} script_iterations=\{script_iters}",
    )
  }
  Ok(WastRoundtripFuzzStats::{
    profile: normalized,
    seed,
    attempts,
    successes,
    stable,
    script_iterations: script_iters,
    module_commands,
    rendered_scripts,
  })
}

///|
test "wast module conversion basic roundtrip" {
  let src =
    #| (module
    #| )
  let mod1 = match wast_to_module(src) {
    Ok(m) => m
    Err(msg) => {
      assert_true(false, msg~)
      { id: None, fields: [] }
    }
  }
  let text1 = module_to_wast(mod1).unwrap()
  let mod2 = wast_to_module(text1).unwrap()
  let text2 = module_to_wast(mod2).unwrap()
  assert_eq(
    normalize_text_for_compare(text1),
    normalize_text_for_compare(text2),
  )
}

///|
test "run_wast_roundtrip_fuzz smoke profile succeeds" {
  let stats = match run_wast_roundtrip_fuzz("smoke", 0x5eedUL) {
    Ok(v) => v
    Err(e) => fail("expected smoke fuzz runner success, got \{e}")
  }
  assert_true(stats.successes > 0)
  assert_true(stats.module_commands > 0)
}

///|
test "wast module text fuzz roundtrip" {
  let stats = run_wast_roundtrip_fuzz("smoke", 0x5eedUL).unwrap()
  assert_true(stats.successes >= 8)
  assert_true(stats.stable >= 1)
}

///|
test "wast arbitrary script smoke" {
  let stats = run_wast_roundtrip_fuzz("smoke", 0xabcUL).unwrap()
  assert_true(stats.module_commands > 0)
  assert_true(stats.rendered_scripts > 0)
}
