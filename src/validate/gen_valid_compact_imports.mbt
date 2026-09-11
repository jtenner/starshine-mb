///|
fn gen_valid_compact_imports_config() -> GenValidConfig {
  let base = gen_valid_array_memory_config()
  GenValidConfig::{
    ..base,
    max_imports: 10,
    max_globals: 1,
    max_body_statements: 462,
  }
}

///|
fn gen_valid_compact_imports_module(ctx : GenValidContext) -> Module {
  let seed = if ctx.use_named_streams {
    ctx.root_seed
  } else {
    ctx.rnd.next_uint64()
  }
  let imports : Array[Import] = []
  let body : Array[Instruction] = [Instruction::i32_const(I32(0))]
  let module_name = Name::new("compact_import_module_\{seed % 17UL}")
  let function_type = ExternType::func(TypeIdx::new(0U))
  let mut functions = 0U
  let mut globals = 0U
  let count = 3 + (seed % 3UL).to_int()
  for index = 0; index < count; index = index + 1 {
    if (seed & 1UL) != 0UL && index == 1 {
      imports.push(
        Import::new(
          module_name,
          Name::new("global_\{index}"),
          ExternType::global(GlobalType::new(ValType::i32(), false)),
        ),
      )
      body.push(Instruction::global_get(GlobalIdx::new(globals)))
      globals += 1U
    } else {
      imports.push(
        Import::new(module_name, Name::new("func_\{index}"), function_type),
      )
      body.push(Instruction::call(FuncIdx::new(functions)))
      functions += 1U
    }
    body.push(Instruction::i32_add())
  }
  // A different module splits the run. Later imports with the original module
  // remain in place, including their independent function/global index spaces.
  for index = 0; index < 3; index = index + 1 {
    imports.push(
      Import::new(
        if index == 0 {
          Name::new("other_module")
        } else {
          module_name
        },
        Name::new("tail_\{index}"),
        function_type,
      ),
    )
    body.push(Instruction::call(FuncIdx::new(functions)))
    body.push(Instruction::i32_add())
    functions += 1U
  }
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(SubType::comp_type(CompType::func([], [ValType::i32()]))),
    ]),
  )
  .with_import_sec(ImportSec::new(imports))
  .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
  .with_code_sec(CodeSec::new([Func::new(Locals::empty(), Expr::new(body))]))
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::new("run"), ExternIdx::func(FuncIdx::new(functions))),
    ]),
  )
}
