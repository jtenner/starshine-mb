///|
fn h2l_straight_array_pack(value : Int32, width : Int32) -> Int32 {
  match width {
    8 => value << 24 >> 24
    16 => value << 16 >> 16
    _ => value
  }
}

///|
fn h2l_straight_array_fixture(
  width : Int32,
  shape : Int32,
  effects~ : Bool = false,
  invalid_index~ : Bool = false,
) -> @lib.Module {
  let array_type = @lib.TypeIdx::new(0U)
  let owner = @lib.LocalIdx::new(3U)
  let get = if width == 32 {
    @lib.Instruction::array_get(array_type)
  } else {
    @lib.Instruction::array_get_s(array_type)
  }
  fn read(index : Int32) -> Array[@lib.Instruction] {
    [
      @lib.Instruction::local_get(owner),
      @lib.Instruction::i32_const(@lib.I32(index)),
      get,
    ]
  }
  let body = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::array_new_fixed(array_type, @lib.U32::new(3U)),
    @lib.Instruction::local_set(owner),
  ]
  for lane in 0..<3 {
    if effects {
      body.push(@lib.Instruction::i32_const(@lib.I32(lane + 1)))
    }
    body.append(
      if invalid_index && lane == 1 {
        read(-1)
      } else if shape == 0 && lane == 0 {
        [@lib.Instruction::i32_const(@lib.I32(100))]
      } else {
        read(
          match shape {
            0 => lane - 1
            1 => if lane == 2 { 2 } else { 1 - lane }
            _ => (lane + 1) % 3
          },
        )
      },
    )
    if effects {
      body.push(@lib.Instruction::call(@lib.FuncIdx::new(0U)))
    }
  }
  body.append([
    @lib.Instruction::array_new_fixed(array_type, @lib.U32::new(3U)),
    @lib.Instruction::local_set(owner),
  ])
  for lane in 0..<3 {
    body.append(read(lane))
  }
  let storage = match width {
    8 => @lib.StorageType::pack_type(@lib.PackType::i8())
    16 => @lib.StorageType::pack_type(@lib.PackType::i16())
    _ => @lib.StorageType::val_type(@lib.ValType::i32())
  }
  let types = [
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::array(@lib.FieldType::new(storage, @lib.Mut::var_())),
      ),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func(
          [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
          [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
        ),
      ),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
          @lib.ValType::i32(),
        ]),
      ),
    ),
  ]
  let module_ = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new(types))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("run"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(if effects { 1U } else { 0U })),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(
            1U,
            @lib.ValType::ref_type(
              @lib.RefType::new(true, @lib.HeapType::new(array_type)),
            ),
          ),
          @lib.Expr::new(body),
        ),
      ]),
    )
  if effects {
    module_.with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("mark"),
          @lib.ExternType::func(@lib.TypeIdx::new(2U)),
        ),
      ]),
    )
  } else {
    module_
  }
}

///|
// Every fixture operation is executed once, with a fixed budget. The result
// records a real bounds trap and import events rather than treating them as
// successful execution. Unknown instructions fail the regression.
fn h2l_straight_array_observe(
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
        @lib.ArrayNewFixed(_, @lib.U32(length)) => {
          let values = Array::make(length.to_int(), 0)
          for index = length.to_int() - 1; index >= 0; index = index - 1 {
            values[index] = h2l_straight_array_pack(stack.pop().unwrap(), width)
          }
          heap.push(values)
          stack.push(heap.length() - 1)
        }
        @lib.ArrayGet(_) | @lib.ArrayGetS(_) | @lib.ArrayGetU(_) => {
          let index = stack.pop().unwrap()
          let reference = stack.pop().unwrap()
          if reference <= 0 || reference >= heap.length() {
            return false
          }
          let values = heap[reference]
          if index < 0 || index >= values.length() {
            return false
          }
          let value = values[index]
          stack.push(
            match instr {
              @lib.ArrayGetU(_) if width == 8 => value & 255
              @lib.ArrayGetU(_) if width == 16 => value & 65535
              _ => value
            },
          )
        }
        @lib.ArraySet(_) => {
          let value = stack.pop().unwrap()
          let index = stack.pop().unwrap()
          let reference = stack.pop().unwrap()
          if reference <= 0 || reference >= heap.length() {
            return false
          }
          let values = heap[reference]
          if index < 0 || index >= values.length() {
            return false
          }
          values[index] = h2l_straight_array_pack(value, width)
        }
        @lib.Call(@lib.FuncIdx(0U)) => {
          let value = stack.pop().unwrap()
          let id = stack.pop().unwrap()
          events.push((id, value))
          stack.push(value)
        }
        @lib.I32Extend8S =>
          stack.push(h2l_straight_array_pack(stack.pop().unwrap(), 8))
        @lib.I32Extend16S =>
          stack.push(h2l_straight_array_pack(stack.pop().unwrap(), 16))
        @lib.I32And => {
          let rhs = stack.pop().unwrap()
          stack.push(stack.pop().unwrap() & rhs)
        }
        @lib.Block(_, @lib.Expr(nested)) => if !execute(nested) { return false }
        @lib.Unreachable => return false
        _ => fail("unexpected array owner fixture instruction: \{instr}")
      }
    }
    true
  }
  let returned = execute(body)
  (returned, if returned { stack } else { [] }, events)
}

