(module
 (global (mut i32) (i32.const 1))
 (global (mut i32) (i32.const 2))
 (func $run (param i32) (result i32) (local i32)
  block
   global.get 0 local.set 1
   i32.const 3 global.set 1
   local.get 0 br_if 0
   local.get 1 return
  end
  i32.const 0)
 (func (export "main") (result i32)
  i32.const 0 call $run i32.const 10 i32.mul
  i32.const 1 call $run i32.add global.get 1 i32.add))
