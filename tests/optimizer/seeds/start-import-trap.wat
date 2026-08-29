(module
  (import "starshine_observe" "event" (func $event (param i32) (result i32)))
  (memory (export "memory") 2)
  (global $state (export "state") (mut i32) (i32.const 0))
  (func $start
    i32.const 5
    call $event
    global.set $state)
  (start $start)
  (func (export "run") (param $divisor i32) (result i32)
    local.get $divisor
    call $event
    global.set $state
    i32.const 70000
    global.get $state
    i32.store8
    i32.const 84
    local.get $divisor
    i32.div_s))
