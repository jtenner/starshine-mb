///|
fn sgo_fact_copy_fixture(global_count : Int, block_count : Int) -> @lib.Module {
  let globals : Array[@lib.Global] = []
  for idx in 0..<global_count {
    globals.push(
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), true),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(idx))]),
      ),
    )
  }
  let body : Array[@lib.Instruction] = []
  for _ in 0..<block_count {
    body.push(
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
          @lib.Instruction::drop(),
        ]),
      ),
    )
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_global_sec(@lib.GlobalSec::new(globals))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
    ]),
  )
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("g"),
        @lib.ExternIdx::global(@lib.GlobalIdx::new(0U)),
      ),
      @lib.Export::new(
        @lib.Name::from_string("run"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
      ),
    ]),
  )
}

///|
fn sgo_fact_copy_bench(it : @bench.T, count : Int) -> Unit {
  let fixture = sgo_fact_copy_fixture(count, count)
  let output = match
    @passes.run_hot_pipeline(fixture, @passes.HotPipelineOptions::new(), [
      "simplify-globals-optimizing",
    ]) {
    Ok(output) => output
    Err(err) => abort("SGO fact-copy benchmark fixture failed: \{err}")
  }
  if output.code_sec is None {
    abort("SGO fact-copy benchmark lost its function")
  }
  let options = @passes.HotPipelineOptions::new(validate_final_module=false)
  it.bench(fn() {
    match
      @passes.run_hot_pipeline(fixture, options, ["simplify-globals-optimizing"]) {
      Ok(output) => it.keep(output)
      Err(err) => abort("SGO fact-copy benchmark failed: \{err}")
    }
  })
}

///|
test "bench SGO runtime fact copies globals=256 blocks=256" (it : @bench.T) {
  sgo_fact_copy_bench(it, 256)
}

///|
test "bench SGO runtime fact copies globals=512 blocks=512" (it : @bench.T) {
  sgo_fact_copy_bench(it, 512)
}
