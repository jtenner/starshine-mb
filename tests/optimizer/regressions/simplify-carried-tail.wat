(module
  (global $value (mut i32) (i32.const 7))
  (func (export "main") (result i32)
    (local $result i32)
    i32.const 0
    if
      unreachable
    else
      global.get $value
      i32.const 9
      global.set $value
      local.set $result
    end
    local.get $result))
