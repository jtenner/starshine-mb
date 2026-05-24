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
  generation_mode : String
  valid_lowered_modules : Int
  static_assertions : Int
  feature_stats : WastArbitraryFeatureStats
} derive(Eq, Debug)

///|
fn wast_roundtrip_parse_profile(
  profile : String,
) -> Result[(String, String, Int, Int, Int, Int, Int), String] {
  let parts : Array[String] = []
  for raw_part in profile.trim().to_owned().split("+") {
    let part = wast_ascii_lower(raw_part.trim().to_owned())
    if part.length() > 0 {
      parts.push(part)
    }
  }
  let base = if parts.length() == 0 { "smoke" } else { parts[0] }
  let (max_attempts, success_target, min_successes, min_stable, script_iters) = match
    base {
    "smoke" => (120, 16, 8, 1, 24)
    "ci" => (600, 80, 20, 2, 64)
    "stress" => (2400, 320, 80, 8, 256)
    _ =>
      return Err(
        "unknown wast fuzz profile '\{profile}'; expected smoke|ci|stress with optional +parser-stress|+valid-only|+static-assertions|+scripts|+module-only",
      )
  }
  let mode = if parts.length() > 1 { parts[1] } else { "parser-stress" }
  match mode {
    "parser-stress"
    | "valid-only"
    | "static-assertions"
    | "scripts"
    | "module-only" =>
      Ok(
        (
          base, mode, max_attempts, success_target, min_successes, min_stable, script_iters,
        ),
      )
    _ =>
      Err(
        "unknown WAST generation mode '\{mode}'; expected parser-stress|valid-only|static-assertions|scripts|module-only",
      )
  }
}

///|
fn wast_roundtrip_valid_only_module(st : RandomState) -> Module {
  Module::{
    id: None,
    fields: [
      FuncField({
        id: Some("$valid0"),
        annotations: [],
        exports: [Export("valid0")],
        type_use: {
          type_index: None,
          func_type: { params: [], results: [I32] },
          param_ids: [],
        },
        locals: [],
        body: [Const(I32Const, "\{st.next_uint() % 1024}")],
      }),
    ],
  }
}

///|
fn wast_roundtrip_static_assertion_script(st : RandomState) -> WastScript {
  let import_idx = st.next_uint() % 32
  {
    commands: [
      AssertUnlinkable(
        Inline(Module::{
          id: None,
          fields: [
            ImportField({
              module_name: "env",
              field_name: "missing\{import_idx}",
              desc: ImportDesc::Func({
                type_index: None,
                func_type: { params: [], results: [] },
                param_ids: [],
              }),
              id: Some("$imp"),
              annotations: [],
            }),
          ],
        }),
        "missing import",
      ),
    ],
  }
}

///|
fn wast_roundtrip_count_static_assertions(script : WastScript) -> Int {
  let mut count = 0
  for cmd in script.commands {
    match cmd {
      AssertMalformed(_, _) | AssertInvalid(_, _) | AssertUnlinkable(_, _) =>
        count += 1
      _ => ()
    }
  }
  count
}

