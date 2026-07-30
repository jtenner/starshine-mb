///|
fn gen_valid_directize_profile_config(
  profile : GenValidProfile,
) -> GenValidConfig {
  let base = GenValidConfig::binaryen_oracle_coverage_forced_default()
  let profile_tag = match profile {
    DirectizeConstantProfile => 110
    DirectizeSelectProfile => 111
    DirectizeTableFactsProfile => 112
    DirectizeTailCallProfile => 113
    DirectizeGcProfile => 114
    DirectizeTable64Profile => 115
    DirectizeLegacyEhProfile => 116
    DirectizeBoundaryProfile => 117
    _ => 110
  }
  GenValidConfig::{
    ..base,
    max_type_defs: 4,
    max_imports: 2,
    max_defined_funcs: 3,
    max_tables: 3,
    max_mems: 0,
    max_globals: 1,
    max_tags: 1,
    max_elems: 4,
    max_datas: 0,
    max_params: 2,
    max_results: 1,
    max_locals: 2,
    max_body_statements: profile_tag,
    max_body_depth: 6,
    features: GenValidFeatureToggles::{
      ..base.features,
      allow_imports: profile == DirectizeBoundaryProfile ||
      profile == DirectizeConstantProfile,
      allow_tables: true,
      allow_mems: false,
      allow_globals: profile == DirectizeConstantProfile,
      allow_tags: profile == DirectizeLegacyEhProfile,
      allow_elems: true,
      allow_datas: false,
      allow_ref_types: true,
      allow_calls: true,
      allow_call_indirect: true,
      allow_tail_calls: profile == DirectizeTailCallProfile,
      allow_branch_heavy_control: profile == DirectizeLegacyEhProfile,
      allow_v128: false,
      allow_relaxed_simd: false,
      allow_atomics: false,
      allow_shared_memories: false,
      allow_memory64: profile == DirectizeTable64Profile,
      allow_subtyping_topology: profile == DirectizeGcProfile,
      allow_name_custom_sections: false,
      allow_typed_body_generator: false,
      allow_ssa_nomerge_body_generator: false,
      allow_heap_store_optimization_body_generator: false,
      allow_heap2local_body_generator: false,
    },
  }
}

///|
fn gen_valid_is_directize_profile_config(config : GenValidConfig) -> Bool {
  config == GenValidConfig::for_profile(DirectizeConstantProfile) ||
  config == GenValidConfig::for_profile(DirectizeSelectProfile) ||
  config == GenValidConfig::for_profile(DirectizeTableFactsProfile) ||
  config == GenValidConfig::for_profile(DirectizeTailCallProfile) ||
  config == GenValidConfig::for_profile(DirectizeGcProfile) ||
  config == GenValidConfig::for_profile(DirectizeTable64Profile) ||
  config == GenValidConfig::for_profile(DirectizeLegacyEhProfile) ||
  config == GenValidConfig::for_profile(DirectizeBoundaryProfile)
}

///|
pub fn gen_valid_directize_profile_case_label(
  profile : GenValidProfile,
  seed : UInt64,
) -> String? {
  match profile {
    DirectizeConstantProfile =>
      match (seed % 5UL).to_int() {
        0 => Some("directize:segment-known")
        1 => Some("directize:defined-hole-trap")
        2 => Some("directize:ref-func-default")
        3 => Some("directize:unknown-default-active-override")
        _ => Some("directize:wrong-type-trap")
      }
    DirectizeSelectProfile =>
      match (seed % 5UL).to_int() {
        0 => Some("directize:select-known-known")
        1 => Some("directize:select-trap-known")
        2 => Some("directize:select-trap-trap")
        3 => Some("directize:select-known-known-condition")
        _ => Some("directize:select-multivalue-results")
      }
    DirectizeTableFactsProfile =>
      match (seed % 5UL).to_int() {
        0 => Some("directize:table-set-barrier")
        1 => Some("directize:table-fill-barrier")
        2 => Some("directize:table-copy-destination-barrier")
        3 => Some("directize:table-init-barrier")
        _ => Some("directize:table-grow-known-and-unknown")
      }
    DirectizeTailCallProfile => Some("directize:return-call-indirect")
    DirectizeGcProfile =>
      if (seed & 1UL) == 0UL {
        Some("directize:gc-subtype-known")
      } else {
        Some("directize:gc-reversed-subtype-trap")
      }
    DirectizeTable64Profile =>
      if (seed & 1UL) == 0UL {
        Some("directize:table64-known")
      } else {
        Some("directize:table64-no-truncation-trap")
      }
    DirectizeLegacyEhProfile =>
      match (seed % 5UL).to_int() {
        0 => Some("directize:legacy-eh-protected")
        1 => Some("directize:legacy-eh-typed-catch")
        2 => Some("directize:legacy-eh-catch-all")
        3 => Some("directize:legacy-eh-delegate")
        _ => Some("directize:try-table-protected")
      }
    DirectizeBoundaryProfile =>
      match (seed % 4UL).to_int() {
        0 => Some("directize:imported-table-negative")
        1 => Some("directize:exported-table-negative")
        2 => Some("directize:passive-declarative-ignored")
        _ => Some("directize:multi-table-positive")
      }
    _ => None
  }
}