///|
fn h2l_straight_array_heap_ops(instrs : Array[@lib.Instruction]) -> Int32 {
  let mut count = 0
  for instr in instrs {
    match instr {
      @lib.ArrayNewFixed(_, _)
      | @lib.ArrayNew(_)
      | @lib.ArrayNewDefault(_)
      | @lib.ArrayGet(_)
      | @lib.ArrayGetS(_)
      | @lib.ArrayGetU(_)
      | @lib.ArraySet(_) => count += 1
      @lib.Block(_, @lib.Expr(nested)) =>
        count += h2l_straight_array_heap_ops(nested)
      @lib.If(_, yes, no) =>
        count += h2l_straight_array_heap_ops(yes) +
          h2l_straight_array_heap_ops(no.or([]))
      _ => ()
    }
  }
  count
}

///|
fn h2l_straight_array_tee_fixture(
  width : Int32,
  index : Int32,
  is_set~ : Bool = false,
) -> @lib.Module {
  let module_ = h2l_straight_array_fixture(width, 0, effects=true)
  let @lib.Func(locals, _) = module_.code_sec.unwrap().0[0]
  let array_type = @lib.TypeIdx::new(0U)
  let owner = @lib.LocalIdx::new(3U)
  let get = if width == 32 {
    @lib.Instruction::array_get(array_type)
  } else {
    @lib.Instruction::array_get_s(array_type)
  }
  let body : Array[@lib.Instruction] = []
  for lane in 0..<3 {
    body.append([
      @lib.Instruction::i32_const(@lib.I32(lane + 1)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(lane.to_uint())),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    ])
  }
  body.append([
    @lib.Instruction::array_new_fixed(array_type, @lib.U32::new(3U)),
    @lib.Instruction::local_tee(owner),
    @lib.Instruction::i32_const(@lib.I32(index)),
  ])
  if is_set {
    body.append([
      @lib.Instruction::i32_const(@lib.I32(4)),
      @lib.Instruction::i32_const(@lib.I32(100)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::array_set(array_type),
    ])
  } else {
    body.push(get)
  }
  for lane in (if is_set { 0 } else { 1 })..<3 {
    body.append([
      @lib.Instruction::local_get(owner),
      @lib.Instruction::i32_const(@lib.I32(lane)),
      get,
    ])
  }
  module_.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]),
  )
}

///|
test "heap2local straight-line fixed array replacements preserve old elements and remove heap operations" {
  for width in [32, 8, 16] {
    for shape in [0, 1, 2] {
      let input = h2l_straight_array_fixture(width, shape)
      assert_true(@validate.validate_module(input) is Ok(_))
      let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
        "heap2local",
      ]).unwrap()
      assert_true(@validate.validate_module(output) is Ok(_))
      for
        args in [
          [10, 20, 30],
          [-129, 32768, 65535],
          [-2147483648, 2147483647, -1],
        ] {
        let a = h2l_straight_array_pack(args[0], width)
        let b = h2l_straight_array_pack(args[1], width)
        let c = h2l_straight_array_pack(args[2], width)
        let expected = (
          true,
          match shape {
            0 => [100, a, b]
            1 => [b, a, c]
            _ => [b, c, a]
          },
          [],
        )
        @debug.assert_eq(
          h2l_straight_array_observe(input, args, width),
          expected,
        )
        @debug.assert_eq(
          h2l_straight_array_observe(output, args, width),
          expected,
        )
      }
      let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
      @debug.assert_eq(h2l_straight_array_heap_ops(body), 0)
    }
  }
}

