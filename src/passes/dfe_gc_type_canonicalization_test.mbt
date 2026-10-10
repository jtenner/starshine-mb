///|
test "DFE canonicalizes transitive GC types before merging private bodies" {
  // Binary-decoded fixture: local WAT parser lacks array.get.
  // (module
  //  (type $a (struct (field i32)))
  //  (type $b (struct (field i32)))
  //  (type $arr_a (array (mut (ref null $a))))
  //  (type $arr_b (array (mut (ref null $b))))
  //  (type $fa (func (param (ref null $arr_a)) (result i32)))
  //  (type $fb (func (param (ref null $arr_b)) (result i32)))
  //  (func $left (type $fa) (param (ref null $arr_a)) (result i32)
  //    local.get 0 i32.const 0 array.get $arr_a struct.get $a 0)
  //  (func $right (type $fb) (param (ref null $arr_b)) (result i32)
  //    local.get 0 i32.const 0 array.get $arr_b struct.get $b 0)
  //  (func (export "run") (result i32)
  //    i32.const 7 struct.new $a array.new_fixed $arr_a 1 call $left
  //    i32.const 11 struct.new $b array.new_fixed $arr_b 1 call $right i32.add))
  let input = @binary.decode_module(b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x21\x07\x5f\x01\x7f\x00\x5f\x01\x7f\x00\x5e\x63\x00\x01\x5e\x63\x01\x01\x60\x01\x63\x02\x01\x7f\x60\x01\x63\x03\x01\x7f\x60\x00\x01\x7f\x03\x04\x03\x04\x05\x06\x07\x07\x01\x03\x72\x75\x6e\x00\x02\x0a\x37\x03\x0d\x00\x20\x00\x41\x00\xfb\x0b\x02\xfb\x02\x00\x00\x0b\x0d\x00\x20\x00\x41\x00\xfb\x0b\x03\xfb\x02\x01\x00\x0b\x19\x00\x41\x07\xfb\x00\x00\xfb\x08\x02\x01\x10\x00\x41\x0b\xfb\x00\x01\xfb\x08\x03\x01\x10\x01\x6a\x0b\x00\x34\x04\x6e\x61\x6d\x65\x01\x0e\x02\x00\x04\x6c\x65\x66\x74\x01\x05\x72\x69\x67\x68\x74\x04\x1d\x06\x00\x01\x61\x01\x01\x62\x02\x05\x61\x72\x72\x5f\x61\x03\x05\x61\x72\x72\x5f\x62\x04\x02\x66\x61\x05\x02\x66\x62").unwrap()
  assert_true(@validate.validate_module(input) is Ok(_))
  let before = @binary.encode_module(input).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "duplicate-function-elimination",
  ]).unwrap()
  @debug.assert_eq(output.func_sec.unwrap().0.length(), 2)
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 4)
  @debug.assert_eq(output.export_sec.unwrap().0.length(), 1)
  assert_true(@validate.validate_module(output) is Ok(_))
  assert_true(@binary.encode_module(output).unwrap().length() < before.length())
  @debug.assert_eq(@binary.encode_module(input).unwrap(), before)
}
