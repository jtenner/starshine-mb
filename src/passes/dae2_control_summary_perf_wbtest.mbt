///|
fn dae2_control_summary_fixture(count : Int) -> @lib.Module {
  let wat : Array[String] = [
    "(module (type $dead (func (param i32) (result i32))) (type $keep (func (result i32))) (func $helper (type $dead) i32.const 7) (func (export \"run\") (result i32) i32.const 9 call $helper)",
  ]
  for index in 0..<count {
    wat.push(
      "(func (export \"keep\{index}\") (type $keep) block (type $keep) i32.const \{index} end)",
    )
  }
  wat.push(")")
  pass_test_module_from_wat(wat.join(""))
}

///|
fn dae2_control_summary_bench(
  it : @bench.T,
  count : Int,
  optimizing : Bool,
) -> Unit {
  let mod_ = dae2_control_summary_fixture(count)
  let lifts = [0]
  let output = dae2_run_module_pass(mod_, false, rewrite_lifts=Some(lifts)).unwrap()
  @validate.validate_module(output).unwrap()
  if lifts[0] != 2 {
    abort("unchanged indexed-control functions were relifted")
  }
  let name = if optimizing { "dae2-optimizing" } else { "dae2" }
  let options = HotPipelineOptions::new(validate_final_module=false)
  @validate.validate_module(run_hot_pipeline(mod_, options, [name]).unwrap()).unwrap()
  it.bench(fn() { it.keep(run_hot_pipeline(mod_, options, [name])) })
}

///|
test "bench DAE2 indexed controls unchanged=16 plain" (it : @bench.T) {
  dae2_control_summary_bench(it, 16, false)
}

///|
test "bench DAE2 indexed controls unchanged=16 optimizing" (it : @bench.T) {
  dae2_control_summary_bench(it, 16, true)
}

///|
test "bench DAE2 indexed controls unchanged=128 plain" (it : @bench.T) {
  dae2_control_summary_bench(it, 128, false)
}

///|
test "bench DAE2 indexed controls unchanged=128 optimizing" (it : @bench.T) {
  dae2_control_summary_bench(it, 128, true)
}

///|
test "bench DAE2 indexed controls unchanged=1024 plain" (it : @bench.T) {
  dae2_control_summary_bench(it, 1024, false)
}

///|
test "bench DAE2 indexed controls unchanged=1024 optimizing" (it : @bench.T) {
  dae2_control_summary_bench(it, 1024, true)
}
