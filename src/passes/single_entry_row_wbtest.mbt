///|
test "single entry proof does not allocate a full local-index row" {
  let locals = Array::make(64, "i32").join(" ")
  let input = pass_test_module_from_wat(
    "(module (func (result i32) (local \{locals}) i32.const 7 local.set 63 local.get 63))",
  )
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let before = @ir.hot_lower_func(func)
  let revision = @ir.hot_revision_current(func)
  let facts = dae2_scan_write_facts(func)
  let slots = [0]
  let actual = dae2_entry_read_sources(
    func,
    known_writes=facts.sole,
    entry_row_slots=Some(slots),
  ).unwrap()
  assert_eq(actual, dae2_writefacts_reference_entry_sources(func).unwrap())
  let flow = @ir.local_graph_build_full_flow(func, @ir.cfg_build(func))
  for node in 0..<@ir.hot_node_count(func) {
    if @ir.hot_node_op(func, node) is @ir.LocalGet {
      let reaching = @ir.local_graph_reaching_sources_for_get(flow, node)
      assert_eq(reaching.length(), 1)
      let @ir.SetSource(write) = reaching[0]
      assert_eq(write, actual[node])
    }
  }
  assert_eq(slots[0], 0)
  assert_eq(@ir.hot_revision_current(func), revision)
  assert_eq(@ir.hot_lower_func(func), before)
}

///|
test "lazy entry rows preserve multiple admitted roots and repeated-root rejection" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  let first = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(7)),
  )
  let second = @ir.hot_build_local_set(
    func,
    1,
    @ir.hot_build_const_i32(func, @lib.I32(9)),
  )
  @ir.hot_root_append(func, first)
  @ir.hot_root_append(func, second)
  @ir.hot_root_append(func, @ir.hot_build_local_get(func, 0))
  @ir.hot_root_append(func, @ir.hot_build_local_get(func, 1))
  assert_eq(
    dae2_entry_read_sources(func),
    dae2_writefacts_reference_entry_sources(func),
  )
  @ir.hot_root_append(func, first)
  assert_true(dae2_entry_read_sources(func) is None)
  assert_true(dae2_writefacts_reference_entry_sources(func) is None)
}
