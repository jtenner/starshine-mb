///|
// Frozen corrected baseline: mechanical helper renames only.

///|
fn dae_prune_max_ref_type_idx_slot(idx : @lib.TypeIdx) -> Int32? {
  match idx {
    @lib.TypeIdx(raw) => Some(raw.reinterpret_as_int())
    @lib.RecIdx(_) => None
  }
}

///|
fn dae_prune_max_ref_simple_func_type_section(
  rec_types : Array[@lib.RecType],
) -> Bool {
  for rec_type in rec_types {
    match rec_type {
      @lib.SingleRecType(subtype) =>
        if subtype.super_types().length() > 0 ||
          subtype.describes_type() is Some(_) ||
          subtype.descriptor_type() is Some(_) {
          return false
        }
      @lib.GroupRecType(_) => return false
    }
  }
  true
}

///|
fn dae_prune_max_ref_mark_used_type_idx(
  idx : @lib.TypeIdx,
  used : Array[Bool],
) -> Unit {
  match dae_prune_max_ref_type_idx_slot(idx) {
    Some(slot) => if slot >= 0 && slot < used.length() { used[slot] = true }
    None => ()
  }
}

///|
fn dae_prune_max_ref_mark_used_heap_type(
  ht : @lib.HeapType,
  used : Array[Bool],
) -> Unit {
  match ht {
    @lib.HeapType(type_idx) =>
      dae_prune_max_ref_mark_used_type_idx(type_idx, used)
    @lib.DefTypeHeapType(_) => {
      let mut idx = 0
      while idx < used.length() {
        used[idx] = true
        idx += 1
      }
    }
    _ => ()
  }
}

///|
fn dae_prune_max_ref_mark_used_ref_type(
  rt : @lib.RefType,
  used : Array[Bool],
) -> Unit {
  match rt {
    @lib.HeapTypeRefType(_, _, ht) =>
      dae_prune_max_ref_mark_used_heap_type(ht, used)
    _ => ()
  }
}

///|
fn dae_prune_max_ref_mark_used_val_type(
  vt : @lib.ValType,
  used : Array[Bool],
) -> Unit {
  match vt {
    @lib.RefTypeValType(rt) => dae_prune_max_ref_mark_used_ref_type(rt, used)
    _ => ()
  }
}

///|
fn dae_prune_max_ref_mark_used_table_type(
  tt : @lib.TableType,
  used : Array[Bool],
) -> Unit {
  let @lib.TableType(rt, _) = tt
  dae_prune_max_ref_mark_used_ref_type(rt, used)
}

///|
fn dae_prune_max_ref_mark_used_global_type(
  gt : @lib.GlobalType,
  used : Array[Bool],
) -> Unit {
  let @lib.GlobalType(vt, _) = gt
  dae_prune_max_ref_mark_used_val_type(vt, used)
}

///|
fn dae_prune_max_ref_mark_used_block_type(
  bt : @lib.BlockType,
  used : Array[Bool],
) -> Unit {
  match bt {
    @lib.TypeIdxBlockType(type_idx) =>
      dae_prune_max_ref_mark_used_type_idx(type_idx, used)
    @lib.ValTypeBlockType(val_type) =>
      dae_prune_max_ref_mark_used_val_type(val_type, used)
    _ => ()
  }
}

