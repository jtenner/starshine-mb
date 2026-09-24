///|
priv struct MsoReferences {
  indices : Map[UInt, UInt]
  functions : Array[@lib.FuncIdx]
  needs_table : Array[Bool]
  types : Array[@lib.SubType]
}

///|
fn MsoReferences::new(types : Array[@lib.SubType]) -> MsoReferences {
  { indices: Map([]), functions: [], needs_table: [false], types, }
}

///|
fn MsoReferences::index(self : MsoReferences, raw : UInt) -> UInt {
  match self.indices.get(raw) {
    Some(i) => i
    None => {
      let i = self.functions.length().to_uint()
      self.indices[raw] = i
      self.functions.push(@lib.FuncIdx::new(raw))
      i
    }
  }
}

///|
fn MsoReferences::scan(self : MsoReferences, expr : @lib.Expr) -> Unit {
  for pos, instr in expr.0 {
    match instr {
      @lib.RefFunc(@lib.FuncIdx(raw)) => ignore(self.index(raw))
      @lib.CallRef(_) | @lib.ReturnCallRef(_) =>
        if pos == 0 || !(expr.0[pos - 1] is @lib.RefNull(_)) {
          self.needs_table[0] = true
        }
      @lib.CallIndirect(_, _) | @lib.ReturnCallIndirect(_, _) =>
        self.needs_table[0] = true
      @lib.RefTest(_, _, @lib.HeapType(t))
      | @lib.RefCast(_, _, @lib.HeapType(t)) =>
        if mso_function_type(self.types, t) {
          self.needs_table[0] = true
        }
      _ => ()
    }
    ignore(
      gto_map_children(instr, fn(body) {
        self.scan(body)
        body
      }),
    )
  }
}

///|
fn mso_collect_references(
  mod_ : @lib.Module,
  types : Array[@lib.SubType],
) -> MsoReferences {
  let refs = MsoReferences::new(types)
  match mod_.global_sec {
    Some(@lib.GlobalSec(gs)) =>
      for @lib.Global(_, init) in gs {
        refs.scan(init)
      }
    None => ()
  }
  match mod_.table_sec {
    Some(@lib.TableSec(ts)) =>
      for @lib.Table(_, init) in ts {
        if init is Some(e) {
          refs.scan(e)
        }
      }
    None => ()
  }
  match mod_.code_sec {
    Some(@lib.CodeSec(fs)) =>
      for @lib.Func(_, body) in fs {
        refs.scan(body)
      }
    None => ()
  }
  match mod_.elem_sec {
    Some(@lib.ElemSec(es)) =>
      for @lib.Elem(_, kind) in es {
        match kind {
          @lib.FuncsElemKind(fs) =>
            for @lib.FuncIdx(raw) in fs {
              ignore(refs.index(raw))
            }
          @lib.FuncExprsElemKind(es) | @lib.TypedExprsElemKind(_, es) =>
            for e in es {
              refs.scan(e)
            }
        }
      }
    None => ()
  }
  refs
}

///|
fn mso_signature_cast(
  out : Array[@lib.Instruction],
  instr : @lib.Instruction,
  nullable : Bool,
  exact : Bool,
  heap : @lib.HeapType,
  function_table : @lib.TableIdx,
  scratch : (@lib.Locals, Int)?,
  is_test : Bool,
) -> Unit {
  let original_type = @lib.RefType::new(nullable, heap, exact~)
  if is_test && out.last() is Some(@lib.RefI31Shared | @lib.RefAsNonNull) {
    out.push(@lib.Instruction::i31_get_u())
    out.push(@lib.Instruction::table_get(function_table))
    out.push(@lib.Instruction::ref_test_type(original_type))
    return
  }
  let (locals, params) = match scratch {
    Some(s) => s
    None => {
      out.push(instr)
      return
    }
  }
  let slot = @lib.LocalIdx::new((params + locals.length()).to_uint())
  locals.push(mso_shared_i31(true))
  out.push(@lib.Instruction::local_tee(slot))
  out.push(@lib.Instruction::ref_is_null())
  let check = [
    @lib.Instruction::local_get(slot),
    @lib.Instruction::i31_get_u(),
    @lib.Instruction::table_get(function_table),
    @lib.Instruction::ref_test_type(original_type),
  ]
  if is_test {
    out.push(
      @lib.Instruction::if_(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        [@lib.Instruction::i32_const(@lib.I32(if nullable { 1 } else { 0 }))],
        Some(check),
      ),
    )
  } else {
    let result_type = @lib.BlockType::val_type(mso_shared_i31(nullable))
    let pass = [@lib.Instruction::local_get(slot)]
    if !nullable {
      pass.push(@lib.Instruction::ref_as_non_null())
    }
    check.push(
      @lib.Instruction::if_(
        result_type,
        pass,
        Some([@lib.Instruction::unreachable_()]),
      ),
    )
    let if_null = if nullable {
      [@lib.Instruction::local_get(slot)]
    } else {
      [@lib.Instruction::unreachable_()]
    }
    out.push(@lib.Instruction::if_(result_type, if_null, Some(check)))
  }
}

