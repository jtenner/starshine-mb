///|
fn assert_implicit_functype_is_distinct_from_grouped_match(
  src : String,
  expected_grouped_type : UInt,
) -> Unit raise {
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) =>
      fail("expected recursive-group implicit functype lowering success: \{e}")
  }
  match lowered.func_sec {
    Some(@lib.FuncSec([@lib.TypeIdx::TypeIdx(2U)])) => ()
    _ => fail("expected implicit function type at flat type index 2")
  }
  let env = @validate.Env::new().with_module(lowered)
  let actual = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(2U)),
      exact=true,
    ),
  )
  let expected = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(expected_grouped_type)),
    ),
  )
  match lowered.global_sec {
    Some(@lib.GlobalSec([@lib.Global(@lib.GlobalType(global_type, false), _)])) =>
      @debug.assert_eq(global_type, expected)
    _ => fail("expected one immutable typed function-reference global")
  }
  assert_false(@validate.Match::matches(actual, expected, env))
  match @validate.validate_module(lowered) {
    Ok(_) => fail("expected grouped function reference mismatch to be rejected")
    Err(e) =>
      assert_true(
        @validate.validation_error_message(e).contains("type mismatch"),
      )
  }
}

///|
test "wast_to_binary_module does not reuse first matching function in rec group" {
  let src =
    #|(module
    #|  (rec (type $ft (func)) (type (func)))
    #|  (func $f)
    #|  (global (ref $ft) (ref.func $f)))
    #|
  assert_implicit_functype_is_distinct_from_grouped_match(src, 0U)
}

///|
test "wast_to_binary_module does not reuse later matching function in rec group" {
  let src =
    #|(module
    #|  (rec (type (func)) (type $ft (func)))
    #|  (func $f)
    #|  (global (ref $ft) (ref.func $f)))
    #|
  assert_implicit_functype_is_distinct_from_grouped_match(src, 1U)
}

///|
test "wast recursive groups match when corresponding internal references match" {
  let src =
    #|(module
    #|  (rec (type $f1 (func)) (type (struct (field (ref $f1)))))
    #|  (rec (type $f2 (func)) (type (struct (field (ref $f2)))))
    #|  (func $f (type $f2))
    #|  (global (ref $f1) (ref.func $f)))
    #|
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) => fail("expected equivalent recursive groups to lower: \{e}")
  }
  match @validate.validate_module(lowered) {
    Ok(_) => ()
    Err(e) => fail("expected equivalent recursive groups to validate: \{e}")
  }
}

///|
test "wast recursive groups reject external reference in place of self reference" {
  let src =
    #|(module
    #|  (rec (type $f1 (func)) (type (struct (field (ref $f1)))))
    #|  (rec (type $f2 (func)) (type (struct (field (ref $f1)))))
    #|  (func $f (type $f2))
    #|  (global (ref $f1) (ref.func $f)))
    #|
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) => fail("expected distinct recursive groups to lower: \{e}")
  }
  match @validate.validate_module(lowered) {
    Ok(_) =>
      fail("expected distinct recursive group function types to be rejected")
    Err(e) =>
      assert_true(
        @validate.validation_error_message(e).contains("type mismatch"),
      )
  }
}

///|
test "wast_to_binary_module appends implicit functypes after rec groups at flat type indices" {
  let src =
    #|(module
    #|  (rec
    #|    (type $a (struct))
    #|    (type $b (struct)))
    #|  (func (param (ref $a)) (result (ref null $b))
    #|    (ref.null $b)))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) =>
      fail("expected implicit functype after rec-group lowering success: \{e}")
  }
  match lowered.func_sec {
    Some(@lib.FuncSec([@lib.TypeIdx::TypeIdx(2U)])) => ()
    _ => fail("expected func section to point at flat type index 2")
  }
  match @validate.validate_module(lowered) {
    Ok(_) => ()
    Err(e) =>
      fail("expected rec-group implicit functype module to validate: \{e}")
  }
}
