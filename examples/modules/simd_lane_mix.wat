(module
  (func (export "lane_add0") (param i32 i32) (result i32)
    local.get 0
    i8x16.splat
    local.get 1
    i8x16.splat
    i8x16.add
    i8x16.extract_lane_s 0))
