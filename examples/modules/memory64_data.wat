(module
  (memory (export "mem") i64 1)
  (data (i64.const 0) "M64!")

  (func (export "load0") (result i32)
    i64.const 0
    i32.load8_u)

  (func (export "size_pages") (result i64)
    memory.size))
