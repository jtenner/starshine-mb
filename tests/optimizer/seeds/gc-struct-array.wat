(module
  (type $pair (struct (field (mut i32)) (field i64)))
  (type $items (array (mut i32)))
  (func (export "gc") (param i32) (result i32)
    (local (ref null $pair))
    local.get 0
    i64.const 9
    struct.new $pair
    local.tee 1
    local.get 0
    struct.set $pair 0
    local.get 1
    struct.get $pair 0))
