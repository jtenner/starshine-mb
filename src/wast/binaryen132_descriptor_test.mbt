///|
test "Binaryen 132 descriptor branch text preserves both reference annotations" {
  for operation in ["br_on_cast_desc_eq", "br_on_cast_desc_eq_fail"] {
    let source = "(module (rec (type $s (sub (descriptor $d) (struct))) (type $d (sub (describes $s) (struct)))) (func (param (ref null $s) (ref null (exact $d))) (result (ref null $s)) (block $exit (result (ref null $s)) (\{operation} $exit (ref null $s) (ref (exact $s)) (local.get 0) (local.get 1)))))"
    let mod_ = match wast_to_binary_module(source) {
      Ok(mod_) => mod_
      Err(err) => fail("descriptor branch text: \{err}")
    }
    let expected_source = @lib.RefType::new(
      true,
      @lib.HeapType::new(@lib.TypeIdx::new(0U)),
    )
    let expected_target = @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      exact=true,
    )
    let expected = if operation == "br_on_cast_desc_eq" {
      @lib.Instruction::br_on_cast_desc_eq(
        @lib.LabelIdx::new(0U),
        expected_source,
        expected_target,
      )
    } else {
      @lib.Instruction::br_on_cast_desc_eq_fail(
        @lib.LabelIdx::new(0U),
        expected_source,
        expected_target,
      )
    }
    let @lib.Func(_, @lib.Expr(body)) = mod_.code_sec.unwrap().0[0]
    match body[0] {
      @lib.Block(_, @lib.Expr(body)) =>
        @debug.assert_eq(body, [
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          expected,
        ])
      _ => fail("expected descriptor branch block")
    }
    let parsed = match wast_to_module(source) {
      Ok(value) => value
      Err(err) => fail(err.to_string())
    }
    let rendered = match module_to_wast(parsed) {
      Ok(value) => value
      Err(err) => fail(err.to_string())
    }
    let roundtrip = match wast_to_binary_module(rendered) {
      Ok(value) => value
      Err(err) => fail(err)
    }
    @debug.assert_eq(roundtrip.code_sec, mod_.code_sec)
  }
}
