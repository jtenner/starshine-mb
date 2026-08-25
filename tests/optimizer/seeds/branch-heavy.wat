(module
  (func (export "branch") (param i32 i32) (result i32)
    (block (result i32)
      local.get 1
      local.get 0
      br_if 0
      drop
      i32.const 9)))
