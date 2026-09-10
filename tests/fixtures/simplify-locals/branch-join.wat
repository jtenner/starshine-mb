(module (func (export "run") (param i32) (result i32) (local i32 i32 i32)
  i32.const 10 local.set 1
  i32.const 20 local.set 2
  block $exit
    block $second
      local.get 0 br_if $second
      local.get 1 local.set 3 br $exit
    end
    local.get 2 local.set 3 br $exit
  end
  local.get 3))
