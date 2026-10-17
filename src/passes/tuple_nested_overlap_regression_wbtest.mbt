///|
fn tuple_nested_overlap_type_blocks(body : Array[@lib.Instruction]) -> Int32 {
  let mut count = 0
  for instr in body {
    if instr is @lib.Block(@lib.TypeIdxBlockType(_), _) {
      count += 1
    }
    match instr {
      @lib.Block(_, @lib.Expr(nested)) | @lib.Loop(_, @lib.Expr(nested)) =>
        count += tuple_nested_overlap_type_blocks(nested)
      @lib.If(_, yes, no) => {
        count += tuple_nested_overlap_type_blocks(yes)
        match no {
          Some(nested) => count += tuple_nested_overlap_type_blocks(nested)
          None => ()
        }
      }
      _ => ()
    }
  }
  count
}

///|
fn tuple_nested_overlap_source(control : String) -> String {
  "(module (type $pair (func (result i32 i32))) " +
  "(func (export \"run\") (result i32) " +
  "(local $saved i32) (local $a i32) (local $b i32) (local $out i32) " +
  control +
  " " +
  "block (type $pair) i32.const 11 i32.const 100 end " +
  "local.set $b local.set $a " +
  "block (type $pair) local.get $a local.get $b end " +
  "local.set $b local.set $a " +
  "i32.const 1 if local.get $a local.set $saved end " +
  "block (type $pair) local.get $saved local.get $b end " +
  "local.set $out local.set $b end " +
  "local.get $b local.get $out i32.add))"
}

///|
test "tuple nested overlapping self copy preserves both producer lanes" {
  // The second copy writes $b with the saved first lane. The preceding self
  // copy must read its current second lane before any replacement writes it.
  for control in ["block", "loop"] {
    let input = pass_test_module_from_wat(tuple_nested_overlap_source(control))
    ignore(@validate.validate_module(input).unwrap())
    assert_eq(tuple_alias_capture_execute(input.code_sec.unwrap().0[0]), 111)
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
      "tuple-optimization",
    ]).unwrap()
    ignore(@validate.validate_module(output).unwrap())
    assert_eq(tuple_alias_capture_execute(output.code_sec.unwrap().0[0]), 111)
    let tuple_blocks = fn(mod_ : @lib.Module) {
      let @lib.Func(_, @lib.Expr(body)) = mod_.code_sec.unwrap().0[0]
      tuple_nested_overlap_type_blocks(body)
    }
    assert_true(
      tuple_blocks(output) < tuple_blocks(input),
      msg="the simple nested self-copy must be scalarized",
    )
    let @lib.Func(input_locals, _) = input.code_sec.unwrap().0[0]
    let @lib.Func(output_locals, @lib.Expr(output_body)) = output.code_sec.unwrap().0[0]
    let written = Array::make(output_locals.length(), false)
    fn check_new_local_reads(body : Array[@lib.Instruction]) -> Unit raise {
      for instr in body {
        match instr {
          @lib.LocalSet(@lib.LocalIdx(index))
          | @lib.LocalTee(@lib.LocalIdx(index)) =>
            written[index.to_int()] = true
          @lib.LocalGet(@lib.LocalIdx(index)) =>
            if index.to_int() >= input_locals.length() {
              assert_true(
                written[index.to_int()],
                msg="new tuple scratch local read before its first write",
              )
            }
          @lib.Block(_, @lib.Expr(nested)) | @lib.Loop(_, @lib.Expr(nested)) =>
            check_new_local_reads(nested)
          @lib.If(_, yes, no) => {
            check_new_local_reads(yes)
            match no {
              Some(nested) => check_new_local_reads(nested)
              None => ()
            }
          }
          _ => ()
        }
      }
    }
    check_new_local_reads(output_body)
  }
}

///|
test "tuple nested overlapping self copy remains correct after repeated cleanup" {
  let input = pass_test_module_from_wat(tuple_nested_overlap_source("loop"))
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals", "vacuum",
    "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals", "vacuum",
  ]).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  let decoded = @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap()
  ignore(@validate.validate_module(decoded).unwrap())
  assert_eq(tuple_alias_capture_execute(decoded.code_sec.unwrap().0[0]), 111)
}

