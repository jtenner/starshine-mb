(module
  (func (export "main") (result i32) (local i32 i32 i32)
    block (result i32)
      i32.const 7 local.set 0
      i32.const 8 local.set 1
      local.get 0 local.get 1 local.get 2 select
      br 0
    end
    i32.const 1 i32.add))