///|
fn gen_valid_directize_void_type() -> RecType {
  RecType::new(SubType::comp_type(CompType::func([], [])))
}

///|
fn gen_valid_directize_i32_param_type() -> RecType {
  RecType::new(SubType::comp_type(CompType::func([ValType::i32()], [])))
}

///|
fn gen_valid_directize_funcref() -> RefType {
  RefType::new(true, HeapType::abs(AbsHeapType::func()))
}

///|
fn gen_valid_directize_table(size : UInt, init? : Expr? = None) -> Table {
  Table::new(
    TableType::new(gen_valid_directize_funcref(), Limits::i32(size, Some(size))),
    init,
  )
}

///|
fn gen_valid_directize_active_elem(
  table : UInt,
  offset : Int,
  funcs : Array[FuncIdx],
) -> Elem {
  Elem::new(
    ElemMode::active(
      TableIdx::new(table),
      Expr::new([Instruction::i32_const(I32(offset))]),
    ),
    ElemKind::funcs(funcs),
  )
}

///|
fn gen_valid_directize_call(table : UInt, offset : Int) -> Array[Instruction] {
  [
    Instruction::i32_const(I32(offset)),
    Instruction::call_indirect(TypeIdx::new(0U), TableIdx::new(table)),
  ]
}

///|
fn gen_valid_directize_constant_module(seed : UInt64) -> Module {
  let variant = (seed % 5UL).to_int()
  let target_type = if variant == 4 {
    TypeIdx::new(1U)
  } else {
    TypeIdx::new(0U)
  }
  let table_init = if variant == 2 {
    Some(Expr::new([Instruction::ref_func(FuncIdx::new(0U))]))
  } else if variant == 3 {
    Some(Expr::new([Instruction::ref_null(HeapType::abs(AbsHeapType::func()))]))
  } else {
    None
  }
  let offset = if variant == 1 { 0 } else { 1 }
  let elems = if variant == 0 || variant == 3 || variant == 4 {
    Some(
      ElemSec::new([gen_valid_directize_active_elem(0U, 1, [FuncIdx::new(0U)])]),
    )
  } else {
    None
  }
  let target_body = if variant == 4 {
    [Instruction::local_get(LocalIdx::new(0U)), Instruction::drop()]
  } else {
    [Instruction::nop()]
  }
  let mut mod_ = Module::new()
    .with_type_sec(
      TypeSec::new([
        gen_valid_directize_void_type(),
        gen_valid_directize_i32_param_type(),
      ]),
    )
    .with_func_sec(FuncSec::new([target_type, TypeIdx::new(0U)]))
    .with_table_sec(
      TableSec::new([gen_valid_directize_table(2U, init=table_init)]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::new(Locals::empty(), Expr::new(target_body)),
        Func::new(
          Locals::empty(),
          Expr::new(gen_valid_directize_call(0U, offset)),
        ),
      ]),
    )
  match elems {
    Some(sec) => mod_ = mod_.with_elem_sec(sec)
    None => ()
  }
  mod_
}

///|
fn gen_valid_directize_multivalue_select_module(seed : UInt64) -> Module {
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(
        SubType::comp_type(CompType::func([], [ValType::i32(), ValType::i64()])),
      ),
    ]),
  )
  .with_func_sec(
    FuncSec::new([TypeIdx::new(0U), TypeIdx::new(0U), TypeIdx::new(0U)]),
  )
  .with_table_sec(TableSec::new([gen_valid_directize_table(2U)]))
  .with_elem_sec(
    ElemSec::new([
      gen_valid_directize_active_elem(0U, 0, [
        FuncIdx::new(0U),
        FuncIdx::new(1U),
      ]),
    ]),
  )
  .with_code_sec(
    CodeSec::new([
      Func::new(
        Locals::empty(),
        Expr::new([
          Instruction::i32_const(I32(1)),
          Instruction::i64_const(I64(2L)),
        ]),
      ),
      Func::new(
        Locals::empty(),
        Expr::new([
          Instruction::i32_const(I32(3)),
          Instruction::i64_const(I64(4L)),
        ]),
      ),
      Func::new(
        Locals::empty(),
        Expr::new([
          Instruction::i32_const(I32(0)),
          Instruction::i32_const(I32(1)),
          Instruction::i32_const(I32(((seed >> 8) & 1UL).to_int())),
          Instruction::select(),
          Instruction::call_indirect(TypeIdx::new(0U), TableIdx::new(0U)),
        ]),
      ),
    ]),
  )
}

