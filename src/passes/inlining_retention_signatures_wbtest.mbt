///|
test "inlining helper removal skips signatures without a retention quota" {
  let mod_ = pass_test_module_from_wat("(module (func) (func) (func))")
  let counts = [0]
  let removed = inl_remove_dead_inlined_helpers(
    mod_,
    inl_build_function_infos(mod_),
    [true, true, true],
    [true, true, true],
    @hashmap.new(),
    signature_builds=Some(counts),
  )
  assert_eq(removed.mod_out.code_sec.unwrap().0.length(), 0)
  assert_eq(removed.original_abs, [])
  assert_eq(counts[0], 0)
}

///|
test "inlining helper removal shares signature builds and preserves first retained helper" {
  let mod_ = pass_test_module_from_wat(
    "(module (type (func)) (type (func)) (func (type 0)) (func (type 1)) (func (param i32)))",
  )
  let retained : @hashmap.HashMap[String, Int] = @hashmap.new()
  retained.set("p:r:", 1)
  let counts = [0]
  let removed = inl_remove_dead_inlined_helpers(
    mod_,
    inl_build_function_infos(mod_),
    [true, true, true],
    [true, true, true],
    retained,
    signature_builds=Some(counts),
  )
  assert_eq(removed.mod_out.code_sec.unwrap().0.length(), 1)
  assert_eq(removed.original_abs, [0])
  assert_true(counts[0] <= 1, msg="signature builds: \{counts[0]}")
  @validate.validate_module(removed.mod_out).unwrap()
}
