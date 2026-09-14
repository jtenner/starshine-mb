///|
test "deep audit coalesce-locals keeps default local value on nullable branch before sole tee" {
  let pass = "coalesce-locals"
  let output = audit_run(
    (
      #|(module (func (param $p i32) (param $r externref) (result i32) (local $t i32)
      #| (block local.get $r br_on_null 0 drop
      #| i32.const 7 local.tee $t i32.const 1 i32.add drop)
      #| local.get $t))
    ),
    pass,
  )
  let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
  // The null edge reads the default zero, which cannot alias arbitrary $p.
  assert_true(locals.length() > 0)
}

///|
test "deep audit coalesce-locals-cfg keeps default local value on nullable branch before sole tee" {
  let pass = "coalesce-locals-cfg"
  let output = audit_run(
    (
      #|(module (func (param $p i32) (param $r externref) (result i32) (local $t i32)
      #| (block local.get $r br_on_null 0 drop
      #| i32.const 7 local.tee $t i32.const 1 i32.add drop)
      #| local.get $t))
    ),
    pass,
  )
  let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
  // The null edge reads the default zero, which cannot alias arbitrary $p.
  assert_true(locals.length() > 0)
}
