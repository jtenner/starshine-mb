///|
// This scan marks exactly the same indices as the Unit marker. Its result is
// only an upper bound for indices the current remapper could change.
fn dae_prune_mark_type_idx_max(idx : @lib.TypeIdx, used : Array[Bool]) -> Int32 {
  match dae_type_idx_slot(idx) {
    Some(slot) =>
      if slot >= 0 && slot < used.length() {
        used[slot] = true
        slot
      } else {
        -1
      }
    None => -1
  }
}

///|
fn dae_prune_mark_heap_type_max(
  ht : @lib.HeapType,
  used : Array[Bool],
) -> Int32 {
  match ht {
    @lib.HeapType(type_idx) => dae_prune_mark_type_idx_max(type_idx, used)
    @lib.DefTypeHeapType(_) => {
      let mut idx = 0
      while idx < used.length() {
        used[idx] = true
        idx += 1
      }
      // Embedded definitions retain all types. Keep a conservative high bound.
      used.length()
    }
    _ => -1
  }
}

///|
fn dae_prune_mark_ref_type_max(rt : @lib.RefType, used : Array[Bool]) -> Int32 {
  match rt {
    @lib.HeapTypeRefType(_, _, ht) => dae_prune_mark_heap_type_max(ht, used)
    _ => -1
  }
}

///|
fn dae_prune_mark_val_type_max(vt : @lib.ValType, used : Array[Bool]) -> Int32 {
  match vt {
    @lib.RefTypeValType(rt) => dae_prune_mark_ref_type_max(rt, used)
    _ => -1
  }
}

///|
fn dae_prune_mark_block_type_max(
  bt : @lib.BlockType,
  used : Array[Bool],
) -> Int32 {
  match bt {
    @lib.TypeIdxBlockType(type_idx) =>
      dae_prune_mark_type_idx_max(type_idx, used)
    @lib.ValTypeBlockType(val_type) =>
      dae_prune_mark_val_type_max(val_type, used)
    _ => -1
  }
}

