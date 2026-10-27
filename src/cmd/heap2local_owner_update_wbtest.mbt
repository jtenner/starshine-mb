///|
// This bounded executor checks the scalar instructions emitted for the numeric
// owner-update fixtures. Any unexpected opcode fails the regression.
fn cmd_heap2local_owner_values(
  mod_ : Module,
  flag : Int32,
) -> Array[Int32] raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = mod_.code_sec.unwrap().0[0]
  let locals = Array::make(1 + body_locals.length(), 0)
  locals[0] = flag
  let stack : Array[Int32] = []
  let mut steps = 0
  fn execute(instrs : Array[@lib.Instruction]) -> Unit raise {
    for instr in instrs {
      steps += 1
      assert_true(steps <= 256)
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
        @lib.Block(_, @lib.Expr(nested)) => execute(nested)
        @lib.If(_, yes, no) => {
          let condition = stack.pop().unwrap()
          execute(if condition != 0 { yes } else { no.unwrap_or([]) })
        }
        _ => fail("unsupported owner-update regression instruction: \{instr}")
      }
    }
  }
  execute(body)
  stack
}

///|
fn cmd_heap2local_owner_fixture(second_fields : String) -> String {
  "(module (type $S (struct (field i32) (field i32))) " +
  "(func (export \"run\") (param $flag i32) (result i32 i32) " +
  "(local $x (ref null $S)) " +
  "(local.set $x (if (result (ref $S)) (local.get $flag) " +
  "(then (struct.new $S (i32.const 10) (i32.const 20))) " +
  "(else (struct.new $S (i32.const 11) (i32.const 21))))) " +
  "(local.set $x (if (result (ref $S)) (local.get $flag) " +
  "(then (struct.new $S " +
  second_fields +
  ")) " +
  "(else (struct.new $S " +
  second_fields +
  ")))) " +
  "(struct.get $S 0 (local.get $x)) (struct.get $S 1 (local.get $x))))"
}

///|
test "command heap2local keeps old owner values until constructor publication" {
  let output = cmd_deep_audit_run(
    cmd_heap2local_owner_fixture(
      "(i32.const 100) (struct.get $S 0 (local.get $x))",
    ),
    "heap2local",
  )
  assert_true(@validate.validate_module(output) is Ok(_))
  @debug.assert_eq(cmd_heap2local_owner_values(output, 0), [100, 11])
  @debug.assert_eq(cmd_heap2local_owner_values(output, 1), [100, 10])
}

///|
test "command heap2local swaps fields from the previous owner" {
  let output = cmd_deep_audit_run(
    cmd_heap2local_owner_fixture(
      "(struct.get $S 1 (local.get $x)) (struct.get $S 0 (local.get $x))",
    ),
    "heap2local",
  )
  @debug.assert_eq(cmd_heap2local_owner_values(output, 0), [21, 11])
  @debug.assert_eq(cmd_heap2local_owner_values(output, 1), [20, 10])
}
