///|
fn gen_valid_engine_state_profiles() -> Array[GenValidProfile] {
  [
    EngineStateScalarControlProfile,
    EngineStateCallsProfile,
    EngineStateMemoryProfile,
    EngineStateTableProfile,
    EngineStateSimdProfile,
    EngineStateImportsProfile,
    EngineStateInitializationProfile,
    EngineStateTrapProfile,
    EngineStateMixedProfile,
    EngineStateTopologyProfile,
    EngineStateEffectsProfile,
    EngineStateResourcesProfile,
    EngineStateBoundariesProfile,
    EngineStateOptimizerShapesProfile,
    EngineStateEquivalentFamiliesProfile,
    EngineStatePassiveSegmentsProfile,
    EngineStateInstantiationBoundariesProfile,
    EngineStateMultiResourceProfile,
    EngineStateStackPressureProfile,
    EngineStateMemoryAliasingProfile,
    EngineStateIndirectTrapsProfile,
    EngineStateTrapPlacementProfile,
    EngineStateCrossInstanceProfile,
    EngineStateResourceExhaustionProfile,
    EngineStateDecoderTopologyProfile,
    EngineStateTailCallsProfile,
    EngineStateTypedFunctionReferencesProfile,
    EngineStateMemory64Profile,
    EngineStateExceptionsProfile,
    EngineStateGcProfile,
    EngineStateLinkGraphProfile,
    EngineStateGcGraphProfile,
    EngineStateInitializationGraphProfile,
    EngineStateExceptionUnwindProfile,
    EngineStateTypeCallMatrixProfile,
    EngineStateLebIndexBoundariesProfile,
    EngineStateTableReferenceMatrixProfile,
    EngineStateMemory64MultiMemoryProfile,
    EngineStateTrapCommitMatrixProfile,
    EngineStateMetamorphicTwinsProfile,
    EngineStateCompilerBoundariesProfile,
    EngineStateNanProfile,
    EngineStateInvalidModuleProfile,
    EngineStateRecursiveMultivalueProfile,
    EngineStateSubtypeCastGraphProfile,
  ]
}

///|
pub fn gen_valid_engine_state_profile() -> GenValidProfile {
  EngineStateAllProfile
}

///|
fn gen_valid_engine_state_profile_kind(
  config : GenValidConfig,
) -> GenValidProfile {
  for profile in gen_valid_engine_state_profiles() {
    if config == GenValidConfig::for_profile(profile) {
      return profile
    }
  }
  EngineStateScalarControlProfile
}

///|
fn gen_valid_is_engine_state_profile_config(config : GenValidConfig) -> Bool {
  for profile in gen_valid_engine_state_profiles() {
    if config == GenValidConfig::for_profile(profile) {
      return true
    }
  }
  false
}

///|
fn gen_valid_engine_state_func_type(
  params : Array[ValType],
  results : Array[ValType],
) -> RecType {
  RecType::new(SubType::comp_type(CompType::func(params, results)))
}

///|
fn gen_valid_engine_state_type_sec() -> TypeSec {
  TypeSec::new([
    gen_valid_engine_state_func_type([ValType::i32()], [ValType::i32()]),
    gen_valid_engine_state_func_type([ValType::i32()], [ValType::i64()]),
    gen_valid_engine_state_func_type([ValType::i32()], []),
    gen_valid_engine_state_func_type([ValType::i32(), ValType::i32()], []),
    gen_valid_engine_state_func_type([ValType::i32(), ValType::i64()], []),
    gen_valid_engine_state_func_type([], []),
    gen_valid_engine_state_func_type([ValType::i32(), ValType::i32()], [
      ValType::i32(),
    ]),
    gen_valid_engine_state_func_type([ValType::i32()], [ValType::i32()]),
    gen_valid_engine_state_func_type([], [ValType::i32()]),
    gen_valid_engine_state_func_type([ValType::i32(), ValType::i64()], [
      ValType::i32(),
      ValType::i64(),
    ]),
    gen_valid_engine_state_func_type([], [ValType::v128()]),
    gen_valid_engine_state_func_type([ValType::f32(), ValType::f64()], [
      ValType::f32(),
      ValType::f64(),
    ]),
  ])
}

///|
fn gen_valid_engine_state_abi_imports() -> Array[Import] {
  let module_name = Name::from_string("__fuzz")
  [
    Import::new(
      module_name,
      Name::from_string("input_i32"),
      ExternType::func(TypeIdx::new(0U)),
    ),
    Import::new(
      module_name,
      Name::from_string("input_i64"),
      ExternType::func(TypeIdx::new(1U)),
    ),
    Import::new(
      module_name,
      Name::from_string("mark"),
      ExternType::func(TypeIdx::new(2U)),
    ),
    Import::new(
      module_name,
      Name::from_string("observe_i32"),
      ExternType::func(TypeIdx::new(3U)),
    ),
    Import::new(
      module_name,
      Name::from_string("observe_i64"),
      ExternType::func(TypeIdx::new(4U)),
    ),
  ]
}

///|
fn gen_valid_engine_state_seed_i32(seed : UInt64, salt : UInt64) -> @lib.I32 {
  I32(((seed ^ (salt * 0x9e3779b97f4a7c15UL)) % 2147483647UL).to_int())
}

