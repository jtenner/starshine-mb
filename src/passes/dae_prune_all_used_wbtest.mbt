///|
test "DAE all-used128 keeps exact module metadata NaN bodies and borrowed ownership" {
  let input = dae_prune_all_used_fixture()
  let bytes = @binary.encode_module(input).unwrap()
  for names in [false, true] {
    let old = dae_prune_max_ref_prune_unused_simple_func_types(
      input,
      preserve_names=names,
    )
    let output = dae_prune_unused_simple_func_types(input, preserve_names=names)
    dae_prune_all_used_assert_identity(input, output, bytes)
    assert_true(physical_equal(old, input))
    assert_eq(@binary.encode_module(old).unwrap(), bytes)
  }
}

///|
test "DAE all-used follow-up retains actual productive max bounds and remap ownership" {
  let input = pass_test_module_from_wat(
    "(module (type (func (result i32))) (type (func (param i64))) (type (func (result i32))) (func (type 2) block (type 0) i32.const 7 end) (func (type 2) block (type 2) i32.const 9 end))",
  )
  let bytes = @binary.encode_module(input).unwrap()
  for names in [false, true] {
    let old = dae_prune_max_ref_prune_unused_simple_func_types(
      input,
      preserve_names=names,
    )
    let output = dae_prune_unused_simple_func_types(input, preserve_names=names)
    @validate.validate_module(output).unwrap()
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(old).unwrap(),
    )
    assert_eq(output.type_sec.unwrap().0.length(), 2)
    assert_eq(output.func_sec.unwrap().0, [
      @lib.TypeIdx::new(1U),
      @lib.TypeIdx::new(1U),
    ])
    assert_eq(output.name_sec, old.name_sec)
    let before = input.code_sec.unwrap().0
    let rows = output.code_sec.unwrap().0
    assert_false(physical_equal(rows, before))
    let @lib.Func(_, @lib.Expr(low_before)) = before[0]
    let @lib.Func(_, @lib.Expr(low_after)) = rows[0]
    assert_true(physical_equal(low_before, low_after))
    let @lib.Func(locals, @lib.Expr(high_after)) = rows[1]
    let @lib.Func(_, @lib.Expr(high_before)) = before[1]
    assert_false(physical_equal(high_before, high_after))
    match high_after[0] {
      @lib.Block(@lib.TypeIdxBlockType(@lib.TypeIdx(1U)), @lib.Expr(body)) =>
        assert_eq(body, [@lib.Instruction::i32_const(9)])
      _ => fail("expected actual indexed block remap")
    }
    let private_root = high_after.copy()
    private_root.push(@lib.Instruction::nop())
    rows[1] = @lib.Func::new(locals, @lib.Expr::new(private_root))
    @validate.validate_module(output).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), bytes)
    assert_eq(
      @binary.encode_module(old).unwrap(),
      @binary.encode_module(
        dae_prune_max_ref_prune_unused_simple_func_types(
          input,
          preserve_names=names,
        ),
      ).unwrap(),
    )
  }
}

///|
test "DAE all-used intentionally preserves invalid body and earlier error order" {
  for earlier in [false, true] {
    let base = pass_test_module_from_wat(
      "(module (type (func)) (func (export \"run\") (type 0) nop))",
    )
    let @lib.Func(locals, _) = base.code_sec.unwrap().0[0]
    let bad = base.with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          locals,
          @lib.Expr::new([
            @lib.Instruction::unreachable_(),
            @lib.Instruction::call_ref(@lib.TypeIdx::new(99U)),
          ]),
        ),
      ]),
    )
    let input = if earlier {
      let row = bad.export_sec.unwrap().0[0]
      bad.with_export_sec(@lib.ExportSec::new([row, row]))
    } else {
      bad
    }
    let bytes = @binary.encode_module(input).unwrap()
    let old = dae_prune_max_ref_prune_unused_simple_func_types(
      input,
      preserve_names=true,
    )
    let output = dae_prune_unused_simple_func_types(input, preserve_names=true)
    assert_true(physical_equal(output, input))
    assert_eq(@binary.encode_module(output).unwrap(), bytes)
    assert_eq(@binary.encode_module(old).unwrap(), bytes)
    let error = @validate.validate_module(input).unwrap_err()
    assert_eq(@validate.validate_module(output).unwrap_err(), error)
    assert_eq(@validate.validate_module(old).unwrap_err(), error)
    if earlier {
      assert_true(
        @validate.validation_error_message(error).contains(
          "duplicate export name",
        ),
      )
    }
    assert_eq(@binary.encode_module(input).unwrap(), bytes)
  }
}

///|
test "DAE all-used no-code and empty-code cases retain exact original module" {
  let base = pass_test_module_from_wat(
    "(module (type $f (func)) (import \"host\" \"f\" (func (type $f))))",
  )
  for input in [base, base.with_code_sec(@lib.CodeSec::new([]))] {
    @validate.validate_module(input).unwrap()
    let bytes = @binary.encode_module(input).unwrap()
    let old = dae_prune_max_ref_prune_unused_simple_func_types(
      input,
      preserve_names=true,
    )
    let output = dae_prune_unused_simple_func_types(input, preserve_names=true)
    assert_true(physical_equal(output, input))
    assert_true(physical_equal(old, input))
    assert_eq(@binary.encode_module(output).unwrap(), bytes)
    assert_eq(@binary.encode_module(input).unwrap(), bytes)
    assert_eq(@validate.validate_module(output), @validate.validate_module(old))
  }
}

///|
test "DAE all-used only after body marking retains the full mandatory scan route" {
  let input = pass_test_module_from_wat(
    "(module (type (func)) (type (func)) (func (type 0) block (type 1) nop end))",
  )
  @validate.validate_module(input).unwrap()
  let source = @binary.encode_module(input).unwrap()
  let old = dae_prune_max_ref_prune_unused_simple_func_types(input)
  let output = dae_prune_unused_simple_func_types(input)
  assert_true(physical_equal(output, input))
  assert_eq(output.type_sec.unwrap().0.length(), 2)
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(old).unwrap(),
  )
  assert_eq(@binary.encode_module(input).unwrap(), source)
}
