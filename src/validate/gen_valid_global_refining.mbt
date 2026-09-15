///|
fn gen_valid_global_refining_profile_config(
  profile : GenValidProfile,
) -> GenValidConfig {
  let base = GenValidConfig::binaryen_oracle_coverage_forced_default()
  let tag = match profile {
    GlobalRefiningPrivateWritesProfile => 180
    GlobalRefiningExportBoundariesProfile => 181
    GlobalRefiningImportAliasesProfile => 182
    GlobalRefiningSubtypeJoinsProfile => 183
    _ => 180
  }
  GenValidConfig::{
    ..base,
    max_type_defs: 8,
    max_imports: 2,
    max_defined_funcs: 1,
    max_globals: 3,
    max_params: 1,
    max_results: 1,
    max_locals: 0,
    max_body_statements: tag,
    max_body_depth: 4,
    features: GenValidFeatureToggles::{
      ..base.features,
      allow_imports: profile == GlobalRefiningImportAliasesProfile,
      allow_globals: true,
      allow_ref_types: true,
      allow_subtyping_topology: true,
      allow_const_expr_variants: true,
      allow_typed_body_generator: false,
      allow_ssa_nomerge_body_generator: false,
      allow_heap_store_optimization_body_generator: false,
      allow_heap2local_body_generator: false,
    },
  }
}

///|
fn gen_valid_is_global_refining_profile_config(config : GenValidConfig) -> Bool {
  [
    GlobalRefiningPrivateWritesProfile,
    GlobalRefiningExportBoundariesProfile,
    GlobalRefiningImportAliasesProfile,
    GlobalRefiningSubtypeJoinsProfile,
  ].any(fn(profile) {
    config == gen_valid_global_refining_profile_config(profile)
  })
}

///|
fn gen_valid_gr_construct(
  type_idx : TypeIdx,
  value : Int,
  extra_field : Bool,
) -> Array[Instruction] {
  let body = [Instruction::i32_const(I32(value))]
  if extra_field {
    body.push(Instruction::i32_const(I32(value + 1)))
  }
  body.push(Instruction::struct_new(type_idx))
  body
}

///|
fn gen_valid_global_refining_profile_module(ctx : GenValidContext) -> Module {
  let config = ctx.config
  let seed = ctx.root_seed
  let value = (seed & 0x7ffffUL).to_int()
  let fields = [
    FieldType::new(StorageType::val_type(ValType::i32()), Mut::const_()),
  ]
  let types = [
    RecType::new(
      SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
    ),
  ]
  let depth = 1 + (seed % 3UL).to_int()
  for level = 0; level < depth; level = level + 1 {
    types.push(
      RecType::new(
        SubType::new(
          false,
          if level == 0 {
            []
          } else {
            [TypeIdx::new(level.to_uint())]
          },
          CompType::struct_(fields),
        ),
      ),
    )
  }
  let parent = TypeIdx::new(depth.to_uint())
  let left = TypeIdx::new((depth + 1).to_uint())
  let right = TypeIdx::new((depth + 2).to_uint())
  types.push(
    RecType::new(SubType::new(true, [parent], CompType::struct_(fields))),
  )
  types.push(
    RecType::new(
      SubType::new(true, [parent], CompType::struct_([fields[0], fields[0]])),
    ),
  )
  let anyref = ValType::ref_type(RefType::abs(AbsHeapType::any()))
  let externref = ValType::ref_type(RefType::abs(AbsHeapType::extern_()))
  let imports : Array[Import] = []
  let globals : Array[Global] = []
  let exports = [
    Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(0U))),
  ]
  let body : Array[Instruction] = []
  let mut target = 0U
  let mut read_target = 0U
  if config ==
    gen_valid_global_refining_profile_config(GlobalRefiningImportAliasesProfile) {
    imports.push(
      Import::new(
        Name::from_string("host"),
        Name::from_string("immutable"),
        ExternType::global(GlobalType::new(externref, false)),
      ),
    )
    imports.push(
      Import::new(
        Name::from_string("host"),
        Name::from_string("mutable"),
        ExternType::global(GlobalType::new(externref, true)),
      ),
    )
    globals.push(
      Global::new(
        GlobalType::new(externref, false),
        Expr::new([Instruction::global_get(GlobalIdx::new(0U))]),
      ),
    )
    globals.push(
      Global::new(
        GlobalType::new(externref, false),
        Expr::new([Instruction::global_get(GlobalIdx::new(2U))]),
      ),
    )
    target = 4U
    read_target = target
    exports.push(
      Export::new(
        Name::from_string("immutable_alias"),
        ExternIdx::global(GlobalIdx::new(3U)),
      ),
    )
    exports.push(
      Export::new(
        Name::from_string("imported_mutable"),
        ExternIdx::global(GlobalIdx::new(1U)),
      ),
    )
    body.append([
      Instruction::global_get(GlobalIdx::new(1U)),
      Instruction::drop(),
      Instruction::global_get(GlobalIdx::new(3U)),
      Instruction::drop(),
    ])
  }
  let nullable = config ==
    gen_valid_global_refining_profile_config(GlobalRefiningPrivateWritesProfile) &&
    (seed & 1UL) != 0UL
  globals.push(
    Global::new(
      GlobalType::new(anyref, true),
      Expr::new(
        if nullable {
          [Instruction::ref_null(HeapType::abs(AbsHeapType::any()))]
        } else {
          gen_valid_gr_construct(left, value, false)
        },
      ),
    ),
  )
  if config ==
    gen_valid_global_refining_profile_config(
      GlobalRefiningExportBoundariesProfile,
    ) {
    globals.push(
      Global::new(
        GlobalType::new(anyref, false),
        Expr::new(gen_valid_gr_construct(left, value, false)),
      ),
    )
    read_target = 1U
    exports.push(
      Export::new(
        Name::from_string("mutable_boundary"),
        ExternIdx::global(GlobalIdx::new(0U)),
      ),
    )
    exports.push(
      Export::new(
        Name::from_string("immutable_boundary"),
        ExternIdx::global(GlobalIdx::new(1U)),
      ),
    )
  }
  if config ==
    gen_valid_global_refining_profile_config(GlobalRefiningSubtypeJoinsProfile) {
    let yes = gen_valid_gr_construct(left, value + 1, false)
    yes.push(Instruction::global_set(GlobalIdx::new(target)))
    let no = gen_valid_gr_construct(right, value + 2, true)
    no.push(Instruction::global_set(GlobalIdx::new(target)))
    body.append([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::if_(BlockType::void_(), yes, Some(no)),
    ])
  } else {
    body.append(gen_valid_gr_construct(left, value + 1, false))
    body.push(Instruction::global_set(GlobalIdx::new(target)))
  }
  body.append([
    Instruction::global_get(GlobalIdx::new(read_target)),
    Instruction::ref_cast(false, HeapType::new(parent)),
    Instruction::struct_get(parent, U32::new(0U)),
  ])
  let mod_ = Module::new()
    .with_type_sec(TypeSec::new(types))
    .with_global_sec(GlobalSec::new(globals))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(CodeSec::new([Func::new(Locals::empty(), Expr::new(body))]))
    .with_export_sec(ExportSec::new(exports))
  if imports.is_empty() {
    mod_
  } else {
    mod_.with_import_sec(ImportSec::new(imports))
  }
}