///|
fn gen_valid_engine_state_seed_i64(seed : UInt64, salt : UInt64) -> @lib.I64 {
  I64(
    ((seed ^ (salt * 0xbf58476d1ce4e5b9UL)) % 9223372036854775783UL).to_int64(),
  )
}

///|
fn gen_valid_engine_state_funcref() -> RefType {
  RefType::new(true, HeapType::abs(AbsHeapType::func()))
}

///|
fn gen_valid_engine_state_memarg(align : UInt, offset : UInt64) -> MemArg {
  MemArg::new(U32(align), None, U64(offset))
}

///|
fn gen_valid_engine_state_mark(event : Int) -> Array[Instruction] {
  [Instruction::i32_const(I32(event)), Instruction::call(FuncIdx::new(2U))]
}

///|
fn gen_valid_engine_state_observe_i32(
  value_id : Int,
  value : Array[Instruction],
) -> Array[Instruction] {
  let out = [Instruction::i32_const(I32(value_id))]
  gen_valid_engine_state_append(out, value)
  out.push(Instruction::call(FuncIdx::new(3U)))
  out
}

///|
fn gen_valid_engine_state_observe_i64(
  value_id : Int,
  value : Array[Instruction],
) -> Array[Instruction] {
  let out = [Instruction::i32_const(I32(value_id))]
  gen_valid_engine_state_append(out, value)
  out.push(Instruction::call(FuncIdx::new(4U)))
  out
}

///|
fn gen_valid_engine_state_append(
  target : Array[Instruction],
  source : Array[Instruction],
) -> Unit {
  for instr in source {
    target.push(instr)
  }
}

///|
fn gen_valid_engine_state_function_exports(count : Int) -> Array[Export] {
  let exports : Array[Export] = []
  for i in 0..<count {
    exports.push(
      Export::new(
        Name::from_string("__fuzz_func_\{i}"),
        ExternIdx::func(FuncIdx::new((5 + i).reinterpret_as_uint())),
      ),
    )
  }
  exports
}

///|
fn gen_valid_engine_state_base_module(
  extra_imports : Array[Import],
  function_types : Array[TypeIdx],
  functions : Array[Func],
  exports : Array[Export],
  tables : Array[Table],
  memories : Array[MemType],
  globals : Array[Global],
  elems : Array[Elem],
  datas : Array[Data],
) -> Module {
  let imports = gen_valid_engine_state_abi_imports()
  for import_ in extra_imports {
    imports.push(import_)
  }
  let all_exports = gen_valid_engine_state_function_exports(
    functions.length() - 1,
  )
  for export_ in exports {
    all_exports.push(export_)
  }
  let start_idx = FuncIdx::new(
    (5 + functions.length() - 1).reinterpret_as_uint(),
  )
  let mut mod_ = Module::new()
    .with_type_sec(gen_valid_engine_state_type_sec())
    .with_import_sec(ImportSec::new(imports))
    .with_func_sec(FuncSec::new(function_types))
    .with_start_sec(StartSec::new(start_idx))
    .with_export_sec(ExportSec::new(all_exports))
    .with_code_sec(CodeSec::new(functions))
  if !tables.is_empty() {
    mod_ = mod_.with_table_sec(TableSec::new(tables))
  }
  if !memories.is_empty() {
    mod_ = mod_.with_mem_sec(MemSec::new(memories))
  }
  if !globals.is_empty() {
    mod_ = mod_.with_global_sec(GlobalSec::new(globals))
  }
  if !elems.is_empty() {
    mod_ = mod_.with_elem_sec(ElemSec::new(elems))
  }
  if !datas.is_empty() {
    mod_ = mod_.with_data_sec(DataSec::new(datas))
  }
  mod_
}

