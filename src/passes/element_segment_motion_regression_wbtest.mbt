///|
priv enum ElementMotionValue {
  Number(Int32)
  ArrayRef(Array[Bool])
  NullRef
}

///|
fn element_motion_number(value : ElementMotionValue) -> Int32 raise {
  match value {
    Number(value) => value
    _ => fail("expected an element-motion integer")
  }
}

///|
// Execute the small fixture instruction set independently of the effect masks.
// Segment drop is observable through subsequent source bounds checks, including
// zero-length operations. ArrayRef keeps aliases through local.get/local.tee.
fn element_motion_execute(func : @lib.Func) -> (Int32?, Array[String]) raise {
  let @lib.Func(local_types, @lib.Expr(body)) = func
  let locals = Array::make(local_types.length(), NullRef)
  let stack : Array[ElementMotionValue] = []
  let events : Array[String] = []
  let mut segment_length = 1
  let mut trapped = false
  fn execute(instrs : Array[@lib.Instruction]) -> Unit raise {
    for instr in instrs {
      if trapped {
        return
      }
      match instr {
        @lib.Nop => ()
        @lib.I32Const(@lib.I32(value)) => stack.push(Number(value))
        @lib.RefNull(_) => stack.push(NullRef)
        @lib.LocalGet(@lib.LocalIdx(index)) =>
          stack.push(locals[index.to_int()])
        @lib.LocalSet(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = stack.pop().unwrap()
        @lib.LocalTee(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = stack[stack.length() - 1]
        @lib.Drop => ignore(stack.pop().unwrap())
        @lib.Block(_, @lib.Expr(nested)) => execute(nested)
        @lib.If(_, then_body, else_body) => {
          let condition = element_motion_number(stack.pop().unwrap())
          execute(if condition != 0 { then_body } else { else_body.or([]) })
        }
        @lib.ElemDrop(@lib.ElemIdx(0U)) => {
          segment_length = 0
          events.push("drop")
        }
        @lib.ArrayNewDefault(_) => {
          let length = element_motion_number(stack.pop().unwrap())
          assert_true(length >= 0 && length <= 2)
          stack.push(ArrayRef(Array::make(length, true)))
        }
        @lib.ArrayNewElem(_, @lib.ElemIdx(0U)) => {
          let length = element_motion_number(stack.pop().unwrap())
          let offset = element_motion_number(stack.pop().unwrap())
          events.push("new")
          if offset < 0 ||
            length < 0 ||
            offset > segment_length ||
            length > segment_length - offset {
            trapped = true
          } else {
            stack.push(ArrayRef(Array::make(length, true)))
          }
        }
        @lib.ArrayInitElem(_, @lib.ElemIdx(0U)) => {
          let length = element_motion_number(stack.pop().unwrap())
          let source = element_motion_number(stack.pop().unwrap())
          let target = element_motion_number(stack.pop().unwrap())
          let array = stack.pop().unwrap()
          events.push("init")
          match array {
            ArrayRef(values) =>
              if source < 0 ||
                target < 0 ||
                length < 0 ||
                source > segment_length ||
                length > segment_length - source ||
                target > values.length() ||
                length > values.length() - target {
                trapped = true
              } else {
                for index in 0..<length {
                  values[target + index] = true
                }
              }
            NullRef => trapped = true
            _ => fail("expected an element-motion array")
          }
        }
        @lib.ArrayLen =>
          match stack.pop().unwrap() {
            ArrayRef(values) => stack.push(Number(values.length()))
            NullRef => trapped = true
            _ => fail("expected an element-motion array length")
          }
        @lib.ArrayGet(_) => {
          let index = element_motion_number(stack.pop().unwrap())
          match stack.pop().unwrap() {
            ArrayRef(values) =>
              if index < 0 || index >= values.length() {
                trapped = true
              } else {
                assert_true(values[index])
                stack.push(NullRef)
              }
            NullRef => trapped = true
            _ => fail("expected an element-motion array read")
          }
        }
        @lib.RefIsNull =>
          match stack.pop().unwrap() {
            NullRef => stack.push(Number(1))
            ArrayRef(_) => stack.push(Number(0))
            _ => fail("expected an element-motion reference")
          }
        _ => fail("unsupported element-motion instruction: \{instr}")
      }
    }
  }
  execute(body)
  let result = if trapped {
    None
  } else {
    assert_eq(stack.length(), 1)
    Some(element_motion_number(stack[0]))
  }
  (result, events)
}

///|
fn element_motion_const(value : Int32) -> @lib.Instruction {
  @lib.Instruction::i32_const(@lib.I32(value))
}

///|
fn element_motion_drop() -> @lib.Instruction {
  @lib.Instruction::elem_drop(@lib.ElemIdx::new(0U))
}

///|
fn element_motion_new(
  offset : Int32,
  length : Int32,
) -> Array[@lib.Instruction] {
  [
    element_motion_const(offset),
    element_motion_const(length),
    @lib.Instruction::array_new_elem(
      @lib.TypeIdx::new(0U),
      @lib.ElemIdx::new(0U),
    ),
  ]
}

///|
fn element_motion_default() -> Array[@lib.Instruction] {
  [
    element_motion_const(1),
    @lib.Instruction::array_new_default(@lib.TypeIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  ]
}

///|
fn element_motion_init(
  target : Int32,
  source : Int32,
  length : Int32,
) -> Array[@lib.Instruction] {
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    element_motion_const(target),
    element_motion_const(source),
    element_motion_const(length),
    @lib.Instruction::array_init_elem(
      @lib.TypeIdx::new(0U),
      @lib.ElemIdx::new(0U),
    ),
  ]
}

///|
fn element_motion_finish(
  body : Array[@lib.Instruction],
  drop~ : Bool = true,
) -> Unit {
  if drop {
    body.push(element_motion_drop())
  }
  body.append([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::array_len(),
  ])
}

///|
fn element_motion_assert_pipeline(
  body : Array[@lib.Instruction],
  expected : (Int32?, Array[String]),
) -> Unit raise {
  let array_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::array(
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::externref()),
                @lib.Mut::var_(),
              ),
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::passive(),
          @lib.ElemKind::typed_exprs(
            @lib.RefType::abs(@lib.AbsHeapType::extern_()),
            [
              @lib.Expr::new([
                @lib.Instruction::ref_null(
                  @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
                ),
              ]),
            ],
          ),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::single(1U, array_ref), @lib.Expr::new(body)),
      ]),
    )
  ignore(@validate.validate_module(input).unwrap())
  assert_eq(element_motion_execute(input.code_sec.unwrap().0[0]), expected)
  for
    pipeline in [
      ["simplify-locals"],
      ["code-pushing"],
      ["merge-blocks"],
      ["local-cse"],
      ["heap-store-optimization"],
      ["optimize-instructions"],
      ["simplify-locals", "merge-blocks", "local-cse", "code-pushing"],
    ] {
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), pipeline).unwrap()
    ignore(@validate.validate_module(output).unwrap())
    assert_eq(
      element_motion_execute(output.code_sec.unwrap().0[0]),
      expected,
      msg="\{pipeline}",
    )
  }
}

