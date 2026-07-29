///|
fn gen_valid_reorder_globals_profile_config(
  profile : GenValidProfile,
) -> GenValidConfig {
  let base = GenValidConfig::binaryen_oracle_coverage_forced_default()
  let uses_imports = profile == ReorderGlobalsImportedProfile ||
    profile == ReorderGlobalsModuleCodeProfile
  let profile_tag = match profile {
    ReorderGlobalsHotTrafficProfile => 90
    ReorderGlobalsDependencySearchProfile => 91
    ReorderGlobalsImportedProfile => 92
    ReorderGlobalsModuleCodeProfile => 93
    ReorderGlobalsLegacyEhProfile => 94
    ReorderGlobalsMetadataRemapProfile => 95
    ReorderGlobalsThresholdProfile => 96
    _ => 90
  }
  GenValidConfig::{
    ..base,
    max_type_defs: 2,
    max_imports: if uses_imports {
      129
    } else {
      0
    },
    max_defined_funcs: 1,
    max_tables: if profile == ReorderGlobalsModuleCodeProfile {
      1
    } else {
      0
    },
    max_mems: if profile == ReorderGlobalsModuleCodeProfile {
      1
    } else {
      0
    },
    max_globals: if uses_imports {
      0
    } else {
      129
    },
    max_tags: if profile == ReorderGlobalsLegacyEhProfile {
      1
    } else {
      0
    },
    max_elems: if profile == ReorderGlobalsModuleCodeProfile {
      1
    } else {
      0
    },
    max_datas: if profile == ReorderGlobalsModuleCodeProfile {
      1
    } else {
      0
    },
    max_params: 0,
    max_results: 1,
    max_locals: 0,
    max_body_statements: profile_tag,
    max_body_depth: 4,
    features: GenValidFeatureToggles::{
      ..base.features,
      allow_imports: uses_imports,
      allow_tables: profile == ReorderGlobalsModuleCodeProfile,
      allow_mems: profile == ReorderGlobalsModuleCodeProfile,
      allow_globals: true,
      allow_tags: profile == ReorderGlobalsLegacyEhProfile,
      allow_elems: profile == ReorderGlobalsModuleCodeProfile,
      allow_datas: profile == ReorderGlobalsModuleCodeProfile,
      allow_ref_types: profile == ReorderGlobalsModuleCodeProfile,
      allow_calls: false,
      allow_call_indirect: false,
      allow_tail_calls: false,
      allow_branch_heavy_control: profile == ReorderGlobalsLegacyEhProfile,
      allow_v128: false,
      allow_relaxed_simd: false,
      allow_atomics: false,
      allow_shared_memories: false,
      allow_memory64: false,
      allow_subtyping_topology: false,
      allow_name_custom_sections: profile == ReorderGlobalsMetadataRemapProfile,
      allow_typed_body_generator: false,
      allow_ssa_nomerge_body_generator: false,
      allow_heap_store_optimization_body_generator: false,
      allow_heap2local_body_generator: false,
    },
  }
}

///|
fn gen_valid_is_reorder_globals_profile_config(config : GenValidConfig) -> Bool {
  config == GenValidConfig::for_profile(ReorderGlobalsHotTrafficProfile) ||
  config == GenValidConfig::for_profile(ReorderGlobalsDependencySearchProfile) ||
  config == GenValidConfig::for_profile(ReorderGlobalsImportedProfile) ||
  config == GenValidConfig::for_profile(ReorderGlobalsModuleCodeProfile) ||
  config == GenValidConfig::for_profile(ReorderGlobalsLegacyEhProfile) ||
  config == GenValidConfig::for_profile(ReorderGlobalsMetadataRemapProfile) ||
  config == GenValidConfig::for_profile(ReorderGlobalsThresholdProfile)
}

