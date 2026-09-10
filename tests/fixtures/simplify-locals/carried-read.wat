(module
  (func (;2;) (export "run") (result i32)
    (local f32 i32 f64)
    f32.const 0x1.ep+2 (;=7.5;)
    i32.const 0
    local.set 1
    local.set 0
    block ;; label = @1
      local.get 0
      f32.const 0x1.ep+2 (;=7.5;)
      f32.eq
      if ;; label = @2
        i32.const 1
        local.set 1
        br 1 (;@1;)
      end
      i32.const 0
      local.set 1
      br 0 (;@1;)
    end
    local.get 1
    f64.const 0x1.28p+3 (;=9.25;)
    i32.const 0
    local.set 1
    local.set 2
    block ;; label = @1
      local.get 2
      f64.const 0x1.28p+3 (;=9.25;)
      f64.eq
      if ;; label = @2
        i32.const 2
        local.set 1
        br 1 (;@1;)
      end
      i32.const 0
      local.set 1
      br 0 (;@1;)
    end
    local.get 1
    i32.add
  )
)
