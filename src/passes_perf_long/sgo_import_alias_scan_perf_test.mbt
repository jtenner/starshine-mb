///|
fn sgo_import_alias_scan_fixture(
  defined_globals : Int,
  writes : Int,
) -> @lib.Module {
  let globals : Array[@lib.Global] = []
  for idx in 0..<defined_globals {
    globals.push(
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), true),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(idx))]),
      ),
    )
  }
  let body : Array[@lib.Instruction] = []
  for idx in 0..<writes {
    body.push(@lib.Instruction::i32_const(@lib.I32(idx)))
    body.push(@lib.Instruction::global_set(@lib.GlobalIdx::new(0U)))
    body.push(@lib.Instruction::global_get(@lib.GlobalIdx::new(0U)))
    body.push(@lib.Instruction::drop())
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_import_sec(
    @lib.ImportSec::new([
      @lib.Import::new(
        @lib.Name::from_string("env"),
        @lib.Name::from_string("g"),
        @lib.ExternType::global(@lib.GlobalType::new(@lib.ValType::i32(), true)),
      ),
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
        @lib.Name::from_string("run"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
      ),
    ]),
  )
}

///|
fn sgo_import_alias_scan_bench(it : @bench.T, defined_globals : Int) -> Unit {
  let fixture = sgo_import_alias_scan_fixture(defined_globals, 256)
  let output = match
    @passes.run_hot_pipeline(fixture, @passes.HotPipelineOptions::new(), [
      "simplify-globals-optimizing",
    ]) {
    Ok(output) => output
    Err(err) => abort("SGO imported-global fixture failed: \{err}")
  }
  if output == fixture {
    abort("SGO imported-global fixture did not rewrite")
  }
  let options = @passes.HotPipelineOptions::new(validate_final_module=false)
  it.bench(fn() {
    match
      @passes.run_hot_pipeline(fixture, options, ["simplify-globals-optimizing"]) {
      Ok(output) => it.keep(output)
      Err(err) => abort("SGO imported-global benchmark failed: \{err}")
    }
  })
}

///|
test "bench SGO imported alias scan defined=256 writes=256" (it : @bench.T) {
  sgo_import_alias_scan_bench(it, 256)
}

///|
test "bench SGO imported alias scan defined=512 writes=256" (it : @bench.T) {
  sgo_import_alias_scan_bench(it, 512)
}
