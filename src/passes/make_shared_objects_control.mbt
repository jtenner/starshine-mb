///|
priv struct MsoControlResults {
  results : Array[@lib.ValType]
  values : Array[@lib.ValType?]
  mut branched : Bool
}

///|
fn MsoControlResults::new(results : Array[@lib.ValType]) -> MsoControlResults {
  { results, values: [], branched: false, }
}

///|
fn mso_control_signature(
  bt : @lib.BlockType,
  types : Array[@lib.SubType],
) -> Array[@lib.ValType]? {
  match bt {
    @lib.VoidBlockType => Some([])
    @lib.ValTypeBlockType(v) => Some([mso_rewrite_val_type(v, types)])
    @lib.TypeIdxBlockType(@lib.TypeIdx(i)) if i.to_int() < types.length() =>
      match types[i.to_int()].get_comptype() {
        @lib.FuncCompType([], results) if results.length() <= 1 =>
          Some(results.map(fn(v) { mso_rewrite_val_type(v, types) }))
        _ => None
      }
    _ => None
  }
}

///|
fn mso_control_internal_ref(
  r : @lib.RefType,
  types : Array[@lib.SubType],
) -> Bool {
  match r.get_heap_type() {
    @lib.SharedAbsHeapTypeHeapType(
      @lib.AnyAbsHeapType
      | @lib.EqAbsHeapType
      | @lib.I31AbsHeapType
      | @lib.StructAbsHeapType
      | @lib.ArrayAbsHeapType
      | @lib.NoneAbsHeapType
    ) => true
    @lib.HeapType(@lib.TypeIdx(i)) if i.to_int() < types.length() =>
      types[i.to_int()].get_comptype()
      is (@lib.StructCompType(_) | @lib.ArrayCompType(_))
    _ => false
  }
}

///|
fn mso_control_join(
  a : @lib.ValType,
  b : @lib.ValType,
  types : Array[@lib.SubType],
) -> @lib.ValType? {
  if a == b {
    return Some(a)
  }
  guard a is @lib.RefTypeValType(a) && b is @lib.RefTypeValType(b) else {
    return None
  }
  let ah = a.get_heap_type()
  let bh = b.get_heap_type()
  let bottom = @lib.HeapType::shared_abs(@lib.AbsHeapType::none())
  let (heap, exact) = if ah == bh {
    (ah, a.is_exact() && b.is_exact())
  } else if ah == bottom && mso_control_internal_ref(b, types) {
    (bh, b.is_exact())
  } else if bh == bottom && mso_control_internal_ref(a, types) {
    (ah, a.is_exact())
  } else {
    return None
  }
  Some(
    @lib.ValType::ref_type(
      @lib.RefType::new(a.is_nullable() || b.is_nullable(), heap, exact~),
    ),
  )
}

///|
fn MsoControlResults::inferred(
  self : MsoControlResults,
  types : Array[@lib.SubType],
) -> @lib.ValType? {
  let mut joined : @lib.ValType? = None
  for value in self.values {
    guard value is Some(value) else { return None }
    joined = match joined {
      None => Some(value)
      Some(old) => mso_control_join(old, value, types)
    }
    if joined is None {
      return None
    }
  }
  joined
}

///|
fn mso_control_note_branch(
  label : @lib.LabelIdx,
  labels : Array[MsoControlResults],
  stack : Array[@lib.ValType?],
  failed : Array[Bool],
) -> Unit {
  let @lib.LabelIdx(depth) = label
  let index = labels.length() - depth.to_int() - 1
  if index < 0 {
    return
  }
  let target = labels[index]
  target.branched = true
  if target.results.length() == 1 {
    if stack.is_empty() {
      failed[0] = true
    }
    target.values.push(stack.last().unwrap_or(None))
  }
}