///|
test "element motion consumers preserve array new before and after elem drop" {
  for offset in [0, 1] {
    let body = element_motion_new(offset, 1)
    body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
    element_motion_finish(body)
    element_motion_assert_pipeline(
      body,
      if offset == 0 {
        (Some(1), ["new", "drop"])
      } else {
        (None, ["new"])
      },
    )
  }
  let body = [element_motion_drop()]
  body.append(element_motion_new(0, 1))
  body.push(@lib.Instruction::array_len())
  element_motion_assert_pipeline(body, (None, ["drop", "new"]))
}

///|
test "element motion consumers preserve array init before and after elem drop" {
  for drop_first in [false, true] {
    let body = element_motion_default()
    if drop_first {
      body.push(element_motion_drop())
    }
    body.append(element_motion_init(0, 0, 1))
    element_motion_finish(body, drop=!drop_first)
    element_motion_assert_pipeline(
      body,
      if drop_first {
        (None, ["drop", "init"])
      } else {
        (Some(1), ["init", "drop"])
      },
    )
  }
}

///|
test "merge blocks keeps an element drop prefix after an earlier array allocation operand" {
  // The second operand's block prefix must not cross the first operand's
  // array.new_elem. This reaches the shared merge-blocks effect motion check.
  for offset in [0, 1] {
    let body = element_motion_new(offset, 1)
    body.append([
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([element_motion_drop(), element_motion_const(0)]),
      ),
      @lib.Instruction::array_get(@lib.TypeIdx::new(0U)),
      @lib.Instruction::ref_is_null(),
    ])
    element_motion_assert_pipeline(
      body,
      if offset == 0 {
        (Some(1), ["new", "drop"])
      } else {
        (None, ["new"])
      },
    )
  }
}

///|
test "element motion consumers preserve empty source and destination bounds" {
  for offset in [0, 1, -1] {
    let body = [element_motion_drop()]
    body.append(element_motion_new(offset, 0))
    body.push(@lib.Instruction::array_len())
    element_motion_assert_pipeline(
      body,
      (if offset == 0 { Some(0) } else { None }, ["drop", "new"]),
    )
  }
  for source in [0, 1, -1] {
    for target in [0, 1, 2, -1] {
      let body = element_motion_default()
      body.push(element_motion_drop())
      body.append(element_motion_init(target, source, 0))
      element_motion_finish(body, drop=false)
      element_motion_assert_pipeline(
        body,
        (
          if source == 0 && target >= 0 && target <= 1 {
            Some(1)
          } else {
            None
          },
          ["drop", "init"],
        ),
      )
    }
  }
  let body = [
    element_motion_drop(),
    @lib.Instruction::ref_null(@lib.HeapType::new(@lib.TypeIdx::new(0U))),
    element_motion_const(0),
    element_motion_const(0),
    element_motion_const(0),
    @lib.Instruction::array_init_elem(
      @lib.TypeIdx::new(0U),
      @lib.ElemIdx::new(0U),
    ),
    element_motion_const(7),
  ]
  element_motion_assert_pipeline(body, (None, ["drop", "init"]))
}

///|
test "element motion consumers preserve live segment source and array target bounds" {
  for length in [0, 1, 2, -1] {
    let body = element_motion_new(0, length)
    body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
    element_motion_finish(body)
    element_motion_assert_pipeline(
      body,
      if length >= 0 && length <= 1 {
        (Some(length), ["new", "drop"])
      } else {
        (None, ["new"])
      },
    )
  }
  for source in [0, 1] {
    for target in [0, 1] {
      let body = element_motion_default()
      body.append(element_motion_init(target, source, 1))
      element_motion_finish(body)
      element_motion_assert_pipeline(
        body,
        if source == 0 && target == 0 {
          (Some(1), ["init", "drop"])
        } else {
          (None, ["init"])
        },
      )
    }
  }
  let body = element_motion_default()
  body.append(element_motion_init(1, 1, 0))
  element_motion_finish(body)
  element_motion_assert_pipeline(body, (Some(1), ["init", "drop"]))
}
