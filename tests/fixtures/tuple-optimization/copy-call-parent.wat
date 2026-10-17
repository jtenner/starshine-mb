(module
  (type $pair (func (result i32 i32)))
  (import "env" "mark" (func $mark (param i32) (result i32)))
  (import "env" "observe" (func $observe (param i32 i32) (result i32)))
  (func (export "call_parent") (param i32) (result i32)
    (local i32 i32 i32 i32)
    block (type $pair)
      local.get 0 i32.const 1 i32.add call $mark
      local.get 0 i32.const 2 i32.add call $mark
    end local.set 2 local.set 1
    block (result i32)
      local.get 2 local.set 4 local.get 1
    end local.tee 3 call $mark
    local.get 4 i32.add)
  (func (export "earlier_operand") (param i32) (result i32)
    (local i32 i32 i32 i32)
    block (type $pair)
      local.get 0 i32.const 1 i32.add call $mark
      local.get 0 i32.const 2 i32.add call $mark
    end local.set 2 local.set 1
    i32.const 77 call $mark
    block (result i32)
      local.get 2 local.set 4 local.get 1
    end local.tee 3 call $observe
    local.get 4 i32.add)
  (func (export "earlier_trap") (param i32) (result i32)
    (local i32 i32 i32 i32)
    block (type $pair)
      local.get 0 i32.const 1 i32.add call $mark
      local.get 0 i32.const 2 i32.add call $mark
    end local.set 2 local.set 1
    i32.const 1 i32.const 0 i32.div_s
    block (result i32)
      local.get 2 local.set 4 local.get 1
    end local.tee 3 call $observe
    local.get 4 i32.add)
  (func (export "later_operand") (param i32) (result i32)
    (local i32 i32 i32 i32)
    block (type $pair)
      local.get 0 i32.const 1 i32.add call $mark
      local.get 0 i32.const 2 i32.add call $mark
    end local.set 2 local.set 1
    block (result i32)
      local.get 2 local.set 4 local.get 1
    end local.tee 3
    local.get 4 call $mark call $observe
    local.get 3 i32.add))
