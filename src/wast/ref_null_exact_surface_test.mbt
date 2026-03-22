///|
test "wast_to_binary_module validates exact ref.null through ref.get_desc" {
  let src =
    #|(module
    #|  (rec
    #|    (type $a (descriptor $b) (struct))
    #|    (type $b (describes $a) (struct))
    #|  )
    #|  (func (result (ref (exact $b)))
    #|    (ref.get_desc $a (ref.null (exact $a)))))
  let lowered = match
    wast_to_binary_module(src, filename="exact-ref-null-desc-fixture.wast") {
    Ok(m) => m
    Err(e) => fail("expected exact ref.null descriptor fixture to lower: \{e}")
  }
  match @validate.validate_module(lowered) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected exact ref.null descriptor fixture to validate: \{@validate.validation_error_message(e)}",
      )
  }
}

///|
test "wast_text_binary_roundtrip preserves exact ref.null immediates" {
  let src =
    #|(module
    #|  (type $a (struct))
    #|  (func (result (ref null (exact $a)))
    #|    (ref.null (exact $a))))
  let (_, decoded) = match
    wast_text_binary_roundtrip(
      src,
      filename="exact-ref-null-roundtrip-fixture.wast",
    ) {
    Ok(v) => v
    Err(e) => fail("expected exact ref.null roundtrip success: \{e}")
  }
  match decoded.code_sec {
    Some(
      @lib.CodeSec([
        @lib.Func(
          _,
          @lib.Expr([
            @lib.RefNull(
              @lib.HeapTypeRefType(
                true,
                true,
                @lib.HeapType(@lib.TypeIdx(0U)),
              ),
            ),
          ]),
        ),
      ])
    ) => ()
    _ => fail("expected decoded exact ref.null immediate")
  }
}
