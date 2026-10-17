///|
fn cmd_h2l_straightline_nonnull_source() -> String {
  "(module (type $Box (struct (field i32))) " +
  "(type $S (struct (field (ref $Box)) (field (ref $Box)) (field (ref $Box)))) " +
  "(func (export \"run\") (param $a (ref $Box)) (param $b (ref $Box)) " +
  "(param $c (ref $Box)) (param $replacement (ref $Box)) " +
  "(result (ref $Box) (ref $Box) (ref $Box)) (local $owner (ref null $S)) " +
  "(local.set $owner (struct.new $S (local.get $a) (local.get $b) (local.get $c))) " +
  "(local.set $owner (struct.new $S (local.get $replacement) " +
  "(struct.get $S 0 (local.get $owner)) (struct.get $S 1 (local.get $owner)))) " +
  "(struct.get $S 0 (local.get $owner)) (struct.get $S 1 (local.get $owner)) " +
  "(struct.get $S 2 (local.get $owner))))"
}

///|
// Positive values identify distinct non-null reference arguments. Owner objects
// use separate ids; every unsupported opcode and every null assertion fails.
fn cmd_h2l_straightline_nonnull_values(
  mod_ : @lib.Module,
  args : Array[Int32],
) -> Array[Int32] raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = mod_.code_sec.unwrap().0[0]
  let locals = Array::make(args.length() + body_locals.length(), 0)
  for index in 0..<args.length() {
    locals[index] = args[index]
  }
  let objects : Array[Array[Int32]] = []
  let stack : Array[Int32] = []
  let mut steps = 0
  fn execute(instrs : Array[@lib.Instruction]) -> Unit raise {
    for instr in instrs {
      steps += 1
      assert_true(steps <= 256)
      match instr {
        @lib.Nop => ()
        @lib.LocalGet(@lib.LocalIdx(index)) =>
          stack.push(locals[index.to_int()])
        @lib.LocalSet(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = stack.pop().unwrap()
        @lib.LocalTee(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = stack[stack.length() - 1]
        @lib.Drop => ignore(stack.pop().unwrap())
        @lib.RefNull(_) => stack.push(0)
        @lib.RefAsNonNull =>
          assert_true(
            stack[stack.length() - 1] != 0,
            msg="cleanup read an uninitialized non-null field",
          )
        @lib.StructNew(_) => {
          let fields = Array::make(3, 0)
          for field = 2; field >= 0; field = field - 1 {
            fields[field] = stack.pop().unwrap()
          }
          objects.push(fields)
          stack.push(99 + objects.length())
        }
        @lib.StructGet(_, @lib.U32(field)) => {
          let reference = stack.pop().unwrap()
          assert_true(reference >= 100 && reference < 100 + objects.length())
          stack.push(objects[reference - 100][field.to_int()])
        }
        @lib.Block(_, @lib.Expr(nested)) => execute(nested)
        _ => fail("unexpected straight-line reference instruction: \{instr}")
      }
    }
  }
  execute(body)
  stack
}

///|
test "command heap2local straight-line non-null old reads survive local cleanup" {
  let input = @passes.pass_test_module_from_wat(
    cmd_h2l_straightline_nonnull_source(),
  )
  let output = optimize_module_with_pass_flags(
    input,
    ["heap2local", "simplify-locals", "coalesce-locals", "vacuum"],
    OptimizeOptions::new(),
  ).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  for args in [[1, 2, 3, 4], [4, 1, 2, 3], [2, 2, 3, 4]] {
    let expected = [args[3], args[0], args[1]]
    @debug.assert_eq(cmd_h2l_straightline_nonnull_values(input, args), expected)
    @debug.assert_eq(
      cmd_h2l_straightline_nonnull_values(output, args),
      expected,
    )
  }
  @debug.assert_eq(
    cmd_deep_audit_count(cmd_deep_audit_body(output), fn(instr) {
      instr is @lib.StructNew(_) || instr is @lib.StructGet(_, _)
    }),
    0,
  )
}
