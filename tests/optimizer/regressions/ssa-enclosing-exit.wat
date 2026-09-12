(module
  (func (export "main") (result i32) (local i32 i32)
    i32.const 0 local.set 0
    i32.const 0 local.set 1
    block
      loop
        block
          local.get 1 i32.const 3 i32.lt_s
          if
            local.get 1 i32.const 1 i32.add local.set 1
            br 2
            br 1
          end
          local.get 1 i32.const 3 i32.eq
          if
            local.get 1 local.set 0
            br 3
            br 1
          end
          unreachable
          nop
        end
        unreachable
      end
      unreachable
    end
    local.get 0))
