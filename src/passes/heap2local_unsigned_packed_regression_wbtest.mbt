///|
fn h2l_unsigned_packed_unsigned(value : Int32, width : Int32) -> Int32 {
  let mask = if width == 8 { 255 } else { 65535 }
  value & mask
}

///|
fn h2l_unsigned_packed_signed(value : Int32, width : Int32) -> Int32 {
  let bits = h2l_unsigned_packed_unsigned(value, width)
  let sign = if width == 8 { 128 } else { 32768 }
  if bits >= sign {
    bits - 2 * sign
  } else {
    bits
  }
}

///|
fn h2l_unsigned_packed_fixture(width : Int32, family : Int32) -> @lib.Module {
  // family 0 is a struct epoch, 1 is an array epoch, 2 is a direct array tee.
  let type_ = @lib.TypeIdx::new(0U)
  let owner = @lib.LocalIdx::new(4U)
  fn read(index : Int32, unsigned : Bool) -> Array[@lib.Instruction] {
    if family == 0 {
      [
        @lib.Instruction::local_get(owner),
        if unsigned {
          @lib.Instruction::struct_get_u(type_, @lib.U32::new(index.to_uint()))
        } else {
          @lib.Instruction::struct_get_s(type_, @lib.U32::new(index.to_uint()))
        },
      ]
    } else {
      [
        @lib.Instruction::local_get(owner),
        @lib.Instruction::i32_const(@lib.I32(index)),
        if unsigned {
          @lib.Instruction::array_get_u(type_)
        } else {
          @lib.Instruction::array_get_s(type_)
        },
      ]
    }
  }
  let allocate = if family == 0 {
    @lib.Instruction::struct_new(type_)
  } else {
    @lib.Instruction::array_new_fixed(type_, @lib.U32::new(3U))
  }
  let body : Array[@lib.Instruction] = []
  if family != 2 {
    for lane in 0..<3 {
      body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(lane.to_uint())))
    }
    body.append([allocate, @lib.Instruction::local_set(owner)])
  }
  for lane in 0..<3 {
    let operand : Array[@lib.Instruction] = []
    if lane == 1 {
      operand.append([
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [@lib.Instruction::unreachable_()],
          None,
        ),
      ])
    }
    operand.push(@lib.Instruction::i32_const(@lib.I32(lane + 1)))
    operand.append(
      if family == 2 {
        [@lib.Instruction::local_get(@lib.LocalIdx::new(lane.to_uint()))]
      } else {
        read((lane + 1) % 3, lane != 1)
      },
    )
    operand.push(@lib.Instruction::call(@lib.FuncIdx::new(0U)))
    if lane == 1 {
      body.push(
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new(operand),
        ),
      )
    } else {
      body.append(operand)
    }
  }
  body.push(allocate)
  if family == 2 {
    body.append([
      @lib.Instruction::local_tee(owner),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::array_get_u(type_),
    ])
    body.append(read(0, false))
    for lane in 1..<3 {
      body.append(read(lane, true))
      body.append(read(lane, false))
    }
  } else {
    body.push(@lib.Instruction::local_set(owner))
    for lane in 0..<3 {
      body.append(read(lane, false))
      body.append(read(lane, true))
    }
  }
  let field = @lib.FieldType::new(
    @lib.StorageType::pack_type(
      if width == 8 {
        @lib.PackType::i8()
      } else {
        @lib.PackType::i16()
      },
    ),
    @lib.Mut::var_(),
  )
  let comp = if family == 0 {
    @lib.CompType::struct_([field, field, field])
  } else {
    @lib.CompType::array(field)
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(comp)),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func(
            Array::make(4, @lib.ValType::i32()),
            Array::make(6, @lib.ValType::i32()),
          ),
        ),
      ),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func(Array::make(2, @lib.ValType::i32()), [
            @lib.ValType::i32(),
          ]),
        ),
      ),
    ]),
  )
  .with_import_sec(
    @lib.ImportSec::new([
      @lib.Import::new(
        @lib.Name::from_string("env"),
        @lib.Name::from_string("mark"),
        @lib.ExternType::func(@lib.TypeIdx::new(2U)),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("run"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(1U)),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::single(
          1U,
          @lib.ValType::ref_type(
            @lib.RefType::new(true, @lib.HeapType::new(type_)),
          ),
        ),
        @lib.Expr::new(body),
      ),
    ]),
  )
}