///|
fn gen_valid_engine_state_scalar_control_module(seed : UInt64) -> Module {
  let trip_count = (seed % 8UL + 1UL).to_int()
  let loop_leaf = Func::new(
    Locals::from_types([ValType::i32(), ValType::i32()]),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::local_set(LocalIdx::new(2U)),
      Instruction::i32_const(I32(trip_count)),
      Instruction::local_set(LocalIdx::new(3U)),
      Instruction::block(
        BlockType::void_(),
        Expr::new([
          Instruction::loop_(
            BlockType::void_(),
            Expr::new([
              Instruction::local_get(LocalIdx::new(3U)),
              Instruction::i32_eqz(),
              Instruction::br_if(LabelIdx::new(1U)),
              Instruction::local_get(LocalIdx::new(2U)),
              Instruction::local_get(LocalIdx::new(1U)),
              Instruction::i32_add(),
              Instruction::local_set(LocalIdx::new(2U)),
              Instruction::local_get(LocalIdx::new(3U)),
              Instruction::i32_const(I32(1)),
              Instruction::i32_sub(),
              Instruction::local_set(LocalIdx::new(3U)),
              Instruction::br(LabelIdx::new(0U)),
            ]),
          ),
        ]),
      ),
      Instruction::local_get(LocalIdx::new(2U)),
    ]),
  )
  let control_leaf = Func::new(
    Locals::from_types([ValType::i32()]),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::i32_lt_s(),
      Instruction::if_(
        BlockType::val_type(ValType::i32()),
        [
          Instruction::local_get(LocalIdx::new(0U)),
          Instruction::local_get(LocalIdx::new(1U)),
          Instruction::i32_xor(),
        ],
        Some([
          Instruction::local_get(LocalIdx::new(0U)),
          Instruction::local_get(LocalIdx::new(1U)),
          Instruction::i32_or(),
        ]),
      ),
      Instruction::local_tee(LocalIdx::new(2U)),
      Instruction::global_set(GlobalIdx::new(0U)),
      Instruction::local_get(LocalIdx::new(2U)),
    ]),
  )
  let multi_leaf = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_const(gen_valid_engine_state_seed_i32(seed, 1UL)),
      Instruction::i32_add(),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::i64_const(gen_valid_engine_state_seed_i64(seed, 2UL)),
      Instruction::i64_xor(),
    ]),
  )
  let float_leaf = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::f32_abs(),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::f64_neg(),
    ]),
  )
  let start_body : Array[Instruction] = []
  gen_valid_engine_state_append(start_body, gen_valid_engine_state_mark(1000))
  gen_valid_engine_state_append(
    start_body,
    gen_valid_engine_state_observe_i32(0, [
      Instruction::i32_const(I32(0)),
      Instruction::call(FuncIdx::new(0U)),
      Instruction::i32_const(I32(-1)),
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  gen_valid_engine_state_append(start_body, gen_valid_engine_state_mark(1001))
  gen_valid_engine_state_append(
    start_body,
    gen_valid_engine_state_observe_i32(1, [
      Instruction::i32_const(I32(1)),
      Instruction::call(FuncIdx::new(0U)),
      Instruction::i32_const(I32(0x55555555)),
      Instruction::call(FuncIdx::new(6U)),
    ]),
  )
  gen_valid_engine_state_append(start_body, gen_valid_engine_state_mark(1002))
  gen_valid_engine_state_append(start_body, [
    Instruction::i32_const(I32(2)),
    Instruction::call(FuncIdx::new(0U)),
    Instruction::i32_const(I32(3)),
    Instruction::call(FuncIdx::new(1U)),
    Instruction::call(FuncIdx::new(7U)),
    Instruction::local_set(LocalIdx::new(1U)),
    Instruction::local_set(LocalIdx::new(0U)),
  ])
  gen_valid_engine_state_append(
    start_body,
    gen_valid_engine_state_observe_i32(2, [
      Instruction::local_get(LocalIdx::new(0U)),
    ]),
  )
  gen_valid_engine_state_append(
    start_body,
    gen_valid_engine_state_observe_i64(3, [
      Instruction::local_get(LocalIdx::new(1U)),
    ]),
  )
  gen_valid_engine_state_append(start_body, gen_valid_engine_state_mark(1003))
  gen_valid_engine_state_append(start_body, [
    Instruction::i32_const(I32(4)),
    Instruction::call(FuncIdx::new(0U)),
    Instruction::f32_reinterpret_i32(),
    Instruction::i32_const(I32(5)),
    Instruction::call(FuncIdx::new(1U)),
    Instruction::f64_reinterpret_i64(),
    Instruction::call(FuncIdx::new(8U)),
    Instruction::local_set(LocalIdx::new(3U)),
    Instruction::local_set(LocalIdx::new(2U)),
  ])
  gen_valid_engine_state_append(
    start_body,
    gen_valid_engine_state_observe_i32(4, [
      Instruction::local_get(LocalIdx::new(2U)),
      Instruction::i32_reinterpret_f32(),
    ]),
  )
  gen_valid_engine_state_append(
    start_body,
    gen_valid_engine_state_observe_i64(5, [
      Instruction::local_get(LocalIdx::new(3U)),
      Instruction::i64_reinterpret_f64(),
    ]),
  )
  gen_valid_engine_state_append(
    start_body,
    gen_valid_engine_state_mark(0x7fffffff),
  )
  gen_valid_engine_state_base_module(
    [],
    [
      TypeIdx::new(6U),
      TypeIdx::new(6U),
      TypeIdx::new(9U),
      TypeIdx::new(11U),
      TypeIdx::new(5U),
    ],
    [
      loop_leaf,
      control_leaf,
      multi_leaf,
      float_leaf,
      Func::new(
        Locals::from_types([
          ValType::i32(),
          ValType::i64(),
          ValType::f32(),
          ValType::f64(),
        ]),
        Expr::new(start_body),
      ),
    ],
    [
      Export::new(
        Name::from_string("__fuzz_global_0"),
        ExternIdx::global(GlobalIdx::new(0U)),
      ),
    ],
    [],
    [],
    [
      Global::new(
        GlobalType::new(ValType::i32(), true),
        Expr::new([Instruction::i32_const(I32(0))]),
      ),
    ],
    [],
    [],
  )
}

///|
fn gen_valid_engine_state_calls_module(seed : UInt64) -> Module {
  let leaf = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_const(gen_valid_engine_state_seed_i32(seed, 3UL)),
      Instruction::i32_add(),
    ]),
  )
  let chain = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::call(FuncIdx::new(5U)),
      Instruction::i32_const(I32(3)),
      Instruction::i32_mul(),
    ]),
  )
  let indirect = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_const(I32(0)),
      Instruction::call_indirect(TypeIdx::new(7U), TableIdx::new(0U)),
    ]),
  )
  let multi = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::f32_abs(),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::f64_neg(),
    ]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(1100))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(10, [
      Instruction::i32_const(I32(10)),
      Instruction::call(FuncIdx::new(0U)),
      Instruction::call(FuncIdx::new(6U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(1101))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(11, [
      Instruction::i32_const(I32(11)),
      Instruction::call(FuncIdx::new(0U)),
      Instruction::call(FuncIdx::new(7U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(1102))
  gen_valid_engine_state_append(start, [
    Instruction::i32_const(I32(12)),
    Instruction::call(FuncIdx::new(0U)),
    Instruction::f32_reinterpret_i32(),
    Instruction::i32_const(I32(13)),
    Instruction::call(FuncIdx::new(1U)),
    Instruction::f64_reinterpret_i64(),
    Instruction::call(FuncIdx::new(8U)),
    Instruction::local_set(LocalIdx::new(1U)),
    Instruction::local_set(LocalIdx::new(0U)),
  ])
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(12, [
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_reinterpret_f32(),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i64(13, [
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::i64_reinterpret_f64(),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [
      TypeIdx::new(7U),
      TypeIdx::new(7U),
      TypeIdx::new(7U),
      TypeIdx::new(11U),
      TypeIdx::new(5U),
    ],
    [
      leaf,
      chain,
      indirect,
      multi,
      Func::new(
        Locals::from_types([ValType::f32(), ValType::f64()]),
        Expr::new(start),
      ),
    ],
    [
      Export::new(
        Name::from_string("__fuzz_table_0"),
        ExternIdx::table(TableIdx::new(0U)),
      ),
    ],
    [
      Table::new(
        TableType::new(
          gen_valid_engine_state_funcref(),
          Limits::i32(2U, Some(4U)),
        ),
        None,
      ),
    ],
    [],
    [],
    [
      Elem::new(
        ElemMode::active(
          TableIdx::new(0U),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
        ElemKind::funcs([FuncIdx::new(5U)]),
      ),
    ],
    [],
  )
}

///|
fn gen_valid_engine_state_memory_module(seed : UInt64) -> Module {
  let store_load = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::i32_const(I32(32)),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_store(gen_valid_engine_state_memarg(2U, 0UL)),
      Instruction::i32_const(I32(32)),
      Instruction::i32_load(gen_valid_engine_state_memarg(2U, 0UL)),
    ]),
  )
  let fill = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::i32_const(I32(64)),
      Instruction::i32_const(gen_valid_engine_state_seed_i32(seed, 4UL)),
      Instruction::i32_const(I32(8)),
      Instruction::memory_fill(MemIdx::new(0U)),
      Instruction::i32_const(I32(64)),
      Instruction::i32_load8u(gen_valid_engine_state_memarg(0U, 0UL)),
    ]),
  )
  let grow = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::i32_const(I32(1)),
      Instruction::memory_grow(MemIdx::new(0U)),
    ]),
  )
  let start : Array[Instruction] = []
  for
    item in [
      (1200, 20, FuncIdx::new(5U), true),
      (1201, 21, FuncIdx::new(6U), false),
      (1202, 22, FuncIdx::new(7U), false),
    ] {
    let (event, value_id, target, takes_input) = item
    gen_valid_engine_state_append(start, gen_valid_engine_state_mark(event))
    let value : Array[Instruction] = []
    if takes_input {
      gen_valid_engine_state_append(value, [
        Instruction::i32_const(I32(20)),
        Instruction::call(FuncIdx::new(0U)),
      ])
    }
    value.push(Instruction::call(target))
    gen_valid_engine_state_append(
      start,
      gen_valid_engine_state_observe_i32(value_id, value),
    )
  }
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(7U), TypeIdx::new(8U), TypeIdx::new(8U), TypeIdx::new(5U)],
    [store_load, fill, grow, Func::new(Locals::empty(), Expr::new(start))],
    [
      Export::new(
        Name::from_string("__fuzz_memory_0"),
        ExternIdx::mem(MemIdx::new(0U)),
      ),
    ],
    [],
    [MemType::new(Limits::i32(1U, Some(2U)))],
    [],
    [],
    [
      Data::new(
        DataMode::active(
          MemIdx::new(0U),
          Expr::new([Instruction::i32_const(I32(8))]),
        ),
        b"\x00\x00\x80\x3f\xff\x00\xaa\x55",
      ),
    ],
  )
}

