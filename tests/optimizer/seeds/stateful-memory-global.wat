(module
  (memory (export "memory") 1)
  (global (export "counter") (mut i32) (i32.const 0))
  (func (export "step") (param i32) (result i32)
    global.get 0
    local.get 0
    i32.add
    global.set 0
    i32.const 0
    global.get 0
    i32.store
    global.get 0))