///|
fn dae_prune_max_ref_collect_used_type_idx_instrs(
  instrs : Array[@lib.Instruction],
  used : Array[Bool],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.Block(block_type, @lib.Expr(body))
      | @lib.Loop(block_type, @lib.Expr(body))
      | @lib.TryTable(block_type, _, @lib.Expr(body)) => {
        dae_prune_max_ref_mark_used_block_type(block_type, used)
        dae_prune_max_ref_collect_used_type_idx_instrs(body, used)
      }
      @lib.Try(block_type, @lib.Expr(body), catches, _) => {
        dae_prune_max_ref_mark_used_block_type(block_type, used)
        dae_prune_max_ref_collect_used_type_idx_instrs(body, used)
        for catch_ in catches {
          let @lib.Expr(catch_body) = match catch_ {
            @lib.LegacyCatch(_, catch_body) | @lib.LegacyCatchAll(catch_body) =>
              catch_body
          }
          dae_prune_max_ref_collect_used_type_idx_instrs(catch_body, used)
        }
      }
      @lib.If(block_type, then_body, else_body) => {
        dae_prune_max_ref_mark_used_block_type(block_type, used)
        dae_prune_max_ref_collect_used_type_idx_instrs(then_body, used)
        match else_body {
          Some(body) =>
            dae_prune_max_ref_collect_used_type_idx_instrs(body, used)
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
        dae_prune_max_ref_mark_used_type_idx(type_idx, used)
      @lib.ContBind(source_type, target_type)
      | @lib.ArrayCopy(source_type, target_type) => {
        dae_prune_max_ref_mark_used_type_idx(source_type, used)
        dae_prune_max_ref_mark_used_type_idx(target_type, used)
      }
      @lib.Select(Some(types)) =>
        for val_type in types {
          dae_prune_max_ref_mark_used_val_type(val_type, used)
        }
      @lib.RefNull(rt) => dae_prune_max_ref_mark_used_ref_type(rt, used)
      @lib.RefTest(_, _, ht)
      | @lib.RefCast(_, _, ht)
      | @lib.RefTestDesc(_, ht)
      | @lib.RefCastDescEq(_, _, ht) =>
        dae_prune_max_ref_mark_used_heap_type(ht, used)
      @lib.BrOnCast(_, _, source_ht, target_ht)
      | @lib.BrOnCastFail(_, _, source_ht, target_ht) => {
        dae_prune_max_ref_mark_used_heap_type(source_ht, used)
        dae_prune_max_ref_mark_used_heap_type(target_ht, used)
      }
      @lib.BrOnCastDescEq(_, source_type, target_type)
      | @lib.BrOnCastDescEqFail(_, source_type, target_type) => {
        dae_prune_max_ref_mark_used_ref_type(source_type, used)
        dae_prune_max_ref_mark_used_ref_type(target_type, used)
      }
      _ => ()
    }
  }
}

///|
fn dae_prune_max_ref_rewrite_pruned_heap_type(
  ht : @lib.HeapType,
  remap : Array[Int32],
) -> @lib.HeapType {
  match ht {
    @lib.HeapType(type_idx) =>
      @lib.HeapType::new(
        dae_prune_max_ref_rewrite_pruned_type_idx(type_idx, remap),
      )
    _ => ht
  }
}

///|
fn dae_prune_max_ref_rewrite_pruned_ref_type(
  rt : @lib.RefType,
  remap : Array[Int32],
) -> @lib.RefType {
  match rt {
    @lib.HeapTypeRefType(nullable, exact, heap_type) =>
      @lib.RefType::new(
        nullable,
        dae_prune_max_ref_rewrite_pruned_heap_type(heap_type, remap),
        exact~,
      )
    _ => rt
  }
}

///|
fn dae_prune_max_ref_rewrite_pruned_val_type(
  vt : @lib.ValType,
  remap : Array[Int32],
) -> @lib.ValType {
  match vt {
    @lib.RefTypeValType(rt) =>
      @lib.ValType::ref_type(
        dae_prune_max_ref_rewrite_pruned_ref_type(rt, remap),
      )
    _ => vt
  }
}

///|
fn dae_prune_max_ref_rewrite_pruned_table_type(
  tt : @lib.TableType,
  remap : Array[Int32],
) -> @lib.TableType {
  let @lib.TableType(rt, limits) = tt
  @lib.TableType::new(
    dae_prune_max_ref_rewrite_pruned_ref_type(rt, remap),
    limits,
  )
}

///|
fn dae_prune_max_ref_rewrite_pruned_global_type(
  gt : @lib.GlobalType,
  remap : Array[Int32],
) -> @lib.GlobalType {
  let @lib.GlobalType(vt, mutable) = gt
  @lib.GlobalType::new(
    dae_prune_max_ref_rewrite_pruned_val_type(vt, remap),
    mutable,
  )
}

///|
fn dae_prune_max_ref_rewrite_pruned_type_idx(
  idx : @lib.TypeIdx,
  remap : Array[Int32],
) -> @lib.TypeIdx {
  match idx {
    @lib.TypeIdx(raw) => {
      let slot = raw.reinterpret_as_int()
      if slot >= 0 && slot < remap.length() && remap[slot] >= 0 {
        @lib.TypeIdx::new(remap[slot].reinterpret_as_uint())
      } else {
        idx
      }
    }
    @lib.RecIdx(_) => idx
  }
}

///|
fn dae_prune_max_ref_pruned_type_idx_unchanged(
  idx : @lib.TypeIdx,
  remap : Array[Int32],
) -> Bool {
  match idx {
    @lib.TypeIdx(raw) => {
      let slot = raw.reinterpret_as_int()
      slot < 0 ||
      slot >= remap.length() ||
      remap[slot] < 0 ||
      remap[slot] == slot
    }
    @lib.RecIdx(_) => true
  }
}

///|
fn dae_prune_max_ref_pruned_heap_type_unchanged(
  ht : @lib.HeapType,
  remap : Array[Int32],
) -> Bool {
  match ht {
    @lib.HeapType(idx) =>
      dae_prune_max_ref_pruned_type_idx_unchanged(idx, remap)
    _ => true
  }
}

