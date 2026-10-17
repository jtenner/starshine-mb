///|
// Frozen S4 admission: keep this local reference independent of the new cache.
fn lower_scope_query_uncached_reference(
  hot : HotFunc,
  scope : NodeId,
  stack : Array[HotLowerStackValue],
) -> Bool {
  let marks : @hashmap.HashMap[NodeId, Int32] = @hashmap.new()
  for value in stack {
    if value.node_id >= 0 {
      marks.set(value.node_id, 1)
    }
  }
  let pending : Array[NodeId] = []
  for slot in 0..<hot_child_count(hot, scope) {
    pending.push(hot_child_get(hot, scope, slot))
  }
  while !pending.is_empty() {
    let value = pending.pop().unwrap()
    if value < 0 {
      continue
    }
    match marks.get(value) {
      Some(1) => return true
      Some(_) => continue
      None => ()
    }
    marks.set(value, 2)
    for slot in 0..<hot_child_count(hot, value) {
      pending.push(hot_child_get(hot, value, slot))
    }
  }
  false
}

///|
fn lower_scope_query_bench(
  it : @bench.T,
  depth : Int32,
  dependent : Bool,
  reference : Bool,
  single_outer~ : Bool = false,
) -> Unit raise {
  let (hot, entry, outer, scopes) = lower_scope_query_fixture(depth, dependent)
  let frames = hot_lower_impl_new_label_frames(hot)
  let (out, stack, extras) = lower_scope_query_run(hot, entry, outer, frames)
  assert_eq(
    lower_first_emission_observe(out, 2, fuel_limit=depth + 32),
    (if dependent { [8] } else { [7, 7] }, []),
  )
  assert_eq(stack.length(), if dependent { 1 } else { 2 })
  assert_eq(extras, [])
  let held : Array[HotLowerStackValue] = [
    { node_id: entry, val_type: @lib.ValType::i32(), },
  ]
  for scope in scopes {
    assert_eq(lower_scope_query_uncached_reference(hot, scope, held), dependent)
    assert_eq(
      hot_lower_impl_scope_uses_parent(hot, scope, frames, held),
      dependent,
    )
  }
  it.bench(fn() {
    // Each timing sample owns a fresh lower cache. The positive nested query
    // order is outer to inner, as in the actual ordered-scope emitter.
    let current = hot_lower_impl_new_label_frames(hot)
    if single_outer {
      // Real independent outer scopes reject once, then enter a fresh region
      // stack. This cold miss exposes cache setup and allocation overhead.
      it.keep(
        if reference {
          lower_scope_query_uncached_reference(hot, outer, held)
        } else {
          hot_lower_impl_scope_uses_parent(hot, outer, current, held)
        },
      )
    } else {
      for index = scopes.length() - 1; index >= 0; index = index - 1 {
        it.keep(
          if reference {
            lower_scope_query_uncached_reference(hot, scopes[index], held)
          } else {
            hot_lower_impl_scope_uses_parent(hot, scopes[index], current, held)
          },
        )
      }
    }
  })
}

///|
fn lower_scope_query_alternating_bench(
  it : @bench.T,
  depth : Int32,
  reference : Bool,
) -> Unit raise {
  let (hot, first, outer, scopes) = lower_scope_query_fixture(depth, true)
  let second = hot_build_local_get(hot, 0)
  let store = hot_child_get(hot, scopes[0], 0)
  let sum = hot_child_get(hot, store, 0)
  // Both exact producer IDs occur below every wrapper. Alternating the only
  // held producer forces the one-target cache to replace its previous proof.
  hot_child_set(hot, sum, 1, second)
  hot_verify_all_or_abort(hot)
  let revision = hot_revision_current(hot)
  let children = hot.children.copy()
  let held : Array[Array[HotLowerStackValue]] = [first, second].map(fn(
    node_id,
  ) {
    [{ node_id, val_type: @lib.ValType::i32(), }]
  })
  let frames = hot_lower_impl_new_label_frames(hot)
  for scope in scopes {
    for stack in held {
      assert_true(lower_scope_query_uncached_reference(hot, scope, stack))
      assert_true(hot_lower_impl_scope_uses_parent(hot, scope, frames, stack))
    }
  }
  let (out, stack, extras) = lower_scope_query_run(
    hot,
    first,
    outer,
    hot_lower_impl_new_label_frames(hot),
  )
  assert_eq(
    lower_first_emission_observe(out, 2, fuel_limit=depth + 32),
    ([7], []),
  )
  assert_eq(stack.length(), 1)
  assert_eq(stack[0].node_id, outer)
  assert_eq(extras, [])
  it.bench(fn() {
    let current = hot_lower_impl_new_label_frames(hot)
    for index = scopes.length() - 1; index >= 0; index = index - 1 {
      let stack = held[index % 2]
      it.keep(
        if reference {
          lower_scope_query_uncached_reference(hot, scopes[index], stack)
        } else {
          hot_lower_impl_scope_uses_parent(hot, scopes[index], current, stack)
        },
      )
    }
  })
  assert_eq(hot_revision_current(hot), revision)
  assert_eq(hot.children, children)
}

///|
#skip("manual native-release ordered-scope query scaling and allocation controls")
test "bench ordered-scope query carried depth=32 S4 uncached" (it : @bench.T) {
  lower_scope_query_bench(it, 32, true, true)
}

