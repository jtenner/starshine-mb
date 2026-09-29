///|
fn dae2_observed_entry_fixture(siblings : Int, stores : Int) -> @lib.Module {
  let wat = [
    "(module (memory 1) (global $g (mut i32) (i32.const 0)) (func $h (param i32) (result i32) i32.const 7) (func (export \"run\") (result i32) i32.const 9 call $h)",
  ]
  for index in 0..<siblings {
    wat.push("(func $store\{index} (param i32 i32 i32)")
    for _ in 0..<stores {
      wat.push("local.get 0 local.get 1 i32.store local.get 2 global.set $g")
    }
    wat.push(
      ") (func (export \"keep\{index}\") (param i32 i32 i32) local.get 0 local.get 1 local.get 2 call $store\{index})",
    )
  }
  wat.push(")")
  pass_test_module_from_wat(wat.join(" "))
}

///|
fn dae2_observed_entry_bench(
  it : @bench.T,
  siblings : Int,
  stores : Int,
  optimizing : Bool,
) -> Unit {
  let input = dae2_observed_entry_fixture(siblings, stores)
  let saved = @binary.encode_module(input).unwrap()
  let lifts = [0]
  let core = dae2_run_module_pass(input, false, analysis_lifts=Some(lifts)).unwrap()
  @validate.validate_module(core).unwrap()
  if lifts[0] != 0 {
    abort("readonly observable boundaries retained HOT analysis arenas")
  }
  for index in 2..<(siblings * 2 + 2) {
    if core.code_sec.unwrap().0[index] != input.code_sec.unwrap().0[index] {
      abort("readonly observable bodies changed during active argument pruning")
    }
  }
  let pass = if optimizing { "dae2-optimizing" } else { "dae2" }
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass]).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(caller)) = output.code_sec.unwrap().0[1]
  if caller != [@lib.Instruction::call(@lib.FuncIdx::new(0U))] {
    abort("readonly observable benchmark retained the active dead argument")
  }
  it.bench(fn() {
    it.keep(run_hot_pipeline(input, HotPipelineOptions::new(), [pass]))
  })
  if @binary.encode_module(input).unwrap() != saved {
    abort("readonly observable benchmark mutated its reusable input")
  }
}

///|
test "bench DAE2 readonly stores siblings=1 stores=1" (it : @bench.T) {
  dae2_observed_entry_bench(it, 1, 1, false)
}

///|
test "bench DAE2 optimizing readonly stores siblings=1 stores=1" (it : @bench.T) {
  dae2_observed_entry_bench(it, 1, 1, true)
}

///|
test "bench DAE2 readonly stores siblings=128 stores=128" (it : @bench.T) {
  dae2_observed_entry_bench(it, 128, 128, false)
}

///|
test "bench DAE2 optimizing readonly stores siblings=128 stores=128" (
  it : @bench.T,
) {
  dae2_observed_entry_bench(it, 128, 128, true)
}
