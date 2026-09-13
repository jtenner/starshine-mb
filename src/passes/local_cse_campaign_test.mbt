///|
test "campaign local-cse retains memory64 select type" {
  let output = audit_run(
    (
      #|(module (memory i64 1)
      #| (func (param i32) (result i64)
      #|  (drop (select (memory.size) (memory.size) (local.get 0)))
      #|  (select (memory.size) (memory.size) (local.get 0))))
    ),
    "local-cse",
  )
  assert_true(@validate.validate_module(output) is Ok(_))
}

///|
test "campaign local-cse retains annotated select reference type" {
  let output = audit_run(
    (
      #|(module (func (param i32) (result eqref)
      #| (drop (select (result eqref) (ref.null i31) (ref.null struct) (local.get 0)))
      #| (select (result eqref) (ref.null i31) (ref.null struct) (local.get 0))))
    ),
    "local-cse",
  )
  assert_true(@validate.validate_module(output) is Ok(_))
}

///|
test "campaign local-cse retains concrete function reference" {
  let output = audit_run(
    (
      #|(module (type $t (func (result i32)))
      #| (func $f (type $t) i32.const 7) (elem declare func $f)
      #| (func (export "f") (result i32)
      #|  (drop (ref.as_non_null (ref.func $f)))
      #|  (call_ref $t (ref.as_non_null (ref.func $f)))))
    ),
    "local-cse",
  )
  assert_true(@validate.validate_module(output) is Ok(_))
}
