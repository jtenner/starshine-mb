///|
fn gen_valid_engine_state_indexed_memarg(
  align : UInt,
  memory : UInt,
  offset : UInt64,
) -> MemArg {
  MemArg::new(U32(align), Some(MemIdx::new(memory)), U64(offset))
}

///|
fn gen_valid_engine_state_extended_types(extra : Array[RecType]) -> TypeSec {
  let TypeSec(types) = gen_valid_engine_state_type_sec()
  for type_ in extra {
    types.push(type_)
  }
  TypeSec::new(types)
}

///|
fn gen_valid_engine_state_passive_segments_module(seed : UInt64) -> Module {
  let leaf = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_const(gen_valid_engine_state_seed_i32(seed, 40UL)),
      Instruction::i32_xor(),
    ]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(2500))
  gen_valid_engine_state_append(start, [
    Instruction::i32_const(I32(32)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(16)),
    Instruction::memory_init(DataIdx::new(0U), MemIdx::new(0U)),
    Instruction::data_drop(DataIdx::new(0U)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(1)),
    Instruction::table_init(ElemIdx::new(0U), TableIdx::new(0U)),
    Instruction::elem_drop(ElemIdx::new(0U)),
  ])
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(150, [
      Instruction::i32_const(I32(32)),
      Instruction::i32_load(gen_valid_engine_state_memarg(2U, 0UL)),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(151, [
      Instruction::i32_const(I32(151)),
      Instruction::i32_const(I32(0)),
      Instruction::call_indirect(TypeIdx::new(7U), TableIdx::new(0U)),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(152, [
      Instruction::i32_const(I32(152)),
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(7U), TypeIdx::new(5U)],
    [leaf, Func::new(Locals::empty(), Expr::new(start))],
    [
      Export::new(
        Name::from_string("__fuzz_memory_0"),
        ExternIdx::mem(MemIdx::new(0U)),
      ),
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
    [MemType::new(Limits::i32(1U, Some(1U)))],
    [],
    [Elem::new(ElemMode::passive(), ElemKind::funcs([FuncIdx::new(5U)]))],
    [
      Data::new(
        DataMode::passive(),
        Bytes::from_array([
          (seed & 0xffUL).to_byte(),
          ((seed >> 8) & 0xffUL).to_byte(),
          ((seed >> 16) & 0xffUL).to_byte(),
          ((seed >> 24) & 0xffUL).to_byte(),
          4,
          5,
          6,
          7,
          8,
          9,
          10,
          11,
          12,
          13,
          14,
          15,
        ]),
      ),
    ],
  ).with_data_cnt_sec(DataCntSec::new(U32(1U)))
}

///|
fn gen_valid_engine_state_multi_resource_module(seed : UInt64) -> Module {
  let left = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_const(I32(17)),
      Instruction::i32_add(),
    ]),
  )
  let right = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_const(I32(31)),
      Instruction::i32_xor(),
    ]),
  )
  let workload = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::i32_const(I32(64)),
      Instruction::i32_const(I32(0)),
      Instruction::i32_const(I32(32)),
      Instruction::memory_copy(MemIdx::new(1U), MemIdx::new(0U)),
      Instruction::i32_const(I32(1)),
      Instruction::memory_grow(MemIdx::new(1U)),
      Instruction::drop(),
      Instruction::i32_const(I32(0)),
      Instruction::i32_const(I32(0)),
      Instruction::i32_const(I32(2)),
      Instruction::table_copy(TableIdx::new(1U), TableIdx::new(0U)),
      Instruction::ref_null(HeapType::abs(AbsHeapType::func())),
      Instruction::i32_const(I32(1)),
      Instruction::table_grow(TableIdx::new(1U)),
      Instruction::drop(),
      Instruction::i32_const(I32(64)),
      Instruction::i32_load(gen_valid_engine_state_indexed_memarg(2U, 1U, 0UL)),
      Instruction::table_size(TableIdx::new(1U)),
      Instruction::i32_xor(),
    ]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(2600))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(160, [
      Instruction::call(FuncIdx::new(7U)),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(161, [
      Instruction::i32_const(gen_valid_engine_state_seed_i32(seed, 41UL)),
      Instruction::i32_const(I32(0)),
      Instruction::call_indirect(TypeIdx::new(7U), TableIdx::new(1U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(7U), TypeIdx::new(7U), TypeIdx::new(8U), TypeIdx::new(5U)],
    [left, right, workload, Func::new(Locals::empty(), Expr::new(start))],
    [
      Export::new(
        Name::from_string("__fuzz_memory_0"),
        ExternIdx::mem(MemIdx::new(0U)),
      ),
      Export::new(
        Name::from_string("__fuzz_memory_1"),
        ExternIdx::mem(MemIdx::new(1U)),
      ),
      Export::new(
        Name::from_string("__fuzz_table_0"),
        ExternIdx::table(TableIdx::new(0U)),
      ),
      Export::new(
        Name::from_string("__fuzz_table_1"),
        ExternIdx::table(TableIdx::new(1U)),
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
      Table::new(
        TableType::new(
          gen_valid_engine_state_funcref(),
          Limits::i32(2U, Some(4U)),
        ),
        None,
      ),
    ],
    [
      MemType::new(Limits::i32(1U, Some(2U))),
      MemType::new(Limits::i32(1U, Some(2U))),
    ],
    [],
    [
      Elem::new(
        ElemMode::active(
          TableIdx::new(0U),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
        ElemKind::funcs([FuncIdx::new(5U), FuncIdx::new(6U)]),
      ),
      Elem::new(
        ElemMode::active(
          TableIdx::new(1U),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
        ElemKind::funcs([FuncIdx::new(6U), FuncIdx::new(5U)]),
      ),
    ],
    [
      Data::new(
        DataMode::active(
          MemIdx::new(0U),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
        b"\x10\x20\x30\x40multi-resource-source",
      ),
      Data::new(
        DataMode::active(
          MemIdx::new(1U),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
        b"\xff\xee\xdd\xccindependent-destination",
      ),
    ],
  )
}

///|
fn gen_valid_engine_state_stack_pressure_module(seed : UInt64) -> Module {
  let wide_body : Array[Instruction] = []
  for i in 0..<8 {
    wide_body.push(
      Instruction::local_get(LocalIdx::new(i.reinterpret_as_uint())),
    )
    wide_body.push(
      Instruction::local_get(LocalIdx::new((i + 8).reinterpret_as_uint())),
    )
    wide_body.push(Instruction::i32_add())
  }
  let reduce_body : Array[Instruction] = []
  for i in 0..<8 {
    reduce_body.push(
      Instruction::local_get(LocalIdx::new(i.reinterpret_as_uint())),
    )
  }
  for _ in 0..<7 {
    reduce_body.push(Instruction::i32_add())
  }
  let deep_body : Array[Instruction] = []
  for i in 0..<64 {
    deep_body.push(
      Instruction::i32_const(
        gen_valid_engine_state_seed_i32(seed, (50 + i).to_uint64()),
      ),
    )
  }
  for _ in 0..<63 {
    deep_body.push(Instruction::i32_xor())
  }
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(2700))
  let wide_call : Array[Instruction] = []
  for i in 0..<16 {
    wide_call.push(Instruction::i32_const(I32(i * 13 + 1)))
  }
  wide_call.push(Instruction::call(FuncIdx::new(5U)))
  wide_call.push(Instruction::call(FuncIdx::new(6U)))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(170, wide_call),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(171, [
      Instruction::call(FuncIdx::new(7U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  let wide_params = Array::make(16, ValType::i32())
  let wide_results = Array::make(8, ValType::i32())
  let reduce_params = Array::make(8, ValType::i32())
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(12U), TypeIdx::new(13U), TypeIdx::new(8U), TypeIdx::new(5U)],
    [
      Func::new(Locals::empty(), Expr::new(wide_body)),
      Func::new(Locals::empty(), Expr::new(reduce_body)),
      Func::new(Locals::empty(), Expr::new(deep_body)),
      Func::new(Locals::empty(), Expr::new(start)),
    ],
    [],
    [],
    [],
    [],
    [],
    [],
  ).with_type_sec(
    gen_valid_engine_state_extended_types([
      gen_valid_engine_state_func_type(wide_params, wide_results),
      gen_valid_engine_state_func_type(reduce_params, [ValType::i32()]),
    ]),
  )
}

///|
fn gen_valid_engine_state_memory_aliasing_module(seed : UInt64) -> Module {
  let address = 65 + ((seed >> 5) % 7UL).to_int()
  let alias_body : Array[Instruction] = [
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32((seed & 0xffUL).to_int())),
    Instruction::i32_const(I32(96)),
    Instruction::memory_fill(MemIdx::new(0U)),
  ]
  if (seed & 1UL) == 0UL {
    gen_valid_engine_state_append(alias_body, [
      Instruction::i32_const(I32(8)),
      Instruction::i32_const(I32(0)),
      Instruction::i32_const(I32(64)),
      Instruction::memory_copy(MemIdx::new(0U), MemIdx::new(0U)),
    ])
  } else {
    gen_valid_engine_state_append(alias_body, [
      Instruction::i32_const(I32(0)),
      Instruction::i32_const(I32(8)),
      Instruction::i32_const(I32(64)),
      Instruction::memory_copy(MemIdx::new(0U), MemIdx::new(0U)),
    ])
  }
  gen_valid_engine_state_append(alias_body, [
    Instruction::i32_const(I32(address)),
    Instruction::i32_const(I32(-1)),
    Instruction::i32_store8(gen_valid_engine_state_memarg(0U, 0UL)),
    Instruction::i32_const(I32(address + 1)),
    Instruction::i32_const(I32(0x12345678)),
    Instruction::i32_store(gen_valid_engine_state_memarg(0U, 0UL)),
    Instruction::i32_const(I32(address)),
    Instruction::i32_load8s(gen_valid_engine_state_memarg(0U, 0UL)),
    Instruction::i32_const(I32(address + 1)),
    Instruction::i32_load16u(gen_valid_engine_state_memarg(0U, 0UL)),
    Instruction::i32_xor(),
  ])
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(2800))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(180, [
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(8U), TypeIdx::new(5U)],
    [
      Func::new(Locals::empty(), Expr::new(alias_body)),
      Func::new(Locals::empty(), Expr::new(start)),
    ],
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
fn gen_valid_engine_state_resource_exhaustion_module(seed : UInt64) -> Module {
  let memory = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::i32_const(I32(1 + (seed % 3UL).to_int())),
      Instruction::memory_grow(MemIdx::new(0U)),
    ]),
  )
  let table = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::ref_null(HeapType::abs(AbsHeapType::func())),
      Instruction::i32_const(I32(1 + ((seed >> 2) % 3UL).to_int())),
      Instruction::table_grow(TableIdx::new(0U)),
    ]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(2900))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(190, [
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(191, [
      Instruction::call(FuncIdx::new(6U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(8U), TypeIdx::new(8U), TypeIdx::new(5U)],
    [memory, table, Func::new(Locals::empty(), Expr::new(start))],
    [
      Export::new(
        Name::from_string("__fuzz_memory_0"),
        ExternIdx::mem(MemIdx::new(0U)),
      ),
      Export::new(
        Name::from_string("__fuzz_table_0"),
        ExternIdx::table(TableIdx::new(0U)),
      ),
    ],
    [
      Table::new(
        TableType::new(
          gen_valid_engine_state_funcref(),
          Limits::i32(4U, Some(4U)),
        ),
        None,
      ),
    ],
    [MemType::new(Limits::i32(1U, Some(1U)))],
    [],
    [],
    [],
  )
}

///|
fn gen_valid_engine_state_decoder_payload(length : Int, seed : UInt64) -> Bytes {
  let bytes : Array[Byte] = []
  for i in 0..<length {
    bytes.push(((seed + i.to_uint64() * 37UL) & 0xffUL).to_byte())
  }
  Bytes::from_array(bytes)
}

///|
fn gen_valid_engine_state_decoder_topology_module(seed : UInt64) -> Module {
  let functions : Array[Func] = []
  let types : Array[TypeIdx] = []
  for i in 0..<11 {
    let body : Array[Instruction] = [
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_const(I32(i + 1)),
    ]
    if (i + (seed % 3UL).to_int()) % 3 == 0 {
      body.push(Instruction::i32_xor())
    } else if (i + (seed % 3UL).to_int()) % 3 == 1 {
      body.push(Instruction::i32_add())
    } else {
      body.push(Instruction::i32_sub())
    }
    functions.push(Func::new(Locals::empty(), Expr::new(body)))
    types.push(TypeIdx::new(7U))
  }
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(3000))
  for i in 0..<11 {
    gen_valid_engine_state_append(
      start,
      gen_valid_engine_state_observe_i32(200 + i, [
        Instruction::i32_const(I32(i * 101)),
        Instruction::call(FuncIdx::new((5 + i).reinterpret_as_uint())),
      ]),
    )
  }
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  functions.push(Func::new(Locals::empty(), Expr::new(start)))
  types.push(TypeIdx::new(5U))
  gen_valid_engine_state_base_module([], types, functions, [], [], [], [], [], []).with_custom_secs([
      @lib.CustomSec::new(
        Name::from_string("a"),
        gen_valid_engine_state_decoder_payload(0, seed),
      ),
      @lib.CustomSec::new(
        Name::from_string("starshine.decoder.boundary.127"),
        gen_valid_engine_state_decoder_payload(127, seed >> 1),
      ),
      @lib.CustomSec::new(
        Name::from_string("starshine.decoder.boundary.128"),
        gen_valid_engine_state_decoder_payload(128, seed >> 2),
      ),
      @lib.CustomSec::new(
        Name::from_string("starshine.decoder.long-name.{seed}"),
        gen_valid_engine_state_decoder_payload(255, seed >> 3),
      ),
    ],
  )
}

///|
fn gen_valid_engine_state_tail_calls_module(seed : UInt64) -> Module {
  let leaf = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_const(gen_valid_engine_state_seed_i32(seed, 120UL)),
      Instruction::i32_add(),
    ]),
  )
  let tail = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::return_call(FuncIdx::new(5U)),
    ]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(3100))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(220, [
      Instruction::i32_const(I32(220)),
      Instruction::call(FuncIdx::new(0U)),
      Instruction::call(FuncIdx::new(6U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(7U), TypeIdx::new(7U), TypeIdx::new(5U)],
    [leaf, tail, Func::new(Locals::empty(), Expr::new(start))],
    [],
    [],
    [],
    [],
    [],
    [],
  )
}

///|
fn gen_valid_engine_state_typed_function_references_module(
  seed : UInt64,
) -> Module {
  let leaf = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_const(gen_valid_engine_state_seed_i32(seed, 121UL)),
      Instruction::i32_xor(),
    ]),
  )
  let caller = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::ref_func(FuncIdx::new(5U)),
      Instruction::call_ref(TypeIdx::new(7U)),
    ]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(3200))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(230, [
      Instruction::i32_const(I32(230)),
      Instruction::call(FuncIdx::new(0U)),
      Instruction::call(FuncIdx::new(6U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(7U), TypeIdx::new(7U), TypeIdx::new(5U)],
    [leaf, caller, Func::new(Locals::empty(), Expr::new(start))],
    [],
    [],
    [],
    [],
    [],
    [],
  )
}

///|
fn gen_valid_engine_state_memory64_module(seed : UInt64) -> Module {
  let address = 96L + ((seed >> 4) % 16UL).to_int64()
  let value = gen_valid_engine_state_seed_i64(seed, 122UL)
  let roundtrip = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::i64_const(I64(address)),
      Instruction::i64_const(value),
      Instruction::i64_store(gen_valid_engine_state_memarg(3U, 0UL)),
      Instruction::i64_const(I64(address)),
      Instruction::i64_load(gen_valid_engine_state_memarg(3U, 0UL)),
    ]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(3300))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i64(240, [
      Instruction::i32_const(I32(0)),
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i64(241, [
      Instruction::memory_size(MemIdx::new(0U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(1U), TypeIdx::new(5U)],
    [roundtrip, Func::new(Locals::empty(), Expr::new(start))],
    [
      Export::new(
        Name::from_string("__fuzz_memory_0"),
        ExternIdx::mem(MemIdx::new(0U)),
      ),
    ],
    [],
    [MemType::new(Limits::i64(1UL, Some(2UL)))],
    [],
    [],
    [],
  )
}

///|
pub fn gen_valid_engine_state_indirect_trap_family(seed : UInt64) -> String {
  match (seed % 3UL).to_int() {
    0 => "null-function-reference"
    1 => "indirect-call-type-mismatch"
    _ => "out-of-bounds-table"
  }
}

///|
pub fn gen_valid_engine_state_outcome(profile : GenValidProfile) -> String {
  match profile {
    EngineStateTrapProfile
    | EngineStateIndirectTrapsProfile
    | EngineStateTrapPlacementProfile
    | EngineStateTrapCommitMatrixProfile => "runtime-trap"
    EngineStateInstantiationBoundariesProfile => "instantiation-failure"
    EngineStateInvalidModuleProfile => "compile-failure"
    _ => "complete"
  }
}

///|
pub fn gen_valid_engine_state_failure_family(
  profile : GenValidProfile,
  seed : UInt64,
) -> String {
  match profile {
    EngineStateTrapProfile | EngineStateTrapPlacementProfile =>
      gen_valid_engine_state_trap_family(seed)
    EngineStateIndirectTrapsProfile =>
      gen_valid_engine_state_indirect_trap_family(seed)
    EngineStateInstantiationBoundariesProfile =>
      gen_valid_engine_state_instantiation_failure_family(seed)
    EngineStateTrapCommitMatrixProfile =>
      gen_valid_engine_state_trap_commit_family(seed)
    EngineStateInvalidModuleProfile =>
      gen_valid_engine_state_invalid_module_family(seed)
    _ => ""
  }
}

///|
fn gen_valid_engine_state_indirect_traps_module(seed : UInt64) -> Module {
  let prefix = gen_valid_engine_state_import_prefix_leaf()
  let wrong_type = Func::new(
    Locals::empty(),
    Expr::new([Instruction::i32_const(I32(0x12345678))]),
  )
  let trap_body : Array[Instruction] = []
  match (seed % 3UL).to_int() {
    0 =>
      gen_valid_engine_state_append(trap_body, [
        Instruction::i32_const(I32(1)),
        Instruction::i32_const(I32(3)),
        Instruction::call_indirect(TypeIdx::new(7U), TableIdx::new(0U)),
        Instruction::drop(),
      ])
    1 =>
      gen_valid_engine_state_append(trap_body, [
        Instruction::i32_const(I32(1)),
        Instruction::ref_func(FuncIdx::new(6U)),
        Instruction::table_set(TableIdx::new(0U)),
        Instruction::i32_const(I32(1)),
        Instruction::i32_const(I32(1)),
        Instruction::call_indirect(TypeIdx::new(7U), TableIdx::new(0U)),
        Instruction::drop(),
      ])
    _ =>
      gen_valid_engine_state_append(trap_body, [
        Instruction::i32_const(I32(1)),
        Instruction::i32_const(I32(99)),
        Instruction::call_indirect(TypeIdx::new(7U), TableIdx::new(0U)),
        Instruction::drop(),
      ])
  }
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(3400))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(250, [
      Instruction::i32_const(I32(250)),
      Instruction::call(FuncIdx::new(0U)),
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x70000000))
  start.push(Instruction::call(FuncIdx::new(7U)))
  gen_valid_engine_state_base_module(
    gen_valid_engine_state_resource_imports(),
    [TypeIdx::new(7U), TypeIdx::new(8U), TypeIdx::new(5U), TypeIdx::new(5U)],
    [
      prefix,
      wrong_type,
      Func::new(Locals::empty(), Expr::new(trap_body)),
      Func::new(Locals::empty(), Expr::new(start)),
    ],
    gen_valid_engine_state_import_exports(),
    [],
    [],
    [],
    [Elem::new(ElemMode::declarative(), ElemKind::funcs([FuncIdx::new(6U)]))],
    [],
  )
}

///|
fn gen_valid_engine_state_trap_placement_module(seed : UInt64) -> Module {
  let prefix = gen_valid_engine_state_import_prefix_leaf()
  let trap_leaf = Func::new(
    Locals::empty(),
    Expr::new(gen_valid_engine_state_trap_instructions(seed)),
  )
  let wrapper_body : Array[Instruction] = []
  match ((seed >> 8) % 4UL).to_int() {
    0 => wrapper_body.push(Instruction::call(FuncIdx::new(6U)))
    1 =>
      wrapper_body.push(
        Instruction::block(
          BlockType::void_(),
          Expr::new([Instruction::call(FuncIdx::new(6U))]),
        ),
      )
    2 =>
      wrapper_body.push(
        Instruction::loop_(
          BlockType::void_(),
          Expr::new([Instruction::call(FuncIdx::new(6U))]),
        ),
      )
    _ =>
      gen_valid_engine_state_append(wrapper_body, [
        Instruction::i32_const(I32(1)),
        Instruction::if_(
          BlockType::void_(),
          [Instruction::call(FuncIdx::new(6U))],
          Some([]),
        ),
      ])
  }
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(3500))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(260, [
      Instruction::i32_const(I32(260)),
      Instruction::call(FuncIdx::new(0U)),
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x70000000))
  start.push(Instruction::call(FuncIdx::new(7U)))
  gen_valid_engine_state_base_module(
    gen_valid_engine_state_resource_imports(),
    [TypeIdx::new(7U), TypeIdx::new(5U), TypeIdx::new(5U), TypeIdx::new(5U)],
    [
      prefix,
      trap_leaf,
      Func::new(Locals::empty(), Expr::new(wrapper_body)),
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
pub fn gen_valid_engine_state_instantiation_failure_family(
  seed : UInt64,
) -> String {
  match (seed % 3UL).to_int() {
    0 => "active-data-out-of-bounds"
    1 => "memory-import-limit-mismatch"
    _ => "table-import-limit-mismatch"
  }
}

///|
fn gen_valid_engine_state_instantiation_boundaries_module(
  seed : UInt64,
) -> Module {
  let leaf = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_const(I32(1)),
      Instruction::i32_add(),
    ]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(3600))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(270, [
      Instruction::i32_const(I32(270)),
      Instruction::call(FuncIdx::new(0U)),
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  match (seed % 3UL).to_int() {
    0 =>
      gen_valid_engine_state_base_module(
        [],
        [TypeIdx::new(7U), TypeIdx::new(5U)],
        [leaf, Func::new(Locals::empty(), Expr::new(start))],
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
        [
          Data::new(
            DataMode::active(
              MemIdx::new(0U),
              Expr::new([Instruction::i32_const(I32(65535))]),
            ),
            b"out-of-bounds",
          ),
        ],
      )
    1 =>
      gen_valid_engine_state_base_module(
        [
          Import::new(
            Name::from_string("__fuzz"),
            Name::from_string("state_memory"),
            ExternType::mem(MemType::new(Limits::i32(2U, Some(2U)))),
          ),
        ],
        [TypeIdx::new(7U), TypeIdx::new(5U)],
        [leaf, Func::new(Locals::empty(), Expr::new(start))],
        [
          Export::new(
            Name::from_string("__fuzz_memory_0"),
            ExternIdx::mem(MemIdx::new(0U)),
          ),
        ],
        [],
        [],
        [],
        [],
        [],
      )
    _ =>
      gen_valid_engine_state_base_module(
        [
          Import::new(
            Name::from_string("__fuzz"),
            Name::from_string("state_table"),
            ExternType::table(
              TableType::new(
                gen_valid_engine_state_funcref(),
                Limits::i32(8U, Some(8U)),
              ),
            ),
          ),
        ],
        [TypeIdx::new(7U), TypeIdx::new(5U)],
        [leaf, Func::new(Locals::empty(), Expr::new(start))],
        [
          Export::new(
            Name::from_string("__fuzz_table_0"),
            ExternIdx::table(TableIdx::new(0U)),
          ),
        ],
        [],
        [],
        [],
        [],
        [],
      )
  }
}

///|
pub fn gen_valid_engine_state_cross_instance_support_module(
  seed : UInt64,
) -> Module {
  Module::new()
  .with_table_sec(
    TableSec::new([
      Table::new(
        TableType::new(
          gen_valid_engine_state_funcref(),
          Limits::i32(4U, Some(8U)),
        ),
        None,
      ),
    ]),
  )
  .with_mem_sec(MemSec::new([MemType::new(Limits::i32(1U, Some(2U)))]))
  .with_global_sec(
    GlobalSec::new([
      Global::new(
        GlobalType::new(ValType::i32(), true),
        Expr::new([
          Instruction::i32_const(gen_valid_engine_state_seed_i32(seed, 130UL)),
        ]),
      ),
    ]),
  )
  .with_export_sec(
    ExportSec::new([
      Export::new(
        Name::from_string("state_memory"),
        ExternIdx::mem(MemIdx::new(0U)),
      ),
      Export::new(
        Name::from_string("state_table"),
        ExternIdx::table(TableIdx::new(0U)),
      ),
      Export::new(
        Name::from_string("state_global_i32"),
        ExternIdx::global(GlobalIdx::new(0U)),
      ),
    ]),
  )
  .with_data_sec(
    DataSec::new([
      Data::new(
        DataMode::active(
          MemIdx::new(0U),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
        b"provider-state",
      ),
    ]),
  )
}

///|
fn gen_valid_engine_state_cross_instance_module(seed : UInt64) -> Module {
  let linked_imports = [
    Import::new(
      Name::from_string("__link"),
      Name::from_string("state_global_i32"),
      ExternType::global(GlobalType::new(ValType::i32(), true)),
    ),
    Import::new(
      Name::from_string("__link"),
      Name::from_string("state_memory"),
      ExternType::mem(MemType::new(Limits::i32(1U, Some(2U)))),
    ),
    Import::new(
      Name::from_string("__link"),
      Name::from_string("state_table"),
      ExternType::table(
        TableType::new(
          gen_valid_engine_state_funcref(),
          Limits::i32(4U, Some(8U)),
        ),
      ),
    ),
  ]
  let leaf = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::global_get(GlobalIdx::new(0U)),
      Instruction::i32_xor(),
    ]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(3700))
  gen_valid_engine_state_append(start, [
    Instruction::i32_const(gen_valid_engine_state_seed_i32(seed, 131UL)),
    Instruction::global_set(GlobalIdx::new(0U)),
    Instruction::i32_const(I32(32)),
    Instruction::i32_const(gen_valid_engine_state_seed_i32(seed, 132UL)),
    Instruction::i32_store(gen_valid_engine_state_memarg(2U, 0UL)),
  ])
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(280, [
      Instruction::i32_const(I32(280)),
      Instruction::i32_const(I32(0)),
      Instruction::call_indirect(TypeIdx::new(7U), TableIdx::new(0U)),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(281, [
      Instruction::i32_const(I32(281)),
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    linked_imports,
    [TypeIdx::new(7U), TypeIdx::new(5U)],
    [leaf, Func::new(Locals::empty(), Expr::new(start))],
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
    ],
    [],
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
    [
      Data::new(
        DataMode::active(
          MemIdx::new(0U),
          Expr::new([Instruction::i32_const(I32(64))]),
        ),
        b"consumer-segment",
      ),
    ],
  )
}

///|
fn gen_valid_engine_state_exceptions_module(seed : UInt64) -> Module {
  let payload = gen_valid_engine_state_seed_i32(seed, 140UL)
  let caught = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::block(
        BlockType::val_type(ValType::i32()),
        Expr::new([
          Instruction::try_table(
            BlockType::void_(),
            [Catch::new(TagIdx::new(0U), LabelIdx::new(0U))],
            Expr::new([
              Instruction::i32_const(payload),
              Instruction::throw_(TagIdx::new(0U)),
            ]),
          ),
          Instruction::i32_const(I32(0)),
        ]),
      ),
    ]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(3800))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(290, [
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(8U), TypeIdx::new(5U)],
    [caught, Func::new(Locals::empty(), Expr::new(start))],
    [],
    [],
    [],
    [],
    [],
    [],
  ).with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(2U))]))
}

///|
fn gen_valid_engine_state_gc_module(seed : UInt64) -> Module {
  let field = FieldType::new(StorageType::val_type(ValType::i32()), Mut::var_())
  let gc_value = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::i32_const(gen_valid_engine_state_seed_i32(seed, 141UL)),
      Instruction::struct_new(TypeIdx::new(12U)),
      Instruction::struct_get(TypeIdx::new(12U), U32(0U)),
    ]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(3900))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(300, [
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(8U), TypeIdx::new(5U)],
    [gc_value, Func::new(Locals::empty(), Expr::new(start))],
    [],
    [],
    [],
    [],
    [],
    [],
  ).with_type_sec(
    gen_valid_engine_state_extended_types([
      RecType::new(SubType::comp_type(CompType::struct_([field]))),
    ]),
  )
}
