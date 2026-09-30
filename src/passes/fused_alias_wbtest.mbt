///|
test "DAE2 alias discovery borrows original storage before one final remap" {
  for ty in ["i32", "i64", "externref"] {
    for
      body in [
        "call $produce local.set 1 local.get 1 call $consume local.get 1 local.set 0 local.get 0 call $consume local.get 0 call $consume",
        "local.get 0 call $consume call $produce local.set 1 local.get 1 call $consume local.get 1 local.set 0 local.get 0 call $consume local.get 0 call $consume",
        "call $produce local.set 0 local.get 0 call $consume local.get 0 local.set 1 local.get 1 call $consume local.get 1 call $consume",
      ] {
      let input = local_alias_fixture(body, ty)
      let saved = @binary.encode_module(input).unwrap()
      let @lib.Func(_, @lib.Expr(original)) = input.code_sec.unwrap().0[0]
      let reads = [0, 0]
      let writes = [0, 0]
      pass_lower_count_locals(original, reads, writes)
      let discovered = dae2_cleanup_parameter_aliases(
        original, 0, reads, writes,
      )
      assert_true(physical_equal(discovered.0, original))
      assert_true(discovered.1 is Some(_))
      let seed = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
      let actual = pass_lower_compact_captures_with_map(
        input.code_sec.unwrap().0[0],
        seed,
        [],
        propagate_parameter_aliases=true,
      )
      let expected = fused_alias_reference_compact(
        input.code_sec.unwrap().0[0],
        seed,
        [],
        propagate_parameter_aliases=true,
      )
      assert_eq(actual, expected)
      @validate.validate_module(
        input.with_code_sec(@lib.CodeSec::new([actual.0])),
      ).unwrap()
      assert_eq(@binary.encode_module(input).unwrap(), saved)
    }
  }
}

///|
test "DAE2 alias discovery borrows nested controls and isolates replay siblings" {
  for
    body in [
      "call $produce local.set 1 local.get 1 call $consume i32.const 1 if local.get 1 local.set 0 local.get 0 call $consume local.get 0 call $consume else local.get 0 call $consume end local.get 0 call $consume",
      "call $produce local.set 1 local.get 1 call $consume (try (do (local.get 1) (local.set 0) (local.get 0) (call $consume) (local.get 0) (call $consume)) (catch_all (local.get 0) (call $consume))) local.get 0 call $consume",
      "loop call $produce local.set 1 local.get 1 call $consume block local.get 1 local.set 0 local.get 0 call $consume local.get 0 call $consume end local.get 0 call $consume i32.const 0 br_if 0 end",
    ] {
    let input = local_alias_fixture(body, "i32")
    let @lib.Func(_, @lib.Expr(original)) = input.code_sec.unwrap().0[0]
    let reads = [0, 0]
    let writes = [0, 0]
    pass_lower_count_locals(original, reads, writes)
    let discovered = dae2_cleanup_parameter_aliases(original, 0, reads, writes)
    assert_true(physical_equal(discovered.0, original))
    for index in 0..<original.length() {
      assert_true(physical_equal(discovered.0[index], original[index]))
    }
    let seed = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
    let actual = pass_lower_compact_captures_with_map(
      input.code_sec.unwrap().0[0],
      seed,
      [],
      propagate_parameter_aliases=true,
    )
    let expected = fused_alias_reference_compact(
      input.code_sec.unwrap().0[0],
      seed,
      [],
      propagate_parameter_aliases=true,
    )
    assert_eq(actual, expected)
    @validate.validate_module(
      input.with_code_sec(@lib.CodeSec::new([actual.0])),
    ).unwrap()
  }
}

///|
test "DAE2 alias discovery avoids materialization for intentionally unestablished sources" {
  let input = local_alias_fixture(
    "block local.get 1 local.set 0 call $produce local.set 1 local.get 1 call $consume local.get 0 call $consume local.get 0 call $consume end",
    "i32",
  )
  let @lib.Func(_, @lib.Expr(original)) = input.code_sec.unwrap().0[0]
  let reads = [0, 0]
  let writes = [0, 0]
  pass_lower_count_locals(original, reads, writes)
  let discovered = dae2_cleanup_parameter_aliases(original, 0, reads, writes)
  assert_eq(discovered.0, original)
  assert_true(physical_equal(discovered.0, original))
  assert_true(discovered.1 is None)
  let (actual, _) = reverse_alias_compact(input)
  assert_eq(actual, input.code_sec.unwrap().0[0])
}
