///|
pub impl Show for S33 with fn output(self, logger) {
  let S33(t) = self
  logger.write_string("S33(")
  Show::output(t, logger)
  logger.write_char(')')
}

///|
pub impl Show for I32 with fn output(self, logger) {
  let I32(t) = self
  logger.write_string("I32(")
  Show::output(t, logger)
  logger.write_char(')')
}

///|
pub impl Show for I64 with fn output(self, logger) {
  let I64(t) = self
  logger.write_string("I64(")
  Show::output(t, logger)
  logger.write_char(')')
}

///|
pub impl Show for F32 with fn output(self, logger) {
  let F32(t) = self
  logger.write_string("F32(")
  Show::output(t, logger)
  logger.write_char(')')
}

///|
pub impl Show for F64 with fn output(self, logger) {
  let F64(t) = self
  logger.write_string("F64(")
  Show::output(t, logger)
  logger.write_char(')')
}

///|
pub impl Show for U32 with fn output(self, logger) {
  let U32(t) = self
  logger.write_string("U32(")
  Show::output(t, logger)
  logger.write_char(')')
}

///|
pub impl Show for U64 with fn output(self, logger) {
  let U64(t) = self
  logger.write_string("U64(")
  Show::output(t, logger)
  logger.write_char(')')
}

///|
pub impl Show for NumType with fn output(self, logger) {
  match self {
    F32NumType => logger.write_string("F32")
    F64NumType => logger.write_string("F64")
    I32NumType => logger.write_string("I32")
    I64NumType => logger.write_string("I64")
  }
}

///|
pub impl Show for AbsHeapType with fn output(self, logger) {
  match self {
    ExnAbsHeapType => logger.write_string("(AbsHeapType Exn)")
    StringAbsHeapType => logger.write_string("(AbsHeapType String)")
    ArrayAbsHeapType => logger.write_string("(AbsHeapType Array)")
    StructAbsHeapType => logger.write_string("(AbsHeapType Struct)")
    I31AbsHeapType => logger.write_string("(AbsHeapType I31)")
    EqAbsHeapType => logger.write_string("(AbsHeapType Eq)")
    AnyAbsHeapType => logger.write_string("(AbsHeapType Any)")
    ExternAbsHeapType => logger.write_string("(AbsHeapType Extern)")
    FuncAbsHeapType => logger.write_string("(AbsHeapType Func)")
    NoneAbsHeapType => logger.write_string("(AbsHeapType None)")
    NoExternAbsHeapType => logger.write_string("(AbsHeapType NoExtern)")
    NoFuncAbsHeapType => logger.write_string("(AbsHeapType NoFunc)")
    NoExnAbsHeapType => logger.write_string("(AbsHeapType NoExn)")
  }
}

///|
pub impl Show for HeapType with fn output(self, logger) {
  match self {
    AbsHeapTypeHeapType(ht) => {
      logger.write_string("(HeapType ")
      Show::output(ht, logger)
      logger.write_char(')')
    }
    HeapType(TypeIdx(t)) => {
      logger.write_string("(HeapType Idx ")
      Show::output(t, logger)
      logger.write_char(')')
    }
    HeapType(RecIdx(t)) => {
      logger.write_string("(HeapType Rec ")
      Show::output(t, logger)
      logger.write_char(')')
    }
    DefTypeHeapType(d) => {
      logger.write_string("(HeapType ")
      Show::output(d, logger)
      logger.write_char(')')
    }
  }
}

///|
pub impl Show for DefType with fn output(self, logger) {
  logger.write_string("(DefType ")
  Show::output(self.0, logger)
  logger.write_char(' ')
  Show::output(self.1, logger)
  logger.write_char(')')
}

///|
pub impl Show for RefType with fn output(self, logger) {
  match self {
    HeapTypeRefType(n, exact, ht) => {
      logger.write_string("(RefType ")
      if !n {
        logger.write_string("Not ")
      }
      logger.write_string("Null ")
      if exact {
        logger.write_string("Exact ")
      }
      Show::output(ht, logger)
      logger.write_char(')')
    }
    AbsHeapTypeRefType(aht) => {
      logger.write_string("(RefType Null ")
      Show::output(aht, logger)
      logger.write_char(')')
    }
  }
}

///|
pub impl Show for ValType with fn output(self, logger) {
  match self {
    VecTypeValType => logger.write_string("(V128)")
    NumTypeValType(nt) => Show::output(nt, logger)
    RefTypeValType(rt) => Show::output(rt, logger)
    BotValType => logger.write_string("(Bot)")
  }
}

///|
pub impl Show for PackType with fn output(self, logger) {
  match self {
    I16PackType => logger.write_string("(I16)")
    I8PackType => logger.write_string("(I8)")
  }
}

///|
pub impl Show for StorageType with fn output(self, logger) {
  match self {
    ValTypeStorageType(vt) => Show::output(vt, logger)
    PackTypeStorageType(pt) => Show::output(pt, logger)
  }
}

///|
pub impl Show for FieldType with fn output(self, logger) {
  let FieldType(st, m) = self
  logger.write_string("(Field ")
  Show::output(m, logger)
  logger.write_char(' ')
  Show::output(st, logger)
  logger.write_char(')')
}

///|
pub impl Show for Mut with fn output(self, logger) {
  match self {
    Var => logger.write_string("Mut")
    Const => logger.write_string("Const")
  }
}

///|
pub impl Show for TypeIdx with fn output(self, logger) {
  match self {
    TypeIdx(val) => {
      logger.write_string("(Type ")
      Show::output(val, logger)
      logger.write_char(')')
    }
    RecIdx(i) => {
      logger.write_string("(Rec ")
      Show::output(i, logger)
      logger.write_char(')')
    }
  }
}

///|
pub impl Show for FuncIdx with fn output(self, logger) {
  let FuncIdx(val) = self
  logger.write_string("(Func ")
  Show::output(val, logger)
  logger.write_char(')')
}

///|
pub impl Show for TableIdx with fn output(self, logger) {
  let TableIdx(val) = self
  logger.write_string("(Table ")
  Show::output(val, logger)
  logger.write_char(')')
}

///|
pub impl Show for MemIdx with fn output(self, logger) {
  let MemIdx(val) = self
  logger.write_string("(Mem ")
  Show::output(val, logger)
  logger.write_char(')')
}

///|
pub impl Show for GlobalIdx with fn output(self, logger) {
  let GlobalIdx(val) = self
  logger.write_string("(Global ")
  Show::output(val, logger)
  logger.write_char(')')
}

///|
pub impl Show for TagIdx with fn output(self, logger) {
  let TagIdx(val) = self
  logger.write_string("(Tag ")
  Show::output(val, logger)
  logger.write_char(')')
}

///|
pub impl Show for ElemIdx with fn output(self, logger) {
  let ElemIdx(val) = self
  logger.write_string("(Elem ")
  Show::output(val, logger)
  logger.write_char(')')
}

///|
pub impl Show for DataIdx with fn output(self, logger) {
  let DataIdx(val) = self
  logger.write_string("(Data ")
  Show::output(val, logger)
  logger.write_char(')')
}

///|
pub impl Show for LocalIdx with fn output(self, logger) {
  let LocalIdx(val) = self
  logger.write_string("(Local ")
  Show::output(val, logger)
  logger.write_char(')')
}

///|
pub impl Show for LabelIdx with fn output(self, logger) {
  let LabelIdx(val) = self
  logger.write_string("(Label ")
  Show::output(val, logger)
  logger.write_char(')')
}

///|
pub impl Show for LaneIdx with fn output(self, logger) {
  let LaneIdx(val) = self
  logger.write_string("(Lane ")
  Show::output(val, logger)
  logger.write_char(')')
}

///|
pub impl Show for CompType with fn output(self, logger) {
  match self {
    StructCompType(st) => {
      logger.write_string("(Struct ")
      for f in st {
        Show::output(f, logger)
        logger.write_char(' ')
      }
      logger.write_char(')')
    }
    ArrayCompType(at) => {
      logger.write_string("(Array ")
      Show::output(at, logger)
      logger.write_char(')')
    }
    FuncCompType(p, r) => {
      logger.write_string("(Func (Props ")
      match p {
        [] => logger.write_string("(Void)")
        _ =>
          for pm in p {
            Show::output(pm, logger)
            logger.write_char(' ')
          }
      }
      logger.write_string(") (Ret ")
      match r {
        [] => logger.write_string("(Void)")
        _ =>
          for pm in r {
            Show::output(pm, logger)
            logger.write_char(' ')
          }
      }
      logger.write_char(')')
    }
  }
}

///|
pub impl Show for SubType with fn output(self, logger) {
  match self {
    SubType(f, sts, meta, ct) => {
      logger.write_string("(Sub ")
      if f {
        logger.write_string("Final ")
      }
      match meta.describes {
        Some(t) => {
          logger.write_string("(describes ")
          Show::output(t, logger)
          logger.write_string(") ")
        }
        None => ()
      }
      match meta.descriptor {
        Some(t) => {
          logger.write_string("(descriptor ")
          Show::output(t, logger)
          logger.write_string(") ")
        }
        None => ()
      }
      for st in sts {
        Show::output(st, logger)
        logger.write_char(' ')
      }
      Show::output(ct, logger)
      logger.write_char(')')
    }
    CompTypeSubType(meta, ct) => {
      logger.write_string("(Sub Final ")
      match meta.describes {
        Some(t) => {
          logger.write_string("(describes ")
          Show::output(t, logger)
          logger.write_string(") ")
        }
        None => ()
      }
      match meta.descriptor {
        Some(t) => {
          logger.write_string("(descriptor ")
          Show::output(t, logger)
          logger.write_string(") ")
        }
        None => ()
      }
      Show::output(ct, logger)
      logger.write_char(')')
    }
  }
}