///|
fn dae_prune_max_ref_pruned_ref_type_unchanged(
  rt : @lib.RefType,
  remap : Array[Int32],
) -> Bool {
  match rt {
    @lib.HeapTypeRefType(_, _, ht) =>
      dae_prune_max_ref_pruned_heap_type_unchanged(ht, remap)
    _ => true
  }
}

///|
fn dae_prune_max_ref_pruned_val_type_unchanged(
  vt : @lib.ValType,
  remap : Array[Int32],
) -> Bool {
  match vt {
    @lib.RefTypeValType(rt) =>
      dae_prune_max_ref_pruned_ref_type_unchanged(rt, remap)
    _ => true
  }
}

///|
fn dae_prune_max_ref_pruned_block_type_unchanged(
  bt : @lib.BlockType,
  remap : Array[Int32],
) -> Bool {
  match bt {
    @lib.TypeIdxBlockType(idx) =>
      dae_prune_max_ref_pruned_type_idx_unchanged(idx, remap)
    @lib.ValTypeBlockType(vt) =>
      dae_prune_max_ref_pruned_val_type_unchanged(vt, remap)
    _ => true
  }
}

///|
fn dae_prune_max_ref_rewrite_pruned_type_idx_instr(
  instr : @lib.Instruction,
  remap : Array[Int32],
) -> @lib.Instruction {
  let rewrite_block_type = fn(block_type : @lib.BlockType) -> @lib.BlockType {
    match block_type {
      @lib.TypeIdxBlockType(type_idx) =>
        @lib.BlockType::type_idx(
          dae_prune_max_ref_rewrite_pruned_type_idx(type_idx, remap),
        )
      @lib.ValTypeBlockType(val_type) =>
        @lib.BlockType::val_type(
          dae_prune_max_ref_rewrite_pruned_val_type(val_type, remap),
        )
      _ => block_type
    }
  }
  match instr {
    @lib.Block(block_type, @lib.Expr(body)) => {
      let next_body = dae_prune_max_ref_rewrite_pruned_type_idx_instrs(
        body, remap,
      )
      if physical_equal(next_body, body) &&
        dae_prune_max_ref_pruned_block_type_unchanged(block_type, remap) {
        return instr
      }
      return @lib.Instruction::block(
        rewrite_block_type(block_type),
        @lib.Expr::new(next_body),
      )
    }
    @lib.Loop(block_type, @lib.Expr(body)) => {
      let next_body = dae_prune_max_ref_rewrite_pruned_type_idx_instrs(
        body, remap,
      )
      if physical_equal(next_body, body) &&
        dae_prune_max_ref_pruned_block_type_unchanged(block_type, remap) {
        return instr
      }
      return @lib.Instruction::loop_(
        rewrite_block_type(block_type),
        @lib.Expr::new(next_body),
      )
    }
    @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
      let next_body = dae_prune_max_ref_rewrite_pruned_type_idx_instrs(
        body, remap,
      )
      if physical_equal(next_body, body) &&
        dae_prune_max_ref_pruned_block_type_unchanged(block_type, remap) {
        return instr
      }
      return @lib.Instruction::try_table(
        rewrite_block_type(block_type),
        catches,
        @lib.Expr::new(next_body),
      )
    }
    @lib.Try(block_type, @lib.Expr(body), catches, delegate) => {
      let next_body = dae_prune_max_ref_rewrite_pruned_type_idx_instrs(
        body, remap,
      )
      let mut rewritten_catches : Array[@lib.LegacyCatch]? = None
      for index = 0; index < catches.length(); index = index + 1 {
        let catch_ = catches[index]
        let catch_body = match catch_ {
          @lib.LegacyCatch(_, @lib.Expr(catch_body))
          | @lib.LegacyCatchAll(@lib.Expr(catch_body)) => catch_body
        }
        let next_catch = dae_prune_max_ref_rewrite_pruned_type_idx_instrs(
          catch_body, remap,
        )
        if !physical_equal(next_catch, catch_body) {
          let rewritten = match catch_ {
            @lib.LegacyCatch(tag_idx, _) =>
              @lib.LegacyCatch::tagged(tag_idx, @lib.Expr::new(next_catch))
            @lib.LegacyCatchAll(_) =>
              @lib.LegacyCatch::all(@lib.Expr::new(next_catch))
          }
          match rewritten_catches {
            Some(copy) => copy[index] = rewritten
            None => {
              let copy = catches.copy()
              copy[index] = rewritten
              rewritten_catches = Some(copy)
            }
          }
        }
      }
      if physical_equal(next_body, body) &&
        rewritten_catches is None &&
        dae_prune_max_ref_pruned_block_type_unchanged(block_type, remap) {
        return instr
      }
      return @lib.Instruction::try_(
        rewrite_block_type(block_type),
        @lib.Expr::new(next_body),
        rewritten_catches.unwrap_or(catches),
        delegate~,
      )
    }
    @lib.If(block_type, then_body, else_body) => {
      let next_then = dae_prune_max_ref_rewrite_pruned_type_idx_instrs(
        then_body, remap,
      )
      let mut else_changed = false
      let next_else = match else_body {
        Some(body) => {
          let next = dae_prune_max_ref_rewrite_pruned_type_idx_instrs(
            body, remap,
          )
          if physical_equal(next, body) {
            else_body
          } else {
            else_changed = true
            Some(next)
          }
        }
        None => None
      }
      if physical_equal(next_then, then_body) &&
        !else_changed &&
        dae_prune_max_ref_pruned_block_type_unchanged(block_type, remap) {
        return instr
      }
      return @lib.Instruction::if_(
        rewrite_block_type(block_type),
        next_then,
        next_else,
      )
    }
    _ => ()
  }
  // These arms inspect only the fields that this remapper rewrites. Embedded
  // definitions and every unrelated opcode keep their existing ownership.
  let unchanged = match instr {
    @lib.CallIndirect(idx, _)
    | @lib.ReturnCallIndirect(idx, _)
    | @lib.CallRef(idx)
    | @lib.ReturnCallRef(idx)
    | @lib.ContNew(idx)
    | @lib.Resume(idx, _)
    | @lib.ResumeThrow(idx, _, _)
    | @lib.ResumeThrowRef(idx, _)
    | @lib.StackSwitch(idx, _)
    | @lib.RefGetDesc(idx) =>
      dae_prune_max_ref_pruned_type_idx_unchanged(idx, remap)
    @lib.ContBind(source_type, target_type) =>
      dae_prune_max_ref_pruned_type_idx_unchanged(source_type, remap) &&
      dae_prune_max_ref_pruned_type_idx_unchanged(target_type, remap)
    @lib.Select(Some(types)) =>
      types.all(fn(vt) {
        dae_prune_max_ref_pruned_val_type_unchanged(vt, remap)
      })
    @lib.RefNull(rt) => dae_prune_max_ref_pruned_ref_type_unchanged(rt, remap)
    @lib.RefTest(_, _, ht)
    | @lib.RefCast(_, _, ht)
    | @lib.RefTestDesc(_, ht)
    | @lib.RefCastDescEq(_, _, ht) =>
      dae_prune_max_ref_pruned_heap_type_unchanged(ht, remap)
    @lib.BrOnCast(_, _, source_type, target_type)
    | @lib.BrOnCastFail(_, _, source_type, target_type) =>
      dae_prune_max_ref_pruned_heap_type_unchanged(source_type, remap) &&
      dae_prune_max_ref_pruned_heap_type_unchanged(target_type, remap)
    @lib.BrOnCastDescEq(_, source_type, target_type)
    | @lib.BrOnCastDescEqFail(_, source_type, target_type) =>
      dae_prune_max_ref_pruned_ref_type_unchanged(source_type, remap) &&
      dae_prune_max_ref_pruned_ref_type_unchanged(target_type, remap)
    _ => true
  }
  if unchanged {
    return instr
  }
  match instr {
    @lib.CallIndirect(type_idx, table_idx) =>
      @lib.Instruction::call_indirect(
        dae_prune_max_ref_rewrite_pruned_type_idx(type_idx, remap),
        table_idx,
      )
    @lib.ReturnCallIndirect(type_idx, table_idx) =>
      @lib.Instruction::return_call_indirect(
        dae_prune_max_ref_rewrite_pruned_type_idx(type_idx, remap),
        table_idx,
      )
    @lib.CallRef(type_idx) =>
      @lib.Instruction::call_ref(
        dae_prune_max_ref_rewrite_pruned_type_idx(type_idx, remap),
      )
    @lib.ReturnCallRef(type_idx) =>
      @lib.Instruction::return_call_ref(
        dae_prune_max_ref_rewrite_pruned_type_idx(type_idx, remap),
      )
    @lib.ContNew(type_idx) =>
      @lib.Instruction::cont_new(
        dae_prune_max_ref_rewrite_pruned_type_idx(type_idx, remap),
      )
    @lib.ContBind(source_type, target_type) =>
      @lib.Instruction::cont_bind(
        dae_prune_max_ref_rewrite_pruned_type_idx(source_type, remap),
        dae_prune_max_ref_rewrite_pruned_type_idx(target_type, remap),
      )
    @lib.Resume(type_idx, handlers) =>
      @lib.Instruction::resume_(
        dae_prune_max_ref_rewrite_pruned_type_idx(type_idx, remap),
        handlers,
      )
    @lib.ResumeThrow(type_idx, tag, handlers) =>
      @lib.Instruction::resume_throw(
        dae_prune_max_ref_rewrite_pruned_type_idx(type_idx, remap),
        tag,
        handlers,
      )
    @lib.ResumeThrowRef(type_idx, handlers) =>
      @lib.Instruction::resume_throw_ref(
        dae_prune_max_ref_rewrite_pruned_type_idx(type_idx, remap),
        handlers,
      )
    @lib.StackSwitch(type_idx, tag) =>
      @lib.Instruction::stack_switch(
        dae_prune_max_ref_rewrite_pruned_type_idx(type_idx, remap),
        tag,
      )
    @lib.Select(Some(types)) =>
      @lib.Instruction::select(
        types=Some(
          types.map(fn(vt) {
            dae_prune_max_ref_rewrite_pruned_val_type(vt, remap)
          }),
        ),
      )
    @lib.RefNull(rt) =>
      @lib.Instruction::ref_null_type(
        dae_prune_max_ref_rewrite_pruned_ref_type(rt, remap),
      )
    @lib.RefGetDesc(type_idx) =>
      @lib.Instruction::ref_get_desc(
        dae_prune_max_ref_rewrite_pruned_type_idx(type_idx, remap),
      )
    @lib.RefTest(nullable, exact, ht) =>
      @lib.Instruction::ref_test_type(
        @lib.RefType::new(
          nullable,
          dae_prune_max_ref_rewrite_pruned_heap_type(ht, remap),
          exact~,
        ),
      )
    @lib.RefCast(nullable, exact, ht) =>
      @lib.Instruction::ref_cast_type(
        @lib.RefType::new(
          nullable,
          dae_prune_max_ref_rewrite_pruned_heap_type(ht, remap),
          exact~,
        ),
      )
    @lib.RefTestDesc(nullable, ht) =>
      @lib.Instruction::ref_test_desc(
        nullable,
        dae_prune_max_ref_rewrite_pruned_heap_type(ht, remap),
      )
    @lib.RefCastDescEq(nullable, exact, ht) =>
      @lib.Instruction::ref_cast_desc_eq_type(
        @lib.RefType::new(
          nullable,
          dae_prune_max_ref_rewrite_pruned_heap_type(ht, remap),
          exact~,
        ),
      )
    @lib.BrOnCast(
      label,
      @lib.CastOp(source_nullable, target_nullable, source_exact, target_exact),
      source_type,
      target_type
    ) =>
      @lib.Instruction::br_on_cast(
        label,
        source_nullable,
        dae_prune_max_ref_rewrite_pruned_heap_type(source_type, remap),
        target_nullable,
        dae_prune_max_ref_rewrite_pruned_heap_type(target_type, remap),
        source_exact~,
        target_exact~,
      )
    @lib.BrOnCastFail(
      label,
      @lib.CastOp(source_nullable, target_nullable, source_exact, target_exact),
      source_type,
      target_type
    ) =>
      @lib.Instruction::br_on_cast_fail(
        label,
        source_nullable,
        dae_prune_max_ref_rewrite_pruned_heap_type(source_type, remap),
        target_nullable,
        dae_prune_max_ref_rewrite_pruned_heap_type(target_type, remap),
        source_exact~,
        target_exact~,
      )
    @lib.BrOnCastDescEq(label, source_type, target_type) =>
      @lib.Instruction::br_on_cast_desc_eq(
        label,
        dae_prune_max_ref_rewrite_pruned_ref_type(source_type, remap),
        dae_prune_max_ref_rewrite_pruned_ref_type(target_type, remap),
      )
    @lib.BrOnCastDescEqFail(label, source_type, target_type) =>
      @lib.Instruction::br_on_cast_desc_eq_fail(
        label,
        dae_prune_max_ref_rewrite_pruned_ref_type(source_type, remap),
        dae_prune_max_ref_rewrite_pruned_ref_type(target_type, remap),
      )
    _ => instr
  }
}

