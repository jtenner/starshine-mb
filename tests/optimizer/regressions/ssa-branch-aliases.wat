(module
  (func $both (param i32) (result i32) (local i32)
    i32.const 7 local.set 1
    local.get 0
    if
      local.get 1 i32.const 1 i32.add local.set 1
    else
      local.get 1 i32.const 2 i32.add local.set 1
    end
    local.get 1)
  (func $one (param i32) (result i32) (local i32)
    i32.const 7 local.set 1
    local.get 0 if i32.const 9 local.set 1 end
    local.get 1)
  (func $return (param i32) (result i32) (local i32)
    i32.const 7 local.set 1
    local.get 0
    if i32.const 10 return
    else local.get 1 i32.const 2 i32.add local.set 1 end
    local.get 1)
  (func $nested (param i32 i32) (result i32) (local i32)
    i32.const 7 local.set 2
    local.get 0
    if
      local.get 1 if i32.const 11 local.set 2 else local.get 2 i32.const 1 i32.add local.set 2 end
    else local.get 2 i32.const 2 i32.add local.set 2 end
    local.get 2)
  (func (export "main") (result i32)
    i32.const 0 call $both i32.const 9 i32.ne
    i32.const 1 call $both i32.const 8 i32.ne i32.or
    i32.const 0 call $one i32.const 7 i32.ne i32.or
    i32.const 1 call $one i32.const 9 i32.ne i32.or
    i32.const 0 call $return i32.const 9 i32.ne i32.or
    i32.const 1 call $return i32.const 10 i32.ne i32.or
    i32.const 0 i32.const 0 call $nested i32.const 9 i32.ne i32.or
    i32.const 1 i32.const 0 call $nested i32.const 8 i32.ne i32.or
    i32.const 1 i32.const 1 call $nested i32.const 11 i32.ne i32.or))