///|
fn gen_valid_directize_select_module(seed : UInt64) -> Module {
  let variant = (seed % 5UL).to_int()
  if variant == 4 {
    return gen_valid_directize_multivalue_select_module(seed)
  }
  let (left, right) = match variant {
    0 | 3 => (0, 1)
    1 => (7, 1)
    _ => (7, 8)
  }
  Module::new()
  .with_type_sec(TypeSec::new([gen_valid_directize_void_type()]))
  .with_func_sec(
    FuncSec::new([TypeIdx::new(0U), TypeIdx::new(0U), TypeIdx::new(0U)]),
  )
  .with_table_sec(TableSec::new([gen_valid_directize_table(2U)]))
  .with_elem_sec(
    ElemSec::new([
      gen_valid_directize_active_elem(0U, 0, [
        FuncIdx::new(0U),
        FuncIdx::new(1U),
      ]),
    ]),
  )
  .with_code_sec(
    CodeSec::new([
      Func::new(Locals::empty(), Expr::new([Instruction::nop()])),
      Func::new(Locals::empty(), Expr::new([Instruction::nop()])),
      Func::new(
        Locals::empty(),
        Expr::new([
          Instruction::i32_const(I32(left)),
          Instruction::i32_const(I32(right)),
          Instruction::i32_const(I32(((seed >> 8) & 1UL).to_int())),
          Instruction::select(),
          Instruction::call_indirect(TypeIdx::new(0U), TableIdx::new(0U)),
        ]),
      ),
    ]),
  )
}

///|
fn gen_valid_directize_table_facts_module(seed : UInt64) -> Module {
  let variant = (seed % 5UL).to_int()
  let mutation : Array[Instruction] = match variant {
    0 =>
      [
        Instruction::i32_const(I32(0)),
        Instruction::ref_func(FuncIdx::new(0U)),
        Instruction::table_set(TableIdx::new(0U)),
      ]
    1 =>
      [
        Instruction::i32_const(I32(0)),
        Instruction::ref_func(FuncIdx::new(0U)),
        Instruction::i32_const(I32(1)),
        Instruction::table_fill(TableIdx::new(0U)),
      ]
    2 =>
      [
        Instruction::i32_const(I32(0)),
        Instruction::i32_const(I32(0)),
        Instruction::i32_const(I32(1)),
        Instruction::table_copy(TableIdx::new(0U), TableIdx::new(1U)),
      ]
    3 =>
      [
        Instruction::i32_const(I32(0)),
        Instruction::i32_const(I32(0)),
        Instruction::i32_const(I32(1)),
        Instruction::table_init(ElemIdx::new(2U), TableIdx::new(0U)),
      ]
    _ =>
      [
        Instruction::ref_null(HeapType::abs(AbsHeapType::func())),
        Instruction::i32_const(I32(1)),
        Instruction::table_grow(TableIdx::new(0U)),
        Instruction::drop(),
      ]
  }
  let body = mutation.copy()
  body.append(gen_valid_directize_call(0U, 0))
  if variant == 4 {
    body.append(gen_valid_directize_call(0U, 2))
  }
  body.append(gen_valid_directize_call(1U, 0))
  Module::new()
  .with_type_sec(TypeSec::new([gen_valid_directize_void_type()]))
  .with_func_sec(FuncSec::new([TypeIdx::new(0U), TypeIdx::new(0U)]))
  .with_table_sec(
    TableSec::new([gen_valid_directize_table(2U), gen_valid_directize_table(2U)]),
  )
  .with_elem_sec(
    ElemSec::new([
      gen_valid_directize_active_elem(0U, 0, [FuncIdx::new(0U)]),
      gen_valid_directize_active_elem(1U, 0, [FuncIdx::new(0U)]),
      Elem::new(ElemMode::passive(), ElemKind::funcs([FuncIdx::new(0U)])),
    ]),
  )
  .with_code_sec(
    CodeSec::new([
      Func::new(Locals::empty(), Expr::new([Instruction::nop()])),
      Func::new(Locals::empty(), Expr::new(body)),
    ]),
  )
}

