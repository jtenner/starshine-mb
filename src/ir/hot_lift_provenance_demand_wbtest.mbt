///|
test "optional lift provenance preserves complete graphs captures and lowered bodies" {
  for
    source in [
      "(module (func (param i32 externref) (local i32 externref) local.get 0 i32.const 7 local.set 0 local.tee 2 drop local.get 1 local.set 3 block local.get 2 if local.get 3 drop else local.get 1 local.set 3 end end unreachable local.set 2 local.get 1 drop))",
      "(module (func (param i32) (result i32 i64) block (result i32 i64) local.get 0 i64.const 9 end))",
      "(module (memory 1) (func (param i32) (result i32) (local i32) local.get 0 i32.load local.set 1 local.get 1 i32.const 3 i32.div_s))",
    ] {
    let input = @wast.wast_to_binary_module(source).unwrap()
    let context = hot_module_context_from_module(input)
    for captures in [false, true] {
      let recorded = hot_lift_func_with_context_result(
        input,
        @lib.FuncIdx::new(0U),
        context,
        capture_stack_locals=captures,
        materialize_multi_values=true,
      ).unwrap()
      let omitted = hot_lift_func_with_context_result(
        input,
        @lib.FuncIdx::new(0U),
        context,
        capture_stack_locals=captures,
        materialize_multi_values=true,
        record_local_accesses=false,
      ).unwrap()
      assert_true(recorded.lifted_local_accesses is Some(_))
      assert_true(omitted.lifted_local_accesses is None)
      assert_eq(hot_node_count(recorded), hot_node_count(omitted))
      assert_eq(hot_revision_current(recorded), hot_revision_current(omitted))
      assert_eq(hot_local_count(recorded), hot_local_count(omitted))
      for id in 0..<hot_node_count(recorded) {
        @debug.assert_eq(hot_node_get(recorded, id), hot_node_get(omitted, id))
        for slot in 0..<hot_node_get(recorded, id).child_count {
          assert_eq(
            hot_child_get(recorded, id, slot),
            hot_child_get(omitted, id, slot),
          )
        }
      }
      hot_verify_all_or_abort(recorded)
      hot_verify_all_or_abort(omitted)
      @debug.assert_eq(hot_lower_func(recorded), hot_lower_func(omitted))
    }
  }
}

///|
test "optional lift provenance preserves malformed-body first errors" {
  // Intentionally invalid operands and locals retain the normal validation path.
  for
    body in [
      "local.get 99", "local.set 0", "f32.const 1 local.set 0", "block f64.const 1 i32.eqz end local.get 99",
    ] {
    let input = @wast.wast_to_binary_module(
      "(module (func (param i32) " + body + "))",
    ).unwrap()
    let context = hot_module_context_from_module(input)
    let a = hot_lift_func_with_context_result(
      input,
      @lib.FuncIdx::new(0U),
      context,
    ).unwrap_err()
    let b = hot_lift_func_with_context_result(
      input,
      @lib.FuncIdx::new(0U),
      context,
      record_local_accesses=false,
    ).unwrap_err()
    assert_eq(a, b)
  }
}

///|
test "explicit lift provenance keeps source order and unreachable write placeholders" {
  let input = lift_step_fixture()
  let hot = hot_lift_func_with_context_result(
    input,
    @lib.FuncIdx::new(0U),
    hot_module_context_from_module(input),
    record_local_accesses=true,
  ).unwrap()
  let accesses = hot_lift_local_accesses(hot)
  assert_eq(accesses.gets.map(fn(pair) { pair.0 }), [0, 1, 0])
  assert_eq(accesses.writes.map(fn(pair) { pair.0 }), [1, 0, 1])
  assert_eq(accesses.writes[2].1, -1)
  assert_eq(accesses.revision, hot_revision_current(hot))
}
