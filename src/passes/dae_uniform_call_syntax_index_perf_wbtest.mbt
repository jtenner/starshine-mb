///|
fn dae_uniform_syntax_bench_rewrite(
  graph : DaeCurrentBoundaryGraph,
  callee_abs : Int32,
  values : Array[@lib.Instruction?]?,
) -> DaePassResult {
  let callee_def = callee_abs - graph.snapshot.imported
  dae_try_rewrite_candidate(
    graph.mod_,
    callee_abs,
    [true],
    values.unwrap(),
    dae_local_use_for_callee(graph.snapshot.funcs[callee_def], 1, callee_abs, 1),
    graph.snapshot.boundary_facts.direct_calls[callee_abs],
    graph.snapshot.boundary_facts.direct_callers[callee_abs],
  )
}

///|
fn dae_uniform_syntax_bench_input(
  debris : Int32,
  siblings : Int32,
) -> @lib.Module {
  let wat = StringBuilder::new()
  wat.write_string(
    "(module (func $a (param i32) (result i32) local.get 0) (func $b (param i32) (result i32) local.get 0) (func $forward (param i32) (result i32) local.get 0 call $a drop local.get 0 call $b) (func (export \"run\") (result i32) ",
  )
  for _ in 0..<debris {
    wat.write_string("nop ")
  }
  wat.write_string("i32.const 7 call $forward)")
  for _ in 0..<siblings {
    wat.write_string(" (func)")
  }
  wat.write_string(")")
  pass_test_module_from_wat(wat.to_string())
}

