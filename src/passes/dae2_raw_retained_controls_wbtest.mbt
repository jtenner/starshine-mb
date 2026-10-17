///|
test "DAE2 recursive replay retains demanded scalar block if and loop results without HOT" {
  for
    region in [
      "block (result i32) local.get 0 local.get 1 i32.const 3 i32.add call $h end",
      "local.get 0 if (result i32) local.get 0 local.get 1 i32.const 3 i32.add call $h else local.get 1 local.get 0 i32.const 2 i32.add call $h end",
      "loop (result i32) local.get 0 local.get 1 i32.const 3 i32.add call $h end",
      "local.get 1 i32.const 10 i32.add block (result i32) local.get 0 local.get 1 i32.const 3 i32.add call $h end i32.add",
      "local.get 1 i32.const 10 i32.add local.get 0 if (result i32) local.get 0 local.get 1 i32.const 3 i32.add call $h else local.get 1 local.get 0 i32.const 2 i32.add call $h end i32.add",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func $h (param i32 i32) (result i32) local.get 0) (func (export \"run\") (param i32 i32) (result i32) \{region}))",
    )
    raw_structured_rewrite_compare(input, label=region)
  }
}

///|
test "DAE2 recursive replay retains indexed scalar loop results with zero or one entry parameter" {
  for
    body in [
      "loop (type $out) local.get 0 local.get 1 i32.const 3 i32.add call $h end",
      "local.get 0 loop (type $in) i32.const 1 i32.add local.get 1 i32.const 3 i32.add call $h end",
    ] {
    let input = pass_test_module_from_wat(
      "(module (type $out (func (result i32))) (type $in (func (param i32) (result i32))) (func $h (param i32 i32) (result i32) local.get 0) (func (export \"run\") (param i32 i32) (result i32) \{body}))",
    )
    raw_structured_rewrite_compare(input, label=body)
  }
}

///|
test "DAE2 recursive replay retains scalar forward branch payloads and terminal arms" {
  for
    region in [
      "block $out (result i32) local.get 0 if local.get 0 local.get 1 i32.const 3 i32.add call $h br $out end local.get 1 local.get 0 i32.const 2 i32.add call $h end",
      "local.get 0 if (result i32) local.get 0 local.get 1 i32.const 3 i32.add call $h return else local.get 1 local.get 0 i32.const 2 i32.add call $h end",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func $h (param i32 i32) (result i32) local.get 0) (func (export \"run\") (param i32 i32) (result i32) \{region}))",
    )
    raw_structured_rewrite_compare(input, label=region)
  }
}

///|
test "DAE2 recursive replay retains scalar loop results on conditional backedges" {
  for
    body in [
      "loop $again (result i32) local.get 0 local.get 1 i32.const 3 i32.add call $h local.get 0 i32.const 1 i32.sub local.tee 0 br_if $again end",
      "local.get 0 loop $again (type $in) i32.const 1 i32.add local.get 1 i32.const 3 i32.add call $h local.get 0 i32.const 1 i32.sub local.tee 0 br_if $again end",
    ] {
    let input = pass_test_module_from_wat(
      "(module (type $in (func (param i32) (result i32))) (func $h (param i32 i32) (result i32) local.get 0) (func (export \"run\") (param i32 i32) (result i32) \{body}))",
    )
    if body.starts_with("loop") {
      let expected = pass_test_module_from_wat(
          "(module (func (param i32) (result i32) local.get 0) (func (param i32 i32) (result i32) loop $again (result i32) local.get 0 call 0 local.get 0 i32.const 1 i32.sub local.tee 0 br_if $again end))",
        ).code_sec.unwrap().0[1]
      // A void backedge discards the held call result on the taken edge;
      // fallthrough returns that same value. Keep the natural stack form:
      // two fewer local operations, smaller raw bytes, no cleanup size loss.
      // Effectful and indexed variants have 60 original/raw/HOT observations and
      // verified v133 canonical/downstream/O2 sizes in indexed-result-semantics.
      raw_structured_held_shape_compare(input, expected, body, strict_gain=true)
    } else {
      raw_structured_rewrite_compare(input, label=body)
    }
  }
}

///|
test "DAE2 recursive replay preserves retained control result writes traps and effect order" {
  for dead in ["local.get 1 i32.load", "call $value"] {
    let input = pass_test_module_from_wat(
      "(module (import \"e\" \"value\" (func $value (result i32))) (memory 1) (global $g (mut i32) (i32.const 0)) (func $h (param i32 i32) (result i32) local.get 0 global.set $g local.get 0) (func (export \"run\") (param i32 i32) (result i32) (local i32) local.get 0 if (result i32) local.get 0 \{dead} call $h local.tee 2 else local.get 1 \{dead} call $h local.tee 2 end local.get 2 i32.add))",
    )
    raw_structured_rewrite_compare(input, label=dead)
  }
}

///|
test "DAE2 recursive replay removes dead plain scalar result headers atomically" {
  let input = pass_test_module_from_wat(
    "(module (func (export \"run\") (param i32) local.get 0 if (result i32) i32.const 7 else i32.const 9 end drop))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let (graph, info, candidate) = raw_forward_resource_plan(input)
  let plan = candidate.unwrap()
  plan.commit(graph)
  info.raw_analysis = true
  info.raw_write_locations = plan.write_locations
  graph.solve()
  let used = graph.used.copy()
  let edges = graph.edges.copy()
  let work = graph.work.copy()
  let result = dae2_rewrite_raw_structured_function(
    graph,
    [info],
    0,
    input.code_sec.unwrap().0[0],
    @ir.hot_module_context_from_module(input),
    info.params,
    [],
  )
  let (rewritten, local_map) = result.unwrap()
  let @lib.Func(_, @lib.Expr(body)) = rewritten
  assert_eq(body, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::if_(@lib.BlockType::void_(), [], Some([])),
  ])
  assert_eq(local_map, [0])
  assert_eq(graph.used, used)
  assert_eq(graph.edges, edges)
  assert_eq(graph.work, work)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
