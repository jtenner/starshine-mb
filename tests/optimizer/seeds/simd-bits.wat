(module
  (func (export "mask") (param i32) (result i32)
    v128.const i32x4 0 0 0 0
    i32.const 0
    i32x4.replace_lane 0
    i32x4.bitmask))
