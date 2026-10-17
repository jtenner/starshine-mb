///|
fn dae_prune_max_fixture() -> @lib.Module {
  pass_test_module_from_wat(
    (
      #| (module
      #|   (type (func (result i32)))
      #|   (type (func (param i64)))
      #|   (type (func (result i32)))
      #|   (func (type 2) block (type 0) i32.const 7 end)
      #|   (func (type 2) block (type 2) i32.const 9 end))
    ),
  )
}

///|
fn dae_prune_max_assert_reference(
  input : @lib.Module,
  preserve_names : Bool,
) -> @lib.Module raise {
  let source = @binary.encode_module(input).unwrap()
  let expected = dae_prune_max_ref_prune_unused_simple_func_types(
    input,
    preserve_names~,
  )
  let actual = dae_prune_unused_simple_func_types(input, preserve_names~)
  @validate.validate_module(expected).unwrap()
  @validate.validate_module(actual).unwrap()
  assert_eq(
    @binary.encode_module(actual).unwrap(),
    @binary.encode_module(expected).unwrap(),
  )
  assert_eq(actual.type_sec, expected.type_sec)
  assert_eq(actual.func_sec, expected.func_sec)
  assert_eq(actual.name_sec, expected.name_sec)
  assert_eq(@binary.encode_module(input).unwrap(), source)
  actual
}

///|
test "DAE prune max keeps lower indexed body and rewrites the first shifted index" {
  let input = dae_prune_max_fixture()
  let before = input.code_sec.unwrap().0
  let @lib.Func(_, @lib.Expr(lower)) = before[0]
  let @lib.Func(_, @lib.Expr(shifted)) = before[1]
  for preserve_names in [false, true] {
    let output = dae_prune_max_assert_reference(input, preserve_names)
    assert_eq(output.type_sec.unwrap().0.length(), 2)
    assert_eq(output.func_sec.unwrap().0, [
      @lib.TypeIdx::new(1U),
      @lib.TypeIdx::new(1U),
    ])
    let @lib.Func(_, @lib.Expr(after_lower)) = output.code_sec.unwrap().0[0]
    let @lib.Func(_, @lib.Expr(after_shifted)) = output.code_sec.unwrap().0[1]
    assert_true(physical_equal(lower, after_lower))
    assert_false(physical_equal(shifted, after_shifted))
    match after_shifted[0] {
      @lib.Block(@lib.TypeIdxBlockType(@lib.TypeIdx(1U)), _) => ()
      _ => fail("expected shifted block type")
    }
  }
}

///|
test "DAE prune max removes trailing type while retaining scalar NaN nested bodies" {
  let input = pass_test_module_from_wat(
    (
      #| (module
      #|   (type (func (result f64)))
      #|   (type (func (param i64)))
      #|   (func (type 0)
      #|     block (result f64) loop (result f64) f64.const nan:0x123 end end))
    ),
  )
  let @lib.Func(_, @lib.Expr(before)) = input.code_sec.unwrap().0[0]
  let output = dae_prune_max_assert_reference(input, false)
  assert_eq(output.type_sec.unwrap().0.length(), 1)
  let @lib.Func(_, @lib.Expr(after)) = output.code_sec.unwrap().0[0]
  assert_true(physical_equal(before, after))
}

///|
test "DAE prune max evidence ends before a source row changes between invocations" {
  let input = dae_prune_max_fixture()
  let first = dae_prune_max_assert_reference(input, true)
  let retained = @binary.encode_module(first).unwrap()
  let funcs = input.code_sec.unwrap().0
  let @lib.Func(locals, @lib.Expr(body)) = funcs[0]
  // Replace one source row, not a shared nested body. The second call must
  // derive fresh mandatory-scan evidence for the newly shifted block index.
  funcs[0] = @lib.Func::new(
    locals,
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(2U)),
        @lib.Expr::new([@lib.Instruction::i32_const(7)]),
      ),
    ]),
  )
  let second = dae_prune_max_assert_reference(input, true)
  assert_eq(second.type_sec.unwrap().0.length(), 1)
  assert_eq(second.func_sec.unwrap().0, [
    @lib.TypeIdx::new(0U),
    @lib.TypeIdx::new(0U),
  ])
  let @lib.Func(_, @lib.Expr(after)) = second.code_sec.unwrap().0[0]
  match after[0] {
    @lib.Block(@lib.TypeIdxBlockType(@lib.TypeIdx(0U)), _) => ()
    _ => fail("expected fresh shifted body evidence")
  }
  assert_eq(@binary.encode_module(first).unwrap(), retained)
  match body[0] {
    @lib.Block(@lib.TypeIdxBlockType(@lib.TypeIdx(0U)), _) => ()
    _ => fail("retained original body changed")
  }
}

///|
test "DAE prune max keeps productive normal DAE and DAEO output owned" {
  for optimize in [false, true] {
    let input = pass_test_module_from_wat(
      "(module (func $target (param i32) (result i32) local.get 0) (func (export \"run\") (result i32) i32.const 7 call $target))",
    )
    let source = @binary.encode_module(input).unwrap()
    let output = dae_run_module_pass(input, optimize~)
    @validate.validate_module(output).unwrap()
    let @lib.FuncSec(indices) = output.func_sec.unwrap()
    let @lib.TypeSec(types) = output.type_sec.unwrap()
    match types[dae_type_idx_slot(indices[0]).unwrap()] {
      @lib.SingleRecType(subtype) =>
        match subtype.get_comptype() {
          @lib.FuncCompType(params, _) => assert_eq(params.length(), 0)
          _ => fail("expected function type")
        }
      _ => fail("expected flat type section")
    }
    assert_true(
      @binary.encode_module(output).unwrap().length() < source.length(),
    )
    assert_eq(@binary.encode_module(input).unwrap(), source)
  }
}
