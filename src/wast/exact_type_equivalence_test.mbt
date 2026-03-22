///|
test "wast_to_binary_module validates structurally equivalent exact struct refs" {
  let src =
    #|(module
    #|  (type (struct))
    #|  (type (struct))
    #|  (type (struct (field (ref 0))))
    #|  (type (struct (field (ref 1))))
    #|  (func (param (ref (exact 2))) (result (ref (exact 3)))
    #|    (local.get 0)))
  let lowered = match
    wast_to_binary_module(src, filename="exact-struct-equivalence-fixture.wast") {
    Ok(m) => m
    Err(e) => fail("expected exact struct equivalence fixture to lower: \{e}")
  }
  match @validate.validate_module(lowered) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected exact struct equivalence fixture to validate: \{@validate.validation_error_message(e)}",
      )
  }
}

///|
test "wast_to_binary_module validates structurally equivalent exact func refs" {
  let src =
    #|(module
    #|  (type (struct))
    #|  (type (struct))
    #|  (type (func (param (ref 0))))
    #|  (type (func (param (ref 1))))
    #|  (func (param (ref (exact 3))) (result (ref (exact 2)))
    #|    (local.get 0)))
  let lowered = match
    wast_to_binary_module(src, filename="exact-func-equivalence-fixture.wast") {
    Ok(m) => m
    Err(e) => fail("expected exact func equivalence fixture to lower: \{e}")
  }
  match @validate.validate_module(lowered) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected exact func equivalence fixture to validate: \{@validate.validation_error_message(e)}",
      )
  }
}
