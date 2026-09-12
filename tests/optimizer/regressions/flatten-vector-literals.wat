(module (type $a (array (mut v128)))
 (func (export "main") (result i32)
  v128.const i32x4 7 2 3 4
  v128.const i32x4 9 6 7 8
  array.new_fixed $a 2 i32.const 1 array.get $a i32x4.extract_lane 0))