///|
fn gen_valid_engine_state_table_module(seed : UInt64) -> Module {
  let first = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_const(gen_valid_engine_state_seed_i32(seed, 5UL)),
      Instruction::i32_add(),
    ]),
  )
  let second = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_const(I32(-1)),
      Instruction::i32_xor(),
    ]),
  )
  let driver = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::i32_const(I32(2)),
      Instruction::ref_func(FuncIdx::new(6U)),
      Instruction::table_set(TableIdx::new(0U)),
      Instruction::ref_null(HeapType::abs(AbsHeapType::func())),
      Instruction::i32_const(I32(1)),
      Instruction::table_grow(TableIdx::new(0U)),
      Instruction::drop(),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_const(I32(0)),
      Instruction::call_indirect(TypeIdx::new(7U), TableIdx::new(0U)),
    ]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(1300))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(30, [
      Instruction::i32_const(I32(30)),
      Instruction::call(FuncIdx::new(0U)),
      Instruction::call(FuncIdx::new(7U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(1301))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(31, [
      Instruction::i32_const(I32(31)),
      Instruction::call(FuncIdx::new(0U)),
      Instruction::call(FuncIdx::new(6U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(7U), TypeIdx::new(7U), TypeIdx::new(7U), TypeIdx::new(5U)],
    [first, second, driver, Func::new(Locals::empty(), Expr::new(start))],
    [
      Export::new(
        Name::from_string("__fuzz_table_0"),
        ExternIdx::table(TableIdx::new(0U)),
      ),
    ],
    [
      Table::new(
        TableType::new(
          gen_valid_engine_state_funcref(),
          Limits::i32(4U, Some(8U)),
        ),
        None,
      ),
    ],
    [],
    [],
    [
      Elem::new(
        ElemMode::active(
          TableIdx::new(0U),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
        ElemKind::funcs([FuncIdx::new(5U), FuncIdx::new(6U)]),
      ),
    ],
    [],
  )
}

///|
fn gen_valid_engine_state_simd_const(seed : UInt64) -> Instruction {
  let lane = (seed % 251UL + 1UL).to_byte()
  Instruction::v128_const(
    lane, b'\x00', b'\xff', b'\x55', b'\xaa', b'\x80', b'\x7f', b'\x01', b'\xfe',
    b'\x10', b'\x20', b'\x40', b'\x08', b'\x04', b'\x02', b'\x01',
  )
}

///|
fn gen_valid_engine_state_simd_module(seed : UInt64) -> Module {
  let first = Func::new(
    Locals::empty(),
    Expr::new([
      gen_valid_engine_state_simd_const(seed),
      Instruction::i32_const(gen_valid_engine_state_seed_i32(seed, 6UL)),
      Instruction::i32x4_splat(),
      Instruction::v128_xor(),
    ]),
  )
  let second = Func::new(
    Locals::empty(),
    Expr::new([Instruction::call(FuncIdx::new(5U)), Instruction::v128_not()]),
  )
  let scalar = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::call(FuncIdx::new(5U)),
      Instruction::v128_any_true(),
    ]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(1400))
  gen_valid_engine_state_append(start, [
    Instruction::i32_const(I32(128)),
    Instruction::call(FuncIdx::new(5U)),
    Instruction::v128_store(gen_valid_engine_state_memarg(4U, 0UL)),
  ])
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(1401))
  gen_valid_engine_state_append(start, [
    Instruction::i32_const(I32(160)),
    Instruction::call(FuncIdx::new(6U)),
    Instruction::v128_store(gen_valid_engine_state_memarg(4U, 0UL)),
  ])
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(40, [Instruction::call(FuncIdx::new(7U))]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(10U), TypeIdx::new(10U), TypeIdx::new(8U), TypeIdx::new(5U)],
    [first, second, scalar, Func::new(Locals::empty(), Expr::new(start))],
    [
      Export::new(
        Name::from_string("__fuzz_memory_0"),
        ExternIdx::mem(MemIdx::new(0U)),
      ),
    ],
    [],
    [MemType::new(Limits::i32(1U, Some(1U)))],
    [],
    [],
    [],
  )
}

///|
fn gen_valid_engine_state_resource_imports() -> Array[Import] {
  let module_name = Name::from_string("__fuzz")
  [
    Import::new(
      module_name,
      Name::from_string("state_global_i32"),
      ExternType::global(GlobalType::new(ValType::i32(), true)),
    ),
    Import::new(
      module_name,
      Name::from_string("state_memory"),
      ExternType::mem(MemType::new(Limits::i32(1U, Some(2U)))),
    ),
    Import::new(
      module_name,
      Name::from_string("state_table"),
      ExternType::table(
        TableType::new(
          gen_valid_engine_state_funcref(),
          Limits::i32(4U, Some(8U)),
        ),
      ),
    ),
  ]
}

///|
fn gen_valid_engine_state_import_exports() -> Array[Export] {
  [
    Export::new(
      Name::from_string("__fuzz_global_0"),
      ExternIdx::global(GlobalIdx::new(0U)),
    ),
    Export::new(
      Name::from_string("__fuzz_memory_0"),
      ExternIdx::mem(MemIdx::new(0U)),
    ),
    Export::new(
      Name::from_string("__fuzz_table_0"),
      ExternIdx::table(TableIdx::new(0U)),
    ),
  ]
}

///|
fn gen_valid_engine_state_import_prefix_leaf() -> Func {
  Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::global_set(GlobalIdx::new(0U)),
      Instruction::i32_const(I32(0)),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_store(gen_valid_engine_state_memarg(2U, 0UL)),
      Instruction::i32_const(I32(0)),
      Instruction::ref_func(FuncIdx::new(5U)),
      Instruction::table_set(TableIdx::new(0U)),
      Instruction::local_get(LocalIdx::new(0U)),
    ]),
  )
}