///|
#skip("manual native-release ordered-scope query scaling and allocation controls")
test "bench ordered-scope query carried depth=32 cached" (it : @bench.T) {
  lower_scope_query_bench(it, 32, true, false)
}

///|
#skip("manual native-release ordered-scope query scaling and allocation controls")
test "bench ordered-scope query carried depth=128 S4 uncached" (it : @bench.T) {
  lower_scope_query_bench(it, 128, true, true)
}

///|
#skip("manual native-release ordered-scope query scaling and allocation controls")
test "bench ordered-scope query carried depth=128 cached" (it : @bench.T) {
  lower_scope_query_bench(it, 128, true, false)
}

///|
#skip("manual native-release ordered-scope query scaling and allocation controls")
test "bench ordered-scope query carried depth=512 S4 uncached" (it : @bench.T) {
  lower_scope_query_bench(it, 512, true, true)
}

///|
#skip("manual native-release ordered-scope query scaling and allocation controls")
test "bench ordered-scope query carried depth=512 cached" (it : @bench.T) {
  lower_scope_query_bench(it, 512, true, false)
}

///|
#skip("manual native-release ordered-scope query scaling and allocation controls")
test "bench ordered-scope query independent depth=32 S4 uncached" (
  it : @bench.T,
) {
  lower_scope_query_bench(it, 32, false, true)
}

///|
#skip("manual native-release ordered-scope query scaling and allocation controls")
test "bench ordered-scope query independent depth=32 cached" (it : @bench.T) {
  lower_scope_query_bench(it, 32, false, false)
}

///|
#skip("manual native-release ordered-scope query scaling and allocation controls")
test "bench ordered-scope query independent depth=128 S4 uncached" (
  it : @bench.T,
) {
  lower_scope_query_bench(it, 128, false, true)
}

///|
#skip("manual native-release ordered-scope query scaling and allocation controls")
test "bench ordered-scope query independent depth=128 cached" (it : @bench.T) {
  lower_scope_query_bench(it, 128, false, false)
}

///|
#skip("manual native-release ordered-scope query scaling and allocation controls")
test "bench ordered-scope query independent depth=512 S4 uncached" (
  it : @bench.T,
) {
  lower_scope_query_bench(it, 512, false, true)
}

///|
#skip("manual native-release ordered-scope query scaling and allocation controls")
test "bench ordered-scope query independent depth=512 cached" (it : @bench.T) {
  lower_scope_query_bench(it, 512, false, false)
}

///|
#skip("manual native-release ordered-scope cold-miss allocation control")
test "bench ordered-scope cold independent depth=32 S4 uncached" (it : @bench.T) {
  lower_scope_query_bench(it, 32, false, true, single_outer=true)
}

///|
#skip("manual native-release ordered-scope cold-miss allocation control")
test "bench ordered-scope cold independent depth=32 cached" (it : @bench.T) {
  lower_scope_query_bench(it, 32, false, false, single_outer=true)
}

///|
#skip("manual native-release ordered-scope cold-miss allocation control")
test "bench ordered-scope cold independent depth=128 S4 uncached" (
  it : @bench.T,
) {
  lower_scope_query_bench(it, 128, false, true, single_outer=true)
}

///|
#skip("manual native-release ordered-scope cold-miss allocation control")
test "bench ordered-scope cold independent depth=128 cached" (it : @bench.T) {
  lower_scope_query_bench(it, 128, false, false, single_outer=true)
}

///|
#skip("manual native-release ordered-scope cold-miss allocation control")
test "bench ordered-scope cold independent depth=512 S4 uncached" (
  it : @bench.T,
) {
  lower_scope_query_bench(it, 512, false, true, single_outer=true)
}

///|
#skip("manual native-release ordered-scope cold-miss allocation control")
test "bench ordered-scope cold independent depth=512 cached" (it : @bench.T) {
  lower_scope_query_bench(it, 512, false, false, single_outer=true)
}

///|
#skip("manual native-release alternating held-target cache footprint control")
test "bench ordered-scope alternating targets depth=32 S4 uncached" (
  it : @bench.T,
) {
  lower_scope_query_alternating_bench(it, 32, true)
}

///|
#skip("manual native-release alternating held-target cache footprint control")
test "bench ordered-scope alternating targets depth=32 cached" (it : @bench.T) {
  lower_scope_query_alternating_bench(it, 32, false)
}

///|
#skip("manual native-release alternating held-target cache footprint control")
test "bench ordered-scope alternating targets depth=128 S4 uncached" (
  it : @bench.T,
) {
  lower_scope_query_alternating_bench(it, 128, true)
}

///|
#skip("manual native-release alternating held-target cache footprint control")
test "bench ordered-scope alternating targets depth=128 cached" (it : @bench.T) {
  lower_scope_query_alternating_bench(it, 128, false)
}

///|
#skip("manual native-release alternating held-target cache footprint control")
test "bench ordered-scope alternating targets depth=512 S4 uncached" (
  it : @bench.T,
) {
  lower_scope_query_alternating_bench(it, 512, true)
}

///|
#skip("manual native-release alternating held-target cache footprint control")
test "bench ordered-scope alternating targets depth=512 cached" (it : @bench.T) {
  lower_scope_query_alternating_bench(it, 512, false)
}
