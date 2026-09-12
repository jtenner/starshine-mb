(module
 (global $value (mut i32) (i32.const 7))
 (func $pair (result i32 i32)
  global.get $value i32.const 3
  i32.const 9 global.set $value nop)
 (func (export "main") (result i32) (local $a i32) (local $b i32)
  call $pair local.set $b local.set $a
  local.get $a i32.const 10 i32.mul local.get $b i32.add))
