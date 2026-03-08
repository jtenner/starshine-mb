///|
fn rand_bounded(max_exclusive : UInt, st : RandomState) -> UInt {
  if max_exclusive == 0 {
    0
  } else {
    st.next_uint() % max_exclusive
  }
}

///|
fn bytes_of(s : String) -> Bytes {
  let bytes = @buffer.new(size_hint=s.length())
  for i = 0; i < s.length(); i = i + 1 {
    bytes.write_byte(s[i].to_int().to_byte())
  }
  bytes.to_bytes()
}

///|
fn rand_len(size : Int, st : RandomState, max_len : UInt) -> Int {
  let base : UInt = if size <= 0 { 1 } else { size.reinterpret_as_uint() + 1 }
  let cap = if max_len < base { max_len } else { base }
  rand_bounded(cap + 1, st).reinterpret_as_int()
}

///|
fn rand_ident(st : RandomState, prefix : String) -> String {
  "\{prefix}\{st.next_uint() % 64}"
}

///|
fn rand_index(st : RandomState, bound : UInt) -> Index {
  Num(rand_bounded(bound, st))
}

///|
fn pick_value_type(st : RandomState) -> ValueType {
  match st.next_uint() % 6 {
    0 => I32
    1 => I64
    2 => F32
    3 => F64
    4 => FuncRef
    _ => ExternRef
  }
}

///|
fn pick_numeric_value_type(st : RandomState) -> ValueType {
  match st.next_uint() % 4 {
    0 => I32
    1 => I64
    2 => F32
    _ => F64
  }
}

///|
fn pick_numeric_opcode(st : RandomState) -> Opcode {
  match st.next_uint() % 14 {
    0 => I32Const
    1 => I64Const
    2 => F32Const
    3 => F64Const
    4 => I32Add
    5 => I32Sub
    6 => I64Add
    7 => I64Sub
    8 => F32Add
    9 => F32Sub
    10 => F64Add
    11 => F64Sub
    12 => I32Eqz
    _ => I64Eqz
  }
}

///|
fn pick_unary_opcode(st : RandomState) -> Opcode {
  match st.next_uint() % 12 {
    0 => I32Clz
    1 => I32Ctz
    2 => I32Popcnt
    3 => I64Clz
    4 => I64Ctz
    5 => I64Popcnt
    6 => F32Abs
    7 => F32Neg
    8 => F64Abs
    9 => F64Neg
    10 => I32Extend8S
    _ => I64Extend32S
  }
}

///|
fn pick_binary_opcode(st : RandomState) -> Opcode {
  match st.next_uint() % 20 {
    0 => I32Add
    1 => I32Sub
    2 => I32Mul
    3 => I32And
    4 => I32Or
    5 => I32Xor
    6 => I64Add
    7 => I64Sub
    8 => I64Mul
    9 => I64And
    10 => I64Or
    11 => I64Xor
    12 => F32Add
    13 => F32Sub
    14 => F32Mul
    15 => F32Div
    16 => F64Add
    17 => F64Sub
    18 => F64Mul
    _ => F64Div
  }
}

///|
fn pick_compare_opcode(st : RandomState) -> Opcode {
  match st.next_uint() % 12 {
    0 => I32Eq
    1 => I32Ne
    2 => I32LtS
    3 => I32GtS
    4 => I64Eq
    5 => I64Ne
    6 => I64LtS
    7 => I64GtS
    8 => F32Eq
    9 => F32Lt
    10 => F64Eq
    _ => F64Lt
  }
}

///|
fn pick_convert_opcode(st : RandomState) -> Opcode {
  match st.next_uint() % 16 {
    0 => I32WrapI64
    1 => I32TruncF32S
    2 => I32TruncF64S
    3 => I64ExtendI32S
    4 => I64TruncF32S
    5 => I64TruncF64S
    6 => F32ConvertI32S
    7 => F32ConvertI64S
    8 => F64ConvertI32S
    9 => F64ConvertI64S
    10 => F32DemoteF64
    11 => F64PromoteF32
    12 => I32ReinterpretF32
    13 => I64ReinterpretF64
    14 => F32ReinterpretI32
    _ => F64ReinterpretI64
  }
}

