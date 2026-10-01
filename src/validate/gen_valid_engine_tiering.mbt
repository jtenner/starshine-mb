///|
fn gen_valid_engine_tiering_profiles() -> Array[GenValidProfile] {
  [
    EngineTieringLoopProfile,
    EngineTieringLargeFunctionProfile,
    EngineTieringCallChainProfile,
    EngineTieringCallFanoutProfile,
    EngineTieringIndirectProfile,
    EngineTieringLocalsStackProfile,
    EngineTieringMemoryProfile,
    EngineTieringGcProfile,
  ]
}

///|
fn gen_valid_engine_tiering_ordinal(profile : GenValidProfile) -> Int {
  match profile {
    EngineTieringLoopProfile => 0
    EngineTieringLargeFunctionProfile => 1
    EngineTieringCallChainProfile => 2
    EngineTieringCallFanoutProfile => 3
    EngineTieringIndirectProfile => 4
    EngineTieringLocalsStackProfile => 5
    EngineTieringMemoryProfile => 6
    EngineTieringGcProfile => 7
    _ => 0
  }
}

///|
fn gen_valid_engine_tiering_config(profile : GenValidProfile) -> GenValidConfig {
  let ordinal = gen_valid_engine_tiering_ordinal(profile)
  GenValidConfig::{
    ..GenValidConfig::portable_coverage_forced_default(),
    max_type_defs: 48,
    max_defined_funcs: 48 + ordinal,
    max_params: 8,
    max_results: 4,
    max_locals: 128,
    max_body_statements: 512,
    max_body_depth: 64,
    max_name_length: 512 + ordinal,
  }
}

///|
fn gen_valid_is_engine_tiering_config(config : GenValidConfig) -> Bool {
  for profile in gen_valid_engine_tiering_profiles() {
    if config == gen_valid_engine_tiering_config(profile) {
      return true
    }
  }
  false
}

///|
fn gen_valid_engine_tiering_profile_kind(
  config : GenValidConfig,
) -> GenValidProfile {
  for profile in gen_valid_engine_tiering_profiles() {
    if config == gen_valid_engine_tiering_config(profile) {
      return profile
    }
  }
  EngineTieringLoopProfile
}

///|
fn gen_valid_engine_tiering_scale(seed : UInt64) -> Int {
  match (seed % 4UL).to_int() {
    0 => 256
    1 => 1024
    2 => 4096
    _ => 16384
  }
}

///|
pub fn gen_valid_engine_tiering_profile_case_label(
  profile : GenValidProfile,
  seed : UInt64,
) -> String? {
  let scale = gen_valid_engine_tiering_scale(seed)
  match profile {
    EngineTieringLoopProfile => Some("tiering:loop:trip-count=\{scale}")
    EngineTieringLargeFunctionProfile => {
      let locals = 32 + (seed % 4UL).to_int() * 32
      let functions = 32 + ((seed >> 2) % 4UL).to_int() * 32
      Some("tiering:large-function:locals=\{locals}:functions=\{functions}")
    }
    EngineTieringCallChainProfile => {
      let depth = 8 << (seed % 4UL).to_int()
      Some("tiering:call-chain:depth=\{depth}")
    }
    EngineTieringCallFanoutProfile => {
      let width = 8 << ((seed >> 2) % 4UL).to_int()
      Some("tiering:call-fanout:width=\{width}")
    }
    EngineTieringIndirectProfile => {
      let mode = if ((seed >> 4) & 1UL) == 1UL {
        "polymorphic"
      } else {
        "monomorphic"
      }
      Some("tiering:indirect:\{mode}:trip-count=\{scale}")
    }
    EngineTieringLocalsStackProfile =>
      Some("tiering:locals-stack:wide=16:deep=64")
    EngineTieringMemoryProfile =>
      Some("tiering:memory-grow-bounds:trip-count=\{scale}")
    EngineTieringGcProfile => Some("tiering:gc-allocation-graph")
    _ => None
  }
}

///|
fn gen_valid_engine_tiering_start(workload : FuncIdx, event : Int) -> Func {
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(event))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(event, [Instruction::call(workload)]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  Func::new(Locals::empty(), Expr::new(start))
}

