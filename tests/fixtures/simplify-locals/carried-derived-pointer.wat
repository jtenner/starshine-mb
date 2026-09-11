(module
 (import "env" "alloc" (func (param i32) (result i32)))
 (memory (export "memory") 1)
 (func (export "run") (param i32) (result i32) (local i32 i32)
  i32.const 8 local.get 0 i32.add call 0 local.set 1
  local.get 1 i32.const 8 i32.add local.set 2
  local.get 1 i32.const 4 i32.store align=1
  local.get 2))
