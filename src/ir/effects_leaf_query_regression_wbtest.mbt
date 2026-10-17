///|
// Freeze the full-arena single-node query for result and benchmark comparisons.
fn effects_leaf_query_reference(func : HotFunc, node : NodeId) -> EffectMask {
  effects_accumulate_node_cached(
    func,
    node,
    Array::make(hot_node_count(func), 0U),
    @bitset.BitSet::new(hot_node_count(func)),
  )
}

///|
test "leaf effects queries preserve state call control and exact payload effects" {
  for
    (source, code_idx) in [
      (
        "(module (func i32.const 7 drop ref.null extern drop nop unreachable))",
        0,
      ),
      (
        "(module (memory 1) (func (param i32) local.get 0 drop memory.size drop))",
        0,
      ),
      (
        "(module (table 1 funcref) (global (mut i32) (i32.const 0)) (func global.get 0 drop table.size 0 drop))",
        0,
      ),
      (
        "(module (func $callee (result i32) i32.const 9) (func call $callee drop))",
        1,
      ),
      (
        "(module (type $s (struct (field i32))) (func struct.new_default $s drop))",
        0,
      ),
      ("(module (memory 1 1 shared) (func atomic.fence))", 0),
      ("(module (func block end))", 0),
    ] {
    let fixture = ir_test_build_hot_from_wat(source, code_idx~)
    let func = fixture.hot_func
    let mut leaves = 0
    for node in 0..<hot_node_count(func) {
      if !hot_node_is_live(func, node) {
        continue
      }
      let mask = effects_for_node(func, node)
      assert_eq(mask, effects_leaf_query_reference(func, node))
      if hot_child_count(func, node) != 0 {
        continue
      }
      leaves += 1
      assert_eq(
        mask,
        effects_mask_for_flags(hot_node_flags(func, node)) |
        effects_mask_for_node_exact(func, node),
      )
      match hot_node_get(func, node).op {
        HotOp::Const | HotOp::RefNull | HotOp::Nop => assert_eq(mask, 0U)
        HotOp::LocalGet => assert_eq(mask, EFFECT_MASK_LOCAL_STATE)
        HotOp::GlobalGet => assert_eq(mask, EFFECT_MASK_GLOBAL_STATE)
        HotOp::MemorySize => assert_eq(mask, EFFECT_MASK_MEMORY_READ)
        HotOp::TableSize => assert_eq(mask, EFFECT_MASK_TABLE_READ)
        HotOp::Unreachable | HotOp::Block =>
          assert_true((mask & EFFECT_MASK_CONTROL) != 0U)
        HotOp::Call =>
          assert_true(
            (mask & (EFFECT_MASK_CALL | EFFECT_MASK_THROW | EFFECT_MASK_TRAP)) ==
            (EFFECT_MASK_CALL | EFFECT_MASK_THROW | EFFECT_MASK_TRAP),
          )
        HotOp::Heap =>
          assert_true(
            (mask & (EFFECT_MASK_TRAP | EFFECT_MASK_MEMORY_WRITE)) ==
            (EFFECT_MASK_TRAP | EFFECT_MASK_MEMORY_WRITE),
          )
        HotOp::Atomic => assert_true((mask & EFFECT_MASK_SEQ_CST) != 0U)
        _ => fail("unexpected leaf effect fixture opcode")
      }
    }
    assert_true(leaves > 0)
    ignore(ir_test_assert_verify_and_lower(fixture))
  }
}