///|
fn pick_const_text(op : Opcode, st : RandomState) -> String {
  match op {
    I32Const => "\{(st.next_uint() % 200).reinterpret_as_int() - 100}"
    I64Const =>
      "\{(st.next_uint() % 200).reinterpret_as_int().to_int64() - 100L}"
    F32Const | F64Const =>
      match st.next_uint() % 8 {
        0 => "0.0"
        1 => "1.0"
        2 => "-1.0"
        3 => "3.5"
        4 => "-2.25"
        5 => "inf"
        6 => "-inf"
        _ => "nan"
      }
    _ => "0"
  }
}

///|
fn gen_memarg(st : RandomState, natural_align : UInt64) -> MemArg {
  let align = if (st.next_uint() & 1) == 1 {
    natural_align
  } else {
    match st.next_uint() % 4 {
      0 => 1UL
      1 => 2UL
      2 => 4UL
      _ => natural_align
    }
  }
  { align, offset: (st.next_uint() % 64).to_uint64() }
}

///|
fn gen_instruction(
  size : Int,
  st : RandomState,
  func_bound : UInt,
) -> Instruction {
  if size <= 0 {
    match st.next_uint() % 12 {
      0 => Nop
      1 => Drop
      2 => LocalGet(Num(0))
      3 => LocalSet(Num(0))
      4 => GlobalGet(Num(0))
      5 => MemorySize
      6 => TableSize(Num(0))
      7 => Const(I32Const, pick_const_text(I32Const, st))
      8 => Const(I64Const, pick_const_text(I64Const, st))
      9 => Const(F32Const, pick_const_text(F32Const, st))
      10 => Const(F64Const, pick_const_text(F64Const, st))
      _ => RefNull(FuncRef)
    }
  } else {
    let next = size / 2
    match st.next_uint() % 20 {
      0 => {
        let body : Array[Instruction] = []
        let n = rand_len(next, st, 3)
        for _ in 0..<n {
          body.push(gen_instruction(next, st, func_bound))
        }
        Block({ label: None, type_use: None }, body)
      }
      1 => {
        let body : Array[Instruction] = []
        let n = rand_len(next, st, 3)
        for _ in 0..<n {
          body.push(gen_instruction(next, st, func_bound))
        }
        Loop({ label: None, type_use: None }, body)
      }
      2 => {
        let then_body : Array[Instruction] = []
        let else_body : Array[Instruction] = []
        let nt = rand_len(next, st, 2)
        let ne = rand_len(next, st, 2)
        for _ in 0..<nt {
          then_body.push(gen_instruction(next, st, func_bound))
        }
        for _ in 0..<ne {
          else_body.push(gen_instruction(next, st, func_bound))
        }
        If({ label: None, type_use: None }, then_body, else_body)
      }
      3 => Br(Num(st.next_uint() % 2))
      4 => BrIf(Num(st.next_uint() % 2))
      5 => BrTable([Num(0), Num(1)], Num(0))
      6 => Return
      7 => Call(Num(rand_bounded(func_bound, st)))
      8 =>
        CallIndirect(Num(0), {
          type_index: Some(Num(0)),
          func_type: { params: [], results: [] },
          param_ids: [],
        })
      9 => Load(I32Load, gen_memarg(st, 4))
      10 => Store(I32Store, gen_memarg(st, 4))
      11 => Unary(pick_unary_opcode(st))
      12 => Binary(pick_binary_opcode(st))
      13 => Test(I32Eqz)
      14 => Compare(pick_compare_opcode(st))
      15 => Convert(pick_convert_opcode(st))
      16 => RefFunc(Num(rand_bounded(func_bound, st)))
      17 => Select(Some([pick_numeric_value_type(st)]))
      18 => TableGet(Num(0))
      _ => {
        let op = pick_numeric_opcode(st)
        Const(op, pick_const_text(op, st))
      }
    }
  }
}

