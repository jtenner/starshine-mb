(module
(type $array (struct (field i32)))
(type $plain (func (param i32) (result i32)))
(type $bound (func (param eqref i32) (result i32)))
(type $closure (struct (field funcref)))
(func $length (param (ref $array)) (result i32) local.get 0 struct.get $array 0)
(func $get (param (ref $array) i32) (result i32) local.get 1)
(func $predicate (type $plain) (param i32) (result i32) i32.const 1)
(elem declare func $predicate)
  (func $run (param (ref $array) eqref) (result i32)
    (local i32 i32 eqref i32 i32)
    local.get 0
    ref.cast (ref $array)
    call $length
    local.set 2
    i32.const 0
    local.set 5
    block ;; label = @1
      loop ;; label = @2
        block ;; label = @3
          i32.const 1
          if ;; label = @4
            local.get 5
            local.set 3
            local.get 3
            local.get 2
            i32.lt_u
            if ;; label = @5
              local.get 3
              local.get 0
              ref.cast (ref $array)
              call $length
              i32.lt_u
              if (result i32) ;; label = @6
                local.get 1
                local.set 4
                local.get 4
                ref.cast (ref $closure)
                struct.get $closure 0
                ref.test (ref $plain)
                if (result i32) ;; label = @7
                  local.get 0
                  ref.cast (ref $array)
                  local.get 3
                  call $get
                  local.get 4
                  ref.cast (ref $closure)
                  struct.get $closure 0
                  ref.cast (ref $plain)
                  call_ref $plain
                else
                  local.get 4
                  local.get 0
                  ref.cast (ref $array)
                  local.get 3
                  call $get
                  local.get 4
                  ref.cast (ref $closure)
                  struct.get $closure 0
                  ref.cast (ref $bound)
                  call_ref $bound
                end
                i32.eqz
              else
                i32.const 0
              end
              if ;; label = @6
                i32.const 0
                local.set 6
                br 5 (;@1;)
              else
                local.get 3
                i32.const 1
                i32.add
                local.set 5
                br 4 (;@2;)
              end
              unreachable
              br 2 (;@3;)
            end
          end
          i32.const 1
          if ;; label = @4
            i32.const 1
            local.set 6
            br 3 (;@1;)
            br 1 (;@3;)
          end
          unreachable
        end
        unreachable
      end
      unreachable
    end
    local.get 6
  )

(func (export "run") (param i32) (result i32)
 local.get 0 struct.new $array ref.func $predicate struct.new $closure call $run)
)
