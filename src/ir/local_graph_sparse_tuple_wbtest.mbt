///|
test "sparse tuple transfer retains exact path state across joins and shared producers" {
  for
    source in [
      "(module (func (param i32) (local i32 i32 i32) (if (result i32 i32) (local.get 0) (then (local.get 1) (local.set 1 (i32.const 7)) (i32.const 3)) (else (i32.const 2) (i32.const 4))) local.set 2 local.set 3 (drop (local.get 1))))",
      "(module (tag $e) (func (param i32) (local i32) (try (do (if (local.get 0) (then (local.set 1 (i32.const 7)) (throw $e)))) (catch $e (drop (local.get 1)))) (drop (local.get 1))))",
      "(module (func (param i32 i32) (local i32) block $exit loop $again local.get 0 if (result i32) i32.const 7 local.tee 1 else local.get 1 end local.set 2 local.get 2 br_if $exit i32.const 0 local.set 0 br $again end end local.get 1 drop))",
    ] {
    let mod_ = @wast.wast_to_binary_module(source).unwrap()
    let func = hot_lift_func_with_context_result(
      mod_,
      @lib.FuncIdx::new(0U),
      hot_module_context_from_module(mod_),
      capture_stack_locals=true,
      materialize_multi_values=true,
    ).unwrap()
    for expanded in [false, true] {
      let cfg = cfg_build(func, expand_operand_control=expanded)
      for block in 0..<cfg_block_count(cfg) {
        let initial = local_graph_entry_state(hot_local_count(func))
        let actual_gets = Array::makei(hot_node_count(func), fn(_) { [] })
        let expected_gets = Array::makei(hot_node_count(func), fn(_) { [] })
        let actual_influences = Array::makei(hot_node_count(func), fn(_) { [] })
        let expected_influences = Array::makei(hot_node_count(func), fn(_) {
          []
        })
        let actual = local_graph_transfer_block(
          func,
          cfg,
          block,
          initial,
          Some(actual_gets),
          Some(actual_influences),
        )
        let expected = local_graph_tuple_reference_block(
          func,
          cfg,
          block,
          initial,
          Some(expected_gets),
          Some(expected_influences),
        )
        assert_eq(actual, expected)
        assert_eq(actual_gets, expected_gets)
        assert_eq(actual_influences, expected_influences)
      }
    }
  }
}