///|
fn dae_prune_collect_used_type_idx_max(
  instrs : Array[@lib.Instruction],
  used : Array[Bool],
) -> Int32 {
  let mut maximum = -1
  for instr in instrs {
    match instr {
      @lib.Block(block_type, @lib.Expr(body))
      | @lib.Loop(block_type, @lib.Expr(body))
      | @lib.TryTable(block_type, _, @lib.Expr(body)) => {
        maximum = maximum.max(dae_prune_mark_block_type_max(block_type, used))
        maximum = maximum.max(dae_prune_collect_used_type_idx_max(body, used))
      }
      @lib.Try(block_type, @lib.Expr(body), catches, _) => {
        maximum = maximum.max(dae_prune_mark_block_type_max(block_type, used))
        maximum = maximum.max(dae_prune_collect_used_type_idx_max(body, used))
        for catch_ in catches {
          let @lib.Expr(catch_body) = match catch_ {
            @lib.LegacyCatch(_, catch_body) | @lib.LegacyCatchAll(catch_body) =>
              catch_body
          }
          maximum = maximum.max(
            dae_prune_collect_used_type_idx_max(catch_body, used),
          )
        }
      }
      @lib.If(block_type, then_body, else_body) => {
        maximum = maximum.max(dae_prune_mark_block_type_max(block_type, used))
        maximum = maximum.max(
          dae_prune_collect_used_type_idx_max(then_body, used),
        )
        match else_body {
          Some(body) =>
            maximum = maximum.max(
              dae_prune_collect_used_type_idx_max(body, used),
            )
          None => ()
        }
      }
      @lib.CallIndirect(type_idx, _)
      | @lib.ReturnCallIndirect(type_idx, _)
      | @lib.CallRef(type_idx)
      | @lib.ReturnCallRef(type_idx)
      | @lib.ContNew(type_idx)
      | @lib.Resume(type_idx, _)
      | @lib.ResumeThrow(type_idx, _, _)
      | @lib.ResumeThrowRef(type_idx, _)
      | @lib.StackSwitch(type_idx, _)
      | @lib.StructNew(type_idx)
      | @lib.StructNewDefault(type_idx)
      | @lib.StructNewDesc(type_idx)
      | @lib.StructNewDefaultDesc(type_idx)
      | @lib.ArrayNew(type_idx)
      | @lib.ArrayNewDefault(type_idx)
      | @lib.ArrayNewFixed(type_idx, _)
      | @lib.ArrayNewData(type_idx, _)
      | @lib.ArrayNewElem(type_idx, _)
      | @lib.ArrayGet(type_idx)
      | @lib.ArrayGetS(type_idx)
      | @lib.ArrayGetU(type_idx)
      | @lib.ArraySet(type_idx)
      | @lib.ArrayFill(type_idx)
      | @lib.ArrayInitData(type_idx, _)
      | @lib.ArrayInitElem(type_idx, _)
      | @lib.RefGetDesc(type_idx)
      | @lib.StructGet(type_idx, _)
      | @lib.StructGetS(type_idx, _)
      | @lib.StructGetU(type_idx, _)
      | @lib.StructWait(type_idx, _)
      | @lib.StructAtomicSet(_, type_idx, _)
      | @lib.ArrayAtomicSet(_, type_idx)
      | @lib.StructAtomicGet(_, type_idx, _)
      | @lib.StructAtomicGetS(_, type_idx, _)
      | @lib.StructAtomicGetU(_, type_idx, _)
      | @lib.StructAtomicRmw(_, _, type_idx, _)
      | @lib.StructAtomicCmpxchg(_, type_idx, _)
      | @lib.StructSet(type_idx, _)
      | @lib.ArrayAtomicGet(_, type_idx)
      | @lib.ArrayAtomicGetS(_, type_idx)
      | @lib.ArrayAtomicGetU(_, type_idx)
      | @lib.ArrayAtomicRmw(_, _, type_idx)
      | @lib.ArrayAtomicCmpxchg(_, type_idx)
      | @lib.ArrayLoad(_, type_idx, _)
      | @lib.ArrayStore(_, type_idx, _) =>
        maximum = maximum.max(dae_prune_mark_type_idx_max(type_idx, used))
      @lib.ContBind(source_type, target_type)
      | @lib.ArrayCopy(source_type, target_type) => {
        maximum = maximum.max(dae_prune_mark_type_idx_max(source_type, used))
        maximum = maximum.max(dae_prune_mark_type_idx_max(target_type, used))
      }
      @lib.Select(Some(types)) =>
        for val_type in types {
          maximum = maximum.max(dae_prune_mark_val_type_max(val_type, used))
        }
      @lib.RefNull(rt) =>
        maximum = maximum.max(dae_prune_mark_ref_type_max(rt, used))
      @lib.RefTest(_, _, ht)
      | @lib.RefCast(_, _, ht)
      | @lib.RefTestDesc(_, ht)
      | @lib.RefCastDescEq(_, _, ht) =>
        maximum = maximum.max(dae_prune_mark_heap_type_max(ht, used))
      @lib.BrOnCast(_, _, source_ht, target_ht)
      | @lib.BrOnCastFail(_, _, source_ht, target_ht) => {
        maximum = maximum.max(dae_prune_mark_heap_type_max(source_ht, used))
        maximum = maximum.max(dae_prune_mark_heap_type_max(target_ht, used))
      }
      @lib.BrOnCastDescEq(_, source_type, target_type)
      | @lib.BrOnCastDescEqFail(_, source_type, target_type) => {
        maximum = maximum.max(dae_prune_mark_ref_type_max(source_type, used))
        maximum = maximum.max(dae_prune_mark_ref_type_max(target_type, used))
      }
      _ => ()
    }
  }
  maximum
}
