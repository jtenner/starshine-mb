(module
 (type $a (array i32))
 (type $b (array i32))
 (type $s (struct (field (ref $a)) (field i32)))
 (type $t (struct (field (ref $b)) (field i32)))
 (func (export "main") (result i32) (local (ref $s))
  i32.const 0 array.new_default $a i32.const 7 struct.new $s local.set 0
  local.get 0 ref.cast (ref $t) struct.get $t 1))