///|
pub fn gen_valid_reorder_globals_profile_case_label(
  profile : GenValidProfile,
  seed : UInt64,
) -> String? {
  match profile {
    ReorderGlobalsHotTrafficProfile =>
      if (seed & 1UL) == 0UL {
        Some("reorder-globals:function-global-get-traffic")
      } else {
        Some("reorder-globals:function-global-set-traffic")
      }
    ReorderGlobalsDependencySearchProfile =>
      match (seed % 4UL).to_int() {
        0 => Some("reorder-globals:dependency-original-order-win")
        1 => Some("reorder-globals:dependency-summed-count-win")
        2 => Some("reorder-globals:dependency-greedy-win")
        _ => Some("reorder-globals:dependency-branching-dag")
      }
    ReorderGlobalsImportedProfile =>
      Some("reorder-globals:imported-global-sort")
    ReorderGlobalsModuleCodeProfile =>
      match (seed % 4UL).to_int() {
        0 => Some("reorder-globals:element-offset-traffic")
        1 => Some("reorder-globals:data-offset-traffic")
        2 => Some("reorder-globals:table-initializer-traffic")
        _ => Some("reorder-globals:element-item-traffic")
      }
    ReorderGlobalsLegacyEhProfile =>
      match (seed % 5UL).to_int() {
        0 => Some("reorder-globals:legacy-eh-protected")
        1 => Some("reorder-globals:legacy-eh-typed-catch")
        2 => Some("reorder-globals:legacy-eh-catch-all")
        3 => Some("reorder-globals:legacy-eh-delegate")
        _ => Some("reorder-globals:try-table-protected")
      }
    ReorderGlobalsMetadataRemapProfile =>
      Some("reorder-globals:export-and-name-remap")
    ReorderGlobalsThresholdProfile =>
      match (seed % 3UL).to_int() {
        0 => Some("reorder-globals:127-global-public-noop")
        1 => Some("reorder-globals:128-global-cost-tie")
        _ => Some("reorder-globals:129-global-uleb-win")
      }
    _ => None
  }
}

///|
fn gen_valid_rg_void_type() -> RecType {
  RecType::new(SubType::comp_type(CompType::func([], [])))
}

///|
fn gen_valid_rg_i32_result_type() -> RecType {
  RecType::new(SubType::comp_type(CompType::func([], [ValType::i32()])))
}

///|
fn gen_valid_rg_i32_global(value : Int, mutable_? : Bool = false) -> Global {
  Global::new(
    GlobalType::new(ValType::i32(), mutable_),
    Expr::new([Instruction::i32_const(I32(value))]),
  )
}

///|
fn gen_valid_rg_i32_globals(
  count : Int,
  mutable_? : Bool = false,
) -> Array[Global] {
  let globals : Array[Global] = Array::new(capacity=count)
  for idx = 0; idx < count; idx = idx + 1 {
    globals.push(gen_valid_rg_i32_global(idx, mutable_~))
  }
  globals
}

///|
fn gen_valid_rg_drop_gets(
  global_idx : UInt,
  repetitions : Int,
) -> Array[Instruction] {
  let body : Array[Instruction] = []
  for rep = 0; rep < repetitions; rep = rep + 1 {
    ignore(rep)
    body.push(Instruction::global_get(GlobalIdx::new(global_idx)))
    body.push(Instruction::drop())
  }
  body
}

///|
fn gen_valid_rg_void_module(
  globals : Array[Global],
  body : Array[Instruction],
) -> Module {
  Module::new()
  .with_type_sec(TypeSec::new([gen_valid_rg_void_type()]))
  .with_global_sec(GlobalSec::new(globals))
  .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
  .with_code_sec(CodeSec::new([Func::new(Locals::empty(), Expr::new(body))]))
}

///|
fn gen_valid_rg_hot_traffic_module(seed : UInt64) -> Module {
  if (seed & 1UL) == 0UL {
    gen_valid_rg_void_module(
      gen_valid_rg_i32_globals(129),
      gen_valid_rg_drop_gets(128U, 1 + ((seed >> 8) % 7UL).to_int()),
    )
  } else {
    let body : Array[Instruction] = []
    let repetitions = 2 + ((seed >> 8) % 5UL).to_int()
    for rep = 0; rep < repetitions; rep = rep + 1 {
      body.push(Instruction::i32_const(I32(rep)))
      body.push(Instruction::global_set(GlobalIdx::new(128U)))
    }
    body.push(Instruction::global_get(GlobalIdx::new(0U)))
    body.push(Instruction::drop())
    gen_valid_rg_void_module(gen_valid_rg_i32_globals(129, mutable_=true), body)
  }
}

///|
fn gen_valid_rg_dependency_chain_globals(other_position : Int) -> Array[Global] {
  let globals : Array[Global] = Array::new(capacity=129)
  let mut chain_old_idx = 0
  for idx = 0; idx < 129; idx = idx + 1 {
    if idx == other_position {
      globals.push(gen_valid_rg_i32_global(9000))
    } else if chain_old_idx == 0 {
      globals.push(gen_valid_rg_i32_global(1))
      chain_old_idx += 1
    } else {
      let previous_abs = idx - 1
      let dependency = if previous_abs == other_position {
        previous_abs - 1
      } else {
        previous_abs
      }
      globals.push(
        Global::new(
          GlobalType::new(ValType::i32(), false),
          Expr::new([
            Instruction::global_get(
              GlobalIdx::new(dependency.reinterpret_as_uint()),
            ),
          ]),
        ),
      )
      chain_old_idx += 1
    }
  }
  globals
}

