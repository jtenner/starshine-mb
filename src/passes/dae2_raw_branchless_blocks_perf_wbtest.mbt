///|
fn dae2_branchless_bench_fixture(
  helpers : Int,
  width : Int,
  depth : Int,
) -> @lib.Module {
  let wat = ["(module"]
  for index in 0..<helpers {
    wat.push("(func $h\{index} (param i32 i32 i32) (result i32)")
    for _ in 0..<depth {
      wat.push("block (result i32)")
    }
    wat.push("local.get 1")
    for _ in 0..<width {
      wat.push("i32.const 7 i32.add")
    }
    for _ in 0..<depth {
      wat.push("end")
    }
    wat.push(
      ") (func (export \"run\{index}\") (param i32) (result i32) i32.const 9 local.get 0 i32.const 8 call $h\{index})",
    )
  }
  wat.push(")")
  pass_test_module_from_wat(wat.join(" "))
}

///|
fn dae2_branchless_bench(
  it : @bench.T,
  helpers : Int,
  width : Int,
  depth : Int,
  reference : Bool,
) -> Unit {
  let input = dae2_branchless_bench_fixture(helpers, width, depth)
  let saved = @binary.encode_module(input).unwrap()
  let analysis = [0]
  let rewrite = [0]
  let output = dae2_run_module_pass(
    input,
    false,
    analysis_lifts=Some(analysis),
    rewrite_lifts=Some(rewrite),
  ).unwrap()
  let before = dae2_run_module_pass(
    input,
    false,
    raw_analysis=false,
    raw_rewrite=false,
  ).unwrap()
  if analysis[0] != 0 ||
    rewrite[0] != 0 ||
    @binary.encode_module(output).unwrap() !=
    @binary.encode_module(before).unwrap() {
    abort(
      "branchless block benchmark changed exact HOT output or retained lift work",
    )
  }
  @validate.validate_module(output).unwrap()
  for index in 0..<helpers {
    if dae_wb_param_count(output, index * 2) != 1 {
      abort("branchless block benchmark lost active pruning")
    }
  }
  it.bench(fn() {
    it.keep(
      dae2_run_module_pass(
        input,
        false,
        raw_analysis=!reference,
        raw_rewrite=!reference,
      ),
    )
  })
  if @binary.encode_module(input).unwrap() != saved {
    abort("branchless block benchmark mutated input")
  }
}

///|
test "bench DAE2 branchless helpers=1 width=1 depth=1 HOT" (it : @bench.T) {
  dae2_branchless_bench(it, 1, 1, 1, true)
}

///|
test "bench DAE2 branchless helpers=1 width=1 depth=1 direct" (it : @bench.T) {
  dae2_branchless_bench(it, 1, 1, 1, false)
}

///|
test "bench DAE2 branchless helpers=1 width=1 depth=16 HOT" (it : @bench.T) {
  dae2_branchless_bench(it, 1, 1, 16, true)
}

///|
test "bench DAE2 branchless helpers=1 width=1 depth=16 direct" (it : @bench.T) {
  dae2_branchless_bench(it, 1, 1, 16, false)
}

///|
test "bench DAE2 branchless helpers=32 width=128 depth=1 HOT" (it : @bench.T) {
  dae2_branchless_bench(it, 32, 128, 1, true)
}

///|
test "bench DAE2 branchless helpers=32 width=128 depth=1 direct" (it : @bench.T) {
  dae2_branchless_bench(it, 32, 128, 1, false)
}

///|
test "bench DAE2 branchless helpers=32 width=128 depth=16 HOT" (it : @bench.T) {
  dae2_branchless_bench(it, 32, 128, 16, true)
}

///|
test "bench DAE2 branchless helpers=32 width=128 depth=16 direct" (
  it : @bench.T,
) {
  dae2_branchless_bench(it, 32, 128, 16, false)
}
