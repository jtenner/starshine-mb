(module
  (type $inner (struct (field i32)))
  (type $outer (struct (field (ref $inner))))
  (func (export "main") (result i32)
    i32.const 21 struct.new $inner ref.cast (ref $inner)
    struct.new $outer ref.cast (ref $outer) struct.get $outer 0
    ref.cast (ref $inner) struct.get $inner 0))
