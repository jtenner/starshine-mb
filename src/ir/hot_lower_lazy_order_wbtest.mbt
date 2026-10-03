///|
test "lower single-root ordering stays lazy without changing emitted instructions" {
  let (func, root) = cfg_lazy_single_region_fixture()
  let frames = hot_lower_impl_new_label_frames(func)
  let suffix = hot_lower_impl_future_dependencies(func, [root], frames)
  assert_false(suffix.required)
  assert_true(
    frames.source_order is None,
    msg="single-root lowering eagerly built whole-function ordering facts",
  )
}

///|
test "lower forward-only roots avoid whole-function ordering facts" {
  let func = cfg_segment_storage_fixture(4)
  let frames = hot_lower_impl_new_label_frames(func)
  ignore(hot_lower_impl_future_dependencies(func, hot_root_span(func), frames))
  assert_true(
    frames.source_order is None,
    msg="forward-only lowering eagerly built whole-function ordering facts",
  )
}

///|
fn lower_lazy_raw_region(
  func : HotFunc,
  frames : HotLowerLabelFrames,
) -> (Array[Instruction], Array[ValType]) {
  let counts = hot_node_use_counts_build(func)
  let roots = hot_root_span(func)
  let options = HotLowerOptions::new()
  let out : Array[Instruction] = []
  let stack : Array[HotLowerStackValue] = []
  let locals : Array[ValType] = []
  let preserve = hot_lower_impl_preserve_region_result_roots(
    func,
    counts,
    roots,
    hot_type_result_arity(func, hot_body_result_type(func)),
  )
  let suffix = hot_lower_impl_future_dependencies(func, roots, frames)
  for index in 0..<roots.length() {
    let root = roots[index]
    hot_lower_impl_emit_preceding_future_dependencies(
      func,
      root,
      roots,
      index + 1,
      suffix,
      counts,
      frames,
      -1,
      stack,
      out,
      locals,
      options,
    )
    hot_lower_impl_emit_root(
      func, root, counts, frames, -1, stack, out, locals, options,
    )
    hot_lower_impl_drop_dead_nonfinal_root_results(
      func,
      root,
      counts,
      preserve[index],
      index + 1 == roots.length(),
      stack,
      out,
    )
  }
  (out, locals)
}

///|
fn lower_lazy_assert_eager_equivalent(func : HotFunc) -> Unit raise {
  let revision = hot_revision_current(func)
  let eager = hot_lower_impl_new_label_frames(func)
  eager.source_order = Some(HotSourceOrderFacts::new(func))
  let lazy = hot_lower_impl_new_label_frames(func)
  assert_eq(
    lower_lazy_raw_region(func, lazy),
    lower_lazy_raw_region(func, eager),
  )
  hot_verify_all_or_abort(func)
  assert_eq(hot_revision_current(func), revision)
}

///|
test "lower lazy ordering matches eager instructions for typed loops GC traps and exception edges" {
  for
    wat in [
      "(module (func))", "(module (func (param i32) (result i32) (local i32) local.get 0 local.set 1 local.get 1 local.get 0 i32.const 1 i32.add local.set 1 i32.const 7 i32.add))",
      "(module (func (param i32) (result i32) local.get 0 if (result i32) i32.const 7 else i32.const 9 end))",
      "(module (type (func (param i32) (result i32))) (func (param i32) (result i32) local.get 0 block (type 0) i32.const 7 i32.add end))",
      "(module (func (param i32) (result i32) block (result i32) loop (result i32) local.get 0 br 1 end end))",
      "(module (type (struct (field i32))) (func (param (ref null 0)) (result i32) local.get 0 struct.get 0 0))",
      "(module (tag $e) (func (param i32) (local i32) block $exit block $catch try_table (catch $e $catch) local.get 0 local.set 1 throw $e end br $exit end local.get 1 drop end))",
      "(module (memory 1) (func (param i32) (result i32) local.get 0 i32.load i32.const 0 i32.const 7 i32.store))",
    ] {
    let input = @wast.wast_to_binary_module(wat).unwrap()
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let func = hot_lift_func(input, @lib.FuncIdx::new(0U))
    lower_lazy_assert_eager_equivalent(func)
    let output = input.with_code_sec(@lib.CodeSec::new([hot_lower_func(func)]))
    @validate.validate_module(output).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "lower lazy ordering initializes once for nested carried reads and isolates sibling snapshots" {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let carried = hot_build_local_get(func, 0)
  let write = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(9)),
  )
  let read = hot_build_drop(func, carried)
  let root = hot_build_block(func, @lib.BlockType::void_(), [write, read])
  hot_root_append(func, root)
  lower_lazy_assert_eager_equivalent(func)
  let frames = hot_lower_impl_new_label_frames(func)
  let sibling = hot_lower_impl_new_label_frames(func)
  ignore(hot_lower_impl_future_dependencies(func, [root], frames))
  assert_true(frames.source_order is None)
  let (body, _) = lower_lazy_raw_region(func, frames)
  guard body[0] is Instruction::Block(_, @lib.Expr(items)) else {
    fail("nested carried read must retain its block")
  }
  assert_eq(items[0], Instruction::local_get(LocalIdx::new(0U)))
  let facts = frames.source_order.unwrap()
  ignore(lower_lazy_raw_region(func, frames))
  assert_true(physical_equal(facts, frames.source_order.unwrap()))
  assert_true(sibling.source_order is None)
  hot_root_set(func, 0, hot_build_nop(func))
  let fresh = hot_lower_impl_new_label_frames(func)
  ignore(lower_lazy_raw_region(func, fresh))
  assert_true(fresh.source_order is None)
}

///|
test "lower lazy ordering retains effectful buried scalars and skips impossible stack reuse" {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let read = hot_build_local_get(func, 0)
  let later = hot_build_const_i32(func, @lib.I32(7))
  let frames = hot_lower_impl_new_label_frames(func)
  let counts = hot_node_use_counts_build(func)
  let stack : Array[HotLowerStackValue] = [
    { node_id: read, val_type: @lib.ValType::i32(), },
    { node_id: later, val_type: @lib.ValType::i32(), },
  ]
  let out : Array[Instruction] = []
  let locals : Array[ValType] = []
  hot_lower_impl_emit_root(
    func,
    read,
    counts,
    frames,
    -1,
    stack,
    out,
    locals,
    HotLowerOptions::new(),
  )
  assert_true(
    frames.source_order is None,
    msg="buried scalar reuse built unused value-order/local-query facts for an effect-only query",
  )
  let masks = frames.node_effects.unwrap()
  assert_eq(masks, effects_build_node_masks(func))
  assert_true(physical_equal(masks, hot_lower_impl_node_effects(func, frames)))
  let facts = hot_lower_impl_source_order(func, frames)
  assert_true(physical_equal(masks, facts.node_effects))
  assert_true(frames.node_effects is None)
  assert_eq(locals, [@lib.ValType::i32(), @lib.ValType::i32()])
  assert_eq(out, [
    Instruction::local_set(LocalIdx::new(1U)),
    Instruction::local_set(LocalIdx::new(2U)),
    Instruction::local_get(LocalIdx::new(1U)),
    Instruction::local_get(LocalIdx::new(2U)),
  ])
  assert_eq(stack[0].node_id, later)
  assert_eq(stack[1].node_id, read)
  let fresh = hot_lower_impl_new_label_frames(func)
  let empty : Array[HotLowerStackValue] = []
  hot_lower_impl_emit_root(
    func,
    read,
    counts,
    fresh,
    -1,
    empty,
    [],
    [],
    HotLowerOptions::new(),
  )
  assert_true(fresh.source_order is None)
}
