(module (type (array (mut i32)))
  (func (;0;) (export "run")
    (local eqref i32 i32)
    i32.const 1
    i32.const 7
    local.set 1
    local.set 2
    local.get 1
    local.get 2
    array.new 0
    ref.cast (ref 0)
    local.tee 0
    i32.const 1
    i32.const 9
    local.set 2
    local.set 1
    ref.cast (ref 0)
    local.get 1
    local.get 2
    array.set 0
  )
)
