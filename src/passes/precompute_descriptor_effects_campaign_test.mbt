///|
test "campaign precompute descriptor branch preserves operand effects" {
  let source =
    #|(module
    #| (rec (type $s (sub (descriptor $d) (struct)))
    #|      (type $d (sub (describes $s) (struct))))
    #| (global $desc (ref (exact $d)) (struct.new $d))
    #| (global $obj (ref $s) (struct.new_default_desc $s (global.get $desc)))
    #| (func (result (ref null $s))
    #|  (block $exit (result (ref null $s))
    #|   (br_on_cast_desc_eq $exit (ref null $s) (ref $s)
    #|    (global.get $obj)
    #|    (block $operand (result (ref (exact $d)))
    #|     (call $effect) (br $operand (global.get $desc))))))
    #| (func $effect unreachable))
  let output = audit_run(source, "precompute")
  assert_true(audit_count(audit_body(output), fn(i) { i is @lib.Call(_) }) > 0)
}
