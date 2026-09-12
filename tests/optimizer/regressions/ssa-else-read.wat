(module
  (func (export "main") (result i32) (local i32)
    i32.const 2
    local.set 0
    i32.const 0
    local.get 0
    i32.ge_u
    if
      i32.const 1
      local.set 0
    else
      i32.const 1
      local.get 0
      i32.ge_u
      local.set 0
    end
    local.get 0))
