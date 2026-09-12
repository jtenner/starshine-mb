(module
  (global $seen (mut i32) (i32.const 0))
  (func $sink (param i32) local.get 0 global.set $seen)
  (func $inc (param i32) (result i32) local.get 0 i32.const 6 i32.add)
  (func (export "main") (result i32) (local i32 i32 i32)
    i32.const 1 local.tee 1 local.tee 0 call $sink
    local.get 1 local.tee 0 call $sink
    block (result i32)
      local.get 0 call $inc local.tee 0 call $sink
      local.get 0 br 0
    end
    local.tee 0
    local.get 1 local.tee 2 call $sink
    local.get 2 call $sink
    local.tee 2 drop
    global.get $seen))
