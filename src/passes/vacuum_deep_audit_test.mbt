///|
test "deep audit vacuum discards excess stack values at a terminal owner branch" {
  let output = audit_run(
    "(module (func (local i32) (block i32.const 1 local.set 0 i32.const 42 br 0)))",
    "vacuum",
  )
  assert_true(@validate.validate_module(output) is Ok(_))
}

///|
test "deep audit vacuum prunes a struct type made unused by body cleanup" {
  // Saved seven-pass case 31 reaches Vacuum with a fresh struct allocation
  // referenced only by removable local traffic. Once Vacuum removes that
  // traffic, the struct type is dead; the function signature and typed local
  // continue to reference the distinct function type at index zero.
  let wat =
    #|(module
    #|  (type (func))
    #|  (type (struct (field (mut i32)) (field eqref)))
    #|  (func (export "main") (type 0)
    #|    (local i32 (ref null 0) anyref)
    #|    struct.new_default 1
    #|    local.set 2
    #|    local.get 2
    #|    drop
    #|    return
    #|    local.get 2
    #|    drop)
    #|  (start 0))
  let output = audit_run(wat, "vacuum")
  assert_true(@validate.validate_module(output) is Ok(_))
  match output.type_sec {
    Some(@lib.TypeSec([@lib.SingleRecType(subtype)])) =>
      assert_true(subtype.get_comptype() is @lib.FuncCompType(_, _))
    other =>
      fail(
        "expected only the live function type after Vacuum, got \{@debug.to_string(other)}",
      )
  }
  match output.func_sec {
    Some(@lib.FuncSec([type_idx])) =>
      @debug.assert_eq(type_idx, @lib.TypeIdx::new(0U))
    other =>
      fail("expected one remapped function, got \{@debug.to_string(other)}")
  }
}

///|
test "deep audit vacuum type pruning excludes opaque position metadata" {
  // Boundary/fail-closed: opaque code metadata and relocation sections can
  // contain byte offsets or type indices that the simple-type remapper cannot
  // update. Vacuum may still perform its ordinary body cleanup, but the new
  // whole-module type-pruning step must not run while such a section survives.
  let wat =
    #|(module
    #|  (type (func))
    #|  (type (struct (field (mut i32)) (field eqref)))
    #|  (func (type 0)
    #|    (local i32 (ref null 0) anyref)
    #|    struct.new_default 1
    #|    local.set 2
    #|    local.get 2
    #|    drop))
  let input = pass_test_module_from_wat(wat).with_custom_secs([
    @lib.CustomSec::new(@lib.Name::new("metadata.code.branch_hint"), b"\x00"),
  ])
  let output = audit_run_module(input, "vacuum")
  assert_true(@validate.validate_module(output) is Ok(_))
  assert_eq(output.custom_secs, input.custom_secs)
  assert_eq(output.type_sec.unwrap().0.length(), 2)
}
