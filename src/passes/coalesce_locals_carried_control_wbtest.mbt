///|
fn cl_carried_control_execute(func : @lib.Func) -> Int raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = func
  let locals = Array::make(body_locals.length(), 0)
  let stack : Array[Int] = []
  let mut fuel = 300
  fn execute(instrs : Array[@lib.Instruction]) -> Int? raise {
    for instr in instrs {
      fuel -= 1
      assert_true(
        fuel >= 0,
        msg="coalesce carried control exceeded 300 instructions",
      )
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
        @lib.Call(@lib.FuncIdx(index)) if index == 0U || index == 1U => {
          let value = stack.pop().unwrap()
          stack.push(if index == 0U { value + 1 } else { value })
        }
        @lib.I32Add | @lib.I32GtS => {
          let rhs = stack.pop().unwrap()
          let lhs = stack.pop().unwrap()
          stack.push(
            match instr {
              @lib.I32Add => lhs + rhs
              _ => if lhs > rhs { 1 } else { 0 }
            },
          )
        }
        @lib.Br(@lib.LabelIdx(depth)) => return Some(depth.to_int())
        @lib.BrIf(@lib.LabelIdx(depth)) =>
          if stack.pop().unwrap() != 0 {
            return Some(depth.to_int())
          }
        @lib.Return => return Some(-1)
        @lib.Block(block_type, @lib.Expr(nested)) => {
          let keep = if block_type is @lib.VoidBlockType { 0 } else { 1 }
          let base = stack.length() + keep
          match execute(nested) {
            Some(-1) => return Some(-1)
            Some(depth) if depth > 0 => return Some(depth - 1)
            Some(_) =>
              while stack.length() > base {
                ignore(stack.pop())
              }
            None => ()
          }
        }
        @lib.Loop(block_type, @lib.Expr(nested)) => {
          assert_true(block_type is @lib.VoidBlockType)
          let base = stack.length()
          let mut again = true
          while again {
            match execute(nested) {
              Some(-1) => return Some(-1)
              Some(0) =>
                while stack.length() > base {
                  ignore(stack.pop())
                }
              Some(depth) => return Some(depth - 1)
              None => again = false
            }
          }
        }
        @lib.If(block_type, then_body, else_body) => {
          assert_true(block_type is @lib.VoidBlockType)
          let condition = stack.pop().unwrap()
          let base = stack.length()
          match
            execute(if condition != 0 { then_body } else { else_body.or([]) }) {
            Some(-1) => return Some(-1)
            Some(depth) if depth > 0 => return Some(depth - 1)
            Some(_) =>
              while stack.length() > base {
                ignore(stack.pop())
              }
            None => ()
          }
        }
        _ =>
          fail(
            "unexpected coalesce carried control instruction or trap: \{instr}",
          )
      }
    }
    None
  }
  let exit = execute(body)
  assert_true(exit == None || exit == Some(-1))
  @debug.assert_eq(stack.length(), 1)
  stack[0]
}

///|
test "coalesce-locals keeps a source slot live across a carried call block" {
  for initial in [-5, 0, 10, 41] {
    let input = pass_test_module_from_wat(
      "(module (func $inc (param i32) (result i32) local.get 0 i32.const 1 i32.add) " +
      "(func $id (param i32) (result i32) local.get 0) " +
      "(func (export \"run\") (result i32) (local i32 i32 i32 i32) " +
      "i32.const \{initial} local.set 0 block (result i32) " +
      "local.get 0 call $inc local.tee 1 drop loop nop end local.get 1 br 0 end " +
      "local.get 0 call $id local.set 2 local.tee 3 local.get 2 i32.add))",
    )
    for pass_name in ["coalesce-locals", "coalesce-locals-cfg"] {
      let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
        pass_name,
      ]).unwrap()
      ignore(@validate.validate_module(output).unwrap())
      let before = input.code_sec.unwrap().0[2]
      let after = output.code_sec.unwrap().0[2]
      @debug.assert_eq(cl_carried_control_execute(before), 2 * initial + 1)
      @debug.assert_eq(cl_carried_control_execute(after), 2 * initial + 1)
      let @lib.Func(locals, _) = after
      assert_true(locals.length() < 4, msg="keep profitable local compaction")
    }
  }
}