///|
test "heap2local straight-line fixed arrays retain constructor import order" {
  for width in [32, 8, 16] {
    let input = h2l_straight_array_fixture(width, 0, effects=true)
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
      "heap2local",
    ]).unwrap()
    assert_true(@validate.validate_module(output) is Ok(_))
    let args = [-129, 65535, 32768]
    let a = h2l_straight_array_pack(args[0], width)
    let b = h2l_straight_array_pack(args[1], width)
    let expected = (true, [100, a, b], [(1, 100), (2, a), (3, b)])
    @debug.assert_eq(h2l_straight_array_observe(input, args, width), expected)
    @debug.assert_eq(h2l_straight_array_observe(output, args, width), expected)
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    @debug.assert_eq(h2l_straight_array_heap_ops(body), 0)
  }
}

///|
test "heap2local intentionally trapping negative fixed-array index preserves earlier import effects" {
  // The module is valid. Reading index -1 from a length-three array must trap;
  // the first constructor operand executes before that intentional bounds trap.
  for width in [32, 8, 16] {
    let input = h2l_straight_array_fixture(
      width,
      0,
      effects=true,
      invalid_index=true,
    )
    assert_true(@validate.validate_module(input) is Ok(_))
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
      "heap2local",
    ]).unwrap()
    assert_true(@validate.validate_module(output) is Ok(_))
    let expected = (false, [], [(1, 100)])
    @debug.assert_eq(
      h2l_straight_array_observe(input, [10, 20, 30], width),
      expected,
    )
    @debug.assert_eq(
      h2l_straight_array_observe(output, [10, 20, 30], width),
      expected,
    )
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    @debug.assert_eq(h2l_straight_array_heap_ops(body), 0)
  }
}

///|
test "heap2local direct fixed-array tee reads preserve allocation effects" {
  for width in [32, 8, 16] {
    let input = h2l_straight_array_tee_fixture(width, 0)
    assert_true(@validate.validate_module(input) is Ok(_))
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
      "heap2local",
    ]).unwrap()
    assert_true(@validate.validate_module(output) is Ok(_))
    let args = [-129, 65535, 32768]
    let expected = (
      true,
      args.map(fn(value) { h2l_straight_array_pack(value, width) }),
      [(1, args[0]), (2, args[1]), (3, args[2])],
    )
    @debug.assert_eq(h2l_straight_array_observe(input, args, width), expected)
    @debug.assert_eq(h2l_straight_array_observe(output, args, width), expected)
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    @debug.assert_eq(h2l_straight_array_heap_ops(body), 0)
  }
}

///|
test "heap2local intentionally trapping fixed-array tee reads preserve all allocation effects" {
  // Both -1 and length 3 are intentionally out of bounds. Array construction
  // completes first, so all three import events must precede the bounds trap.
  for width in [32, 8, 16] {
    for index in [-1, 3] {
      let input = h2l_straight_array_tee_fixture(width, index)
      assert_true(@validate.validate_module(input) is Ok(_))
      let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
        "heap2local",
      ]).unwrap()
      assert_true(@validate.validate_module(output) is Ok(_))
      let args = [7, 9, -129]
      let expected = (false, [], [(1, 7), (2, 9), (3, -129)])
      @debug.assert_eq(h2l_straight_array_observe(input, args, width), expected)
      @debug.assert_eq(
        h2l_straight_array_observe(output, args, width),
        expected,
      )
      let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
      @debug.assert_eq(h2l_straight_array_heap_ops(body), 0)
    }
  }
}

///|
test "heap2local fixed-array tee stores preserve value effects and intentional bounds traps" {
  // A valid store and both bounds directions evaluate the stored value after
  // all constructor operands. The fourth import must occur even when it traps.
  for width in [32, 8, 16] {
    for index in [0, -1, 3] {
      let input = h2l_straight_array_tee_fixture(width, index, is_set=true)
      assert_true(@validate.validate_module(input) is Ok(_))
      let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
        "heap2local",
      ]).unwrap()
      assert_true(@validate.validate_module(output) is Ok(_))
      let args = [-129, 65535, 32768]
      let expected = (
        index == 0,
        if index == 0 {
          [
            100,
            h2l_straight_array_pack(args[1], width),
            h2l_straight_array_pack(args[2], width),
          ]
        } else {
          []
        },
        [(1, args[0]), (2, args[1]), (3, args[2]), (4, 100)],
      )
      @debug.assert_eq(h2l_straight_array_observe(input, args, width), expected)
      @debug.assert_eq(
        h2l_straight_array_observe(output, args, width),
        expected,
      )
      let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
      @debug.assert_eq(h2l_straight_array_heap_ops(body), 0)
    }
  }
}
