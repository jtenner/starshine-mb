///|
test "campaign precompute preserves null descriptor trap" {
  let output = audit_run(
    (
      #|(module
      #| (rec (type $box (descriptor $desc) (struct))
      #|      (type $desc (describes $box) (struct)))
      #| (func (result i32)
      #|  (ref.eq (struct.new_default_desc $box (ref.null (exact $desc)))
      #|          (ref.null eq))))
    ),
    "precompute",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.StructNewDefaultDesc(_) || i is @lib.Unreachable
    }) >
    0,
  )
}