///|
fn gen_valid_rg_dependency_search_module(seed : UInt64) -> Module {
  match (seed % 4UL).to_int() {
    0 => {
      let globals = gen_valid_rg_dependency_chain_globals(128)
      let body = gen_valid_rg_drop_gets(127U, 10)
      for instr in gen_valid_rg_drop_gets(128U, 2) {
        body.push(instr)
      }
      gen_valid_rg_void_module(globals, body)
    }
    1 => {
      let globals = gen_valid_rg_dependency_chain_globals(2)
      let body = gen_valid_rg_drop_gets(128U, 10)
      for instr in gen_valid_rg_drop_gets(2U, 2) {
        body.push(instr)
      }
      gen_valid_rg_void_module(globals, body)
    }
    2 =>
      gen_valid_rg_void_module(
        gen_valid_rg_dependency_chain_globals(128),
        gen_valid_rg_drop_gets(128U, 4),
      )
    _ => {
      let globals = gen_valid_rg_i32_globals(129)
      globals[126] = Global::new(
        GlobalType::new(ValType::i32(), false),
        Expr::new([Instruction::global_get(GlobalIdx::new(0U))]),
      )
      globals[127] = Global::new(
        GlobalType::new(ValType::i32(), false),
        Expr::new([Instruction::global_get(GlobalIdx::new(1U))]),
      )
      globals[128] = Global::new(
        GlobalType::new(ValType::i32(), false),
        Expr::new([
          Instruction::global_get(GlobalIdx::new(126U)),
          Instruction::global_get(GlobalIdx::new(127U)),
          Instruction::i32_add(),
        ]),
      )
      gen_valid_rg_void_module(globals, gen_valid_rg_drop_gets(128U, 8))
    }
  }
}

///|
fn gen_valid_rg_imported_module(seed : UInt64) -> Module {
  let imports : Array[Import] = Array::new(capacity=129)
  for idx = 0; idx < 129; idx = idx + 1 {
    imports.push(
      Import::new(
        Name::from_string("rg"),
        Name::from_string("g\{idx}-\{(seed >> 8) & 0xffUL}"),
        ExternType::global(GlobalType::new(ValType::i32(), false)),
      ),
    )
  }
  Module::new()
  .with_type_sec(TypeSec::new([gen_valid_rg_i32_result_type()]))
  .with_import_sec(ImportSec::new(imports))
  .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(0U))),
    ]),
  )
  .with_code_sec(
    CodeSec::new([
      Func::new(
        Locals::empty(),
        Expr::new([Instruction::global_get(GlobalIdx::new(128U))]),
      ),
    ]),
  )
}

///|
fn gen_valid_rg_global_imports(
  count : Int,
  value_type : ValType,
) -> Array[Import] {
  let imports : Array[Import] = Array::new(capacity=count)
  for idx = 0; idx < count; idx = idx + 1 {
    imports.push(
      Import::new(
        Name::from_string("rg-module-code"),
        Name::from_string("g\{idx}"),
        ExternType::global(GlobalType::new(value_type, false)),
      ),
    )
  }
  imports
}

