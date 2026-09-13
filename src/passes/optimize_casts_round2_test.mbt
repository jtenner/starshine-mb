///|
test "round2 optimize casts retains producer effects in folded test" {
  let input = pass_test_module_from_wat(
    "(module (type $S (struct)) (import \"m\" \"produce\" (func $produce (result (ref $S)))) (func (result i32) unreachable))",
  ).with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          @lib.Instruction::ref_test(
            false,
            @lib.HeapType::new(@lib.TypeIdx::new(0U)),
          ),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "optimize-casts")
  assert_eq(audit_count(audit_body(output), fn(i) { i is @lib.Call(_) }), 1)
}
