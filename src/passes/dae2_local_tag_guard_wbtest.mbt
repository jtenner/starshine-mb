///|
test "DAE2 no local tag admission preserves imported tags and empty tag sections" {
  for
    source in [
      "(module (func (param i32) local.get 0 drop))", "(module (import \"env\" \"t\" (tag $t)) (func block $out try_table (catch_all $out) throw $t end end))",
    ] {
    for empty_section in [false, true] {
      let input = pass_test_module_from_wat(source)
      let input = if empty_section {
        input.with_tag_sec(@lib.TagSec::new([]))
      } else {
        input
      }
      let saved = @binary.encode_module(input).unwrap()
      let expected = dae2_fold_known_local_throws_reference(input)
      let setups = [0]
      let output = dae2_fold_known_local_throws(
        input,
        setup_builds=Some(setups),
      )
      assert_eq(output, expected)
      assert_true(physical_equal(output, input))
      @validate.validate_module(output).unwrap()
      assert_eq(@binary.encode_module(output).unwrap(), saved)
      assert_eq(@binary.encode_module(input).unwrap(), saved)
      assert_eq(setups, [0])
    }
  }
}

///|
test "DAE2 local tag admission retains fresh local throw folding and sibling identity" {
  let input = pass_test_module_from_wat(
    "(module (tag $t) (func block $out try_table (catch_all $out) throw $t end end) (func (param i32) local.get 0 drop))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let expected = dae2_fold_known_local_throws_reference(input)
  let setups = [0]
  let output = dae2_fold_known_local_throws(input, setup_builds=Some(setups))
  assert_eq(output, expected)
  assert_true(@binary.encode_module(output).unwrap() != saved)
  assert_true(
    physical_equal(output.code_sec.unwrap().0[1], input.code_sec.unwrap().0[1]),
  )
  @validate.validate_module(output).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_eq(setups, [1])
}

///|
test "DAE2 no local tags preserves intentionally invalid unresolved throw for final validation" {
  let input = pass_test_module_from_wat("(module (func))")
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::throw_(@lib.TagIdx::new(99U))]),
      ),
    ]),
  )
  let saved = @binary.encode_module(input).unwrap()
  let expected = dae2_fold_known_local_throws_reference(input)
  let setups = [0]
  let output = dae2_fold_known_local_throws(input, setup_builds=Some(setups))
  assert_eq(output, expected)
  assert_true(@validate.validate_module(output) is Err(_))
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_eq(setups, [0])
}
