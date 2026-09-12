(module
  (global $seen (mut i32) (i32.const 0))
  (func $record (param i32)
    global.get $seen i32.const 10 i32.mul local.get 0 i32.add global.set $seen)
  (func $defer (result i32)
    block (result i32)
      i32.const 4 call $record
      i32.const 9 br 0
    end
    i32.const 5 call $record
    return)
  (func (export "main") (result i32)
    call $defer i32.const 9 i32.ne
    if unreachable end
    global.get $seen))
