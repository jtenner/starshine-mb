///|
fn gen_valid_campaign_gc_refs_config() -> GenValidConfig {
  let base = GenValidConfig::binaryen_oracle_coverage_forced_default()
  GenValidConfig::{
    ..base,
    max_type_defs: 6,
    max_imports: 0,
    max_defined_funcs: 1,
    max_tables: 0,
    max_mems: 0,
    max_globals: 0,
    max_tags: 0,
    max_elems: 0,
    max_datas: 0,
    max_params: 0,
    max_results: 1,
    max_locals: 2,
    max_body_statements: 468,
    max_body_depth: 1,
    features: GenValidFeatureToggles::{
      ..base.features,
      allow_ref_types: true,
      allow_subtyping_topology: true,
      allow_typed_body_generator: false,
      allow_ssa_nomerge_body_generator: false,
      allow_heap_store_optimization_body_generator: false,
      allow_heap2local_body_generator: false,
    },
  }
}

///|
fn gen_valid_is_campaign_gc_refs_config(config : GenValidConfig) -> Bool {
  config == gen_valid_campaign_gc_refs_config()
}

///|
fn gen_valid_campaign_gc_refs_module(ctx : GenValidContext) -> Module {
  let seed = if ctx.use_named_streams {
    ctx.root_seed
  } else {
    ctx.rnd.next_uint64()
  }
  let variant = (seed % 8UL).to_int()
  let base_value = @lib.I32(((seed >> 3) & 0x7fffUL).to_int() + 1)
  let other_value = @lib.I32(((seed * 37UL + 17UL) & 0x7fffUL).to_int() + 17)
  let last_value = @lib.I32(((seed * 101UL + 29UL) & 0x7fffUL).to_int() + 43)
  let root_idx = TypeIdx::new(1U)
  let left_idx = TypeIdx::new(2U)
  let right_idx = TypeIdx::new(3U)
  let leaf_idx = TypeIdx::new(4U)
  let array_idx = TypeIdx::new(5U)
  let field32 = FieldType::new(
    StorageType::val_type(ValType::i32()),
    Mut::var_(),
  )
  let field64 = FieldType::new(
    StorageType::val_type(ValType::i64()),
    Mut::var_(),
  )
  let types = [
    RecType::new(SubType::comp_type(CompType::func([], [ValType::i32()]))),
    RecType::new(SubType::new(false, [], CompType::struct_([field32]))),
    RecType::new(
      SubType::new(false, [root_idx], CompType::struct_([field32, field32])),
    ),
    RecType::new(
      SubType::new(
        true,
        [if ((seed >> 3) & 1UL) == 0UL { root_idx } else { left_idx }],
        CompType::struct_([field32, field32, field64]),
      ),
    ),
    RecType::new(
      SubType::new(
        true,
        [left_idx],
        CompType::struct_([field32, field32, field32]),
      ),
    ),
    RecType::new(SubType::comp_type(CompType::array(field32))),
  ]
  let root_local = LocalIdx::new(0U)
  let array_local = LocalIdx::new(1U)
  let body : Array[Instruction] = []
  if variant == 0 {
    body.append([
      Instruction::i32_const(base_value),
      Instruction::i32_const(other_value),
      Instruction::struct_new(left_idx),
      Instruction::local_set(root_local),
      Instruction::local_get(root_local),
      Instruction::ref_test(false, HeapType::new(left_idx)),
      Instruction::drop(),
      Instruction::local_get(root_local),
      Instruction::ref_cast(false, HeapType::new(left_idx)),
      Instruction::struct_get(left_idx, U32(1U)),
    ])
  } else if variant == 1 {
    body.append([
      Instruction::i32_const(base_value),
      Instruction::i32_const(other_value),
      Instruction::i32_const(last_value),
      Instruction::struct_new(leaf_idx),
      Instruction::local_set(root_local),
      Instruction::local_get(root_local),
      Instruction::ref_test(false, HeapType::new(right_idx)),
      Instruction::drop(),
      Instruction::local_get(root_local),
      Instruction::ref_cast(false, HeapType::new(leaf_idx)),
      Instruction::struct_get(leaf_idx, U32(2U)),
    ])
  } else if variant == 2 {
    body.append([
      Instruction::i32_const(base_value),
      Instruction::i32_const(other_value),
      Instruction::i64_const(I64(13L)),
      Instruction::struct_new(right_idx),
      Instruction::local_set(root_local),
      Instruction::local_get(root_local),
      Instruction::ref_test(false, HeapType::new(left_idx)),
      Instruction::drop(),
      Instruction::local_get(root_local),
      Instruction::ref_cast(false, HeapType::new(right_idx)),
      Instruction::struct_get(right_idx, U32(1U)),
    ])
  } else if variant == 3 {
    body.append([
      Instruction::ref_null(HeapType::new(root_idx)),
      Instruction::local_set(root_local),
      Instruction::local_get(root_local),
      Instruction::ref_test(true, HeapType::new(root_idx)),
      Instruction::drop(),
      Instruction::local_get(root_local),
      Instruction::ref_cast(true, HeapType::new(root_idx)),
      Instruction::ref_is_null(),
    ])
  } else if variant == 4 {
    body.append([
      Instruction::i32_const(base_value),
      Instruction::i32_const(other_value),
      Instruction::struct_new(left_idx),
      Instruction::local_set(root_local),
      Instruction::local_get(root_local),
      Instruction::ref_as_non_null(),
      Instruction::ref_cast(false, HeapType::new(left_idx)),
      Instruction::struct_get(left_idx, U32(0U)),
    ])
  } else if variant == 5 {
    body.append([
      Instruction::i32_const(base_value),
      Instruction::i32_const(other_value),
      Instruction::struct_new(left_idx),
      Instruction::local_set(root_local),
      Instruction::local_get(root_local),
      Instruction::ref_cast(false, HeapType::new(left_idx)),
      Instruction::i32_const(last_value),
      Instruction::struct_set(left_idx, U32(1U)),
      Instruction::local_get(root_local),
      Instruction::ref_cast(false, HeapType::new(left_idx)),
      Instruction::struct_get(left_idx, U32(1U)),
    ])
  } else if variant == 6 {
    body.append([
      Instruction::i32_const(base_value),
      Instruction::i32_const(other_value),
      Instruction::array_new_fixed(array_idx, U32(2U)),
      Instruction::local_set(array_local),
      Instruction::local_get(array_local),
      Instruction::i32_const(I32(1)),
      Instruction::i32_const(last_value),
      Instruction::array_set(array_idx),
      Instruction::local_get(array_local),
      Instruction::i32_const(I32(1)),
      Instruction::array_get(array_idx),
    ])
  } else {
    body.append([
      Instruction::i32_const(I32(3)),
      Instruction::array_new_default(array_idx),
      Instruction::local_set(array_local),
      Instruction::local_get(array_local),
      Instruction::array_len(),
      Instruction::local_get(array_local),
      Instruction::i32_const(I32(0)),
      Instruction::array_get(array_idx),
      Instruction::i32_add(),
    ])
  }
  Module::new()
  .with_type_sec(TypeSec::new(types))
  .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
  .with_code_sec(
    CodeSec::new([
      Func::new(
        Locals::from_types([
          ValType::ref_type(RefType::new(true, HeapType::new(root_idx))),
          ValType::ref_type(RefType::new(true, HeapType::new(array_idx))),
        ]),
        Expr::new(body),
      ),
    ]),
  )
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::new("run"), ExternIdx::func(FuncIdx::new(0U))),
    ]),
  )
}
