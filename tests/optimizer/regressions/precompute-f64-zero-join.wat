(module
 (func $choose (param i32) (result i32) (local f64)
  local.get 0
  if f64.const 0 local.set 1 else f64.const -0 local.set 1 end
  local.get 1 i64.reinterpret_f64 i64.const -9223372036854775808 i64.eq)
 (func (export "main") (result i32)
  i32.const 0 call $choose i32.const 10 i32.mul
  i32.const 1 call $choose i32.add))
