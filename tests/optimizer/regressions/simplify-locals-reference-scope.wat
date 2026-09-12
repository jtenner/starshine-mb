(module
 (type $s (struct (field i32) (field i32)))
 (func (export "main") (result i32) (local $x (ref $s))
  (block (result i32)
   (local.set $x (struct.new $s (i32.const 1) (i32.const 7)))
   (block (result i32) (struct.get $s 0 (local.get $x)))
   (if (result i32)
    (then (struct.get $s 1 (local.get $x)))
    (else (i32.const 0))))))
