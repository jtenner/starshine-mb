///|
test "lift exact local conflicts visit shared operands once per query and retain access direction" {
  let func = HotFunc::new()
  assert_eq(
    hot_alloc_instr_payload(
      func,
      HotInstrPayload::new(@lib.Instruction::i32_add()),
    ),
    0,
  )
  for _ in 0..<129 {
    ignore(hot_append_body_local(func, @lib.ValType::i32()))
  }
  let read64 = hot_build_local_get(func, 64)
  let read128 = hot_build_local_get(func, 128)
  let mut value = hot_build_binary(func, @lib.ValType::i32(), read64, read128)
  for _ in 0..<12 {
    value = hot_build_binary(func, @lib.ValType::i32(), value, value)
  }
  hot_root_append(func, hot_build_drop(func, value))
  let valid : Result[Unit, HotVerifyError] = hot_verify_all(func)
  valid.unwrap()
  let masks = HotLiftLocalAccessMasks::new()
  hot_lift_impl_collect_local_access_masks(func, value, masks, None)
  let visits = [0]
  assert_false(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      value,
      0,
      true,
      masks=Some(masks),
      node_visits=Some(visits),
    ),
  )
  assert_true(
    visits[0] <= 4 * hot_node_count(func),
    msg="exact mixed-band conflict expanded a shared operand repeatedly",
  )
  assert_true(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      value,
      64,
      true,
      masks=Some(masks),
    ),
  )
  assert_false(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      value,
      64,
      false,
      masks=Some(masks),
    ),
  )
  assert_true(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      value,
      128,
      true,
      masks=Some(masks),
    ),
  )
  assert_false(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      value,
      0,
      true,
      masks=Some(masks),
    ),
  )
  let write64 = hot_build_local_tee(
    func,
    64,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  let mixed = hot_build_binary(func, @lib.ValType::i32(), value, write64)
  assert_true(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      mixed,
      64,
      false,
      masks=Some(masks),
    ),
  )
  assert_true(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      mixed,
      64,
      true,
      masks=Some(masks),
    ),
  )
  let saved_reads = masks.reads.copy()
  let saved_writes = masks.writes.copy()
  ignore(hot_build_const_i32(func, @lib.I32(19)))
  assert_false(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      value,
      0,
      true,
      masks=Some(masks),
    ),
  )
  assert_eq(masks.reads, saved_reads)
  assert_eq(masks.writes, saved_writes)
}
