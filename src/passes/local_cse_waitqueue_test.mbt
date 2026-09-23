///|
test "local cse treats waitqueue synchronization as nested reuse barriers" {
  let output = audit_run(local_cse_waitqueue_barrier_wat(), "local-cse")
  assert_true(@validate.validate_module(output) is Ok(_))
  let counts : Array[Int] = []
  for idx = 0; idx < 3; idx = idx + 1 {
    counts.push(
      audit_count(audit_body(output, index=idx), fn(instr) {
        instr is @lib.StructGet(@lib.TypeIdx(0U), @lib.U32(0U))
      }),
    )
  }
  @debug.assert_eq(counts, [2, 2, 2])
}

///|
fn local_cse_waitqueue_barrier_wat() -> String {
  let source =
    #|(module
    #|  (type $S (shared (struct (field (mut i32)))))
    #|  (global $q (ref (shared waitqueue)) (waitqueue.new))
    #|  (func (export "new") (param $s (ref $S)) (result i32)
    #|    (drop (i32.add
    #|      (struct.get $S 0 (local.get $s))
    #|      (i32.const 1)))
    #|    (block (result i32)
    #|      (drop (waitqueue.new))
    #|      (i32.add
    #|        (struct.get $S 0 (local.get $s))
    #|        (i32.const 1))))
    #|  (func (export "notify") (param $s (ref $S)) (result i32)
    #|    (drop (i32.add
    #|      (struct.get $S 0 (local.get $s))
    #|      (i32.const 1)))
    #|    (block (result i32)
    #|      (drop (waitqueue.notify (global.get $q) (i32.const 1)))
    #|      (i32.add
    #|        (struct.get $S 0 (local.get $s))
    #|        (i32.const 1))))
    #|  (func (export "wait") (param $s (ref $S)) (result i32)
    #|    (drop (i32.add
    #|      (struct.get $S 0 (local.get $s))
    #|      (i32.const 1)))
    #|    (block (result i32)
    #|      (drop (struct.wait $S 0
    #|        (local.get $s)
    #|        (global.get $q)
    #|        (i32.const 0)
    #|        (i64.const 0)))
    #|      (i32.add
    #|        (struct.get $S 0 (local.get $s))
    #|        (i32.const 1)))))
  source
}