///|
pub fn run_wast_roundtrip_fuzz(
  profile : String,
  seed : UInt64,
) -> Result[WastRoundtripFuzzStats, String] {
  let (
    normalized,
    generation_mode,
    max_attempts,
    success_target,
    min_successes,
    min_stable,
    script_iters,
  ) = match wast_roundtrip_parse_profile(profile) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let state = @splitmix.new(seed~)
  let mut successes = 0
  let mut stable = 0
  let mut attempts = 0
  let mut valid_lowered_modules = 0
  let mut feature_stats = wast_arbitrary_empty_feature_stats()
  while attempts < max_attempts && successes < success_target {
    attempts += 1
    let wmod : Module = if generation_mode == "valid-only" {
      wast_roundtrip_valid_only_module(state)
    } else {
      Arbitrary::arbitrary(5, state)
    }
    let wmod_feature_stats = wast_arbitrary_feature_stats(wmod)
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
        if generation_mode == "valid-only" {
          let lowered = match wast_to_binary_module(printed) {
            Err(_) => continue
            Ok(v) => v
          }
          match @validate.validate_module(lowered) {
            Err(_) => continue
            Ok(_) => valid_lowered_modules += 1
          }
        }
        successes += 1
        feature_stats = wast_arbitrary_add_feature_stats(
          feature_stats, wmod_feature_stats,
        )
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
  let actual_script_iters = if generation_mode == "module-only" {
    0
  } else {
    script_iters
  }
  let mut module_commands = 0
  let mut rendered_scripts = 0
  let mut static_assertions = 0
  for _ in 0..<actual_script_iters {
    let script : WastScript = if generation_mode == "static-assertions" {
      wast_roundtrip_static_assertion_script(script_state)
    } else {
      Arbitrary::arbitrary(5, script_state)
    }
    for cmd in script.commands {
      if cmd is Module(_) {
        module_commands += 1
      }
    }
    static_assertions += wast_roundtrip_count_static_assertions(script)
    match script_to_wast(script) {
      Ok(text) => {
        ignore(wast_to_script(text))
        rendered_scripts += 1
      }
      Err(_) => ()
    }
  }
  if generation_mode != "module-only" {
    if generation_mode == "scripts" && module_commands <= 0 {
      return Err(
        "wast fuzz generated no module commands: profile=\{normalized} mode=\{generation_mode} script_iterations=\{actual_script_iters}",
      )
    }
    if rendered_scripts <= 0 {
      return Err(
        "wast fuzz rendered no scripts: profile=\{normalized} mode=\{generation_mode} script_iterations=\{actual_script_iters}",
      )
    }
  }
  Ok(WastRoundtripFuzzStats::{
    profile: normalized,
    seed,
    attempts,
    successes,
    stable,
    script_iterations: actual_script_iters,
    module_commands,
    rendered_scripts,
    generation_mode,
    valid_lowered_modules,
    static_assertions,
    feature_stats,
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
  @debug.assert_eq(
    normalize_text_for_compare(text1),
    normalize_text_for_compare(text2),
  )
}

///|
test "run_wast_roundtrip_fuzz reports WAST arbitrary FZG mirror counters" {
  match run_wast_roundtrip_fuzz("smoke", 0x5eedUL) {
    Ok(stats) => {
      @debug.assert_eq(stats.successes, 16)
      @debug.assert_eq(stats.feature_stats.gc_type_fields, 16)
      @debug.assert_eq(stats.feature_stats.exported_tags, 16)
      @debug.assert_eq(stats.feature_stats.descriptor_ref_ops, 32)
      @debug.assert_eq(stats.feature_stats.bulk_memory_ops, 64)
      @debug.assert_eq(stats.feature_stats.bulk_table_ops, 64)
      @debug.assert_eq(stats.feature_stats.tail_call_ops, 48)
      @debug.assert_eq(stats.feature_stats.exception_ops, 32)
      @debug.assert_eq(stats.feature_stats.simd_const_ops, 16)
      assert_true(
        stats.feature_stats.control_ops >
        stats.feature_stats.tail_call_ops + stats.feature_stats.exception_ops,
        msg="random WAST bodies should add control-family opcode coverage beyond the widened prelude",
      )
      assert_true(
        stats.feature_stats.numeric_ops > stats.feature_stats.simd_const_ops,
        msg="random WAST bodies should add numeric opcode coverage beyond the widened prelude",
      )
      assert_true(
        stats.feature_stats.memory_ops > stats.feature_stats.bulk_memory_ops,
        msg="random WAST bodies should add memory opcode coverage beyond the widened prelude",
      )
      assert_true(
        stats.feature_stats.table_ops > stats.feature_stats.bulk_table_ops,
        msg="random WAST bodies should add table opcode coverage beyond the widened prelude",
      )
      assert_true(
        stats.feature_stats.reference_ops >
        stats.feature_stats.descriptor_ref_ops,
        msg="random WAST bodies should add reference opcode coverage beyond the widened prelude",
      )
    }
    Err(msg) => fail("expected smoke WAST roundtrip success: \{msg}")
  }
}

///|
test "run_wast_roundtrip_fuzz supports WAST generation modes" {
  match run_wast_roundtrip_fuzz("smoke+valid-only", 0x5eedUL) {
    Ok(stats) => {
      @debug.assert_eq(stats.profile, "smoke")
      @debug.assert_eq(stats.generation_mode, "valid-only")
      @debug.assert_eq(stats.successes, 16)
      @debug.assert_eq(stats.valid_lowered_modules, stats.successes)
    }
    Err(msg) => fail("expected valid-only WAST mode success: \{msg}")
  }
  match run_wast_roundtrip_fuzz("smoke+module-only", 0x5eedUL) {
    Ok(stats) => {
      @debug.assert_eq(stats.generation_mode, "module-only")
      @debug.assert_eq(stats.script_iterations, 0)
      @debug.assert_eq(stats.module_commands, 0)
      @debug.assert_eq(stats.rendered_scripts, 0)
      @debug.assert_eq(stats.successes, 16)
    }
    Err(msg) => fail("expected module-only WAST mode success: \{msg}")
  }
  match run_wast_roundtrip_fuzz("smoke+static-assertions", 0x5eedUL) {
    Ok(stats) => {
      @debug.assert_eq(stats.generation_mode, "static-assertions")
      assert_true(stats.static_assertions > 0)
      assert_true(stats.rendered_scripts > 0)
    }
    Err(msg) => fail("expected static-assertions WAST mode success: \{msg}")
  }
  match run_wast_roundtrip_fuzz("smoke+scripts", 0x5eedUL) {
    Ok(stats) => {
      @debug.assert_eq(stats.generation_mode, "scripts")
      assert_true(stats.module_commands > 0)
      assert_true(stats.rendered_scripts > 0)
    }
    Err(msg) => fail("expected scripts WAST mode success: \{msg}")
  }
}

///|
test "run_wast_roundtrip_fuzz rejects unknown profile" {
  match run_wast_roundtrip_fuzz("not-a-profile", 0x5eedUL) {
    Ok(_) => fail("expected unknown profile error")
    Err(msg) => assert_true(msg.contains("unknown wast fuzz profile"))
  }
  match run_wast_roundtrip_fuzz("smoke+not-a-mode", 0x5eedUL) {
    Ok(_) => fail("expected unknown WAST generation mode error")
    Err(msg) => assert_true(msg.contains("unknown WAST generation mode"))
  }
}
