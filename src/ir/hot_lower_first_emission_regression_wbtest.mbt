///|
fn lower_first_emission_observe(
  body : Array[Instruction],
  local_count : Int32,
  fuel_limit~ : Int32 = 512,
) -> (Array[Int32], Array[Int32]) raise {
  let values : Array[Int32] = []
  let events : Array[Int32] = []
  let locals = Array::make(local_count, 0)
  let mut fuel = fuel_limit
  fn execute(items : Array[Instruction]) -> Unit raise {
    for instr in items {
      fuel -= 1
      assert_true(fuel > 0)
      match instr {
        Instruction::I32Const(@lib.I32(value)) => values.push(value)
        Instruction::Call(@lib.FuncIdx(index)) => {
          assert_eq(index, 0U)
          let argument = values.pop().unwrap()
          events.push(argument)
          values.push(2 * argument)
        }
        Instruction::LocalSet(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = values.pop().unwrap()
        Instruction::LocalGet(@lib.LocalIdx(index)) =>
          values.push(locals[index.to_int()])
        Instruction::Drop => ignore(values.pop().unwrap())
        Instruction::I32Add => {
          let rhs = values.pop().unwrap()
          let lhs = values.pop().unwrap()
          values.push(lhs + rhs)
        }
        Instruction::Block(_, @lib.Expr(nested)) => execute(nested)
        Instruction::Nop => ()
        _ => fail("unsupported first-emission fixture: \{instr}")
      }
    }
  }
  execute(body)
  (values, events)
}

///|
test "lower distinct scalar calls avoid futile reuse work and retain each value and effect" {
  for width in [8, 16] {
    let mut text = "(module (import \"env\" \"mark\" (func (param i32) (result i32))) (func (result "
    for _ in 0..<width {
      text += "i32 "
    }
    text += ") "
    for lane in 0..<width {
      text += "i32.const " + lane.to_string() + " call 0 "
    }
    text += "))"
    let input = @wast.wast_to_binary_module(text).unwrap()
    ignore(@validate.validate_module(input).unwrap())
    let func = hot_lift_func(input, @lib.FuncIdx::new(1U))
    let revision = hot_revision_current(func)
    assert_eq(func.roots.length(), width)
    let counts = hot_node_use_counts_build(func)
    let frames = hot_lower_impl_new_label_frames(func)
    let stack : Array[HotLowerStackValue] = []
    let out : Array[Instruction] = []
    let locals : Array[ValType] = []
    for root in func.roots {
      hot_lower_impl_emit_root(
        func,
        root,
        counts,
        frames,
        -1,
        stack,
        out,
        locals,
        HotLowerOptions::new(),
      )
    }
    let @lib.Func(_, @lib.Expr(original)) = input.code_sec.unwrap().0[0]
    assert_eq(out, original)
    assert_eq(locals, [])
    let arguments = Array::makei(width, fn(lane) { lane })
    assert_eq(
      lower_first_emission_observe(out, 0),
      (arguments.map(fn(x) { 2 * x }), arguments),
    )
    ignore(
      @validate.validate_module(
        input.with_code_sec(
          @lib.CodeSec::new([
            @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(out)),
          ]),
        ),
      ).unwrap(),
    )
    assert_eq(hot_revision_current(func), revision)
    assert_true(
      frames.node_effects is None,
      msg="first emissions cannot reuse an existing value; avoid whole-arena masks and failed stack scans",
    )
  }
}

