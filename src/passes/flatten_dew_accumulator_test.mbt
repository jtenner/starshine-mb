///|
fn flatten_dew_accumulator_execute(func : @lib.Func, input : Int) -> Int raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = func
  let locals = Array::make(body_locals.length() + 1, 0)
  locals[0] = input
  let stack : Array[Int] = []
  let mut fuel = 3000
  fn execute(instrs : Array[@lib.Instruction]) -> Int? raise {
    for instr in instrs {
      fuel -= 1
      assert_true(
        fuel >= 0,
        msg="flatten accumulator exceeded 3000 instructions",
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
          assert_true(block_type is @lib.VoidBlockType)
          let base = stack.length()
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
          fail("unexpected flatten accumulator instruction or trap: \{instr}")
      }
    }
    None
  }
  let exit = execute(body)
  assert_true(exit == None || exit == Some(-1))
  @debug.assert_eq(stack.length(), 1)
  stack[0]
}
