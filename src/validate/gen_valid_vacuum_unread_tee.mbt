///|
fn gen_valid_vacuum_unread_tee_config() -> GenValidConfig {
  let base = GenValidConfig::binaryen_oracle_coverage_forced_default()
  GenValidConfig::{
    ..base,
    max_type_defs: 3,
    max_imports: 1,
    max_defined_funcs: 1,
    max_tables: 0,
    max_mems: 1,
    max_globals: 1,
    max_tags: 1,
    max_elems: 0,
    max_datas: 0,
    max_params: 1,
    max_results: 2,
    max_locals: 1,
    max_body_statements: 30,
    max_body_depth: 4,
    max_module_byte_size_budget: Some(200009),
    features: GenValidFeatureToggles::{
      ..base.features,
      allow_imports: true,
      allow_tables: false,
      allow_mems: true,
      allow_globals: true,
      allow_tags: true,
      allow_elems: false,
      allow_datas: false,
      allow_ref_types: true,
      allow_calls: true,
      allow_call_indirect: false,
      allow_tail_calls: false,
      allow_v128: false,
      allow_relaxed_simd: false,
      allow_memory64: false,
      allow_atomics: false,
      allow_name_custom_sections: false,
      allow_typed_body_generator: true,
    },
  }
}

///|
// Dedicated inputs contain real tees, exported observations and effectful host
// calls. Seed-selected negatives exercise complete-read proof and opaque EH.
fn gen_valid_vacuum_unread_tee_module(seed : UInt64) -> Module {
  let family = (seed % 13UL).to_int()
  let value = @lib.I32(((seed >> 4) & 0x7fffUL).to_int() + 17)
  let i32 = ValType::i32()
  let tee_local = LocalIdx::new(1U)
  let seen = GlobalIdx::new(0U)
  let produce = FuncIdx::new(0U)
  let tag = TagIdx::new(0U)
  let types = [
    RecType::new(SubType::comp_type(CompType::func([i32], [i32]))),
    RecType::new(SubType::comp_type(CompType::func([i32], [i32]))),
  ]
  let mut locals = Locals::single(1U, i32)
  let mut has_tag = false
  let mut has_memory = false
  let body = match family {
    0 =>
      [
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::call(produce),
        Instruction::local_tee(tee_local),
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::i32_add(),
      ]
    1 => {
      types[0] = RecType::new(
        SubType::comp_type(CompType::func([i32], [ValType::i64(), i32])),
      )
      types[1] = types[0]
      [
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::call(produce),
        Instruction::local_tee(tee_local),
      ]
    }
    2 => {
      let ref_ = ValType::externref()
      types[0] = RecType::new(
        SubType::comp_type(CompType::func([ref_], [ref_])),
      )
      types[1] = types[0]
      locals = Locals::single(1U, ref_)
      [
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::call(produce),
        Instruction::local_tee(tee_local),
      ]
    }
    3 | 4 => {
      let struct_ = TypeIdx::new(2U)
      types.push(
        RecType::new(
          SubType::comp_type(
            CompType::struct_([
              FieldType::new(StorageType::val_type(i32), Mut::var_()),
            ]),
          ),
        ),
      )
      let ref_ = ValType::ref_type(
        RefType::new(
          family == 4 || (seed & 16UL) != 0UL,
          HeapType::new(struct_),
        ),
      )
      locals = Locals::single(1U, ref_)
      if family == 3 {
        [
          Instruction::local_get(LocalIdx::new(0U)),
          Instruction::call(produce),
          Instruction::struct_new(struct_),
          Instruction::local_tee(tee_local),
          Instruction::struct_get(struct_, U32(0U)),
        ]
      } else {
        [
          Instruction::local_get(LocalIdx::new(0U)),
          Instruction::call(produce),
          Instruction::drop(),
          Instruction::ref_null(HeapType::new(struct_)),
          Instruction::local_tee(tee_local),
          Instruction::ref_is_null(),
        ]
      }
    }
    5 =>
      [
        Instruction::block(
          BlockType::void_(),
          Expr::new([
            Instruction::loop_(
              BlockType::void_(),
              Expr::new([
                Instruction::local_get(LocalIdx::new(0U)),
                Instruction::call(produce),
                Instruction::local_tee(tee_local),
                Instruction::global_set(seen),
                Instruction::br(LabelIdx::new(1U)),
              ]),
            ),
          ]),
        ),
        Instruction::global_get(seen),
      ]
    6 =>
      [
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::call(produce),
        Instruction::local_tee(tee_local),
        Instruction::global_set(seen),
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::if_(
          BlockType::void_(),
          [Instruction::global_get(seen), Instruction::global_set(seen)],
          Some([
            Instruction::local_get(tee_local),
            Instruction::global_set(seen),
          ]),
        ),
        Instruction::global_get(seen),
      ]
    7 => {
      has_tag = true
      [
        Instruction::block(
          BlockType::void_(),
          Expr::new([
            Instruction::try_table(
              BlockType::void_(),
              [Catch::all(LabelIdx::new(0U))],
              Expr::new([
                Instruction::local_get(LocalIdx::new(0U)),
                Instruction::call(produce),
                Instruction::local_tee(tee_local),
                Instruction::global_set(seen),
                Instruction::throw_(tag),
              ]),
            ),
          ]),
        ),
        Instruction::global_get(seen),
      ]
    }
    8 =>
      [
        Instruction::try_(
          BlockType::val_type(i32),
          Expr::new([
            Instruction::local_get(LocalIdx::new(0U)),
            Instruction::call(produce),
            Instruction::local_tee(tee_local),
          ]),
          [@lib.LegacyCatch::all(Expr::new([Instruction::i32_const(value)]))],
        ),
      ]
    9 => {
      has_tag = true
      [
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::call(produce),
        Instruction::local_tee(tee_local),
        Instruction::drop(),
        Instruction::try_(
          BlockType::void_(),
          Expr::new([Instruction::throw_(tag)]),
          [
            @lib.LegacyCatch::all(
              Expr::new([
                Instruction::local_get(tee_local),
                Instruction::global_set(seen),
              ]),
            ),
          ],
        ),
        Instruction::global_get(seen),
      ]
    }
    10 =>
      [
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::call(produce),
        Instruction::local_tee(tee_local),
        Instruction::global_set(seen),
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::i32_const(@lib.I32(0)),
        Instruction::i32_div_s(),
      ]
    11 =>
      [
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::if_(
          BlockType::void_(),
          [
            Instruction::local_get(LocalIdx::new(0U)),
            Instruction::call(produce),
            Instruction::local_tee(tee_local),
            Instruction::global_set(seen),
          ],
          Some([
            Instruction::i32_const(value),
            Instruction::call(produce),
            Instruction::local_tee(tee_local),
            Instruction::global_set(seen),
          ]),
        ),
        Instruction::global_get(seen),
      ]
    _ => {
      has_memory = true
      [
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::call(produce),
        Instruction::local_tee(tee_local),
        Instruction::global_set(seen),
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::i32_load(gen_valid_memarg()),
      ]
    }
  }
  if has_tag {
    types.push(RecType::new(SubType::comp_type(CompType::func([], []))))
  }
  let mod_ = Module::new()
    .with_type_sec(TypeSec::new(types))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::from_string("env"),
          Name::from_string("produce"),
          ExternType::func(TypeIdx::new(0U)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1U)]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(i32, true),
          Expr::new([Instruction::i32_const(value)]),
        ),
      ]),
    )
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(1U))),
        Export::new(Name::from_string("seen"), ExternIdx::global(seen)),
      ]),
    )
    .with_code_sec(CodeSec::new([Func::new(locals, Expr::new(body))]))
  let mod_ = if has_tag {
    mod_.with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(2U))]))
  } else {
    mod_
  }
  if has_memory {
    mod_.with_mem_sec(MemSec::new([MemType::new(Limits::i32(1U, None))]))
  } else {
    mod_
  }
}
