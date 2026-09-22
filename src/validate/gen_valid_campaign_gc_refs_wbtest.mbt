///|
test "campaign GC reference subtype profile covers valid operators and operands" {
  let profile = gen_valid_profile_by_name("campaign-gc-ref-subtypes").unwrap()
  let config = GenValidConfig::for_profile(profile)
  @debug.assert_eq(gen_valid_profile_name(profile), "campaign-gc-ref-subtypes")
  let seen = Array::make(8, false)
  let mut saw_struct_new = false
  let mut saw_struct_get = false
  let mut saw_struct_set = false
  let mut saw_array_new = false
  let mut saw_array_get = false
  let mut saw_array_set = false
  let mut saw_array_len = false
  let mut saw_ref_test = false
  let mut saw_ref_cast = false
  let mut saw_nullable = false
  let mut saw_nonnullable = false
  let seen_values : Array[@lib.I32] = []
  let mut saw_right_sibling = false
  let mut saw_right_descendant = false
  let mut previous : Module? = None
  for seed = 0UL; seed < 64UL; seed = seed + 1UL {
    let generated = gen_valid_module_from_seed(seed, config).unwrap()
    let mod_ = generated.wasm_module
    match validate_module(mod_) {
      Ok(_) => ()
      Err(error) => fail(validation_error_message(error))
    }
    @debug.assert_eq(generated.config_label, "campaign-gc-ref-subtypes")
    match mod_.type_sec.unwrap().0[3] {
      SingleRecType(SubType(_, [TypeIdx(1U)], _, _)) => saw_right_sibling = true
      SingleRecType(SubType(_, [TypeIdx(2U)], _, _)) =>
        saw_right_descendant = true
      _ => fail("unexpected right subtype parent")
    }
    let Func(_, Expr(body)) = mod_.code_sec.unwrap().0[0]
    let variant = (seed % 8UL).to_int()
    seen[variant] = true
    saw_struct_new = saw_struct_new || body.any(fn(i) { i is StructNew(_) })
    saw_struct_get = saw_struct_get || body.any(fn(i) { i is StructGet(_, _) })
    saw_struct_set = saw_struct_set || body.any(fn(i) { i is StructSet(_, _) })
    saw_array_new = saw_array_new ||
      body.any(fn(i) { i is ArrayNewFixed(_, _) || i is ArrayNewDefault(_) })
    saw_array_get = saw_array_get || body.any(fn(i) { i is ArrayGet(_) })
    saw_array_set = saw_array_set || body.any(fn(i) { i is ArraySet(_) })
    saw_array_len = saw_array_len || body.any(fn(i) { i is ArrayLen })
    saw_ref_test = saw_ref_test || body.any(fn(i) { i is RefTest(_, _, _) })
    saw_ref_cast = saw_ref_cast || body.any(fn(i) { i is RefCast(_, _, _) })
    saw_nullable = saw_nullable || body.any(fn(i) { i is RefNull(_) })
    saw_nonnullable = saw_nonnullable || body.any(fn(i) { i is RefAsNonNull })
    for instr in body {
      if instr is I32Const(value) {
        if !seen_values.contains(value) {
          seen_values.push(value)
        }
      }
    }
    if previous is Some(previous) {
      assert_true(mod_ != previous)
    }
    previous = Some(mod_)
  }
  assert_true(seen.iter().all(fn(value) { value }))
  assert_true(saw_struct_new && saw_struct_get && saw_struct_set)
  assert_true(saw_array_new && saw_array_get && saw_array_set && saw_array_len)
  assert_true(saw_ref_test && saw_ref_cast)
  assert_true(saw_nullable && saw_nonnullable)
  assert_true(seen_values.length() >= 32)
  assert_true(saw_right_sibling && saw_right_descendant)
}
