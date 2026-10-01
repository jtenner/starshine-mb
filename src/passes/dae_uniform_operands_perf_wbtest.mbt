///|
fn dae_uniform_operands_bench(
  it : @bench.T,
  params : Int,
  computed : Bool,
  sliced : Bool,
) -> Unit {
  let text = StringBuilder::new()
  text.write_string("(module (func $h (param")
  for _ in 0..<params {
    text.write_string(" i32")
  }
  text.write_string(")) (func (export \"run\")")
  for p in 0..<params {
    text.write_string(" i32.const \{p}")
    if computed {
      text.write_string(" i32.const 1 i32.add")
    }
  }
  text.write_string(" call $h))")
  let input = pass_test_module_from_wat(text.to_string())
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  let @lib.Func(_, @lib.Expr(body)) = graph.snapshot.funcs[1]
  let call_idx = body.length() - 1
  let proof = dae_uniform_callsite_operands_at(
    input,
    body,
    call_idx,
    params,
    0,
    graph.snapshot.type_indices,
  ).unwrap()
  if proof.direct_actual_start.is_some() == computed {
    abort("wrong operand recovery path")
  }
  it.bench(fn() {
    it.keep(
      if sliced {
        dae_uniform_operands_sliced_reference_at(
          input,
          body,
          call_idx,
          params,
          0,
          graph.snapshot.type_indices,
        )
      } else {
        dae_uniform_callsite_operands_at(
          input,
          body,
          call_idx,
          params,
          0,
          graph.snapshot.type_indices,
        )
      },
    )
  })
  if @binary.encode_module(input).unwrap() != saved {
    abort("fixture mutated")
  }
}

///|
test "bench DAE uniform operands scalar=1 sliced" (it : @bench.T) {
  dae_uniform_operands_bench(it, 1, false, true)
}

///|
test "bench DAE uniform operands scalar=1 borrowed" (it : @bench.T) {
  dae_uniform_operands_bench(it, 1, false, false)
}

///|
test "bench DAE uniform operands scalar=16 sliced" (it : @bench.T) {
  dae_uniform_operands_bench(it, 16, false, true)
}

///|
test "bench DAE uniform operands scalar=16 borrowed" (it : @bench.T) {
  dae_uniform_operands_bench(it, 16, false, false)
}

///|
test "bench DAE uniform operands computed=1 sliced" (it : @bench.T) {
  dae_uniform_operands_bench(it, 1, true, true)
}

///|
test "bench DAE uniform operands computed=1 fallback" (it : @bench.T) {
  dae_uniform_operands_bench(it, 1, true, false)
}

///|
/// Dedicated native lane. Copy the pinned artifact to this ignored path first;
/// parsing and validation of the reusable input stay outside the timed closure.
fn dae_uniform_small_fixture_bench(it : @bench.T, optimize : Bool) -> Unit {
  let bytes = @sfs.read_file_bytes(".tmp/dae-small-benchmark.wasm").unwrap()
  let input = @binary.decode_module(bytes).unwrap()
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let pass = if optimize { "dae-optimizing" } else { "dae" }
  let preflight = run_hot_pipeline(input, HotPipelineOptions::new(), [pass]).unwrap()
  @validate.validate_module(preflight).unwrap()
  if @binary.encode_module(preflight).unwrap() == saved {
    abort("fixture must exercise DAE")
  }
  it.bench(fn() {
    it.keep(run_hot_pipeline(input, HotPipelineOptions::new(), [pass]).unwrap())
  })
  if @binary.encode_module(input).unwrap() != saved {
    abort("fixture mutated")
  }
}

///|
test "bench DAE warm fixed small module complete pipeline" (it : @bench.T) {
  dae_uniform_small_fixture_bench(it, false)
}

///|
test "bench DAE optimizing warm fixed small module complete pipeline" (
  it : @bench.T,
) {
  dae_uniform_small_fixture_bench(it, true)
}
