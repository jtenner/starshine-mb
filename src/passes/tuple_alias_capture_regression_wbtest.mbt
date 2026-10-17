///|
// This executor covers the integer and structured-control instructions in the
// fixtures below. Unsupported instructions fail, and a fuel bound catches a
// changed loop exit. All result blocks are branch-free; loop branches carry no
// values, so no result-block stack unwind is needed.
fn tuple_alias_capture_execute(func : @lib.Func) -> Int32 raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = func
  let locals = Array::make(body_locals.length(), 0)
  let stack : Array[Int32] = []
  let mut fuel = 1000
  fn execute(instrs : Array[@lib.Instruction]) -> Int32? raise {
    for instr in instrs {
      fuel -= 1
      assert_true(fuel >= 0, msg="tuple alias fixture exceeded its fuel bound")
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
        @lib.I32Eqz => stack.push(if stack.pop().unwrap() == 0 { 1 } else { 0 })
        @lib.I32Add | @lib.I32Eq | @lib.I32LtS => {
          let rhs = stack.pop().unwrap()
          let lhs = stack.pop().unwrap()
          stack.push(
            match instr {
              @lib.I32Add => lhs + rhs
              @lib.I32Eq => if lhs == rhs { 1 } else { 0 }
              _ => if lhs < rhs { 1 } else { 0 }
            },
          )
        }
        @lib.Block(_, @lib.Expr(nested)) =>
          @debug.assert_eq(execute(nested), None)
        @lib.Loop(block_type, @lib.Expr(nested)) => {
          assert_true(block_type is @lib.VoidBlockType)
          let base = stack.length()
          let mut again = true
          while again {
            match execute(nested) {
              Some(0) => @debug.assert_eq(stack.length(), base)
              Some(depth) => return Some(depth - 1)
              None => again = false
            }
          }
        }
        @lib.If(block_type, then_body, else_body) => {
          assert_true(block_type is @lib.VoidBlockType)
          let condition = stack.pop().unwrap()
          @debug.assert_eq(
            execute(if condition != 0 { then_body } else { else_body.or([]) }),
            None,
          )
        }
        @lib.BrIf(@lib.LabelIdx(depth)) =>
          if stack.pop().unwrap() != 0 {
            return Some(depth.to_int())
          }
        _ => fail("unsupported tuple alias fixture instruction: \{instr}")
      }
    }
    None
  }
  @debug.assert_eq(execute(body), None)
  @debug.assert_eq(stack.length(), 1)
  stack[0]
}

///|
fn tuple_alias_capture_check(source : String, expected : Int32) -> Unit raise {
  let original = pass_test_module_from_wat(source)
  ignore(@validate.validate_module(original).unwrap())
  let optimized = run_hot_pipeline(original, HotPipelineOptions::new(), [
    "tuple-optimization",
  ]).unwrap()
  ignore(@validate.validate_module(optimized).unwrap())
  @debug.assert_eq(
    tuple_alias_capture_execute(original.code_sec.unwrap().0[0]),
    expected,
  )
  @debug.assert_eq(
    tuple_alias_capture_execute(optimized.code_sec.unwrap().0[0]),
    expected,
  )
}

///|
fn tuple_alias_capture_source(
  iterations : Int32,
  capture_iteration : Int32,
  chained : Bool,
  mixed : Bool,
  delayed : Bool,
  trailing~ : Bool = false,
) -> String {
  let capture = "local.get $a local.set $saved_a local.get $b local.set $saved_b " +
    (if chained {
      "local.get $saved_a local.set $alias_a local.get $saved_b local.set $alias_b "
    } else {
      ""
    })
  let alias_a = if chained { "$alias_a" } else { "$saved_a" }
  let alias_b = if mixed {
    "$b"
  } else if chained {
    "$alias_b"
  } else {
    "$saved_b"
  }
  let copy = if trailing {
    "block (result i32) local.get \{alias_a} " +
    "local.get \{alias_b} local.set $out_b end local.set $out_a "
  } else {
    "block (result i32) local.get \{alias_b} local.set $out_b " +
    "local.get \{alias_a} end local.set $out_a "
  }
  let traffic = if delayed {
    copy + capture
  } else {
    "local.get $iteration i32.const \{capture_iteration} i32.eq if " +
    capture +
    "end " +
    copy
  }
  "(module (type $pair (func (result i32 i32))) " +
  "(func (export \"run\") (result i32) " +
  "(local $a i32) (local $b i32) (local $saved_a i32) (local $saved_b i32) " +
  "(local $alias_a i32) (local $alias_b i32) " +
  "(local $out_a i32) (local $out_b i32) (local $iteration i32) " +
  "loop $again block (type $pair) " +
  "local.get $iteration i32.const 11 i32.add " +
  "local.get $iteration i32.const 100 i32.add end " +
  "local.set $b local.set $a " +
  traffic +
  "local.get $iteration i32.const 1 i32.add local.tee $iteration " +
  "i32.const \{iterations} i32.lt_s br_if $again end " +
  "local.get $out_a local.get $out_b i32.add))"
}

///|
test "tuple alias capture remains a snapshot when its producer repeats" {
  for iterations in [1, 2, 4] {
    for capture_iteration in 0..<iterations {
      tuple_alias_capture_check(
        tuple_alias_capture_source(
          iterations, capture_iteration, false, false, false,
        ),
        111 + 2 * capture_iteration,
      )
    }
  }
}

///|
test "tuple alias chains retain captured values across producer reexecution" {
  for iterations in [1, 2, 4] {
    tuple_alias_capture_check(
      tuple_alias_capture_source(iterations, 0, true, false, false),
      111,
    )
  }
}

///|
test "tuple copy keeps a captured lane separate from a current producer lane" {
  for iterations in [1, 2, 4] {
    tuple_alias_capture_check(
      tuple_alias_capture_source(iterations, 0, false, true, false),
      111 + iterations - 1,
    )
  }
}

///|
test "tuple loop aliases read before their write keep zero and previous values" {
  for iterations in [1, 2, 4] {
    tuple_alias_capture_check(
      tuple_alias_capture_source(iterations, 0, false, false, true),
      if iterations == 1 {
        0
      } else {
        111 + 2 * (iterations - 2)
      },
    )
  }
}

///|
test "tuple trailing result-block copy retains loop-carried captures" {
  for delayed in [false, true] {
    for iterations in [1, 2, 4] {
      tuple_alias_capture_check(
        tuple_alias_capture_source(
          iterations,
          0,
          false,
          false,
          delayed,
          trailing=true,
        ),
        if !delayed {
          111
        } else if iterations == 1 {
          0
        } else {
          111 + 2 * (iterations - 2)
        },
      )
    }
  }
}

///|
test "tuple result-block copy records the locals read by each captured lane" {
  for trailing in [false, true] {
    let source = tuple_alias_capture_source(
      2,
      0,
      false,
      false,
      false,
      trailing~,
    )
    let func = pass_test_lift_first_func(source)
    let analysis = tuple_optimization_analyze(func, @ir.use_def_build(func))
    let mut found_copy = false
    for group in analysis.groups {
      if group.lane_locals == [6, 7] && group.copy_source is Some(_) {
        found_copy = true
        @debug.assert_eq(group.copy_payload_locals, Some([2, 3]))
        assert_false(group.bad)
        assert_true(tuple_optimization_group_should_rewrite(group))
      }
    }
    assert_true(found_copy, msg="expected the captured result-block copy group")
  }
}