///|
fn gen_valid_engine_state_imports_module() -> Module {
  let prefix = gen_valid_engine_state_import_prefix_leaf()
  let read_global = Func::new(
    Locals::empty(),
    Expr::new([Instruction::global_get(GlobalIdx::new(0U))]),
  )
  let read_memory = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::i32_const(I32(0)),
      Instruction::i32_load(gen_valid_engine_state_memarg(2U, 0UL)),
    ]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(1500))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(50, [
      Instruction::i32_const(I32(50)),
      Instruction::call(FuncIdx::new(0U)),
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(1501))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(51, [Instruction::call(FuncIdx::new(6U))]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(52, [Instruction::call(FuncIdx::new(7U))]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    gen_valid_engine_state_resource_imports(),
    [TypeIdx::new(7U), TypeIdx::new(8U), TypeIdx::new(8U), TypeIdx::new(5U)],
    [
      prefix,
      read_global,
      read_memory,
      Func::new(Locals::empty(), Expr::new(start)),
    ],
    gen_valid_engine_state_import_exports(),
    [],
    [],
    [],
    [],
    [],
  )
}

///|
fn gen_valid_engine_state_initialization_module(seed : UInt64) -> Module {
  let load = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::i32_const(I32(8)),
      Instruction::i32_load(gen_valid_engine_state_memarg(2U, 0UL)),
    ]),
  )
  let global_mix = Func::new(
    Locals::from_types([ValType::i32()]),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::global_get(GlobalIdx::new(0U)),
      Instruction::i32_add(),
      Instruction::local_tee(LocalIdx::new(1U)),
      Instruction::global_set(GlobalIdx::new(0U)),
      Instruction::local_get(LocalIdx::new(1U)),
    ]),
  )
  let indirect = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::i32_const(I32(0)),
      Instruction::call_indirect(TypeIdx::new(8U), TableIdx::new(0U)),
    ]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(1600))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(60, [Instruction::call(FuncIdx::new(5U))]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(1601))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(61, [
      Instruction::i32_const(I32(61)),
      Instruction::call(FuncIdx::new(0U)),
      Instruction::call(FuncIdx::new(6U)),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(62, [Instruction::call(FuncIdx::new(7U))]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  let exports = [
    Export::new(
      Name::from_string("__fuzz_memory_0"),
      ExternIdx::mem(MemIdx::new(0U)),
    ),
    Export::new(
      Name::from_string("__fuzz_memory_alias_0"),
      ExternIdx::mem(MemIdx::new(0U)),
    ),
    Export::new(
      Name::from_string("__fuzz_table_0"),
      ExternIdx::table(TableIdx::new(0U)),
    ),
    Export::new(
      Name::from_string("__fuzz_table_alias_0"),
      ExternIdx::table(TableIdx::new(0U)),
    ),
    Export::new(
      Name::from_string("__fuzz_global_0"),
      ExternIdx::global(GlobalIdx::new(0U)),
    ),
    Export::new(
      Name::from_string("__fuzz_global_alias_0"),
      ExternIdx::global(GlobalIdx::new(0U)),
    ),
  ]
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(8U), TypeIdx::new(7U), TypeIdx::new(8U), TypeIdx::new(5U)],
    [load, global_mix, indirect, Func::new(Locals::empty(), Expr::new(start))],
    exports,
    [
      Table::new(
        TableType::new(
          gen_valid_engine_state_funcref(),
          Limits::i32(2U, Some(4U)),
        ),
        None,
      ),
    ],
    [MemType::new(Limits::i32(1U, Some(1U)))],
    [
      Global::new(
        GlobalType::new(ValType::i32(), true),
        Expr::new([
          Instruction::i32_const(gen_valid_engine_state_seed_i32(seed, 7UL)),
        ]),
      ),
    ],
    [
      Elem::new(
        ElemMode::active(
          TableIdx::new(0U),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
        ElemKind::funcs([FuncIdx::new(5U)]),
      ),
    ],
    [
      Data::new(
        DataMode::active(
          MemIdx::new(0U),
          Expr::new([Instruction::i32_const(I32(8))]),
        ),
        b"\x2a\x00\x00\x00\x00\x00\x00\x80",
      ),
    ],
  )
}

///|
pub fn gen_valid_engine_state_trap_family(seed : UInt64) -> String {
  match (seed % 6UL).to_int() {
    0 => "unreachable"
    1 => "integer-division-by-zero"
    2 => "signed-division-overflow"
    3 => "invalid-float-to-integer-conversion"
    4 => "out-of-bounds-memory"
    _ => "out-of-bounds-table"
  }
}

///|
fn gen_valid_engine_state_trap_instructions(
  seed : UInt64,
) -> Array[Instruction] {
  match (seed % 6UL).to_int() {
    0 => [Instruction::unreachable_()]
    1 =>
      [
        Instruction::i32_const(I32(1)),
        Instruction::i32_const(I32(0)),
        Instruction::i32_div_s(),
        Instruction::drop(),
      ]
    2 =>
      [
        Instruction::i32_const(I32(-2147483648)),
        Instruction::i32_const(I32(-1)),
        Instruction::i32_div_s(),
        Instruction::drop(),
      ]
    3 =>
      [
        Instruction::i32_const(I32(0x7fc00000)),
        Instruction::f32_reinterpret_i32(),
        Instruction::i32_trunc_f32s(),
        Instruction::drop(),
      ]
    4 =>
      [
        Instruction::i32_const(I32(65536)),
        Instruction::i32_load(gen_valid_engine_state_memarg(2U, 0UL)),
        Instruction::drop(),
      ]
    _ =>
      [
        Instruction::i32_const(I32(99)),
        Instruction::table_get(TableIdx::new(0U)),
        Instruction::drop(),
      ]
  }
}

///|
fn gen_valid_engine_state_trap_module(seed : UInt64) -> Module {
  let prefix = gen_valid_engine_state_import_prefix_leaf()
  let read_global = Func::new(
    Locals::empty(),
    Expr::new([Instruction::global_get(GlobalIdx::new(0U))]),
  )
  let read_memory = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::i32_const(I32(0)),
      Instruction::i32_load(gen_valid_engine_state_memarg(2U, 0UL)),
    ]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(1700))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(70, [
      Instruction::i32_const(I32(70)),
      Instruction::call(FuncIdx::new(0U)),
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(71, [Instruction::call(FuncIdx::new(6U))]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(72, [Instruction::call(FuncIdx::new(7U))]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x70000000))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_trap_instructions(seed),
  )
  gen_valid_engine_state_base_module(
    gen_valid_engine_state_resource_imports(),
    [TypeIdx::new(7U), TypeIdx::new(8U), TypeIdx::new(8U), TypeIdx::new(5U)],
    [
      prefix,
      read_global,
      read_memory,
      Func::new(Locals::empty(), Expr::new(start)),
    ],
    gen_valid_engine_state_import_exports(),
    [],
    [],
    [],
    [],
    [],
  )
}

