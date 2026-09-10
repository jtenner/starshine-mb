(module
  (func (export "run") (param $limit i32) (result i32)
    (local $copy i32) (local $counter i32) (local $result i32)
    i32.const 0 local.set $counter
    block $exit
      loop $again
        block $body
          i32.const 1
          if
            local.get $counter local.tee $copy local.get $limit i32.lt_u
            if
              local.get $copy i32.const 2 i32.eq
              if
                i32.const 1 local.set $result br $exit
              else
                local.get $copy i32.const 1 i32.add local.set $counter br $again
              end
              unreachable
              br $body
            end
          end
          i32.const 1
          if
            i32.const 0 local.set $result br $exit
            br $body
          end
          unreachable
        end
        unreachable
      end
      unreachable
    end
    local.get $result))
