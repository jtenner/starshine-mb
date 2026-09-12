(module
 (func (export "main") (result i32) (local f64)
  f64.const 0 local.set 0
  loop f64.const -0 local.set 0 end
  local.get 0 i64.reinterpret_f64 i64.const -9223372036854775808 i64.eq))
