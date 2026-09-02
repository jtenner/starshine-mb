///|
fn gen_valid_engine_state_join_instruction(seed : UInt64) -> Instruction {
  match (seed % 4UL).to_int() {
    0 => Instruction::i32_add()
    1 => Instruction::i32_xor()
    2 => Instruction::i32_or()
    _ => Instruction::i32_sub()
  }
}

///|
fn gen_valid_engine_state_topology_module(seed : UInt64) -> Module {
  let leaf = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_const(gen_valid_engine_state_seed_i32(seed, 20UL)),
      Instruction::i32_add(),
    ]),
  )
  let left = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::call(FuncIdx::new(5U)),
      Instruction::i32_const(I32(1)),
      Instruction::i32_add(),
    ]),
  )
  let right = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::call(FuncIdx::new(5U)),
      Instruction::i32_const(I32(3)),
      Instruction::i32_mul(),
    ]),
  )
  let dispatch_slot = ((seed >> 5) % 2UL).to_int()
  let dispatch = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_const(I32(dispatch_slot)),
      Instruction::call_indirect(TypeIdx::new(7U), TableIdx::new(0U)),
    ]),
  )
  let diamond = Func::new(
    Locals::from_types([ValType::i32(), ValType::i32()]),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::call(FuncIdx::new(6U)),
      Instruction::local_set(LocalIdx::new(1U)),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::call(FuncIdx::new(7U)),
      Instruction::local_set(LocalIdx::new(2U)),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::local_get(LocalIdx::new(2U)),
      gen_valid_engine_state_join_instruction(seed),
      Instruction::call(FuncIdx::new(8U)),
    ]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(1900))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(90, [
      Instruction::i32_const(I32(90)),
      Instruction::call(FuncIdx::new(0U)),
      Instruction::call(FuncIdx::new(9U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(1901))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(91, [
      Instruction::i32_const(I32(91)),
      Instruction::call(FuncIdx::new(0U)),
      Instruction::call(FuncIdx::new(8U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [
      TypeIdx::new(7U),
      TypeIdx::new(7U),
      TypeIdx::new(7U),
      TypeIdx::new(7U),
      TypeIdx::new(7U),
      TypeIdx::new(5U),
    ],
    [
      leaf,
      left,
      right,
      dispatch,
      diamond,
      Func::new(Locals::empty(), Expr::new(start)),
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
        ElemKind::funcs([FuncIdx::new(5U), FuncIdx::new(6U)]),
      ),
    ],
    [],
  )
}

///|
fn gen_valid_engine_state_effects_module(seed : UInt64) -> Module {
  let address = 32 + ((seed >> 7) % 4UL).to_int() * 4
  let global_effect = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::i32_const(I32(2002)),
      Instruction::call(FuncIdx::new(2U)),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::global_set(GlobalIdx::new(0U)),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_const(gen_valid_engine_state_seed_i32(seed, 21UL)),
      Instruction::i32_add(),
    ]),
  )
  let memory_effect = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::i32_const(I32(2003)),
      Instruction::call(FuncIdx::new(2U)),
      Instruction::i32_const(I32(address)),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_store(gen_valid_engine_state_memarg(2U, 0UL)),
      Instruction::i32_const(I32(address)),
      Instruction::i32_load(gen_valid_engine_state_memarg(2U, 0UL)),
    ]),
  )
  let merge_body : Array[Instruction] = []
  if ((seed >> 3) & 1UL) == 0UL {
    gen_valid_engine_state_append(merge_body, [
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::call(FuncIdx::new(5U)),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::call(FuncIdx::new(6U)),
    ])
  } else {
    gen_valid_engine_state_append(merge_body, [
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::call(FuncIdx::new(6U)),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::call(FuncIdx::new(5U)),
    ])
  }
  merge_body.push(gen_valid_engine_state_join_instruction(seed >> 9))
  let merge = Func::new(Locals::empty(), Expr::new(merge_body))
  let branch = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_const(I32(1)),
      Instruction::i32_and(),
      Instruction::if_(
        BlockType::val_type(ValType::i32()),
        [
          Instruction::local_get(LocalIdx::new(0U)),
          Instruction::call(FuncIdx::new(5U)),
        ],
        Some([
          Instruction::local_get(LocalIdx::new(0U)),
          Instruction::call(FuncIdx::new(6U)),
        ]),
      ),
    ]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(2000))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(100, [
      Instruction::i32_const(I32(100)),
      Instruction::call(FuncIdx::new(0U)),
      Instruction::i32_const(I32(101)),
      Instruction::call(FuncIdx::new(0U)),
      Instruction::call(FuncIdx::new(7U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(2001))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(101, [
      Instruction::i32_const(I32(102)),
      Instruction::call(FuncIdx::new(0U)),
      Instruction::call(FuncIdx::new(8U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [
      TypeIdx::new(7U),
      TypeIdx::new(7U),
      TypeIdx::new(6U),
      TypeIdx::new(7U),
      TypeIdx::new(5U),
    ],
    [
      global_effect,
      memory_effect,
      merge,
      branch,
      Func::new(Locals::empty(), Expr::new(start)),
    ],
    [
      Export::new(
        Name::from_string("__fuzz_global_0"),
        ExternIdx::global(GlobalIdx::new(0U)),
      ),
      Export::new(
        Name::from_string("__fuzz_memory_0"),
        ExternIdx::mem(MemIdx::new(0U)),
      ),
    ],
    [],
    [MemType::new(Limits::i32(1U, Some(1U)))],
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
fn gen_valid_engine_state_resources_module(seed : UInt64) -> Module {
  let read = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::i32_const(I32(0)),
      Instruction::i32_load(gen_valid_engine_state_memarg(2U, 0UL)),
    ]),
  )
  let mutate = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::global_set(GlobalIdx::new(0U)),
      Instruction::i32_const(I32(4)),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_const(I32(8)),
      Instruction::memory_fill(MemIdx::new(0U)),
      Instruction::i32_const(I32(2)),
      Instruction::ref_func(FuncIdx::new(5U)),
      Instruction::table_set(TableIdx::new(0U)),
      Instruction::global_get(GlobalIdx::new(0U)),
    ]),
  )
  let grow = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::i32_const(I32(1)),
      Instruction::memory_grow(MemIdx::new(0U)),
      Instruction::drop(),
      Instruction::ref_null(HeapType::abs(AbsHeapType::func())),
      Instruction::i32_const(I32(1)),
      Instruction::table_grow(TableIdx::new(0U)),
      Instruction::drop(),
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  let memory_copy = [
    Instruction::i32_const(I32(16)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(8)),
    Instruction::memory_copy(MemIdx::new(0U), MemIdx::new(0U)),
  ]
  let table_copy = [
    Instruction::i32_const(I32(1)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(2)),
    Instruction::table_copy(TableIdx::new(0U), TableIdx::new(0U)),
  ]
  let copy_body : Array[Instruction] = []
  match ((seed >> 11) % 4UL).to_int() {
    0 => {
      gen_valid_engine_state_append(copy_body, memory_copy)
      gen_valid_engine_state_append(copy_body, table_copy)
    }
    1 => {
      gen_valid_engine_state_append(copy_body, table_copy)
      gen_valid_engine_state_append(copy_body, memory_copy)
    }
    2 => {
      copy_body.push(
        Instruction::block(BlockType::void_(), Expr::new(memory_copy)),
      )
      gen_valid_engine_state_append(copy_body, table_copy)
    }
    _ => {
      copy_body.push(Instruction::i32_const(I32(1)))
      copy_body.push(
        Instruction::if_(BlockType::void_(), memory_copy, Some([])),
      )
      gen_valid_engine_state_append(copy_body, table_copy)
    }
  }
  copy_body.push(Instruction::call(FuncIdx::new(5U)))
  let copy = Func::new(Locals::empty(), Expr::new(copy_body))
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(2100))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(110, [
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(111, [
      Instruction::i32_const(I32(110)),
      Instruction::call(FuncIdx::new(0U)),
      Instruction::call(FuncIdx::new(6U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(2101))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(112, [
      Instruction::call(FuncIdx::new(7U)),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(113, [
      Instruction::call(FuncIdx::new(8U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  let fill_byte = (seed % 251UL + 1UL).to_byte()
  gen_valid_engine_state_base_module(
    [],
    [
      TypeIdx::new(8U),
      TypeIdx::new(7U),
      TypeIdx::new(8U),
      TypeIdx::new(8U),
      TypeIdx::new(5U),
    ],
    [read, mutate, grow, copy, Func::new(Locals::empty(), Expr::new(start))],
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
    [
      Table::new(
        TableType::new(
          gen_valid_engine_state_funcref(),
          Limits::i32(4U, Some(8U)),
        ),
        None,
      ),
    ],
    [MemType::new(Limits::i32(1U, Some(2U)))],
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
        ElemKind::funcs([FuncIdx::new(5U), FuncIdx::new(6U)]),
      ),
      Elem::new(
        ElemMode::active(
          TableIdx::new(0U),
          Expr::new([Instruction::i32_const(I32(1))]),
        ),
        ElemKind::funcs([FuncIdx::new(7U), FuncIdx::new(5U)]),
      ),
    ],
    [
      Data::new(
        DataMode::active(
          MemIdx::new(0U),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
        b"\x01\x02\x03\x04\x05\x06\x07\x08",
      ),
      Data::new(
        DataMode::active(
          MemIdx::new(0U),
          Expr::new([Instruction::i32_const(I32(2))]),
        ),
        Bytes::from_array([fill_byte, fill_byte, fill_byte, fill_byte]),
      ),
    ],
  )
}

///|
fn gen_valid_engine_state_boundary_i32(seed : UInt64) -> @lib.I32 {
  match (seed % 8UL).to_int() {
    0 => I32(0)
    1 => I32(-1)
    2 => I32(-2147483648)
    3 => I32(2147483647)
    4 => I32(255)
    5 => I32(256)
    6 => I32(65535)
    _ => I32(65536)
  }
}

///|
fn gen_valid_engine_state_boundary_f32_bits(seed : UInt64) -> @lib.I32 {
  match ((seed >> 4) % 8UL).to_int() {
    0 => I32(0)
    1 => I32(-2147483648)
    2 => I32(0x7f800000)
    3 => I32(-8388608)
    4 => I32(1)
    5 => I32(0x007fffff)
    6 => I32(0x7fc00001)
    _ => I32(-4194303)
  }
}

///|
fn gen_valid_engine_state_boundaries_module(seed : UInt64) -> Module {
  let integer_body : Array[Instruction] = [
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::i32_const(gen_valid_engine_state_boundary_i32(seed)),
  ]
  match ((seed >> 8) % 4UL).to_int() {
    0 => integer_body.push(Instruction::i32_add())
    1 => integer_body.push(Instruction::i32_xor())
    2 => integer_body.push(Instruction::i32_rotl())
    _ => integer_body.push(Instruction::i32_rotr())
  }
  let integer = Func::new(Locals::empty(), Expr::new(integer_body))
  let memory = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::i32_const(I32(65529)),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_store16(gen_valid_engine_state_memarg(0U, 0UL)),
      Instruction::i32_const(I32(65532)),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_store(gen_valid_engine_state_memarg(2U, 0UL)),
      Instruction::i32_const(I32(65532)),
      Instruction::i32_load(gen_valid_engine_state_memarg(2U, 0UL)),
    ]),
  )
  let float_bits = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::i32_const(gen_valid_engine_state_boundary_f32_bits(seed)),
      Instruction::f32_reinterpret_i32(),
      if ((seed >> 12) & 1UL) == 0UL {
        Instruction::f32_abs()
      } else {
        Instruction::f32_neg()
      },
      Instruction::i32_reinterpret_f32(),
    ]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(2200))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(120, [
      Instruction::i32_const(I32(120)),
      Instruction::call(FuncIdx::new(0U)),
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(121, [
      Instruction::i32_const(I32(121)),
      Instruction::call(FuncIdx::new(0U)),
      Instruction::call(FuncIdx::new(6U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(2201))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(122, [
      Instruction::call(FuncIdx::new(7U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(7U), TypeIdx::new(7U), TypeIdx::new(8U), TypeIdx::new(5U)],
    [integer, memory, float_bits, Func::new(Locals::empty(), Expr::new(start))],
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
fn gen_valid_engine_state_optimizer_shapes_module(seed : UInt64) -> Module {
  let constant = gen_valid_engine_state_seed_i32(seed, 30UL)
  let leaf = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_const(constant),
      Instruction::i32_add(),
    ]),
  )
  let wrapper = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  let debris_body : Array[Instruction] = []
  match ((seed >> 6) % 4UL).to_int() {
    0 =>
      gen_valid_engine_state_append(debris_body, [
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::local_set(LocalIdx::new(1U)),
        Instruction::local_get(LocalIdx::new(1U)),
        Instruction::i32_const(I32(0)),
        Instruction::i32_add(),
        Instruction::call(FuncIdx::new(6U)),
      ])
    1 =>
      gen_valid_engine_state_append(debris_body, [
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::local_tee(LocalIdx::new(1U)),
        Instruction::drop(),
        Instruction::block(
          BlockType::val_type(ValType::i32()),
          Expr::new([
            Instruction::local_get(LocalIdx::new(1U)),
            Instruction::call(FuncIdx::new(6U)),
          ]),
        ),
      ])
    2 =>
      gen_valid_engine_state_append(debris_body, [
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::call(FuncIdx::new(6U)),
        Instruction::i32_const(gen_valid_engine_state_seed_i32(seed, 31UL)),
        Instruction::drop(),
      ])
    _ =>
      gen_valid_engine_state_append(debris_body, [
        Instruction::i32_const(I32(1)),
        Instruction::if_(
          BlockType::val_type(ValType::i32()),
          [
            Instruction::local_get(LocalIdx::new(0U)),
            Instruction::call(FuncIdx::new(6U)),
          ],
          Some([
            Instruction::local_get(LocalIdx::new(0U)),
            Instruction::i32_const(constant),
            Instruction::i32_add(),
          ]),
        ),
      ])
  }
  gen_valid_engine_state_append(debris_body, [
    Instruction::local_tee(LocalIdx::new(1U)),
    Instruction::global_set(GlobalIdx::new(0U)),
    Instruction::local_get(LocalIdx::new(1U)),
  ])
  let debris = Func::new(
    Locals::from_types([ValType::i32()]),
    Expr::new(debris_body),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(2300))
  for
    item in [
      (130, FuncIdx::new(5U)),
      (131, FuncIdx::new(6U)),
      (132, FuncIdx::new(7U)),
    ] {
    let (value_id, target) = item
    gen_valid_engine_state_append(
      start,
      gen_valid_engine_state_observe_i32(value_id, [
        Instruction::i32_const(I32(value_id)),
        Instruction::call(FuncIdx::new(0U)),
        Instruction::call(target),
      ]),
    )
  }
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(7U), TypeIdx::new(7U), TypeIdx::new(7U), TypeIdx::new(5U)],
    [leaf, wrapper, debris, Func::new(Locals::empty(), Expr::new(start))],
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
fn gen_valid_engine_state_equivalent_families_module(seed : UInt64) -> Module {
  let constant_int = (seed % 1000000UL + 1UL).to_int()
  let constant = @lib.I32(constant_int)
  let canonical = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_const(constant),
      Instruction::i32_add(),
    ]),
  )
  let alternate_body : Array[Instruction] = []
  match ((seed >> 10) % 4UL).to_int() {
    0 =>
      gen_valid_engine_state_append(alternate_body, [
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::i32_const(I32(-constant_int)),
        Instruction::i32_sub(),
      ])
    1 =>
      alternate_body.push(
        Instruction::block(
          BlockType::val_type(ValType::i32()),
          Expr::new([
            Instruction::local_get(LocalIdx::new(0U)),
            Instruction::i32_const(constant),
            Instruction::i32_add(),
          ]),
        ),
      )
    2 =>
      gen_valid_engine_state_append(alternate_body, [
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::i32_const(I32(1)),
        Instruction::i32_and(),
        Instruction::if_(
          BlockType::val_type(ValType::i32()),
          [
            Instruction::local_get(LocalIdx::new(0U)),
            Instruction::i32_const(constant),
            Instruction::i32_add(),
          ],
          Some([
            Instruction::local_get(LocalIdx::new(0U)),
            Instruction::i32_const(I32(-constant_int)),
            Instruction::i32_sub(),
          ]),
        ),
      ])
    _ =>
      gen_valid_engine_state_append(alternate_body, [
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::local_set(LocalIdx::new(1U)),
        Instruction::local_get(LocalIdx::new(1U)),
        Instruction::i32_const(constant),
        Instruction::i32_add(),
      ])
  }
  let alternate = Func::new(
    Locals::from_types([ValType::i32()]),
    Expr::new(alternate_body),
  )
  let wrapper = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  let verifier = Func::new(
    Locals::from_types([ValType::i32(), ValType::i32()]),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::call(FuncIdx::new(5U)),
      Instruction::local_set(LocalIdx::new(1U)),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::call(FuncIdx::new(6U)),
      Instruction::local_set(LocalIdx::new(2U)),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::local_get(LocalIdx::new(2U)),
      Instruction::i32_ne(),
      Instruction::if_(BlockType::void_(), [Instruction::unreachable_()], None),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::call(FuncIdx::new(7U)),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::i32_ne(),
      Instruction::if_(BlockType::void_(), [Instruction::unreachable_()], None),
      Instruction::local_get(LocalIdx::new(1U)),
    ]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(2400))
  for
    item in [
      (140, FuncIdx::new(5U)),
      (141, FuncIdx::new(6U)),
      (142, FuncIdx::new(8U)),
    ] {
    let (value_id, target) = item
    gen_valid_engine_state_append(
      start,
      gen_valid_engine_state_observe_i32(value_id, [
        Instruction::i32_const(I32(140)),
        Instruction::call(FuncIdx::new(0U)),
        Instruction::call(target),
      ]),
    )
  }
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [
      TypeIdx::new(7U),
      TypeIdx::new(7U),
      TypeIdx::new(7U),
      TypeIdx::new(7U),
      TypeIdx::new(5U),
    ],
    [
      canonical,
      alternate,
      wrapper,
      verifier,
      Func::new(Locals::empty(), Expr::new(start)),
    ],
    [],
    [],
    [],
    [],
    [],
    [],
  )
}
