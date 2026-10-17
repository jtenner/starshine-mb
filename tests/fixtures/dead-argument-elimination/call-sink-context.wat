(module
  (type $gc_base (sub (struct (field i32))))
  (type $gc_leaf (sub $gc_base (struct (field i32))))
  (import "host" "sink32" (func $sink32 (param i32)))
  (import "host" "sink64" (func $sink64 (param i64)))
  (import "host" "mark32" (func $mark32 (param i32) (result i32)))
  (func $private32 (param i32) local.get 0 call $sink32)
  (func $public32 (export "public32") (param i32) local.get 0 call $sink32)
  (func $private64 (param i64) local.get 0 call $sink64)
  (func $public64 (export "public64") (param i64) local.get 0 call $sink64)
  (func $discarded (result i32) i32.const 13 call $mark32)
  (func (export "run") (param i32 i64)
    i32.const 7 call $private32
    local.get 0 call $public32
    i64.const 11 call $private64
    local.get 1 call $public64
    call $discarded drop)
  (func $gc_identity (param (ref null $gc_base)) (result (ref null $gc_base))
    local.get 0)
  (func $gc_check (param (ref null $gc_base)) (result i32)
    local.get 0 struct.get $gc_base 0)
  (func (export "gc_run") (param i32) (result i32)
    local.get 0 call $mark32 drop
    local.get 0 struct.new $gc_leaf call $gc_identity call $gc_check
    call $mark32)
  (func $gc_nullable_identity (param (ref null $gc_base)) (result (ref null $gc_base))
    local.get 0)
  (func $gc_nullable_check (param (ref null $gc_base)) (result i32)
    local.get 0 struct.get $gc_base 0)
  (func (export "gc_nullable") (param i32 i32) (result i32)
    local.get 0 call $mark32 drop
    local.get 1
    if (result (ref null $gc_base))
      ref.null $gc_base
    else
      local.get 0 struct.new $gc_leaf
    end
    call $gc_nullable_identity call $gc_nullable_check
    call $mark32)
)