///|
fn gen_valid_directize_tail_module(seed : UInt64) -> Module {
  let offset = if (seed & 1UL) == 0UL { 0 } else { 7 }
  Module::new()
  .with_type_sec(TypeSec::new([gen_valid_directize_void_type()]))
  .with_func_sec(FuncSec::new([TypeIdx::new(0U), TypeIdx::new(0U)]))
  .with_table_sec(TableSec::new([gen_valid_directize_table(1U)]))
  .with_elem_sec(
    ElemSec::new([gen_valid_directize_active_elem(0U, 0, [FuncIdx::new(0U)])]),
  )
  .with_code_sec(
    CodeSec::new([
      Func::new(Locals::empty(), Expr::new([Instruction::nop()])),
      Func::new(
        Locals::empty(),
        Expr::new([
          Instruction::i32_const(I32(offset)),
          Instruction::return_call_indirect(TypeIdx::new(0U), TableIdx::new(0U)),
        ]),
      ),
    ]),
  )
}

///|
fn gen_valid_directize_gc_module(seed : UInt64) -> Module {
  let positive = (seed & 1UL) == 0UL
  let super_idx = TypeIdx::new(0U)
  let sub_idx = TypeIdx::new(1U)
  let target_type = if positive { sub_idx } else { super_idx }
  let call_type = if positive { super_idx } else { sub_idx }
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(SubType::new(false, [], CompType::func([], []))),
      RecType::new(SubType::new(true, [super_idx], CompType::func([], []))),
      gen_valid_directize_void_type(),
    ]),
  )
  .with_func_sec(FuncSec::new([target_type, TypeIdx::new(2U)]))
  .with_table_sec(TableSec::new([gen_valid_directize_table(1U)]))
  .with_elem_sec(
    ElemSec::new([gen_valid_directize_active_elem(0U, 0, [FuncIdx::new(0U)])]),
  )
  .with_code_sec(
    CodeSec::new([
      Func::new(Locals::empty(), Expr::new([Instruction::nop()])),
      Func::new(
        Locals::empty(),
        Expr::new([
          Instruction::i32_const(I32(0)),
          Instruction::call_indirect(call_type, TableIdx::new(0U)),
        ]),
      ),
    ]),
  )
}

///|
fn gen_valid_directize_table64_module(seed : UInt64) -> Module {
  let offset = if (seed & 1UL) == 0UL { 1L } else { 4294967297L }
  let funcref = gen_valid_directize_funcref()
  Module::new()
  .with_type_sec(TypeSec::new([gen_valid_directize_void_type()]))
  .with_func_sec(FuncSec::new([TypeIdx::new(0U), TypeIdx::new(0U)]))
  .with_table_sec(
    TableSec::new([
      Table::new(TableType::new(funcref, Limits::i64(2UL, Some(2UL))), None),
    ]),
  )
  .with_elem_sec(
    ElemSec::new([
      Elem::new(
        ElemMode::active(
          TableIdx::new(0U),
          Expr::new([Instruction::i64_const(I64(1L))]),
        ),
        ElemKind::typed_exprs(funcref, [
          Expr::new([Instruction::ref_func(FuncIdx::new(0U))]),
        ]),
      ),
    ]),
  )
  .with_code_sec(
    CodeSec::new([
      Func::new(Locals::empty(), Expr::new([Instruction::nop()])),
      Func::new(
        Locals::empty(),
        Expr::new([
          Instruction::i64_const(I64(offset)),
          Instruction::call_indirect(TypeIdx::new(0U), TableIdx::new(0U)),
        ]),
      ),
    ]),
  )
}