///|
// Track actual branch payloads, including conditional branches that retain
// their payload on fallthrough. Unknown producers prevent result narrowing;
// instructions and effects are never removed or reordered by this analysis.
fn mso_control_scan(
  body : Array[@lib.Instruction],
  labels : Array[MsoControlResults],
  types : Array[@lib.SubType],
  failed : Array[Bool],
) -> Bool {
  let stack : Array[@lib.ValType?] = []
  let pop = fn() {
    if stack.is_empty() {
      failed[0] = true
    }
    stack.pop().unwrap_or(None)
  }
  for instr in body {
    match instr {
      @lib.RefNull(r) =>
        stack.push(Some(@lib.ValType::ref_type(mso_null_ref_type(r, types))))
      @lib.RefFunc(_) => stack.push(Some(mso_shared_i31(false)))
      @lib.I32Const(_)
      | @lib.I64Const(_)
      | @lib.F32Const(_)
      | @lib.F64Const(_)
      | @lib.LocalGet(_)
      | @lib.GlobalGet(_) => stack.push(None)
      @lib.RefI31 | @lib.RefI31Shared => {
        ignore(pop())
        stack.push(Some(mso_shared_i31(false)))
      }
      @lib.RefAsNonNull => {
        let next = match pop() {
          Some(@lib.RefTypeValType(r)) =>
            Some(
              @lib.ValType::ref_type(
                @lib.RefType::new(false, r.get_heap_type(), exact=r.is_exact()),
              ),
            )
          _ => None
        }
        stack.push(next)
      }
      @lib.Drop | @lib.LocalSet(_) | @lib.GlobalSet(_) => ignore(pop())
      @lib.LocalTee(_) => {
        // local.tee has the declared local type, not its operand's subtype.
        ignore(pop())
        stack.push(None)
      }
      @lib.Nop => ()
      @lib.Br(label) => {
        mso_control_note_branch(label, labels, stack, failed)
        return false
      }
      @lib.BrIf(label) => {
        ignore(pop())
        mso_control_note_branch(label, labels, stack, failed)
      }
      @lib.BrTable(targets, fallback) => {
        ignore(pop())
        for target in targets {
          mso_control_note_branch(target, labels, stack, failed)
        }
        mso_control_note_branch(fallback, labels, stack, failed)
        return false
      }
      @lib.Unreachable
      | @lib.Return
      | @lib.ReturnCall(_)
      | @lib.ReturnCallIndirect(_, _)
      | @lib.ReturnCallRef(_)
      | @lib.Throw(_)
      | @lib.ThrowRef => return false
      @lib.Block(bt, expr) => {
        guard mso_control_signature(bt, types) is Some(results) else {
          failed[0] = true
          return false
        }
        let frame = MsoControlResults::new(results)
        labels.push(frame)
        let fallthrough = mso_control_scan(expr.0, labels, types, failed)
        ignore(labels.pop())
        if !fallthrough && !frame.branched {
          return false
        }
        if results.length() == 1 {
          stack.push(Some(frame.inferred(types).unwrap_or(results[0])))
        }
      }
      @lib.If(bt, yes, no) => {
        ignore(pop())
        guard mso_control_signature(bt, types) is Some(results) else {
          failed[0] = true
          return false
        }
        let frame = MsoControlResults::new(results)
        labels.push(frame)
        let yes_falls = mso_control_scan(yes, labels, types, failed)
        let no_falls = mso_control_scan(no.unwrap_or([]), labels, types, failed)
        ignore(labels.pop())
        if !yes_falls && !no_falls && !frame.branched {
          return false
        }
        if results.length() == 1 {
          stack.push(Some(frame.inferred(types).unwrap_or(results[0])))
        }
      }
      _ => {
        failed[0] = true
        return false
      }
    }
    if failed[0] {
      return false
    }
  }
  let frame = labels.last().unwrap()
  if stack.length() != frame.results.length() {
    failed[0] = true
  } else if frame.results.length() == 1 {
    frame.values.push(stack[0])
  }
  true
}

///|
fn mso_refinalized_control_type(
  bt : @lib.BlockType,
  arms : Array[@lib.Expr],
  types : Array[@lib.SubType],
) -> @lib.BlockType {
  let fallback = mso_rewrite_block_type(bt, types)
  guard mso_control_signature(bt, types)
    is Some([@lib.RefTypeValType(_) as result]) else {
    return fallback
  }
  let frame = MsoControlResults::new([result])
  let failed = [false]
  for arm in arms {
    ignore(mso_control_scan(arm.0, [frame], types, failed))
  }
  if failed[0] {
    return fallback
  }
  match frame.inferred(types) {
    Some(@lib.RefTypeValType(_) as result) => @lib.BlockType::val_type(result)
    _ => fallback
  }
}