///|
fn mso_refinalized_block_type(
  block_type : @lib.BlockType,
  expr : @lib.Expr,
  types : Array[@lib.SubType],
) -> @lib.BlockType {
  let fallback = mso_rewrite_block_type(block_type, types)
  match block_type {
    @lib.ValTypeBlockType(@lib.RefTypeValType(r)) if r.is_nullable() => ()
    _ => return fallback
  }
  let body = expr.0
  if body.length() < 2 {
    return fallback
  }
  let source = match body[0] {
    @lib.RefNull(r) => r
    _ => return fallback
  }
  let only_null = if body[1] is @lib.Br(@lib.LabelIdx(0U)) {
    // Instructions after this unconditional branch cannot add another value.
    true
  } else if body.length() >= 3 {
    // A single leaf selector cannot consume or replace the null payload.
    let leaf = body[1] is @lib.I32Const(_) ||
      body[1] is @lib.LocalGet(_) ||
      body[1] is @lib.GlobalGet(_)
    leaf &&
    (match body[2] {
      @lib.BrIf(@lib.LabelIdx(0U)) => body.length() == 3
      @lib.BrTable(labels, fallback) =>
        run_hot_pipeline_merge_blocks_br_table_all_self(labels, fallback)
      _ => false
    })
  } else {
    false
  }
  if !only_null {
    return fallback
  }
  @lib.BlockType::val_type(
    @lib.ValType::ref_type(mso_null_ref_type(source, types)),
  )
}

///|
fn mso_null_ref_type(
  source : @lib.RefType,
  types : Array[@lib.SubType],
) -> @lib.RefType {
  let bottom = match source.get_heap_type() {
    @lib.SharedAbsHeapTypeHeapType(abs) => {
      let unshared = @lib.RefType::new(true, @lib.HeapType::abs(abs))
      let bottom = remove_unused_brs_null_bottom_ref_type(unshared).unwrap()
      match bottom.get_heap_type() {
        @lib.AbsHeapTypeHeapType(abs) =>
          @lib.RefType::new(true, @lib.HeapType::shared_abs(abs))
        _ => return mso_rewrite_ref_type(source, types)
      }
    }
    @lib.HeapType(t) => {
      let heap = if mso_function_type(types, t) {
        @lib.AbsHeapType::no_func()
      } else if t is @lib.TypeIdx(i) &&
        types[i.to_int()].get_comptype() is @lib.ContCompType(_) {
        @lib.AbsHeapType::no_cont()
      } else {
        @lib.AbsHeapType::none()
      }
      @lib.RefType::new(true, @lib.HeapType::abs(heap))
    }
    _ =>
      match remove_unused_brs_null_bottom_ref_type(source) {
        Some(r) => r
        None => return mso_rewrite_ref_type(source, types)
      }
  }
  mso_rewrite_ref_type(bottom, types)
}

///|
fn mso_emit_null_call(
  out : Array[@lib.Instruction],
  types : Array[@lib.SubType],
  t : @lib.TypeIdx,
) -> Bool {
  if !(out.last() is Some(@lib.RefNull(_))) {
    return false
  }
  let (params, _) = match mso_signature(types, t) {
    Some(sig) => sig
    None => return false
  }
  ignore(out.pop())
  for _ in params {
    match dae_find_droppable_pure_stack_expr_start(out, None) {
      Some(start) =>
        while out.length() > start {
          ignore(out.pop())
        }
      None => out.push(@lib.Instruction::drop())
    }
  }
  out.push(@lib.Instruction::unreachable_())
  true
}
