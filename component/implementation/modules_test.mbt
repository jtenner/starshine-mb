///|
fn component_test_minimal_wasm() -> FixedArray[Byte] {
  FixedArray::from_array([
    b'\x00',
    b'a',
    b's',
    b'm',
    b'\x01',
    b'\x00',
    b'\x00',
    b'\x00',
  ])
}

///|
test "component validates and roundtrips a minimal module" {
  let input = component_test_minimal_wasm()
  match validate_wasm(input) {
    Ok(_) => ()
    Err(err) => fail("unexpected validation failure: \{err.message}")
  }
  match roundtrip_wasm(input) {
    Ok(output) => {
      if output.length() != input.length() {
        fail("unexpected roundtrip length: \{output.length()}")
      }
      for index = 0; index < input.length(); index = index + 1 {
        if output[index] != input[index] {
          fail("roundtrip byte mismatch at \{index}")
        }
      }
    }
    Err(err) => fail("unexpected roundtrip failure: \{err.message}")
  }
}

///|
test "component parses WAT and rejects malformed wasm with staged diagnostics" {
  match wat_to_wasm("(module (func (export \"run\")))") {
    Ok(output) => {
      if output.length() < 8 ||
        output[0] != b'\x00' ||
        output[1] != b'a' ||
        output[2] != b's' ||
        output[3] != b'm' {
        fail("WAT conversion did not emit a wasm module")
      }
    }
    Err(err) => fail("unexpected WAT conversion failure: \{err.message}")
  }

  match validate_wasm(FixedArray::from_array([b'\xff'])) {
    Err(err) =>
      if err.stage != DECODE {
        fail("expected decode diagnostic")
      }
    Ok(_) => fail("expected malformed wasm to fail decoding")
  }
}

///|
test "component exposes deterministic valid module generation" {
  if !available_generator_profiles().contains("natural-small") {
    fail("expected natural-small generator profile")
  }
  let options : GenerationOptions = {
    seed: 0x5eedUL,
    profile: "natural-small",
  }
  let first = match generate_valid_wasm(options) {
    Ok(generated) => generated
    Err(err) => fail("unexpected generation failure: \{err.message}")
  }
  let second = match generate_valid_wasm(options) {
    Ok(generated) => generated
    Err(err) => fail("unexpected repeat generation failure: \{err.message}")
  }
  if first.profile != "natural-small" || first.attempts == 0U {
    fail("unexpected generation metadata")
  }
  if first.wasm != second.wasm {
    fail("same profile and seed must produce identical wasm")
  }
  match validate_wasm(first.wasm) {
    Ok(_) => ()
    Err(err) => fail("generated module did not validate: \{err.message}")
  }

  match
    generate_valid_wasm({ seed: 1UL, profile: "not-a-generator-profile" }) {
    Err(err) =>
      if err.stage != GENERATE {
        fail("expected generate diagnostic")
      }
    Ok(_) => fail("expected unknown generator profile to fail")
  }
}

///|
test "component lists every runnable optimizer pass category" {
  let mut saw_function_pass = false
  let mut saw_module_pass = false
  let mut saw_preset = false
  for info in available_passes() {
    if info.name == "vacuum" && info.kind == FUNCTION_PASS {
      saw_function_pass = true
    }
    if info.name == "local-cse" && info.kind == MODULE_PASS {
      saw_module_pass = true
    }
    if info.name == "optimize" && info.kind == PRESET {
      saw_preset = true
    }
    if info.name == "const-hoisting" {
      fail("removed passes must not be advertised")
    }
  }
  if !saw_function_pass || !saw_module_pass || !saw_preset {
    fail("expected function, module, and preset entries")
  }
}

///|
test "component runs an explicit no-op optimizer pipeline" {
  let options : OptimizeOptions = {
    preset: NONE,
    additional_passes: [],
    closed_world: false,
    traps_never_happen: false,
    ignore_implicit_traps: false,
    zero_filled_memory: false,
    optimize_level: b'\x00',
    shrink_level: b'\x00',
  }
  match optimize_wasm(component_test_minimal_wasm(), options) {
    Ok(output) =>
      if output.length() != 8 {
        fail("unexpected optimized output length: \{output.length()}")
      }
    Err(err) => fail("unexpected optimize failure: \{err.message}")
  }
}
