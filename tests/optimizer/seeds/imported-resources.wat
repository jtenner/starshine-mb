(module
  (import "env" "global" (global $imported-global (mut i32)))
  (import "env" "memory" (memory $imported-memory 2 3))
  (import "env" "table" (table $imported-table 2 4 funcref))
  (func $target (result i32)
    i32.const 17)
  (elem (i32.const 0) func $target)
  (func (export "mutate") (param $value i32) (result i32)
    local.get $value
    global.set $imported-global
    i32.const 70001
    global.get $imported-global
    i32.store8
    i32.const 0
    table.get $imported-table
    drop
    global.get $imported-global)
  (export "imported-global" (global $imported-global))
  (export "imported-memory" (memory $imported-memory))
  (export "imported-table" (table $imported-table)))
