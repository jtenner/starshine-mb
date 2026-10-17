///|
fn cfg_pure_preflight_check(
  input : @lib.Module,
  func : HotFunc,
  expected : @lib.Func,
  selected : Array[NodeId],
  cold : Bool,
) -> Unit raise {
  hot_verify_all_or_abort(func)
  let input_bytes = @binary.encode_module(input).unwrap()
  let revision = hot_revision_current(func)
  let nodes = func.nodes.copy()
  let children = func.children.copy()
  let roots = Array::makei(hot_root_count(func), fn(slot) {
    hot_root_get(func, slot)
  })
  assert_eq(roots.length(), 2)
  // This is the real collector with eagerly built facts, independently of the
  // cheap preflight. Pure-case emptiness is proved before checking saved work.
  assert_eq(
    hot_source_order_preceding_dependencies(
      func,
      roots[0],
      roots,
      1,
      None,
      HotSourceOrderFacts::new(func),
    ),
    selected,
  )
  let reference = cfg_builder_new(func, true, true)
  let expected_segments = cfg_segment_storage_reference(
    reference,
    func,
    HotRegionRef::root(),
  )
  let builder = cfg_builder_new(func, true, true)
  let actual_segments = cfg_builder_region_segments(
    builder,
    func,
    HotRegionRef::root(),
  )
  assert_eq(builder.cfg, reference.cfg)
  assert_eq(actual_segments.length(), expected_segments.length())
  for slot in 0..<actual_segments.length() {
    assert_eq(
      actual_segments.get(slot).last_node,
      expected_segments[slot].last_node,
    )
    assert_eq(
      actual_segments.get(slot).end_slot,
      expected_segments[slot].end_slot,
    )
  }
  cfg_verify(cfg_build(func, expand_operand_control=true))
  let lowered = hot_lower_func(func)
  assert_eq(lowered, expected)
  @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([lowered]))).unwrap()
  let frames = hot_lower_impl_new_label_frames(func)
  let future = hot_lower_impl_future_dependencies(func, roots, frames)
  assert_eq(func.nodes, nodes)
  assert_eq(func.children, children)
  assert_eq(
    Array::makei(hot_root_count(func), fn(slot) { hot_root_get(func, slot) }),
    roots,
  )
  assert_eq(hot_revision_current(func), revision)
  assert_eq(@binary.encode_module(input).unwrap(), input_bytes)
  if cold {
    // The real builder/lower would allocate complete function-sized facts at
    // this seam. No counter-only result substitutes for their exact output.
    assert_true(
      builder.source_order is None,
      msg="pure source preflight built whole-function CFG facts",
    )
    assert_true(
      frames.source_order is None,
      msg="pure source preflight built whole-function lowering facts",
    )
    assert_false(future.required)
  } else {
    assert_true(builder.source_order is Some(_))
    assert_true(frames.source_order is Some(_))
    assert_true(future.required)
  }
}

///|
test "pure carried constant preserves exact CFG and lower output without complete source facts" {
  let input = ir_test_module_from_wat(
    "(module (func (param i32) (result i32) i32.const 7 i32.const 9 local.set 0))",
  )
  let expected = ir_test_module_from_wat(
    "(module (func (param i32) (result i32) i32.const 9 local.set 0 i32.const 7))",
  )
  cfg_pure_preflight_check(
    input,
    hot_lift_func(input, @lib.FuncIdx::new(0U)),
    expected.code_sec.unwrap().0[0],
    [],
    true,
  )
}

///|
test "pure carried null preserves reference result and owned input without complete source facts" {
  let input = ir_test_module_from_wat(
    "(module (func (param i32) (result externref) ref.null extern i32.const 9 local.set 0))",
  )
  let expected = ir_test_module_from_wat(
    "(module (func (param i32) (result externref) i32.const 9 local.set 0 ref.null extern))",
  )
  cfg_pure_preflight_check(
    input,
    hot_lift_func(input, @lib.FuncIdx::new(0U)),
    expected.code_sec.unwrap().0[0],
    [],
    true,
  )
}

