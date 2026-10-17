///|
test "DAE prune bound keeps retained GC slot and exact lower reference bodies" {
  let input = pass_test_module_from_wat(
    "(module (type $s (struct (field i32))) (type (func (param i64))) (type $f (func (result i32))) (func (type $f) (local (ref null $s)) ref.null $s local.set 0 struct.new_default $s drop local.get 0 ref.is_null))",
  )
  let source = @binary.encode_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(before)) = input.code_sec.unwrap().0[0]
  for names in [false, true] {
    let output = dae_prune_max_assert_reference(input, names)
    assert_eq(output.type_sec.unwrap().0.length(), 2)
    assert_eq(output.func_sec.unwrap().0, [@lib.TypeIdx::new(1U)])
    assert_eq(output.type_sec.unwrap().0[0], input.type_sec.unwrap().0[0])
    let @lib.Func(locals, @lib.Expr(after)) = output.code_sec.unwrap().0[0]
    assert_true(physical_equal(after, before))
    assert_eq(
      locals.runs()[0].val_type(),
      @lib.ValType::ref_null(@lib.HeapType::new(@lib.TypeIdx::new(0U))),
    )
    match after[2] {
      @lib.StructNewDefault(@lib.TypeIdx(0U)) => ()
      _ => fail("expected unchanged GC instruction index")
    }
  }
  assert_eq(@binary.encode_module(input).unwrap(), source)
}

///|
test "DAE prune bound still rewrites a type used only by locals" {
  let input = pass_test_module_from_wat(
    "(module (type (func (param i64))) (type $f (func)) (type $local (func (param i32))) (func (type $f) (local (ref null $local)) nop))",
  )
  let source = @binary.encode_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(before)) = input.code_sec.unwrap().0[0]
  let output = dae_prune_max_assert_reference(input, true)
  assert_eq(output.type_sec.unwrap().0.length(), 2)
  assert_eq(output.func_sec.unwrap().0, [@lib.TypeIdx::new(0U)])
  let @lib.Func(locals, @lib.Expr(after)) = output.code_sec.unwrap().0[0]
  assert_true(physical_equal(after, before))
  assert_eq(
    locals.runs()[0].val_type(),
    @lib.ValType::ref_null(@lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  assert_eq(@binary.encode_module(input).unwrap(), source)
}

///|
test "DAE prune bound intentionally retains old fallback for a moved GC definition" {
  let input = pass_test_module_from_wat(
    "(module (type (func (param i64))) (type $s (struct (field i32))) (type $f (func)) (func (type $f) struct.new_default $s drop))",
  )
  let source = @binary.encode_module(input).unwrap()
  let output = dae_prune_max_assert_reference(input, false)
  assert_true(physical_equal(output, input))
  assert_eq(output.type_sec.unwrap().0.length(), 3)
  assert_eq(@binary.encode_module(input).unwrap(), source)
}

///|
test "DAE prune bound intentionally keeps invalid index and earlier validation error order" {
  for earlier_error in [false, true] {
    let base = pass_test_module_from_wat(
      "(module (type (func)) (type (func (param i64))) (func (export \"run\") (type 0) nop))",
    )
    let @lib.Func(locals, _) = base.code_sec.unwrap().0[0]
    let body = [
      @lib.Instruction::unreachable_(),
      @lib.Instruction::call_ref(@lib.TypeIdx::new(99U)),
    ]
    let bad_body = base.with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]),
    )
    let input = if earlier_error {
      let row = base.export_sec.unwrap().0[0]
      bad_body.with_export_sec(@lib.ExportSec::new([row, row]))
    } else {
      bad_body
    }
    let source = @binary.encode_module(input).unwrap()
    let expected = dae_prune_max_ref_prune_unused_simple_func_types(input)
    let output = dae_prune_unused_simple_func_types(input)
    assert_eq(output.type_sec.unwrap().0.length(), 1)
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(expected).unwrap(),
    )
    assert_eq(
      @validate.validate_module(output).unwrap_err(),
      @validate.validate_module(expected).unwrap_err(),
    )
    assert_eq(
      @validate.validate_module(output).unwrap_err(),
      @validate.validate_module(input).unwrap_err(),
    )
    if earlier_error {
      assert_true(
        @validate.validation_error_message(
          @validate.validate_module(output).unwrap_err(),
        ).contains("duplicate export name"),
      )
    }
    let @lib.Func(_, @lib.Expr(after)) = output.code_sec.unwrap().0[0]
    assert_true(physical_equal(after, body))
    assert_eq(after[1], @lib.Instruction::call_ref(@lib.TypeIdx::new(99U)))
    assert_eq(@binary.encode_module(input).unwrap(), source)
  }
}

