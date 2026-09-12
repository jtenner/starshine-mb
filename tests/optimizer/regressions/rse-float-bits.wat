(module
 (func (export "main") (result i32) (local $f f32) (local $d f64)
  f32.const -0 local.set $f
  f64.const -0 local.set $d
  local.get $f i32.reinterpret_f32 i32.const -2147483648 i32.eq
  local.get $d i64.reinterpret_f64 i64.const -9223372036854775808 i64.eq
  i32.and
  f32.const nan:0x400001 local.set $f
  f32.const nan:0x400002 local.set $f
  local.get $f i32.reinterpret_f32 i32.const 2143289346 i32.eq
  i32.and
  f64.const nan:0x8000000000001 local.set $d
  f64.const nan:0x8000000000002 local.set $d
  local.get $d i64.reinterpret_f64 i64.const 9221120237041090562 i64.eq
  i32.and))
