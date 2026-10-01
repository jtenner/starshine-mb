///|
priv struct GtoTypeOrder {
  types : Array[@lib.SubType]
  seen : Array[Bool]
  order : Array[Int]
  control : Array[@lib.TypeIdx]
}

///|
fn GtoTypeOrder::new(types : Array[@lib.SubType]) -> GtoTypeOrder {
  { types, seen: Array::make(types.length(), false), order: [], control: [], }
}

///|
fn GtoTypeOrder::note(self : GtoTypeOrder, idx : @lib.TypeIdx) -> Unit {
  if idx is @lib.TypeIdx(raw) {
    let i = raw.to_int()
    if i < self.seen.length() && !self.seen[i] {
      self.seen[i] = true
      self.order.push(i)
    }
  }
}

///|
fn GtoTypeOrder::heap(self : GtoTypeOrder, heap : @lib.HeapType) -> Unit {
  if heap is @lib.HeapType(t) {
    self.note(t)
  }
}

///|
fn GtoTypeOrder::value(self : GtoTypeOrder, value : @lib.ValType) -> Unit {
  if value is @lib.RefTypeValType(r) {
    self.heap(r.get_heap_type())
  }
}

///|
fn GtoTypeOrder::block(self : GtoTypeOrder, bt : @lib.BlockType) -> Unit {
  match bt {
    @lib.ValTypeBlockType(v) => self.value(v)
    @lib.TypeIdxBlockType(@lib.TypeIdx(i) as t) =>
      match self.types[i.to_int()].get_comptype() {
        @lib.FuncCompType([], [v]) => self.value(v)
        @lib.FuncCompType([], []) => ()
        _ => self.control.push(t)
      }
    _ => ()
  }
}

///|
fn GtoTypeOrder::scan(self : GtoTypeOrder, expr : @lib.Expr) -> Unit {
  for instr in expr.0 {
    ignore(
      gto_map_children(instr, fn(body) {
        self.scan(body)
        body
      }),
    )
    match instr {
      @lib.Block(bt, _)
      | @lib.Loop(bt, _)
      | @lib.If(bt, _, _)
      | @lib.TryTable(bt, _, _)
      | @lib.Try(bt, _, _, _) => self.block(bt)
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
      | @lib.ArrayStore(_, type_idx, _) => self.note(type_idx)
      @lib.ContBind(source_type, target_type)
      | @lib.ArrayCopy(source_type, target_type) => {
        self.note(source_type)
        self.note(target_type)
      }
      @lib.Select(Some(types)) =>
        for val_type in types {
          self.value(val_type)
        }
      @lib.RefNull(rt) => self.heap(rt.get_heap_type())
      @lib.RefTest(_, _, ht)
      | @lib.RefCast(_, _, ht)
      | @lib.RefTestDesc(_, ht)
      | @lib.RefCastDescEq(_, _, ht) => self.heap(ht)
      @lib.BrOnCast(_, _, source_ht, target_ht)
      | @lib.BrOnCastFail(_, _, source_ht, target_ht) => {
        self.heap(source_ht)
        self.heap(target_ht)
      }
      @lib.BrOnCastDescEq(_, source_type, target_type)
      | @lib.BrOnCastDescEqFail(_, source_type, target_type) => {
        self.heap(source_type.get_heap_type())
        self.heap(target_type.get_heap_type())
      }
      _ => ()
    }
  }
}

///|
// Match collectHeapTypeInfo's first-use order: module expressions, module
// declarations, then each function signature, locals and postorder body.
fn gto_collect_type_order(mod_ : @lib.Module) -> Array[Int] {
  let context = @ir.hot_module_context_from_module(mod_)
  let collector = GtoTypeOrder::new(context.subtypes)
  ignore(
    gto_map_initializers(mod_, fn(body) {
      collector.scan(body)
      body
    }),
  )
  for @lib.GlobalType(v, _) in context.globals {
    collector.value(v)
  }
  for @lib.TagType(t) in context.tags {
    collector.note(t)
  }
  for @lib.TableType(r, _) in context.tables {
    collector.heap(r.get_heap_type())
  }
  if mod_.elem_sec is Some(@lib.ElemSec(elems)) {
    for @lib.Elem(_, kind) in elems {
      if kind is @lib.TypedExprsElemKind(r, _) {
        collector.heap(r.get_heap_type())
      }
    }
  }
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(fs)) => fs
    None => []
  }
  let imported = context.func_type_idxs.length() - funcs.length()
  for i, t in context.func_type_idxs {
    collector.note(t)
    if i >= imported {
      let @lib.Func(locals, body) = funcs[i - imported]
      for run in locals.runs() {
        collector.value(run.val_type())
      }
      collector.scan(body)
    }
  }
  let mut cursor = 0
  let mut control_cursor = 0
  while cursor < collector.order.length() ||
        control_cursor < collector.control.length() {
    while cursor < collector.order.length() {
      let slot = collector.order[cursor]
      ignore(
        gto_map_subtype_indices(context.subtypes[slot], fn(t) {
          collector.note(t)
          t
        }),
      )
      cursor += 1
    }
    if control_cursor < collector.control.length() {
      collector.note(collector.control[control_cursor])
      control_cursor += 1
    }
  }
  collector.order
}