///|
test "DAE prune bound marks every branch and catch with exact old side effects" {
  // First retain a real productive prune and its full independent byte oracle.
  let productive = dae_prune_max_fixture()
  let output = dae_prune_max_assert_reference(productive, false)
  assert_eq(output.type_sec.unwrap().0.length(), 2)
  let leaf = [@lib.Instruction::nop()]
  let changed = [@lib.Instruction::call_ref(@lib.TypeIdx::new(7U))]
  let bodies = [
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      @lib.Expr::new(leaf),
    ),
    @lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new(leaf)),
    @lib.Instruction::if_(@lib.BlockType::void_(), leaf, Some(changed)),
    @lib.Instruction::try_table(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(2U)),
      [],
      @lib.Expr::new(leaf),
    ),
    @lib.Instruction::try_(@lib.BlockType::void_(), @lib.Expr::new(leaf), [
      @lib.LegacyCatch::tagged(@lib.TagIdx::new(0U), @lib.Expr::new(changed)),
      @lib.LegacyCatch::all(
        @lib.Expr::new([
          @lib.Instruction::select(
            types=Some([
              @lib.ValType::ref_null(@lib.HeapType::new(@lib.TypeIdx::new(6U))),
            ]),
          ),
        ]),
      ),
    ]),
  ]
  let used = Array::make(9, false)
  let expected = Array::make(9, false)
  dae_prune_max_ref_collect_used_type_idx_instrs(bodies, expected)
  assert_eq(dae_prune_collect_used_type_idx_max(bodies, used), 7)
  assert_eq(used, expected)
  assert_eq(used, [false, true, true, false, false, false, true, true, false])
  assert_eq(changed, [@lib.Instruction::call_ref(@lib.TypeIdx::new(7U))])
  assert_eq(leaf, [@lib.Instruction::nop()])
}

///|
test "DAE prune bound intentionally preserves RecIdx OOB and embedded definition marking" {
  let productive = dae_prune_max_fixture()
  let output = dae_prune_max_assert_reference(productive, true)
  assert_eq(output.type_sec.unwrap().0.length(), 2)
  let input = [
    @lib.Instruction::call_ref(@lib.TypeIdx::rec(0U)),
    @lib.Instruction::return_call_ref(@lib.TypeIdx::new(99U)),
    @lib.Instruction::call_ref(@lib.TypeIdx::new(0xffffffffU)),
  ]
  let used = Array::make(3, false)
  let expected = Array::make(3, false)
  dae_prune_max_ref_collect_used_type_idx_instrs(input, expected)
  assert_eq(dae_prune_collect_used_type_idx_max(input, used), -1)
  assert_eq(used, expected)
  assert_eq(used, [false, false, false])
  assert_true(
    physical_equal(dae_rewrite_pruned_type_idx_instrs(input, [0, 1, 2]), input),
  )
  let embedded = @lib.DefType::new(productive.type_sec.unwrap().0[0], 0U)
  let embedded_body = [
    @lib.Instruction::ref_null(@lib.HeapType::def_type(embedded)),
  ]
  dae_prune_max_ref_collect_used_type_idx_instrs(embedded_body, expected)
  assert_eq(dae_prune_collect_used_type_idx_max(embedded_body, used), 3)
  assert_eq(used, expected)
  assert_eq(used, [true, true, true])
  assert_true(
    physical_equal(
      dae_rewrite_pruned_type_idx_instrs(embedded_body, [0, 1, 2]),
      embedded_body,
    ),
  )
}