///|
fn dae_uniform_syntax_bench(
  it : @bench.T,
  debris : Int32,
  siblings : Int32,
  single_query : Bool,
  indexed : Bool,
) -> Unit raise {
  let input = dae_uniform_syntax_bench_input(debris, siblings)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  let visits = [0]
  let reference_visits = [0]
  let actual = dae_collect_exact_literal_candidate_defs_with_facts(
    input,
    graph.snapshot.call_facts,
    -1,
    syntax_visits=Some(visits),
  )
  let expected = dae_collect_exact_literal_candidate_defs_with_facts(
    input,
    graph.snapshot.call_facts,
    -1,
    indexed_syntax=false,
    syntax_visits=Some(reference_visits),
  )
  assert_eq(actual, [0, 1, 2])
  assert_eq(actual, expected)
  assert_true(visits[0] < reference_visits[0])
  for mode in [false, true] {
    let query = DaeUniformSyntaxQuery::new(
      graph.mod_,
      graph.snapshot.type_indices,
      graph.snapshot.boundary_facts,
      mode,
    )
    assert_eq(
      dae_uniform_syntax_query_values(query, graph, 0, 1),
      Some([Some(@lib.Instruction::i32_const(@lib.I32(7)))]),
    )
  }
  let output = dae_uniform_syntax_bench_rewrite(
    graph,
    0,
    Some([Some(@lib.Instruction::i32_const(@lib.I32(7)))]),
  )
  assert_true(output.changed)
  @validate.validate_module(output.mod_out).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  it.bench(fn() {
    if single_query {
      // This control has no syntax reuse. It exposes per-query index overhead.
      let query = DaeUniformSyntaxQuery::new(
        graph.mod_,
        graph.snapshot.type_indices,
        graph.snapshot.boundary_facts,
        indexed,
      )
      it.keep(dae_uniform_syntax_query_values(query, graph, 0, 1))
    } else {
      it.keep(
        dae_collect_exact_literal_candidate_defs_with_facts(
          input,
          graph.snapshot.call_facts,
          -1,
          indexed_syntax=indexed,
        ),
      )
    }
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
#skip("paired native syntax index cost; dedicated performance lane")
test "bench DAE syntax discovery debris=0 siblings=0 reference" (it : @bench.T) {
  dae_uniform_syntax_bench(it, 0, 0, false, false)
}

///|
#skip("paired native syntax index cost; dedicated performance lane")
test "bench DAE syntax discovery debris=0 siblings=0 indexed" (it : @bench.T) {
  dae_uniform_syntax_bench(it, 0, 0, false, true)
}

///|
#skip("paired native syntax index cost; dedicated performance lane")
test "bench DAE syntax discovery debris=32 siblings=0 reference" (it : @bench.T) {
  dae_uniform_syntax_bench(it, 32, 0, false, false)
}

///|
#skip("paired native syntax index cost; dedicated performance lane")
test "bench DAE syntax discovery debris=32 siblings=0 indexed" (it : @bench.T) {
  dae_uniform_syntax_bench(it, 32, 0, false, true)
}

///|
#skip("13k unrelated functions; dedicated native performance lane")
test "bench DAE syntax discovery debris=32 siblings=13000 reference" (
  it : @bench.T,
) {
  dae_uniform_syntax_bench(it, 32, 13000, false, false)
}

///|
#skip("13k unrelated functions; dedicated native performance lane")
test "bench DAE syntax discovery debris=32 siblings=13000 indexed" (
  it : @bench.T,
) {
  dae_uniform_syntax_bench(it, 32, 13000, false, true)
}

///|
#skip("single-query index overhead; dedicated native performance lane")
test "bench DAE syntax single debris=32 siblings=0 reference" (it : @bench.T) {
  dae_uniform_syntax_bench(it, 32, 0, true, false)
}

///|
#skip("single-query index overhead; dedicated native performance lane")
test "bench DAE syntax single debris=32 siblings=0 indexed" (it : @bench.T) {
  dae_uniform_syntax_bench(it, 32, 0, true, true)
}

///|
#skip("single query with 13k unrelated functions; dedicated native performance lane")
test "bench DAE syntax single debris=32 siblings=13000 reference" (
  it : @bench.T,
) {
  dae_uniform_syntax_bench(it, 32, 13000, true, false)
}

///|
#skip("single query with 13k unrelated functions; dedicated native performance lane")
test "bench DAE syntax single debris=32 siblings=13000 indexed" (it : @bench.T) {
  dae_uniform_syntax_bench(it, 32, 13000, true, true)
}

///|
fn dae_uniform_syntax_call_dense_input(calls : Int32) -> @lib.Module {
  let wat = StringBuilder::new()
  wat.write_string(
    "(module (import \"env\" \"tick\" (func $tick)) (func $h (param i32) (result i32) local.get 0) (func $forward (param i32) (result i32) local.get 0 call $h) (func (export \"run\") (result i32) ",
  )
  for _ in 0..<calls {
    wat.write_string("call $tick ")
  }
  wat.write_string("i32.const 7 call $forward))")
  pass_test_module_from_wat(wat.to_string()).with_custom_secs([
    @lib.CustomSec::new(@lib.Name::new("syntax.keep"), b"unchanged"),
  ])
}

///|
fn dae_uniform_syntax_call_dense_query(
  graph : DaeCurrentBoundaryGraph,
  mode : Int32,
) -> Array[@lib.Instruction?]? {
  if mode == 0 {
    // This frozen component constructs no new syntax-query state and has no
    // new visitor branches. It exposes total added query-construction cost.
    dae_s6_uniform_reference_collect_uniform_const_actuals_from_boundary_facts(
      graph.mod_,
      1,
      1,
      graph.snapshot.type_indices,
      graph.snapshot.boundary_facts,
    )
  } else if mode == 2 {
    // Use the production default, including its internal fresh constructor.
    dae_collect_uniform_const_actuals_from_boundary_facts(
      graph.mod_,
      1,
      1,
      graph.snapshot.type_indices,
      graph.snapshot.boundary_facts,
    )
  } else {
    // mode1 is the current visitor with indexing disabled. It still constructs
    // the new query object; it is not the frozen pre-index baseline.
    let query = DaeUniformSyntaxQuery::new(
      graph.mod_,
      graph.snapshot.type_indices,
      graph.snapshot.boundary_facts,
      false,
    )
    dae_uniform_syntax_query_values(query, graph, 1, 1)
  }
}

///|
fn dae_uniform_syntax_call_dense_bench(
  it : @bench.T,
  calls : Int32,
  mode : Int32,
) -> Unit raise {
  let input = dae_uniform_syntax_call_dense_input(calls)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  let baseline = dae_uniform_syntax_call_dense_query(graph, 0)
  let reference = dae_uniform_syntax_bench_rewrite(graph, 1, baseline)
  assert_true(reference.changed)
  @validate.validate_module(reference.mod_out).unwrap()
  let reference_bytes = @binary.encode_module(reference.mod_out).unwrap()
  for control in 0..<3 {
    let values = dae_uniform_syntax_call_dense_query(graph, control)
    assert_eq(values, Some([Some(@lib.Instruction::i32_const(@lib.I32(7)))]))
    assert_eq(values, baseline)
    let output = dae_uniform_syntax_bench_rewrite(graph, 1, values)
    assert_true(output.changed)
    assert_eq(output.touched, reference.touched)
    assert_eq(@binary.encode_module(output.mod_out).unwrap(), reference_bytes)
    @validate.validate_module(output.mod_out).unwrap()
    assert_eq(output.mod_out.custom_secs, input.custom_secs)
    let after = dae_current_boundary_graph_new(output.mod_out)
    assert_eq(
      after.snapshot.function_types[1],
      Some(@lib.FuncType::new([], [@lib.ValType::i32()])),
    )
    let @lib.Func(_, @lib.Expr(body)) = after.snapshot.funcs[0]
    assert_eq(body, [@lib.Instruction::i32_const(@lib.I32(7))])
    let @lib.Func(_, @lib.Expr(run)) = after.snapshot.funcs[2]
    let mut ticks = 0
    for instr in run {
      if instr == @lib.Instruction::call(@lib.FuncIdx::new(0U)) {
        ticks += 1
      }
    }
    assert_eq(ticks, calls)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
  it.bench(fn() {
    // Every mode supplies no recorder, syntax counter, or uniform cache. Each
    // measured query starts cold and includes release of its private state.
    it.keep(dae_uniform_syntax_call_dense_query(graph, mode))
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
#skip("call-dense cold cost; dedicated native performance lane")
test "bench DAE syntax dense calls=16 frozen S6" (it : @bench.T) {
  dae_uniform_syntax_call_dense_bench(it, 16, 0)
}

///|
#skip("call-dense cold cost; dedicated native performance lane")
test "bench DAE syntax dense calls=16 current visitor" (it : @bench.T) {
  dae_uniform_syntax_call_dense_bench(it, 16, 1)
}

///|
#skip("call-dense cold cost; dedicated native performance lane")
test "bench DAE syntax dense calls=16 indexed" (it : @bench.T) {
  dae_uniform_syntax_call_dense_bench(it, 16, 2)
}

///|
#skip("call-dense cold cost; dedicated native performance lane")
test "bench DAE syntax dense calls=128 frozen S6" (it : @bench.T) {
  dae_uniform_syntax_call_dense_bench(it, 128, 0)
}

///|
#skip("call-dense cold cost; dedicated native performance lane")
test "bench DAE syntax dense calls=128 current visitor" (it : @bench.T) {
  dae_uniform_syntax_call_dense_bench(it, 128, 1)
}

///|
#skip("call-dense cold cost; dedicated native performance lane")
test "bench DAE syntax dense calls=128 indexed" (it : @bench.T) {
  dae_uniform_syntax_call_dense_bench(it, 128, 2)
}

///|
#skip("call-dense cold cost; dedicated native performance lane")
test "bench DAE syntax dense calls=1024 frozen S6" (it : @bench.T) {
  dae_uniform_syntax_call_dense_bench(it, 1024, 0)
}

///|
#skip("call-dense cold cost; dedicated native performance lane")
test "bench DAE syntax dense calls=1024 current visitor" (it : @bench.T) {
  dae_uniform_syntax_call_dense_bench(it, 1024, 1)
}

///|
#skip("call-dense cold cost; dedicated native performance lane")
test "bench DAE syntax dense calls=1024 indexed" (it : @bench.T) {
  dae_uniform_syntax_call_dense_bench(it, 1024, 2)
}
