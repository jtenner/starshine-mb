///|
test "hot verify all rejects an invalid drop with a missing operand" {
  let func = HotFunc::new()
  let drop = hot_build_drop(func, HOT_NONE_NODE)
  hot_root_append(func, drop)
  // Builders permit staging sentinels; final verification must reject this
  // incomplete ordinary operand before lowering consumes it as a node ID.
  missing_operand_assert_rejected(func, drop, 0)
}

///|
fn missing_operand_assert_rejected(
  func : HotFunc,
  node : NodeId,
  slot : Int32,
) -> Unit raise {
  // Core admits staging sentinels; both final entry points must reject them.
  assert_eq(hot_verify_core(func), Ok(()))
  let expected = Err(
    HotVerifyError::InvalidControlChild(node, slot, HOT_NONE_NODE),
  )
  assert_eq(hot_verify_control(func), expected)
  assert_eq(hot_verify_all(func), expected)
  assert_eq(hot_verify_all(func, cache=Some(())), expected)
}

///|
test "hot verify rejects an invalid local set with a missing operand" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let set = hot_build_local_set(func, 0, HOT_NONE_NODE)
  hot_root_append(func, set)
  missing_operand_assert_rejected(func, set, 0)
}

///|
test "hot verify rejects either missing binary operand including detached nodes" {
  for slot in 0..<2 {
    let func = HotFunc::new()
    let value = hot_build_const_i32(func, @lib.I32(1))
    let binary = hot_build_binary(func, @lib.ValType::i32(), value, value)
    hot_node_exact_instr_set(func, binary, @lib.Instruction::i32_add())
    assert_eq(hot_verify_all(func), Ok(()))
    // A live detached node can be attached later and must also be checked.
    hot_child_set(func, binary, slot, HOT_NONE_NODE)
    missing_operand_assert_rejected(func, binary, slot)
  }
}

///|
test "hot verify rejects missing call arguments and indirect callees" {
  for kind in 0..<3 {
    for slot in 0..<2 {
      let func = HotFunc::new()
      let value = hot_build_const_i32(func, @lib.I32(1))
      let call = match kind {
        0 => hot_build_call(func, 0, [], [value, value])
        1 =>
          hot_build_call_indirect(
            func,
            @lib.TypeIdx::new(0U),
            @lib.TableIdx::new(0U),
            [],
            [value],
            value,
          )
        _ => hot_build_call_ref(func, @lib.TypeIdx::new(0U), [], [value], value)
      }
      hot_root_append(func, call)
      assert_eq(hot_verify_all(func), Ok(()))
      hot_child_set(func, call, slot, HOT_NONE_NODE)
      missing_operand_assert_rejected(func, call, slot)
    }
  }
}

///|
test "hot verify rejects a missing branch payload before lowering" {
  let func = HotFunc::new()
  hot_body_result_type_set(
    func,
    hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let branch = hot_build_br(func, HOT_IMPLICIT_FUNCTION_LABEL, values=[
    HOT_NONE_NODE,
  ])
  hot_root_append(func, branch)
  missing_operand_assert_rejected(func, branch, 0)
}

///|
test "hot verify accepts absent optional regions and zero argument calls" {
  let func = HotFunc::new()
  let condition = hot_build_const_i32(func, @lib.I32(1))
  let if_node = hot_build_if(func, @lib.BlockType::void_(), condition, [])
  let try_node = hot_build_try(func, @lib.BlockType::void_(), [])
  assert_eq(hot_child_get(func, if_node, 2), HOT_NONE_NODE)
  assert_eq(hot_child_get(func, try_node, 1), HOT_NONE_NODE)
  hot_root_append(func, if_node)
  hot_root_append(func, try_node)
  hot_root_append(func, hot_build_call(func, 0, [], []))
  assert_eq(hot_verify_all(func), Ok(()))
}
