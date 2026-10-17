///|
fn tuple_source_only_cmd_execute(
  func : @lib.Func,
  argument : Int32,
) -> Int32 raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = func
  let locals = Array::make(1 + body_locals.length(), 0)
  locals[0] = argument
  let stack : Array[Int32] = []
  let mut fuel = 512
  fn execute(instrs : Array[@lib.Instruction]) -> Unit raise {
    for instr in instrs {
      fuel -= 1
      assert_true(fuel > 0)
      match instr {
        @lib.Nop => ()
        @lib.Drop => ignore(stack.pop().unwrap())
        @lib.I32Const(@lib.I32(value)) => stack.push(value)
        @lib.LocalGet(@lib.LocalIdx(index)) =>
          stack.push(locals[index.to_int()])
        @lib.LocalSet(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = stack.pop().unwrap()
        @lib.LocalTee(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = stack[stack.length() - 1]
        @lib.I32Add => {
          let rhs = stack.pop().unwrap()
          let lhs = stack.pop().unwrap()
          stack.push(lhs + rhs)
        }
        @lib.Block(_, @lib.Expr(nested)) | @lib.Loop(_, @lib.Expr(nested)) =>
          execute(nested)
        _ => fail("unsupported source-only tuple fixture instruction: \{instr}")
      }
    }
  }
  execute(body)
  assert_eq(stack.length(), 1)
  stack[0]
}

///|
fn tuple_source_only_cmd_metrics(
  body : Array[@lib.Instruction],
) -> (Int32, Int32) {
  let mut tuple_blocks = 0
  let mut local_ops = 0
  for instr in body {
    match instr {
      @lib.LocalGet(_) | @lib.LocalSet(_) | @lib.LocalTee(_) => local_ops += 1
      @lib.Block(block_type, @lib.Expr(nested)) => {
        if block_type is @lib.TypeIdxBlockType(_) {
          tuple_blocks += 1
        }
        let (blocks, ops) = tuple_source_only_cmd_metrics(nested)
        tuple_blocks += blocks
        local_ops += ops
      }
      @lib.Loop(_, @lib.Expr(nested)) => {
        let (blocks, ops) = tuple_source_only_cmd_metrics(nested)
        tuple_blocks += blocks
        local_ops += ops
      }
      _ => ()
    }
  }
  (tuple_blocks, local_ops)
}

///|
fn tuple_source_only_cmd_check(loop_ : Bool) -> Unit raise {
  let open_control = if loop_ { "loop " } else { "" }
  let close_control = if loop_ { "end " } else { "" }
  let text = "(module (type (func (result i32 i32))) " +
    "(func (export \"run\") (param i32) (result i32) (local i32 i32) " +
    open_control +
    "block (type 0) local.get 0 i32.const 1 i32.add " +
    "local.get 0 i32.const 2 i32.add end local.set 2 local.set 1 " +
    close_control +
    "local.get 1 local.get 2 i32.add))"
  let input = @passes.pass_test_module_from_wat(text)
  let input_bytes = encode_module_bytes(input)
  let @lib.Func(input_locals, @lib.Expr(input_body)) = input.code_sec.unwrap().0[0]
  let (input_blocks, input_ops) = tuple_source_only_cmd_metrics(input_body)
  assert_eq(input_blocks, 1)
  let cases = [
    (-2147483648, 3),
    (-1, 1),
    (0, 3),
    (1, 5),
    (42, 87),
    (2147483647, 1),
  ]
  for (argument, expected) in cases {
    assert_eq(
      tuple_source_only_cmd_execute(input.code_sec.unwrap().0[0], argument),
      expected,
    )
  }
  let mut first_size : Int32? = None
  for repeat in 1..<5 {
    let passes = Array::make(repeat, "tuple-optimization")
    let output = optimize_module_with_pass_flags(
      input,
      passes,
      OptimizeOptions::new(),
    ).unwrap()
    let output_bytes = encode_module_bytes(output)
    let decoded = decode_module_bytes(output_bytes)
    ignore(@validate.validate_module(decoded).unwrap())
    let @lib.Func(output_locals, @lib.Expr(body)) = decoded.code_sec.unwrap().0[0]
    let (blocks, ops) = tuple_source_only_cmd_metrics(body)
    // A whole-pass no-op does not meet this required scalarization contract.
    assert_eq(blocks, 0)
    assert_true(
      output_bytes.length() < input_bytes.length(),
      msg="source scalarization must save encoded bytes",
    )
    assert_true(
      output_locals.length() <= input_locals.length(),
      msg="source scalarization must not add scratch locals",
    )
    assert_true(
      ops <= input_ops,
      msg="source scalarization must not add local operations",
    )
    match first_size {
      Some(size) => assert_eq(output_bytes.length(), size)
      None => first_size = Some(output_bytes.length())
    }
    for (argument, expected) in cases {
      assert_eq(
        tuple_source_only_cmd_execute(decoded.code_sec.unwrap().0[0], argument),
        expected,
      )
    }
  }
}

///|
test "tuple dispatcher source-only arithmetic scalarization saves bytes and stays stable" {
  tuple_source_only_cmd_check(false)
}

///|
test "tuple dispatcher loop source-only scalarization adds no locals across repeat passes" {
  tuple_source_only_cmd_check(true)
}

///|
test "tuple dispatcher pure-source scalarization retains mutable overlap trap call and partial-write behavior" {
  let cases : Array[(String, (Int32?, Array[Int32]))] = [
    (
      "block (type 0) local.get 0 i32.const 1 i32.add local.get 0 i32.const 2 i32.add end " +
      "local.set 0 local.set 1 local.get 1 local.get 0 i32.add",
      (Some(23), []),
    ),
    (
      "local.get 0 local.set 1 block (type 0) local.get 1 i32.const 1 i32.add " +
      "local.get 1 i32.const 2 i32.add end local.set 1 local.set 2 local.get 2 local.get 1 i32.add",
      (Some(23), []),
    ),
    (
      "block (type 0) local.get 0 i32.const 0 i32.div_s local.get 0 i32.const 2 i32.add end " +
      "local.set 2 local.set 1 local.get 1 local.get 2 i32.add",
      (None, []),
    ),
    (
      "block (type 0) local.get 0 i32.const 1 i32.add call 0 local.get 0 i32.const 2 i32.add call 0 end " +
      "local.set 2 local.set 1 local.get 1 local.get 2 i32.add",
      (Some(23), [11, 12]),
    ),
    (
      "i32.const 7 local.set 1 block (type 0) local.get 0 i32.const 1 i32.add " +
      "local.get 0 i32.const 2 i32.add end local.set 2 local.get 1 local.set 3 local.set 1 " +
      "local.get 3 local.get 1 i32.add local.get 2 i32.add",
      (Some(30), []),
    ),
  ]
  for (body, expected) in cases {
    let text = "(module (type (func (result i32 i32))) " +
      "(import \"env\" \"mark\" (func (param i32) (result i32))) " +
      "(func (export \"run\") (param i32) (result i32) (local i32 i32 i32) " +
      body +
      "))"
    let input = @passes.pass_test_module_from_wat(text)
    assert_eq(
      tuple_prefix_cmd_execute(input.code_sec.unwrap().0[0], arguments=[10]),
      expected,
    )
    for
      passes in [
        ["tuple-optimization"],
        [
          "tuple-optimization", "tuple-optimization", "tuple-optimization", "tuple-optimization",
        ],
        [
          "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals",
          "vacuum", "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals",
          "vacuum",
        ],
      ] {
      let output = optimize_module_with_pass_flags(
        input,
        passes,
        OptimizeOptions::new(),
      ).unwrap()
      let decoded = decode_module_bytes(encode_module_bytes(output))
      ignore(@validate.validate_module(decoded).unwrap())
      assert_eq(
        tuple_prefix_cmd_execute(decoded.code_sec.unwrap().0[0], arguments=[10]),
        expected,
        msg="body: \{body}; passes: \{passes}",
      )
    }
  }
}

///|
test "tuple dispatcher typed entry operands preserve values through source scalarization" {
  // Block entry operands are children before the body roots. They must remain
  // owned until the original block is evaluated, including after repeat passes.
  let input = @passes.pass_test_module_from_wat(
    "(module (type (func (param i32 i32) (result i32 i32))) " +
    "(func (export \"run\") (param i32 i32) (result i32) (local i32 i32) " +
    "local.get 0 local.get 1 block (type 0) i32.const 2 i32.add end " +
    "local.set 3 local.set 2 local.get 2 local.get 3 i32.add))",
  )
  ignore(@validate.validate_module(input).unwrap())
  assert_eq(
    tuple_prefix_cmd_execute(input.code_sec.unwrap().0[0], arguments=[10, 20]),
    (Some(32), []),
  )
  for
    passes in [
      ["tuple-optimization"],
      [
        "tuple-optimization", "tuple-optimization", "tuple-optimization", "tuple-optimization",
      ],
      [
        "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals", "vacuum",
        "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals", "vacuum",
      ],
    ] {
    let output = optimize_module_with_pass_flags(
      input,
      passes,
      OptimizeOptions::new(),
    ).unwrap()
    let decoded = @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap()
    ignore(@validate.validate_module(decoded).unwrap())
    assert_eq(
      tuple_prefix_cmd_execute(decoded.code_sec.unwrap().0[0], arguments=[
        10, 20,
      ]),
      (Some(32), []),
    )
  }
}

///|
test "tuple dispatcher multiple pure sources retain later opaque values and effects" {
  // The first two groups retire old producer IDs. Later group rewrites still
  // hold the original analysis snapshot, so this covers node-ID reuse too.
  let input = @passes.pass_test_module_from_wat(
    "(module (type (func (result i32 i32))) " +
    "(import \"env\" \"mark\" (func (param i32) (result i32))) " +
    "(func (export \"run\") (param i32) (result i32) (local i32 i32 i32 i32 i32 i32) " +
    "block (type 0) local.get 0 i32.const 1 i32.add local.get 0 i32.const 2 i32.add end " +
    "local.set 2 local.set 1 " +
    "block (type 0) local.get 0 i32.const 3 i32.add local.get 0 i32.const 4 i32.add end " +
    "local.set 4 local.set 3 " +
    "block (type 0) local.get 0 i32.const 5 i32.add call 0 local.get 0 i32.const 6 i32.add call 0 end " +
    "local.set 6 local.set 5 " +
    "local.get 1 local.get 2 i32.add local.get 3 i32.add local.get 4 i32.add " +
    "local.get 5 i32.add local.get 6 i32.add))",
  )
  let original = @binary.decode_module(@binary.encode_module(input).unwrap()).unwrap()
  ignore(@validate.validate_module(original).unwrap())
  let expected = (Some(81), [15, 16])
  assert_eq(
    tuple_prefix_cmd_execute(original.code_sec.unwrap().0[0], arguments=[10]),
    expected,
  )
  for
    passes in [
      ["tuple-optimization"],
      [
        "tuple-optimization", "tuple-optimization", "tuple-optimization", "tuple-optimization",
      ],
      [
        "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals", "vacuum",
        "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals", "vacuum",
      ],
    ] {
    let output = optimize_module_with_pass_flags(
      input,
      passes,
      OptimizeOptions::new(),
    ).unwrap()
    let decoded = @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap()
    ignore(@validate.validate_module(decoded).unwrap())
    assert_eq(
      tuple_prefix_cmd_execute(decoded.code_sec.unwrap().0[0], arguments=[10]),
      expected,
    )
  }
}