///|
test "old void wrapper cannot create source demand for a newer pure operand" {
  let input = ir_test_module_from_wat(
    "(module (func (param i32) i32.const 7 drop i32.const 9 local.set 0))",
  )
  let func = hot_lift_func(input, @lib.FuncIdx::new(0U))
  let old_drop = hot_root_get(func, 0)
  let write = hot_root_get(func, 1)
  let newer = hot_build_const_i32(func, @lib.I32(11))
  hot_child_set(func, old_drop, 0, newer)
  ignore(hot_root_splice(func, 0, 2, [write, old_drop]))
  let expected = ir_test_module_from_wat(
    "(module (func (param i32) i32.const 9 local.set 0 i32.const 11 drop))",
  )
  cfg_pure_preflight_check(
    input,
    func,
    expected.code_sec.unwrap().0[0],
    [],
    true,
  )
}

///|
fn cfg_pure_preflight_later_sum(func : HotFunc, carried : NodeId) -> NodeId {
  let result = hot_build_binary(
    func,
    @lib.ValType::i32(),
    carried,
    hot_build_const_i32(func, @lib.I32(0)),
  )
  hot_node_exact_instr_set(func, result, @lib.Instruction::i32_add())
  result
}

///|
test "source preflight retains a carried local read before its overwrite" {
  let input = ir_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0 i32.const 9 local.set 0 i32.const 0 i32.add))",
  )
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  hot_body_result_type_set(
    func,
    hot_type_intern_results(func, [@lib.ValType::i32()]),
  )
  let carried = hot_build_local_get(func, 0)
  let write = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(9)),
  )
  let later = cfg_pure_preflight_later_sum(func, carried)
  hot_root_append(func, write)
  hot_root_append(func, later)
  cfg_pure_preflight_check(
    input,
    func,
    input.code_sec.unwrap().0[0],
    [carried],
    false,
  )
}

///|
test "source preflight keeps a trapping producer before a later observable call" {
  let input = ir_test_module_from_wat(
    "(module (import \"m\" \"mark\" (func)) (func (result i32) i32.const 1 i32.const 0 i32.div_s call 0 i32.const 0 i32.add))",
  )
  let func = HotFunc::new()
  hot_body_result_type_set(
    func,
    hot_type_intern_results(func, [@lib.ValType::i32()]),
  )
  let carried = hot_build_binary(
    func,
    @lib.ValType::i32(),
    hot_build_const_i32(func, @lib.I32(1)),
    hot_build_const_i32(func, @lib.I32(0)),
  )
  hot_node_exact_instr_set(func, carried, @lib.Instruction::i32_div_s())
  let call = hot_build_call(func, 0, [], [])
  let later = cfg_pure_preflight_later_sum(func, carried)
  hot_root_append(func, call)
  hot_root_append(func, later)
  cfg_pure_preflight_check(
    input,
    func,
    input.code_sec.unwrap().0[0],
    [carried],
    false,
  )
}

///|
test "source preflight keeps a global read before its observable overwrite" {
  let input = ir_test_module_from_wat(
    "(module (global (mut i32) (i32.const 0)) (func (result i32) global.get 0 i32.const 9 global.set 0 i32.const 0 i32.add))",
  )
  let func = HotFunc::new()
  hot_body_result_type_set(
    func,
    hot_type_intern_results(func, [@lib.ValType::i32()]),
  )
  let carried = hot_build_global_get(func, 0, @lib.ValType::i32())
  let write = hot_build_global_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(9)),
  )
  let later = cfg_pure_preflight_later_sum(func, carried)
  hot_root_append(func, write)
  hot_root_append(func, later)
  cfg_pure_preflight_check(
    input,
    func,
    input.code_sec.unwrap().0[0],
    [carried],
    false,
  )
}

///|
test "source preflight cycle sentinel remains conservative for intentionally invalid operands" {
  let func = HotFunc::new()
  let value = hot_build_const_i32(func, @lib.I32(7))
  let other = hot_build_const_i32(func, @lib.I32(9))
  let cyclic = hot_build_binary(func, @lib.ValType::i32(), value, other)
  hot_node_exact_instr_set(func, cyclic, @lib.Instruction::i32_add())
  hot_child_set(func, cyclic, 1, cyclic)
  // A malformed cycle is intentionally unsupported as executable HOT. Only
  // the bounded conservative preflight kernel is exercised here.
  let minima = Array::make(hot_node_count(func), -1)
  let visits = [0]
  assert_true(
    cfg_operand_minimum_order(func, cyclic, minima, visits=Some(visits)) < 0,
  )
  assert_eq(visits[0], 2)
  assert_eq(
    cfg_operand_minimum_order(func, cyclic, minima, visits=Some(visits)),
    minima[cyclic],
  )
  assert_eq(visits[0], 2)
}
