///|
test "Binaryen 132 call_ref and return_call_ref accept bare signature indices" {
  for operation in ["call_ref", "return_call_ref"] {
    let source = "(module (type $sig (func (result i32))) (elem declare func $target) (func $target (type $sig) (result i32) (i32.const 7)) (func (result i32) (\{operation} $sig (ref.func $target))))"
    let mod_ = match wast_to_binary_module(source) {
      Ok(mod_) => mod_
      Err(err) => fail("reference call parsing: \{err}")
    }
    let expected = if operation == "call_ref" {
      @lib.Instruction::call_ref(@lib.TypeIdx::new(0U))
    } else {
      @lib.Instruction::return_call_ref(@lib.TypeIdx::new(0U))
    }
    @debug.assert_eq(
      mod_.elem_sec,
      Some(
        @lib.ElemSec::new([
          @lib.Elem::new(
            @lib.ElemMode::declarative(),
            @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
          ),
        ]),
      ),
    )
    match mod_.code_sec {
      Some(@lib.CodeSec([_, @lib.Func(_, @lib.Expr(body))])) =>
        @debug.assert_eq(body, [
          @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
          expected,
        ])
      _ => fail("expected two reference-call functions")
    }
  }
}

///|
test "declarative function elements preserve mode through WAST printing" {
  for contents in ["", "$target"] {
    let source = "(module (func $target) (elem $declaration declare func \{contents}))"
    let parsed = wast_to_module(source).unwrap()
    let printed = module_to_wast(parsed).unwrap()
    assert_true(printed.contains("declare func"))
    let original = wast_to_binary_module(source).unwrap()
    let roundtrip = wast_to_binary_module(printed).unwrap()
    @debug.assert_eq(roundtrip.elem_sec, original.elem_sec)
  }
}

///|
test "declarative typed element expressions preserve types and indices" {
  for element_type in ["funcref", "(ref null $sig)"] {
    let source = "(module (type $sig (func)) (func $target (type $sig)) (elem declare \{element_type} (ref.func $target)))"
    let original = match wast_to_binary_module(source) {
      Ok(mod_) => mod_
      Err(err) => fail("typed declaration: \{err}")
    }
    let @lib.ElemSec(elems) = original.elem_sec.unwrap()
    assert_true(
      elems[0]
      is @lib.Elem(
        @lib.Declarative,
        @lib.TypedExprsElemKind(
          _,
          [@lib.Expr([@lib.RefFunc(@lib.FuncIdx(0U))])]
        )
      ),
    )
    let printed = module_to_wast(wast_to_module(source).unwrap()).unwrap()
    @debug.assert_eq(
      wast_to_binary_module(printed).unwrap().elem_sec,
      original.elem_sec,
    )
  }
}
