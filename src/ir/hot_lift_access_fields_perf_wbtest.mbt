///|
fn lift_access_fields_bench(
  it : @bench.T,
  kind : Int,
  original : Bool,
) -> Unit raise {
  let (func, value) = hot_lift_local_mask_fixture(
    if kind == 0 {
      0
    } else {
      32
    },
  )
  let masks = HotLiftLocalAccessMasks::new()
  let old_masks = HotLiftLocalAccessReferenceMasks::new()
  let cached = kind >= 2
  let local = if kind == 0 || kind == 5 {
    0
  } else if kind == 4 {
    64
  } else {
    1
  }
  let actual_masks = if cached { Some(masks) } else { None }
  let original_masks = if cached { Some(old_masks) } else { None }
  assert_eq(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      value,
      local,
      true,
      masks=actual_masks,
    ),
    lift_access_fields_original_value_conflicts_with_local_access(
      func,
      value,
      local,
      true,
      masks=original_masks,
    ),
  )
  let revision = hot_revision_current(func)
  it.bench(fn() {
    // Cold rows include complete first-use construction. Other cached rows
    // query the same immutable completed value with equivalent warm summaries.
    it.keep(
      if original {
        let query_masks = if kind == 3 {
          Some(HotLiftLocalAccessReferenceMasks::new())
        } else {
          original_masks
        }
        lift_access_fields_original_value_conflicts_with_local_access(
          func,
          value,
          local,
          true,
          masks=query_masks,
        )
      } else {
        let query_masks = if kind == 3 {
          Some(HotLiftLocalAccessMasks::new())
        } else {
          actual_masks
        }
        hot_lift_impl_value_conflicts_with_local_access(
          func,
          value,
          local,
          true,
          masks=query_masks,
        )
      },
    )
  })
  assert_eq(hot_revision_current(func), revision)
}

///|
test "bench lift access fields leaf-positive original" (it : @bench.T) {
  lift_access_fields_bench(it, 0, true)
}

///|
test "bench lift access fields leaf-positive projected" (it : @bench.T) {
  lift_access_fields_bench(it, 0, false)
}

///|
test "bench lift access fields uncached-negative32 original" (it : @bench.T) {
  lift_access_fields_bench(it, 1, true)
}

///|
test "bench lift access fields uncached-negative32 projected" (it : @bench.T) {
  lift_access_fields_bench(it, 1, false)
}

///|
test "bench lift access fields warm-negative32 original" (it : @bench.T) {
  lift_access_fields_bench(it, 2, true)
}

///|
test "bench lift access fields warm-negative32 projected" (it : @bench.T) {
  lift_access_fields_bench(it, 2, false)
}

///|
test "bench lift access fields cold-negative32 original" (it : @bench.T) {
  lift_access_fields_bench(it, 3, true)
}

///|
test "bench lift access fields cold-negative32 projected" (it : @bench.T) {
  lift_access_fields_bench(it, 3, false)
}

///|
test "bench lift access fields collision-negative32 original" (it : @bench.T) {
  lift_access_fields_bench(it, 4, true)
}

///|
test "bench lift access fields collision-negative32 projected" (it : @bench.T) {
  lift_access_fields_bench(it, 4, false)
}

///|
test "bench lift access fields warm-positive32 original" (it : @bench.T) {
  lift_access_fields_bench(it, 5, true)
}

///|
test "bench lift access fields warm-positive32 projected" (it : @bench.T) {
  lift_access_fields_bench(it, 5, false)
}
