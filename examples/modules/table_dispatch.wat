(module
  (type $unary (func (param i32) (result i32)))
  (table 2 funcref)

  (func $inc (type $unary) (param i32) (result i32)
    local.get 0
    i32.const 1
    i32.add)

  (func $dec (type $unary) (param i32) (result i32)
    local.get 0
    i32.const 1
    i32.sub)

  (elem (i32.const 0) func $inc $dec)

  (func (export "dispatch") (param i32 i32) (result i32)
    local.get 0
    local.get 1
    call_indirect (type $unary)))
