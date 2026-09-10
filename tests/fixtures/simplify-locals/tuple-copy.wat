(module
  (type (func (param i32 i32) (result i32 i32 i32)))
  (import "env" "tri" (func (type 0)))
  (func (export "run") (result i32)
    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
    i32.const 42 i32.const 10000 call 0
    local.set 8 local.set 7 local.tee 6 local.set 11
    local.get 7 local.set 10
    block (result i32 i32 i32)
      local.get 11 local.get 10 local.get 8
    end
    local.set 5 local.set 4 local.tee 3
    block (result i32 i32 i32)
      local.get 3 local.get 4 local.get 5
    end
    local.set 2 local.set 1 local.tee 0 drop drop
    local.get 0))
