///|
fn dae2_child_fixture() -> (@ir.HotFunc, Int, Int, Int) {
  let func = @ir.HotFunc::new()
  let left = @ir.hot_build_const_i32(func, @lib.I32(1))
  let right = @ir.hot_build_const_i32(func, @lib.I32(2))
  let add = @ir.hot_build_binary(func, @lib.ValType::i32(), left, right)
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  @ir.hot_root_append(func, @ir.hot_build_drop(func, add))
  (func, add, left, right)
}

///|
test "DAE2 retains an unchanged child span without moving its storage" {
  let (func, add, left, right) = dae2_child_fixture()
  let original_base = @ir.hot_node_get(func, add).child_base
  assert_false(dae2_replace_children_if_changed(func, add, [left, right]))
  assert_eq(@ir.hot_node_get(func, add).child_base, original_base)
  assert_eq(@ir.hot_child_span(func, add), [left, right])
  @ir.hot_verify_core(func).unwrap()
}

///|
test "DAE2 changed child spans preserve order and compare current storage" {
  let (func, add, left, right) = dae2_child_fixture()
  assert_true(dae2_replace_children_if_changed(func, add, [right, left]))
  assert_eq(@ir.hot_child_span(func, add), [right, left])
  ignore(@ir.hot_replace_child_span(func, add, []))
  assert_true(dae2_replace_children_if_changed(func, add, [right, left]))
  assert_eq(@ir.hot_child_span(func, add), [right, left])
  @ir.hot_verify_core(func).unwrap()
}
