///|
fn source_order_minimum_fixture(
  count : Int,
) -> (HotFunc, NodeId, NodeId, NodeId) {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let old = hot_build_call(func, 0, [@lib.ValType::i32()], [])
  let barrier = hot_build_call(func, 1, [], [])
  fn build(length : Int) -> NodeId {
    if length == 1 {
      return hot_build_local_get(func, 0)
    }
    let left = length / 2
    let node = hot_build_binary(
      func,
      @lib.ValType::i32(),
      build(left),
      build(length - left),
    )
    hot_node_exact_instr_set(func, node, @lib.Instruction::i32_add())
    node
  }
  let later = build(count)
  let value = hot_build_binary(func, @lib.ValType::i32(), old, later)
  hot_node_exact_instr_set(func, value, @lib.Instruction::i32_add())
  let root = hot_build_drop(func, value)
  (func, old, barrier, root)
}

///|
test "cached dependency minima prune a later subtree while retaining the old call" {
  let (func, old, barrier, root) = source_order_minimum_fixture(16)
  let facts = HotSourceOrderFacts::new(func)
  let cache = facts.preceding_dependency_min_cache
  assert_eq(
    hot_lower_impl_preceding_dependency_min_node(
      func,
      root,
      cache,
      facts.value_orders,
      facts.node_effects,
    ),
    old,
  )
  let scratch = HotSourceOrderScratch::new(hot_node_count(func))
  let out : Array[NodeId] = []
  let queries = [0]
  hot_lower_impl_collect_preceding_dependency_indexed(
    func,
    root,
    barrier,
    root,
    facts.value_orders,
    facts.node_effects,
    scratch.seen_consumer,
    scratch.consumer_bounds,
    scratch.touched,
    out,
    Some(cache),
    Some(queries),
  )
  assert_eq(out, [old])
  assert_eq(scratch.consumer_bounds[old], root)
  // Only drop and its combining binary need operand queries. The later
  // effectful subtree has no value before the barrier and must not be walked.
  assert_eq(queries[0], 2)
}

///|
test "dependency minimum pruning preserves selected source order on cold and reused facts" {
  for count in [1, 4, 16] {
    let (func, old, barrier, root) = source_order_minimum_fixture(count)
    let facts = HotSourceOrderFacts::new(func)
    let reference = HotSourceOrderFacts::new(func)
    let future = [root]
    for _ in 0..<3 {
      let result = hot_source_order_preceding_dependencies(
        func,
        barrier,
        future,
        0,
        None,
        facts,
      )
      assert_eq(result, [old])
      assert_eq(
        result,
        source_order_minimum_reference_query(
          func,
          barrier,
          future,
          0,
          None,
          reference,
        ),
      )
      let scratch = facts.dependency_scratch.unwrap()
      assert_eq(scratch.touched, [])
      for id in 0..<hot_node_count(func) {
        assert_eq(scratch.seen_consumer[id], hot_node_count(func))
        assert_eq(scratch.consumer_bounds[id], -1)
        assert_false(scratch.anti_dependencies[id])
      }
    }
  }
}

///|
test "dependency minimum query agrees with the original for source wrappers traps refs and shared inputs" {
  for
    source in [
      "(module (import \"m\" \"f\" (func $f (result i32))) (func (param i32) (result i32) call $f local.get 0 i32.add))",
      "(module (func (param i32) (result i32) local.get 0 block i32.const 11 local.set 0 end local.get 0 i32.add))",
      "(module (memory 1) (func (param i32) (result i32) local.get 0 i32.load i32.const 0 i32.div_s))",
      "(module (func (param externref) (result externref) local.get 0 block i32.const 1 drop end))",
      "(module (type $s (func (param i32) (result i32))) (func (param i32) (result i32) local.get 0 i32.const 7 local.tee 0 if (type $s) local.get 0 i32.add else local.get 0 i32.sub end))",
    ] {
    let module_ = ir_test_module_from_wat(source)
    let func = hot_lift_func(
      module_,
      @lib.FuncIdx::new(if source.contains("import") { 1U } else { 0U }),
    )
    let roots = Array::makei(hot_root_count(func), fn(i) {
      hot_root_get(func, i)
    })
    let facts = HotSourceOrderFacts::new(func)
    let reference = HotSourceOrderFacts::new(func)
    for root in roots {
      for start in 0..<=roots.length() {
        assert_eq(
          hot_source_order_preceding_dependencies(
            func,
            root,
            roots,
            start,
            None,
            facts,
          ),
          source_order_minimum_reference_query(
            func,
            root,
            roots,
            start,
            None,
            reference,
          ),
        )
      }
    }
    hot_verify_all(func).unwrap()
  }
  let (func, _, barrier, root) = source_order_minimum_fixture(4)
  let combined = hot_build_binary(
    func,
    @lib.ValType::i32(),
    hot_child_get(func, root, 0),
    hot_child_get(func, root, 0),
  )
  hot_node_exact_instr_set(func, combined, @lib.Instruction::i32_add())
  let future = [hot_build_drop(func, combined), root]
  let facts = HotSourceOrderFacts::new(func)
  let reference = HotSourceOrderFacts::new(func)
  assert_eq(
    hot_source_order_preceding_dependencies(
      func,
      barrier,
      future,
      0,
      None,
      facts,
    ),
    source_order_minimum_reference_query(
      func,
      barrier,
      future,
      0,
      None,
      reference,
    ),
  )
}

///|
test "cyclic operand minima remain conservative and dependency queries terminate" {
  let (func, old, barrier, root) = source_order_minimum_fixture(4)
  let value = hot_child_get(func, root, 0)
  let later = hot_child_get(func, value, 1)
  let facts = HotSourceOrderFacts::new(func)
  let reference = HotSourceOrderFacts::new(func)
  hot_child_set(func, later, 1, value)
  // Supply conservative rows directly: normal facts construction requires an
  // acyclic operand graph. This malformed cycle tests only the query kernel.
  // This malformed cyclic graph intentionally tests conservative analysis;
  // it is not a valid executable wasm fixture.
  assert_true(
    hot_lower_impl_preceding_dependency_min_node(
      func,
      root,
      facts.preceding_dependency_min_cache,
      facts.value_orders,
      facts.node_effects,
    ) <
    0,
  )
  assert_eq(
    hot_source_order_preceding_dependencies(
      func,
      barrier,
      [root],
      0,
      None,
      facts,
    ),
    source_order_minimum_reference_query(
      func,
      barrier,
      [root],
      0,
      None,
      reference,
    ),
  )
  assert_eq(facts.dependency_scratch.unwrap().touched, [])
  assert_eq(old, 0)
}
