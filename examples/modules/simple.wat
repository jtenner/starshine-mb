(module
  (func (export "add_then_shift") (param i32 i32) (result i32)
    local.get 0
    local.get 1
    i32.add
    i32.const 1
    i32.shl))