///|
fn gen_valid_engine_tiering_loop_module(seed : UInt64) -> Module {
  let trip_count = gen_valid_engine_tiering_scale(seed)
  let body = [
    Instruction::i32_const(I32(0)),
    Instruction::local_set(LocalIdx::new(0U)),
    Instruction::i32_const(gen_valid_engine_state_seed_i32(seed, 600UL)),
    Instruction::local_set(LocalIdx::new(1U)),
    Instruction::block(
      BlockType::void_(),
      Expr::new([
        Instruction::loop_(
          BlockType::void_(),
          Expr::new([
            Instruction::local_get(LocalIdx::new(0U)),
            Instruction::i32_const(I32(trip_count)),
            Instruction::i32_ge_u(),
            Instruction::br_if(LabelIdx::new(1U)),
            Instruction::local_get(LocalIdx::new(1U)),
            Instruction::local_get(LocalIdx::new(0U)),
            Instruction::i32_const(I32(0x9e37)),
            Instruction::i32_mul(),
            Instruction::i32_xor(),
            Instruction::local_set(LocalIdx::new(1U)),
            Instruction::local_get(LocalIdx::new(0U)),
            Instruction::i32_const(I32(1)),
            Instruction::i32_add(),
            Instruction::local_set(LocalIdx::new(0U)),
            Instruction::br(LabelIdx::new(0U)),
          ]),
        ),
      ]),
    ),
    Instruction::local_get(LocalIdx::new(1U)),
  ]
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(8U), TypeIdx::new(5U)],
    [
      Func::new(
        Locals::from_types([ValType::i32(), ValType::i32()]),
        Expr::new(body),
      ),
      gen_valid_engine_tiering_start(FuncIdx::new(5U), 6000),
    ],
    [],
    [],
    [],
    [],
    [],
    [],
  )
}

///|
fn gen_valid_engine_tiering_call_chain_module(seed : UInt64) -> Module {
  let depth = 8 << (seed % 4UL).to_int()
  let functions : Array[Func] = []
  let types : Array[TypeIdx] = []
  for index in 0..<depth {
    let body = if index + 1 == depth {
      [Instruction::i32_const(gen_valid_engine_state_seed_i32(seed, 610UL))]
    } else {
      [
        Instruction::call(FuncIdx::new((5 + index + 1).reinterpret_as_uint())),
        Instruction::i32_const(I32(index + 1)),
        Instruction::i32_add(),
      ]
    }
    functions.push(Func::new(Locals::empty(), Expr::new(body)))
    types.push(TypeIdx::new(8U))
  }
  functions.push(gen_valid_engine_tiering_start(FuncIdx::new(5U), 6100))
  types.push(TypeIdx::new(5U))
  gen_valid_engine_state_base_module([], types, functions, [], [], [], [], [], [])
}

///|
fn gen_valid_engine_tiering_call_fanout_module(seed : UInt64) -> Module {
  let width = 8 << ((seed >> 2) % 4UL).to_int()
  let functions : Array[Func] = []
  let types : Array[TypeIdx] = []
  for index in 0..<width {
    functions.push(
      Func::new(
        Locals::empty(),
        Expr::new([
          Instruction::i32_const(
            gen_valid_engine_state_seed_i32(seed, (620 + index).to_uint64()),
          ),
        ]),
      ),
    )
    types.push(TypeIdx::new(8U))
  }
  let driver : Array[Instruction] = [Instruction::i32_const(I32(0))]
  for index in 0..<width {
    driver.push(
      Instruction::call(FuncIdx::new((5 + index).reinterpret_as_uint())),
    )
    driver.push(Instruction::i32_xor())
  }
  functions.push(Func::new(Locals::empty(), Expr::new(driver)))
  types.push(TypeIdx::new(8U))
  let driver_idx = FuncIdx::new((5 + width).reinterpret_as_uint())
  functions.push(gen_valid_engine_tiering_start(driver_idx, 6200))
  types.push(TypeIdx::new(5U))
  gen_valid_engine_state_base_module([], types, functions, [], [], [], [], [], [])
}

