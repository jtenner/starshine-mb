(module
  (type $pair (func (result i32 i32)))
  (import "env" "mark" (func $mark (param i32 i32) (result i32)))

  (func (export "prefix")
    (param $limit i32) (param $capture i32)
    (param $saved_a i32) (param $saved_b i32) (param $trap_at i32)
    (result i32 i32)
    (local $a i32) (local $b i32)
    (local $alias_a i32) (local $alias_b i32)
    (local $out_a i32) (local $out_b i32) (local $iteration i32)
    local.get $limit i32.const 0 i32.le_s
    if
      local.get $saved_a local.get $saved_b return
    end
    block $done
      loop $again
        local.get $iteration local.get $limit i32.ge_s br_if $done
        block (type $pair)
          i32.const 1 local.get $iteration i32.const 11 i32.add call $mark
          i32.const 2 local.get $iteration i32.const 100 i32.add call $mark
        end
        local.set $b local.set $a
        local.get $iteration local.get $capture i32.eq
        if
          local.get $a local.set $saved_a
          local.get $b local.set $saved_b
        end
        block (result i32)
          local.get $saved_b local.set $out_b
          local.get $saved_a
        end local.set $out_a
        local.get $iteration local.get $trap_at i32.eq if unreachable end
        local.get $iteration i32.const 1 i32.add local.set $iteration
        br $again
      end
    end
    local.get $out_a local.get $out_b)


  (func (export "trailing")
    (param $limit i32) (param $capture i32)
    (param $saved_a i32) (param $saved_b i32) (param $trap_at i32)
    (result i32 i32)
    (local $a i32) (local $b i32)
    (local $alias_a i32) (local $alias_b i32)
    (local $out_a i32) (local $out_b i32) (local $iteration i32)
    local.get $limit i32.const 0 i32.le_s
    if
      local.get $saved_a local.get $saved_b return
    end
    block $done
      loop $again
        local.get $iteration local.get $limit i32.ge_s br_if $done
        block (type $pair)
          i32.const 1 local.get $iteration i32.const 11 i32.add call $mark
          i32.const 2 local.get $iteration i32.const 100 i32.add call $mark
        end
        local.set $b local.set $a
        local.get $iteration local.get $capture i32.eq
        if
          local.get $a local.set $saved_a
          local.get $b local.set $saved_b
        end
        block (result i32)
          local.get $saved_a
          local.get $saved_b local.set $out_b
        end local.set $out_a
        local.get $iteration local.get $trap_at i32.eq if unreachable end
        local.get $iteration i32.const 1 i32.add local.set $iteration
        br $again
      end
    end
    local.get $out_a local.get $out_b)


  (func (export "chain")
    (param $limit i32) (param $capture i32)
    (param $alias_a i32) (param $alias_b i32) (param $trap_at i32)
    (result i32 i32)
    (local $a i32) (local $b i32)
    (local $saved_a i32) (local $saved_b i32)
    (local $out_a i32) (local $out_b i32) (local $iteration i32)
    local.get $limit i32.const 0 i32.le_s
    if
      local.get $alias_a local.get $alias_b return
    end
    block $done
      loop $again
        local.get $iteration local.get $limit i32.ge_s br_if $done
        block (type $pair)
          i32.const 1 local.get $iteration i32.const 11 i32.add call $mark
          i32.const 2 local.get $iteration i32.const 100 i32.add call $mark
        end
        local.set $b local.set $a
        local.get $iteration local.get $capture i32.eq
        if
          local.get $a local.set $saved_a
          local.get $b local.set $saved_b
          local.get $saved_a local.set $alias_a
          local.get $saved_b local.set $alias_b
        end
        block (result i32)
          local.get $alias_b local.set $out_b
          local.get $alias_a
        end local.set $out_a
        local.get $iteration local.get $trap_at i32.eq if unreachable end
        local.get $iteration i32.const 1 i32.add local.set $iteration
        br $again
      end
    end
    local.get $out_a local.get $out_b)


  (func (export "mixed")
    (param $limit i32) (param $capture i32)
    (param $saved_a i32) (param $saved_b i32) (param $trap_at i32)
    (result i32 i32)
    (local $a i32) (local $b i32)
    (local $alias_a i32) (local $alias_b i32)
    (local $out_a i32) (local $out_b i32) (local $iteration i32)
    local.get $limit i32.const 0 i32.le_s
    if
      local.get $saved_a local.get $saved_b return
    end
    block $done
      loop $again
        local.get $iteration local.get $limit i32.ge_s br_if $done
        block (type $pair)
          i32.const 1 local.get $iteration i32.const 11 i32.add call $mark
          i32.const 2 local.get $iteration i32.const 100 i32.add call $mark
        end
        local.set $b local.set $a
        local.get $iteration local.get $capture i32.eq
        if
          local.get $a local.set $saved_a
          local.get $b local.set $saved_b
        end
        block (result i32)
          local.get $b local.set $out_b
          local.get $saved_a
        end local.set $out_a
        local.get $iteration local.get $trap_at i32.eq if unreachable end
        local.get $iteration i32.const 1 i32.add local.set $iteration
        br $again
      end
    end
    local.get $out_a local.get $out_b)


  (func (export "delayed")
    (param $limit i32) (param $capture i32)
    (param $saved_a i32) (param $saved_b i32) (param $trap_at i32)
    (result i32 i32)
    (local $a i32) (local $b i32)
    (local $alias_a i32) (local $alias_b i32)
    (local $out_a i32) (local $out_b i32) (local $iteration i32)
    local.get $limit i32.const 0 i32.le_s
    if
      local.get $saved_a local.get $saved_b return
    end
    block $done
      loop $again
        local.get $iteration local.get $limit i32.ge_s br_if $done
        block (type $pair)
          i32.const 1 local.get $iteration i32.const 11 i32.add call $mark
          i32.const 2 local.get $iteration i32.const 100 i32.add call $mark
        end
        local.set $b local.set $a
        block (result i32)
          local.get $saved_b local.set $out_b
          local.get $saved_a
        end local.set $out_a
        local.get $a local.set $saved_a
          local.get $b local.set $saved_b
        local.get $iteration local.get $trap_at i32.eq if unreachable end
        local.get $iteration i32.const 1 i32.add local.set $iteration
        br $again
      end
    end
    local.get $out_a local.get $out_b)


  (func (export "partial_block_set") (result i32)
    (local $a i32) (local $b i32) (local $observed i32)
    block
      block (type $pair)
        i32.const 1 i32.const 11 call $mark
        i32.const 2 i32.const 100 call $mark
      end
      local.set $b
      i32.const 3 local.get $b call $mark local.set $observed
      local.set $a
    end
    local.get $observed)

  (func (export "partial_block_tee") (result i32)
    (local $a i32) (local $b i32) (local $observed i32)
    block
      block (type $pair)
        i32.const 1 i32.const 11 call $mark
        i32.const 2 i32.const 100 call $mark
      end
      local.tee $b drop
      i32.const 3 local.get $b call $mark local.set $observed
      local.set $a
    end
    local.get $observed)

  (func (export "partial_loop_set") (result i32)
    (local $a i32) (local $b i32) (local $observed i32)
    loop
      block (type $pair)
        i32.const 1 i32.const 11 call $mark
        i32.const 2 i32.const 100 call $mark
      end
      local.set $b
      i32.const 3 local.get $b call $mark local.set $observed
      local.set $a
    end
    local.get $observed)

  (func (export "partial_loop_tee") (result i32)
    (local $a i32) (local $b i32) (local $observed i32)
    loop
      block (type $pair)
        i32.const 1 i32.const 11 call $mark
        i32.const 2 i32.const 100 call $mark
      end
      local.tee $b drop
      i32.const 3 local.get $b call $mark local.set $observed
      local.set $a
    end
    local.get $observed)

  (func (export "copy_prefix") (param $trap i32) (result i32)
    (local $a i32) (local $b i32) (local $oa i32) (local $ob i32)
    block (type $pair) i32.const 11 i32.const 100 end
    local.set $b local.set $a
    block (type $pair) i32.const 9 i32.const 9 call $mark drop local.get $trap if unreachable end local.get $a local.get $b end local.set $ob local.set $oa
    local.get $oa local.get $ob i32.add)

  (func (export "nested_prefix") (param $trap i32) (result i32)
    (local $a i32) (local $b i32) (local $oa i32) (local $ob i32)
    block (type $pair) i32.const 11 i32.const 100 end
    local.set $b local.set $a
    block (type $pair) block (result i32) i32.const 9 i32.const 9 call $mark drop local.get $trap if unreachable end local.get $a end local.get $b end local.set $ob local.set $oa
    local.get $oa local.get $ob i32.add)

  (func (export "scalar_prefix") (param $trap i32) (result i32)
    (local $a i32) (local $b i32) (local $oa i32) (local $ob i32)
    block (type $pair) i32.const 11 i32.const 100 end
    local.set $b local.set $a
    block (result i32) i32.const 9 i32.const 9 call $mark drop local.get $trap if unreachable end local.get $a local.get $b local.set $ob end local.set $oa
    local.get $oa local.get $ob i32.add)

  (func (export "partial_block_call") (result i32)
    (local $a i32) (local $b i32) (local $observed i32)
    block
      block (type $pair)
        i32.const 1 i32.const 11 call $mark
        i32.const 2 i32.const 100 call $mark
      end
      local.tee $b
      call $mark_tee drop
      i32.const 3 local.get $b call $mark local.set $observed
      local.set $a
    end
    local.get $observed)

  (func (export "partial_loop_call") (result i32)
    (local $a i32) (local $b i32) (local $observed i32)
    loop
      block (type $pair)
        i32.const 1 i32.const 11 call $mark
        i32.const 2 i32.const 100 call $mark
      end
      local.tee $b
      call $mark_tee drop
      i32.const 3 local.get $b call $mark local.set $observed
      local.set $a
    end
    local.get $observed)

  (func $mark_tee (param i32) (result i32)
    i32.const 4 local.get 0 call $mark)

  (func (export "earlier_block_call") (result i32)
    (local $a i32) (local $b i32)
    block
    i32.const 7 i32.const 77 call $mark
    block (type $pair)
      i32.const 1 i32.const 11 call $mark
      i32.const 2 i32.const 100 call $mark
    end
    local.set $b local.tee $a
    call $observe_later drop
    end
    i32.const 3 local.get $b call $mark)

  (func (export "earlier_block_trap") (result i32)
    (local $a i32) (local $b i32)
    block
    i32.const 1 i32.const 0 i32.div_s
    block (type $pair)
      i32.const 1 i32.const 11 call $mark
      i32.const 2 i32.const 100 call $mark
    end
    local.set $b local.tee $a
    call $observe_later drop
    end
    i32.const 3 local.get $b call $mark)

  (func (export "earlier_loop_call") (result i32)
    (local $a i32) (local $b i32)
    loop
    i32.const 7 i32.const 77 call $mark
    block (type $pair)
      i32.const 1 i32.const 11 call $mark
      i32.const 2 i32.const 100 call $mark
    end
    local.set $b local.tee $a
    call $observe_later drop
    end
    i32.const 3 local.get $b call $mark)

  (func (export "earlier_loop_trap") (result i32)
    (local $a i32) (local $b i32)
    loop
    i32.const 1 i32.const 0 i32.div_s
    block (type $pair)
      i32.const 1 i32.const 11 call $mark
      i32.const 2 i32.const 100 call $mark
    end
    local.set $b local.tee $a
    call $observe_later drop
    end
    i32.const 3 local.get $b call $mark)

  (func (export "earlier_root_call") (result i32)
    (local $a i32) (local $b i32)

    i32.const 7 i32.const 77 call $mark
    block (type $pair)
      i32.const 1 i32.const 11 call $mark
      i32.const 2 i32.const 100 call $mark
    end
    local.set $b local.set $a local.get $a
    call $observe_later drop
        i32.const 3 local.get $b call $mark)

  (func (export "earlier_root_trap") (result i32)
    (local $a i32) (local $b i32)

    i32.const 1 i32.const 0 i32.div_s
    block (type $pair)
      i32.const 1 i32.const 11 call $mark
      i32.const 2 i32.const 100 call $mark
    end
    local.set $b local.set $a local.get $a
    call $observe_later drop
        i32.const 3 local.get $b call $mark)

  (func (export "earlier_reduced_loop_call") (result i32)
    (local $a i32) (local $b i32)
    loop
    i32.const 7 i32.const 77 call $mark
    block (type $pair)
      i32.const 1 i32.const 11 call $mark
      i32.const 2 i32.const 100 call $mark
    end
    local.set $b local.set $a local.get $a
    call $observe_later drop
    end
    i32.const 3 local.get $b call $mark)

  (func (export "earlier_reduced_loop_trap") (result i32)
    (local $a i32) (local $b i32)
    loop
    i32.const 1 i32.const 0 i32.div_s
    block (type $pair)
      i32.const 1 i32.const 11 call $mark
      i32.const 2 i32.const 100 call $mark
    end
    local.set $b local.set $a local.get $a
    call $observe_later drop
    end
    i32.const 3 local.get $b call $mark)

  (func $observe_later (param i32 i32) (result i32)
    i32.const 5 local.get 0 call $mark drop
    i32.const 6 local.get 1 call $mark drop
    i32.const 0)
)
