///|
test "Binaryen 132 waitqueue text authors shared queues and explicit wait operands" {
  let source =
    #|(module (type $S (shared (struct (field (mut i32)))))
    #| (global $q (mut (ref null (shared waitqueue))) (waitqueue.new))
    #| (func (param (ref null $S)) (result i32)
    #|   (drop (waitqueue.notify (global.get $q) (i32.const 1)))
    #|   (struct.wait $S 0 (local.get 0) (global.get $q) (i32.const 0) (i64.const 1))))
  let input = wast_to_binary_module(source).unwrap()
  let text = module_to_wast(wast_to_module(source).unwrap()).unwrap()
  assert_true(text.contains("waitqueue.new"))
  assert_true(text.contains("waitqueue.notify"))
  assert_true(text.contains("struct.wait"))
  let roundtrip = wast_to_binary_module(text).unwrap()
  @debug.assert_eq(roundtrip.code_sec, input.code_sec)
  @debug.assert_eq(roundtrip.global_sec, input.global_sec)
}