///|
test "lower first-emission admission retains buried calls and in-flight control values" {
  for
    early in [
      "i32.const 11 call 0 ", "block (result i32) i32.const 11 call 0 i32.const 12 call 0 i32.const 13 call 0 i32.add i32.add end ",
    ] {
    let input = @wast.wast_to_binary_module(
      "(module (import \"env\" \"mark\" (func (param i32) (result i32))) " +
      "(func (result i32 i32) i32.const 7 " +
      early +
      "))",
    ).unwrap()
    ignore(@validate.validate_module(input).unwrap())
    let func = hot_lift_func(input, @lib.FuncIdx::new(1U))
    assert_eq(func.roots.length(), 2)
    let counts = hot_node_use_counts_build(func)
    let frames = hot_lower_impl_new_label_frames(func)
    let stack : Array[HotLowerStackValue] = []
    let out : Array[Instruction] = []
    let locals : Array[ValType] = []
    // A dependency may be emitted before its sole actual graph use. Reusing
    // it later must move the old value, even when the graph use count is one.
    let value = func.roots[1]
    for root in [value, func.roots[0], value] {
      hot_lower_impl_emit_root(
        func,
        root,
        counts,
        frames,
        -1,
        stack,
        out,
        locals,
        HotLowerOptions::new(),
      )
    }
    let expected = if early.starts_with("block") {
      ([7, 72], [11, 12, 13])
    } else {
      ([7, 22], [11])
    }
    assert_eq(lower_first_emission_observe(out, locals.length()), expected)
    assert_eq(stack.length(), 2)
    assert_eq(stack[1].node_id, value)
    let output = input.with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::from_types(locals), @lib.Expr::new(out)),
      ]),
    )
    ignore(@validate.validate_module(output).unwrap())
  }
}

///|
test "lower first-emission state includes suspended outer stack values" {
  let func = HotFunc::new()
  let scalar = @lib.ValType::i32()
  let early = hot_build_call(func, 0, [scalar], [
    hot_build_const_i32(func, @lib.I32(11)),
  ])
  let nested_calls = Array::makei(3, fn(lane) {
    hot_build_call(func, 0, [scalar], [
      hot_build_const_i32(func, @lib.I32(14 + lane)),
    ])
  })
  let body = nested_calls.copy()
  for lane in [2, 1, 0] {
    body.push(hot_build_drop(func, nested_calls[lane]))
  }
  let nested = hot_build_block(func, @lib.BlockType::void_(), body)
  let later = hot_build_const_i32(func, @lib.I32(7))
  for root in [early, nested, later] {
    hot_root_append(func, root)
  }
  let counts = hot_node_use_counts_build(func)
  let frames = hot_lower_impl_new_label_frames(func)
  let stack : Array[HotLowerStackValue] = []
  let out : Array[Instruction] = []
  let locals : Array[ValType] = []
  // The first deep lookup occurs on another stack. It must not hide the
  // already emitted outer value when that value is requested again.
  for root in [early, nested, later, early] {
    hot_lower_impl_emit_root(
      func,
      root,
      counts,
      frames,
      -1,
      stack,
      out,
      locals,
      HotLowerOptions::new(),
    )
  }
  assert_eq(
    lower_first_emission_observe(out, locals.length()),
    ([7, 22], [11, 14, 15, 16]),
  )
  assert_eq(stack.length(), 2)
  assert_eq(stack[1].node_id, early)
}

///|
test "lower first-emission state includes synthesized control prefix values" {
  let input = @wast.wast_to_binary_module(
    "(module (import \"env\" \"mark\" (func (param i32) (result i32))) " +
    "(func (result i32 i32) i32.const 7 i32.const 11 call 0))",
  ).unwrap()
  let func = hot_lift_func(input, @lib.FuncIdx::new(1U))
  let value = func.roots[1]
  let later = func.roots[0]
  let prefix = hot_build_block(func, @lib.BlockType::void_(), [value, later])
  let nop = hot_build_nop(func)
  let counts = hot_node_use_counts_build(func)
  let frames = hot_lower_impl_new_label_frames(func)
  let stack : Array[HotLowerStackValue] = []
  // Entry values already exist in the enclosing output. Their synthesized
  // stack entries do not necessarily pass through emit_root themselves.
  let out = [
    Instruction::i32_const(11),
    Instruction::call(@lib.FuncIdx::new(0U)),
    Instruction::i32_const(7),
  ]
  let locals : Array[ValType] = []
  hot_lower_impl_emit_root(
    func,
    nop,
    counts,
    frames,
    -1,
    stack,
    out,
    locals,
    HotLowerOptions::new(),
  )
  hot_lower_impl_push_control_prefix(func, prefix, 2, stack, frames)
  hot_lower_impl_emit_root(
    func,
    value,
    counts,
    frames,
    -1,
    stack,
    out,
    locals,
    HotLowerOptions::new(),
  )
  assert_eq(lower_first_emission_observe(out, locals.length()), ([7, 22], [11]))
  let output = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::from_types(locals), @lib.Expr::new(out)),
    ]),
  )
  ignore(@validate.validate_module(output).unwrap())
}
