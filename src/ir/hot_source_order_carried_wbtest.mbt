///|
fn carried_vector_fixture(
  count : Int,
) -> (HotFunc, Array[NodeId], NodeId, Array[NodeId]) {
  let func = HotFunc::new()
  let calls = Array::makei(count, fn(i) {
    hot_build_call(func, i, [@lib.ValType::i32()], [])
  })
  let barrier = hot_build_call(func, count, [], [])
  let future = calls.map(fn(call) { hot_build_drop(func, call) })
  (func, calls, barrier, future)
}

///|
test "carried dependency queries allocate one workspace vector and own each returned row" {
  let (func, calls, barrier, future) = carried_vector_fixture(6)
  let facts = HotSourceOrderFacts::new(func)
  let reference = HotSourceOrderFacts::new(func)
  let old_scratch = SourceOrderCarriedReferenceScratch::new(
    hot_node_count(func),
  )
  let builds = [0]
  let saved : Array[Array[NodeId]] = []
  let expected : Array[Array[NodeId]] = []
  let revision = hot_revision_current(func)
  for length in [6, 1, 3, 0, 6, 1, 0] {
    let roots = future[:length].to_owned()
    let actual = hot_source_order_preceding_dependencies(
      func,
      barrier,
      roots,
      0,
      None,
      facts,
      carried_builds=Some(builds),
    )
    assert_eq(actual, calls[:length].to_owned())
    assert_eq(
      actual,
      source_order_carried_reference_query(
        func,
        barrier,
        roots,
        0,
        None,
        reference,
        old_scratch,
      ),
    )
    saved.push(actual)
    expected.push(actual.copy())
    for index in 0..<saved.length() {
      assert_eq(saved[index], expected[index])
    }
  }
  // Mutating a caller-owned selection must not corrupt a later query or a
  // held sibling selection. The reusable internal carried vector is separate.
  saved[0].clear()
  assert_eq(saved[4], calls)
  assert_eq(
    hot_source_order_preceding_dependencies(
      func,
      barrier,
      future,
      0,
      None,
      facts,
      carried_builds=Some(builds),
    ),
    calls,
  )
  assert_eq(hot_revision_current(func), revision)
  assert_eq(builds[0], 1)
}

///|
test "empty and pure dependency queries avoid creating carried workspace" {
  let (func, _, barrier, future) = carried_vector_fixture(3)
  let pure = hot_build_const_i32(func, @lib.I32(7))
  let facts = HotSourceOrderFacts::new(func)
  let builds = [0]
  for
    (root, roots, start) in [
      (pure, future, 0),
      (barrier, [], 0),
      (barrier, future, future.length()),
      (barrier, future, future.length() + 1),
    ] {
    assert_eq(
      hot_source_order_preceding_dependencies(
        func,
        root,
        roots,
        start,
        None,
        facts,
        carried_builds=Some(builds),
      ),
      [],
    )
    assert_true(facts.dependency_scratch is None)
  }
  assert_eq(builds[0], 0)
}

///|
test "carried workspace keeps independent source snapshots and effect ordering" {
  for
    source in [
      "(module (import \"m\" \"f\" (func $f (result i32))) (func (param i32) (result i32) call $f block local.get 0 drop end local.get 0 i32.add))",
      "(module (memory 1) (func (param i32) (result i32) local.get 0 i32.load block i32.const 7 local.set 0 end local.get 0 i32.add))",
      "(module (func (param externref) (result externref) local.get 0 block i32.const 1 drop end))",
      "(module (func (param i32) (result i32) local.get 0 block local.get 0 i32.const 1 i32.add local.set 0 end local.get 0 i32.add))",
    ] {
    let module_ = ir_test_module_from_wat(source)
    let func = hot_lift_func(
      module_,
      @lib.FuncIdx::new(if source.contains("import") { 1U } else { 0U }),
    )
    let roots = Array::makei(hot_root_count(func), fn(slot) {
      hot_root_get(func, slot)
    })
    let first = HotSourceOrderFacts::new(func)
    let second = HotSourceOrderFacts::new(func)
    let reference = HotSourceOrderFacts::new(func)
    let old_scratch = SourceOrderCarriedReferenceScratch::new(
      hot_node_count(func),
    )
    let index = Some(HotSourceOrderRootIndex::new(func, roots, first))
    for root in roots {
      for start in 0..<=roots.length() {
        let expected = source_order_carried_reference_query(
          func, root, roots, start, index, reference, old_scratch,
        )
        let held = hot_source_order_preceding_dependencies(
          func, root, roots, start, index, first,
        )
        assert_eq(held, expected)
        assert_eq(
          hot_source_order_preceding_dependencies(
            func,
            root,
            roots,
            start,
            None,
            second,
          ),
          expected,
        )
        assert_eq(held, expected)
      }
    }
    hot_verify_all(func).unwrap()
  }
}

///|
test "carried high-water storage survives narrow and indexed empty queries without retaining values" {
  let (func, calls, barrier, roots) = carried_vector_fixture(32)
  let pure = hot_build_const_i32(func, @lib.I32(7))
  let facts = HotSourceOrderFacts::new(func)
  let sibling = HotSourceOrderFacts::new(func)
  let held = hot_source_order_preceding_dependencies(
    func,
    barrier,
    roots,
    0,
    None,
    facts,
  )
  assert_eq(held, calls)
  let scratch = facts.dependency_scratch.unwrap()
  let buffer = scratch.carried
  let capacity = buffer.capacity()
  assert_eq(buffer, [])
  assert_true(capacity >= calls.length())
  assert_true(capacity <= hot_node_count(func) * 2)
  let index = Some(HotSourceOrderRootIndex::new(func, roots, facts))
  for
    (root, start, expected) in [
      (barrier, roots.length() - 1, [calls[calls.length() - 1]]),
      (barrier, roots.length(), []),
      (pure, 0, []),
    ] {
    assert_eq(
      hot_source_order_preceding_dependencies(
        func, root, roots, start, index, facts,
      ),
      expected,
    )
    assert_eq(buffer, [])
    assert_eq(buffer.capacity(), capacity)
    assert_true(physical_equal(scratch.carried, buffer))
    assert_eq(scratch.touched, [])
    for id in 0..<hot_node_count(func) {
      assert_eq(scratch.seen_consumer[id], hot_node_count(func))
      assert_eq(scratch.consumer_bounds[id], -1)
      assert_false(scratch.anti_dependencies[id])
    }
    assert_eq(held, calls)
  }
  assert_eq(
    hot_source_order_preceding_dependencies(
      func,
      barrier,
      roots,
      0,
      None,
      sibling,
    ),
    calls,
  )
  assert_false(
    physical_equal(sibling.dependency_scratch.unwrap().carried, buffer),
  )
  assert_eq(buffer, [])
  assert_eq(buffer.capacity(), capacity)
}