///|
pub impl Show for RecType with fn output(self, logger) {
  match self {
    SingleRecType(st) => {
      logger.write_string("(Rec ")
      Show::output(st, logger)
      logger.write_char(')')
    }
    GroupRecType(sts) => {
      logger.write_string("(Rec ")
      for st in sts {
        Show::output(st, logger)
        logger.write_char(' ')
      }
      logger.write_char(')')
    }
  }
}

///|
pub impl Show for Limits with fn output(self, logger) {
  match self {
    I32Limits(min, max) => {
      logger.write_string("(Lim I32 ")
      Show::output(min, logger)
      if max is Some(max) {
        logger.write_char(' ')
        Show::output(max, logger)
      }
      logger.write_char(')')
    }
    I64Limits(min, max) => {
      logger.write_string("(Lim I64 ")
      Show::output(min, logger)
      if max is Some(max) {
        logger.write_char(' ')
        Show::output(max, logger)
      }
      logger.write_char(')')
    }
  }
}

///|
pub impl Show for TagType with fn output(self, logger) {
  let TagType(t) = self
  Show::output(t, logger)
}

///|
pub impl Show for GlobalType with fn output(self, logger) {
  let GlobalType(vt, m) = self
  logger.write_string("(GlobalType ")
  if m {
    logger.write_string("Mut ")
  }
  Show::output(vt, logger)
  logger.write_char(')')
}

///|
pub impl Show for MemType with fn output(self, logger) {
  let MemType(l, shared) = self
  if shared {
    logger.write_string("(MemType Shared ")
    Show::output(l, logger)
    logger.write_char(')')
    return
  }
  Show::output(l, logger)
}

///|
pub impl Show for TableType with fn output(self, logger) {
  let TableType(rt, l) = self
  logger.write_string("(TableType ")
  Show::output(rt, logger)
  logger.write_char(' ')
  Show::output(l, logger)
  logger.write_char(')')
}

///|
pub impl Show for ExternType with fn output(self, logger) {
  match self {
    GlobalExternType(gt) => Show::output(gt, logger)
    MemExternType(mt) => Show::output(mt, logger)
    TableExternType(tt) => Show::output(tt, logger)
    FuncExternType(t) => Show::output(t, logger)
    TagExternType(t) => Show::output(t, logger)
  }
}

///|
pub impl Show for ExternIdx with fn output(self, logger) {
  match self {
    GlobalExternIdx(g) => Show::output(g, logger)
    MemExternIdx(m) => Show::output(m, logger)
    TableExternIdx(t) => Show::output(t, logger)
    FuncExternIdx(f) => Show::output(f, logger)
    TagExternIdx(t) => Show::output(t, logger)
  }
}

///|
pub impl Show for ElemMode with fn output(self, logger) {
  match self {
    Active(t, e) => {
      logger.write_string("(Active ")
      Show::output(t, logger)
      logger.write_char(' ')
      Show::output(e, logger)
      logger.write_char(')')
    }
    Passive => logger.write_string("Passive")
    Declarative => logger.write_string("Declarative")
  }
}

///|
pub impl Show for ElemKind with fn output(self, logger) {
  match self {
    FuncExprsElemKind(exprs) => {
      logger.write_string("(Funcs ")
      for expr in exprs {
        Show::output(expr, logger)
        logger.write_char(' ')
      }
      logger.write_char(')')
    }
    FuncsElemKind(idxs) => {
      logger.write_string("(Funcs Indexes ")
      for idx in idxs {
        Show::output(idx, logger)
        logger.write_char(' ')
      }
      logger.write_char(')')
    }
    TypedExprsElemKind(rt, exprs) => {
      logger.write_string("(Exprs ")
      Show::output(rt, logger)
      logger.write_char(' ')
      for expr in exprs {
        Show::output(expr, logger)
      }
      logger.write_char(')')
    }
  }
}

///|
pub impl Show for Elem with fn output(self, logger) {
  let Elem(m, k) = self
  logger.write_string("(Elem ")
  Show::output(m, logger)
  logger.write_char(' ')
  Show::output(k, logger)
  logger.write_char(')')
}

///|
pub impl Show for Expr with fn output(self, logger) {
  let Expr(insts) = self
  for inst in insts {
    Show::output(inst, logger)
  }
  logger.write_string("(end)")
}

///|
pub impl Show for Import with fn output(self, logger) {
  let Import(ns, n, et) = self
  logger.write_char('(')
  Show::output(ns, logger)
  logger.write_char(' ')
  Show::output(n, logger)
  logger.write_char(' ')
  Show::output(et, logger)
  logger.write_char(')')
}

///|
pub impl Show for Table with fn output(self, logger) {
  let Table(tt, e) = self
  logger.write_string("(Table ")
  Show::output(tt, logger)
  if e is Some(e) {
    logger.write_char(' ')
    Show::output(e, logger)
  }
  logger.write_char(')')
}

///|
pub impl Show for Global with fn output(self, logger) {
  let Global(gt, e) = self
  logger.write_string("(Global ")
  Show::output(gt, logger)
  logger.write_char(' ')
  Show::output(e, logger)
  logger.write_char(')')
}

///|
pub impl Show for Export with fn output(self, logger) {
  let Export(n, idx) = self
  logger.write_string("(Export ")
  Show::output(n, logger)
  logger.write_char(' ')
  Show::output(idx, logger)
  logger.write_char(')')
}

///|
pub impl Show for Locals with fn output(self, logger) {
  for run in self.runs() {
    let mut remaining = run.count
    while remaining > 0 {
      Show::output(run.vt, logger)
      logger.write_char(' ')
      remaining = remaining - 1
    }
  }
}

///|
pub impl Show for LocalRun with fn output(self, logger) {
  logger.write_string("(LocalRun ")
  logger.write_string(self.count.to_string())
  logger.write_char(' ')
  Show::output(self.vt, logger)
  logger.write_char(')')
}

///|
pub impl Show for Func with fn output(self, logger) {
  match self {
    Func(ls, expr) => {
      logger.write_string("(Func ")
      Show::output(ls, logger)
      logger.write_char(' ')
      Show::output(expr, logger)
      logger.write_char(')')
    }
  }
}

///|
pub impl Show for DataMode with fn output(self, logger) {
  match self {
    Active(m, e) => {
      logger.write_string("(Active ")
      Show::output(m, logger)
      logger.write_char(' ')
      Show::output(e, logger)
      logger.write_char(')')
    }
    Passive => logger.write_string("Passive")
  }
}

///|
pub impl Show for Data with fn output(self, logger) {
  let Data(dm, b) = self
  logger.write_string("(Data ")
  Show::output(dm, logger)
  logger.write_char(' ')
  Show::output(b, logger)
  logger.write_char(')')
}

///|
pub impl Show for Name with fn output(self, logger) {
  let Name(sv) = self
  logger.write_char('"')
  sv.to_owned().output(logger)
  logger.write_char('"')
}

///|
pub impl Show for NameAssoc with fn output(self, logger) {
  let NameAssoc(idx, name) = self
  logger.write_string("(NameAssoc ")
  Show::output(idx, logger)
  logger.write_char(' ')
  Show::output(name, logger)
  logger.write_char(')')
}

///|
pub impl Show for NameMap with fn output(self, logger) {
  let NameMap(entries) = self
  logger.write_string("[NameMap")
  if entries.length() == 0 {
    logger.write_char(']')
    return
  }
  logger.write_string(": ")
  Show::output(entries, logger)
  logger.write_char(']')
}

///|
pub impl Show for IndirectNameAssoc with fn output(self, logger) {
  let IndirectNameAssoc(idx, names) = self
  logger.write_string("(IndirectNameAssoc ")
  Show::output(idx, logger)
  logger.write_char(' ')
  Show::output(names, logger)
  logger.write_char(')')
}

///|
pub impl Show for IndirectNameMap with fn output(self, logger) {
  let IndirectNameMap(entries) = self
  logger.write_string("[IndirectNameMap")
  if entries.length() == 0 {
    logger.write_char(']')
    return
  }
  logger.write_string(": ")
  Show::output(entries, logger)
  logger.write_char(']')
}

///|
pub impl Show for NameSec with fn output(self, logger) {
  let {
    module_name,
    func_names,
    local_names,
    label_names,
    type_names,
    table_names,
    memory_names,
    global_names,
    elem_names,
    data_names,
    field_names,
    tag_names,
  } = self
  logger.write_string("NameSec(module_name=")
  logger.write_string(@debug.to_string(module_name))
  logger.write_string(" func_names=")
  logger.write_string(@debug.to_string(func_names))
  logger.write_string(" local_names=")
  logger.write_string(@debug.to_string(local_names))
  logger.write_string(" label_names=")
  logger.write_string(@debug.to_string(label_names))
  logger.write_string(" type_names=")
  logger.write_string(@debug.to_string(type_names))
  logger.write_string(" table_names=")
  logger.write_string(@debug.to_string(table_names))
  logger.write_string(" memory_names=")
  logger.write_string(@debug.to_string(memory_names))
  logger.write_string(" global_names=")
  logger.write_string(@debug.to_string(global_names))
  logger.write_string(" elem_names=")
  logger.write_string(@debug.to_string(elem_names))
  logger.write_string(" data_names=")
  logger.write_string(@debug.to_string(data_names))
  logger.write_string(" field_names=")
  logger.write_string(@debug.to_string(field_names))
  logger.write_string(" tag_names=")
  logger.write_string(@debug.to_string(tag_names))
  logger.write_char(')')
}

///|
pub impl Show for BlockType with fn output(self, logger) {
  match self {
    ValTypeBlockType(vt) => Show::output(vt, logger)
    VoidBlockType => logger.write_string("(Void)")
    TypeIdxBlockType(t) => Show::output(t, logger)
  }
}

