(module
  (type $pair (func (result i32 i32)))
  (import "env" "mark" (func $mark (param i32 i32) (result i32)))
  (func (export "root") (param i32) (result i32) (local i32 i32)
    block (type $pair)
      local.get 0 i32.const 1 i32.add
      local.get 0 i32.const 2 i32.add
    end
    local.set 2 local.set 1
    local.get 1 local.get 2 i32.add)
  (func (export "loop") (param i32) (result i32) (local i32 i32)
    loop
      block (type $pair)
        local.get 0 i32.const 1 i32.add
        local.get 0 i32.const 2 i32.add
      end
      local.set 2 local.set 1
    end
    local.get 1 local.get 2 i32.add)
  (type $entry_pair (func (param i32 i32) (result i32 i32)))
  (func (export "typed_entry") (param i32 i32) (result i32) (local i32 i32)
    local.get 0 local.get 1
    block (type $entry_pair)
      i32.const 2 i32.add
    end
    local.set 3 local.set 2
    local.get 2 local.get 3 i32.add)
  (func (export "mutable_parameter") (param i32) (result i32) (local i32 i32)
    block (type $pair)
      local.get 0 i32.const 1 i32.add
      local.get 0 i32.const 2 i32.add
    end
    local.set 0 local.set 1
    local.get 1 local.get 0 i32.add)
  (func (export "overlap") (param i32) (result i32) (local i32 i32)
    local.get 0 local.set 1
    block (type $pair)
      local.get 1 i32.const 1 i32.add
      local.get 1 i32.const 2 i32.add
    end
    local.set 1 local.set 2
    local.get 2 local.get 1 i32.add)
  (func (export "trapping") (param i32) (result i32) (local i32 i32)
    block (type $pair)
      local.get 0 i32.const 0 i32.div_s
      local.get 0 i32.const 2 i32.add
    end
    local.set 2 local.set 1
    local.get 1 local.get 2 i32.add)
  (func (export "calls") (param i32) (result i32) (local i32 i32)
    block (type $pair)
      i32.const 1 local.get 0 i32.const 1 i32.add call $mark
      i32.const 2 local.get 0 i32.const 2 i32.add call $mark
    end
    local.set 2 local.set 1
    local.get 1 local.get 2 i32.add)
  (func (export "multi_group") (param i32) (result i32) (local i32 i32 i32 i32 i32 i32)
    block (type $pair)
      local.get 0 i32.const 1 i32.add
      local.get 0 i32.const 2 i32.add
    end
    local.set 2 local.set 1
    block (type $pair)
      local.get 0 i32.const 3 i32.add
      local.get 0 i32.const 4 i32.add
    end
    local.set 4 local.set 3
    block (type $pair)
      i32.const 1 local.get 0 i32.const 5 i32.add call $mark
      i32.const 2 local.get 0 i32.const 6 i32.add call $mark
    end
    local.set 6 local.set 5
    local.get 1 local.get 2 i32.add local.get 3 i32.add
    local.get 4 i32.add local.get 5 i32.add local.get 6 i32.add)
  (func (export "interleaved_write") (param i32) (result i32) (local i32 i32 i32)
    i32.const 7 local.set 1
    block (type $pair)
      local.get 0 i32.const 1 i32.add
      local.get 0 i32.const 2 i32.add
    end
    local.set 2 local.get 1 local.set 3 local.set 1
    local.get 3 local.get 1 i32.add local.get 2 i32.add)
  (func (export "publication_0") (param i32) (result i32) (local i32 i32 i32)
    local.get 0 local.set 1
    block (type $pair)
      local.get 1 i32.const 1 i32.add
      local.get 1 i32.const 2 i32.add
    end
    local.set 2
    i32.const 99 local.set 1
    local.set 3
    local.get 1 local.get 2 i32.add local.get 3 i32.add)
  (func (export "publication_2") (param i32) (result i32) (local i32 i32 i32)
    local.get 0 local.set 1
    block (type $pair)
      local.get 1 i32.const 1 i32.add
      local.get 1 i32.const 2 i32.add
    end
    local.set 2
    i32.const 99 local.set 1
    local.set 3
    local.get 1 local.get 2 i32.add local.get 3 i32.add
    local.get 0 i32.add local.get 0 i32.add)
  (func (export "publication_4") (param i32) (result i32) (local i32 i32 i32)
    local.get 0 local.set 1
    block (type $pair)
      local.get 1 i32.const 1 i32.add
      local.get 1 i32.const 2 i32.add
    end
    local.set 2
    i32.const 99 local.set 1
    local.set 3
    local.get 1 local.get 2 i32.add local.get 3 i32.add
    local.get 0 i32.add local.get 0 i32.add
    local.get 0 i32.add local.get 0 i32.add))
