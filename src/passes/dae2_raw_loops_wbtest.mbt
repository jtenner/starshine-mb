///|
test "DAE2 raw loops preserve sparse local backedges and overwrite precision" {
  for
    body in [
      "local.get 1 local.set 4 loop $again local.get 4 i32.const 1 i32.sub local.set 4 local.get 4 br_if $again end local.get 4",
      "local.get 1 local.set 4 loop $again local.get 0 if local.get 2 local.set 4 br $again end end local.get 4",
      "loop $again local.get 0 if local.get 1 local.set 4 br $again end local.get 2 local.set 4 end local.get 4",
      "loop $again local.get 4 local.set 4 local.get 0 br_if $again end i32.const 7",
      "local.get 1 local.set 4 loop $again i32.const 7 local.set 4 local.get 0 br_if $again end local.get 4",
      "local.get 1 local.set 4 local.get 2 local.set 5 loop $again local.get 4 local.get 5 local.set 4 local.set 5 local.get 0 br_if $again end local.get 4",
      "loop $again (result i32) local.get 0 if br $again end local.get 1 end", "block $out (result i32) loop $again local.get 0 if local.get 1 br $out end local.get 0 br_if $again end local.get 2 end",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func $h (param i32 i32 i32 i64) (result i32) (local i32 i32) \{body}) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
    )
    raw_conditional_compare_boundaries(input, 2)
    let lifts = [0]
    ignore(
      dae2_run_module_pass(input, false, analysis_lifts=Some(lifts)).unwrap(),
    )
    assert_eq(lifts[0], 0)
  }
}

///|
test "DAE2 raw indexed scalar loop entries preserve initial and backedge payload demand" {
  for
    body in [
      "local.get 1 loop $again (type $one) local.set 4 local.get 4 i32.const 1 i32.sub local.get 0 br_if $again drop end local.get 4",
      "local.get 1 loop $again (type $one) drop local.get 2 local.get 0 br_if $again drop end i32.const 7",
      "local.get 1 loop $again (type $one) local.set 4 local.get 0 if local.get 2 br $again end end local.get 4",
      "local.get 1 loop $again (type $one_result) local.tee 4 local.get 0 br_if $again end",
      "local.get 1 loop $again (type $one_result) local.set 4 local.get 0 if local.get 2 br $again end local.get 4 end",
    ] {
    let input = pass_test_module_from_wat(
      "(module (type $one (func (param i32))) (type $one_result (func (param i32) (result i32))) (func $h (param i32 i32 i32 i64) (result i32) (local i32) \{body}) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
    )
    raw_conditional_compare_boundaries(input, 2)
    let lifts = [0]
    ignore(
      dae2_run_module_pass(input, false, analysis_lifts=Some(lifts)).unwrap(),
    )
    assert_eq(lifts[0], 0)
  }
}

///|
test "DAE2 raw loop phi events preserve entries of skipped enclosing regions" {
  for
    body in [
      "local.get 1 local.set 4 block $out local.get 0 br_if $out loop $again local.get 2 local.set 4 local.get 0 br_if $again end i32.const 9 local.set 4 end local.get 4",
      "block $out local.get 0 br_if $out loop $again local.get 2 local.set 4 local.get 0 br_if $again end i32.const 9 local.set 4 end local.get 4",
      "local.get 1 local.set 4 block $out loop $again local.get 0 if local.get 4 return end local.get 4 i32.const 1 i32.sub local.set 4 local.get 4 br_if $out br $again end end local.get 4",
      "local.get 1 local.set 4 block $out loop $outer local.get 0 if br $out end loop $inner local.get 4 i32.const 1 i32.sub local.set 4 local.get 4 br_if $inner end br $outer end end local.get 4",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func $h (param i32 i32 i32 i64) (result i32) (local i32) \{body}) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
    )
    raw_conditional_compare_boundaries(input, 2)
  }
}

///|
test "DAE2 raw loops preserve effects traps and dead whole-result demand" {
  for
    body in [
      "local.get 1 local.set 4 loop $again local.get 4 i32.load local.set 4 local.get 0 br_if $again end local.get 4",
      "loop $again local.get 0 if unreachable end local.get 1 i32.const 7 i32.store end local.get 2",
      "loop $again (result i32) local.get 0 if br $again end local.get 1 end", "local.get 1 loop $again (type $one) drop local.get 2 local.get 0 br_if $again drop end i32.const 7",
    ] {
    let input = pass_test_module_from_wat(
      "(module (memory 1) (type $one (func (param i32))) (func $h (param i32 i32 i32 i64) (result i32) (local i32) \{body}) (func (export \"run\") (param i32 i32 i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h drop))",
    )
    raw_conditional_compare_boundaries(input, 2)
  }
}

///|
test "DAE2 raw diverging loops keep the least fixed point and observed entry payloads" {
  for
    body in [
      "loop $again local.get 4 local.set 4 br $again end", "local.get 1 loop $again (type $one) drop local.get 2 br $again end",
    ] {
    let input = pass_test_module_from_wat(
      "(module (type $one (func (param i32))) (func $h (param i32 i32 i32 i64) (local i32) \{body}) (func (export \"run\") (param i32 i32 i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
    )
    raw_conditional_compare_boundaries(input, 2)
  }
}

///|
fn raw_loop_nested_target_locals(depth : Int32, width : Int32) -> @lib.Module {
  let locals = Array::make(width, "i32").join(" ")
  let loops = Array::makei(depth, fn(i) { "loop $again\{i}" }).join(" ")
  let writes = Array::makei(width, fn(i) { "local.get 1 local.set \{i + 4}" }).join(
    " ",
  )
  let targets = Array::makei(depth, fn(i) { "$again\{i}" }).join(" ")
  pass_test_module_from_wat(
    "(module (func $h (param i32 i32 i32 i64) (local \{locals}) \{loops} \{writes} local.get 0 br_table \{targets} \{Array::make(depth, "end").join(" ")}) (func (export \"run\") (param i32 i32 i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
  )
}

///|
test "DAE2 raw loop resource guard intentionally delegates nested wide phi state to HOT" {
  let input = raw_loop_nested_target_locals(32, 32)
  let (graph, info, plan) = raw_forward_resource_plan(input)
  assert_true(plan is None)
  assert_eq(graph.used.length(), info.params.length() + 1)
  assert_eq(graph.edges.length(), 0)
  raw_conditional_compare_boundaries(input, 1)
  let output = dae2_run_module_pass(input, false).unwrap()
  let @lib.FuncType(params, _) = @ir.hot_module_resolve_func_type(
    @ir.hot_module_context_from_module(output),
    @lib.FuncIdx::new(0U),
  ).unwrap()
  assert_eq(params.length(), 1)
}
