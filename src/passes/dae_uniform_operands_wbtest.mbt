///|
test "DAE uniform operand proof borrows contiguous scalar and GC roots without slices" {
  let input = pass_test_module_from_wat(
    "(module (type $s (struct (field i32))) (func $h (param i32 f64 (ref null $s))) (func (export \"run\") i32.const 7 f64.const -0 ref.null $s call $h))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  let @lib.Func(_, @lib.Expr(body)) = graph.snapshot.funcs[1]
  let operands = dae_uniform_callsite_operands_at(
    input,
    body,
    3,
    3,
    0,
    graph.snapshot.type_indices,
  ).unwrap()
  assert_eq(operands.direct_actual_start, Some(0))
  assert_true(operands.evidence is None)
  assert_true(physical_equal(operands.scope, body))
  assert_eq(operands.scope[1], body[1])
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE uniform operand proof preserves ambient stack and computed operand fallback" {
  let input = pass_test_module_from_wat(
    "(module (func $h (param i32) (result i32) local.get 0) (func (export \"run\") (result i32) i32.const 9 i32.const 4 call $h i32.add))",
  )
  @validate.validate_module(input).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  let @lib.Func(_, @lib.Expr(body)) = graph.snapshot.funcs[1]
  let operands = dae_uniform_callsite_operands_at(
    input,
    body,
    2,
    1,
    1,
    graph.snapshot.type_indices,
  ).unwrap()
  assert_eq(operands.direct_actual_start, Some(1))
  assert_true(operands.evidence is None)
  let computed = pass_test_module_from_wat(
    "(module (func $h (param i32)) (func (export \"run\") i32.const 1 i32.const 2 i32.add call $h))",
  )
  @validate.validate_module(computed).unwrap()
  let graph = dae_current_boundary_graph_new(computed)
  let @lib.Func(_, @lib.Expr(body)) = graph.snapshot.funcs[1]
  let operands = dae_uniform_callsite_operands_at(
    computed,
    body,
    3,
    1,
    0,
    graph.snapshot.type_indices,
  ).unwrap()
  assert_eq(operands.direct_actual_start, None)
  let evidence = operands.evidence.unwrap()
  assert_eq(evidence.slices[0].start, 0)
  assert_eq(evidence.slices[0].end, 3)
}

///|
test "DAE contiguous operands retain forwarded constants and rebuild changed callers" {
  for value in [7, 11] {
    let input = pass_test_module_from_wat(
      "(module (func $h (param i32) (result i32) local.get 0) (func $forward (param i32) (result i32) local.get 0 call $h) (func (export \"run\") (result i32) i32.const \{value} call $forward))",
    )
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let graph = dae_current_boundary_graph_new(input)
    assert_eq(
      dae_collect_uniform_const_actuals_from_boundary_facts(
        input,
        0,
        1,
        graph.snapshot.type_indices,
        graph.snapshot.boundary_facts,
      ),
      Some([Some(@lib.Instruction::i32_const(@lib.I32(value)))]),
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "DAE contiguous operands preserve recursive and exported forwarding boundaries" {
  for recurse in [false, true] {
    let body = if recurse { "local.get 0 call $h" } else { "local.get 0" }
    let input = pass_test_module_from_wat(
      "(module (func $h (param i32) (result i32) \{body}) (func $forward (export \"forward\") (param i32) (result i32) local.get 0 call $h))",
    )
    @validate.validate_module(input).unwrap()
    let graph = dae_current_boundary_graph_new(input)
    assert_eq(
      dae_collect_uniform_const_actuals_from_boundary_facts(
        input,
        0,
        1,
        graph.snapshot.type_indices,
        graph.snapshot.boundary_facts,
      ),
      Some([None]),
    )
  }
}

///|
test "DAE uniform scanning still rejects intentionally invalid later control signatures" {
  let input = pass_test_module_from_wat(
    "(module (func $h (param i32)) (func (export \"run\") i32.const 7 call $h))",
  )
  let graph = dae_current_boundary_graph_new(input)
  let @lib.Func(_, @lib.Expr(original)) = graph.snapshot.funcs[1]
  let body = original.copy()
  // Intentionally invalid type index: finishing a constant proof must not
  // bypass the scanner's existing control-admission failure.
  body.push(
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(999U)),
      @lib.Expr::new([]),
    ),
  )
  assert_false(
    dae_collect_uniform_const_actuals_instrs(
      body,
      0,
      [@lib.ValType::i32()],
      0,
      1,
      input,
      graph.snapshot.type_indices,
      graph.snapshot.boundary_facts,
      Array::make(graph.snapshot.total, false),
      [false],
      [false],
      [None],
    ),
  )
}

///|
test "DAE operand recovery matches full slicing for interleaved effects and multi-value producers" {
  for
    text in [
      "(module (import \"m\" \"tick\" (func $tick)) (func $h (param i32)) (func (export \"run\") i32.const 7 call $tick call $h))",
      "(module (func $pair (result i32 i32) i32.const 1 i32.const 2) (func $h (param i32 i32)) (func (export \"run\") call $pair call $h))",
    ] {
    let input = pass_test_module_from_wat(text)
    @validate.validate_module(input).unwrap()
    let graph = dae_current_boundary_graph_new(input)
    let @lib.Func(_, @lib.Expr(body)) = graph.snapshot.funcs[graph.snapshot.funcs.length() -
      1]
    let call_idx = body.length() - 1
    let params = if body[0] is @lib.Call(_) { 2 } else { 1 }
    let actual = dae_uniform_callsite_operands_at(
      input,
      body,
      call_idx,
      params,
      0,
      graph.snapshot.type_indices,
    )
    let reference = dae_uniform_operands_sliced_reference_at(
      input,
      body,
      call_idx,
      params,
      0,
      graph.snapshot.type_indices,
    )
    assert_eq(actual.is_some(), reference.is_some())
    match (actual, reference) {
      (Some(actual), Some(reference)) => {
        assert_eq(actual.direct_actual_start, None)
        let slices = actual.evidence.unwrap().slices
        let old_slices = reference.evidence.unwrap().slices
        assert_eq(slices.length(), old_slices.length())
        for p in 0..<slices.length() {
          assert_eq(slices[p].start, old_slices[p].start)
          assert_eq(slices[p].end, old_slices[p].end)
        }
      }
      _ => ()
    }
  }
}

///|
test "DAE borrowed uniform operands preserve forwarded NaN payload bits" {
  let input = pass_test_module_from_wat(
    "(module (func $h (param f64) (result i64) local.get 0 i64.reinterpret_f64) (func $f (param f64) (result i64) local.get 0 call $h) (func (export \"run\") (result i64) f64.const nan:0x123456 call $f))",
  )
  let graph = dae_current_boundary_graph_new(input)
  match
    dae_collect_uniform_const_actuals_from_boundary_facts(
      input,
      0,
      1,
      graph.snapshot.type_indices,
      graph.snapshot.boundary_facts,
    ) {
    Some([Some(@lib.F64Const(@lib.F64(value)))]) =>
      assert_eq(value.reinterpret_as_int64(), 0x7ff0000000123456L)
    _ => fail("expected the exact forwarded NaN constant")
  }
}
