///|
fn dae2_indexed_sources_fixture(pairs : Int, reads : Int) -> @lib.Module {
  let wat = ["(module"]
  for index in 0..<pairs {
    wat.push(
      "(func $h\{index} (param i32 i32 i32 i32) (result i32) local.get 0 if local.get 1 local.set 2 end local.get 2",
    )
    for _ in 1..<reads {
      wat.push("local.get 2 i32.add")
    }
    wat.push(")")
    wat.push(
      "(func (export \"run\{index}\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i32.const 9 call $h\{index})",
    )
  }
  wat.push(")")
  pass_test_module_from_wat(wat.join(" "))
}

///|
fn dae2_indexed_sources_pipeline_bench(
  it : @bench.T,
  pairs : Int,
  reads : Int,
  optimizing : Bool,
) -> Unit {
  let input = dae2_indexed_sources_fixture(pairs, reads)
  let source_bytes = @binary.encode_module(input).unwrap()
  let pass = if optimizing { "dae2-optimizing" } else { "dae2" }
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass]).unwrap()
  @validate.validate_module(output).unwrap()
  let context = @ir.hot_module_context_from_module(output)
  for index in 0..<pairs {
    if @ir.hot_module_resolve_func_type(
        context,
        @lib.FuncIdx::new((index * 2).to_uint()),
      ) !=
      Some(
        @lib.FuncType::new(
          [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
          [@lib.ValType::i32()],
        ),
      ) {
      abort("mutable source benchmark did not prune the unused argument")
    }
    let @lib.Func(_, @lib.Expr(caller)) = output.code_sec.unwrap().0[index * 2 +
      1]
    if caller !=
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::call(@lib.FuncIdx::new((index * 2).to_uint())),
      ] {
      abort("mutable source benchmark changed retained caller arguments")
    }
  }
  it.bench(fn() {
    it.keep(run_hot_pipeline(input, HotPipelineOptions::new(), [pass]))
  })
  if @binary.encode_module(input).unwrap() != source_bytes {
    abort("DAE2 source lookup mutated its input snapshot")
  }
}

///|
test "bench DAE2 mutable sources pairs=1 reads=1" (it : @bench.T) {
  dae2_indexed_sources_pipeline_bench(it, 1, 1, false)
}

///|
test "bench DAE2 optimizing mutable sources pairs=1 reads=1" (it : @bench.T) {
  dae2_indexed_sources_pipeline_bench(it, 1, 1, true)
}

///|
test "bench DAE2 mutable sources pairs=1 reads=128" (it : @bench.T) {
  dae2_indexed_sources_pipeline_bench(it, 1, 128, false)
}

///|
test "bench DAE2 optimizing mutable sources pairs=1 reads=128" (it : @bench.T) {
  dae2_indexed_sources_pipeline_bench(it, 1, 128, true)
}

///|
test "bench DAE2 mutable sources pairs=32 reads=1" (it : @bench.T) {
  dae2_indexed_sources_pipeline_bench(it, 32, 1, false)
}

///|
test "bench DAE2 optimizing mutable sources pairs=32 reads=1" (it : @bench.T) {
  dae2_indexed_sources_pipeline_bench(it, 32, 1, true)
}

///|
test "bench DAE2 mutable sources pairs=32 reads=128" (it : @bench.T) {
  dae2_indexed_sources_pipeline_bench(it, 32, 128, false)
}

///|
test "bench DAE2 optimizing mutable sources pairs=32 reads=128" (it : @bench.T) {
  dae2_indexed_sources_pipeline_bench(it, 32, 128, true)
}
