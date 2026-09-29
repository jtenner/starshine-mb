///|
fn dae_pure_arguments_bench(
  it : @bench.T,
  helpers : Int,
  width : Int,
  optimizing : Bool,
) -> Unit {
  let wat = ["(module (import \"m\" \"value\" (func $v (result i32)))"]
  for index in 0..<helpers {
    wat.push(
      "(func $h\{index} (param i32 i32) (result i32) local.get 1) (func (export \"run\{index}\") (param i32) (result i32) call $v drop i32.const 1",
    )
    for _ in 1..<width {
      wat.push("i32.const 7 i32.add")
    }
    wat.push("local.get 0 call $h\{index})")
  }
  wat.push(")")
  let input = pass_test_module_from_wat(wat.join(" "))
  let saved = @binary.encode_module(input).unwrap()
  let pass = if optimizing { "dae-optimizing" } else { "dae" }
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass]).unwrap()
  @validate.validate_module(output).unwrap()
  let context = @ir.hot_module_context_from_module(output)
  for index in 0..<helpers {
    let callee = @lib.FuncIdx::new((index * 2 + 1).reinterpret_as_uint())
    if @ir.hot_module_resolve_func_type(context, callee) !=
      Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])) {
      abort("pure-argument benchmark did not remove the dead parameter")
    }
    let @lib.Func(locals, @lib.Expr(caller)) = output.code_sec.unwrap().0[index *
      2 +
      1]
    if locals.length() != 0 ||
      caller !=
      [
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::call(callee),
      ] {
      abort(
        "pure-argument benchmark retained arithmetic or lost prefix effects",
      )
    }
  }
  it.bench(fn() {
    it.keep(run_hot_pipeline(input, HotPipelineOptions::new(), [pass]))
  })
  if @binary.encode_module(input).unwrap() != saved {
    abort("pure-argument benchmark mutated its reusable input")
  }
}

///|
test "bench DAE pure arguments helpers=1 width=1" (it : @bench.T) {
  dae_pure_arguments_bench(it, 1, 1, false)
}

///|
test "bench DAE optimizing pure arguments helpers=1 width=1" (it : @bench.T) {
  dae_pure_arguments_bench(it, 1, 1, true)
}

///|
test "bench DAE pure arguments helpers=32 width=128" (it : @bench.T) {
  dae_pure_arguments_bench(it, 32, 128, false)
}

///|
test "bench DAE optimizing pure arguments helpers=32 width=128" (it : @bench.T) {
  dae_pure_arguments_bench(it, 32, 128, true)
}
