(module
  (memory (export "memory") 1 1)
  (func (export "fill") (param $destination i32) (param $value i32)
    local.get $destination
    local.get $value
    i32.const 16
    memory.fill)
  (func (export "fill_const") (param $destination i32)
    local.get $destination
    i32.const 171
    i32.const 16
    memory.fill)
  (func (export "copy") (param $destination i32) (param $source i32)
    local.get $destination
    local.get $source
    i32.const 16
    memory.copy)
)