///|
test "leaf effects queries reflect revisions and transitions to and from operand subtrees" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (global (mut i32) (i32.const 0)) (func block end))",
  )
  let func = fixture.hot_func
  let root = hot_root_get(func, 0)
  assert_eq(effects_for_node(func, root), EFFECT_MASK_CONTROL)
  let rev = hot_revision_current(func)
  let value = hot_build_global_get(func, 0, @lib.ValType::i32())
  let shared = hot_build_drop(func, value)
  hot_region_replace_body(func, hot_region_body_ref(func, root), [shared])
  assert_true(hot_revision_current(func) > rev)
  assert_eq(
    effects_for_node(func, root),
    EFFECT_MASK_CONTROL | EFFECT_MASK_GLOBAL_STATE,
  )
  assert_eq(
    effects_for_node(func, root),
    effects_leaf_query_reference(func, root),
  )
  ignore(ir_test_assert_verify_and_lower(fixture))
  let constant = hot_build_const_i32(func, @lib.I32(13))
  hot_replace_node(func, value, hot_node_get(func, constant))
  assert_eq(effects_for_node(func, value), 0U)
  assert_eq(effects_for_node(func, root), EFFECT_MASK_CONTROL)
  assert_eq(
    effects_for_node(func, root),
    effects_leaf_query_reference(func, root),
  )
  ignore(ir_test_assert_verify_and_lower(fixture))
  hot_region_replace_body(func, hot_region_body_ref(func, root), [])
  assert_eq(effects_for_node(func, root), EFFECT_MASK_CONTROL)
  ignore(ir_test_assert_verify_and_lower(fixture))
}

///|
test "leaf queries preserve shared DAG effects while the arena grows" {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let leaf = hot_build_local_get(func, 0)
  let mut value = leaf
  for _ in 0..<10 {
    value = hot_build_binary(func, @lib.ValType::i32(), value, value)
    hot_node_exact_instr_set(func, value, @lib.Instruction::i32_add())
  }
  hot_root_append(func, hot_build_drop(func, value))
  assert_eq(effects_for_node(func, leaf), EFFECT_MASK_LOCAL_STATE)
  assert_eq(effects_for_node(func, value), EFFECT_MASK_LOCAL_STATE)
  for _ in 0..<32 {
    ignore(hot_build_const_i32(func, @lib.I32(1)))
  }
  assert_eq(
    effects_for_node(func, leaf),
    effects_leaf_query_reference(func, leaf),
  )
  assert_eq(
    effects_for_node(func, value),
    effects_leaf_query_reference(func, value),
  )
  let fence = hot_build_atomic(func, [], @lib.Instruction::atomic_fence(), [])
  assert_eq(
    effects_for_node(func, fence),
    effects_leaf_query_reference(func, fence),
  )
  assert_true((effects_for_node(func, fence) & EFFECT_MASK_SEQ_CST) != 0U)
}

///|
fn effects_leaf_query_bench(
  it : @bench.T,
  arena_size : Int32,
  reference : Bool,
) -> Unit {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let leaf = hot_build_local_get(func, 0)
  for _ in 1..<arena_size {
    hot_root_append(func, hot_build_nop(func))
  }
  if effects_for_node(func, leaf) != EFFECT_MASK_LOCAL_STATE ||
    effects_leaf_query_reference(func, leaf) != EFFECT_MASK_LOCAL_STATE {
    abort("leaf effects benchmark fixture changed its local read")
  }
  // A count of one keeps each calibrated sample visible without winsorization.
  for sample in 0..<7 {
    it.bench(
      fn() {
        it.keep(
          if reference {
            effects_leaf_query_reference(func, leaf)
          } else {
            effects_for_node(func, leaf)
          },
        )
      },
      name="raw-\{sample}",
      count=1,
    )
  }
}

///|
#skip
test "bench leaf effect query arena=16 full arena" (it : @bench.T) {
  effects_leaf_query_bench(it, 16, true)
}

///|
#skip
test "bench leaf effect query arena=16 selected" (it : @bench.T) {
  effects_leaf_query_bench(it, 16, false)
}

///|
#skip
test "bench leaf effect query arena=4096 full arena" (it : @bench.T) {
  effects_leaf_query_bench(it, 4096, true)
}

///|
#skip
test "bench leaf effect query arena=4096 selected" (it : @bench.T) {
  effects_leaf_query_bench(it, 4096, false)
}
