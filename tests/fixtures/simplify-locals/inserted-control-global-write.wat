(module
 (import "env" "observe" (func (param i32 i32)))
 (global (export "observed") (mut i32) (i32.const 17))
 (func (export "run") (param i32 i32) (result i32) (local i32)
  local.get 1 if
    local.get 0 local.get 1 call 0
    local.get 1 local.set 2
  end
  i32.const 0 global.set 0
  local.get 2 if local.get 2 global.set 0 end
  i32.const 2 local.tee 0 local.get 0 i32.add))
