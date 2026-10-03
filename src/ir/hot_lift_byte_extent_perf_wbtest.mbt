///|
fn lift_byte_extent_bench(
  it : @bench.T,
  kind : Int,
  original : Bool,
) -> Unit raise {
  let func = HotFunc::new(
    locals=HotLocals::new(
      locals=Array::make(
        if kind == 6 || kind == 7 {
          17000
        } else {
          400
        },
        @lib.ValType::i32(),
      ),
    ),
  )
  let payload = hot_alloc_instr_payload(
    func,
    HotInstrPayload::new(@lib.Instruction::i32_add()),
  )
  assert_eq(payload, 0)
  let width = if kind == 0 { 0 } else if kind >= 8 { 512 } else { 32 }
  let local_id = if kind == 6 || kind == 7 { 16384 } else { 0 }
  let mut value = hot_build_local_get(func, local_id)
  for i in 0..<width {
    value = hot_build_binary(
      func,
      @lib.ValType::i32(),
      value,
      hot_build_const_i32(func, @lib.I32(i)),
    )
  }
  hot_root_append(func, hot_build_drop(func, value))
  let checked : Result[Unit, HotVerifyError] = hot_verify_all(func)
  checked.unwrap()
  let query = if kind == 2 || kind == 5 || kind == 9 {
    64
  } else if kind == 3 {
    1
  } else if kind == 7 {
    16448
  } else if kind == 6 {
    16384
  } else {
    0
  }
  let cold = kind == 4 || kind == 5
  let actual = Some(HotLiftLocalAccessMasks::new())
  let before = Some(HotLiftLocalAccessReferenceMasks::new())
  // Warm identical completed trees through an irrelevant query first.
  assert_false(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      value,
      1,
      true,
      masks=actual,
    ),
  )
  assert_false(
    lift_extent_reference_conflict(func, value, 1, true, masks=before),
  )
  assert_eq(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      value,
      query,
      true,
      masks=actual,
    ),
    lift_extent_reference_conflict(func, value, query, true, masks=before),
  )
  let revision = hot_revision_current(func)
  it.bench(fn() {
    it.keep(
      if original {
        let selected = if cold {
          Some(HotLiftLocalAccessReferenceMasks::new())
        } else {
          before
        }
        lift_extent_reference_conflict(func, value, query, true, masks=selected)
      } else {
        let selected = if cold {
          Some(HotLiftLocalAccessMasks::new())
        } else {
          actual
        }
        hot_lift_impl_value_conflicts_with_local_access(
          func,
          value,
          query,
          true,
          masks=selected,
        )
      },
    )
  })
  assert_eq(hot_revision_current(func), revision)
}

///|
test "bench lift byte leaf-control before" (it : @bench.T) {
  lift_byte_extent_bench(it, 0, true)
}

///|
test "bench lift byte leaf-control extent" (it : @bench.T) {
  lift_byte_extent_bench(it, 0, false)
}

///|
test "bench lift byte warm-positive32 before" (it : @bench.T) {
  lift_byte_extent_bench(it, 1, true)
}

///|
test "bench lift byte warm-positive32 extent" (it : @bench.T) {
  lift_byte_extent_bench(it, 1, false)
}

///|
test "bench lift byte warm-collision32 before" (it : @bench.T) {
  lift_byte_extent_bench(it, 2, true)
}

///|
test "bench lift byte warm-collision32 extent" (it : @bench.T) {
  lift_byte_extent_bench(it, 2, false)
}

///|
test "bench lift byte warm-negative32 before" (it : @bench.T) {
  lift_byte_extent_bench(it, 3, true)
}

///|
test "bench lift byte warm-negative32 extent" (it : @bench.T) {
  lift_byte_extent_bench(it, 3, false)
}

///|
test "bench lift byte cold-positive32 before" (it : @bench.T) {
  lift_byte_extent_bench(it, 4, true)
}

///|
test "bench lift byte cold-positive32 extent" (it : @bench.T) {
  lift_byte_extent_bench(it, 4, false)
}

///|
test "bench lift byte cold-collision32 before" (it : @bench.T) {
  lift_byte_extent_bench(it, 5, true)
}

///|
test "bench lift byte cold-collision32 extent" (it : @bench.T) {
  lift_byte_extent_bench(it, 5, false)
}

///|
test "bench lift byte saturated-positive32 before" (it : @bench.T) {
  lift_byte_extent_bench(it, 6, true)
}

///|
test "bench lift byte saturated-positive32 extent" (it : @bench.T) {
  lift_byte_extent_bench(it, 6, false)
}

///|
test "bench lift byte saturated-collision32 before" (it : @bench.T) {
  lift_byte_extent_bench(it, 7, true)
}

///|
test "bench lift byte saturated-collision32 extent" (it : @bench.T) {
  lift_byte_extent_bench(it, 7, false)
}

///|
test "bench lift byte warm-positive512 before" (it : @bench.T) {
  lift_byte_extent_bench(it, 8, true)
}

///|
test "bench lift byte warm-positive512 extent" (it : @bench.T) {
  lift_byte_extent_bench(it, 8, false)
}

///|
test "bench lift byte warm-collision512 before" (it : @bench.T) {
  lift_byte_extent_bench(it, 9, true)
}

///|
test "bench lift byte warm-collision512 extent" (it : @bench.T) {
  lift_byte_extent_bench(it, 9, false)
}
