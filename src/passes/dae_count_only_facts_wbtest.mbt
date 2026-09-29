///|
test "DAE count-only queries preserve direct dropped tail and escaped facts without full infos" {
  let input = pass_test_module_from_wat(
    "(module (type $sig (func (param i32) (result i32))) (func $helper (type $sig) local.get 0) (elem declare func $helper) (func (export \"run\") (param i32) (result i32) local.get 0 if i32.const 1 call $helper drop else block i32.const 2 call $helper drop end end ref.func $helper drop local.get 0 return_call $helper unreachable i32.const 4 call $helper drop))",
  )
  let builds = [0]
  let actual = dae_collect_current_call_facts(
    input,
    2,
    function_info_builds=Some(builds),
  )
  let expected = dae_collect_current_function_analysis(input, 2).call_facts
  assert_true(dae_current_call_facts_equal(actual, expected))
  assert_eq(actual.direct_calls, [3, 0])
  assert_eq(actual.dropped_calls, [2, 0])
  assert_eq(actual.tail_calls, [true, false])
  assert_true(actual.escaped[0])
  assert_eq(actual.direct_callers, [[1], []])
  assert_eq(builds[0], 0)
  let fresh = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0) (func (export \"run\") (result i32) i32.const 7 call 0))",
  )
  let next = dae_collect_current_call_facts(fresh, 2)
  assert_eq(next.direct_calls, [1, 0])
  assert_eq(next.dropped_calls, [0, 0])
  assert_false(next.tail_calls[0])
  assert_false(next.escaped[0])
  for name in ["dae", "dae-optimizing"] {
    @validate.validate_module(
      run_hot_pipeline(fresh, HotPipelineOptions::new(), [name]).unwrap(),
    ).unwrap()
  }
}
