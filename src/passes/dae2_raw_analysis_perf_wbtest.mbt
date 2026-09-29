///|
fn dae2_raw_analysis_fixture(helpers : Int, width : Int) -> @lib.Module {
  let wat = ["(module"]
  for index in 0..<helpers {
    wat.push("(func $h\{index} (param i32 i32 i32) (result i32) local.get 1")
    for _ in 0..<width {
      wat.push("i32.const 7 i32.add")
    }
    wat.push(
      ") (func (export \"run\{index}\") (param i32) (result i32) i32.const 9 local.get 0 i32.const 11 call $h\{index})",
    )
  }
  wat.push(")")
  pass_test_module_from_wat(wat.join(" "))
}

///|
fn dae2_raw_analysis_bench(
  it : @bench.T,
  helpers : Int,
  width : Int,
  mode : Int,
) -> Unit {
  let input = dae2_raw_analysis_fixture(helpers, width)
  let saved = @binary.encode_module(input).unwrap()
  let lifts = [0]
  let output = dae2_run_module_pass(input, false, analysis_lifts=Some(lifts)).unwrap()
  let reference = dae2_run_module_pass(input, false, raw_analysis=false).unwrap()
  @validate.validate_module(output).unwrap()
  if lifts[0] != 0 ||
    @binary.encode_module(output).unwrap() !=
    @binary.encode_module(reference).unwrap() {
    abort(
      "raw analysis retained initial HOT lifts or changed the complete rewrite",
    )
  }
  let context = @ir.hot_module_context_from_module(output)
  for index in 0..<helpers {
    if @ir.hot_module_resolve_func_type(
        context,
        @lib.FuncIdx::new((index * 2).to_uint()),
      ) !=
      Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])) {
      abort(
        "raw analysis did not prune the active helper's two dead parameters",
      )
    }
  }
  let pass = if mode == 3 { "dae2-optimizing" } else { "dae2" }
  if mode >= 2 {
    @validate.validate_module(
      run_hot_pipeline(input, HotPipelineOptions::new(), [pass]).unwrap(),
    ).unwrap()
  }
  it.bench(fn() {
    if mode < 2 {
      it.keep(dae2_run_module_pass(input, false, raw_analysis=mode == 1))
    } else {
      it.keep(run_hot_pipeline(input, HotPipelineOptions::new(), [pass]))
    }
  })
  if @binary.encode_module(input).unwrap() != saved {
    abort("raw analysis benchmark mutated its reusable input")
  }
}

///|
test "bench DAE2 flat analysis helpers=1 width=1 HOT reference" (it : @bench.T) {
  dae2_raw_analysis_bench(it, 1, 1, 0)
}

///|
test "bench DAE2 flat analysis helpers=1 width=1 raw" (it : @bench.T) {
  dae2_raw_analysis_bench(it, 1, 1, 1)
}

///|
test "bench DAE2 flat analysis helpers=32 width=128 HOT reference" (
  it : @bench.T,
) {
  dae2_raw_analysis_bench(it, 32, 128, 0)
}

///|
test "bench DAE2 flat analysis helpers=32 width=128 raw" (it : @bench.T) {
  dae2_raw_analysis_bench(it, 32, 128, 1)
}

///|
test "bench DAE2 flat pipeline helpers=1 width=1" (it : @bench.T) {
  dae2_raw_analysis_bench(it, 1, 1, 2)
}

///|
test "bench DAE2 optimizing flat pipeline helpers=1 width=1" (it : @bench.T) {
  dae2_raw_analysis_bench(it, 1, 1, 3)
}

///|
test "bench DAE2 flat pipeline helpers=32 width=128" (it : @bench.T) {
  dae2_raw_analysis_bench(it, 32, 128, 2)
}

///|
test "bench DAE2 optimizing flat pipeline helpers=32 width=128" (it : @bench.T) {
  dae2_raw_analysis_bench(it, 32, 128, 3)
}