///|
fn gen_func_type(st : RandomState) -> FuncType {
  let params : Array[ValueType] = []
  let results : Array[ValueType] = []
  let pc = st.next_uint() % 3
  let rc = st.next_uint() % 2
  for _ in 0..<pc.reinterpret_as_int() {
    params.push(pick_numeric_value_type(st))
  }
  for _ in 0..<rc.reinterpret_as_int() {
    results.push(pick_numeric_value_type(st))
  }
  { params, results }
}

///|
fn gen_type_use(st : RandomState, type_count : UInt) -> TypeUse {
  if type_count > 0 && (st.next_uint() & 1) == 1 {
    {
      type_index: Some(Num(st.next_uint() % type_count)),
      func_type: { params: [], results: [] },
      param_ids: [],
    }
  } else {
    let func_type = gen_func_type(st)
    let param_ids : Array[String?] = []
    for _ in func_type.params {
      param_ids.push(None)
    }
    { type_index: None, func_type, param_ids }
  }
}

///|
fn gen_module(size : Int, st : RandomState) -> Module {
  let fields : Array[ModuleField] = []

  // Always provide at least one func type for call_indirect / signature references.
  let type_count : UInt = st.next_uint() % 2 + 1
  for _ in 0..<type_count.reinterpret_as_int() {
    fields.push(TypeField({ id: None, func_type: gen_func_type(st) }))
  }
  let mut func_count : UInt = 0

  // Optional imported function.
  if (st.next_uint() & 1) == 1 {
    fields.push(
      ImportField({
        module_name: "env",
        field_name: "imp\{st.next_uint() % 8}",
        desc: ImportDesc::Func(gen_type_use(st, type_count)),
        id: Some("$imp\{st.next_uint() % 8}"),
      }),
    )
    func_count += 1
  }

  // At least one memory and table to make memory/table instructions valid.
  fields.push(
    MemoryField({
      id: Some("$mem0"),
      exports: [],
      memory_type: MemoryType({ min: 1, max: Some(2) }),
    }),
  )
  fields.push(
    TableField({
      id: Some("$tab0"),
      exports: [],
      table_type: { limits: { min: 1, max: Some(4) }, elem_type: FuncRef },
      elem_init: None,
      elem_exprs: None,
      elem_init_type: None,
      elem_offset: None,
    }),
  )

  // Optional global.
  if (st.next_uint() & 1) == 1 {
    fields.push(
      GlobalField({
        id: Some("$g0"),
        exports: [],
        global_type: { val_type: I32, mutable_: (st.next_uint() & 1) == 1 },
        init: [Const(I32Const, "0")],
      }),
    )
  }
  let func_defs : UInt = st.next_uint() % 3 + 1
  for i in 0..<func_defs.reinterpret_as_int() {
    let locals : Array[Local] = []
    let local_n = rand_len(size, st, 3)
    for _ in 0..<local_n {
      locals.push({ id: None, val_type: pick_numeric_value_type(st) })
    }
    let body : Array[Instruction] = []
    let body_n = rand_len(size + 1, st, 8)
    for _ in 0..<body_n {
      body.push(gen_instruction(size, st, func_count + func_defs))
    }
    fields.push(
      FuncField({
        id: Some("$f\{i}"),
        exports: [],
        type_use: gen_type_use(st, type_count),
        locals,
        body,
      }),
    )
    func_count += 1
  }

  // Optional element/data segments.
  if func_count > 0 && (st.next_uint() & 1) == 1 {
    let funcs : Array[Index] = [Num(0)]
    if func_count > 1 {
      funcs.push(Num(1))
    }
    fields.push(
      ElemField({
        id: None,
        table_index: Num(0),
        offset: [Const(I32Const, "0")],
        func_indices: funcs,
        elem_exprs: [],
        elem_type: None,
      }),
    )
  }
  if (st.next_uint() & 1) == 1 {
    fields.push(
      DataField({
        id: None,
        memory_index: Num(0),
        offset: [Const(I32Const, "0")],
        data: bytes_of("fuzz"),
      }),
    )
  }

  // Optional export/start.
  if func_count > 0 {
    fields.push(ExportField({ name: "main", desc: ExportDesc::Func(Num(0)) }))
    if (st.next_uint() & 1) == 1 {
      fields.push(StartField({ func_index: Num(0) }))
    }
  }
  { id: None, fields }
}

