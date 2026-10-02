///|
test "lift local-access projection preserves completed masks and fresh mutation facts" {
  let (func, value) = hot_lift_local_mask_fixture(4)
  let actual = HotLiftLocalAccessMasks::new()
  let prior = HotLiftLocalAccessMasks::new()
  let revision = hot_revision_current(func)
  hot_lift_impl_collect_local_access_masks(func, value, actual, None)
  lift_access_fields_original_collect_local_access_masks(
    func,
    value,
    prior,
    None,
  )
  assert_eq(actual.reads, prior.reads)
  assert_eq(actual.writes, prior.writes)
  assert_eq(actual.ready, prior.ready)
  assert_eq(actual.reads[value], 1UL)
  assert_eq(actual.writes[value], 0UL)
  assert_eq(hot_revision_current(func), revision)
  let saved = actual.reads.copy()
  hot_node_set(func, value, hot_node_get(func, 0))
  // Completed-value caches must never be reused after mutation. Fresh masks
  // read the current arena fields and leave the held prior snapshot intact.
  let fresh = HotLiftLocalAccessMasks::new()
  hot_lift_impl_collect_local_access_masks(func, value, fresh, None)
  assert_eq(fresh.reads[value], 1UL)
  assert_eq(fresh.writes[value], 0UL)
  assert_eq(actual.reads, saved)
  assert_eq(fresh.ready.filter(fn(ready) { ready }).length(), 1)
}

///|
test "lift local-access projection retains incomplete deletion-index fallback and input ownership" {
  let (func, value) = hot_lift_local_mask_fixture(4)
  let dead = hot_build_nop(func)
  hot_delete_node(func, dead)
  func.deleted_nodes.clear()
  let free = func.free_nodes.copy()
  let revision = hot_revision_current(func)
  let masks = HotLiftLocalAccessMasks::new()
  hot_lift_impl_collect_local_access_masks(func, value, masks, None)
  assert_eq(masks.reads[value], 1UL)
  assert_eq(masks.writes[value], 0UL)
  assert_true(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      value,
      0,
      true,
      masks=Some(masks),
    ),
  )
  assert_false(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      value,
      0,
      false,
      masks=Some(masks),
    ),
  )
  assert_eq(func.free_nodes, free)
  assert_eq(hot_revision_current(func), revision)
  for invalid in [-1, dead, hot_node_count(func)] {
    let visits = [0]
    assert_false(
      hot_lift_impl_value_conflicts_with_local_access(
        func,
        invalid,
        0,
        true,
        node_visits=Some(visits),
      ),
    )
    assert_eq(visits[0], 0)
  }
}

///|
test "lift local-access projection retains mask collisions exact dependencies and identical traversal" {
  let (func, value) = hot_lift_local_mask_fixture(8)
  let write = hot_build_local_tee(
    func,
    64,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  let joined = hot_build_binary(func, @lib.ValType::i32(), value, write)
  let actual = HotLiftLocalAccessMasks::new()
  let prior = HotLiftLocalAccessMasks::new()
  let revision = hot_revision_current(func)
  for root in [value, write, joined] {
    for local in [0, 1, 63, 64, 65, 127] {
      for is_write in [false, true] {
        let av = [0]
        let pv = [0]
        assert_eq(
          hot_lift_impl_value_conflicts_with_local_access(
            func,
            root,
            local,
            is_write,
            masks=Some(actual),
            node_visits=Some(av),
          ),
          lift_access_fields_original_value_conflicts_with_local_access(
            func,
            root,
            local,
            is_write,
            masks=Some(prior),
            node_visits=Some(pv),
          ),
        )
        assert_eq(av, pv)
        assert_eq(actual.reads, prior.reads)
        assert_eq(actual.writes, prior.writes)
        assert_eq(actual.ready, prior.ready)
      }
    }
  }
  assert_true(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      joined,
      64,
      false,
      masks=Some(actual),
    ),
  )
  assert_false(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      value,
      64,
      true,
      masks=Some(actual),
    ),
  )
  assert_eq(hot_revision_current(func), revision)
}
