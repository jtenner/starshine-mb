///|
fn dae2_raw_producers_bench(
  it : @bench.T,
  helpers : Int,
  width : Int,
  mode : Int,
) -> Unit {
  let wat = ["(module (type $s (struct (field i32)))"]
  for index in 0..<helpers {
    wat.push("(func $h\{index} (param i32 i32 i32) (result i32)")
    for _ in 0..<width {
      wat.push("local.get 0 struct.new $s struct.get $s 0 drop")
    }
    wat.push(
      "local.get 1) (func (export \"run\{index}\") (param i32 i32) (result i32) local.get 0 local.get 1 i32.const 9 call $h\{index})",
    )
  }
  wat.push(")")
  let input = pass_test_module_from_wat(wat.join(" "))
  let saved = @binary.encode_module(input).unwrap()
  let lifts = [0]
  let output = dae2_run_module_pass(input, false, analysis_lifts=Some(lifts)).unwrap()
  let reference = dae2_run_module_pass(input, false, raw_analysis=false).unwrap()
  @validate.validate_module(output).unwrap()
  if lifts[0] != 0 ||
    @binary.encode_module(output).unwrap() !=
    @binary.encode_module(reference).unwrap() {
    abort("raw mandatory producers changed output or retained first lifts")
  }
  let context = @ir.hot_module_context_from_module(output)
  for index in 0..<helpers {
    if @ir.hot_module_resolve_func_type(
        context,
        @lib.FuncIdx::new((2 * index).to_uint()),
      ) !=
      Some(
        @lib.FuncType::new([@lib.ValType::i32(), @lib.ValType::i32()], [
          @lib.ValType::i32(),
        ]),
      ) {
      abort(
        "producer benchmark lost live allocation fields or retained a dead parameter",
      )
    }
  }
  let pass = if mode == 3 { "dae2-optimizing" } else { "dae2" }
  it.bench(fn() {
    if mode < 2 {
      it.keep(dae2_run_module_pass(input, false, raw_analysis=mode == 1))
    } else {
      it.keep(run_hot_pipeline(input, HotPipelineOptions::new(), [pass]))
    }
  })
  if @binary.encode_module(input).unwrap() != saved {
    abort("raw producer benchmark mutated input")
  }
}

///|
test "bench DAE2 mandatory producers helpers=1 width=1 HOT" (it : @bench.T) {
  dae2_raw_producers_bench(it, 1, 1, 0)
}

///|
test "bench DAE2 mandatory producers helpers=1 width=1 raw" (it : @bench.T) {
  dae2_raw_producers_bench(it, 1, 1, 1)
}

///|
test "bench DAE2 mandatory producers helpers=32 width=128 HOT" (it : @bench.T) {
  dae2_raw_producers_bench(it, 32, 128, 0)
}

///|
test "bench DAE2 mandatory producers helpers=32 width=128 raw" (it : @bench.T) {
  dae2_raw_producers_bench(it, 32, 128, 1)
}

///|
test "bench DAE2 producer pipeline helpers=1 width=1" (it : @bench.T) {
  dae2_raw_producers_bench(it, 1, 1, 2)
}

///|
test "bench DAE2 optimizing producer pipeline helpers=1 width=1" (it : @bench.T) {
  dae2_raw_producers_bench(it, 1, 1, 3)
}

///|
test "bench DAE2 producer pipeline helpers=32 width=128" (it : @bench.T) {
  dae2_raw_producers_bench(it, 32, 128, 2)
}

///|
test "bench DAE2 optimizing producer pipeline helpers=32 width=128" (
  it : @bench.T,
) {
  dae2_raw_producers_bench(it, 32, 128, 3)
}
