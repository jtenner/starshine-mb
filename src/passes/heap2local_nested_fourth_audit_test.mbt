///|
test "fourth audit heap2local struct nested" {
  let output = audit_run(
    "(module (type $S (struct (field i32))) (func (export \"f\") (param i32) (result i32) (local $s (ref null $S)) (local.set $s (struct.new $S (i32.const 7)))(if (local.get 0) (then (local.set $s (struct.new $S (i32.const 9))))) (struct.get $S 0 (local.get $s))))",
    "heap2local",
  )
  @debug.assert_eq(fourth_audit_heap_eval(output, [1]), [9])
}

///|
test "fourth audit heap2local array nested" {
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
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::i32_const(@lib.I32(9)),
              @lib.Instruction::array_new_fixed(t, @lib.U32(1U)),
              @lib.Instruction::local_set(l),
            ],
            None,
          ),
          @lib.Instruction::local_get(l),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::array_get(t),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "heap2local")
  @debug.assert_eq(fourth_audit_heap_eval(output, [1]), [9])
}
