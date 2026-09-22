///|
fn gen_valid_campaign_segment_state_config() -> GenValidConfig {
  let base = GenValidConfig::binaryen_oracle_coverage_forced_default()
  GenValidConfig::{
    ..base,
    max_type_defs: 1,
    max_imports: 0,
    max_defined_funcs: 2,
    max_tables: 1,
    max_mems: 1,
    max_globals: 0,
    max_tags: 0,
    max_elems: 5,
    max_datas: 4,
    max_params: 0,
    max_results: 0,
    max_locals: 0,
    max_body_statements: 274,
    max_body_depth: 1,
    max_segment_payload_size: 24,
    features: GenValidFeatureToggles::{
      ..base.features,
      allow_imports: false,
      allow_tables: true,
      allow_mems: true,
      allow_globals: false,
      allow_tags: false,
      allow_elems: true,
      allow_datas: true,
      allow_ref_types: true,
      allow_memory64: false,
      allow_atomics: false,
      allow_shared_memories: false,
      allow_name_custom_sections: false,
      allow_typed_body_generator: false,
      allow_ssa_nomerge_body_generator: false,
    },
  }
}

///|
fn gen_valid_campaign_segment_state_bytes(seed : UInt64, salt : Int) -> Bytes {
  let bytes : Array[Byte] = []
  let length = 5 + ((seed + salt.to_uint64() * 11UL) % 7UL).to_int()
  for offset = 0; offset < length; offset = offset + 1 {
    bytes.push(
      ((seed + salt.to_uint64() * 37UL + offset.to_uint64() * 13UL) & 0xffUL).to_byte(),
    )
  }
  Bytes::from_array(bytes)
}

///|
fn gen_valid_campaign_segment_state_module(ctx : GenValidContext) -> Module {
  let seed = ctx.root_seed
  let data_rotation = (seed % 4UL).to_int()
  let swap_passive_elems = ((seed >> 2) & 1UL) != 0UL
  let swap_active_elems = ((seed >> 3) & 1UL) != 0UL
  let data_offset = 8 + ((seed * 7UL + 3UL) % 9UL).to_int()
  let elem_offset = 1 + (seed / 3UL % 2UL).to_int()
  let datas : Array[Data] = []
  let elems : Array[Elem] = []
  let mut active_data = 0U
  let mut first_passive_data = 0U
  let mut second_passive_data = 0U
  let mut first_passive_elem = 0U
  let mut second_passive_elem = 0U
  for slot = 0; slot < 4; slot = slot + 1 {
    let category = (slot + data_rotation) % 4
    let mode = if category == 0 || category == 2 {
      if category == 0 {
        active_data = slot.to_uint()
      }
      DataMode::active(
        MemIdx::new(0U),
        Expr::new([
          Instruction::i32_const(
            I32(if category == 0 { data_offset } else { data_offset + 3 }),
          ),
        ]),
      )
    } else {
      if category == 1 {
        first_passive_data = slot.to_uint()
      } else {
        second_passive_data = slot.to_uint()
      }
      DataMode::passive()
    }
    datas.push(
      Data::new(mode, gen_valid_campaign_segment_state_bytes(seed, category)),
    )
  }
  for slot = 0; slot < 5; slot = slot + 1 {
    // Binaryen 132 addresses passive segments by their passive-only index.
    // Keep them first so its parser accepts both bulk-operation targets.
    let category = match slot {
      0 => if swap_passive_elems { 4 } else { 1 }
      1 => if swap_passive_elems { 1 } else { 4 }
      2 => if swap_active_elems { 3 } else { 0 }
      3 => if swap_active_elems { 0 } else { 3 }
      _ => 2
    }
    let mode = match category {
      0 | 3 =>
        ElemMode::active(
          TableIdx::new(0U),
          Expr::new([
            Instruction::i32_const(
              I32(if category == 0 { elem_offset } else { elem_offset + 1 }),
            ),
          ]),
        )
      1 | 4 => {
        if category == 1 {
          first_passive_elem = slot.to_uint()
        } else {
          second_passive_elem = slot.to_uint()
        }
        ElemMode::passive()
      }
      _ => ElemMode::declarative()
    }
    elems.push(
      Elem::new(
        mode,
        ElemKind::funcs(
          if category == 0 || category == 3 {
            [FuncIdx::new(0U), FuncIdx::new(1U)]
          } else {
            [FuncIdx::new((seed % 2UL).to_uint())]
          },
        ),
      ),
    )
  }
  let run : Array[Instruction] = [
    Instruction::i32_const(I32(32 + (seed * 5UL % 16UL).to_int())),
    Instruction::i32_const(I32(1)),
    Instruction::i32_const(I32(2)),
    Instruction::memory_init(DataIdx::new(first_passive_data), MemIdx::new(0U)),
    Instruction::data_drop(DataIdx::new(first_passive_data)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(0)),
    Instruction::memory_init(DataIdx::new(first_passive_data), MemIdx::new(0U)),
    Instruction::i32_const(I32(48)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(1)),
    Instruction::memory_init(DataIdx::new(second_passive_data), MemIdx::new(0U)),
    Instruction::data_drop(DataIdx::new(second_passive_data)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(1)),
    Instruction::table_init(ElemIdx::new(first_passive_elem), TableIdx::new(0U)),
    Instruction::elem_drop(ElemIdx::new(first_passive_elem)),
    Instruction::i32_const(I32(1)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(1)),
    Instruction::table_init(
      ElemIdx::new(second_passive_elem),
      TableIdx::new(0U),
    ),
    Instruction::elem_drop(ElemIdx::new(second_passive_elem)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(0)),
    Instruction::memory_init(DataIdx::new(active_data), MemIdx::new(0U)),
    Instruction::data_drop(DataIdx::new(active_data)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(0)),
    Instruction::table_init(ElemIdx::new(first_passive_elem), TableIdx::new(0U)),
    Instruction::elem_drop(ElemIdx::new(second_passive_elem)),
  ]
  let probe : Array[Instruction] = []
  if (seed & 1UL) == 0UL {
    probe.append([
      Instruction::i32_const(I32(0)),
      Instruction::i32_const(I32(0)),
      Instruction::i32_const(I32(1)),
      Instruction::memory_init(DataIdx::new(active_data), MemIdx::new(0U)),
    ])
  } else {
    probe.append([
      Instruction::elem_drop(ElemIdx::new(first_passive_elem)),
      Instruction::i32_const(I32(0)),
      Instruction::i32_const(I32(0)),
      Instruction::i32_const(I32(1)),
      Instruction::table_init(
        ElemIdx::new(first_passive_elem),
        TableIdx::new(0U),
      ),
    ])
  }
  Module::new()
  .with_type_sec(
    TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(0U), TypeIdx::new(0U)]))
  .with_table_sec(
    TableSec::new([
      Table::new(
        TableType::new(
          RefType::abs(AbsHeapType::func()),
          Limits::i32(8U, Some(8U)),
        ),
        None,
      ),
    ]),
  )
  .with_mem_sec(MemSec::new([MemType::new(Limits::i32(1U, Some(1U)))]))
  .with_elem_sec(ElemSec::new(elems))
  .with_data_cnt_sec(DataCntSec::new(U32(4U)))
  .with_code_sec(
    CodeSec::new([
      Func::new(Locals::empty(), Expr::new(run)),
      Func::new(Locals::empty(), Expr::new(probe)),
    ]),
  )
  .with_data_sec(DataSec::new(datas))
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::new("run"), ExternIdx::func(FuncIdx::new(0U))),
      Export::new(Name::new("probe"), ExternIdx::func(FuncIdx::new(1U))),
    ]),
  )
}
