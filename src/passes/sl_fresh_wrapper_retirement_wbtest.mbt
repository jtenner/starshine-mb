///|
test "SL replacement factories retain exact source order and retire fresh nodes without arena ownership scans" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32) local.get 0 local.set 1 local.get 1))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let set_id = @ir.hot_root_get(func, 0)
  let value_id = @ir.hot_child_get(func, set_id, 0)
  let set_order = @ir.hot_node_get(func, set_id).order
  let value_order = @ir.hot_node_get(func, value_id).order
  let scans = [0]
  for kind in 0..<5 {
    let nodes_before = @ir.hot_node_count(func)
    let replacement = match kind {
      0 => simplify_locals_make_nop(func, retirement_scans=Some(scans))
      1 =>
        simplify_locals_make_drop(func, value_id, retirement_scans=Some(scans))
      2 => simplify_locals_make_local_get(func, 1, retirement_scans=Some(scans))
      3 =>
        simplify_locals_make_local_tee(
          func,
          set_id,
          retirement_scans=Some(scans),
        )
      _ =>
        simplify_locals_make_local_set(
          func,
          1,
          value_id,
          retirement_scans=Some(scans),
        )
    }
    assert_eq(@ir.hot_node_count(func), nodes_before + 1)
    assert_false(@ir.hot_node_is_live(func, nodes_before))
    assert_true(
      match (kind, replacement.op) {
        (0, @ir.Nop)
        | (1, @ir.Drop)
        | (2, @ir.LocalGet)
        | (3, @ir.LocalTee)
        | (4, @ir.LocalSet) => true
        _ => false
      },
    )
    assert_eq(
      replacement.order,
      if kind == 3 {
        set_order
      } else if kind == 4 {
        value_order
      } else {
        nodes_before
      },
    )
    assert_eq(
      replacement.child_count,
      if kind == 0 || kind == 2 {
        0
      } else {
        1
      },
    )
    if replacement.child_count == 1 {
      assert_eq(func.children[replacement.child_base], value_id)
    }
    assert_eq(replacement.flags, @ir.hot_default_flags_for_op(replacement.op))
    assert_eq(scans[0], 0)
    @ir.hot_verify_all(func).unwrap()
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "SL wrapper extraction retains checked ownership scanning for older detached nodes" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0))",
  )
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let older = @ir.hot_build_local_get(func, 0)
  let newer = @ir.hot_build_nop(func)
  let scans = [0]
  let replacement = simplify_locals_take_new_wrapper(func, older, Some(scans))
  assert_true(replacement.op is @ir.LocalGet)
  assert_eq(replacement.imm0, 0)
  assert_false(@ir.hot_node_is_live(func, older))
  assert_true(@ir.hot_node_is_live(func, newer))
  assert_eq(scans[0], 1)
  @ir.hot_verify_all(func).unwrap()
}