///|
pub impl Arbitrary for ValueType with arbitrary(_, st) {
  pick_value_type(st)
}

///|
pub impl Arbitrary for Index with arbitrary(size, st) {
  if (st.next_uint() & 1) == 1 {
    Num(rand_bounded((size + 1).reinterpret_as_uint(), st))
  } else {
    let suffix = rand_ident(st, "id")
    Id("$\{suffix}")
  }
}

///|
pub impl Arbitrary for Limits with arbitrary(_, st) {
  let min = st.next_uint() % 5
  let max : UInt? = if (st.next_uint() & 1) == 1 {
    Some(min + st.next_uint() % 3)
  } else {
    None
  }
  { min, max }
}

///|
pub impl Arbitrary for FuncType with arbitrary(_, st) {
  gen_func_type(st)
}

///|
pub impl Arbitrary for TypeUse with arbitrary(size, st) {
  gen_type_use(st, (size + 1).reinterpret_as_uint())
}

///|
pub impl Arbitrary for InlineExport with arbitrary(_, st) {
  Export("ex_\{st.next_uint() % 32}")
}

///|
pub impl Arbitrary for TableType with arbitrary(_, st) {
  {
    limits: Arbitrary::arbitrary(2, st),
    elem_type: if (st.next_uint() & 1) == 1 {
      FuncRef
    } else {
      ExternRef
    },
  }
}

///|
pub impl Arbitrary for MemoryType with arbitrary(_, st) {
  MemoryType(Arbitrary::arbitrary(2, st))
}

///|
pub impl Arbitrary for GlobalType with arbitrary(_, st) {
  { val_type: pick_numeric_value_type(st), mutable_: (st.next_uint() & 1) == 1 }
}

///|
pub impl Arbitrary for Local with arbitrary(_, st) {
  {
    id: if (st.next_uint() & 1) == 1 {
      Some("$l\{st.next_uint() % 32}")
    } else {
      None
    },
    val_type: pick_numeric_value_type(st),
  }
}

///|
pub impl Arbitrary for ImportDesc with arbitrary(size, st) {
  match st.next_uint() % 4 {
    0 => Func(Arbitrary::arbitrary(size, st))
    1 => Table(Arbitrary::arbitrary(size, st))
    2 => Memory(Arbitrary::arbitrary(size, st))
    _ => Global(Arbitrary::arbitrary(size, st))
  }
}

///|
pub impl Arbitrary for Import with arbitrary(size, st) {
  {
    module_name: "env",
    field_name: "f\{st.next_uint() % 64}",
    desc: Arbitrary::arbitrary(size, st),
    id: if (st.next_uint() & 1) == 1 {
      Some("$imp\{st.next_uint() % 64}")
    } else {
      None
    },
  }
}

///|
pub impl Arbitrary for ExportDesc with arbitrary(size, st) {
  match st.next_uint() % 4 {
    0 => Func(rand_index(st, (size + 1).reinterpret_as_uint()))
    1 => Table(rand_index(st, 1))
    2 => Memory(rand_index(st, 1))
    _ => Global(rand_index(st, 1))
  }
}

///|
pub impl Arbitrary for Export with arbitrary(size, st) {
  { name: "ex\{st.next_uint() % 64}", desc: Arbitrary::arbitrary(size, st) }
}

///|
pub impl Arbitrary for Start with arbitrary(size, st) {
  { func_index: rand_index(st, (size + 1).reinterpret_as_uint()) }
}

///|
pub impl Arbitrary for MemArg with arbitrary(_, st) {
  gen_memarg(st, 4)
}

///|
pub impl Arbitrary for BlockType with arbitrary(size, st) {
  {
    label: if (st.next_uint() & 1) == 1 {
      Some("$b\{st.next_uint() % 32}")
    } else {
      None
    },
    type_use: if (st.next_uint() & 1) == 1 {
      Some(Arbitrary::arbitrary(size, st))
    } else {
      None
    },
  }
}

