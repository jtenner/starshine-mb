///|
fn node0_fixture(kind : Int) -> (HotFunc, HotOp, TypeId, Int, Int) {
  let func = HotFunc::new()
  match kind {
    0 => (func, HotOp::Nop, hot_type_void(func), 0, 0)
    1 => {
      let payload = hot_alloc_const(
        func,
        HotConstPayload::i32_const(@lib.I32(-7)),
      )
      (
        func,
        HotOp::Const,
        hot_type_intern_value(func, @lib.ValType::i32()),
        payload,
        0,
      )
    }
    2 => {
      let seed = hot_build_const_i32(func, @lib.I32(11))
      let holder = hot_build_drop(func, seed)
      hot_delete_node(func, holder)
      (func, HotOp::Unreachable, hot_type_void(func), 0, 0)
    }
    _ => {
      let value = @lib.RefType::abs(@lib.AbsHeapType::extern_())
      let payload = hot_alloc_const(
        func,
        HotConstPayload::ref_null_const(value),
      )
      (
        func,
        HotOp::RefNull,
        hot_type_intern_value(func, @lib.ValType::ref_null_type(value)),
        payload,
        0,
      )
    }
  }
}

///|
test "zero-child factory retains exact fields payloads order and revision" {
  for kind in [0, 1, 3] {
    let (before, op, ty, imm0, imm1) = node0_fixture(kind)
    let (after, new_op, new_ty, new_imm0, new_imm1) = node0_fixture(kind)
    let revision = after.revision
    let expected = hot_build_node(before, op, ty, imm0~, imm1~)
    let actual = hot_build_node0(
      after,
      new_op,
      new_ty,
      imm0=new_imm0,
      imm1=new_imm1,
    )
    assert_eq(actual, expected)
    assert_eq(after.nodes, before.nodes)
    assert_eq(after.children, before.children)
    assert_eq(after.deleted_nodes, before.deleted_nodes)
    assert_eq(after.free_nodes, before.free_nodes)
    assert_eq(after.consts, before.consts)
    assert_eq(after.revision, revision + 1)
    assert_eq(after.revision, before.revision)
    assert_eq(hot_node_get(after, actual).child_base, 0)
    assert_eq(hot_child_count(after, actual), 0)
    assert_true(hot_verify_all(after, cache=Some(())).is_ok())
  }
}

///|
test "zero-child factory retains append semantics in an arena with deleted child spans" {
  let (before, op, ty, imm0, imm1) = node0_fixture(2)
  let (after, new_op, new_ty, new_imm0, new_imm1) = node0_fixture(2)
  let deleted = after.free_nodes.copy()
  let old_count = after.nodes.length()
  let expected = hot_build_node(before, op, ty, imm0~, imm1~)
  let actual = hot_build_node0(
    after,
    new_op,
    new_ty,
    imm0=new_imm0,
    imm1=new_imm1,
  )
  assert_eq(actual, expected)
  assert_eq(actual, old_count)
  assert_eq(after.free_nodes, deleted)
  assert_eq(after.nodes, before.nodes)
  assert_eq(after.children, before.children)
  assert_eq(after.deleted_nodes, before.deleted_nodes)
  assert_eq(after.revision, before.revision)
  assert_eq(hot_node_get(after, actual).child_base, 0)
  assert_eq(hot_child_count(after, actual), 0)
  assert_true(hot_verify_all(after, cache=Some(())).is_ok())
}
