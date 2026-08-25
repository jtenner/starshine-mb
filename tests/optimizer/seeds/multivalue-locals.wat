(module
  (func (export "pair") (param i32 i64) (result i64 i32)
    (local i32)
    local.get 0
    i32.const 1
    i32.add
    local.tee 2
    drop
    local.get 1
    local.get 2))
