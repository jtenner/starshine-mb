///|
test "round2 flatten keeps operand null check before later call" {
  let output = audit_run(
    (
      #|(module (import "m" "side" (func $side (result i32))) (import "m" "sink" (func $sink (param (ref func) i32))) (func (param funcref) local.get 0 ref.as_non_null call $side call $sink))
    ),
    "flatten",
  )
  let body = audit_body(output)
  let mut checked = false
  for i in body {
    if i is @lib.RefAsNonNull {
      checked = true
    }
    if i is @lib.Call(@lib.FuncIdx(0U)) {
      assert_true(checked)
    }
  }
}
