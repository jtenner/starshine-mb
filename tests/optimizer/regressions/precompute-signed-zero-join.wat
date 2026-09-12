(module
 (func $choose (param i32) (result i32) (local f32)
  local.get 0
  if f32.const 0 local.set 1 else f32.const -0 local.set 1 end
  local.get 1 i32.reinterpret_f32)
 (func (export "main") (result i32) i32.const 0 call $choose))
