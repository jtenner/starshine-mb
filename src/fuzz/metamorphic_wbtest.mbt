///|
fn assert_metamorphic_roundtrip_valid(
  mod : @lib.Module,
) -> Result[Unit, String] {
  match validate_module(mod) {
    Ok(_) => ()
    Err(err) => return Err(validation_error_message(err))
  }
  let encoded = match encode_module(mod) {
    Ok(bytes) => bytes
    Err(msg) => return Err("encode failed: \{msg}")
  }
  let decoded = match decode_module(encoded) {
    Ok(mod) => mod
    Err(msg) => return Err("decode failed: \{msg}")
  }
  match validate_module(decoded) {
    Ok(_) => Ok(())
    Err(err) =>
      Err(
        "decoded transformed module invalid: \{validation_error_message(err)}",
      )
  }
}

///|
test "metamorphic add-custom transform preserves validation and binary roundtrip" {
  let generated = match
    gen_valid_module_result_from_seed(
      0x1036UL,
      GenValidConfig::natural_default(),
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected valid GenValid seed, got \{e.validation_error_message}")
  }
  let transformed = match
    metamorphic_apply_transform(generated.wasm_module, AddNonNameCustomSection) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "add-non-name-custom-section")
  @debug.assert_eq(
    transformed.wasm_module.custom_secs.length(),
    generated.wasm_module.custom_secs.length() + 1,
  )
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic leading custom-section transform preserves validation and binary roundtrip" {
  let generated = match
    gen_valid_module_result_from_seed(
      0x1038UL,
      GenValidConfig::natural_default(),
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected valid GenValid seed, got \{e.validation_error_message}")
  }
  let transformed = match
    metamorphic_apply_transform(
      generated.wasm_module,
      AddLeadingNonNameCustomSection,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-non-name-custom-section",
  )
  @debug.assert_eq(
    transformed.wasm_module.custom_secs.length(),
    generated.wasm_module.custom_secs.length() + 1,
  )
  match transformed.wasm_module.custom_secs[0] {
    @lib.CustomSec(name, _) =>
      @debug.assert_eq(
        name,
        @lib.Name::from_string(
          "starshine.metamorphic.add-leading-non-name-custom-section",
        ),
      )
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic module-name transform preserves validation and binary roundtrip" {
  let generated = match
    gen_valid_module_result_from_seed(
      0x1037UL,
      GenValidConfig::natural_default(),
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected valid GenValid seed, got \{e.validation_error_message}")
  }
  let transformed = match
    metamorphic_apply_transform(generated.wasm_module, AddModuleNameSection) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "add-module-name-section")
  match transformed.wasm_module.name_sec {
    Some(name_sec) =>
      match name_sec.module_name {
        Some(name) =>
          @debug.assert_eq(
            name,
            @lib.Name::from_string("starshine.metamorphic.module"),
          )
        None => fail("expected transformed module name")
      }
    None => fail("expected transformed name section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic smoke applies deterministic transform to GenValid source" {
  let stats = match run_validate_valid_metamorphic_fuzz("smoke", 0x1036UL) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(stats.profile, "smoke")
  @debug.assert_eq(stats.generated, 1)
  @debug.assert_eq(stats.transformed, 3)
  @debug.assert_eq(stats.validated, 3)
  assert_true(stats.transform_ids.contains("add-non-name-custom-section"))
  assert_true(
    stats.transform_ids.contains("add-leading-non-name-custom-section"),
  )
  assert_true(stats.transform_ids.contains("add-module-name-section"))
}
