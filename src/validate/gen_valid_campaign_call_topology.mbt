///|
fn gen_valid_campaign_call_topology_config() -> GenValidConfig {
  let base = GenValidConfig::binaryen_oracle_coverage_forced_default()
  GenValidConfig::{
    ..base,
    max_type_defs: 1,
    max_imports: 1,
    max_defined_funcs: 3,
    max_tables: 1,
    max_mems: 0,
    max_globals: 1,
    max_tags: 0,
    max_elems: 1,
    max_datas: 0,
    max_params: 1,
    max_results: 1,
    max_locals: 1,
    max_body_statements: 497,
    max_body_depth: 1,
    features: GenValidFeatureToggles::{
      ..base.features,
      allow_imports: true,
      allow_tables: true,
      allow_globals: true,
      allow_elems: true,
      allow_ref_types: true,
      allow_calls: true,
      allow_call_indirect: true,
      allow_tail_calls: true,
    },
  }
}

///|
fn gen_valid_campaign_call_topology_module(ctx : GenValidContext) -> Module {
  let seed = if ctx.use_named_streams {
    ctx.root_seed
  } else {
    ctx.rnd.next_uint64()
  }
  let variant = (seed % 12UL).to_int()
  let topology = (seed / 12UL % 4UL).to_int()
  let reversed_table = seed / 48UL % 2UL != 0UL
  let type_idx = TypeIdx::new(0U)
  let typed_ref = RefType::new(true, HeapType::new(type_idx))
  let arg = Instruction::local_get(LocalIdx::new(0U))
  let first_body = if topology == 1 || topology == 3 {
    [arg, Instruction::call(FuncIdx::new(0U))]
  } else {
    [
      arg,
      Instruction::i32_const(I32((seed >> 8).to_int())),
      Instruction::i32_xor(),
    ]
  }
  let second_body = match topology {
    0 | 1 =>
      [
        arg,
        Instruction::i32_const(I32((seed >> 16).to_int())),
        Instruction::i32_add(),
      ]
    2 => [arg, Instruction::call(FuncIdx::new(1U))]
    _ =>
      [
        arg,
        Instruction::call(FuncIdx::new(0U)),
        arg,
        Instruction::call(FuncIdx::new(1U)),
        Instruction::i32_add(),
      ]
  }
  let body = match variant {
    0 => [arg, Instruction::call(FuncIdx::new(0U))]
    1 => [arg, Instruction::call(FuncIdx::new(1U))]
    2 => [arg, Instruction::call(FuncIdx::new(2U))]
    3 => [arg, Instruction::return_call(FuncIdx::new(0U))]
    4 => [arg, Instruction::return_call(FuncIdx::new(2U))]
    5 =>
      [
        arg,
        Instruction::i32_const(I32(0)),
        Instruction::call_indirect(type_idx, TableIdx::new(0U)),
      ]
    6 =>
      [
        arg,
        Instruction::i32_const(I32(2)),
        Instruction::call_indirect(type_idx, TableIdx::new(0U)),
      ]
    7 =>
      [
        arg,
        Instruction::i32_const(I32(1)),
        Instruction::return_call_indirect(type_idx, TableIdx::new(0U)),
      ]
    8 =>
      [
        arg,
        Instruction::ref_func(FuncIdx::new(1U)),
        Instruction::call_ref(type_idx),
      ]
    9 =>
      [
        arg,
        Instruction::ref_func(FuncIdx::new(2U)),
        Instruction::local_set(LocalIdx::new(1U)),
        Instruction::local_get(LocalIdx::new(1U)),
        Instruction::call_ref(type_idx),
      ]
    10 =>
      [
        arg,
        Instruction::i32_const(I32(2)),
        Instruction::table_get(TableIdx::new(0U)),
        Instruction::return_call_ref(type_idx),
      ]
    _ =>
      [
        arg,
        Instruction::global_get(GlobalIdx::new(0U)),
        Instruction::call_ref(type_idx),
      ]
  }
  let table_funcs = if reversed_table {
    [FuncIdx::new(2U), FuncIdx::new(0U), FuncIdx::new(1U)]
  } else {
    [FuncIdx::new(0U), FuncIdx::new(1U), FuncIdx::new(2U)]
  }
  let table_entries : Array[Expr] = []
  for idx in table_funcs {
    table_entries.push(Expr::new([Instruction::ref_func(idx)]))
  }
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(
        SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
      ),
    ]),
  )
  .with_import_sec(
    ImportSec::new([
      Import::new(
        Name::from_string("campaign"),
        Name::from_string("host"),
        ExternType::func(type_idx),
      ),
    ]),
  )
  .with_func_sec(FuncSec::new([type_idx, type_idx, type_idx]))
  .with_table_sec(
    TableSec::new([
      Table::new(TableType::new(typed_ref, Limits::i32(3U, Some(3U))), None),
    ]),
  )
  .with_global_sec(
    GlobalSec::new([
      Global::new(
        GlobalType::new(ValType::ref_type(typed_ref), false),
        Expr::new([Instruction::ref_func(FuncIdx::new(0U))]),
      ),
    ]),
  )
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(3U))),
    ]),
  )
  .with_elem_sec(
    ElemSec::new([
      Elem::new(
        ElemMode::active(
          TableIdx::new(0U),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
        ElemKind::typed_exprs(typed_ref, table_entries),
      ),
    ]),
  )
  .with_code_sec(
    CodeSec::new([
      Func::new(Locals::empty(), Expr::new(first_body)),
      Func::new(Locals::empty(), Expr::new(second_body)),
      Func::new(
        Locals::from_types([ValType::ref_type(typed_ref)]),
        Expr::new(body),
      ),
    ]),
  )
}
