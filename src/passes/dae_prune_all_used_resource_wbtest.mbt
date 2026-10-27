///|
fn dae_prune_all_used_fixture() -> @lib.Module {
  let text = StringBuilder()
  text.write_string("(module $all_used (type $only (func)) ")
  for index in 0..<128 {
    text.write_string(
      "(func $f\{index} (type $only) f64.const nan:0x123 drop nop) ",
    )
  }
  text.write_string(")")
  pass_test_module_from_wat(text.to_string())
}

///|
fn dae_prune_all_used_assert_identity(
  input : @lib.Module,
  output : @lib.Module,
  bytes : Bytes,
) -> Unit raise {
  @validate.validate_module(input).unwrap()
  @validate.validate_module(output).unwrap()
  assert_true(physical_equal(input, output))
  assert_true(
    physical_equal(input.type_sec.unwrap().0, output.type_sec.unwrap().0),
  )
  assert_true(
    physical_equal(input.code_sec.unwrap().0, output.code_sec.unwrap().0),
  )
  assert_eq(output.type_sec.unwrap().0.length(), 1)
  assert_eq(output.func_sec.unwrap().0.length(), 128)
  assert_eq(output.name_sec, input.name_sec)
  assert_true(output.name_sec is Some(_))
  let before = input.code_sec.unwrap().0
  let after = output.code_sec.unwrap().0
  assert_eq(after.length(), 128)
  for index in 0..<128 {
    assert_eq(output.func_sec.unwrap().0[index], @lib.TypeIdx::new(0U))
    let @lib.Func(bl, @lib.Expr(b)) = before[index]
    let @lib.Func(al, @lib.Expr(a)) = after[index]
    assert_eq(al.runs(), bl.runs())
    assert_true(physical_equal(a, b))
    assert_eq(a.length(), 3)
    match a[0] {
      @lib.F64Const(@lib.F64(value)) =>
        assert_eq(value.reinterpret_as_int64(), 0x7ff0000000000123L)
      _ => fail("expected flat exact NaN")
    }
    assert_true(a[1] is @lib.Drop)
    assert_true(a[2] is @lib.Nop)
  }
  assert_eq(@binary.encode_module(output).unwrap(), bytes)
  assert_eq(@binary.encode_module(input).unwrap(), bytes)
  // No prune returns the original module. All source containers are borrowed;
  // arbitrary mutation of the returned nested bodies is not an ownership API.
}

///|
fn dae_prune_all_used_profile_wrapper(input : @lib.Module) -> @lib.Module raise {
  let output = dae_prune_unused_simple_func_types(input, preserve_names=true)
  assert_true(physical_equal(output, input))
  assert_eq(output.func_sec.unwrap().0.length(), 128)
  output
}

///|
#skip("dedicated ordinary one-call all-used128 work baseline; no clocks")
test "DAE all-used128 normal prune resource after exact behavior" (
  it : @bench.T,
) {
  ignore(it)
  let input = dae_prune_all_used_fixture()
  let source = @binary.encode_module(input).unwrap()
  @validate.validate_module(input).unwrap()
  assert_eq(input.type_sec.unwrap().0.length(), 1)
  assert_eq(input.func_sec.unwrap().0.length(), 128)
  // Exactly one real normal prune. No old reference or extra collector call.
  let output = dae_prune_all_used_profile_wrapper(input)
  dae_prune_all_used_assert_identity(input, output, source)
  it.keep(output)
  println(
    "type-prune-all-used behavior=matched funcs=128 types=1-to-1 signature=matched nan_bits=7ff0000000000123 body_identity=matched source_identity=matched no_prune_borrowing=matched normal_prune_calls=1",
  )
}
