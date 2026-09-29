///|
fn dae2_wide_joins_bench(
  it : @bench.T,
  helpers : Int,
  joins : Int,
  optimizing : Bool,
) -> Unit {
  let wat = ["(module"]
  for index in 0..<helpers {
    wat.push("(func $h\{index} (param i32 i32 i32 i32) (result i32)")
    for _ in 0..<joins {
      wat.push("local.get 0 if local.get 1 local.set 2 end")
    }
    wat.push("local.get 2")
    for _ in 1..<joins {
      wat.push("local.get 2 i32.add")
    }
    wat.push(
      ") (func (export \"run\{index}\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i32.const 9 call $h\{index})",
    )
  }
  wat.push(")")
  let input = pass_test_module_from_wat(wat.join(" "))
  let saved = @binary.encode_module(input).unwrap()
  let pass = if optimizing { "dae2-optimizing" } else { "dae2" }
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass]).unwrap()
  @validate.validate_module(output).unwrap()
  let context = @ir.hot_module_context_from_module(output)
  for index in 0..<helpers {
    if @ir.hot_module_resolve_func_type(
        context,
        @lib.FuncIdx::new((index * 2).reinterpret_as_uint()),
      ) !=
      Some(
        @lib.FuncType::new(Array::make(3, @lib.ValType::i32()), [
          @lib.ValType::i32(),
        ]),
      ) {
      abort("wide-join benchmark did not prune precisely the fourth parameter")
    }
    let @lib.Func(_, @lib.Expr(caller)) = output.code_sec.unwrap().0[index * 2 +
      1]
    if caller !=
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::call(
          @lib.FuncIdx::new((index * 2).reinterpret_as_uint()),
        ),
      ] {
      abort("wide-join benchmark lost a live argument or retained the dead one")
    }
  }
  it.bench(fn() {
    it.keep(run_hot_pipeline(input, HotPipelineOptions::new(), [pass]))
  })
  if @binary.encode_module(input).unwrap() != saved {
    abort("wide-join benchmark mutated its reusable input")
  }
}

///|
test "bench DAE2 conditional joins helpers=1 joins=1" (it : @bench.T) {
  dae2_wide_joins_bench(it, 1, 1, false)
}

///|
test "bench DAE2 optimizing conditional joins helpers=1 joins=1" (it : @bench.T) {
  dae2_wide_joins_bench(it, 1, 1, true)
}

///|
test "bench DAE2 conditional joins helpers=32 joins=128" (it : @bench.T) {
  dae2_wide_joins_bench(it, 32, 128, false)
}

///|
test "bench DAE2 optimizing conditional joins helpers=32 joins=128" (
  it : @bench.T,
) {
  dae2_wide_joins_bench(it, 32, 128, true)
}
