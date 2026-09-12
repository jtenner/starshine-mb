(module
  (type (;0;) (func (param i32) (result i32)))
  (type (;1;) (cont 0))
  (type (;2;) (func (result i32)))
  (type (;3;) (cont 2))
  (type (;4;) (func (result i32)))
  (type (;5;) (func))
  (type (;6;) (func (result i32)))
  (tag (;0;) (type 5))
  (export "run" (func 2))
  (elem (;0;) declare funcref (ref.func 0))
  (func (;0;) (type 0) (param i32) (result i32)
    local.get 0
  )
  (func (;1;) (type 4) (result i32)
    i32.const -782172248
  )
  (func (;2;) (type 6) (result i32)
    call 1
    drop
    ref.func 0
    cont.new 1
    resume_throw 1 0
  )
)
