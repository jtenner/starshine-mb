(module
 (type $s (struct (field (mut i32))))
 (func $read (param $p (ref $s)) (param $condition i32) (result i32)
  local.get $condition
  if (result i32) unreachable else
   local.get $p struct.get $s 0
   local.get $p i32.const 9 struct.set $s 0
   nop
  end
  )
 (func (export "main") (result i32)
  i32.const 7 struct.new $s i32.const 0 call $read))