///|
fn tuple_nested_overlap_effect_source() -> String {
  "(module (type $pair (func (result i32 i32))) " +
  "(import \"env\" \"mark\" (func $mark (param i32) (result i32))) " +
  "(func (export \"run\") (param $limit i32) (result i32) " +
  "(local $saved i32) (local $a i32) (local $b i32) (local $out i32) (local $i i32) " +
  "local.get $limit i32.const 3 i32.and i32.const 1 i32.add local.set $limit " +
  "loop $again " +
  "block (type $pair) local.get $i i32.const 11 i32.add " +
  "local.get $i i32.const 100 i32.add end local.set $b local.set $a " +
  "block (type $pair) i32.const 9 call $mark drop " +
  "local.get $a local.get $b end local.set $b local.set $a " +
  "local.get $i i32.eqz if local.get $a local.set $saved end " +
  "block (type $pair) local.get $saved local.get $b end " +
  "local.set $out local.set $b " +
  "local.get $i i32.const 1 i32.add local.tee $i " +
  "local.get $limit i32.lt_s br_if $again end " +
  "local.get $b local.get $out i32.add))"
}

///|
// This executor handles only the bounded fixture surface. The imported mark
// returns its operand and records each call, so duplicate evaluation is visible.
fn tuple_nested_overlap_effect_execute(
  func : @lib.Func,
  argument : Int32,
) -> (Int32, Array[Int32]) raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = func
  let locals = Array::make(1 + body_locals.length(), 0)
  locals[0] = argument
  let stack : Array[Int32] = []
  let events : Array[Int32] = []
  let mut fuel = 2048
  fn execute(instrs : Array[@lib.Instruction]) -> Int32? raise {
    for instr in instrs {
      fuel -= 1
      assert_true(fuel > 0)
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
        @lib.I32Eqz => stack.push(if stack.pop().unwrap() == 0 { 1 } else { 0 })
        @lib.I32Add | @lib.I32And | @lib.I32LtS => {
          let rhs = stack.pop().unwrap()
          let lhs = stack.pop().unwrap()
          stack.push(
            match instr {
              @lib.I32Add => lhs + rhs
              @lib.I32And => lhs & rhs
              _ => if lhs < rhs { 1 } else { 0 }
            },
          )
        }
        @lib.Call(index) => {
          assert_eq(index, @lib.FuncIdx::new(0U))
          events.push(stack[stack.length() - 1])
        }
        @lib.Block(_, @lib.Expr(nested)) => assert_eq(execute(nested), None)
        @lib.Loop(@lib.VoidBlockType, @lib.Expr(nested)) => {
          let base = stack.length()
          let mut again = true
          while again {
            match execute(nested) {
              Some(0) => assert_eq(stack.length(), base)
              Some(depth) => return Some(depth - 1)
              None => again = false
            }
          }
        }
        @lib.If(@lib.VoidBlockType, yes, no) => {
          let condition = stack.pop().unwrap()
          assert_eq(execute(if condition != 0 { yes } else { no.or([]) }), None)
        }
        @lib.BrIf(@lib.LabelIdx(depth)) =>
          if stack.pop().unwrap() != 0 {
            return Some(depth.to_int())
          }
        _ => fail("unexpected nested tuple fixture instruction: \{instr}")
      }
    }
    None
  }
  assert_eq(execute(body), None)
  assert_eq(stack.length(), 1)
  (stack[0], events)
}

///|
test "tuple nested opaque producer runs once and preserves overlapping loop snapshots" {
  let input = pass_test_module_from_wat(tuple_nested_overlap_effect_source())
  for
    passes in [
      ["tuple-optimization"],
      [
        "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals", "vacuum",
        "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals", "vacuum",
      ],
    ] {
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), passes).unwrap()
    ignore(@validate.validate_module(output).unwrap())
    for argument in [0, 1, 3, -1, -4, -2147483648, 2147483647] {
      let last_iteration = argument & 3
      let expected = (111 + last_iteration, Array::make(1 + last_iteration, 9))
      assert_eq(
        tuple_nested_overlap_effect_execute(
          input.code_sec.unwrap().0[0],
          argument,
        ),
        expected,
      )
      assert_eq(
        tuple_nested_overlap_effect_execute(
          output.code_sec.unwrap().0[0],
          argument,
        ),
        expected,
      )
    }
  }
}