///|
fn dae_prune_max_ref_rewrite_pruned_type_idx_instrs(
  instrs : Array[@lib.Instruction],
  remap : Array[Int32],
) -> Array[@lib.Instruction] {
  let mut out : Array[@lib.Instruction]? = None
  for index = 0; index < instrs.length(); index = index + 1 {
    let instr = instrs[index]
    let next = dae_prune_max_ref_rewrite_pruned_type_idx_instr(instr, remap)
    match out {
      Some(copy) => copy.push(next)
      None =>
        if !physical_equal(next, instr) {
          let copy = Array::new(capacity=instrs.length())
          for prefix = 0; prefix < index; prefix = prefix + 1 {
            copy.push(instrs[prefix])
          }
          copy.push(next)
          out = Some(copy)
        }
    }
  }
  out.unwrap_or(instrs)
}

///|
fn dae_prune_max_ref_val_type_has_indexed_heap_type(vt : @lib.ValType) -> Bool {
  match vt {
    @lib.RefTypeValType(@lib.HeapTypeRefType(_, _, @lib.HeapType(_))) => true
    @lib.RefTypeValType(@lib.HeapTypeRefType(_, _, @lib.DefTypeHeapType(_))) =>
      true
    _ => false
  }
}

///|
fn dae_prune_max_ref_storage_type_has_indexed_heap_type(
  storage : @lib.StorageType,
) -> Bool {
  match storage {
    @lib.ValTypeStorageType(vt) =>
      dae_prune_max_ref_val_type_has_indexed_heap_type(vt)
    _ => false
  }
}

