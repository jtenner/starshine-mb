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

///|
test "inlining retention formats only eligible candidate signatures" {
  let count = 64
  let mod_ = inl_sparse_retention_fixture(count)
  let candidates = Array::make(count, false)
  candidates[0] = true
  candidates[count - 1] = true
  let retained : @hashmap.HashMap[String, Int] = @hashmap.new()
  retained.set("p:r:", 1)
  let formatted = [0]
  let removed = inl_remove_dead_inlined_helpers(
    mod_,
    inl_build_function_infos(mod_),
    candidates,
    candidates,
    retained,
    formatted_signatures=Some(formatted),
  )
  assert_eq(removed.original_abs, Array::makei(count - 1, fn(i) { i }))
  assert_eq(removed.mod_out.code_sec.unwrap().0.length(), count - 1)
  @validate.validate_module(removed.mod_out).unwrap()
  assert_true(formatted[0] <= 2, msg="formatted signatures: \{formatted[0]}")
}

///|
fn inl_sparse_retention_fixture(count : Int) -> @lib.Module {
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new(
      Array::makei(count, fn(_) {
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], [])))
      }),
    ),
  )
  .with_func_sec(
    @lib.FuncSec::new(
      Array::makei(count, fn(i) { @lib.TypeIdx::new(i.reinterpret_as_uint()) }),
    ),
  )
  .with_code_sec(
    @lib.CodeSec::new(
      Array::makei(count, fn(_) {
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
      }),
    ),
  )
}
