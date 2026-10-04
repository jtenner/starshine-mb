///|
fn lift_step_fixture() -> @lib.Module {
  @wast.wast_to_binary_module(
    (
      #|(module
      #|  (func (param i32) (local i32)
      #|    local.get 0 local.tee 1 drop
      #|    i32.const 3 local.set 0
      #|    block local.get 1 drop end
      #|    unreachable local.set 1 local.get 0 drop))
    ),
  ).unwrap()
}

///|
test "lift instruction results preserve ordered source accesses and unreachable placeholders" {
  let input = lift_step_fixture()
  for captures in [false, true] {
    let hot = hot_lift_func_with_context_result(
      input,
      @lib.FuncIdx::new(0U),
      hot_module_context_from_module(input),
      capture_stack_locals=captures,
      materialize_multi_values=true,
    ).unwrap()
    let accesses = hot_lift_local_accesses(hot)
    assert_eq(accesses.gets.map(fn(pair) { pair.0 }), [0, 1, 0])
    assert_eq(accesses.writes.map(fn(pair) { pair.0 }), [1, 0, 1])
    assert_eq(accesses.writes[2].1, -1)
    for (_, node) in accesses.gets {
      assert_eq(hot_node_get(hot, node).op, HotOp::LocalGet)
    }
    assert_eq(hot_node_get(hot, accesses.writes[0].1).op, HotOp::LocalTee)
    assert_eq(hot_node_get(hot, accesses.writes[1].1).op, HotOp::LocalSet)
    hot_verify_all_or_abort(hot)
    assert_eq(accesses.revision, hot_revision_current(hot))
  }
}

///|
test "lift instruction results retain the first concrete type error" {
  // These invalid bodies deliberately exercise failure before later bad locals.
  for
    body in [
      "i32.add local.get 99", "f32.const 1 i32.const 2 i32.add local.get 99", "block f64.const 1 i32.eqz end local.get 99",
    ] {
    let input = @wast.wast_to_binary_module("(module (func " + body + "))").unwrap()
    let result = hot_lift_func_with_context_result(
      input,
      @lib.FuncIdx::new(0U),
      hot_module_context_from_module(input),
    )
    match result {
      Err(TypecheckFailure(instruction, _)) =>
        assert_true(instruction == "i32.add" || instruction == "i32.eqz")
      _ => fail("invalid lift must retain its first instruction type error")
    }
  }
}

///|
test "lift instruction results retain reference tuple branch and tail-call state" {
  for
    source in [
      (
        #|(module (type $s (struct (field i32)))
        #| (func $pair (result (ref $s) i64) i32.const 7 struct.new $s i64.const 9)
        #| (func (param i32) (result (ref $s) i64)
        #|  local.get 0 if (result (ref $s) i64) call $pair else return_call $pair end))
      ),
      (
        #|(module (func (param i32) (result i32)
        #| block (result i32) i32.const 7 local.get 0 br_if 0 drop i32.const 9 end))
      ),
    ] {
    let input = @wast.wast_to_binary_module(source).unwrap()
    let context = hot_module_context_from_module(input)
    let bodies = input.code_sec.unwrap().0
    for index in 0..<bodies.length() {
      let hot = hot_lift_func_with_context_result(
        input,
        @lib.FuncIdx::new(index.reinterpret_as_uint()),
        context,
        capture_stack_locals=true,
        materialize_multi_values=true,
      ).unwrap()
      hot_verify_all_or_abort(hot)
      let lowered = hot_lower_func(hot)
      let types = hot_module_resolve_func_type(
        context,
        @lib.FuncIdx::new(index.reinterpret_as_uint()),
      ).unwrap()
      assert_true(
        @validate.validate_func_body_against_functype(
          hot_module_context_validation_env(context),
          types,
          lowered,
        )
        is Ok(_),
      )
    }
  }
}
