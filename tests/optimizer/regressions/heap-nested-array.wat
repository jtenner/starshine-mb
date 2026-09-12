(module
  (type $inner (struct (field i32)))
  (type $array (array (ref $inner)))
  (func (export "main") (result i32)
    i32.const 21 struct.new $inner ref.cast (ref $inner)
    array.new_fixed $array 1 i32.const 0 array.get $array
    ref.cast (ref $inner) struct.get $inner 0))
