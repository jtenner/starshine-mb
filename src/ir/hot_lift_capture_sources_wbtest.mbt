///|
/// Install only after the baseline writer-cut runtime RED and candidate API.
test "capture source journal preserves all three creator paths and complete HOT" {
  for
    (text, index) in [
      (
        "(module (func (param i32) (result i32) local.get 0 i32.const 7 local.set 0 i32.const 1 i32.add))",
        0,
      ),
      (
        "(module (import \"m\" \"p\" (func $p (result i32))) (func (result i32) call $p loop nop end i32.const 1 i32.add))",
        1,
      ),
      (
        "(module (import \"m\" \"p\" (func $p (result i32 i64))) (func (result i32 i64) call $p))",
        1,
      ),
    ] {
    let input = @wast.wast_to_binary_module(text).unwrap()
    @validate.validate_module(input).unwrap()
    let context = hot_module_context_from_module(input)
    let plain = hot_lift_func_with_context_result(
      input,
      @lib.FuncIdx::new(index.to_uint()),
      context,
      capture_stack_locals=true,
      materialize_multi_values=true,
    ).unwrap()
    let recorded = hot_lift_func_with_context_result(
      input,
      @lib.FuncIdx::new(index.to_uint()),
      context,
      capture_stack_locals=true,
      materialize_multi_values=true,
      record_capture_sources=true,
    ).unwrap()
    assert_eq(hot_node_count(plain), hot_node_count(recorded))
    assert_eq(hot_local_count(plain), hot_local_count(recorded))
    assert_eq(plain.children, recorded.children)
    assert_eq(plain.roots, recorded.roots)
    assert_eq(hot_revision_current(plain), hot_revision_current(recorded))
    for node in 0..<hot_node_count(plain) {
      @debug.assert_eq(hot_node_get(plain, node), hot_node_get(recorded, node))
    }
    let accesses = hot_lift_local_accesses(recorded)
    let pairs = accesses.capture_sources.unwrap()
    assert_true(pairs.length() > 0)
    assert_eq(hot_local_count(recorded), accesses.local_count + pairs.length())
    assert_true(hot_lift_local_accesses(plain).capture_sources is None)
    for pair in 0..<pairs.length() {
      let (read, write) = pairs[pair]
      let get = hot_node_get(recorded, read)
      let set = hot_node_get(recorded, write)
      assert_true(get.op is LocalGet)
      assert_true(set.op is LocalSet)
      assert_eq(get.imm0, accesses.local_count + pair)
      assert_eq(set.imm0, get.imm0)
      assert_true(write < read)
    }
    hot_verify_all_or_abort(plain)
    hot_verify_all_or_abort(recorded)
    @debug.assert_eq(hot_lower_func(plain), hot_lower_func(recorded))
  }
}

///|
test "capture source journal retains intentionally invalid input first errors" {
  for body in ["local.get 99", "local.set 0", "f32.const 1 local.set 0"] {
    let input = @wast.wast_to_binary_module(
      "(module (func (param i32) " + body + "))",
    ).unwrap()
    let context = hot_module_context_from_module(input)
    let a = hot_lift_func_with_context_result(
      input,
      @lib.FuncIdx::new(0U),
      context,
      capture_stack_locals=true,
      materialize_multi_values=true,
    ).unwrap_err()
    let b = hot_lift_func_with_context_result(
      input,
      @lib.FuncIdx::new(0U),
      context,
      capture_stack_locals=true,
      materialize_multi_values=true,
      record_capture_sources=true,
    ).unwrap_err()
    assert_eq(a, b)
  }
}
