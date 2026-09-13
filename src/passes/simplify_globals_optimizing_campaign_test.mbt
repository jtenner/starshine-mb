///|
test "campaign simplify globals preserves exported allocation identity" {
  let output = audit_run(
    (
      #|(module (type $s (struct))
      #| (global $a (export "a") (ref $s) (struct.new_default $s))
      #| (global $b (export "b") (ref $s) (global.get $a)))
    ),
    "simplify-globals-optimizing",
  )
  let @lib.GlobalSec(globals) = output.global_sec.unwrap()
  let @lib.Global(_, @lib.Expr(init)) = globals[1]
  assert_true(init[0] is @lib.GlobalGet(_))
}
