(module
 (func $choose (param i32) (result f64) (local f64)
  local.get 0
  if f64.const nan:0x8000000000001 local.set 1
  else f64.const 0 local.set 1 end
  local.get 1)
 (func (export "main") (result i32)
  i32.const 1 call $choose f64.const 0 f64.eq))
