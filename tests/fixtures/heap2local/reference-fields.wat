(module
  (type $value (struct (field i32)))
  (type $pair (struct (field i32) (field (ref $value))))
  (type $array (array (mut (ref $value))))
  (func $sum (param (ref $value)) (result i32) (local (ref null $pair))
    i32.const 7 local.get 0 struct.new $pair local.tee 1
    struct.get $pair 0
    local.get 1 struct.get $pair 1 struct.get $value 0
    i32.add)
  (func $reference (param (ref $value)) (result (ref $value))
    (local (ref null $pair))
    i32.const 7 local.get 0 struct.new $pair local.tee 1
    struct.get $pair 0 drop
    local.get 1 struct.get $pair 1)
  (func $elements (param (ref $value)) (result i32) (local (ref null $array))
    local.get 0 i32.const 7 struct.new $value
    array.new_fixed $array 2 local.set 1
    local.get 1 i32.const 0 array.get $array struct.get $value 0
    local.get 1 i32.const 1 array.get $array struct.get $value 0
    i32.add)
  (func (export "sum") (param i32) (result i32)
    local.get 0 struct.new $value call $sum)
  (func (export "reference") (param i32) (result i32)
    local.get 0 struct.new $value call $reference struct.get $value 0)
  (func (export "elements") (param i32) (result i32)
    local.get 0 struct.new $value call $elements))
