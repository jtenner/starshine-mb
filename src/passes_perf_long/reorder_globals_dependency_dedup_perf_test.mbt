///|
fn rg_dependency_dedup_fixture(count : Int) -> @lib.Module {
  let imports : Array[@lib.Import] = []
  let init : Array[@lib.Instruction] = [
    @lib.Instruction::i32_const(@lib.I32(0)),
  ]
  for idx in 0..<count {
    imports.push(
      @lib.Import::new(
        @lib.Name::from_string("env"),
        @lib.Name::from_string("g\{idx}"),
        @lib.ExternType::global(
          @lib.GlobalType::new(@lib.ValType::i32(), false),
        ),
      ),
    )
    for _ in 0..<2 {
      init.push(
        @lib.Instruction::global_get(
          @lib.GlobalIdx::new(idx.reinterpret_as_uint()),
        ),
      )
      init.push(@lib.Instruction::i32_add())
    }
  }
  @lib.Module::new()
  .with_import_sec(@lib.ImportSec::new(imports))
  .with_global_sec(
    @lib.GlobalSec::new([
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), false),
        @lib.Expr::new(init),
      ),
    ]),
  )
}

///|
fn rg_dependency_dedup_bench(it : @bench.T, count : Int) -> Unit {
  let fixture = rg_dependency_dedup_fixture(count)
  let output = @passes.reorder_globals_run_module_pass(fixture)
  if output.global_sec is None {
    abort("ReorderGlobals dependency benchmark lost its global")
  }
  it.bench(fn() { it.keep(@passes.reorder_globals_run_module_pass(fixture)) })
}

///|
test "bench reorder-globals repeated extended-const dependencies count=256" (
  it : @bench.T,
) {
  rg_dependency_dedup_bench(it, 256)
}

///|
test "bench reorder-globals repeated extended-const dependencies count=512" (
  it : @bench.T,
) {
  rg_dependency_dedup_bench(it, 512)
}