///|
fn dae_prune_max_ref_comp_type_has_indexed_heap_type(
  comp_type : @lib.CompType,
) -> Bool {
  match comp_type {
    @lib.FuncCompType(params, results) =>
      params.any(dae_prune_max_ref_val_type_has_indexed_heap_type) ||
      results.any(dae_prune_max_ref_val_type_has_indexed_heap_type)
    @lib.StructCompType(fields) =>
      fields.any(fn(field) {
        let @lib.FieldType(storage, _) = field
        dae_prune_max_ref_storage_type_has_indexed_heap_type(storage)
      })
    @lib.ArrayCompType(field) => {
      let @lib.FieldType(storage, _) = field
      dae_prune_max_ref_storage_type_has_indexed_heap_type(storage)
    }
    @lib.ContCompType(_) => true
  }
}

///|
fn dae_prune_max_ref_prune_unused_simple_func_types(
  mod_ : @lib.Module,
  preserve_names~ : Bool = false,
) -> @lib.Module {
  let rec_types = match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) => rec_types
    None => return mod_
  }
  if !dae_prune_max_ref_simple_func_type_section(rec_types) {
    return mod_
  }
  let used = Array::make(rec_types.length(), false)
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(type_idx)) =>
            dae_prune_max_ref_mark_used_type_idx(type_idx, used)
          @lib.Import(_, _, @lib.TableExternType(table_type)) =>
            dae_prune_max_ref_mark_used_table_type(table_type, used)
          @lib.Import(_, _, @lib.GlobalExternType(global_type)) =>
            dae_prune_max_ref_mark_used_global_type(global_type, used)
          @lib.Import(_, _, @lib.TagExternType(tag_type)) => {
            let @lib.TagType(type_idx) = tag_type
            dae_prune_max_ref_mark_used_type_idx(type_idx, used)
          }
          _ => ()
        }
      }
    None => ()
  }
  match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) =>
      for type_idx in type_idxs {
        dae_prune_max_ref_mark_used_type_idx(type_idx, used)
      }
    None => ()
  }
  match mod_.tag_sec {
    Some(@lib.TagSec(tags)) =>
      for tag in tags {
        let @lib.TagType(type_idx) = tag
        dae_prune_max_ref_mark_used_type_idx(type_idx, used)
      }
    None => ()
  }
  match mod_.table_sec {
    Some(@lib.TableSec(tables)) =>
      for table in tables {
        let @lib.Table(table_type, initializer) = table
        dae_prune_max_ref_mark_used_table_type(table_type, used)
        match initializer {
          Some(@lib.Expr(body)) =>
            dae_prune_max_ref_collect_used_type_idx_instrs(body, used)
          None => ()
        }
      }
    None => ()
  }
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) =>
      for global in globals {
        let @lib.Global(global_type, @lib.Expr(body)) = global
        dae_prune_max_ref_mark_used_global_type(global_type, used)
        dae_prune_max_ref_collect_used_type_idx_instrs(body, used)
      }
    None => ()
  }
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) =>
      for elem in elems {
        let @lib.Elem(_, kind) = elem
        match kind {
          @lib.TypedExprsElemKind(ref_type, exprs) => {
            dae_prune_max_ref_mark_used_ref_type(ref_type, used)
            for expr in exprs {
              let @lib.Expr(body) = expr
              dae_prune_max_ref_collect_used_type_idx_instrs(body, used)
            }
          }
          @lib.FuncExprsElemKind(exprs) =>
            for expr in exprs {
              let @lib.Expr(body) = expr
              dae_prune_max_ref_collect_used_type_idx_instrs(body, used)
            }
          _ => ()
        }
      }
    None => ()
  }
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(body)) = func
        for local_run in locals.runs() {
          dae_prune_max_ref_mark_used_val_type(local_run.val_type(), used)
        }
        dae_prune_max_ref_collect_used_type_idx_instrs(body, used)
      }
    None => ()
  }
  // The current remapper rewrites every module-level reference but does not
  // reconstruct retained type definitions. Prune a mixed flat section only
  // when each retained definition is internally index-free; unused function
  // signatures may still reference GC types and disappear safely.
  for old_idx = 0; old_idx < rec_types.length(); old_idx = old_idx + 1 {
    if !used[old_idx] {
      continue
    }
    match rec_types[old_idx] {
      @lib.SingleRecType(subtype) =>
        if dae_prune_max_ref_comp_type_has_indexed_heap_type(
            subtype.get_comptype(),
          ) {
          return mod_
        }
      @lib.GroupRecType(_) => return mod_
    }
  }
  let remap = Array::make(rec_types.length(), -1)
  let next_types : Array[@lib.RecType] = []
  let mut old_idx = 0
  while old_idx < rec_types.length() {
    if used[old_idx] {
      remap[old_idx] = next_types.length()
      next_types.push(rec_types[old_idx])
    }
    old_idx += 1
  }
  if next_types.length() == rec_types.length() {
    return mod_
  }
  // Type-index-bearing GC instructions are conservatively left untouched by
  // this compact remapper. Require every retained non-function definition to
  // keep its original slot; function types may shift because all function,
  // block, tag, call-ref, import, and signature references are rewritten.
  for old_idx = 0; old_idx < rec_types.length(); old_idx = old_idx + 1 {
    if !used[old_idx] || remap[old_idx] == old_idx {
      continue
    }
    match rec_types[old_idx] {
      @lib.SingleRecType(subtype) =>
        match subtype.get_comptype() {
          @lib.FuncCompType(_, _) => ()
          _ => return mod_
        }
      @lib.GroupRecType(_) => return mod_
    }
  }
  let mut next = mod_
    .with_type_sec(@lib.TypeSec::new(next_types))
    .without_name_sec()
  if preserve_names {
    match mod_.name_sec {
      Some(names) => {
        let type_names = match names.type_names {
          Some(names) => rl_rewrite_name_map(names, remap)
          None => None
        }
        let field_names = match names.field_names {
          Some(@lib.IndirectNameMap(entries)) => {
            let kept : Array[@lib.IndirectNameAssoc] = []
            for entry in entries {
              let @lib.IndirectNameAssoc(type_idx, fields) = entry
              let old_idx = type_idx.to_int()
              if old_idx >= 0 && old_idx < remap.length() && remap[old_idx] >= 0 {
                kept.push(
                  @lib.IndirectNameAssoc::new(
                    remap[old_idx].reinterpret_as_uint(),
                    fields,
                  ),
                )
              }
            }
            if kept.is_empty() {
              None
            } else {
              Some(@lib.IndirectNameMap::new(kept))
            }
          }
          None => None
        }
        next = next.with_name_sec(
          @lib.NameSec::new(
            module_name=names.module_name,
            func_names=names.func_names,
            local_names=names.local_names,
            label_names=names.label_names,
            type_names~,
            table_names=names.table_names,
            memory_names=names.memory_names,
            global_names=names.global_names,
            elem_names=names.elem_names,
            data_names=names.data_names,
            field_names~,
            tag_names=names.tag_names,
          ),
        )
      }
      None => ()
    }
  }
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) => {
      let rewritten : Array[@lib.Import] = []
      for import_ in imports {
        match import_ {
          @lib.Import(module_name, base_name, @lib.FuncExternType(type_idx)) =>
            rewritten.push(
              @lib.Import::new(
                module_name,
                base_name,
                @lib.ExternType::func(
                  dae_prune_max_ref_rewrite_pruned_type_idx(type_idx, remap),
                ),
              ),
            )
          @lib.Import(module_name, base_name, @lib.TableExternType(table_type)) =>
            rewritten.push(
              @lib.Import::new(
                module_name,
                base_name,
                @lib.ExternType::table(
                  dae_prune_max_ref_rewrite_pruned_table_type(table_type, remap),
                ),
              ),
            )
          @lib.Import(
            module_name,
            base_name,
            @lib.GlobalExternType(global_type)
          ) =>
            rewritten.push(
              @lib.Import::new(
                module_name,
                base_name,
                @lib.ExternType::global(
                  dae_prune_max_ref_rewrite_pruned_global_type(
                    global_type, remap,
                  ),
                ),
              ),
            )
          @lib.Import(module_name, base_name, @lib.TagExternType(tag_type)) => {
            let @lib.TagType(type_idx) = tag_type
            rewritten.push(
              @lib.Import::new(
                module_name,
                base_name,
                @lib.ExternType::tag(
                  @lib.TagType::new(
                    dae_prune_max_ref_rewrite_pruned_type_idx(type_idx, remap),
                  ),
                ),
              ),
            )
          }
          _ => rewritten.push(import_)
        }
      }
      next = next.with_import_sec(@lib.ImportSec::new(rewritten))
    }
    None => ()
  }
  match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => {
      let rewritten : Array[@lib.TypeIdx] = []
      for type_idx in type_idxs {
        rewritten.push(
          dae_prune_max_ref_rewrite_pruned_type_idx(type_idx, remap),
        )
      }
      next = next.with_func_sec(@lib.FuncSec::new(rewritten))
    }
    None => ()
  }
  match mod_.tag_sec {
    Some(@lib.TagSec(tags)) => {
      let rewritten : Array[@lib.TagType] = []
      for tag in tags {
        let @lib.TagType(type_idx) = tag
        rewritten.push(
          @lib.TagType::new(
            dae_prune_max_ref_rewrite_pruned_type_idx(type_idx, remap),
          ),
        )
      }
      next = next.with_tag_sec(@lib.TagSec::new(rewritten))
    }
    None => ()
  }
  match mod_.table_sec {
    Some(@lib.TableSec(tables)) => {
      let rewritten : Array[@lib.Table] = []
      for table in tables {
        let @lib.Table(table_type, init) = table
        rewritten.push(
          @lib.Table::new(
            dae_prune_max_ref_rewrite_pruned_table_type(table_type, remap),
            match init {
              Some(@lib.Expr(body)) =>
                Some(
                  @lib.Expr::new(
                    dae_prune_max_ref_rewrite_pruned_type_idx_instrs(
                      body, remap,
                    ),
                  ),
                )
              None => None
            },
          ),
        )
      }
      next = next.with_table_sec(@lib.TableSec::new(rewritten))
    }
    None => ()
  }
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) => {
      let rewritten : Array[@lib.Global] = []
      for global in globals {
        let @lib.Global(global_type, @lib.Expr(body)) = global
        rewritten.push(
          @lib.Global::new(
            dae_prune_max_ref_rewrite_pruned_global_type(global_type, remap),
            @lib.Expr::new(
              dae_prune_max_ref_rewrite_pruned_type_idx_instrs(body, remap),
            ),
          ),
        )
      }
      next = next.with_global_sec(@lib.GlobalSec::new(rewritten))
    }
    None => ()
  }
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) => {
      let rewritten : Array[@lib.Elem] = []
      for elem in elems {
        let @lib.Elem(mode, kind) = elem
        let next_kind = match kind {
          @lib.TypedExprsElemKind(ref_type, exprs) => {
            let next_exprs : Array[@lib.Expr] = []
            for expr in exprs {
              let @lib.Expr(body) = expr
              next_exprs.push(
                @lib.Expr::new(
                  dae_prune_max_ref_rewrite_pruned_type_idx_instrs(body, remap),
                ),
              )
            }
            @lib.ElemKind::typed_exprs(
              dae_prune_max_ref_rewrite_pruned_ref_type(ref_type, remap),
              next_exprs,
            )
          }
          @lib.FuncExprsElemKind(exprs) => {
            let next_exprs : Array[@lib.Expr] = []
            for expr in exprs {
              let @lib.Expr(body) = expr
              next_exprs.push(
                @lib.Expr::new(
                  dae_prune_max_ref_rewrite_pruned_type_idx_instrs(body, remap),
                ),
              )
            }
            @lib.ElemKind::func_exprs(next_exprs)
          }
          _ => kind
        }
        rewritten.push(@lib.Elem::new(mode, next_kind))
      }
      next = next.with_elem_sec(@lib.ElemSec::new(rewritten))
    }
    None => ()
  }
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let rewritten : Array[@lib.Func] = []
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(body)) = func
        let next_runs : Array[@lib.LocalRun] = []
        for run in locals.runs() {
          next_runs.push(
            @lib.LocalRun::new(
              run.count(),
              dae_prune_max_ref_rewrite_pruned_val_type(run.val_type(), remap),
            ),
          )
        }
        rewritten.push(
          @lib.Func::new(
            @lib.Locals::new(next_runs),
            @lib.Expr::new(
              dae_prune_max_ref_rewrite_pruned_type_idx_instrs(body, remap),
            ),
          ),
        )
      }
      next = next.with_code_sec(@lib.CodeSec::new(rewritten))
    }
    None => ()
  }
  next
}