///|
fn gen_valid_rg_module_code_module(seed : UInt64) -> Module {
  let variant = (seed % 4UL).to_int()
  let funcref = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let mut mod_ = Module::new()
    .with_type_sec(TypeSec::new([gen_valid_rg_void_type()]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([Func::new(Locals::empty(), Expr::new([Instruction::nop()]))]),
    )
  mod_ = mod_.with_import_sec(
    ImportSec::new(
      gen_valid_rg_global_imports(
        129,
        if variant <= 1 {
          ValType::i32()
        } else {
          ValType::funcref()
        },
      ),
    ),
  )
  match variant {
    0 =>
      mod_
      .with_table_sec(
        TableSec::new([
          Table::new(TableType::new(funcref, Limits::i32(1U, None)), None),
        ]),
      )
      .with_elem_sec(
        ElemSec::new([
          Elem::new(
            ElemMode::active(
              TableIdx::new(0U),
              Expr::new([Instruction::global_get(GlobalIdx::new(128U))]),
            ),
            ElemKind::funcs([FuncIdx::new(0U)]),
          ),
        ]),
      )
    1 =>
      mod_
      .with_mem_sec(MemSec::new([MemType::new(Limits::i32(1U, None))]))
      .with_data_sec(
        DataSec::new([
          Data::new(
            DataMode::active(
              MemIdx::new(0U),
              Expr::new([Instruction::global_get(GlobalIdx::new(128U))]),
            ),
            Bytes::from_array([0x52]),
          ),
        ]),
      )
    2 =>
      mod_.with_table_sec(
        TableSec::new([
          Table::new(
            TableType::new(funcref, Limits::i32(1U, None)),
            Some(Expr::new([Instruction::global_get(GlobalIdx::new(128U))])),
          ),
        ]),
      )
    _ =>
      mod_.with_elem_sec(
        ElemSec::new([
          Elem::new(
            ElemMode::passive(),
            ElemKind::typed_exprs(funcref, [
              Expr::new([Instruction::global_get(GlobalIdx::new(128U))]),
            ]),
          ),
        ]),
      )
  }
}

///|
fn gen_valid_rg_legacy_eh_module(seed : UInt64) -> Module {
  let tag = TagIdx::new(0U)
  let hot = Expr::new(gen_valid_rg_drop_gets(128U, 4))
  let body = match (seed % 5UL).to_int() {
    0 =>
      [
        Instruction::try_(BlockType::void_(), hot, [
          @lib.LegacyCatch::tagged(tag, Expr::new([Instruction::nop()])),
        ]),
      ]
    1 =>
      [
        Instruction::try_(
          BlockType::void_(),
          Expr::new([Instruction::throw_(tag)]),
          [@lib.LegacyCatch::tagged(tag, hot)],
        ),
      ]
    2 =>
      [
        Instruction::try_(
          BlockType::void_(),
          Expr::new([Instruction::throw_(tag)]),
          [@lib.LegacyCatch::all(hot)],
        ),
      ]
    3 =>
      [
        Instruction::try_(
          BlockType::void_(),
          Expr::new([
            Instruction::try_(
              BlockType::void_(),
              hot,
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
              hot,
            ),
          ]),
        ),
      ]
  }
  gen_valid_rg_void_module(gen_valid_rg_i32_globals(129), body).with_tag_sec(
    TagSec::new([TagType::new(TypeIdx::new(0U))]),
  )
}

///|
fn gen_valid_rg_metadata_module(seed : UInt64) -> Module {
  let salt = ((seed >> 8) & 0xffUL).to_int()
  gen_valid_rg_void_module(
    gen_valid_rg_i32_globals(129),
    gen_valid_rg_drop_gets(128U, 3 + salt % 4),
  )
  .with_export_sec(
    ExportSec::new([
      Export::new(
        Name::from_string("hot"),
        ExternIdx::global(GlobalIdx::new(128U)),
      ),
    ]),
  )
  .with_name_sec(
    NameSec::new(
      global_names=Some(
        NameMap::new([
          NameAssoc::new(0U, Name::from_string("cold")),
          NameAssoc::new(128U, Name::from_string("hot")),
        ]),
      ),
    ),
  )
}

///|
fn gen_valid_rg_threshold_module(seed : UInt64) -> Module {
  let count = match (seed % 3UL).to_int() {
    0 => 127
    1 => 128
    _ => 129
  }
  gen_valid_rg_void_module(
    gen_valid_rg_i32_globals(count),
    gen_valid_rg_drop_gets((count - 1).reinterpret_as_uint(), 4),
  )
}

///|
fn gen_valid_reorder_globals_profile_module(ctx : GenValidContext) -> Module {
  let config = ctx.config
  if config ==
    GenValidConfig::for_profile(ReorderGlobalsDependencySearchProfile) {
    gen_valid_rg_dependency_search_module(ctx.root_seed)
  } else if config == GenValidConfig::for_profile(ReorderGlobalsImportedProfile) {
    gen_valid_rg_imported_module(ctx.root_seed)
  } else if config ==
    GenValidConfig::for_profile(ReorderGlobalsModuleCodeProfile) {
    gen_valid_rg_module_code_module(ctx.root_seed)
  } else if config == GenValidConfig::for_profile(ReorderGlobalsLegacyEhProfile) {
    gen_valid_rg_legacy_eh_module(ctx.root_seed)
  } else if config ==
    GenValidConfig::for_profile(ReorderGlobalsMetadataRemapProfile) {
    gen_valid_rg_metadata_module(ctx.root_seed)
  } else if config ==
    GenValidConfig::for_profile(ReorderGlobalsThresholdProfile) {
    gen_valid_rg_threshold_module(ctx.root_seed)
  } else {
    gen_valid_rg_hot_traffic_module(ctx.root_seed)
  }
}