///|
pub impl Show for Catch with fn output(self, logger) {
  match self {
    CatchAll(l) => {
      logger.write_string("(catch_all ")
      Show::output(l, logger)
      logger.write_char(')')
    }
    CatchRef(t, l) => {
      logger.write_string("(catch_ref ")
      Show::output(t, logger)
      logger.write_char(' ')
      Show::output(l, logger)
      logger.write_char(')')
    }
    Catch(t, l) => {
      logger.write_string("(catch ")
      Show::output(t, logger)
      logger.write_char(' ')
      Show::output(l, logger)
      logger.write_char(')')
    }
    CatchAllRef(l) => {
      logger.write_string("(catch_all_ref ")
      Show::output(l, logger)
      logger.write_char(')')
    }
  }
}

///|
pub impl Show for MemArg with fn output(self, logger) {
  let MemArg(a, m, o) = self
  logger.write_string("align=")
  Show::output(a, logger)
  if m is Some(m) {
    logger.write_string(" mem=")
    Show::output(m, logger)
  }
  logger.write_string(" offset=")
  Show::output(o, logger)
}

///|
pub impl Show for AtomicOrder with fn output(self, logger) {
  match self {
    SeqCst => logger.write_string("seq_cst")
    AcqRel => logger.write_string("acq_rel")
  }
}

