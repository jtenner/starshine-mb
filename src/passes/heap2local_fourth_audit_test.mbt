///|
test "fourth audit heap2local struct initializer" {
  let output = audit_run(
    "(module (type $S (struct (field i32))) (func (export \"f\") (param i32) (result i32) (local $s (ref null $S)) (local.set $s (struct.new $S (i32.const 7)))(drop (struct.get $S 0 (local.get $s)))(local.set $s (struct.new $S (struct.get $S 0 (local.get $s)))) (struct.get $S 0 (local.get $s))))",
    "heap2local",
  )
  @debug.assert_eq(fourth_audit_heap_eval(output, [1]), [7])
}

///|
test "fourth audit heap2local array initializer" {
  let t = @lib.TypeIdx::new(0U)
  let l = @lib.LocalIdx::new(1U)
  let input = pass_test_module_from_wat(
    "(module (type $a (array i32)) (func (param i32) (result i32) (local (ref null $a)) i32.const 0))",
  )
  let @lib.Func(locals, _) = input.code_sec.unwrap().0[0]
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        locals,
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::array_new_fixed(t, @lib.U32(1U)),
          @lib.Instruction::local_set(l),
          @lib.Instruction::local_get(l),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::array_get(t),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(l),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::array_get(t),
          @lib.Instruction::array_new_fixed(t, @lib.U32(1U)),
          @lib.Instruction::local_set(l),
          @lib.Instruction::local_get(l),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::array_get(t),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "heap2local")
  @debug.assert_eq(fourth_audit_heap_eval(output, [1]), [7])
}