///|
fn gen_valid_engine_tiering_indirect_module(seed : UInt64) -> Module {
  let trip_count = gen_valid_engine_tiering_scale(seed)
  let polymorphic = ((seed >> 4) & 1UL) == 1UL
  let first = Func::new(
    Locals::empty(),
    Expr::new([Instruction::i32_const(I32(0x13579bdf))]),
  )
  let second = Func::new(
    Locals::empty(),
    Expr::new([Instruction::i32_const(I32(0x2468ace))]),
  )
  let driver : Array[Instruction] = [
    Instruction::i32_const(I32(0)),
    Instruction::local_set(LocalIdx::new(0U)),
    Instruction::i32_const(I32(0)),
    Instruction::local_set(LocalIdx::new(1U)),
  ]
  let loop_body : Array[Instruction] = [
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::i32_const(I32(trip_count)),
    Instruction::i32_ge_u(),
    Instruction::br_if(LabelIdx::new(1U)),
    Instruction::local_get(LocalIdx::new(1U)),
  ]
  if polymorphic {
    loop_body.push(Instruction::local_get(LocalIdx::new(0U)))
    loop_body.push(Instruction::i32_const(I32(1)))
    loop_body.push(Instruction::i32_and())
  } else {
    loop_body.push(Instruction::i32_const(I32(0)))
  }
  gen_valid_engine_state_append(loop_body, [
    Instruction::call_indirect(TypeIdx::new(8U), TableIdx::new(0U)),
    Instruction::i32_xor(),
    Instruction::local_set(LocalIdx::new(1U)),
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::i32_const(I32(1)),
    Instruction::i32_add(),
    Instruction::local_set(LocalIdx::new(0U)),
    Instruction::br(LabelIdx::new(0U)),
  ])
  driver.push(
    Instruction::block(
      BlockType::void_(),
      Expr::new([Instruction::loop_(BlockType::void_(), Expr::new(loop_body))]),
    ),
  )
  driver.push(Instruction::local_get(LocalIdx::new(1U)))
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(8U), TypeIdx::new(8U), TypeIdx::new(8U), TypeIdx::new(5U)],
    [
      first,
      second,
      Func::new(
        Locals::from_types([ValType::i32(), ValType::i32()]),
        Expr::new(driver),
      ),
      gen_valid_engine_tiering_start(FuncIdx::new(7U), 6300),
    ],
    [],
    [
      Table::new(
        TableType::new(
          gen_valid_engine_state_funcref(),
          Limits::i32(2U, Some(2U)),
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
fn gen_valid_engine_tiering_memory_module(seed : UInt64) -> Module {
  let trip_count = gen_valid_engine_tiering_scale(seed)
  let body = [
    Instruction::i32_const(I32(1)),
    Instruction::memory_grow(MemIdx::new(0U)),
    Instruction::drop(),
    Instruction::i32_const(I32(0)),
    Instruction::local_set(LocalIdx::new(0U)),
    Instruction::i32_const(gen_valid_engine_state_seed_i32(seed, 640UL)),
    Instruction::local_set(LocalIdx::new(1U)),
    Instruction::block(
      BlockType::void_(),
      Expr::new([
        Instruction::loop_(
          BlockType::void_(),
          Expr::new([
            Instruction::local_get(LocalIdx::new(0U)),
            Instruction::i32_const(I32(trip_count)),
            Instruction::i32_ge_u(),
            Instruction::br_if(LabelIdx::new(1U)),
            Instruction::i32_const(I32(64)),
            Instruction::local_get(LocalIdx::new(1U)),
            Instruction::local_get(LocalIdx::new(0U)),
            Instruction::i32_add(),
            Instruction::i32_store(gen_valid_engine_state_memarg(2U, 0UL)),
            Instruction::i32_const(I32(64)),
            Instruction::i32_load(gen_valid_engine_state_memarg(2U, 0UL)),
            Instruction::local_get(LocalIdx::new(1U)),
            Instruction::i32_xor(),
            Instruction::local_set(LocalIdx::new(1U)),
            Instruction::local_get(LocalIdx::new(0U)),
            Instruction::i32_const(I32(1)),
            Instruction::i32_add(),
            Instruction::local_set(LocalIdx::new(0U)),
            Instruction::br(LabelIdx::new(0U)),
          ]),
        ),
      ]),
    ),
    Instruction::local_get(LocalIdx::new(1U)),
  ]
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(8U), TypeIdx::new(5U)],
    [
      Func::new(
        Locals::from_types([ValType::i32(), ValType::i32()]),
        Expr::new(body),
      ),
      gen_valid_engine_tiering_start(FuncIdx::new(5U), 6400),
    ],
    [
      Export::new(
        Name::from_string("__fuzz_memory_0"),
        ExternIdx::mem(MemIdx::new(0U)),
      ),
    ],
    [],
    [MemType::new(Limits::i32(1U, Some(4U)))],
    [],
    [],
    [],
  )
}

///|
fn gen_valid_engine_tiering_profile_module(ctx : GenValidContext) -> Module {
  match gen_valid_engine_tiering_profile_kind(ctx.config) {
    EngineTieringLoopProfile =>
      gen_valid_engine_tiering_loop_module(ctx.root_seed)
    EngineTieringLargeFunctionProfile =>
      gen_valid_engine_state_compiler_boundaries_module(ctx.root_seed)
    EngineTieringCallChainProfile =>
      gen_valid_engine_tiering_call_chain_module(ctx.root_seed)
    EngineTieringCallFanoutProfile =>
      gen_valid_engine_tiering_call_fanout_module(ctx.root_seed)
    EngineTieringIndirectProfile =>
      gen_valid_engine_tiering_indirect_module(ctx.root_seed)
    EngineTieringLocalsStackProfile =>
      gen_valid_engine_state_stack_pressure_module(ctx.root_seed)
    EngineTieringMemoryProfile =>
      gen_valid_engine_tiering_memory_module(ctx.root_seed)
    EngineTieringGcProfile =>
      gen_valid_engine_state_gc_graph_module(ctx.root_seed)
    _ => gen_valid_engine_tiering_loop_module(ctx.root_seed)
  }
}
