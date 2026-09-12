(module
 (type $s (struct (field i32)))
 (func (export "main") (result i32)
  (local $x (ref $s)) (local $y (ref $s))
  block (result i32)
   i32.const 7 struct.new $s local.set $y
   local.get $y struct.get $s 0
  end
  drop
  (block (result (ref $s)) unreachable)
  local.tee $x drop
  loop
   local.get $x struct.get $s 0 drop
  end
  i32.const 0))