///|
pub impl Show for Instruction with fn output(self, logger) {
  match self {
    Unreachable => logger.write_string("unreachable")
    Nop => logger.write_string("nop")
    Block(bt, expr) => {
      logger.write_string("(block ")
      Show::output(bt, logger)
      logger.write_char(' ')
      Show::output(expr, logger)
      logger.write_char(')')
    }
    Loop(bt, expr) => {
      logger.write_string("(loop ")
      Show::output(bt, logger)
      logger.write_char(' ')
      Show::output(expr, logger)
      logger.write_char(')')
    }
    If(bt, i, e) => {
      logger.write_string("(if ")
      Show::output(bt, logger)
      logger.write_char(' ')
      for n in i {
        Show::output(n, logger)
        logger.write_char(' ')
      }
      if e is Some(e) {
        logger.write_string("else ")
        for n in e {
          Show::output(n, logger)
          logger.write_char(' ')
        }
        logger.write_char(')')
      }
    }
    Throw(t) => {
      logger.write_string("(throw ")
      Show::output(t, logger)
      logger.write_char(')')
    }
    ThrowRef => logger.write_string("throw_ref")
    Br(l) => {
      logger.write_string("(br ")
      Show::output(l, logger)
      logger.write_char(')')
    }
    BrIf(l) => {
      logger.write_string("(br_if ")
      Show::output(l, logger)
      logger.write_char(')')
    }
    BrTable(ls, l) => {
      logger.write_string("(br_table ")
      for n in ls {
        Show::output(n, logger)
        logger.write_char(' ')
      }
      Show::output(l, logger)
      logger.write_char(')')
    }
    Return => logger.write_string("return")
    Call(f) => {
      logger.write_string("(call ")
      Show::output(f, logger)
      logger.write_char(')')
    }
    CallIndirect(ty, tbl) => {
      logger.write_string("(call_indirect ")
      Show::output(ty, logger)
      logger.write_char(' ')
      Show::output(tbl, logger)
      logger.write_char(')')
    }
    ReturnCall(f) => {
      logger.write_string("(return_call ")
      Show::output(f, logger)
      logger.write_char(')')
    }
    ReturnCallIndirect(ty, tbl) => {
      logger.write_string("(return_call_indirect ")
      Show::output(ty, logger)
      logger.write_char(' ')
      Show::output(tbl, logger)
      logger.write_char(')')
    }
    CallRef(t) => {
      logger.write_string("(call_ref ")
      Show::output(t, logger)
      logger.write_char(')')
    }
    ReturnCallRef(t) => {
      logger.write_string("(return_call_ref ")
      Show::output(t, logger)
      logger.write_char(')')
    }
    Drop => logger.write_string("drop")
    Select(None) => logger.write_string("select")
    Select(Some(vts)) => {
      logger.write_string("(select")
      for vt in vts {
        logger.write_char(' ')
        Show::output(vt, logger)
      }
      logger.write_char(')')
    }
    Pop(vt) => {
      logger.write_string("(pop ")
      Show::output(vt, logger)
      logger.write_char(')')
    }
    Try(bt, body, catches, delegate_target) => {
      logger.write_string("(try ")
      Show::output(bt, logger)
      logger.write_char(' ')
      Show::output(body, logger)
      for catch_ in catches {
        logger.write_char(' ')
        match catch_ {
          LegacyCatch(tag, catch_body) => {
            logger.write_string("(catch ")
            Show::output(tag, logger)
            logger.write_char(' ')
            Show::output(catch_body, logger)
            logger.write_char(')')
          }
          LegacyCatchAll(catch_body) => {
            logger.write_string("(catch_all ")
            Show::output(catch_body, logger)
            logger.write_char(')')
          }
        }
      }
      if delegate_target is Some(target) {
        logger.write_string(" (delegate ")
        Show::output(target, logger)
        logger.write_char(')')
      }
      logger.write_char(')')
    }
    TryTable(bt, c, e) => {
      logger.write_string("(try_table ")
      Show::output(bt, logger)
      logger.write_char(' ')
      Show::output(c, logger)
      logger.write_char(' ')
      Show::output(e, logger)
      logger.write_char(')')
    }
    LocalGet(l) => {
      logger.write_string("(local.get ")
      Show::output(l, logger)
      logger.write_char(')')
    }
    LocalSet(l) => {
      logger.write_string("(local.set ")
      Show::output(l, logger)
      logger.write_char(')')
    }
    LocalTee(l) => {
      logger.write_string("(local.tee ")
      Show::output(l, logger)
      logger.write_char(')')
    }
    GlobalGet(g) => {
      logger.write_string("(global.get ")
      Show::output(g, logger)
      logger.write_char(')')
    }
    GlobalSet(g) => {
      logger.write_string("(global.set ")
      Show::output(g, logger)
      logger.write_char(')')
    }
    TableGet(t) => {
      logger.write_string("(table.get ")
      Show::output(t, logger)
      logger.write_char(')')
    }
    TableSet(t) => {
      logger.write_string("(table.set ")
      Show::output(t, logger)
      logger.write_char(')')
    }
    I32Load(m) => {
      logger.write_string("(i32.load ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I64Load(m) => {
      logger.write_string("(i64.load ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    F32Load(m) => {
      logger.write_string("(f32.load ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    F64Load(m) => {
      logger.write_string("(f64.load ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I32Load8S(m) => {
      logger.write_string("(i32.load8s ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I32Load8U(m) => {
      logger.write_string("(i32.load8u ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I32Load16S(m) => {
      logger.write_string("(i32.load16s ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I32Load16U(m) => {
      logger.write_string("(i32.load16u ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I64Load8S(m) => {
      logger.write_string("(i64.load8s ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I64Load8U(m) => {
      logger.write_string("(i64.load8u ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I64Load16S(m) => {
      logger.write_string("(i64.load16s ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I64Load16U(m) => {
      logger.write_string("(i64.load16u ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I64Load32S(m) => {
      logger.write_string("(i64.load32s ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I64Load32U(m) => {
      logger.write_string("(i64.load32u ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I32Store(m) => {
      logger.write_string("(i32.store ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I64Store(m) => {
      logger.write_string("(i64.store ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    F32Store(m) => {
      logger.write_string("(f32.store ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    F64Store(m) => {
      logger.write_string("(f64.store ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I32Store8(m) => {
      logger.write_string("(i32.store8 ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I32Store16(m) => {
      logger.write_string("(i32.store16 ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I64Store8(m) => {
      logger.write_string("(i64.store8 ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I64Store16(m) => {
      logger.write_string("(i64.store16 ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I64Store32(m) => {
      logger.write_string("(i64.store32 ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    MemorySize(m) => {
      logger.write_string("(memory.size ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    MemoryGrow(m) => {
      logger.write_string("(memory.grow ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    MemoryAtomicNotify(m) => {
      logger.write_string("(memory.atomic.notify ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    MemoryAtomicWait32(m) => {
      logger.write_string("(memory.atomic.wait32 ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    MemoryAtomicWait64(m) => {
      logger.write_string("(memory.atomic.wait64 ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    AtomicFence => logger.write_string("atomic.fence")
    I32AtomicLoad(m) => {
      logger.write_string("(i32.atomic.load ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I64AtomicLoad(m) => {
      logger.write_string("(i64.atomic.load ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I32AtomicLoad8U(m) => {
      logger.write_string("(i32.atomic.load8_u ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I32AtomicLoad16U(m) => {
      logger.write_string("(i32.atomic.load16_u ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I64AtomicLoad8U(m) => {
      logger.write_string("(i64.atomic.load8_u ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I64AtomicLoad16U(m) => {
      logger.write_string("(i64.atomic.load16_u ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I64AtomicLoad32U(m) => {
      logger.write_string("(i64.atomic.load32_u ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I32AtomicStore(m) => {
      logger.write_string("(i32.atomic.store ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I64AtomicStore(m) => {
      logger.write_string("(i64.atomic.store ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I32AtomicStore8(m) => {
      logger.write_string("(i32.atomic.store8 ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I32AtomicStore16(m) => {
      logger.write_string("(i32.atomic.store16 ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I64AtomicStore8(m) => {
      logger.write_string("(i64.atomic.store8 ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I64AtomicStore16(m) => {
      logger.write_string("(i64.atomic.store16 ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    I64AtomicStore32(m) => {
      logger.write_string("(i64.atomic.store32 ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    AtomicRmw(op, m) => {
      logger.write_string("(atomic.rmw ")
      Show::output(op, logger)
      logger.write_char(' ')
      Show::output(m, logger)
      logger.write_char(')')
    }
    AtomicCmpxchg(op, m) => {
      logger.write_string("(atomic.cmpxchg ")
      Show::output(op, logger)
      logger.write_char(' ')
      Show::output(m, logger)
      logger.write_char(')')
    }
    I32Const(c) => {
      logger.write_string("(i32.const ")
      Show::output(c, logger)
      logger.write_char(')')
    }
    I64Const(c) => {
      logger.write_string("(i64.const ")
      Show::output(c, logger)
      logger.write_char(')')
    }
    F32Const(c) => {
      logger.write_string("(f32.const ")
      Show::output(c, logger)
      logger.write_char(')')
    }
    F64Const(c) => {
      logger.write_string("(f64.const ")
      Show::output(c, logger)
      logger.write_char(')')
    }
    I32Eqz => logger.write_string("i32.eqz")
    I32Eq => logger.write_string("i32.eq")
    I32Ne => logger.write_string("i32.ne")
    I32LtS => logger.write_string("i32.lt_s")
    I32LtU => logger.write_string("i32.lt_u")
    I32GtS => logger.write_string("i32.gt_s")
    I32GtU => logger.write_string("i32.gt_u")
    I32LeS => logger.write_string("i32.le_s")
    I32LeU => logger.write_string("i32.le_u")
    I32GeS => logger.write_string("i32.ge_s")
    I32GeU => logger.write_string("i32.ge_u")
    I64Eqz => logger.write_string("i64.eqz")
    I64Eq => logger.write_string("i64.eq")
    I64Ne => logger.write_string("i64.ne")
    I64LtS => logger.write_string("i64.lt_s")
    I64LtU => logger.write_string("i64.lt_u")
    I64GtS => logger.write_string("i64.gt_s")
    I64GtU => logger.write_string("i64.gt_u")
    I64LeS => logger.write_string("i64.le_s")
    I64LeU => logger.write_string("i64.le_u")
    I64GeS => logger.write_string("i64.ge_s")
    I64GeU => logger.write_string("i64.ge_u")
    F32Eq => logger.write_string("f32.eq")
    F32Ne => logger.write_string("f32.ne")
    F32Lt => logger.write_string("f32.lt")
    F32Gt => logger.write_string("f32.gt")
    F32Le => logger.write_string("f32.le")
    F32Ge => logger.write_string("f32.ge")
    F64Eq => logger.write_string("f64.eq")
    F64Ne => logger.write_string("f64.ne")
    F64Lt => logger.write_string("f64.lt")
    F64Gt => logger.write_string("f64.gt")
    F64Le => logger.write_string("f64.le")
    F64Ge => logger.write_string("f64.ge")
    I32Clz => logger.write_string("i32.clz")
    I32Ctz => logger.write_string("i32.ctz")
    I32Popcnt => logger.write_string("i32.popcnt")
    I32Add => logger.write_string("i32.add")
    I32Sub => logger.write_string("i32.sub")
    I32Mul => logger.write_string("i32.mul")
    I32DivS => logger.write_string("i32.div_s")
    I32DivU => logger.write_string("i32.div_u")
    I32RemS => logger.write_string("i32.rem_s")
    I32RemU => logger.write_string("i32.rem_u")
    I32And => logger.write_string("i32.and")
    I32Or => logger.write_string("i32.or")
    I32Xor => logger.write_string("i32.xor")
    I32Shl => logger.write_string("i32.shl")
    I32ShrS => logger.write_string("i32.shr_s")
    I32ShrU => logger.write_string("i32.shr_u")
    I32Rotl => logger.write_string("i32.rotl")
    I32Rotr => logger.write_string("i32.rotr")
    I64Clz => logger.write_string("i64.clz")
    I64Ctz => logger.write_string("i64.ctz")
    I64Popcnt => logger.write_string("i64.popcnt")
    I64Add => logger.write_string("i64.add")
    I64Sub => logger.write_string("i64.sub")
    I64Mul => logger.write_string("i64.mul")
    I64DivS => logger.write_string("i64.div_s")
    I64DivU => logger.write_string("i64.div_u")
    I64RemS => logger.write_string("i64.rem_s")
    I64RemU => logger.write_string("i64.rem_u")
    I64And => logger.write_string("i64.and")
    I64Or => logger.write_string("i64.or")
    I64Xor => logger.write_string("i64.xor")
    I64Shl => logger.write_string("i64.shl")
    I64ShrS => logger.write_string("i64.shr_s")
    I64ShrU => logger.write_string("i64.shr_u")
    I64Rotl => logger.write_string("i64.rotl")
    I64Rotr => logger.write_string("i64.rotr")
    F32Abs => logger.write_string("f32.abs")
    F32Neg => logger.write_string("f32.neg")
    F32Ceil => logger.write_string("f32.ceil")
    F32Floor => logger.write_string("f32.floor")
    F32Trunc => logger.write_string("f32.trunc")
    F32Nearest => logger.write_string("f32.nearest")
    F32Sqrt => logger.write_string("f32.sqrt")
    F32Add => logger.write_string("f32.add")
    F32Sub => logger.write_string("f32.sub")
    F32Mul => logger.write_string("f32.mul")
    F32Div => logger.write_string("f32.div")
    F32Min => logger.write_string("f32.min")
    F32Max => logger.write_string("f32.max")
    F32Copysign => logger.write_string("f32.copysign")
    F64Abs => logger.write_string("f64.abs")
    F64Neg => logger.write_string("f64.neg")
    F64Ceil => logger.write_string("f64.ceil")
    F64Floor => logger.write_string("f64.floor")
    F64Trunc => logger.write_string("f64.trunc")
    F64Nearest => logger.write_string("f64.nearest")
    F64Sqrt => logger.write_string("f64.sqrt")
    F64Add => logger.write_string("f64.add")
    F64Sub => logger.write_string("f64.sub")
    F64Mul => logger.write_string("f64.mul")
    F64Div => logger.write_string("f64.div")
    F64Min => logger.write_string("f64.min")
    F64Max => logger.write_string("f64.max")
    F64Copysign => logger.write_string("f64.copysign")
    I32WrapI64 => logger.write_string("i32.wrap_i64")
    I32TruncF32S => logger.write_string("i32.trunc_f32s")
    I32TruncF32U => logger.write_string("i32.trunc_f32u")
    I32TruncF64S => logger.write_string("i32.trunc_f64s")
    I32TruncF64U => logger.write_string("i32.trunc_f64u")
    I64ExtendI32S => logger.write_string("i64.extend_i32s")
    I64ExtendI32U => logger.write_string("i64.extend_i32u")
    I64TruncF32S => logger.write_string("i64.trunc_f32s")
    I64TruncF32U => logger.write_string("i64.trunc_f32u")
    I64TruncF64S => logger.write_string("i64.trunc_f64s")
    I64TruncF64U => logger.write_string("i64.trunc_f64u")
    F32ConvertI32S => logger.write_string("f32.convert_i32s")
    F32ConvertI32U => logger.write_string("f32.convert_i32u")
    F32ConvertI64S => logger.write_string("f32.convert_i64s")
    F32ConvertI64U => logger.write_string("f32.convert_i64u")
    F32DemoteF64 => logger.write_string("f32.demote_f64")
    F64ConvertI32S => logger.write_string("f64.convert_i32s")
    F64ConvertI32U => logger.write_string("f64.convert_i32u")
    F64ConvertI64S => logger.write_string("f64.convert_i64s")
    F64ConvertI64U => logger.write_string("f64.convert_i64u")
    F64PromoteF32 => logger.write_string("f64.promote_f32")
    I32ReinterpretF32 => logger.write_string("i32.reinterpret_f32")
    I64ReinterpretF64 => logger.write_string("i64.reinterpret_f64")
    F32ReinterpretI32 => logger.write_string("f32.reinterpret_i32")
    F64ReinterpretI64 => logger.write_string("f64.reinterpret_i64")
    I32Extend8S => logger.write_string("i32.extend8s")
    I32Extend16S => logger.write_string("i32.extend16s")
    I64Extend8S => logger.write_string("i64.extend8s")
    I64Extend16S => logger.write_string("i64.extend16s")
    I64Extend32S => logger.write_string("i64.extend32s")
    RefNull(rt) => {
      logger.write_string("(ref.null ")
      Show::output(rt, logger)
      logger.write_char(')')
    }
    RefIsNull => logger.write_string("ref.null")
    RefFunc(i) => {
      logger.write_string("(ref.func ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    RefEq => logger.write_string("ref.eq")
    RefAsNonNull => logger.write_string("ref.as_non_null")
    BrOnNull(l) => {
      logger.write_string("(br_on_null ")
      Show::output(l, logger)
      logger.write_char(')')
    }
    BrOnNonNull(l) => {
      logger.write_string("(br_on_non_null ")
      Show::output(l, logger)
      logger.write_char(')')
    }
    StructNew(i) => {
      logger.write_string("(struct.new ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    StructNewDefault(i) => {
      logger.write_string("(struct.new_default ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    StructNewDesc(i) => {
      logger.write_string("(struct.new_desc ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    StructNewDefaultDesc(i) => {
      logger.write_string("(struct.new_default_desc ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    StructGet(t, i) => {
      logger.write_string("(struct.get ")
      Show::output(t, logger)
      logger.write_char(' ')
      Show::output(i, logger)
      logger.write_char(')')
    }
    StructGetS(t, i) => {
      logger.write_string("(struct.get_s ")
      Show::output(t, logger)
      logger.write_char(' ')
      Show::output(i, logger)
      logger.write_char(')')
    }
    StructGetU(t, i) => {
      logger.write_string("(struct.get_u ")
      Show::output(t, logger)
      logger.write_char(' ')
      Show::output(i, logger)
      logger.write_char(')')
    }
    StructAtomicGet(order, t, i) => {
      logger.write_string("(struct.atomic.get ")
      Show::output(order, logger)
      logger.write_char(' ')
      Show::output(t, logger)
      logger.write_char(' ')
      Show::output(i, logger)
      logger.write_char(')')
    }
    StructAtomicGetS(order, t, i) => {
      logger.write_string("(struct.atomic.get_s ")
      Show::output(order, logger)
      logger.write_char(' ')
      Show::output(t, logger)
      logger.write_char(' ')
      Show::output(i, logger)
      logger.write_char(')')
    }
    StructAtomicGetU(order, t, i) => {
      logger.write_string("(struct.atomic.get_u ")
      Show::output(order, logger)
      logger.write_char(' ')
      Show::output(t, logger)
      logger.write_char(' ')
      Show::output(i, logger)
      logger.write_char(')')
    }
    StructSet(t, i) => {
      logger.write_string("(struct.set ")
      Show::output(t, logger)
      logger.write_char(' ')
      Show::output(i, logger)
      logger.write_char(')')
    }
    ArrayNew(i) => {
      logger.write_string("(array.new ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    ArrayNewDefault(i) => {
      logger.write_string("(array.new_default ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    ArrayNewFixed(i, n) => {
      logger.write_string("(array.new_fixed ")
      Show::output(i, logger)
      logger.write_char(' ')
      Show::output(n, logger)
      logger.write_char(')')
    }
    ArrayNewData(i, n) => {
      logger.write_string("(array.new_data ")
      Show::output(i, logger)
      logger.write_char(' ')
      Show::output(n, logger)
      logger.write_char(')')
    }
    ArrayNewElem(i, n) => {
      logger.write_string("(array.new_elem ")
      Show::output(i, logger)
      logger.write_char(' ')
      Show::output(n, logger)
      logger.write_char(')')
    }
    StringConst(bytes) => {
      logger.write_string("(string.const ")
      Show::output(bytes, logger)
      logger.write_char(')')
    }
    StringNewUtf8Array => logger.write_string("string.new_utf8_array")
    StringNewWtf16Array => logger.write_string("string.new_wtf16_array")
    StringEncodeUtf8Array => logger.write_string("string.encode_utf8_array")
    StringEncodeWtf16Array => logger.write_string("string.encode_wtf16_array")
    StringNewLossyUtf8Array =>
      logger.write_string("string.new_lossy_utf8_array")
    StringNewWtf8Array => logger.write_string("string.new_wtf8_array")
    StringEncodeLossyUtf8Array =>
      logger.write_string("string.encode_lossy_utf8_array")
    StringEncodeWtf8Array => logger.write_string("string.encode_wtf8_array")
    ArrayGet(i) => {
      logger.write_string("(array.get ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    ArrayGetS(i) => {
      logger.write_string("(array.get_s ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    ArrayGetU(i) => {
      logger.write_string("(array.get_u ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    ArraySet(i) => {
      logger.write_string("(array.set ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    ArrayLen => logger.write_string("array.len")
    ArrayFill(i) => {
      logger.write_string("(array.fill ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    ArrayCopy(i, n) => {
      logger.write_string("(array.copy ")
      Show::output(i, logger)
      logger.write_char(' ')
      Show::output(n, logger)
      logger.write_char(')')
    }
    ArrayInitData(i, n) => {
      logger.write_string("(array.init_data ")
      Show::output(i, logger)
      logger.write_char(' ')
      Show::output(n, logger)
      logger.write_char(')')
    }
    ArrayInitElem(i, n) => {
      logger.write_string("(array.init_elem ")
      Show::output(i, logger)
      logger.write_char(' ')
      Show::output(n, logger)
      logger.write_char(')')
    }
    RefGetDesc(ti) => {
      logger.write_string("(ref.get_desc ")
      Show::output(ti, logger)
      logger.write_char(')')
    }
    RefTest(n, ht) => {
      logger.write_string("(ref.test ")
      HeapTypeRefType(n, false, ht).output(logger)
      logger.write_char(')')
    }
    RefCast(n, ht) => {
      logger.write_string("(ref.cast ")
      HeapTypeRefType(n, false, ht).output(logger)
      logger.write_char(')')
    }
    RefTestDesc(n, ht) => {
      logger.write_string("(ref.test_desc ")
      HeapTypeRefType(n, false, ht).output(logger)
      logger.write_char(')')
    }
    RefCastDescEq(n, ht) => {
      logger.write_string("(ref.cast_desc_eq ")
      HeapTypeRefType(n, false, ht).output(logger)
      logger.write_char(')')
    }
    BrOnCast(i, CastOp(l, r), lht, rht) => {
      logger.write_string("(br_on_cast ")
      Show::output(i, logger)
      logger.write_char(' ')
      HeapTypeRefType(l, false, lht).output(logger)
      logger.write_char(' ')
      HeapTypeRefType(r, false, rht).output(logger)
      logger.write_char(')')
    }
    BrOnCastFail(i, CastOp(l, r), lht, rht) => {
      logger.write_string("(br_on_cast_fail ")
      Show::output(i, logger)
      logger.write_char(' ')
      HeapTypeRefType(l, false, lht).output(logger)
      logger.write_char(' ')
      HeapTypeRefType(r, false, rht).output(logger)
      logger.write_char(')')
    }
    AnyConvertExtern => logger.write_string("any.convert_extern")
    ExternConvertAny => logger.write_string("extern.convert_any")
    RefI31 => logger.write_string("ref.i31")
    I31GetS => logger.write_string("i31.get_s")
    I31GetU => logger.write_string("i31.get_u")
    I32TruncSatF32S => logger.write_string("i32.trunc_sat_f32s")
    I32TruncSatF32U => logger.write_string("i32.trunc_sat_f32u")
    I32TruncSatF64S => logger.write_string("i32.trunc_sat_f64s")
    I32TruncSatF64U => logger.write_string("i32.trunc_sat_f64u")
    I64TruncSatF32S => logger.write_string("i64.trunc_sat_f32s")
    I64TruncSatF32U => logger.write_string("i64.trunc_sat_f32u")
    I64TruncSatF64S => logger.write_string("i64.trunc_sat_f64s")
    I64TruncSatF64U => logger.write_string("i64.trunc_sat_f64u")
    MemoryInit(i, m) => {
      logger.write_string("(memory.init ")
      Show::output(i, logger)
      logger.write_char(' ')
      Show::output(m, logger)
      logger.write_char(')')
    }
    DataDrop(i) => {
      logger.write_string("(data.drop ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    MemoryCopy(i0, i1) => {
      logger.write_string("(memory.copy ")
      Show::output(i0, logger)
      logger.write_char(' ')
      Show::output(i1, logger)
      logger.write_char(')')
    }
    MemoryFill(i) => {
      logger.write_string("(memory.fill ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    TableInit(i0, i1) => {
      logger.write_string("(table.init ")
      Show::output(i0, logger)
      logger.write_char(' ')
      Show::output(i1, logger)
      logger.write_char(')')
    }
    ElemDrop(i) => {
      logger.write_string("(elem.drop ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    TableCopy(i0, i1) => {
      logger.write_string("(table.copy ")
      Show::output(i0, logger)
      logger.write_char(' ')
      Show::output(i1, logger)
      logger.write_char(')')
    }
    TableGrow(i) => {
      logger.write_string("(table.grow ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    TableSize(i) => {
      logger.write_string("(table.size ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    TableFill(i) => {
      logger.write_string("(table.fill ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    V128Load(m) => {
      logger.write_string("(v128.load ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    V128Load8x8S(m) => {
      logger.write_string("(v128.load8x8s ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    V128Load8x8U(m) => {
      logger.write_string("(v128.load8x8u ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    V128Load16x4S(m) => {
      logger.write_string("(v128.load16x4s ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    V128Load16x4U(m) => {
      logger.write_string("(v128.load16x4u ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    V128Load32x2S(m) => {
      logger.write_string("(v128.load32x2s ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    V128Load32x2U(m) => {
      logger.write_string("(v128.load32x2u ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    V128Load8Splat(m) => {
      logger.write_string("(v128.load8_splat ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    V128Load16Splat(m) => {
      logger.write_string("(v128.load16_splat ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    V128Load32Splat(m) => {
      logger.write_string("(v128.load32_splat ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    V128Load64Splat(m) => {
      logger.write_string("(v128.load64_splat ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    V128Store(m) => {
      logger.write_string("(v128.store ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    V128Const(
      l0,
      l1,
      l2,
      l3,
      l4,
      l5,
      l6,
      l7,
      l8,
      l9,
      l10,
      l11,
      l12,
      l13,
      l14,
      l15
    ) => {
      logger.write_string("(v128.const ")
      l0.to_hex().pad_start(2, '0').output(logger)
      l1.to_hex().pad_start(2, '0').output(logger)
      l2.to_hex().pad_start(2, '0').output(logger)
      l3.to_hex().pad_start(2, '0').output(logger)
      l4.to_hex().pad_start(2, '0').output(logger)
      l5.to_hex().pad_start(2, '0').output(logger)
      l6.to_hex().pad_start(2, '0').output(logger)
      l7.to_hex().pad_start(2, '0').output(logger)
      l8.to_hex().pad_start(2, '0').output(logger)
      l9.to_hex().pad_start(2, '0').output(logger)
      l10.to_hex().pad_start(2, '0').output(logger)
      l11.to_hex().pad_start(2, '0').output(logger)
      l12.to_hex().pad_start(2, '0').output(logger)
      l13.to_hex().pad_start(2, '0').output(logger)
      l14.to_hex().pad_start(2, '0').output(logger)
      l15.to_hex().pad_start(2, '0').output(logger)
      logger.write_char(')')
    }
    I8x16Shuffle(
      l0,
      l1,
      l2,
      l3,
      l4,
      l5,
      l6,
      l7,
      l8,
      l9,
      l10,
      l11,
      l12,
      l13,
      l14,
      l15
    ) => {
      logger.write_string("(i8x16.shuffle ")
      Show::output(l0, logger)
      logger.write_char(' ')
      Show::output(l1, logger)
      logger.write_char(' ')
      Show::output(l2, logger)
      logger.write_char(' ')
      Show::output(l3, logger)
      logger.write_char(' ')
      Show::output(l4, logger)
      logger.write_char(' ')
      Show::output(l5, logger)
      logger.write_char(' ')
      Show::output(l6, logger)
      logger.write_char(' ')
      Show::output(l7, logger)
      logger.write_char(' ')
      Show::output(l8, logger)
      logger.write_char(' ')
      Show::output(l9, logger)
      logger.write_char(' ')
      Show::output(l10, logger)
      logger.write_char(' ')
      Show::output(l11, logger)
      logger.write_char(' ')
      Show::output(l12, logger)
      logger.write_char(' ')
      Show::output(l13, logger)
      logger.write_char(' ')
      Show::output(l14, logger)
      logger.write_char(' ')
      Show::output(l15, logger)
      logger.write_char(')')
    }
    I8x16Swizzle => logger.write_string("i8x16.swizzle")
    I8x16Splat => logger.write_string("i8x16.splat")
    I16x8Splat => logger.write_string("i16x8.splat")
    I32x4Splat => logger.write_string("i32x4.splat")
    I64x2Splat => logger.write_string("i64x2.splat")
    F32x4Splat => logger.write_string("f32x4.splat")
    F64x2Splat => logger.write_string("f64x2.splat")
    I8x16ExtractLaneS(i) => {
      logger.write_string("(i8x16.extract_lane_s ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    I8x16ExtractLaneU(i) => {
      logger.write_string("(i8x16.extract_lane_u ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    I8x16ReplaceLane(i) => {
      logger.write_string("(i8x16.replace_lane ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    I16x8ExtractLaneS(i) => {
      logger.write_string("(i16x8.extract_lane_s ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    I16x8ExtractLaneU(i) => {
      logger.write_string("(i16x8.extract_lane_u ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    I16x8ReplaceLane(i) => {
      logger.write_string("(i16x8.replace_lane ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    I32x4ExtractLane(i) => {
      logger.write_string("(i32x4.extract_lane ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    I32x4ReplaceLane(i) => {
      logger.write_string("(i32x4.replace_lane ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    I64x2ExtractLane(i) => {
      logger.write_string("(i64x2.extract_lane ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    I64x2ReplaceLane(i) => {
      logger.write_string("(i64x2.replace_lane ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    F32x4ExtractLane(i) => {
      logger.write_string("(f32x4.extract_lane ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    F32x4ReplaceLane(i) => {
      logger.write_string("(f32x4.replace_lane ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    F64x2ExtractLane(i) => {
      logger.write_string("(f64x2.extract_lane ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    F64x2ReplaceLane(i) => {
      logger.write_string("(f64x2.replace_lane ")
      Show::output(i, logger)
      logger.write_char(')')
    }
    I8x16Eq => logger.write_string("i8x16.eq")
    I8x16Ne => logger.write_string("i8x16.ne")
    I8x16LtS => logger.write_string("i8x16.lt_s")
    I8x16LtU => logger.write_string("i8x16.lt_u")
    I8x16GtS => logger.write_string("i8x16.gt_s")
    I8x16GtU => logger.write_string("i8x16.gt_u")
    I8x16LeS => logger.write_string("i8x16.le_s")
    I8x16LeU => logger.write_string("i8x16.le_u")
    I8x16GeS => logger.write_string("i8x16.ge_s")
    I8x16GeU => logger.write_string("i8x16.ge_u")
    I16x8Eq => logger.write_string("i16x8.eq")
    I16x8Ne => logger.write_string("i16x8.ne")
    I16x8LtS => logger.write_string("i16x8.lt_s")
    I16x8LtU => logger.write_string("i16x8.lt_u")
    I16x8GtS => logger.write_string("i16x8.gt_s")
    I16x8GtU => logger.write_string("i16x8.gt_u")
    I16x8LeS => logger.write_string("i16x8.le_s")
    I16x8LeU => logger.write_string("i16x8.le_u")
    I16x8GeS => logger.write_string("i16x8.ge_s")
    I16x8GeU => logger.write_string("i16x8.ge_u")
    I32x4Eq => logger.write_string("i32x4.eq")
    I32x4Ne => logger.write_string("i32x4.ne")
    I32x4LtS => logger.write_string("i32x4.lt_s")
    I32x4LtU => logger.write_string("i32x4.lt_u")
    I32x4GtS => logger.write_string("i32x4.gt_s")
    I32x4GtU => logger.write_string("i32x4.gt_u")
    I32x4LeS => logger.write_string("i32x4.le_s")
    I32x4LeU => logger.write_string("i32x4.le_u")
    I32x4GeS => logger.write_string("i32x4.ge_s")
    I32x4GeU => logger.write_string("i32x4.ge_u")
    F32x4Eq => logger.write_string("f32x4.eq")
    F32x4Ne => logger.write_string("f32x4.ne")
    F32x4Lt => logger.write_string("f32x4.lt")
    F32x4Gt => logger.write_string("f32x4.gt")
    F32x4Le => logger.write_string("f32x4.le")
    F32x4Ge => logger.write_string("f32x4.ge")
    F64x2Eq => logger.write_string("f64x2.eq")
    F64x2Ne => logger.write_string("f64x2.ne")
    F64x2Lt => logger.write_string("f64x2.lt")
    F64x2Gt => logger.write_string("f64x2.gt")
    F64x2Le => logger.write_string("f64x2.le")
    F64x2Ge => logger.write_string("f64x2.ge")
    V128Not => logger.write_string("v128.not")
    V128And => logger.write_string("v128.and")
    V128Andnot => logger.write_string("v128.andnot")
    V128Or => logger.write_string("v128.or")
    V128Xor => logger.write_string("v128.xor")
    V128Bitselect => logger.write_string("v128.bitselect")
    V128AnyTrue => logger.write_string("v128.any_true")
    V128Load8Lane(m, i) => {
      logger.write_string("(v128.load8_lane ")
      Show::output(m, logger)
      logger.write_char(' ')
      Show::output(i, logger)
      logger.write_char(')')
    }
    V128Load16Lane(m, i) => {
      logger.write_string("(v128.load16_lane ")
      Show::output(m, logger)
      logger.write_char(' ')
      Show::output(i, logger)
      logger.write_char(')')
    }
    V128Load32Lane(m, i) => {
      logger.write_string("(v128.load32_lane ")
      Show::output(m, logger)
      logger.write_char(' ')
      Show::output(i, logger)
      logger.write_char(')')
    }
    V128Load64Lane(m, i) => {
      logger.write_string("(v128.load64_lane ")
      Show::output(m, logger)
      logger.write_char(' ')
      Show::output(i, logger)
      logger.write_char(')')
    }
    V128Store8Lane(m, i) => {
      logger.write_string("(v128.store8_lane ")
      Show::output(m, logger)
      logger.write_char(' ')
      Show::output(i, logger)
      logger.write_char(')')
    }
    V128Store16Lane(m, i) => {
      logger.write_string("(v128.store16_lane ")
      Show::output(m, logger)
      logger.write_char(' ')
      Show::output(i, logger)
      logger.write_char(')')
    }
    V128Store32Lane(m, i) => {
      logger.write_string("(v128.store32_lane ")
      Show::output(m, logger)
      logger.write_char(' ')
      Show::output(i, logger)
      logger.write_char(')')
    }
    V128Store64Lane(m, i) => {
      logger.write_string("(v128.store64_lane ")
      Show::output(m, logger)
      logger.write_char(' ')
      Show::output(i, logger)
      logger.write_char(')')
    }
    V128Load32Zero(m) => {
      logger.write_string("(v128_load32_zero ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    V128Load64Zero(m) => {
      logger.write_string("(v128_load64_zero ")
      Show::output(m, logger)
      logger.write_char(')')
    }
    F32x4DemoteF64x2Zero => logger.write_string("f32x4.demote_f64x2_zero")
    F64x2PromoteLowF32x4 => logger.write_string("f64x2.promote_low_f32x4")
    I8x16Abs => logger.write_string("i8x16.abs")
    I8x16Neg => logger.write_string("i8x16.neg")
    I8x16Popcnt => logger.write_string("i8x16.popcnt")
    I8x16AllTrue => logger.write_string("i8x16.all_true")
    I8x16Bitmask => logger.write_string("i8x16.bitmask")
    I8x16NarrowI16x8S => logger.write_string("i8x16.narrow_i16x8s")
    I8x16NarrowI16x8U => logger.write_string("i8x16.narrow_i16x8u")
    F32x4Ceil => logger.write_string("f32x4.ceil")
    F32x4Floor => logger.write_string("f32x4.floor")
    F32x4Trunc => logger.write_string("f32x4.trunc")
    F32x4Nearest => logger.write_string("f32x4.nearest")
    I8x16Shl => logger.write_string("i8x16.shl")
    I8x16ShrS => logger.write_string("i8x16.shr_s")
    I8x16ShrU => logger.write_string("i8x16.shr_u")
    I8x16Add => logger.write_string("i8x16.add")
    I8x16AddSatS => logger.write_string("i8x16.add_sat_s")
    I8x16AddSatU => logger.write_string("i8x16.add_sat_u")
    I8x16Sub => logger.write_string("i8x16.sub")
    I8x16SubSatS => logger.write_string("i8x16.sub_sat_s")
    I8x16SubSatU => logger.write_string("i8x16.sub_sat_u")
    F64x2Ceil => logger.write_string("f64x2.ceil")
    F64x2Floor => logger.write_string("f64x2.floor")
    I8x16MinS => logger.write_string("i8x16.min_s")
    I8x16MinU => logger.write_string("i8x16.min_u")
    I8x16MaxS => logger.write_string("i8x16.max_s")
    I8x16MaxU => logger.write_string("i8x16.max_u")
    F64x2Trunc => logger.write_string("f64x2.trunc")
    I8x16AvgrU => logger.write_string("i8x16.avgr_u")
    I16x8ExtaddPairwiseI8x16S =>
      logger.write_string("i16x8.extadd_pairwise_i8x16s")
    I16x8ExtaddPairwiseI8x16U =>
      logger.write_string("i16x8.extadd_pairwise_i8x16u")
    I32x4ExtaddPairwiseI16x8S =>
      logger.write_string("i32x4.extadd_pairwise_i16x8s")
    I32x4ExtaddPairwiseI16x8U =>
      logger.write_string("i32x4.extadd_pairwise_i16x8u")
    I16x8Abs => logger.write_string("i16x8.abs")
    I16x8Neg => logger.write_string("i16x8.neg")
    I16x8Q15mulrSatS => logger.write_string("i16x8.15mulr_sat_s")
    I16x8AllTrue => logger.write_string("i16x8.all_true")
    I16x8Bitmask => logger.write_string("i16x8.bitmask")
    I16x8NarrowI32x4S => logger.write_string("i16x8.narrow_i32x4s")
    I16x8NarrowI32x4U => logger.write_string("i16x8.narrow_i32x4u")
    I16x8ExtendLowI8x16S => logger.write_string("i16x8.extend_low_i8x16s")
    I16x8ExtendHighI8x16S => logger.write_string("i16x8.extend_high_i8x16s")
    I16x8ExtendLowI8x16U => logger.write_string("i16x8.extend_low_i8x16u")
    I16x8ExtendHighI8x16U => logger.write_string("i16x8.extend_high_i8x16u")
    I16x8Shl => logger.write_string("i16x8.shl")
    I16x8ShrS => logger.write_string("i16x8.shr_s")
    I16x8ShrU => logger.write_string("i16x8.shr_u")
    I16x8Add => logger.write_string("i16x8.add")
    I16x8AddSatS => logger.write_string("i16x8.add_sat_s")
    I16x8AddSatU => logger.write_string("i16x8.add_sat_u")
    I16x8Sub => logger.write_string("i16x8.sub")
    I16x8SubSatS => logger.write_string("i16x8.sub_sat_s")
    I16x8SubSatU => logger.write_string("i16x8.sub_sat_u")
    F64x2Nearest => logger.write_string("f64x2.nearest")
    I16x8Mul => logger.write_string("i16x8.mul")
    I16x8MinS => logger.write_string("i16x8.min_s")
    I16x8MinU => logger.write_string("i16x8.min_u")
    I16x8MaxS => logger.write_string("i16x8.max_s")
    I16x8MaxU => logger.write_string("i16x8.max_u")
    I16x8AvgrU => logger.write_string("i16x8.avgr_u")
    I16x8ExtmulLowI8x16S => logger.write_string("i16x8.extmul_low_i8x16s")
    I16x8ExtmulHighI8x16S => logger.write_string("i16x8.extmul_high_i8x16s")
    I16x8ExtmulLowI8x16U => logger.write_string("i16x8.extmul_low_i8x16u")
    I16x8ExtmulHighI8x16U => logger.write_string("i16x8.extmul_high_i8x16u")
    I32x4Abs => logger.write_string("i32x4.abs")
    I32x4Neg => logger.write_string("i32x4.neg")
    I32x4AllTrue => logger.write_string("i32x4.all_true")
    I32x4Bitmask => logger.write_string("i32x4.bitmask")
    I32x4ExtendLowI16x8S => logger.write_string("i32x4.extend_low_i16x8s")
    I32x4ExtendHighI16x8S => logger.write_string("i32x4.extend_high_i16x8s")
    I32x4ExtendLowI16x8U => logger.write_string("i32x4.extend_low_i16x8u")
    I32x4ExtendHighI16x8U => logger.write_string("i32x4.extend_high_i16x8u")
    I32x4Shl => logger.write_string("i32x4.shl")
    I32x4ShrS => logger.write_string("i32x4.shr_s")
    I32x4ShrU => logger.write_string("i32x4.shr_u")
    I32x4Add => logger.write_string("i32x4.add")
    I32x4Sub => logger.write_string("i32x4.sub")
    I32x4Mul => logger.write_string("i32x4.mul")
    I32x4MinS => logger.write_string("i32x4.min_s")
    I32x4MinU => logger.write_string("i32x4.min_u")
    I32x4MaxS => logger.write_string("i32x4.max_s")
    I32x4MaxU => logger.write_string("i32x4.max_u")
    I32x4DotI16x8S => logger.write_string("i32x4.dot_i16x8s")
    I32x4ExtmulLowI16x8S => logger.write_string("i32x4.extmul_low_i16x8s")
    I32x4ExtmulHighI16x8S => logger.write_string("i32x4.extmul_high_i16x8s")
    I32x4ExtmulLowI16x8U => logger.write_string("i32x4.extmul_low_i16x8u")
    I32x4ExtmulHighI16x8U => logger.write_string("i32x4.extmul_high_i16x8u")
    I64x2Abs => logger.write_string("i64x2.abs")
    I64x2Neg => logger.write_string("i64x2.neg")
    I64x2AllTrue => logger.write_string("i64x2.all_true")
    I64x2Bitmask => logger.write_string("i64x2.bitmask")
    I64x2ExtendLowI32x4S => logger.write_string("i64x2.extend_low_i32x4s")
    I64x2ExtendHighI32x4S => logger.write_string("i64x2.extend_high_i32x4s")
    I64x2ExtendLowI32x4U => logger.write_string("i64x2.extend_low_i32x4u")
    I64x2ExtendHighI32x4U => logger.write_string("i64x2.extend_high_i32x4u")
    I64x2Shl => logger.write_string("i64x2.shl")
    I64x2ShrS => logger.write_string("i64x2.shr_s")
    I64x2ShrU => logger.write_string("i64x2.shr_u")
    I64x2Add => logger.write_string("i64x2.add")
    I64x2Sub => logger.write_string("i64x2.sub")
    I64x2Mul => logger.write_string("i64x2.mul")
    I64x2Eq => logger.write_string("i64x2.eq")
    I64x2Ne => logger.write_string("i64x2.ne")
    I64x2LtS => logger.write_string("i64x2.lt_s")
    I64x2GtS => logger.write_string("i64x2.gt_s")
    I64x2LeS => logger.write_string("i64x2.le_s")
    I64x2GeS => logger.write_string("i64x2.ge_s")
    I64x2ExtmulLowI32x4S => logger.write_string("i64x2.extmul_low_i32x4s")
    I64x2ExtmulHighI32x4S => logger.write_string("i64x2.extmul_high_i32x4s")
    I64x2ExtmulLowI32x4U => logger.write_string("i64x2.extmul_low_i32x4u")
    I64x2ExtmulHighI32x4U => logger.write_string("i64x2.extmul_high_i32x4u")
    F32x4Abs => logger.write_string("f32x4.abs")
    F32x4Neg => logger.write_string("f32x4.neg")
    F32x4Sqrt => logger.write_string("f32x4.sqrt")
    F32x4Add => logger.write_string("f32x4.add")
    F32x4Sub => logger.write_string("f32x4.sub")
    F32x4Mul => logger.write_string("f32x4.mul")
    F32x4Div => logger.write_string("f32x4.div")
    F32x4Min => logger.write_string("f32x4.min")
    F32x4Max => logger.write_string("f32x4.max")
    F32x4Pmin => logger.write_string("f32x4.pmin")
    F32x4Pmax => logger.write_string("f32x4.pmax")
    F64x2Abs => logger.write_string("f64x2.abs")
    F64x2Neg => logger.write_string("f64x2.neg")
    F64x2Sqrt => logger.write_string("f64x2.sqrt")
    F64x2Add => logger.write_string("f64x2.add")
    F64x2Sub => logger.write_string("f64x2.sub")
    F64x2Mul => logger.write_string("f64x2.mul")
    F64x2Div => logger.write_string("f64x2.div")
    F64x2Min => logger.write_string("f64x2.min")
    F64x2Max => logger.write_string("f64x2.max")
    F64x2Pmin => logger.write_string("f64x2.pmin")
    F64x2Pmax => logger.write_string("f64x2.pmax")
    I32x4TruncSatF32x4S => logger.write_string("i32x4.trunc_sat_f32x4s")
    I32x4TruncSatF32x4U => logger.write_string("i32x4.trunc_sat_f32x4u")
    F32x4ConvertI32x4S => logger.write_string("f32x4.convert_i32x4s")
    F32x4ConvertI32x4U => logger.write_string("f32x4.convert_i32x4u")
    I32x4TruncSatF64x2SZero =>
      logger.write_string("i32x4.trunc_sat_f64x2s_zero")
    I32x4TruncSatF64x2UZero =>
      logger.write_string("i32x4.trunc_sat_f64x2u_zero")
    F64x2ConvertLowI32x4S => logger.write_string("f64x2.convert_low_i32x4s")
    F64x2ConvertLowI32x4U => logger.write_string("f64x2.convert_low_i32x4u")
    I8x16RelaxedSwizzle => logger.write_string("i8x16.relaxed_swizzle")
    I32x4RelaxedTruncF32x4S => logger.write_string("i32x4.relaxed_trunc_f32x4s")
    I32x4RelaxedTruncF32x4U => logger.write_string("i32x4.relaxed_trunc_f32x4u")
    I32x4RelaxedTruncZeroF64x2S =>
      logger.write_string("i32x4.relaxed_trunc_zero_f64x2s")
    I32x4RelaxedTruncZeroF64x2U =>
      logger.write_string("i32x4.relaxed_trunc_zero_f64x2u")
    F32x4RelaxedMadd => logger.write_string("f32x4.relaxed_madd")
    F32x4RelaxedNmadd => logger.write_string("f32x4.relaxed_nmadd")
    F64x2RelaxedMadd => logger.write_string("f64x2.relaxed_madd")
    F64x2RelaxedNmadd => logger.write_string("f64x2.relaxed_nmadd")
    I8x16RelaxedLaneselect => logger.write_string("i8x16.relaxed_laneselect")
    I16x8RelaxedLaneselect => logger.write_string("i16x8.relaxed_laneselect")
    I32x4RelaxedLaneselect => logger.write_string("i32x4.relaxed_laneselect")
    I64x2RelaxedLaneselect => logger.write_string("i64x2.relaxed_laneselect")
    F32x4RelaxedMin => logger.write_string("f32x4.relaxed_min")
    F32x4RelaxedMax => logger.write_string("f32x4.relaxed_max")
    F64x2RelaxedMin => logger.write_string("f64x2.relaxed_min")
    F64x2RelaxedMax => logger.write_string("f64x2.relaxed_max")
    I16x8RelaxedQ15mulrS => logger.write_string("i16x8.relaxed_q15mulr_s")
    I16x8RelaxedDotI8x16I7x16S =>
      logger.write_string("i16x8.relaxed_dot_i8x16i7x16s")
    I32x4RelaxedDotI8x16I7x16AddS =>
      logger.write_string("i32x4.relaxed_dot_i8x16i7x16_add_s")
  }
}

///|
pub impl Show for CustomSec with fn output(self, logger) {
  let CustomSec(name, _) = self
  logger.write_string("[Custom: ")
  Show::output(name, logger)
  logger.write_char(']')
}

///|
pub impl Show for TypeSec with fn output(self, logger) {
  let TypeSec(tys) = self
  logger.write_string("[Types")
  if tys.length() == 0 {
    logger.write_char(']')
    return
  }
  logger.write_string(":\n")
  for ty in tys {
    logger.write_string("  - ")
    Show::output(ty, logger)
    logger.write_char('\n')
  }
  logger.write_char(']')
}

///|
pub impl Show for ImportSec with fn output(self, logger) {
  let ImportSec(imports) = self
  logger.write_string("[Imports")
  if imports.length() == 0 {
    logger.write_char(']')
    return
  }
  logger.write_string(": \n")
  for i in imports {
    logger.write_string("  - ")
    Show::output(i, logger)
    logger.write_char('\n')
  }
  logger.write_char(']')
}

///|
pub impl Show for FuncSec with fn output(self, logger) {
  let FuncSec(fns) = self
  logger.write_string("[Funcs")
  if fns.length() == 0 {
    logger.write_char(']')
    return
  }
  logger.write_string(": \n")
  for i in fns {
    logger.write_string("  - ")
    Show::output(i, logger)
    logger.write_char('\n')
  }
  logger.write_char(']')
}

///|
pub impl Show for TableSec with fn output(self, logger) {
  let TableSec(tbls) = self
  logger.write_string("[Tables")
  if tbls.length() == 0 {
    logger.write_char(']')
    return
  }
  logger.write_string(": \n")
  for i in tbls {
    logger.write_string("  - ")
    Show::output(i, logger)
    logger.write_char('\n')
  }
  logger.write_char(']')
}

///|
pub impl Show for MemSec with fn output(self, logger) {
  let MemSec(mems) = self
  logger.write_string("[Memory")
  if mems.length() == 0 {
    logger.write_char(']')
    return
  }
  logger.write_string(": \n")
  for i in mems {
    logger.write_string("  - ")
    Show::output(i, logger)
    logger.write_char('\n')
  }
  logger.write_char(']')
}

///|
pub impl Show for TagSec with fn output(self, logger) {
  let TagSec(mems) = self
  logger.write_string("[Tags")
  if mems.length() == 0 {
    logger.write_char(']')
    return
  }
  logger.write_string(": \n")
  for i in mems {
    logger.write_string("  - ")
    Show::output(i, logger)
    logger.write_char('\n')
  }
  logger.write_char(']')
}

///|
pub impl Show for GlobalSec with fn output(self, logger) {
  let GlobalSec(globals) = self
  logger.write_string("[Globals")
  if globals.length() == 0 {
    logger.write_char(']')
    return
  }
  logger.write_string(": \n")
  for i in globals {
    logger.write_string("  - ")
    Show::output(i, logger)
    logger.write_char('\n')
  }
  logger.write_char(']')
}

///|
pub impl Show for ExportSec with fn output(self, logger) {
  let ExportSec(exports) = self
  logger.write_string("[Globals")
  if exports.length() == 0 {
    logger.write_char(']')
    return
  }
  logger.write_string(": \n")
  for i in exports {
    logger.write_string("  - ")
    Show::output(i, logger)
    logger.write_char('\n')
  }
  logger.write_char(']')
}

///|
pub impl Show for StartSec with fn output(self, logger) {
  let StartSec(start) = self
  logger.write_string("[Start ")
  Show::output(start, logger)
  logger.write_char(']')
}

///|
pub impl Show for ElemSec with fn output(self, logger) {
  let ElemSec(elems) = self
  logger.write_string("[Elems")
  if elems.length() == 0 {
    logger.write_char(']')
    return
  }
  logger.write_string(": \n")
  for i in elems {
    logger.write_string("  - ")
    Show::output(i, logger)
    logger.write_char('\n')
  }
  logger.write_char(']')
}

///|
pub impl Show for DataCntSec with fn output(self, logger) {
  let DataCntSec(start) = self
  logger.write_string("[DataCount ")
  Show::output(start, logger)
  logger.write_char(']')
}

///|
pub impl Show for CodeSec with fn output(self, logger) {
  let CodeSec(codes) = self
  logger.write_string("[Code")
  if codes.length() == 0 {
    logger.write_char(']')
    return
  }
  logger.write_string(": \n")
  for i in codes {
    logger.write_string("  - ")
    Show::output(i, logger)
    logger.write_char('\n')
  }
  logger.write_char(']')
}

///|
pub impl Show for DataSec with fn output(self, logger) {
  let DataSec(datas) = self
  logger.write_string("[Elems")
  if datas.length() == 0 {
    logger.write_char(']')
    return
  }
  logger.write_string(": \n")
  for i in datas {
    logger.write_string("  - ")
    Show::output(i, logger)
    logger.write_char('\n')
  }
  logger.write_char(']')
}

///|
pub impl Show for FuncAnnotation with fn output(self, logger) {
  logger.write_string("FuncAnnotation(name=")
  logger.write_string(self.name)
  logger.write_string(", args=")
  Show::output(self.args, logger)
  logger.write_char(')')
}

///|
pub impl Show for FuncAnnotationAssoc with fn output(self, logger) {
  let FuncAnnotationAssoc(idx, annotations) = self
  logger.write_string("FuncAnnotationAssoc(")
  Show::output(idx, logger)
  logger.write_string(", ")
  Show::output(annotations, logger)
  logger.write_char(')')
}

///|
pub impl Show for FuncAnnotationSec with fn output(self, logger) {
  let FuncAnnotationSec(entries) = self
  logger.write_string("[FuncAnnotationSec")
  if entries.length() == 0 {
    logger.write_char(']')
    return
  }
  logger.write_string(": \n")
  for entry in entries {
    logger.write_string("  - ")
    Show::output(entry, logger)
    logger.write_char('\n')
  }
  logger.write_char(']')
}

///|
pub impl Show for Module with fn output(self, logger) {
  let {
    custom_secs: customs,
    name_sec,
    raw_name_sec_payload,
    type_sec,
    import_sec,
    func_annotation_sec,
    func_sec,
    table_sec,
    mem_sec,
    tag_sec,
    stringrefs_sec,
    global_sec,
    export_sec,
    start_sec,
    elem_sec,
    data_cnt_sec,
    code_sec,
    data_sec,
  } = self
  logger.write_string("Module[\n")
  logger.write_string("customs: ")
  Show::output(customs, logger)
  logger.write_char('\n')
  logger.write_string("name_sec: ")
  logger.write_string(@debug.to_string(name_sec))
  logger.write_char('\n')
  logger.write_string("raw_name_sec_payload: ")
  logger.write_string(@debug.to_string(raw_name_sec_payload))
  logger.write_char('\n')
  logger.write_string("type_sec: ")
  logger.write_string(@debug.to_string(type_sec))
  logger.write_char('\n')
  logger.write_string("import_sec: ")
  logger.write_string(@debug.to_string(import_sec))
  logger.write_char('\n')
  logger.write_string("func_annotation_sec: ")
  logger.write_string(@debug.to_string(func_annotation_sec))
  logger.write_char('\n')
  logger.write_string("func_sec: ")
  logger.write_string(@debug.to_string(func_sec))
  logger.write_char('\n')
  logger.write_string("table_sec: ")
  logger.write_string(@debug.to_string(table_sec))
  logger.write_char('\n')
  logger.write_string("mem_sec: ")
  logger.write_string(@debug.to_string(mem_sec))
  logger.write_char('\n')
  logger.write_string("tag_sec: ")
  logger.write_string(@debug.to_string(tag_sec))
  logger.write_char('\n')
  logger.write_string("stringrefs_sec: ")
  logger.write_string(@debug.to_string(stringrefs_sec))
  logger.write_char('\n')
  logger.write_string("global_sec: ")
  logger.write_string(@debug.to_string(global_sec))
  logger.write_char('\n')
  logger.write_string("export_sec: ")
  logger.write_string(@debug.to_string(export_sec))
  logger.write_char('\n')
  logger.write_string("start_sec: ")
  logger.write_string(@debug.to_string(start_sec))
  logger.write_char('\n')
  logger.write_string("elem_sec: ")
  logger.write_string(@debug.to_string(elem_sec))
  logger.write_char('\n')
  logger.write_string("data_cnt_sec: ")
  logger.write_string(@debug.to_string(data_cnt_sec))
  logger.write_char('\n')
  logger.write_string("code_sec: ")
  logger.write_string(@debug.to_string(code_sec))
  logger.write_char('\n')
  logger.write_string("data_sec: ")
  logger.write_string(@debug.to_string(data_sec))
  logger.write_string("]")
}

///|
pub impl Show for FuncType with fn output(self, logger) {
  let FuncType(props, results) = self
  logger.write_string("FuncType {\n  props : ")
  Show::output(props, logger)
  logger.write_string("\n  results : ")
  Show::output(results, logger)
  logger.write_string("\n}")
}
