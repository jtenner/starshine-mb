(module
  (func (export "main") (result i32) (local i32)
    i32.const 0 local.set 0
    block
      i32.const 1
      if
        i32.const 7 local.set 0
        br 1
      end
      unreachable
    end
    local.get 0))
