(module
 (rec (type $a (struct (field i32))) (type $b (struct (field i32))))
 (type $c (struct (field i32)))
 (func (export "main") (result i32) (local (ref $a))
  i32.const 7 struct.new $a local.set 0
  local.get 0 ref.test (ref $c)))
