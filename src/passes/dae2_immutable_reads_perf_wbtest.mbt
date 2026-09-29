///|
fn dae2_immutable_reads_fixture(count : Int, mixed : Bool) -> @lib.Module {
  let wat : Array[String] = ["(module"]
  for index in 0..<count {
    wat.push("(func $h\{index} (param i32 i32) (result i32)")
    if mixed {
      wat.push("local.get 1 i32.const 1 i32.add local.set 1")
    }
    wat.push("local.get 1)")
    wat.push(
      "(func (export \"run\{index}\") (param i32) (result i32) i32.const 9 local.get 0 call $h\{index})",
    )
  }
  wat.push(")")
  pass_test_module_from_wat(wat.join(" "))
}

///|
fn dae2_immutable_reads_bench(it : @bench.T, count : Int, mixed : Bool) -> Unit {
  let input = dae2_immutable_reads_fixture(count, mixed)
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["dae2"]).unwrap()
  @validate.validate_module(output).unwrap()
  let context = @ir.hot_module_context_from_module(output)
  for index in 0..<count {
    if @ir.hot_module_resolve_func_type(
        context,
        @lib.FuncIdx::new((index * 2).reinterpret_as_uint()),
      ) !=
      Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])) {
      abort(
        "DAE2 immutable-read benchmark failed to remove the unused parameter",
      )
    }
    let @lib.Func(_, @lib.Expr(caller)) = output.code_sec.unwrap().0[index * 2 +
      1]
    if caller !=
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::call(
          @lib.FuncIdx::new((index * 2).reinterpret_as_uint()),
        ),
      ] {
      abort(
        "DAE2 immutable-read benchmark changed the retained caller argument",
      )
    }
  }
  it.bench(fn() {
    it.keep(run_hot_pipeline(input, HotPipelineOptions::new(), ["dae2"]))
  })
}

///|
test "bench DAE2 immutable reads pairs=1" (it : @bench.T) {
  dae2_immutable_reads_bench(it, 1, false)
}

///|
test "bench DAE2 mixed reads pairs=1" (it : @bench.T) {
  dae2_immutable_reads_bench(it, 1, true)
}

///|
test "bench DAE2 immutable reads pairs=128" (it : @bench.T) {
  dae2_immutable_reads_bench(it, 128, false)
}

///|
test "bench DAE2 mixed reads pairs=128" (it : @bench.T) {
  dae2_immutable_reads_bench(it, 128, true)
}

///|
test "bench DAE2 immutable reads pairs=1024" (it : @bench.T) {
  dae2_immutable_reads_bench(it, 1024, false)
}

///|
test "bench DAE2 mixed reads pairs=1024" (it : @bench.T) {
  dae2_immutable_reads_bench(it, 1024, true)
}
