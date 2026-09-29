///|
fn dae2_raw_tee_fixture(helpers : Int, width : Int) -> @lib.Module {
  let wat = ["(module"]
  for index in 0..<helpers {
    wat.push("(func $h\{index} (param i32 i32 i32) (result i32) local.get 1")
    for _ in 0..<width {
      wat.push("i32.const 7 i32.add local.tee 0 drop local.get 0")
    }
    wat.push(
      ") (func (export \"run\{index}\") (param i32) (result i32) i32.const 9 local.get 0 i32.const 8 call $h\{index})",
    )
  }
  wat.push(")")
  pass_test_module_from_wat(wat.join(" "))
}

///|
fn dae2_raw_tee_bench(
  it : @bench.T,
  helpers : Int,
  width : Int,
  reference : Bool,
) -> Unit {
  let input = dae2_raw_tee_fixture(helpers, width)
  let saved = @binary.encode_module(input).unwrap()
  let output = dae2_run_module_pass(input, false).unwrap()
  let before = dae2_run_module_pass(input, false, raw_rewrite=false).unwrap()
  if @binary.encode_module(output).unwrap() !=
    @binary.encode_module(before).unwrap() {
    abort("scalar tee mutation changed reference output")
  }
  @validate.validate_module(output).unwrap()
  for index in 0..<helpers {
    if dae_wb_param_count(output, index * 2) != 1 {
      abort("scalar tee benchmark lost active parameter pruning")
    }
  }
  it.bench(fn() {
    it.keep(dae2_run_module_pass(input, false, raw_rewrite=!reference))
  })
  if @binary.encode_module(input).unwrap() != saved {
    abort("scalar tee benchmark mutated input")
  }
}

///|
test "bench DAE2 scalar tee helpers=1 width=1 HOT mutation" (it : @bench.T) {
  dae2_raw_tee_bench(it, 1, 1, true)
}

///|
test "bench DAE2 scalar tee helpers=1 width=1 direct mutation" (it : @bench.T) {
  dae2_raw_tee_bench(it, 1, 1, false)
}

///|
test "bench DAE2 scalar tee helpers=32 width=128 HOT mutation" (it : @bench.T) {
  dae2_raw_tee_bench(it, 32, 128, true)
}

///|
test "bench DAE2 scalar tee helpers=32 width=128 direct mutation" (
  it : @bench.T,
) {
  dae2_raw_tee_bench(it, 32, 128, false)
}

///|
fn dae2_raw_tee_pipeline_bench(
  it : @bench.T,
  helpers : Int,
  width : Int,
  optimizing : Bool,
) -> Unit {
  let input = dae2_raw_tee_fixture(helpers, width)
  let saved = @binary.encode_module(input).unwrap()
  let pass = if optimizing { "dae2-optimizing" } else { "dae2" }
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass]).unwrap()
  @validate.validate_module(output).unwrap()
  for index in 0..<helpers {
    if dae_wb_param_count(output, index * 2) != 1 {
      abort("tee pipeline benchmark did not prune both dead parameters")
    }
  }
  if helpers > 1 && optimizing {
    let perf = HotPerfSession::new(
      trace_counters=false,
      trace_checkpoints=false,
    )
    let profiled = run_hot_pipeline(
      input,
      HotPipelineOptions::new(perf=Some(perf)),
      [pass],
    ).unwrap()
    if @binary.encode_module(profiled).unwrap() !=
      @binary.encode_module(output).unwrap() {
      abort("tee pipeline profiling changed active output")
    }
    println("DAE2-O tee detail timers: \{perf.timer_totals}")
  }
  it.bench(fn() {
    it.keep(run_hot_pipeline(input, HotPipelineOptions::new(), [pass]))
  })
  if @binary.encode_module(input).unwrap() != saved {
    abort("tee pipeline benchmark mutated input")
  }
}

///|
test "bench DAE2 scalar tee pipeline helpers=1 width=1" (it : @bench.T) {
  dae2_raw_tee_pipeline_bench(it, 1, 1, false)
}

///|
test "bench DAE2-O scalar tee pipeline helpers=1 width=1" (it : @bench.T) {
  dae2_raw_tee_pipeline_bench(it, 1, 1, true)
}

///|
test "bench DAE2 scalar tee pipeline helpers=32 width=128" (it : @bench.T) {
  dae2_raw_tee_pipeline_bench(it, 32, 128, false)
}

///|
test "bench DAE2-O scalar tee pipeline helpers=32 width=128" (it : @bench.T) {
  dae2_raw_tee_pipeline_bench(it, 32, 128, true)
}
