///|
fn gen_valid_h2l_dedicated_trigger_check(
  profile : GenValidProfile,
  seed : UInt64,
) -> Unit raise {
  let config = GenValidConfig::for_profile(profile)
  let generated = match gen_valid_module_result_from_seed(seed, config) {
    Ok(value) => value
    Err(failure) => fail(failure.validation_error_message)
  }
  @debug.assert_eq(generated.config_label, gen_valid_profile_name(profile))
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(error) => fail(validation_error_message(error))
  }
  let replay = match gen_valid_module_result_from_seed(seed, config) {
    Ok(value) => value
    Err(failure) => fail(failure.validation_error_message)
  }
  @debug.assert_eq(generated.wasm_module, replay.wasm_module)
  @debug.assert_eq(generated.config_label, replay.config_label)
  let has_candidate = match profile {
    Heap2LocalStructProfile =>
      gen_valid_test_module_contains_h2l_struct_candidate(generated.wasm_module)
    Heap2LocalArrayProfile =>
      gen_valid_test_module_contains_h2l_array_candidate(generated.wasm_module)
    Heap2LocalRefProfile =>
      gen_valid_test_module_contains_h2l_ref_candidate(generated.wasm_module)
    _ => fail("expected an exact dedicated Heap struct, array, or ref profile")
  }
  assert_true(
    has_candidate,
    msg="dedicated Heap profile must emit its constructor/accessor IR candidate",
  )
  assert_true(generated.facts.has_gc_constructors)
  assert_true(generated.facts.has_gc_accessors)
}

///|
// Fixed case_seed values come from the heap2local-all batch with root 0x5eed.
// These valid but empty cases exposed type slots consumed by unused function
// signatures. A dedicated profile must emit its stated Heap candidate.
test "heap2local dedicated trigger struct recorded case 27" {
  gen_valid_h2l_dedicated_trigger_check(
    Heap2LocalStructProfile,
    3598005743272457411UL,
  )
}

///|
test "heap2local dedicated trigger array recorded case 17" {
  gen_valid_h2l_dedicated_trigger_check(
    Heap2LocalArrayProfile,
    2276689355537440657UL,
  )
}

///|
test "heap2local dedicated trigger array recorded case 18" {
  gen_valid_h2l_dedicated_trigger_check(
    Heap2LocalArrayProfile,
    9354529152041376654UL,
  )
}

///|
test "heap2local dedicated trigger array recorded case 21" {
  gen_valid_h2l_dedicated_trigger_check(
    Heap2LocalArrayProfile,
    7258542069610106701UL,
  )
}

///|
test "heap2local dedicated trigger ref recorded case 10" {
  gen_valid_h2l_dedicated_trigger_check(
    Heap2LocalRefProfile,
    12690502217235577382UL,
  )
}
