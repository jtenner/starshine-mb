///|
fn gen_valid_array_memory_config() -> GenValidConfig {
  let base = GenValidConfig::binaryen_oracle_coverage_forced_default()
  GenValidConfig::{
    ..base,
    max_type_defs: 2,
    max_imports: 0,
    max_defined_funcs: 1,
    max_tables: 0,
    max_mems: 0,
    max_globals: 0,
    max_tags: 0,
    max_elems: 0,
    max_datas: 0,
    max_params: 3,
    max_results: 1,
    max_locals: 0,
    max_body_statements: 460,
    max_body_depth: 1,
  }
}

///|
fn gen_valid_array_memory_module(ctx : GenValidContext) -> Module {
  let seed = if ctx.use_named_streams {
    ctx.root_seed
  } else {
    ctx.rnd.next_uint64()
  }
  let ti = TypeIdx::new(0U)
  let cases = [
    (
      Instruction::array_load(@lib.LoadOp::i32_load(), ti),
      ValType::i32(),
      2U,
      false,
    ),
    (
      Instruction::array_load(@lib.LoadOp::i64_load(), ti),
      ValType::i64(),
      3U,
      false,
    ),
    (
      Instruction::array_load(@lib.LoadOp::f32_load(), ti),
      ValType::f32(),
      2U,
      false,
    ),
    (
      Instruction::array_load(@lib.LoadOp::f64_load(), ti),
      ValType::f64(),
      3U,
      false,
    ),
    (
      Instruction::array_load(@lib.LoadOp::i32_load8s(), ti),
      ValType::i32(),
      0U,
      false,
    ),
    (
      Instruction::array_load(@lib.LoadOp::i32_load8u(), ti),
      ValType::i32(),
      0U,
      false,
    ),
    (
      Instruction::array_load(@lib.LoadOp::i32_load16s(), ti),
      ValType::i32(),
      1U,
      false,
    ),
    (
      Instruction::array_load(@lib.LoadOp::i32_load16u(), ti),
      ValType::i32(),
      1U,
      false,
    ),
    (
      Instruction::array_load(@lib.LoadOp::i64_load8s(), ti),
      ValType::i64(),
      0U,
      false,
    ),
    (
      Instruction::array_load(@lib.LoadOp::i64_load8u(), ti),
      ValType::i64(),
      0U,
      false,
    ),
    (
      Instruction::array_load(@lib.LoadOp::i64_load16s(), ti),
      ValType::i64(),
      1U,
      false,
    ),
    (
      Instruction::array_load(@lib.LoadOp::i64_load16u(), ti),
      ValType::i64(),
      1U,
      false,
    ),
    (
      Instruction::array_load(@lib.LoadOp::i64_load32s(), ti),
      ValType::i64(),
      2U,
      false,
    ),
    (
      Instruction::array_load(@lib.LoadOp::i64_load32u(), ti),
      ValType::i64(),
      2U,
      false,
    ),
    (
      Instruction::array_load(@lib.LoadOp::v128_load(), ti),
      ValType::v128(),
      4U,
      false,
    ),
    (
      Instruction::array_store(@lib.StoreOp::i32_store(), ti),
      ValType::i32(),
      2U,
      true,
    ),
    (
      Instruction::array_store(@lib.StoreOp::i64_store(), ti),
      ValType::i64(),
      3U,
      true,
    ),
    (
      Instruction::array_store(@lib.StoreOp::f32_store(), ti),
      ValType::f32(),
      2U,
      true,
    ),
    (
      Instruction::array_store(@lib.StoreOp::f64_store(), ti),
      ValType::f64(),
      3U,
      true,
    ),
    (
      Instruction::array_store(@lib.StoreOp::i32_store8(), ti),
      ValType::i32(),
      0U,
      true,
    ),
    (
      Instruction::array_store(@lib.StoreOp::i32_store16(), ti),
      ValType::i32(),
      1U,
      true,
    ),
    (
      Instruction::array_store(@lib.StoreOp::i64_store8(), ti),
      ValType::i64(),
      0U,
      true,
    ),
    (
      Instruction::array_store(@lib.StoreOp::i64_store16(), ti),
      ValType::i64(),
      1U,
      true,
    ),
    (
      Instruction::array_store(@lib.StoreOp::i64_store32(), ti),
      ValType::i64(),
      2U,
      true,
    ),
    (
      Instruction::array_store(@lib.StoreOp::v128_store(), ti),
      ValType::v128(),
      4U,
      true,
    ),
  ]
  let (original, value_type, maximum, store) = cases[(seed % 25UL).to_int()]
  let align = (seed / 25UL % (maximum + 1U).to_uint64()).to_uint()
  let offset = [0UL, 1UL, 17UL, 0xffffffffUL][(seed / 7UL % 4UL).to_int()]
  let ma = MemArg::new(align, None, offset)
  let op = match original {
    Instruction::ArrayLoad(op, ti, _) =>
      Instruction::array_load(op, ti, memarg=ma)
    Instruction::ArrayStore(op, ti, _) =>
      Instruction::array_store(op, ti, memarg=ma)
    _ => original
  }
  let storage = [
      StorageType::pack_type(PackType::i8()),
      StorageType::pack_type(PackType::i16()),
      StorageType::val_type(ValType::i32()),
      StorageType::val_type(ValType::i64()),
      StorageType::val_type(ValType::f32()),
      StorageType::val_type(ValType::f64()),
      StorageType::val_type(ValType::v128()),
    ][(seed / 3UL % 7UL).to_int()]
  let params = [ValType::ref_array_nullable(ti), ValType::i32()]
  let body = [
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::local_get(LocalIdx::new(1U)),
  ]
  if store {
    params.push(value_type)
    body.push(Instruction::local_get(LocalIdx::new(2U)))
  }
  body.push(op)
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(
        SubType::comp_type(
          CompType::array(
            FieldType::new(
              storage,
              if store || (seed & 4UL) != 0UL {
                Mut::var_()
              } else {
                Mut::const_()
              },
            ),
          ),
        ),
      ),
      RecType::new(
        SubType::comp_type(
          CompType::func(params, if store { [] } else { [value_type] }),
        ),
      ),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(1U)]))
  .with_code_sec(
    CodeSec::new([Func::new(Locals::from_types([]), Expr::new(body))]),
  )
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(0U))),
    ]),
  )
}
