///|
test "wast_to_module parses passive typed empty elem declarations" {
  let src =
    #|(module
    #|  (type $func (func))
    #|  (table 0 (ref null $func))
    #|  (elem (ref null $func)))
  let mod = match
    wast_to_module(src, filename="passive-typed-empty-elem.wast") {
    Ok(m) => m
    Err(e) => fail("expected passive typed empty elem parse success: \{e}")
  }
  match mod.fields {
    [TypeField(_), TableField(_), ElemField(elem)] => {
      assert_eq(elem.offset.length(), 0)
      assert_eq(elem.func_indices.length(), 0)
      assert_eq(elem.elem_exprs.length(), 0)
      match elem.elem_type {
        Some(TypedFuncRef(HeapTypeRef::TypeId("$func"))) => ()
        _ => fail("expected passive typed empty elem type hint")
      }
    }
    _ => fail("expected type, table, and elem fields in parsed module")
  }
}

///|
test "module_to_wast preserves passive typed empty elem declarations" {
  let src =
    #|(module
    #|  (type $func (func))
    #|  (table 0 (ref null $func))
    #|  (elem (ref null $func)))
  let mod = match
    wast_to_module(src, filename="passive-typed-empty-elem-print.wast") {
    Ok(m) => m
    Err(e) => fail("expected passive typed empty elem parse success: \{e}")
  }
  let text = match module_to_wast(mod) {
    Ok(t) => t
    Err(e) => fail("expected passive typed empty elem print success: \{e}")
  }
  assert_true(text.contains("(elem (ref null $func))"))
  match wast_to_module(text, filename="printed-passive-typed-empty-elem.wast") {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected passive typed empty elem printed output to parse back: \{e}",
      )
  }
}

///|
test "wast_to_binary_module lowers passive typed empty elem declarations" {
  let src =
    #|(module
    #|  (type $func (func))
    #|  (table 0 (ref null $func))
    #|  (elem (ref null $func)))
  let lowered = match
    wast_to_binary_module(src, filename="passive-typed-empty-elem-lower.wast") {
    Ok(m) => m
    Err(e) => fail("expected passive typed empty elem lowering success: \{e}")
  }
  match lowered.elem_sec {
    Some(@lib.ElemSec([elem])) =>
      assert_eq(
        elem,
        @lib.Elem::new(
          @lib.ElemMode::passive(),
          @lib.ElemKind::typed_exprs(
            @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
            [],
          ),
        ),
      )
    _ => fail("expected lowered passive typed empty elem section")
  }
  match @validate.validate_module(lowered) {
    Ok(_) => ()
    Err(e) =>
      fail("expected passive typed empty elem fixture to validate: \{e}")
  }
}