///|
fn gen_valid_engine_state_mixed_module(seed : UInt64) -> Module {
  let scalar = Func::new(
    Locals::from_types([ValType::i32()]),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::i32_xor(),
      Instruction::local_tee(LocalIdx::new(2U)),
      Instruction::global_set(GlobalIdx::new(0U)),
      Instruction::local_get(LocalIdx::new(2U)),
    ]),
  )
  let memory = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::i32_const(I32(48)),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_store(gen_valid_engine_state_memarg(2U, 0UL)),
      Instruction::i32_const(I32(48)),
      Instruction::i32_load(gen_valid_engine_state_memarg(2U, 0UL)),
    ]),
  )
  let driver = Func::new(
    Locals::from_types([ValType::i32()]),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_const(gen_valid_engine_state_seed_i32(seed, 8UL)),
      Instruction::call(FuncIdx::new(5U)),
      Instruction::call(FuncIdx::new(6U)),
      Instruction::local_set(LocalIdx::new(1U)),
      Instruction::i32_const(I32(128)),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::i32x4_splat(),
      Instruction::v128_not(),
      Instruction::v128_store(gen_valid_engine_state_memarg(4U, 0UL)),
      Instruction::i32_const(I32(1)),
      Instruction::ref_func(FuncIdx::new(6U)),
      Instruction::table_set(TableIdx::new(0U)),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::i32_const(I32(0)),
      Instruction::call_indirect(TypeIdx::new(7U), TableIdx::new(0U)),
    ]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(1800))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(80, [
      Instruction::i32_const(I32(80)),
      Instruction::call(FuncIdx::new(0U)),
      Instruction::i32_const(I32(-1)),
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(81, [
      Instruction::i32_const(I32(81)),
      Instruction::call(FuncIdx::new(0U)),
      Instruction::call(FuncIdx::new(6U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(1801))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(82, [
      Instruction::i32_const(I32(82)),
      Instruction::call(FuncIdx::new(0U)),
      Instruction::call(FuncIdx::new(7U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(6U), TypeIdx::new(7U), TypeIdx::new(7U), TypeIdx::new(5U)],
    [scalar, memory, driver, Func::new(Locals::empty(), Expr::new(start))],
    [
      Export::new(
        Name::from_string("__fuzz_memory_0"),
        ExternIdx::mem(MemIdx::new(0U)),
      ),
      Export::new(
        Name::from_string("__fuzz_table_0"),
        ExternIdx::table(TableIdx::new(0U)),
      ),
      Export::new(
        Name::from_string("__fuzz_global_0"),
        ExternIdx::global(GlobalIdx::new(0U)),
      ),
    ],
    [
      Table::new(
        TableType::new(
          gen_valid_engine_state_funcref(),
          Limits::i32(2U, Some(4U)),
        ),
        None,
      ),
    ],
    [MemType::new(Limits::i32(1U, Some(1U)))],
    [
      Global::new(
        GlobalType::new(ValType::i32(), true),
        Expr::new([Instruction::i32_const(I32(0))]),
      ),
    ],
    [
      Elem::new(
        ElemMode::active(
          TableIdx::new(0U),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
        ElemKind::funcs([FuncIdx::new(6U)]),
      ),
    ],
    [
      Data::new(
        DataMode::active(
          MemIdx::new(0U),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
        b"\x00\x01\x02\x03\x04\x05\x06\x07",
      ),
    ],
  )
}

///|
pub fn gen_valid_engine_state_static_instruction_count(mod_ : Module) -> Int {
  gen_valid_module_instruction_count(mod_)
}

///|
fn gen_valid_engine_state_profile_module(ctx : GenValidContext) -> Module {
  match gen_valid_engine_state_profile_kind(ctx.config) {
    EngineStateScalarControlProfile =>
      gen_valid_engine_state_scalar_control_module(ctx.root_seed)
    EngineStateCallsProfile =>
      gen_valid_engine_state_calls_module(ctx.root_seed)
    EngineStateMemoryProfile =>
      gen_valid_engine_state_memory_module(ctx.root_seed)
    EngineStateTableProfile =>
      gen_valid_engine_state_table_module(ctx.root_seed)
    EngineStateSimdProfile => gen_valid_engine_state_simd_module(ctx.root_seed)
    EngineStateImportsProfile => gen_valid_engine_state_imports_module()
    EngineStateInitializationProfile =>
      gen_valid_engine_state_initialization_module(ctx.root_seed)
    EngineStateTrapProfile => gen_valid_engine_state_trap_module(ctx.root_seed)
    EngineStateMixedProfile =>
      gen_valid_engine_state_mixed_module(ctx.root_seed)
    EngineStateTopologyProfile =>
      gen_valid_engine_state_topology_module(ctx.root_seed)
    EngineStateEffectsProfile =>
      gen_valid_engine_state_effects_module(ctx.root_seed)
    EngineStateResourcesProfile =>
      gen_valid_engine_state_resources_module(ctx.root_seed)
    EngineStateBoundariesProfile =>
      gen_valid_engine_state_boundaries_module(ctx.root_seed)
    EngineStateOptimizerShapesProfile =>
      gen_valid_engine_state_optimizer_shapes_module(ctx.root_seed)
    EngineStateEquivalentFamiliesProfile =>
      gen_valid_engine_state_equivalent_families_module(ctx.root_seed)
    EngineStatePassiveSegmentsProfile =>
      gen_valid_engine_state_passive_segments_module(ctx.root_seed)
    EngineStateInstantiationBoundariesProfile =>
      gen_valid_engine_state_instantiation_boundaries_module(ctx.root_seed)
    EngineStateMultiResourceProfile =>
      gen_valid_engine_state_multi_resource_module(ctx.root_seed)
    EngineStateStackPressureProfile =>
      gen_valid_engine_state_stack_pressure_module(ctx.root_seed)
    EngineStateMemoryAliasingProfile =>
      gen_valid_engine_state_memory_aliasing_module(ctx.root_seed)
    EngineStateIndirectTrapsProfile =>
      gen_valid_engine_state_indirect_traps_module(ctx.root_seed)
    EngineStateTrapPlacementProfile =>
      gen_valid_engine_state_trap_placement_module(ctx.root_seed)
    EngineStateCrossInstanceProfile =>
      gen_valid_engine_state_cross_instance_module(ctx.root_seed)
    EngineStateResourceExhaustionProfile =>
      gen_valid_engine_state_resource_exhaustion_module(ctx.root_seed)
    EngineStateDecoderTopologyProfile =>
      gen_valid_engine_state_decoder_topology_module(ctx.root_seed)
    EngineStateTailCallsProfile =>
      gen_valid_engine_state_tail_calls_module(ctx.root_seed)
    EngineStateTypedFunctionReferencesProfile =>
      gen_valid_engine_state_typed_function_references_module(ctx.root_seed)
    EngineStateMemory64Profile =>
      gen_valid_engine_state_memory64_module(ctx.root_seed)
    EngineStateExceptionsProfile =>
      gen_valid_engine_state_exceptions_module(ctx.root_seed)
    EngineStateGcProfile => gen_valid_engine_state_gc_module(ctx.root_seed)
    EngineStateLinkGraphProfile =>
      gen_valid_engine_state_link_graph_consumer_module(ctx.root_seed)
    EngineStateGcGraphProfile =>
      gen_valid_engine_state_gc_graph_module(ctx.root_seed)
    EngineStateInitializationGraphProfile =>
      gen_valid_engine_state_initialization_graph_module(ctx.root_seed)
    EngineStateExceptionUnwindProfile =>
      gen_valid_engine_state_exception_unwind_module(ctx.root_seed)
    EngineStateTypeCallMatrixProfile =>
      gen_valid_engine_state_type_call_matrix_module(ctx.root_seed)
    EngineStateLebIndexBoundariesProfile =>
      gen_valid_engine_state_leb_index_boundaries_module(ctx.root_seed)
    EngineStateTableReferenceMatrixProfile =>
      gen_valid_engine_state_table_reference_matrix_module(ctx.root_seed)
    EngineStateMemory64MultiMemoryProfile =>
      gen_valid_engine_state_memory64_multi_memory_module(ctx.root_seed)
    EngineStateTrapCommitMatrixProfile =>
      gen_valid_engine_state_trap_commit_matrix_module(ctx.root_seed)
    EngineStateMetamorphicTwinsProfile =>
      gen_valid_engine_state_metamorphic_module(ctx.root_seed, false)
    EngineStateCompilerBoundariesProfile =>
      gen_valid_engine_state_compiler_boundaries_module(ctx.root_seed)
    EngineStateNanProfile => gen_valid_engine_state_nan_module(ctx.root_seed)
    EngineStateInvalidModuleProfile =>
      gen_valid_engine_state_invalid_base_module(ctx.root_seed)
    EngineStateRecursiveMultivalueProfile =>
      gen_valid_engine_state_recursive_multivalue_module(ctx.root_seed)
    EngineStateSubtypeCastGraphProfile =>
      gen_valid_engine_state_subtype_cast_graph_module(ctx.root_seed)
    _ => gen_valid_engine_state_scalar_control_module(ctx.root_seed)
  }
}