///|
pub impl Arbitrary for SimdShape with arbitrary(_, st) {
  match st.next_uint() % 6 {
    0 => I8x16
    1 => I16x8
    2 => I32x4
    3 => I64x2
    4 => F32x4
    _ => F64x2
  }
}

///|
pub impl Arbitrary for V128Const with arbitrary(_, st) {
  let shape : SimdShape = Arbitrary::arbitrary(0, st)
  let values : Array[String] = []
  let count = match shape {
    I8x16 => 16
    I16x8 => 8
    I32x4 => 4
    I64x2 => 2
    F32x4 => 4
    F64x2 => 2
  }
  for _ in 0..<count {
    values.push("\{(st.next_uint() % 32).reinterpret_as_int() - 16}")
  }
  { shape, values }
}

///|
pub impl Arbitrary for ShuffleLanes with arbitrary(_, st) {
  let lanes : FixedArray[UInt] = FixedArray::make(16, 0)
  for i = 0; i < 16; i = i + 1 {
    lanes[i] = st.next_uint() % 32
  }
  { lanes, }
}

///|
pub impl Arbitrary for Opcode with arbitrary(_, st) {
  match st.next_uint() % 8 {
    0 => pick_binary_opcode(st)
    1 => pick_unary_opcode(st)
    2 => pick_compare_opcode(st)
    3 => pick_convert_opcode(st)
    4 => I32Const
    5 => I64Const
    6 => F32Const
    _ => F64Const
  }
}

///|
pub impl Arbitrary for Instruction with arbitrary(size, st) {
  gen_instruction(size, st, (size + 2).reinterpret_as_uint())
}

///|
pub impl Arbitrary for Func with arbitrary(size, st) {
  let locals : Array[Local] = []
  let local_n = rand_len(size, st, 3)
  for _ in 0..<local_n {
    locals.push(Arbitrary::arbitrary(size, st))
  }
  let body : Array[Instruction] = []
  let body_n = rand_len(size + 1, st, 8)
  for _ in 0..<body_n {
    body.push(gen_instruction(size, st, 4))
  }
  {
    id: if (st.next_uint() & 1) == 1 {
      Some("$f\{st.next_uint() % 64}")
    } else {
      None
    },
    exports: [],
    type_use: gen_type_use(st, (size + 1).reinterpret_as_uint()),
    locals,
    body,
  }
}

///|
pub impl Arbitrary for Global with arbitrary(size, st) {
  {
    id: if (st.next_uint() & 1) == 1 {
      Some("$g\{st.next_uint() % 64}")
    } else {
      None
    },
    exports: [],
    global_type: Arbitrary::arbitrary(size, st),
    init: [Const(I32Const, "0")],
  }
}

///|
pub impl Arbitrary for Table with arbitrary(size, st) {
  {
    id: if (st.next_uint() & 1) == 1 {
      Some("$t\{st.next_uint() % 64}")
    } else {
      None
    },
    exports: [],
    table_type: Arbitrary::arbitrary(size, st),
    elem_init: None,
    elem_exprs: None,
    elem_init_type: None,
    elem_offset: None,
  }
}

///|
pub impl Arbitrary for Memory with arbitrary(size, st) {
  {
    id: if (st.next_uint() & 1) == 1 {
      Some("$m\{st.next_uint() % 64}")
    } else {
      None
    },
    exports: [],
    memory_type: Arbitrary::arbitrary(size, st),
  }
}

///|
pub impl Arbitrary for TypeDef with arbitrary(size, st) {
  {
    id: if (st.next_uint() & 1) == 1 {
      Some("$t\{st.next_uint() % 64}")
    } else {
      None
    },
    func_type: Arbitrary::arbitrary(size, st),
  }
}

///|
pub impl Arbitrary for DataSegment with arbitrary(size, _) {
  {
    id: None,
    memory_index: Num(0),
    offset: [Const(I32Const, "0")],
    data: bytes_of("data\{size}"),
  }
}

///|
pub impl Arbitrary for ElemSegment with arbitrary(size, st) {
  let funcs : Array[Index] = []
  let n = rand_len(size, st, 3)
  for _ in 0..<n {
    funcs.push(Num(st.next_uint() % 4))
  }
  {
    id: None,
    table_index: Num(0),
    offset: [Const(I32Const, "0")],
    func_indices: funcs,
    elem_exprs: [],
    elem_type: None,
  }
}

