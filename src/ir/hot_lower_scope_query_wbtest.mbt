///|
// Keep fixture values independent of the native stack storage representation.
fn lower_test_value_stack(
  values : Array[HotLowerStackValue],
) -> HotLowerValueStack {
  let stack = hot_lower_value_stack_new()
  for value in values {
    stack.push(value)
  }
  stack
}

///|
fn lower_scope_query_fixture(
  depth : Int32,
  dependent : Bool,
) -> (HotFunc, NodeId, NodeId, Array[NodeId]) {
  let input = @wast.wast_to_binary_module(
    "(module (type $in (func (param i32) (result i32))) (func (param i32) (result i32) (local i32) local.get 0 loop $again (type $in) i32.const 1 i32.add local.get 0 i32.const 1 i32.sub local.tee 0 br_if $again end))",
  ).unwrap()
  let hot = hot_lift_func_with_context_result(
    input,
    @lib.FuncIdx::new(0U),
    hot_module_context_from_module(input),
    capture_stack_locals=false,
    materialize_multi_values=true,
  ).unwrap()
  let count = hot_node_count(hot)
  let mut value = -1
  for node in 0..<count {
    if hot_node_exact_instr(hot, node) is Some(@lib.I32Add) {
      value = node
      break
    }
  }
  if value < 0 {
    abort("missing loop-entry arithmetic")
  }
  let entry = hot_child_get(hot, value, 0)
  let operand = if dependent {
    value
  } else {
    hot_build_const_i32(hot, @lib.I32(7))
  }
  let store = hot_build_local_set(hot, 1, operand)
  let read = hot_build_local_get(hot, 1)
  let scopes = [
    hot_build_block(hot, @lib.BlockType::val_type(@lib.ValType::i32()), [
      store, read,
    ]),
  ]
  for _ in 1..<depth {
    scopes.push(
      hot_build_block(hot, @lib.BlockType::val_type(@lib.ValType::i32()), [
        scopes[scopes.length() - 1],
      ]),
    )
  }
  let outer = scopes[scopes.length() - 1]
  for node in 0..<count {
    for slot in 0..<hot_child_count(hot, node) {
      if hot_child_get(hot, node, slot) == value {
        hot_child_set(hot, node, slot, outer)
      }
    }
  }
  hot_verify_all_or_abort(hot)
  (hot, entry, outer, scopes)
}

///|
fn lower_scope_query_run(
  hot : HotFunc,
  entry : NodeId,
  outer : NodeId,
  frames : HotLowerLabelFrames,
) -> (Array[Instruction], HotLowerValueStack, Array[ValType]) {
  // The real carried value differs from local 0's initializer. Re-evaluating
  // its producer would turn 7 + 1 into 0 + 1 in the observer below.
  let stack : HotLowerValueStack = lower_test_value_stack([
    { node_id: entry, val_type: @lib.ValType::i32(), },
  ])
  let out = [Instruction::i32_const(7)]
  let extras : Array[ValType] = []
  hot_lower_impl_emit_root(
    hot,
    outer,
    hot_node_use_counts_build(hot),
    frames,
    -1,
    stack,
    out,
    extras,
    HotLowerOptions::new(),
  )
  (out, stack, extras)
}

///|
test "nested ordered scopes consume the actual carried value with linear dependency work" {
  for depth in [16, 32] {
    let (hot, entry, outer, _) = lower_scope_query_fixture(depth, true)
    let revision = hot_revision_current(hot)
    let children = hot.children.copy()
    let roots = hot.roots.copy()
    let work = [0]
    let frames = hot_lower_impl_new_label_frames(
      hot,
      scope_query_work=Some(work),
    )
    let (out, stack, extras) = lower_scope_query_run(hot, entry, outer, frames)
    assert_eq(out, [
      Instruction::i32_const(7),
      Instruction::i32_const(1),
      Instruction::i32_add(),
      Instruction::local_set(@lib.LocalIdx::new(1U)),
      Instruction::local_get(@lib.LocalIdx::new(1U)),
    ])
    assert_eq(lower_first_emission_observe(out, 2), ([8], []))
    assert_eq(stack.length(), 1)
    assert_eq(stack[0].node_id, outer)
    assert_eq(extras, [])
    assert_eq(hot_revision_current(hot), revision)
    assert_eq(hot.children, children)
    assert_eq(hot.roots, roots)
    assert_true(
      work[0] <= 8 * depth + 32,
      msg="nested scopes must not rescan every descendant chain",
    )
  }
}

///|
test "independent nested ordered scopes preserve their frames with linear rejection work" {
  for depth in [16, 32] {
    let (hot, entry, outer, _) = lower_scope_query_fixture(depth, false)
    let children = hot.children.copy()
    let roots = hot.roots.copy()
    let work = [0]
    let frames = hot_lower_impl_new_label_frames(
      hot,
      scope_query_work=Some(work),
    )
    let (out, stack, extras) = lower_scope_query_run(hot, entry, outer, frames)
    let counts = [0, 0, 0, 0, 0, 0]
    loop_entry_scope_boundary_counts(out, 0, counts)
    assert_eq(counts[0], depth)
    assert_eq(lower_first_emission_observe(out, 2), ([7, 7], []))
    assert_eq(stack.length(), 2)
    assert_eq(stack[0].node_id, entry)
    assert_eq(stack[1].node_id, outer)
    assert_eq(extras, [])
    assert_eq(hot.children, children)
    assert_eq(hot.roots, roots)
    assert_true(
      work[0] <= 8 * depth + 32,
      msg="independent nested scopes must share the exact negative proof",
    )
  }
}

///|
test "scope dependency reuse distinguishes shared operands and changing held node identities" {
  let hot = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  let first = hot_build_local_get(hot, 0)
  let second = hot_build_local_get(hot, 1)
  // Same local index is not the same evaluated producer.
  let other_first = hot_build_local_get(hot, 0)
  let other_second = hot_build_local_get(hot, 1)
  let mut shared = hot_build_binary(hot, @lib.ValType::i32(), first, second)
  for _ in 0..<8 {
    shared = hot_build_binary(hot, @lib.ValType::i32(), shared, shared)
  }
  let scope = hot_build_block(
    hot,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [shared],
  )
  let frames = hot_lower_impl_new_label_frames(hot)
  let revision = hot_revision_current(hot)
  for
    (held, expected) in [
      ([first], true),
      ([second], true),
      ([other_first], false),
      ([other_first, second], true),
      ([other_first, other_second], false),
      ([second, first], true),
      ([other_second], false),
      ([first], true),
    ] {
    let stack : HotLowerValueStack = lower_test_value_stack(
      held.map(fn(node_id) { { node_id, val_type: @lib.ValType::i32(), } }),
    )
    assert_eq(
      hot_lower_impl_scope_uses_parent(hot, scope, frames, stack),
      expected,
    )
  }
  assert_eq(hot_revision_current(hot), revision)
}
