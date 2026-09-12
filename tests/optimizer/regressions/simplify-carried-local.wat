(module
  (func (export "main") (result i32)
    (local $source i32) (local $result i32)
    i32.const 7 local.set $source
    i32.const 0
    if unreachable else
      local.get $source
      i32.const 9 local.set $source
      local.set $result
    end
    local.get $result i32.const 10 i32.mul local.get $source i32.add))
