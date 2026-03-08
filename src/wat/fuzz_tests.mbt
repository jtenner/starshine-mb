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
test "wast module conversion basic roundtrip" {
  let src =
    #| (module
    #| )
  let mod1 = match wat_to_module(src) {
    Ok(m) => m
    Err(msg) => fail(msg)
  }
  let text1 = module_to_wat(mod1).unwrap()
  let mod2 = wat_to_module(text1).unwrap()
  let text2 = module_to_wat(mod2).unwrap()
  assert_eq(
    normalize_text_for_compare(text1),
    normalize_text_for_compare(text2),
  )
}

///|
test "wast module text fuzz roundtrip" {
  let state = @splitmix.new(seed=0x5eedUL)
  let mut successes = 0
  let mut stable = 0
  let mut attempts = 0
  while attempts < 600 && successes < 80 {
    attempts += 1
    let wmod : Module = Arbitrary::arbitrary(5, state)
    match module_to_wat(wmod) {
      Err(_) => continue
      Ok(printed) => {
        let parsed = match wat_to_module(printed) {
          Err(_) => continue
          Ok(parsed) => parsed
        }
        let printed_round = match module_to_wat(parsed) {
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
  assert_true(successes >= 20)
  assert_true(stable >= 2)
}

///|
test "wast arbitrary script smoke" {
  let state = @splitmix.new(seed=0xabcUL)
  let mut module_commands = 0
  let mut rendered_scripts = 0
  for _ in 0..<64 {
    let script : WastScript = Arbitrary::arbitrary(5, state)
    for cmd in script.commands {
      if cmd is Module(_) {
        module_commands += 1
      }
    }
    match script_to_wat(script) {
      Ok(text) => {
        ignore(wat_to_script(text))
        rendered_scripts += 1
      }
      Err(_) => ()
    }
  }
  assert_true(module_commands > 0)
  assert_true(rendered_scripts > 0)
}
