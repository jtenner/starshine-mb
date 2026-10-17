// Original Starshine generator; licensing scope: ../../LICENSE.
// Copyright 2026 Joshua Tenner. No upstream counterpart is claimed.

///|
fn gen_valid_msf_record_copy_config() -> GenValidConfig {
  let base = GenValidConfig::binaryen_oracle_coverage_forced_default()
  GenValidConfig::{
    ..base,
    max_type_defs: 7,
    max_imports: 1,
    max_defined_funcs: 38,
    max_tables: 0,
    max_mems: 0,
    max_globals: 1,
    max_tags: 0,
    max_elems: 0,
    max_datas: 0,
    max_params: 2,
    max_results: 1,
    max_locals: 2,
    max_body_statements: 3000,
    max_body_depth: 40,
    max_module_byte_size_budget: Some(200013),
    features: GenValidFeatureToggles::{
      ..base.features,
      allow_imports: true,
      allow_tables: false,
      allow_mems: false,
      allow_globals: true,
      allow_tags: false,
      allow_start: false,
      allow_elems: false,
      allow_datas: false,
      allow_ref_types: true,
      allow_calls: true,
      allow_call_indirect: false,
      allow_tail_calls: false,
      allow_typed_body_generator: true,
    },
  }
}

///|
// Every generated input contains 8..12 matching copies of a 12..32-field
// immutable record. Ordinary i32 exports execute the copies in generic runtime
// comparison; typed exports independently expose null traps and old/new aliases.
fn gen_valid_msf_record_copy_module(seed : UInt64) -> Module {
  let fields = 12 + (seed % 21UL).to_int()
  let arms = 8 + (seed % 5UL).to_int()
  let initial = 100 + ((seed >> 8) % 1000UL).to_int()
  let replacement = 41 + ((seed >> 20) % 1000UL).to_int()
  let i32 = ValType::i32()
  let record = TypeIdx::new(0U)
  let ref_ = ValType::ref_type(RefType::new(true, HeapType::new(record)))
  let nonnull = ValType::ref_type(RefType::new(false, HeapType::new(record)))
  let types = [
    RecType::new(
      SubType::comp_type(
        CompType::struct_(
          Array::make(
            fields,
            FieldType::new(StorageType::val_type(i32), Mut::const_()),
          ),
        ),
      ),
    ),
    RecType::new(SubType::comp_type(CompType::func([i32], []))),
    RecType::new(SubType::comp_type(CompType::func([], [nonnull]))),
    RecType::new(SubType::comp_type(CompType::func([ref_, i32], [ref_]))),
    RecType::new(SubType::comp_type(CompType::func([ref_], [i32]))),
    RecType::new(SubType::comp_type(CompType::func([i32], [i32]))),
    RecType::new(SubType::comp_type(CompType::func([ref_, ref_], [i32]))),
  ]
  let make_body : Array[Instruction] = []
  for field in 0..<fields {
    make_body.push(Instruction::i32_const(I32(initial + field)))
  }
  make_body.push(Instruction::struct_new(record))
  let mut chain = [Instruction::local_get(LocalIdx::new(0U))]
  for selected = arms - 1; selected >= 0; selected = selected - 1 {
    let arm : Array[Instruction] = []
    for field in 0..<fields {
      if selected == field {
        arm.push(Instruction::i32_const(I32(replacement + selected)))
      } else {
        arm.append([
          Instruction::local_get(LocalIdx::new(0U)),
          Instruction::struct_get(record, U32(field.reinterpret_as_uint())),
        ])
      }
    }
    arm.push(Instruction::struct_new(record))
    chain = [
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::i32_const(I32(selected)),
      Instruction::i32_eq(),
      Instruction::if_(BlockType::val_type(ref_), arm, Some(chain)),
    ]
  }
  let update_body = [
    Instruction::local_get(LocalIdx::new(1U)),
    Instruction::call(FuncIdx::new(0U)),
    Instruction::global_get(GlobalIdx::new(0U)),
    Instruction::i32_const(I32(1)),
    Instruction::i32_add(),
    Instruction::global_set(GlobalIdx::new(0U)),
  ]
  update_body.append(chain)
  let run_body = [
    Instruction::call(FuncIdx::new(1U)),
    Instruction::local_set(LocalIdx::new(1U)),
    Instruction::local_get(LocalIdx::new(1U)),
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::call(FuncIdx::new(2U)),
    Instruction::local_set(LocalIdx::new(2U)),
    Instruction::local_get(LocalIdx::new(1U)),
    Instruction::local_get(LocalIdx::new(2U)),
    Instruction::ref_eq(),
    Instruction::i32_const(I32(10000)),
    Instruction::i32_mul(),
  ]
  for field in 0..<fields {
    run_body.append([
      Instruction::local_get(LocalIdx::new(2U)),
      Instruction::struct_get(record, U32(field.reinterpret_as_uint())),
      Instruction::i32_add(),
    ])
  }
  let funcs = [
    Func::new(Locals::empty(), Expr::new(make_body)),
    Func::new(Locals::empty(), Expr::new(update_body)),
    Func::new(Locals::single(2U, ref_), Expr::new(run_body)),
    Func::new(
      Locals::empty(),
      Expr::new([
        Instruction::ref_null(HeapType::new(record)),
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::call(FuncIdx::new(2U)),
        Instruction::ref_is_null(),
      ]),
    ),
    Func::new(
      Locals::empty(),
      Expr::new([
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::local_get(LocalIdx::new(1U)),
        Instruction::ref_eq(),
      ]),
    ),
  ]
  let type_idxs = [
    TypeIdx::new(2U),
    TypeIdx::new(3U),
    TypeIdx::new(5U),
    TypeIdx::new(5U),
    TypeIdx::new(6U),
  ]
  let exports = [
    Export::new(Name::from_string("make"), ExternIdx::func(FuncIdx::new(1U))),
    Export::new(Name::from_string("update"), ExternIdx::func(FuncIdx::new(2U))),
    Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(3U))),
    Export::new(Name::from_string("trap"), ExternIdx::func(FuncIdx::new(4U))),
    Export::new(Name::from_string("same"), ExternIdx::func(FuncIdx::new(5U))),
    Export::new(
      Name::from_string("seen"),
      ExternIdx::global(GlobalIdx::new(0U)),
    ),
  ]
  for field in 0..<fields {
    exports.push(
      Export::new(
        Name::from_string("field\{field}"),
        ExternIdx::func(FuncIdx::new((6 + field).reinterpret_as_uint())),
      ),
    )
    type_idxs.push(TypeIdx::new(4U))
    funcs.push(
      Func::new(
        Locals::empty(),
        Expr::new([
          Instruction::local_get(LocalIdx::new(0U)),
          Instruction::struct_get(record, U32(field.reinterpret_as_uint())),
        ]),
      ),
    )
  }
  Module::new()
  .with_type_sec(TypeSec::new(types))
  .with_import_sec(
    ImportSec::new([
      Import::new(
        Name::from_string("env"),
        Name::from_string("observe"),
        ExternType::func(TypeIdx::new(1U)),
      ),
    ]),
  )
  .with_func_sec(FuncSec::new(type_idxs))
  .with_code_sec(CodeSec::new(funcs))
  .with_global_sec(
    GlobalSec::new([
      Global::new(
        GlobalType::new(i32, true),
        Expr::new([Instruction::i32_const(I32(0))]),
      ),
    ]),
  )
  .with_export_sec(ExportSec::new(exports))
}
