///|
test "reorder-globals dependency graph preserves first occurrence and deduplicates reads" {
  let init = @lib.Expr::new([
    @lib.Instruction::global_get(@lib.GlobalIdx::new(3U)),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(1U)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(3U)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::i32_add(),
  ])
  let globals = [
    @lib.Global::new(@lib.GlobalType::new(@lib.ValType::i32(), false), init),
  ]
  let graph = rg_build_dependency_graph(globals, 4)
  @debug.assert_eq(graph.length(), 5)
  @debug.assert_eq(graph[0], [4])
  @debug.assert_eq(graph[1], [4])
  @debug.assert_eq(graph[2], [])
  @debug.assert_eq(graph[3], [4])
  @debug.assert_eq(graph[4], [])
  let imports : Array[@lib.Import] = []
  for idx in 0..<4 {
    imports.push(
      @lib.Import::new(
        @lib.Name::from_string("env"),
        @lib.Name::from_string("g\{idx}"),
        @lib.ExternType::global(
          @lib.GlobalType::new(@lib.ValType::i32(), false),
        ),
      ),
    )
  }
  let input = @lib.Module::new()
    .with_import_sec(@lib.ImportSec::new(imports))
    .with_global_sec(@lib.GlobalSec::new(globals))
  assert_true(@validate.validate_module(input) is Ok(_))
  let output = reorder_globals_run_module_pass(input)
  assert_true(@validate.validate_module(output) is Ok(_))
}
