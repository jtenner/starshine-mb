///|
fn dae2_pinned_calls_fixture(siblings : Int, calls : Int) -> @lib.Module {
  let wat = [
    "(module (type $sig (func (param i32) (result i32))) (import \"host\" \"echo\" (func $echo (type $sig))) (func $h (param i32) (result i32) i32.const 7) (func (export \"run\") (result i32) i32.const 9 call $h)",
  ]
  for index in 0..<siblings {
    wat.push("(func (export \"keep\{index}\") (param i32) (result i32)")
    for _ in 1..<calls {
      wat.push("local.get 0 call $echo drop")
    }
    wat.push("local.get 0 block (type $sig) call $echo br 0 end)")
  }
  wat.push(")")
  pass_test_module_from_wat(wat.join(" "))
}

///|
fn dae2_pinned_calls_bench(
  it : @bench.T,
  siblings : Int,
  calls : Int,
  optimizing : Bool,
) -> Unit {
  let input = dae2_pinned_calls_fixture(siblings, calls)
  let saved = @binary.encode_module(input).unwrap()
  let lifts = [0]
  let core = dae2_run_module_pass(input, false, analysis_lifts=Some(lifts)).unwrap()
  @validate.validate_module(core).unwrap()
  if lifts[0] != 0 {
    abort("pinned callee/control bodies still allocated HOT analysis arenas")
  }
  for index in 2..<(siblings + 2) {
    if core.code_sec.unwrap().0[index] != input.code_sec.unwrap().0[index] {
      abort("pinned call body changed during active argument pruning")
    }
  }
  let pass = if optimizing { "dae2-optimizing" } else { "dae2" }
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass]).unwrap()
  @validate.validate_module(output).unwrap()
  let context = @ir.hot_module_context_from_module(output)
  if @ir.hot_module_resolve_func_type(context, @lib.FuncIdx::new(1U)) !=
    Some(@lib.FuncType::new([], [@lib.ValType::i32()])) {
    abort("pinned-call benchmark retained the active helper's dead parameter")
  }
  let @lib.Func(_, @lib.Expr(caller)) = output.code_sec.unwrap().0[1]
  if caller != [@lib.Instruction::call(@lib.FuncIdx::new(1U))] {
    abort("pinned-call benchmark changed the active caller")
  }
  it.bench(fn() {
    it.keep(run_hot_pipeline(input, HotPipelineOptions::new(), [pass]))
  })
  if @binary.encode_module(input).unwrap() != saved {
    abort("pinned-call benchmark mutated its reusable input")
  }
}

///|
test "bench DAE2 pinned calls siblings=1 calls=1" (it : @bench.T) {
  dae2_pinned_calls_bench(it, 1, 1, false)
}

///|
test "bench DAE2 optimizing pinned calls siblings=1 calls=1" (it : @bench.T) {
  dae2_pinned_calls_bench(it, 1, 1, true)
}

///|
test "bench DAE2 pinned calls siblings=128 calls=128" (it : @bench.T) {
  dae2_pinned_calls_bench(it, 128, 128, false)
}

///|
test "bench DAE2 optimizing pinned calls siblings=128 calls=128" (it : @bench.T) {
  dae2_pinned_calls_bench(it, 128, 128, true)
}
