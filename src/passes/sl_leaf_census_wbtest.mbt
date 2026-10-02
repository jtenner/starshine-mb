///|
test "leaf conditional cleanup borrows complete bodies with no conditional" {
  for
    wat in [
      "(module (func (param i32) local.get 0 drop))", "(module (func (param i32) block loop local.get 0 drop end end try_table local.get 0 drop end))",
      "(module (type $s (struct (field i32))) (func (param (ref $s)) block local.get 0 struct.get $s 0 drop f64.const nan:0x12345 drop f32.const -0 drop end))",
      "(module (global (mut i32) (i32.const 0)) (func (param i32) block local.get 0 global.set 0 i32.const 1 local.get 0 i32.div_s drop end))",
    ] {
    let input = pass_test_module_from_wat(wat)
    let saved = @binary.encode_module(input).unwrap()
    let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    let @lib.TypeIdx(type_idx) = input.func_sec.unwrap().0[0]
    let params = match
      input.type_sec.unwrap().0[type_idx.reinterpret_as_int()] {
      @lib.SingleRecType(subtype) =>
        match subtype.get_comptype() {
          @lib.FuncCompType(params, _) => params
          _ => abort("expected function signature")
        }
      _ => abort("expected singleton function type")
    }
    let (actual, count) = run_hot_pipeline_raw_simplify_locals_rewrite_leaf_conditional_assignments(
      body, params, locals,
    )
    assert_eq(count, 0)
    assert_true(
      physical_equal(actual, body),
      msg="a function without ifs still cloned conditional-cleanup storage",
    )
    let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, body)
    let reused = run_hot_pipeline_raw_simplify_locals_rewrite_leaf_conditional_assignments(
      body,
      params,
      locals,
      stats~,
    )
    assert_eq(reused.1, 0)
    assert_true(physical_equal(reused.0, body))
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "leaf conditional cleanup owns all rewritten storage including unchanged siblings" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) block block local.get 0 drop end local.get 0 if (result i32) i32.const 7 else i32.const 9 end drop end local.get 0))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, body)
  let (actual, count) = run_hot_pipeline_raw_simplify_locals_rewrite_leaf_conditional_assignments(
    body,
    [@lib.ValType::i32()],
    locals,
    stats~,
  )
  assert_eq(count, 1)
  assert_false(physical_equal(actual, body))
  guard actual[0] is @lib.Block(_, @lib.Expr(outer)) else {
    fail("expected outer block")
  }
  assert_eq(outer[1:5].to_owned(), [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::select(),
  ])
  @validate.validate_module(
    input.with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(actual))]),
    ),
  ).unwrap()
  guard outer[0] is @lib.Block(_, @lib.Expr(sibling)) else {
    fail("expected unchanged sibling block")
  }
  sibling[0] = @lib.Instruction::nop()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "leaf conditional cleanup discovers new nested candidates after mutation" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) block local.get 0 drop end))",
  )
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  assert_eq(
    run_hot_pipeline_raw_simplify_locals_gate_stats(locals, body).if_count,
    0,
  )
  guard body[0] is @lib.Block(_, @lib.Expr(child)) else {
    fail("expected mutable block body")
  }
  child.append([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [@lib.Instruction::i32_const(@lib.I32(3))],
      Some([@lib.Instruction::i32_const(@lib.I32(5))]),
    ),
    @lib.Instruction::drop(),
  ])
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, body)
  assert_eq(stats.if_count, 1)
  let (actual, count) = run_hot_pipeline_raw_simplify_locals_rewrite_leaf_conditional_assignments(
    body,
    [@lib.ValType::i32()],
    locals,
    stats~,
  )
  assert_eq(count, 1)
  @validate.validate_module(
    input.with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(actual))]),
    ),
  ).unwrap()
}

///|
test "leaf conditional census preserves effectful arms and reference results" {
  for
    wat in [
      "(module (global (mut i32) (i32.const 0)) (func (param i32) (result i32) local.get 0 if (result i32) i32.const 7 global.set 0 i32.const 3 else i32.const 9 global.set 0 i32.const 5 end))",
      "(module (type $s (struct (field i32))) (func (param i32) (result (ref null $s)) local.get 0 if (result (ref null $s)) ref.null $s else ref.null $s end))",
      "(module (func (param i32) (result i32) local.get 0 if (result i32) unreachable else i32.const 5 end))",
    ] {
    let input = pass_test_module_from_wat(wat)
    let saved = @binary.encode_module(input).unwrap()
    let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, body)
    assert_eq(stats.if_count, 1)
    let (actual, count) = run_hot_pipeline_raw_simplify_locals_rewrite_leaf_conditional_assignments(
      body,
      [@lib.ValType::i32()],
      locals,
      stats~,
    )
    // These non-leaf or reference arms are intentionally outside the existing
    // numeric leaf-to-select transform. The census never broadens admission.
    assert_eq(count, 0)
    assert_eq(
      @binary.encode_module(
        input.with_code_sec(
          @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(actual))]),
        ),
      ).unwrap(),
      saved,
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
