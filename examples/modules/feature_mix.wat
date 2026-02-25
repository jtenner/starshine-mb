(module
  (memory (export "mem") 1)
  (table 2 funcref)
  (global $g (mut i32) (i32.const 7))

  (func $inc (param i32) (result i32)
    local.get 0
    global.get $g
    i32.add)

  (func $twice (param i32) (result i32)
    local.get 0
    call $inc
    local.get 0
    call $inc
    i32.add)

  (elem (i32.const 0) func $inc $twice)
  (data (i32.const 0) "starshine-demo")

  (func (export "run") (param i32) (result i32)
    local.get 0
    call $twice))
