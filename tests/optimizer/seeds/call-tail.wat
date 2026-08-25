(module
  (func $leaf (param i32) (result i32)
    local.get 0 i32.const 3 i32.mul)
  (func $middle (param i32) (result i32)
    local.get 0 call $leaf)
  (func (export "tail") (param i32) (result i32)
    local.get 0 return_call $middle))