///|
// Heap fields store low bits. Signed reads use arithmetic subtraction, while
// unsigned reads return the stored magnitude. Unknown opcodes fail this bounded
// model; an intentional constructor trap records the exact preceding imports.
fn h2l_unsigned_packed_observe(
  module_ : @lib.Module,
  args : Array[Int32],
  width : Int32,
) -> (Bool, Array[Int32], Array[(Int32, Int32)]) raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = module_.code_sec.unwrap().0[0]
  let locals = args.copy()
  for _ in 0..<body_locals.length() {
    locals.push(0)
  }
  let heap : Array[Array[Int32]] = [[]]
  let stack : Array[Int32] = []
  let events : Array[(Int32, Int32)] = []
  let mut steps = 0
  fn allocate() -> Unit {
    let fields = Array::make(3, 0)
    for lane = 2; lane >= 0; lane = lane - 1 {
      fields[lane] = h2l_unsigned_packed_unsigned(stack.pop().unwrap(), width)
    }
    heap.push(fields)
    stack.push(heap.length() - 1)
  }
  fn execute(instrs : Array[@lib.Instruction]) -> Bool raise {
    for instr in instrs {
      steps += 1
      assert_true(steps <= 512)
      match instr {
        @lib.Nop => ()
        @lib.I32Const(@lib.I32(value)) => stack.push(value)
        @lib.LocalGet(@lib.LocalIdx(index)) =>
          stack.push(locals[index.to_int()])
        @lib.LocalSet(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = stack.pop().unwrap()
        @lib.LocalTee(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = stack[stack.length() - 1]
        @lib.Drop => ignore(stack.pop().unwrap())
        @lib.StructNew(_) | @lib.ArrayNewFixed(_, @lib.U32(3U)) => allocate()
        @lib.StructGetS(_, @lib.U32(index))
        | @lib.StructGetU(_, @lib.U32(index)) => {
          let reference = stack.pop().unwrap()
          assert_true(reference > 0 && reference < heap.length())
          let value = heap[reference][index.to_int()]
          stack.push(
            if instr is @lib.StructGetU(_, _) {
              value
            } else {
              h2l_unsigned_packed_signed(value, width)
            },
          )
        }
        @lib.ArrayGetS(_) | @lib.ArrayGetU(_) => {
          let index = stack.pop().unwrap()
          let reference = stack.pop().unwrap()
          assert_true(reference > 0 && reference < heap.length())
          assert_true(index >= 0 && index < 3)
          let value = heap[reference][index]
          stack.push(
            if instr is @lib.ArrayGetU(_) {
              value
            } else {
              h2l_unsigned_packed_signed(value, width)
            },
          )
        }
        @lib.Call(@lib.FuncIdx(0U)) => {
          let value = stack.pop().unwrap()
          let id = stack.pop().unwrap()
          events.push((id, value))
          stack.push(value)
        }
        @lib.I32And => {
          let rhs = stack.pop().unwrap()
          stack.push(stack.pop().unwrap() & rhs)
        }
        @lib.I32Extend8S =>
          stack.push(h2l_unsigned_packed_signed(stack.pop().unwrap(), 8))
        @lib.I32Extend16S =>
          stack.push(h2l_unsigned_packed_signed(stack.pop().unwrap(), 16))
        @lib.Block(_, @lib.Expr(nested)) => if !execute(nested) { return false }
        @lib.If(_, yes, no) => {
          let condition = stack.pop().unwrap()
          if !execute(if condition != 0 { yes } else { no.or([]) }) {
            return false
          }
        }
        @lib.Unreachable => return false
        _ => fail("unexpected packed unsigned fixture opcode: \{instr}")
      }
    }
    true
  }
  let returned = execute(body)
  (returned, if returned { stack } else { [] }, events)
}

///|
fn h2l_unsigned_packed_count(
  instrs : Array[@lib.Instruction],
  predicate : (@lib.Instruction) -> Bool,
) -> Int32 {
  let mut count = 0
  for instr in instrs {
    if predicate(instr) {
      count += 1
    }
    match instr {
      @lib.Block(_, @lib.Expr(nested)) =>
        count += h2l_unsigned_packed_count(nested, predicate)
      @lib.If(_, yes, no) =>
        count += h2l_unsigned_packed_count(yes, predicate) +
          h2l_unsigned_packed_count(no.or([]), predicate)
      _ => ()
    }
  }
  count
}

///|
fn h2l_unsigned_packed_assert_scalarized(output : @lib.Module) -> Unit raise {
  assert_true(@validate.validate_module(output) is Ok(_))
  let bytes = @binary.encode_module(output).unwrap()
  let decoded = @binary.decode_module(bytes).unwrap()
  assert_true(@validate.validate_module(decoded) is Ok(_))
  let @lib.Func(_, @lib.Expr(body)) = decoded.code_sec.unwrap().0[0]
  @debug.assert_eq(
    h2l_unsigned_packed_count(body, fn(instr) {
      instr is @lib.StructNew(_) ||
      instr is @lib.StructGetS(_, _) ||
      instr is @lib.StructGetU(_, _) ||
      instr is @lib.ArrayNewFixed(_, _) ||
      instr is @lib.ArrayGetS(_) ||
      instr is @lib.ArrayGetU(_)
    }),
    0,
  )
  assert_true(
    h2l_unsigned_packed_count(body, fn(instr) { instr is @lib.I32And }) >= 3,
    msg="packed get_u reads must exercise scalar masks",
  )
  assert_true(
    h2l_unsigned_packed_count(body, fn(instr) {
      instr is @lib.I32Extend8S || instr is @lib.I32Extend16S
    }) >=
    3,
    msg="signed contrast reads must retain sign extension",
  )
}

///|
test "heap2local scalarized packed get_u masks preserve unsigned values and signed contrasts" {
  let values = [
    0, 1, -1, 127, 128, 255, 256, 32767, 32768, 65535, 65536, -32769, -2147483648,
    2147483647,
  ]
  for width in [8, 16] {
    for family in [0, 1, 2] {
      let input = h2l_unsigned_packed_fixture(width, family)
      assert_true(@validate.validate_module(input) is Ok(_))
      let @lib.Func(_, @lib.Expr(input_body)) = input.code_sec.unwrap().0[0]
      @debug.assert_eq(
        h2l_unsigned_packed_count(input_body, fn(instr) {
          instr is @lib.StructGetU(_, _) || instr is @lib.ArrayGetU(_)
        }),
        if family == 2 {
          3
        } else {
          5
        },
      )
      let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
        "heap2local",
      ]).unwrap()
      h2l_unsigned_packed_assert_scalarized(output)
      for index in 0..<values.length() {
        let a = values[index]
        let b = values[(index + 5) % values.length()]
        let c = values[(index + 9) % values.length()]
        let args = [a, b, c, 0]
        let expected = if family == 2 {
          (
            true,
            [
              h2l_unsigned_packed_unsigned(a, width),
              h2l_unsigned_packed_signed(a, width),
              h2l_unsigned_packed_unsigned(b, width),
              h2l_unsigned_packed_signed(b, width),
              h2l_unsigned_packed_unsigned(c, width),
              h2l_unsigned_packed_signed(c, width),
            ],
            [(1, a), (2, b), (3, c)],
          )
        } else {
          (
            true,
            [
              h2l_unsigned_packed_signed(b, width),
              h2l_unsigned_packed_unsigned(b, width),
              h2l_unsigned_packed_signed(c, width),
              h2l_unsigned_packed_unsigned(c, width),
              h2l_unsigned_packed_signed(a, width),
              h2l_unsigned_packed_unsigned(a, width),
            ],
            [
              (1, h2l_unsigned_packed_unsigned(b, width)),
              (2, h2l_unsigned_packed_signed(c, width)),
              (3, h2l_unsigned_packed_unsigned(a, width)),
            ],
          )
        }
        @debug.assert_eq(
          h2l_unsigned_packed_observe(input, args, width),
          expected,
        )
        @debug.assert_eq(
          h2l_unsigned_packed_observe(output, args, width),
          expected,
        )
      }
    }
  }
}

///|
test "heap2local scalarized unsigned packed constructors preserve the intentional trap frontier" {
  // The fail parameter deliberately traps in operand two. The first unsigned
  // read/import completes; later operand imports and owner publication do not.
  for width in [8, 16] {
    for family in [0, 1, 2] {
      let input = h2l_unsigned_packed_fixture(width, family)
      let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
        "heap2local",
      ]).unwrap()
      h2l_unsigned_packed_assert_scalarized(output)
      for
        values in [
          [0, 128, 65535],
          [-1, 32768, 2147483647],
          [-2147483648, 255, -32769],
        ] {
        let args = [values[0], values[1], values[2], 1]
        let expected = (
          false,
          [],
          [
            (
              1,
              if family == 2 {
                values[0]
              } else {
                h2l_unsigned_packed_unsigned(values[1], width)
              },
            ),
          ],
        )
        @debug.assert_eq(
          h2l_unsigned_packed_observe(input, args, width),
          expected,
        )
        @debug.assert_eq(
          h2l_unsigned_packed_observe(output, args, width),
          expected,
        )
      }
    }
  }
}
