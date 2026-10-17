///|
fn tuple_opaque_growth_run(
  input : @lib.Module,
  passes : Array[String],
) -> @lib.Module raise {
  let input_bytes = encode_module_bytes(input)
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["opaque.wasm"] },
    file_exists=fn(path) { path == "opaque.wasm" },
    read_file=fn(path) {
      if path == "opaque.wasm" {
        Ok(input_bytes)
      } else {
        Err("missing opaque copy fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let args : Array[String] = []
  for pass_name in passes {
    args.push("--" + pass_name)
  }
  args.push("--out")
  args.push("out.wasm")
  args.push("opaque.wasm")
  let summary = run_cmd_with_adapter(args, io).unwrap()
  assert_eq(summary.resolved_passes, passes)
  assert_eq(writes.length(), 1)
  assert_eq(writes[0].0, "out.wasm")
  decode_module_bytes(writes[0].1)
}

///|
fn tuple_opaque_growth_counts(body : Array[@lib.Instruction]) -> (Int32, Int32) {
  let mut blocks = 0
  let mut locals = 0
  for instr in body {
    match instr {
      @lib.LocalGet(_) | @lib.LocalSet(_) | @lib.LocalTee(_) => locals += 1
      @lib.Block(_, @lib.Expr(nested)) => {
        let (nested_blocks, nested_locals) = tuple_opaque_growth_counts(nested)
        blocks += 1 + nested_blocks
        locals += nested_locals
      }
      @lib.Loop(_, @lib.Expr(nested)) => {
        let (nested_blocks, nested_locals) = tuple_opaque_growth_counts(nested)
        blocks += nested_blocks
        locals += nested_locals
      }
      @lib.If(_, then_body, else_body) => {
        let (then_blocks, then_locals) = tuple_opaque_growth_counts(then_body)
        let (else_blocks, else_locals) = tuple_opaque_growth_counts(
          else_body.or([]),
        )
        blocks += then_blocks + else_blocks
        locals += then_locals + else_locals
      }
      _ => ()
    }
  }
  (blocks, locals)
}

///|
fn tuple_opaque_growth_fixture(
  copy : Bool,
  loop_ : Bool,
  trailing : Bool,
  trapping : Bool,
  pure : Bool,
) -> String {
  let mark = if pure { " " } else { " call $mark " }
  let source = "block (type $pair) local.get 0 i32.const 1 i32.add" +
    mark +
    (if trapping { "i32.const 1 i32.const 0 i32.div_s drop " } else { "" }) +
    "local.get 0 i32.const 2 i32.add" +
    mark +
    "end local.set 2 local.set 1 "
  let copied = if trailing {
    "block (result i32) local.get 1 local.get 2 local.set 4 end local.set 3 "
  } else {
    "block (result i32) local.get 2 local.set 4 local.get 1 end local.set 3 "
  }
  "(module (type $pair (func (result i32 i32))) " +
  "(import \"env\" \"mark\" (func $mark (param i32) (result i32))) " +
  "(func (export \"run\") (param i32) (result i32) " +
  (if copy { "(local i32 i32 i32 i32) " } else { "(local i32 i32) " }) +
  (if loop_ { "loop " } else { "" }) +
  source +
  (if copy { copied } else { "" }) +
  (if loop_ { "end " } else { "" }) +
  (if copy {
    "local.get 3 local.get 4 i32.add))"
  } else {
    "local.get 1 local.get 2 i32.add))"
  })
}

///|
fn tuple_opaque_growth_check(
  copy : Bool,
  loop_ : Bool,
  trailing : Bool,
  trapping : Bool,
  pure : Bool,
) -> Unit raise {
  let input = @passes.pass_test_module_from_wat(
    tuple_opaque_growth_fixture(copy, loop_, trailing, trapping, pure),
  )
  ignore(@validate.validate_module(input).unwrap())
  let @lib.Func(input_locals, @lib.Expr(input_body)) = input.code_sec.unwrap().0[0]
  let input_bytes = @binary.encode_module(input).unwrap().length()
  let (input_blocks, input_local_ops) = tuple_opaque_growth_counts(input_body)
  assert_eq(input_blocks, if copy { 2 } else { 1 })
  let expected : (Int32?, Array[Int32]) = (
    if trapping {
      None
    } else {
      Some(23)
    },
    if pure {
      []
    } else if trapping {
      [11]
    } else {
      [11, 12]
    },
  )
  assert_eq(
    tuple_prefix_cmd_execute(input.code_sec.unwrap().0[0], arguments=[10]),
    expected,
  )
  let mut previous_size : Int32? = None
  for repeat in 1..<5 {
    let output = tuple_opaque_growth_run(
      input,
      Array::make(repeat, "tuple-optimization"),
    )
    let bytes = @binary.encode_module(output).unwrap()
    let decoded = @binary.decode_module(bytes).unwrap()
    ignore(@validate.validate_module(decoded).unwrap())
    assert_eq(
      tuple_prefix_cmd_execute(decoded.code_sec.unwrap().0[0], arguments=[10]),
      expected,
    )
    let @lib.Func(body_locals, @lib.Expr(body)) = decoded.code_sec.unwrap().0[0]
    let (blocks, local_ops) = tuple_opaque_growth_counts(body)
    // Positive copies must actually lose their wrapper. A whole-pass no-op
    // cannot meet both wrapper removal and strict first-pass byte saving.
    if pure {
      // Removing the arithmetic producer as well is a strict further saving;
      // all byte/local/operation/stability and semantic checks still apply.
      assert_true(blocks <= 1)
    } else {
      assert_eq(blocks, 1)
    }
    if copy {
      assert_true(
        bytes.length() < input_bytes,
        msg="copy forwarding must save bytes before cleanup",
      )
    } else {
      // The already scalar-spilled opaque producer stays at its original site.
      assert_true(
        bytes.length() <= input_bytes,
        msg="opaque source staging must not add bytes",
      )
    }
    assert_true(
      body_locals.length() <= input_locals.length(),
      msg="copy/source rewrite added locals",
    )
    assert_true(
      local_ops <= input_local_ops,
      msg="copy/source rewrite added local operations",
    )
    match previous_size {
      Some(previous) =>
        if pure && copy && repeat == 2 {
          // Copy removal exposes the source-only pure fold to the next pass.
          // That further saving is allowed; the fully folded result is stable.
          assert_true(bytes.length() <= previous)
        } else {
          assert_eq(bytes.length(), previous)
        }
      None => ()
    }
    previous_size = Some(bytes.length())
  }
  for
    passes in [
      [
        "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals", "vacuum",
      ],
      [
        "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals", "vacuum",
        "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals", "vacuum",
      ],
    ] {
    let output = tuple_opaque_growth_run(input, passes)
    let decoded = @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap()
    ignore(@validate.validate_module(decoded).unwrap())
    assert_eq(
      tuple_prefix_cmd_execute(decoded.code_sec.unwrap().0[0], arguments=[10]),
      expected,
    )
  }
}

///|
test "tuple dispatcher opaque-copy opaque calls add no source-only staging across repeated passes" {
  tuple_opaque_growth_check(false, false, false, false, false)
}

///|
test "tuple dispatcher opaque-copy opaque intentional trap retains earlier events without staging growth" {
  tuple_opaque_growth_check(false, false, false, true, false)
}

///|
test "tuple dispatcher opaque-copy root prefix copy saves bytes and stays stable" {
  tuple_opaque_growth_check(true, false, false, false, false)
}

///|
test "tuple dispatcher opaque-copy root trailing copy saves bytes and stays stable" {
  tuple_opaque_growth_check(true, false, true, false, false)
}

///|
test "tuple dispatcher opaque-copy loop prefix copy saves bytes and stays stable" {
  tuple_opaque_growth_check(true, true, false, false, false)
}

///|
test "tuple dispatcher opaque-copy loop trailing copy saves bytes and stays stable" {
  tuple_opaque_growth_check(true, true, true, false, false)
}

///|
test "tuple dispatcher opaque-copy arithmetic source with copies still makes real size progress" {
  for loop_ in [false, true] {
    tuple_opaque_growth_check(true, loop_, false, false, true)
  }
}

///|
test "tuple dispatcher opaque-copy typed entry source keeps operands while its copy saves bytes" {
  let input = @passes.pass_test_module_from_wat(
    "(module (type $pair (func (param i32 i32) (result i32 i32))) " +
    "(func (export \"run\") (param i32 i32) (result i32) (local i32 i32 i32 i32) " +
    "local.get 0 local.get 1 block (type $pair) i32.const 2 i32.add end local.set 3 local.set 2 " +
    "block (result i32) local.get 3 local.set 5 local.get 2 end local.set 4 " +
    "local.get 4 local.get 5 i32.add))",
  )
  ignore(@validate.validate_module(input).unwrap())
  let input_bytes = @binary.encode_module(input).unwrap().length()
  assert_eq(
    tuple_prefix_cmd_execute(input.code_sec.unwrap().0[0], arguments=[10, 20]),
    (Some(32), []),
  )
  let mut first_size : Int32? = None
  for repeat in 1..<5 {
    let output = tuple_opaque_growth_run(
      input,
      Array::make(repeat, "tuple-optimization"),
    )
    let bytes = @binary.encode_module(output).unwrap()
    let decoded = @binary.decode_module(bytes).unwrap()
    ignore(@validate.validate_module(decoded).unwrap())
    assert_eq(
      tuple_prefix_cmd_execute(decoded.code_sec.unwrap().0[0], arguments=[
        10, 20,
      ]),
      (Some(32), []),
    )
    let @lib.Func(locals, @lib.Expr(body)) = decoded.code_sec.unwrap().0[0]
    let (blocks, local_ops) = tuple_opaque_growth_counts(body)
    assert_eq(blocks, 1)
    assert_true(bytes.length() < input_bytes)
    assert_true(locals.length() <= 4)
    assert_true(local_ops <= 10)
    match first_size {
      Some(first) => assert_eq(bytes.length(), first)
      None => first_size = Some(bytes.length())
    }
  }
}

///|
test "tuple dispatcher opaque-copy captured payload survives a later producer execution when copies flatten" {
  let text = "(module (type $pair (func (result i32 i32))) " +
    "(func (export \"run\") (result i32) " +
    "(local $a i32) (local $b i32) (local $saved_a i32) (local $saved_b i32) " +
    "(local $alias_a i32) (local $alias_b i32) (local $out_a i32) (local $out_b i32) (local $i i32) " +
    "loop $again block (type $pair) local.get $i i32.const 11 i32.add local.get $i i32.const 100 i32.add end " +
    "local.set $b local.set $a local.get $i i32.eqz if local.get $a local.set $saved_a " +
    "local.get $b local.set $saved_b local.get $saved_a local.set $alias_a local.get $saved_b local.set $alias_b end " +
    "block (result i32) local.get $alias_b local.set $out_b local.get $alias_a end local.set $out_a " +
    "local.get $i i32.const 1 i32.add local.tee $i i32.const 2 i32.lt_s br_if $again end " +
    "local.get $out_a local.get $out_b i32.add))"
  let input = @passes.pass_test_module_from_wat(text)
  ignore(@validate.validate_module(input).unwrap())
  assert_eq(tuple_alias_cmd_execute(input.code_sec.unwrap().0[0]), 111)
  let input_bytes = @binary.encode_module(input).unwrap().length()
  let mut first_size : Int32? = None
  for repeat in 1..<5 {
    let output = tuple_opaque_growth_run(
      input,
      Array::make(repeat, "tuple-optimization"),
    )
    let bytes = @binary.encode_module(output).unwrap()
    let decoded = @binary.decode_module(bytes).unwrap()
    ignore(@validate.validate_module(decoded).unwrap())
    assert_eq(tuple_alias_cmd_execute(decoded.code_sec.unwrap().0[0]), 111)
    let @lib.Func(_, @lib.Expr(body)) = decoded.code_sec.unwrap().0[0]
    assert_eq(tuple_opaque_growth_counts(body).0, 1)
    assert_true(bytes.length() < input_bytes)
    match first_size {
      Some(first) => assert_eq(bytes.length(), first)
      None => first_size = Some(bytes.length())
    }
  }
}

///|
test "tuple dispatcher opaque-copy overlap masked copies Call parents and prefixes keep original effects" {
  let source = "block (type $pair) local.get 0 i32.const 1 i32.add call $mark " +
    "local.get 0 i32.const 2 i32.add call $mark end local.set 2 local.set 1 "
  let cases : Array[(String, (Int32?, Array[Int32]))] = [
    // A permutation requires snapshots: two a values plus b distinguish lanes.
    (
      "block (type $pair) local.get 2 local.get 1 end local.set 2 local.set 1 " +
      "local.get 1 local.get 1 i32.add local.get 2 i32.add",
      (Some(35), [11, 12]),
    ),
    // Plain scalar copy groups have no result carrier or host lane to rewrite.
    (
      "local.get 1 local.set 3 local.get 2 local.set 4 local.get 3 local.get 4 i32.add",
      (Some(23), [11, 12]),
    ),
    (
      "block (result i32) local.get 2 local.set 4 local.get 1 end local.tee 3 call $mark " +
      "local.get 4 i32.add",
      (Some(23), [11, 12, 11]),
    ),
    // The direct-copy proof intentionally excludes effectful prefixes.
    (
      "block (result i32) i32.const 77 call $mark drop local.get 1 local.get 2 local.set 4 end " +
      "local.set 3 local.get 3 local.get 4 i32.add",
      (Some(23), [11, 12, 77]),
    ),
    (
      "block (result i32) i32.const 77 call $mark drop i32.const 1 i32.const 0 i32.div_s drop " +
      "local.get 1 local.get 2 local.set 4 end local.set 3 local.get 3 local.get 4 i32.add",
      (None, [11, 12, 77]),
    ),
  ]
  for (tail, expected) in cases {
    let input = @passes.pass_test_module_from_wat(
      "(module (type $pair (func (result i32 i32))) " +
      "(import \"env\" \"mark\" (func $mark (param i32) (result i32))) " +
      "(func (export \"run\") (param i32) (result i32) (local i32 i32 i32 i32) " +
      source +
      tail +
      "))",
    )
    ignore(@validate.validate_module(input).unwrap())
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
      let output = tuple_opaque_growth_run(input, passes)
      let decoded = @binary.decode_module(
        @binary.encode_module(output).unwrap(),
      ).unwrap()
      ignore(@validate.validate_module(decoded).unwrap())
      assert_eq(
        tuple_prefix_cmd_execute(decoded.code_sec.unwrap().0[0], arguments=[10]),
        expected,
      )
    }
  }
}

///|
// This bounded executor uses one numeric stack because this fixture only moves
// the i64 constant 100; no mixed-type arithmetic or conversions are admitted.
fn tuple_opaque_drop_only_observe(
  func : @lib.Func,
) -> (Int32, Array[Int32]) raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = func
  let locals = Array::make(1 + body_locals.length(), 0)
  locals[0] = 10
  let stack : Array[Int32] = []
  let events : Array[Int32] = []
  let mut fuel = 128
  fn execute(instructions : Array[@lib.Instruction]) -> Unit raise {
    for instruction in instructions {
      fuel -= 1
      assert_true(fuel > 0)
      match instruction {
        @lib.Nop => ()
        @lib.Drop => ignore(stack.pop().unwrap())
        @lib.I32Const(@lib.I32(value)) => stack.push(value)
        @lib.I64Const(value) => {
          assert_eq(value, @lib.I64::new(100L))
          stack.push(100)
        }
        @lib.LocalGet(@lib.LocalIdx(index)) =>
          stack.push(locals[index.to_int()])
        @lib.LocalSet(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = stack.pop().unwrap()
        @lib.LocalTee(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = stack[stack.length() - 1]
        @lib.Call(index) => {
          assert_eq(index, @lib.FuncIdx::new(0U))
          events.push(stack[stack.length() - 1])
        }
        @lib.Block(_, @lib.Expr(nested)) => execute(nested)
        _ => fail("unsupported opaque drop-only instruction: \{instruction}")
      }
    }
  }
  execute(body)
  assert_eq(stack.length(), 1)
  (stack[0], events)
}

///|
test "command opaque-copy dropped mixed lanes retain effects without staging growth" {
  let input = @passes.pass_test_module_from_wat(
    "(module (type $pair (func (result i32 i64))) " +
    "(import \"env\" \"mark\" (func $mark (param i32) (result i32))) " +
    "(func (export \"run\") (param i32) (result i32) (local i32 i64) " +
    "block (type $pair) local.get 0 call $mark i64.const 100 end " +
    "local.set 2 local.set 1 local.get 1 drop local.get 2 drop i32.const 42))",
  )
  ignore(@validate.validate_module(input).unwrap())
  let expected = (42, [10])
  assert_eq(
    tuple_opaque_drop_only_observe(input.code_sec.unwrap().0[0]),
    expected,
  )
  let input_bytes = @binary.encode_module(input).unwrap().length()
  let mut output = input
  for _ in 0..<4 {
    output = tuple_opaque_growth_run(output, ["tuple-optimization"])
    let bytes = @binary.encode_module(output).unwrap()
    let decoded = @binary.decode_module(bytes).unwrap()
    ignore(@validate.validate_module(decoded).unwrap())
    assert_eq(
      tuple_opaque_drop_only_observe(decoded.code_sec.unwrap().0[0]),
      expected,
    )
    assert_eq(bytes.length(), input_bytes)
    let @lib.Func(locals, @lib.Expr(body)) = decoded.code_sec.unwrap().0[0]
    assert_eq(locals.length(), 2)
    assert_eq(tuple_opaque_growth_counts(body), (1, 5))
  }
}

///|
fn tuple_opaque_wide_fixture(
  arity : Int32,
  trailing : Bool,
  loop_ : Bool,
  descending : Bool,
) -> String {
  let mut types = ""
  let mut locals = ""
  for _ in 0..<arity {
    types += "i32 "
    locals += "i32 i32 "
  }
  let mut source = "block (type 0) "
  for lane in 1..<(arity + 1) {
    source += "local.get 0 i32.const " + lane.to_string() + " i32.add call 0 "
  }
  source += "end "
  for lane in 0..<arity {
    source += "local.set " + (arity - lane).to_string() + " "
  }
  let mut copy = "block (result i32) "
  if trailing {
    copy += "local.get 1 "
  }
  for index in 2..<(arity + 1) {
    let lane = if descending { arity + 2 - index } else { index }
    copy += "local.get " +
      lane.to_string() +
      " local.set " +
      (arity + lane).to_string() +
      " "
  }
  if !trailing {
    copy += "local.get 1 "
  }
  copy += "end local.set " + (arity + 1).to_string() + " "
  let mut result = "local.get " + (arity + 1).to_string() + " "
  for lane in 2..<(arity + 1) {
    for _ in 0..<lane {
      result += "local.get " + (arity + lane).to_string() + " i32.add "
    }
  }
  "(module (type (func (result " +
  types +
  "))) " +
  "(import \"env\" \"mark\" (func (param i32) (result i32))) " +
  "(func (export \"run\") (param i32) (result i32) (local " +
  locals +
  ") " +
  (if loop_ { "loop " } else { "" }) +
  source +
  copy +
  (if loop_ { "end " } else { "" }) +
  result +
  "))"
}

///|
fn tuple_opaque_wide_check(arity : Int32, descending : Bool) -> Unit raise {
  for trailing in [false, true] {
    for loop_ in [false, true] {
      let input = @passes.pass_test_module_from_wat(
        tuple_opaque_wide_fixture(arity, trailing, loop_, descending),
      )
      ignore(@validate.validate_module(input).unwrap())
      let @lib.Func(_, @lib.Expr(input_body)) = input.code_sec.unwrap().0[0]
      let (_, input_ops) = tuple_opaque_growth_counts(input_body)
      let before_bytes = @binary.encode_module(input).unwrap().length()
      for
        passes in [
          ["tuple-optimization"],
          ["tuple-optimization", "tuple-optimization"],
          [
            "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals",
            "vacuum", "tuple-optimization",
          ],
        ] {
        let output = tuple_opaque_growth_run(input, passes)
        let decoded = @binary.decode_module(
          @binary.encode_module(output).unwrap(),
        ).unwrap()
        ignore(@validate.validate_module(decoded).unwrap())
        let @lib.Func(locals, @lib.Expr(body)) = decoded.code_sec.unwrap().0[0]
        let (blocks, ops) = tuple_opaque_growth_counts(body)
        assert_true(
          blocks <= 1,
          msg="wide scalar copy blocks=\{blocks} arity=\{arity} trailing=\{trailing} loop=\{loop_} passes=\{passes}".view(),
        )
        assert_true(locals.length() <= 2 * arity)
        assert_true(ops <= input_ops)
        assert_true(
          @binary.encode_module(decoded).unwrap().length() < before_bytes,
        )
        for argument in [-2147483648, -1, 0, 10, 2147483647] {
          let events = Array::makei(arity, fn(lane) { argument + lane + 1 })
          let mut expected = 0
          for lane in 0..<arity {
            expected += (lane + 1) * events[lane]
          }
          assert_eq(
            tuple_prefix_cmd_execute(input.code_sec.unwrap().0[0], arguments=[
              argument,
            ]),
            (Some(expected), events),
          )
          assert_eq(
            tuple_prefix_cmd_execute(decoded.code_sec.unwrap().0[0], arguments=[
              argument,
            ]),
            (Some(expected), events),
          )
        }
      }
    }
  }
}

///|
test "command tuple opaque copy three lanes preserve distinct values and effects" {
  for descending in [false, true] {
    tuple_opaque_wide_check(3, descending)
  }
}

///|
test "command tuple opaque copy four lanes preserve distinct values and effects" {
  for descending in [false, true] {
    tuple_opaque_wide_check(4, descending)
  }
}

///|
test "command tuple ascending stores preserve read-after-write overlap" {
  // Store3 changes the value read for store4. These source/destination locals
  // intentionally overlap, so simultaneous snapshot forwarding is invalid.
  for trailing in [false, true] {
    let input = @passes.pass_test_module_from_wat(
      "(module (type (func (result i32 i32 i32))) " +
      "(import \"env\" \"mark\" (func (param i32) (result i32))) " +
      "(func (export \"run\") (param i32) (result i32) (local i32 i32 i32 i32) " +
      "block (type 0) local.get 0 i32.const 1 i32.add call 0 " +
      "local.get 0 i32.const 2 i32.add call 0 local.get 0 i32.const 3 i32.add call 0 end " +
      "local.set 3 local.set 2 local.set 1 block (result i32) " +
      (if trailing { "local.get 1 " } else { "" }) +
      "local.get 2 local.set 3 local.get 3 local.set 4 " +
      (if trailing { "" } else { "local.get 1 " }) +
      "end local.set 2 local.get 2 local.get 3 i32.add local.get 4 i32.add))",
    )
    ignore(@validate.validate_module(input).unwrap())
    for
      passes in [
        ["tuple-optimization"],
        ["tuple-optimization", "tuple-optimization"],
        [
          "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals",
          "vacuum", "tuple-optimization",
        ],
      ] {
      let output = tuple_opaque_growth_run(input, passes)
      let decoded = @binary.decode_module(
        @binary.encode_module(output).unwrap(),
      ).unwrap()
      ignore(@validate.validate_module(decoded).unwrap())
      for argument in [-2147483648, -1, 0, 10, 2147483647] {
        let expected = (
          Some(argument * 3 + 5),
          [argument + 1, argument + 2, argument + 3],
        )
        assert_eq(
          tuple_prefix_cmd_execute(input.code_sec.unwrap().0[0], arguments=[
            argument,
          ]),
          expected,
        )
        assert_eq(
          tuple_prefix_cmd_execute(decoded.code_sec.unwrap().0[0], arguments=[
            argument,
          ]),
          expected,
        )
      }
    }
  }
}
