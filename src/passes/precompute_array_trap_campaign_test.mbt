///|
test "campaign precompute preserves negative array allocation trap" {
  for pass in ["precompute", "precompute-propagate"] {
    let input = pass_test_module_from_wat(
      "(module (type $a (array i32)) (func (result i32) i32.const 0))",
    )
    let input = input.with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(-1),
            @lib.Instruction::array_new_default(@lib.TypeIdx::new(0U)),
            @lib.Instruction::ref_null(
              @lib.HeapType::abs(@lib.AbsHeapType::eq()),
            ),
            @lib.Instruction::ref_eq(),
          ]),
        ),
      ]),
    )
    let output = audit_run_module(input, pass)
    assert_true(
      audit_count(audit_body(output), fn(i) {
        i is @lib.ArrayNewDefault(_) || i is @lib.Unreachable
      }) >
      0,
      msg="\{pass}: \{audit_body(output)}",
    )
  }
}

///|
test "precompute preserves a dynamic array allocation trap under ref.is_null" {
  let input =
    #| (module
    #|   (type $a (array i32))
    #|   (func (export "run") (param i32) (result i32)
    #|     (ref.is_null (array.new_default $a (local.get 0)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["precompute"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected dynamic array precompute success, got \{err}")
  }
  assert_true(
    audit_count(audit_body(optimized), fn(i) { i is @lib.ArrayNewDefault(_) }) >
    0,
    msg="dynamic negative lengths must still trap",
  )
}