///|
pub impl Arbitrary for ModuleField with arbitrary(size, st) {
  match st.next_uint() % 10 {
    0 => TypeField(Arbitrary::arbitrary(size, st))
    1 => FuncField(Arbitrary::arbitrary(size, st))
    2 => TableField(Arbitrary::arbitrary(size, st))
    3 => MemoryField(Arbitrary::arbitrary(size, st))
    4 => GlobalField(Arbitrary::arbitrary(size, st))
    5 => ImportField(Arbitrary::arbitrary(size, st))
    6 => ExportField(Arbitrary::arbitrary(size, st))
    7 => StartField(Arbitrary::arbitrary(size, st))
    8 => ElemField(Arbitrary::arbitrary(size, st))
    _ => DataField(Arbitrary::arbitrary(size, st))
  }
}

///|
pub impl Arbitrary for Module with arbitrary(size, st) {
  gen_module(size, st)
}

///|
pub impl Arbitrary for WastValue with arbitrary(_, st) {
  match st.next_uint() % 6 {
    0 => I32("\{(st.next_uint() % 200).reinterpret_as_int() - 100}")
    1 => I64("\{(st.next_uint() % 200).reinterpret_as_int().to_int64() - 100L}")
    2 => F32("0.0")
    3 => F64("0.0")
    4 => RefNull(FuncRef)
    _ => RefFunc
  }
}

///|
pub impl Arbitrary for WastResult with arbitrary(size, st) {
  match st.next_uint() % 7 {
    0 => Value(Arbitrary::arbitrary(size, st))
    1 => F32NanCanonical
    2 => F32NanArithmetic
    3 => F64NanCanonical
    4 => F64NanArithmetic
    5 => RefNull(Some(FuncRef))
    _ => RefFunc
  }
}

///|
pub impl Arbitrary for WastAction with arbitrary(size, st) {
  let args : Array[WastValue] = []
  let n = rand_len(size, st, 4)
  for _ in 0..<n {
    args.push(Arbitrary::arbitrary(size, st))
  }
  {
    module_name: if (st.next_uint() & 1) == 1 {
      Some("$m")
    } else {
      None
    },
    name: "fn\{st.next_uint() % 32}",
    args,
  }
}

///|
pub impl Arbitrary for WastActionType with arbitrary(size, st) {
  if (st.next_uint() & 1) == 1 {
    Invoke(Arbitrary::arbitrary(size, st))
  } else {
    Get(None, "g\{st.next_uint() % 16}")
  }
}

///|
pub impl Arbitrary for WastModuleDef with arbitrary(size, st) {
  match st.next_uint() % 3 {
    0 => Inline(Arbitrary::arbitrary(size, st))
    1 => Binary(b"\x00asm")
    _ => Quote(["(module)"])
  }
}

///|
pub impl Arbitrary for WastCommand with arbitrary(size, st) {
  match st.next_uint() % 9 {
    0 => Module(Arbitrary::arbitrary(size, st))
    1 => Register("m\{st.next_uint() % 8}", None)
    2 => Action(Arbitrary::arbitrary(size, st))
    3 =>
      AssertReturn(Arbitrary::arbitrary(size, st), [
        Arbitrary::arbitrary(size, st),
      ])
    4 => AssertTrap(Arbitrary::arbitrary(size, st), "trap")
    5 => AssertException(Arbitrary::arbitrary(size, st))
    6 => AssertExhaustion(Arbitrary::arbitrary(size, st), "exhaust")
    7 => AssertMalformed(Arbitrary::arbitrary(size, st), "malformed")
    _ => AssertInvalid(Arbitrary::arbitrary(size, st), "invalid")
  }
}

///|
pub impl Arbitrary for WastScript with arbitrary(size, st) {
  let commands : Array[WastCommand] = []
  let n = rand_len(size, st, 6)
  for _ in 0..<n {
    commands.push(Arbitrary::arbitrary(size, st))
  }
  { commands, }
}
