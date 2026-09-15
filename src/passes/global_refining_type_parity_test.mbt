///|
test "global-refining type parity prunes unused generated siblings" {
  for
    name in [
      "global-refining-private-writes", "global-refining-export-boundaries", "global-refining-import-aliases",
    ] {
    let profile = @validate.gen_valid_profile_by_name(name).unwrap()
    let input = @validate.gen_valid_module_result_from_seed(
        17UL,
        @validate.GenValidConfig::for_profile(profile),
      ).unwrap().wasm_module
    let output = global_refining_run_module_pass(input)
    assert_true(@validate.validate_module(output).is_ok())
    @debug.assert_eq(
      output.type_sec.unwrap().0.length(),
      input.type_sec.unwrap().0.length() - 1,
    )
  }
}

///|
test "global-refining type parity retains and remaps cast-only type roots" {
  for cast in [false, true] {
    let input = pass_test_module_from_wat(
      "(module (type (struct)) (type (struct (field i32))) (type (struct)) (type (func)) (global (mut anyref) (struct.new_default 2)) (func (type 3) global.get 0 drop))",
    )
    let heap = @lib.HeapType::new(@lib.TypeIdx::new(1U))
    let operation = if cast {
      @lib.Instruction::ref_cast(false, heap)
    } else {
      @lib.Instruction::ref_test(false, heap)
    }
    let input = input.with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([
            @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
            operation,
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
    assert_true(@validate.validate_module(input).is_ok())
    let output = global_refining_run_module_pass(input)
    assert_true(@validate.validate_module(output).is_ok())
    @debug.assert_eq(output.type_sec.unwrap().0.length(), 3)
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    let target = @lib.HeapType::new(@lib.TypeIdx::new(0U))
    @debug.assert_eq(
      body[1],
      if cast {
        @lib.Instruction::ref_cast(false, target)
      } else {
        @lib.Instruction::ref_test(false, target)
      },
    )
  }
}
