(module
  (global $value (mut i32) (i32.const 7))
  (func (export "main") (result i32)
    (local $result i32)
    i32.const 1
    if
      global.get $value
      i32.const 9
      global.set $value
      local.set $result
    end
    local.get $result
    i32.const 10
    i32.mul
    global.get $value
    i32.add))