///|
fn gen_valid_directize_legacy_eh_module(seed : UInt64) -> Module {
  let tag = TagIdx::new(0U)
  let call = Expr::new(gen_valid_directize_call(0U, 0))
  let body = match (seed % 5UL).to_int() {
    0 =>
      [
        Instruction::try_(BlockType::void_(), call, [
          @lib.LegacyCatch::tagged(tag, Expr::new([Instruction::nop()])),
        ]),
      ]
    1 =>
      [
        Instruction::try_(
          BlockType::void_(),
          Expr::new([Instruction::throw_(tag)]),
          [@lib.LegacyCatch::tagged(tag, call)],
        ),
      ]
    2 =>
      [
        Instruction::try_(
          BlockType::void_(),
          Expr::new([Instruction::throw_(tag)]),
          [@lib.LegacyCatch::all(call)],
        ),
      ]
    3 =>
      [
        Instruction::try_(
          BlockType::void_(),
          Expr::new([
            Instruction::try_(
              BlockType::void_(),
              call,
              [],
              delegate=Some(LabelIdx::new(0U)),
            ),
          ]),
          [@lib.LegacyCatch::tagged(tag, Expr::new([Instruction::nop()]))],
        ),
      ]
    _ =>
      [
        Instruction::block(
          BlockType::void_(),
          Expr::new([
            Instruction::try_table(
              BlockType::void_(),
              [Catch::new(tag, LabelIdx::new(0U))],
              call,
            ),
          ]),
        ),
      ]
  }
  Module::new()
  .with_type_sec(TypeSec::new([gen_valid_directize_void_type()]))
  .with_func_sec(FuncSec::new([TypeIdx::new(0U), TypeIdx::new(0U)]))
  .with_table_sec(TableSec::new([gen_valid_directize_table(1U)]))
  .with_elem_sec(
    ElemSec::new([gen_valid_directize_active_elem(0U, 0, [FuncIdx::new(0U)])]),
  )
  .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(0U))]))
  .with_code_sec(
    CodeSec::new([
      Func::new(Locals::empty(), Expr::new([Instruction::nop()])),
      Func::new(Locals::empty(), Expr::new(body)),
    ]),
  )
}

///|
fn gen_valid_directize_boundary_module(seed : UInt64) -> Module {
  let variant = (seed % 4UL).to_int()
  let funcref = gen_valid_directize_funcref()
  let imports = if variant == 0 {
    Some(
      ImportSec::new([
        Import::new(
          Name::from_string("directize"),
          Name::from_string("table"),
          ExternType::table(TableType::new(funcref, Limits::i32(1U, Some(1U)))),
        ),
      ]),
    )
  } else {
    None
  }
  let defined_table_idx = if variant == 0 { 1U } else { 0U }
  let mut mod_ = Module::new()
    .with_type_sec(TypeSec::new([gen_valid_directize_void_type()]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U), TypeIdx::new(0U)]))
    .with_table_sec(
      TableSec::new([
        gen_valid_directize_table(1U),
        gen_valid_directize_table(1U),
      ]),
    )
    .with_elem_sec(
      ElemSec::new([
        gen_valid_directize_active_elem(defined_table_idx, 0, [FuncIdx::new(0U)]),
        Elem::new(ElemMode::passive(), ElemKind::funcs([FuncIdx::new(0U)])),
        Elem::new(ElemMode::declarative(), ElemKind::funcs([FuncIdx::new(0U)])),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::new(Locals::empty(), Expr::new([Instruction::nop()])),
        Func::new(
          Locals::empty(),
          Expr::new(gen_valid_directize_call(defined_table_idx, 0)),
        ),
      ]),
    )
  match imports {
    Some(sec) => mod_ = mod_.with_import_sec(sec)
    None => ()
  }
  if variant == 1 {
    mod_ = mod_.with_export_sec(
      ExportSec::new([
        Export::new(
          Name::from_string("table"),
          ExternIdx::table(TableIdx::new(1U)),
        ),
      ]),
    )
  }
  mod_
}

///|
fn gen_valid_directize_profile_module(ctx : GenValidContext) -> Module {
  if ctx.config == GenValidConfig::for_profile(DirectizeSelectProfile) {
    gen_valid_directize_select_module(ctx.root_seed)
  } else if ctx.config ==
    GenValidConfig::for_profile(DirectizeTableFactsProfile) {
    gen_valid_directize_table_facts_module(ctx.root_seed)
  } else if ctx.config == GenValidConfig::for_profile(DirectizeTailCallProfile) {
    gen_valid_directize_tail_module(ctx.root_seed)
  } else if ctx.config == GenValidConfig::for_profile(DirectizeGcProfile) {
    gen_valid_directize_gc_module(ctx.root_seed)
  } else if ctx.config == GenValidConfig::for_profile(DirectizeTable64Profile) {
    gen_valid_directize_table64_module(ctx.root_seed)
  } else if ctx.config == GenValidConfig::for_profile(DirectizeLegacyEhProfile) {
    gen_valid_directize_legacy_eh_module(ctx.root_seed)
  } else if ctx.config == GenValidConfig::for_profile(DirectizeBoundaryProfile) {
    gen_valid_directize_boundary_module(ctx.root_seed)
  } else {
    gen_valid_directize_constant_module(ctx.root_seed)
  }
}
