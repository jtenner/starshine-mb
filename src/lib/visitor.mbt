/// Transformer callbacks - all optional. Return `None` to use default recursion.
pub struct ModuleTransformer {
  on_instruction : ((Instruction) -> Instruction?)?
  on_expr : ((Expr) -> Expr?)?
  on_valtype : ((ValType) -> ValType?)?
  on_reftype : ((RefType) -> RefType?)?
  on_heaptype : ((HeapType) -> HeapType?)?
  on_blocktype : ((BlockType) -> BlockType?)?
  on_funcidx : ((FuncIdx) -> FuncIdx?)?
  on_typeidx : ((TypeIdx) -> TypeIdx?)?
  on_localidx : ((LocalIdx) -> LocalIdx?)?
  on_globalidx : ((GlobalIdx) -> GlobalIdx?)?
  on_tableidx : ((TableIdx) -> TableIdx?)?
  on_memidx : ((MemIdx) -> MemIdx?)?
  on_labelidx : ((LabelIdx) -> LabelIdx?)?
  on_dataidx : ((DataIdx) -> DataIdx?)?
  on_elemidx : ((ElemIdx) -> ElemIdx?)?
  on_tagidx : ((TagIdx) -> TagIdx?)?
}

pub fn ModuleTransformer::new() -> ModuleTransformer {
  ModuleTransformer::{
    on_instruction: None,
    on_expr: None,
    on_valtype: None,
    on_reftype: None,
    on_heaptype: None,
    on_blocktype: None,
    on_funcidx: None,
    on_typeidx: None,
    on_localidx: None,
    on_globalidx: None,
    on_tableidx: None,
    on_memidx: None,
    on_labelidx: None,
    on_dataidx: None,
    on_elemidx: None,
    on_tagidx: None,
  }
}

pub fn ModuleTransformer::walk_expr(self : ModuleTransformer, expr : Expr) -> Expr {
  // Check if user wants to override
  match self.on_expr {
    Some(f) =>
      match f(expr) {
        Some(e) => e
        None => self.walk_expr_default(expr)
      }
    None => self.walk_expr_default(expr)
  }
}

pub fn ModuleTransformer::walk_expr_default(self : ModuleTransformer, expr : Expr) -> Expr {
  let Expr(instructions) = expr
  Expr(instructions.map(fn(i) { self.walk_instruction(i) }))
}

pub fn ModuleTransformer::walk_instruction(self : ModuleTransformer, instr : Instruction) -> Instruction {
  match self.on_instruction {
    Some(f) =>
      match f(instr) {
        Some(i) => i
        None => self.walk_instruction_default(instr)
      }
    None => self.walk_instruction_default(instr)
  }
}

pub fn ModuleTransformer::walk_instruction_default(
  self : ModuleTransformer,
  instr : Instruction
) -> Instruction {
  match instr {
    // Control instructions with nested structure
    Block(bt, body) => Block(self.walk_blocktype(bt), self.walk_expr(body))
    Loop(bt, body) => Loop(self.walk_blocktype(bt), self.walk_expr(body))
    If(bt, then_body, else_body) =>
      If(
        self.walk_blocktype(bt),
        then_body.map(fn(i) { self.walk_instruction(i) }),
        else_body.map(fn(arr) { arr.map(fn(i) { self.walk_instruction(i) }) }),
      )
    TryTable(bt, catches, body) =>
      TryTable(
        self.walk_blocktype(bt),
        catches.map(fn(c) { self.walk_catch(c) }),
        self.walk_expr(body),
      )

    // Branch instructions
    Br(l) => Br(self.walk_labelidx(l))
    BrIf(l) => BrIf(self.walk_labelidx(l))
    BrTable(labels, default) =>
      BrTable(
        labels.map(fn(l) { self.walk_labelidx(l) }),
        self.walk_labelidx(default),
      )
    BrOnNull(l) => BrOnNull(self.walk_labelidx(l))
    BrOnNonNull(l) => BrOnNonNull(self.walk_labelidx(l))
    BrOnCast(l, op, ht1, ht2) =>
      BrOnCast(
        self.walk_labelidx(l),
        op,
        self.walk_heaptype(ht1),
        self.walk_heaptype(ht2),
      )
    BrOnCastFail(l, op, ht1, ht2) =>
      BrOnCastFail(
        self.walk_labelidx(l),
        op,
        self.walk_heaptype(ht1),
        self.walk_heaptype(ht2),
      )

    // Call instructions
    Call(f) => Call(self.walk_funcidx(f))
    CallIndirect(t, tbl) =>
      CallIndirect(self.walk_typeidx(t), self.walk_tableidx(tbl))
    ReturnCall(f) => ReturnCall(self.walk_funcidx(f))
    ReturnCallIndirect(t, tbl) =>
      ReturnCallIndirect(self.walk_typeidx(t), self.walk_tableidx(tbl))
    CallRef(t) => CallRef(self.walk_typeidx(t))
    ReturnCallRef(t) => ReturnCallRef(self.walk_typeidx(t))

    // Variable instructions
    LocalGet(l) => LocalGet(self.walk_localidx(l))
    LocalSet(l) => LocalSet(self.walk_localidx(l))
    LocalTee(l) => LocalTee(self.walk_localidx(l))
    GlobalGet(g) => GlobalGet(self.walk_globalidx(g))
    GlobalSet(g) => GlobalSet(self.walk_globalidx(g))

    // Table instructions
    TableGet(t) => TableGet(self.walk_tableidx(t))
    TableSet(t) => TableSet(self.walk_tableidx(t))
    TableGrow(t) => TableGrow(self.walk_tableidx(t))
    TableSize(t) => TableSize(self.walk_tableidx(t))
    TableFill(t) => TableFill(self.walk_tableidx(t))
    TableCopy(t1, t2) =>
      TableCopy(self.walk_tableidx(t1), self.walk_tableidx(t2))
    TableInit(e, t) => TableInit(self.walk_elemidx(e), self.walk_tableidx(t))
    ElemDrop(e) => ElemDrop(self.walk_elemidx(e))

    // Reference instructions
    RefNull(ht) => RefNull(self.walk_heaptype(ht))
    RefFunc(f) => RefFunc(self.walk_funcidx(f))
    RefTest(nullable, ht) => RefTest(nullable, self.walk_heaptype(ht))
    RefCast(nullable, ht) => RefCast(nullable, self.walk_heaptype(ht))

    // Struct/Array instructions
    StructNew(t) => StructNew(self.walk_typeidx(t))
    StructNewDefault(t) => StructNewDefault(self.walk_typeidx(t))
    StructGet(t, f) => StructGet(self.walk_typeidx(t), f)
    StructGetS(t, f) => StructGetS(self.walk_typeidx(t), f)
    StructGetU(t, f) => StructGetU(self.walk_typeidx(t), f)
    StructSet(t, f) => StructSet(self.walk_typeidx(t), f)
    ArrayNew(t) => ArrayNew(self.walk_typeidx(t))
    ArrayNewDefault(t) => ArrayNewDefault(self.walk_typeidx(t))
    ArrayNewFixed(t, n) => ArrayNewFixed(self.walk_typeidx(t), n)
    ArrayNewData(t, d) =>
      ArrayNewData(self.walk_typeidx(t), self.walk_dataidx(d))
    ArrayNewElem(t, e) =>
      ArrayNewElem(self.walk_typeidx(t), self.walk_elemidx(e))
    ArrayGet(t) => ArrayGet(self.walk_typeidx(t))
    ArrayGetS(t) => ArrayGetS(self.walk_typeidx(t))
    ArrayGetU(t) => ArrayGetU(self.walk_typeidx(t))
    ArraySet(t) => ArraySet(self.walk_typeidx(t))
    ArrayFill(t) => ArrayFill(self.walk_typeidx(t))
    ArrayCopy(t1, t2) =>
      ArrayCopy(self.walk_typeidx(t1), self.walk_typeidx(t2))
    ArrayInitData(t, d) =>
      ArrayInitData(self.walk_typeidx(t), self.walk_dataidx(d))
    ArrayInitElem(t, e) =>
      ArrayInitElem(self.walk_typeidx(t), self.walk_elemidx(e))

    // Memory instructions
    MemorySize(m) => MemorySize(self.walk_memidx(m))
    MemoryGrow(m) => MemoryGrow(self.walk_memidx(m))
    MemoryFill(m) => MemoryFill(self.walk_memidx(m))
    MemoryCopy(m1, m2) =>
      MemoryCopy(self.walk_memidx(m1), self.walk_memidx(m2))
    MemoryInit(d, m) => MemoryInit(self.walk_dataidx(d), self.walk_memidx(m))
    DataDrop(d) => DataDrop(self.walk_dataidx(d))

    // Exception instructions
    Throw(t) => Throw(self.walk_tagidx(t))

    // Select with types
    Select(types) =>
      Select(types.map(fn(arr) { arr.map(fn(t) { self.walk_valtype(t) }) }))

    // All other instructions pass through unchanged
    other => other
  }
}

pub fn ModuleTransformer::walk_blocktype(self : ModuleTransformer, bt : BlockType) -> BlockType {
  match self.on_blocktype {
    Some(f) =>
      match f(bt) {
        Some(b) => b
        None => self.walk_blocktype_default(bt)
      }
    None => self.walk_blocktype_default(bt)
  }
}

pub fn ModuleTransformer::walk_blocktype_default(self : ModuleTransformer, bt : BlockType) -> BlockType {
  match bt {
    EmptyBlockType => EmptyBlockType
    ValTypeBlockType(vt) => ValTypeBlockType(self.walk_valtype(vt))
    TypeIdxBlockType(t) => TypeIdxBlockType(self.walk_typeidx(t))
  }
}

pub fn ModuleTransformer::walk_catch(self : ModuleTransformer, c : Catch) -> Catch {
  match c {
    Catch(tag, label) => Catch(self.walk_tagidx(tag), self.walk_labelidx(label))
    CatchRef(tag, label) =>
      CatchRef(self.walk_tagidx(tag), self.walk_labelidx(label))
    CatchAll(label) => CatchAll(self.walk_labelidx(label))
    CatchAllRef(label) => CatchAllRef(self.walk_labelidx(label))
  }
}

// Index walkers - leaf nodes
pub fn ModuleTransformer::walk_funcidx(self : ModuleTransformer, idx : FuncIdx) -> FuncIdx {
  match self.on_funcidx {
    Some(f) => f(idx).unwrap_or(idx)
    None => idx
  }
}

pub fn ModuleTransformer::walk_typeidx(self : ModuleTransformer, idx : TypeIdx) -> TypeIdx {
  match self.on_typeidx {
    Some(f) => f(idx).unwrap_or(idx)
    None => idx
  }
}

pub fn ModuleTransformer::walk_localidx(self : ModuleTransformer, idx : LocalIdx) -> LocalIdx {
  match self.on_localidx {
    Some(f) => f(idx).unwrap_or(idx)
    None => idx
  }
}

pub fn ModuleTransformer::walk_globalidx(self : ModuleTransformer, idx : GlobalIdx) -> GlobalIdx {
  match self.on_globalidx {
    Some(f) => f(idx).unwrap_or(idx)
    None => idx
  }
}

pub fn ModuleTransformer::walk_tableidx(self : ModuleTransformer, idx : TableIdx) -> TableIdx {
  match self.on_tableidx {
    Some(f) => f(idx).unwrap_or(idx)
    None => idx
  }
}

pub fn ModuleTransformer::walk_memidx(self : ModuleTransformer, idx : MemIdx) -> MemIdx {
  match self.on_memidx {
    Some(f) => f(idx).unwrap_or(idx)
    None => idx
  }
}

pub fn ModuleTransformer::walk_labelidx(self : ModuleTransformer, idx : LabelIdx) -> LabelIdx {
  match self.on_labelidx {
    Some(f) => f(idx).unwrap_or(idx)
    None => idx
  }
}

pub fn ModuleTransformer::walk_dataidx(self : ModuleTransformer, idx : DataIdx) -> DataIdx {
  match self.on_dataidx {
    Some(f) => f(idx).unwrap_or(idx)
    None => idx
  }
}

pub fn ModuleTransformer::walk_elemidx(self : ModuleTransformer, idx : ElemIdx) -> ElemIdx {
  match self.on_elemidx {
    Some(f) => f(idx).unwrap_or(idx)
    None => idx
  }
}

pub fn ModuleTransformer::walk_tagidx(self : ModuleTransformer, idx : TagIdx) -> TagIdx {
  match self.on_tagidx {
    Some(f) => f(idx).unwrap_or(idx)
    None => idx
  }
}

pub fn ModuleTransformer::walk_valtype(self : ModuleTransformer, vt : ValType) -> ValType {
  match self.on_valtype {
    Some(f) =>
      match f(vt) {
        Some(v) => v
        None => self.walk_valtype_default(vt)
      }
    None => self.walk_valtype_default(vt)
  }
}

pub fn ModuleTransformer::walk_valtype_default(self : ModuleTransformer, vt : ValType) -> ValType {
  match vt {
    RefTypeValType(rt) => RefTypeValType(self.walk_reftype(rt))
    other => other
  }
}

pub fn ModuleTransformer::walk_reftype(self : ModuleTransformer, rt : RefType) -> RefType {
  match self.on_reftype {
    Some(f) =>
      match f(rt) {
        Some(r) => r
        None => self.walk_reftype_default(rt)
      }
    None => self.walk_reftype_default(rt)
  }
}

pub fn ModuleTransformer::walk_reftype_default(self : ModuleTransformer, rt : RefType) -> RefType {
  match rt {
    HeapTypeRefType(nullable, ht) =>
      HeapTypeRefType(nullable, self.walk_heaptype(ht))
    AbsHeapTypeRefType(_) => rt
  }
}

pub fn ModuleTransformer::walk_heaptype(self : ModuleTransformer, ht : HeapType) -> HeapType {
  match self.on_heaptype {
    Some(f) =>
      match f(ht) {
        Some(h) => h
        None => self.walk_heaptype_default(ht)
      }
    None => self.walk_heaptype_default(ht)
  }
}

pub fn ModuleTransformer::walk_heaptype_default(self : ModuleTransformer, ht : HeapType) -> HeapType {
  match ht {
    HeapType(t) => HeapType(self.walk_typeidx(t))
    other => other
  }
}

pub fn ModuleTransformer::walk_module(self : ModuleTransformer, mod : Module) -> Module {
  let Module(
    custom,
    type_sec,
    import_sec,
    func_sec,
    table_sec,
    mem_sec,
    tag_sec,
    global_sec,
    export_sec,
    start_sec,
    elem_sec,
    datacnt_sec,
    code_sec,
    data_sec,
  ) = mod
  Module(
    custom,
    type_sec.map(fn(ts) { self.walk_typesec(ts) }),
    import_sec,
    func_sec.map(fn(fs) { self.walk_funcsec(fs) }),
    table_sec,
    mem_sec,
    tag_sec,
    global_sec.map(fn(gs) { self.walk_globalsec(gs) }),
    export_sec,
    start_sec,
    elem_sec.map(fn(es) { self.walk_elemsec(es) }),
    datacnt_sec,
    code_sec.map(fn(cs) { self.walk_codesec(cs) }),
    data_sec.map(fn(ds) { self.walk_datasec(ds) }),
  )
}

pub fn ModuleTransformer::walk_codesec(self : ModuleTransformer, cs : CodeSec) -> CodeSec {
  let CodeSec(funcs) = cs
  CodeSec(funcs.map(fn(f) { self.walk_func(f) }))
}

pub fn ModuleTransformer::walk_func(self : ModuleTransformer, f : Func) -> Func {
  let Func(locals, body) = f
  Func(
    locals.map(fn(l) {
      let Locals(n, vt) = l
      Locals(n, self.walk_valtype(vt))
    }),
    self.walk_expr(body),
  )
}

pub fn ModuleTransformer::walk_typesec(self : ModuleTransformer, ts : TypeSec) -> TypeSec {
  let TypeSec(rectypes) = ts
  TypeSec(rectypes.map(fn(rt) { self.walk_rectype(rt) }))
}

pub fn ModuleTransformer::walk_rectype(self : ModuleTransformer, rt : RecType) -> RecType {
  match rt {
    SingleRecType(st) => SingleRecType(self.walk_subtype(st))
    GroupRecType(sts) => GroupRecType(sts.map(fn(st) { self.walk_subtype(st) }))
  }
}

pub fn ModuleTransformer::walk_subtype(self : ModuleTransformer, st : SubType) -> SubType {
  match st {
    SubType(final_, supers, ct) =>
      SubType(
        final_,
        supers.map(fn(t) { self.walk_typeidx(t) }),
        self.walk_comptype(ct),
      )
    CompTypeSubType(ct) => CompTypeSubType(self.walk_comptype(ct))
  }
}

pub fn ModuleTransformer::walk_comptype(self : ModuleTransformer, ct : CompType) -> CompType {
  match ct {
    FuncCompType(params, results) =>
      FuncCompType(
        params.map(fn(t) { self.walk_valtype(t) }),
        results.map(fn(t) { self.walk_valtype(t) }),
      )
    StructCompType(fields) =>
      StructCompType(fields.map(fn(f) { self.walk_fieldtype(f) }))
    ArrayCompType(ft) => ArrayCompType(self.walk_fieldtype(ft))
  }
}

pub fn ModuleTransformer::walk_fieldtype(self : ModuleTransformer, ft : FieldType) -> FieldType {
  let FieldType(st, mut_) = ft
  FieldType(self.walk_storagetype(st), mut_)
}

pub fn ModuleTransformer::walk_storagetype(self : ModuleTransformer, st : StorageType) -> StorageType {
  match st {
    ValTypeStorageType(vt) => ValTypeStorageType(self.walk_valtype(vt))
    PackTypeStorageType(_) => st
  }
}

pub fn ModuleTransformer::walk_globalsec(self : ModuleTransformer, gs : GlobalSec) -> GlobalSec {
  let GlobalSec(globals) = gs
  GlobalSec(globals.map(fn(g) { self.walk_global(g) }))
}

pub fn ModuleTransformer::walk_global(self : ModuleTransformer, g : Global) -> Global {
  let Global(gt, init) = g
  Global(self.walk_globaltype(gt), self.walk_expr(init))
}

pub fn ModuleTransformer::walk_globaltype(self : ModuleTransformer, gt : GlobalType) -> GlobalType {
  let GlobalType(vt, mutable) = gt
  GlobalType(self.walk_valtype(vt), mutable)
}

pub fn ModuleTransformer::walk_elemsec(self : ModuleTransformer, es : ElemSec) -> ElemSec {
  let ElemSec(elems) = es
  ElemSec(elems.map(fn(e) { self.walk_elem(e) }))
}

pub fn ModuleTransformer::walk_elem(self : ModuleTransformer, e : Elem) -> Elem {
  let Elem(mode, kind) = e
  Elem(self.walk_elemmode(mode), self.walk_elemkind(kind))
}

pub fn ModuleTransformer::walk_elemmode(self : ModuleTransformer, mode : ElemMode) -> ElemMode {
  match mode {
    Active(tidx, offset) =>
      Active(self.walk_tableidx(tidx), self.walk_expr(offset))
    other => other
  }
}

pub fn ModuleTransformer::walk_elemkind(self : ModuleTransformer, kind : ElemKind) -> ElemKind {
  match kind {
    FuncsElemKind(idxs) =>
      FuncsElemKind(idxs.map(fn(i) { self.walk_funcidx(i) }))
    FuncExprsElemKind(exprs) =>
      FuncExprsElemKind(exprs.map(fn(e) { self.walk_expr(e) }))
    TypedExprsElemKind(rt, exprs) =>
      TypedExprsElemKind(
        self.walk_reftype(rt),
        exprs.map(fn(e) { self.walk_expr(e) }),
      )
  }
}

pub fn ModuleTransformer::walk_datasec(self : ModuleTransformer, ds : DataSec) -> DataSec {
  let DataSec(data) = ds
  DataSec(data.map(fn(d) { self.walk_data(d) }))
}

pub fn ModuleTransformer::walk_data(self : ModuleTransformer, d : Data) -> Data {
  let Data(mode, bytes) = d
  Data(self.walk_datamode(mode), bytes)
}

pub fn ModuleTransformer::walk_datamode(self : ModuleTransformer, mode : DataMode) -> DataMode {
  match mode {
    Active(midx, offset) =>
      Active(self.walk_memidx(midx), self.walk_expr(offset))
    Passive => Passive
  }
}

pub fn ModuleTransformer::walk_funcsec(self : ModuleTransformer, fs : FuncSec) -> FuncSec {
  let FuncSec(idxs) = fs
  FuncSec(idxs.map(fn(i) { self.walk_typeidx(i) }))
}

pub struct ModuleVisitor {
  // Instructions and expressions
  visit_instruction : ((Instruction) -> Unit)?
  visit_expr : ((Expr) -> Unit)?

  // Types
  visit_valtype : ((ValType) -> Unit)?
  visit_reftype : ((RefType) -> Unit)?
  visit_heaptype : ((HeapType) -> Unit)?
  visit_blocktype : ((BlockType) -> Unit)?
  visit_comptype : ((CompType) -> Unit)?
  visit_subtype : ((SubType) -> Unit)?
  visit_rectype : ((RecType) -> Unit)?
  visit_fieldtype : ((FieldType) -> Unit)?
  visit_storagetype : ((StorageType) -> Unit)?
  visit_globaltype : ((GlobalType) -> Unit)?
  visit_tabletype : ((TableType) -> Unit)?
  visit_memtype : ((MemType) -> Unit)?
  visit_functype : ((FuncType) -> Unit)?

  // Indices
  visit_funcidx : ((FuncIdx) -> Unit)?
  visit_typeidx : ((TypeIdx) -> Unit)?
  visit_localidx : ((LocalIdx) -> Unit)?
  visit_globalidx : ((GlobalIdx) -> Unit)?
  visit_tableidx : ((TableIdx) -> Unit)?
  visit_memidx : ((MemIdx) -> Unit)?
  visit_labelidx : ((LabelIdx) -> Unit)?
  visit_dataidx : ((DataIdx) -> Unit)?
  visit_elemidx : ((ElemIdx) -> Unit)?
  visit_tagidx : ((TagIdx) -> Unit)?

  // Module sections
  visit_func : ((Func) -> Unit)?
  visit_global : ((Global) -> Unit)?
  visit_table : ((Table) -> Unit)?
  visit_elem : ((Elem) -> Unit)?
  visit_data : ((Data) -> Unit)?
  visit_import : ((Import) -> Unit)?
  visit_export : ((Export) -> Unit)?

  // Control whether to descend into children after visiting
  // Default is true - set to false in callback to skip children
  descend : Bool
}

pub fn ModuleVisitor::new() -> ModuleVisitor {
  {
    visit_instruction: None,
    visit_expr: None,
    visit_valtype: None,
    visit_reftype: None,
    visit_heaptype: None,
    visit_blocktype: None,
    visit_comptype: None,
    visit_subtype: None,
    visit_rectype: None,
    visit_fieldtype: None,
    visit_storagetype: None,
    visit_globaltype: None,
    visit_tabletype: None,
    visit_memtype: None,
    visit_functype: None,
    visit_funcidx: None,
    visit_typeidx: None,
    visit_localidx: None,
    visit_globalidx: None,
    visit_tableidx: None,
    visit_memidx: None,
    visit_labelidx: None,
    visit_dataidx: None,
    visit_elemidx: None,
    visit_tagidx: None,
    visit_func: None,
    visit_global: None,
    visit_table: None,
    visit_elem: None,
    visit_data: None,
    visit_import: None,
    visit_export: None,
    descend: true,
  }
}

pub fn ModuleVisitor::visit_expr(self : ModuleVisitor, expr : Expr) -> Unit {
  match self.visit_expr {
    Some(f) => f(expr)
    None => ()
  }
  if self.descend {
    let Expr(instructions) = expr
    instructions.each(fn(i) { self.visit_instruction(i) })
  }
}

pub fn ModuleVisitor::visit_instruction(self : ModuleVisitor, instr : Instruction) -> Unit {
  match self.visit_instruction {
    Some(f) => f(instr)
    None => ()
  }
  if self.descend {
    self.visit_instruction_children(instr)
  }
}

pub fn ModuleVisitor::visit_instruction_children(self : ModuleVisitor, instr : Instruction) -> Unit {
  match instr {
    // Control instructions with nested structure
    Block(bt, body) => {
      self.visit_blocktype(bt)
      self.visit_expr(body)
    }
    Loop(bt, body) => {
      self.visit_blocktype(bt)
      self.visit_expr(body)
    }
    If(bt, then_instrs, else_instrs) => {
      self.visit_blocktype(bt)
      then_instrs.each(fn(i) { self.visit_instruction(i) })
      match else_instrs {
        Some(instrs) => instrs.each(fn(i) { self.visit_instruction(i) })
        None => ()
      }
    }
    TryTable(bt, catches, body) => {
      self.visit_blocktype(bt)
      catches.each(fn(c) { self.visit_catch(c) })
      self.visit_expr(body)
    }

    // Branch instructions
    Br(l) => self.visit_labelidx(l)
    BrIf(l) => self.visit_labelidx(l)
    BrTable(labels, default) => {
      labels.each(fn(l) { self.visit_labelidx(l) })
      self.visit_labelidx(default)
    }
    BrOnNull(l) => self.visit_labelidx(l)
    BrOnNonNull(l) => self.visit_labelidx(l)
    BrOnCast(l, _, ht1, ht2) => {
      self.visit_labelidx(l)
      self.visit_heaptype(ht1)
      self.visit_heaptype(ht2)
    }
    BrOnCastFail(l, _, ht1, ht2) => {
      self.visit_labelidx(l)
      self.visit_heaptype(ht1)
      self.visit_heaptype(ht2)
    }

    // Call instructions
    Call(f) => self.visit_funcidx(f)
    CallIndirect(t, tbl) => {
      self.visit_typeidx(t)
      self.visit_tableidx(tbl)
    }
    ReturnCall(f) => self.visit_funcidx(f)
    ReturnCallIndirect(t, tbl) => {
      self.visit_typeidx(t)
      self.visit_tableidx(tbl)
    }
    CallRef(t) => self.visit_typeidx(t)
    ReturnCallRef(t) => self.visit_typeidx(t)

    // Variable instructions
    LocalGet(l) => self.visit_localidx(l)
    LocalSet(l) => self.visit_localidx(l)
    LocalTee(l) => self.visit_localidx(l)
    GlobalGet(g) => self.visit_globalidx(g)
    GlobalSet(g) => self.visit_globalidx(g)

    // Table instructions
    TableGet(t) => self.visit_tableidx(t)
    TableSet(t) => self.visit_tableidx(t)
    TableGrow(t) => self.visit_tableidx(t)
    TableSize(t) => self.visit_tableidx(t)
    TableFill(t) => self.visit_tableidx(t)
    TableCopy(t1, t2) => {
      self.visit_tableidx(t1)
      self.visit_tableidx(t2)
    }
    TableInit(e, t) => {
      self.visit_elemidx(e)
      self.visit_tableidx(t)
    }
    ElemDrop(e) => self.visit_elemidx(e)

    // Memory instructions with MemIdx
    MemorySize(m) => self.visit_memidx(m)
    MemoryGrow(m) => self.visit_memidx(m)
    MemoryFill(m) => self.visit_memidx(m)
    MemoryCopy(m1, m2) => {
      self.visit_memidx(m1)
      self.visit_memidx(m2)
    }
    MemoryInit(d, m) => {
      self.visit_dataidx(d)
      self.visit_memidx(m)
    }
    DataDrop(d) => self.visit_dataidx(d)

    // Reference instructions
    RefNull(ht) => self.visit_heaptype(ht)
    RefFunc(f) => self.visit_funcidx(f)
    RefTest(_, ht) => self.visit_heaptype(ht)
    RefCast(_, ht) => self.visit_heaptype(ht)

    // Struct instructions
    StructNew(t) => self.visit_typeidx(t)
    StructNewDefault(t) => self.visit_typeidx(t)
    StructGet(t, _) => self.visit_typeidx(t)
    StructGetS(t, _) => self.visit_typeidx(t)
    StructGetU(t, _) => self.visit_typeidx(t)
    StructSet(t, _) => self.visit_typeidx(t)

    // Array instructions
    ArrayNew(t) => self.visit_typeidx(t)
    ArrayNewDefault(t) => self.visit_typeidx(t)
    ArrayNewFixed(t, _) => self.visit_typeidx(t)
    ArrayNewData(t, d) => {
      self.visit_typeidx(t)
      self.visit_dataidx(d)
    }
    ArrayNewElem(t, e) => {
      self.visit_typeidx(t)
      self.visit_elemidx(e)
    }
    ArrayGet(t) => self.visit_typeidx(t)
    ArrayGetS(t) => self.visit_typeidx(t)
    ArrayGetU(t) => self.visit_typeidx(t)
    ArraySet(t) => self.visit_typeidx(t)
    ArrayFill(t) => self.visit_typeidx(t)
    ArrayCopy(t1, t2) => {
      self.visit_typeidx(t1)
      self.visit_typeidx(t2)
    }
    ArrayInitData(t, d) => {
      self.visit_typeidx(t)
      self.visit_dataidx(d)
    }
    ArrayInitElem(t, e) => {
      self.visit_typeidx(t)
      self.visit_elemidx(e)
    }

    // Exception handling
    Throw(t) => self.visit_tagidx(t)

    // Select with optional types
    Select(types) =>
      match types {
        Some(ts) => ts.each(fn(t) { self.visit_valtype(t) })
        None => ()
      }

    // All other instructions have no children to visit
    _ => ()
  }
}

pub fn ModuleVisitor::visit_catch(self : ModuleVisitor, c : Catch) -> Unit {
  match c {
    Catch(tag, label) => {
      self.visit_tagidx(tag)
      self.visit_labelidx(label)
    }
    CatchRef(tag, label) => {
      self.visit_tagidx(tag)
      self.visit_labelidx(label)
    }
    CatchAll(label) => self.visit_labelidx(label)
    CatchAllRef(label) => self.visit_labelidx(label)
  }
}

pub fn ModuleVisitor::visit_blocktype(self : ModuleVisitor, bt : BlockType) -> Unit {
  match self.visit_blocktype {
    Some(f) => f(bt)
    None => ()
  }
  if self.descend {
    match bt {
      EmptyBlockType => ()
      ValTypeBlockType(vt) => self.visit_valtype(vt)
      TypeIdxBlockType(t) => self.visit_typeidx(t)
    }
  }
}

pub fn ModuleVisitor::visit_valtype(self : ModuleVisitor, vt : ValType) -> Unit {
  match self.visit_valtype {
    Some(f) => f(vt)
    None => ()
  }
  if self.descend {
    match vt {
      RefTypeValType(rt) => self.visit_reftype(rt)
      _ => ()
    }
  }
}

pub fn ModuleVisitor::visit_reftype(self : ModuleVisitor, rt : RefType) -> Unit {
  match self.visit_reftype {
    Some(f) => f(rt)
    None => ()
  }
  if self.descend {
    match rt {
      HeapTypeRefType(_, ht) => self.visit_heaptype(ht)
      AbsHeapTypeRefType(_) => ()
    }
  }
}

pub fn ModuleVisitor::visit_heaptype(self : ModuleVisitor, ht : HeapType) -> Unit {
  match self.visit_heaptype {
    Some(f) => f(ht)
    None => ()
  }
  if self.descend {
    match ht {
      HeapType(t) => self.visit_typeidx(t)
      _ => ()
    }
  }
}

pub fn ModuleVisitor::visit_comptype(self : ModuleVisitor, ct : CompType) -> Unit {
  match self.visit_comptype {
    Some(f) => f(ct)
    None => ()
  }
  if self.descend {
    match ct {
      FuncCompType(params, results) => {
        params.each(fn(t) { self.visit_valtype(t) })
        results.each(fn(t) { self.visit_valtype(t) })
      }
      StructCompType(fields) => fields.each(fn(f) { self.visit_fieldtype(f) })
      ArrayCompType(ft) => self.visit_fieldtype(ft)
    }
  }
}

pub fn ModuleVisitor::visit_subtype(self : ModuleVisitor, st : SubType) -> Unit {
  match self.visit_subtype {
    Some(f) => f(st)
    None => ()
  }
  if self.descend {
    match st {
      SubType(_, supers, ct) => {
        supers.each(fn(t) { self.visit_typeidx(t) })
        self.visit_comptype(ct)
      }
      CompTypeSubType(ct) => self.visit_comptype(ct)
    }
  }
}

pub fn ModuleVisitor::visit_rectype(self : ModuleVisitor, rt : RecType) -> Unit {
  match self.visit_rectype {
    Some(f) => f(rt)
    None => ()
  }
  if self.descend {
    match rt {
      SingleRecType(st) => self.visit_subtype(st)
      GroupRecType(sts) => sts.each(fn(st) { self.visit_subtype(st) })
    }
  }
}

pub fn ModuleVisitor::visit_fieldtype(self : ModuleVisitor, ft : FieldType) -> Unit {
  match self.visit_fieldtype {
    Some(f) => f(ft)
    None => ()
  }
  if self.descend {
    let FieldType(st, _) = ft
    self.visit_storagetype(st)
  }
}

pub fn ModuleVisitor::visit_storagetype(self : ModuleVisitor, st : StorageType) -> Unit {
  match self.visit_storagetype {
    Some(f) => f(st)
    None => ()
  }
  if self.descend {
    match st {
      ValTypeStorageType(vt) => self.visit_valtype(vt)
      PackTypeStorageType(_) => ()
    }
  }
}

pub fn ModuleVisitor::visit_globaltype(self : ModuleVisitor, gt : GlobalType) -> Unit {
  match self.visit_globaltype {
    Some(f) => f(gt)
    None => ()
  }
  if self.descend {
    let GlobalType(vt, _) = gt
    self.visit_valtype(vt)
  }
}

pub fn ModuleVisitor::visit_tabletype(self : ModuleVisitor, tt : TableType) -> Unit {
  match self.visit_tabletype {
    Some(f) => f(tt)
    None => ()
  }
  if self.descend {
    let TableType(rt, _) = tt
    self.visit_reftype(rt)
  }
}

pub fn ModuleVisitor::visit_memtype(self : ModuleVisitor, mt : MemType) -> Unit {
  match self.visit_memtype {
    Some(f) => f(mt)
    None => ()
  }
  // MemType only contains Limits, no nested types to visit
}

pub fn ModuleVisitor::visit_funcidx(self : ModuleVisitor, idx : FuncIdx) -> Unit {
  match self.visit_funcidx {
    Some(f) => f(idx)
    None => ()
  }
}

pub fn ModuleVisitor::visit_typeidx(self : ModuleVisitor, idx : TypeIdx) -> Unit {
  match self.visit_typeidx {
    Some(f) => f(idx)
    None => ()
  }
}

pub fn ModuleVisitor::visit_localidx(self : ModuleVisitor, idx : LocalIdx) -> Unit {
  match self.visit_localidx {
    Some(f) => f(idx)
    None => ()
  }
}

pub fn ModuleVisitor::visit_globalidx(self : ModuleVisitor, idx : GlobalIdx) -> Unit {
  match self.visit_globalidx {
    Some(f) => f(idx)
    None => ()
  }
}

pub fn ModuleVisitor::visit_tableidx(self : ModuleVisitor, idx : TableIdx) -> Unit {
  match self.visit_tableidx {
    Some(f) => f(idx)
    None => ()
  }
}

pub fn ModuleVisitor::visit_memidx(self : ModuleVisitor, idx : MemIdx) -> Unit {
  match self.visit_memidx {
    Some(f) => f(idx)
    None => ()
  }
}

pub fn ModuleVisitor::visit_labelidx(self : ModuleVisitor, idx : LabelIdx) -> Unit {
  match self.visit_labelidx {
    Some(f) => f(idx)
    None => ()
  }
}

pub fn ModuleVisitor::visit_dataidx(self : ModuleVisitor, idx : DataIdx) -> Unit {
  match self.visit_dataidx {
    Some(f) => f(idx)
    None => ()
  }
}

pub fn ModuleVisitor::visit_elemidx(self : ModuleVisitor, idx : ElemIdx) -> Unit {
  match self.visit_elemidx {
    Some(f) => f(idx)
    None => ()
  }
}

pub fn ModuleVisitor::visit_tagidx(self : ModuleVisitor, idx : TagIdx) -> Unit {
  match self.visit_tagidx {
    Some(f) => f(idx)
    None => ()
  }
}

pub fn ModuleVisitor::visit_module(self : ModuleVisitor, mod : Module) -> Unit {
  let Module(
    _custom,
    type_sec,
    import_sec,
    func_sec,
    table_sec,
    mem_sec,
    tag_sec,
    global_sec,
    export_sec,
    _start_sec,
    elem_sec,
    _datacnt_sec,
    code_sec,
    data_sec,
  ) = mod

  match type_sec {
    Some(ts) => self.visit_typesec(ts)
    None => ()
  }
  match import_sec {
    Some(i) => self.visit_importsec(i)
    None => ()
  }
  match func_sec {
    Some(fs) => self.visit_funcsec(fs)
    None => ()
  }
  match table_sec {
    Some(ts) => self.visit_tablesec(ts)
    None => ()
  }
  match mem_sec {
    Some(ms) => self.visit_memsec(ms)
    None => ()
  }
  match tag_sec {
    Some(ts) => self.visit_tagsec(ts)
    None => ()
  }
  match global_sec {
    Some(gs) => self.visit_globalsec(gs)
    None => ()
  }
  match export_sec {
    Some(es) => self.visit_exportsec(es)
    None => ()
  }
  match elem_sec {
    Some(es) => self.visit_elemsec(es)
    None => ()
  }
  match code_sec {
    Some(cs) => self.visit_codesec(cs)
    None => ()
  }
  match data_sec {
    Some(ds) => self.visit_datasec(ds)
    None => ()
  }
}

pub fn ModuleVisitor::visit_typesec(self : ModuleVisitor, ts : TypeSec) -> Unit {
  let TypeSec(rectypes) = ts
  rectypes.each(fn(rt) { self.visit_rectype(rt) })
}

pub fn ModuleVisitor::visit_importsec(self : ModuleVisitor, import_sec : ImportSec) -> Unit {
  let ImportSec(imports) = import_sec
  imports.each(fn(i) { self.visit_import(i) })
}

pub fn ModuleVisitor::visit_import(self : ModuleVisitor, imp : Import) -> Unit {
  match self.visit_import {
    Some(f) => f(imp)
    None => ()
  }
  if self.descend {
    let Import(_, _, extern_type) = imp
    self.visit_externtype(extern_type)
  }
}

pub fn ModuleVisitor::visit_externtype(self : ModuleVisitor, et : ExternType) -> Unit {
  match et {
    FuncExternType(tidx) => self.visit_typeidx(tidx)
    TableExternType(tt) => self.visit_tabletype(tt)
    MemExternType(mt) => self.visit_memtype(mt)
    GlobalExternType(gt) => self.visit_globaltype(gt)
    TagExternType(tt) => {
      let TagType(tidx) = tt
      self.visit_typeidx(tidx)
    }
  }
}

pub fn ModuleVisitor::visit_funcsec(self : ModuleVisitor, fs : FuncSec) -> Unit {
  let FuncSec(type_indices) = fs
  type_indices.each(fn(t) { self.visit_typeidx(t) })
}

pub fn ModuleVisitor::visit_tablesec(self : ModuleVisitor, ts : TableSec) -> Unit {
  let TableSec(tables) = ts
  tables.each(fn(t) { self.visit_table(t) })
}

pub fn ModuleVisitor::visit_table(self : ModuleVisitor, t : Table) -> Unit {
  match self.visit_table {
    Some(f) => f(t)
    None => ()
  }
  if self.descend {
    let Table(tt, init) = t
    self.visit_tabletype(tt)
    match init {
      Some(e) => self.visit_expr(e)
      None => ()
    }
  }
}

pub fn ModuleVisitor::visit_memsec(self : ModuleVisitor, ms : MemSec) -> Unit {
  let MemSec(mems) = ms
  mems.each(fn(m) { self.visit_memtype(m) })
}

pub fn ModuleVisitor::visit_tagsec(self : ModuleVisitor, ts : TagSec) -> Unit {
  let TagSec(tags) = ts
  tags.each(fn(t) {
    let TagType(tidx) = t
    self.visit_typeidx(tidx)
  })
}

pub fn ModuleVisitor::visit_globalsec(self : ModuleVisitor, gs : GlobalSec) -> Unit {
  let GlobalSec(globals) = gs
  globals.each(fn(g) { self.visit_global(g) })
}

pub fn ModuleVisitor::visit_global(self : ModuleVisitor, g : Global) -> Unit {
  match self.visit_global {
    Some(f) => f(g)
    None => ()
  }
  if self.descend {
    let Global(gt, init) = g
    self.visit_globaltype(gt)
    self.visit_expr(init)
  }
}

pub fn ModuleVisitor::visit_exportsec(self : ModuleVisitor, es : ExportSec) -> Unit {
  let ExportSec(exports) = es
  exports.each(fn(e) { self.visit_export(e) })
}

pub fn ModuleVisitor::visit_export(self : ModuleVisitor, exp : Export) -> Unit {
  match self.visit_export {
    Some(f) => f(exp)
    None => ()
  }
  if self.descend {
    let Export(_, idx) = exp
    self.visit_externidx(idx)
  }
}

pub fn ModuleVisitor::visit_externidx(self : ModuleVisitor, idx : ExternIdx) -> Unit {
  match idx {
    FuncExternIdx(f) => self.visit_funcidx(f)
    TableExternIdx(t) => self.visit_tableidx(t)
    MemExternIdx(m) => self.visit_memidx(m)
    GlobalExternIdx(g) => self.visit_globalidx(g)
    TagExternIdx(t) => self.visit_tagidx(t)
  }
}

pub fn ModuleVisitor::visit_elemsec(self : ModuleVisitor, es : ElemSec) -> Unit {
  let ElemSec(elems) = es
  elems.each(fn(e) { self.visit_elem(e) })
}

pub fn ModuleVisitor::visit_elem(self : ModuleVisitor, e : Elem) -> Unit {
  match self.visit_elem {
    Some(f) => f(e)
    None => ()
  }
  if self.descend {
    let Elem(mode, kind) = e
    self.visit_elemmode(mode)
    self.visit_elemkind(kind)
  }
}

pub fn ModuleVisitor::visit_elemmode(self : ModuleVisitor, mode : ElemMode) -> Unit {
  match mode {
    Active(tidx, offset) => {
      self.visit_tableidx(tidx)
      self.visit_expr(offset)
    }
    Passive => ()
    Declarative => ()
  }
}

pub fn ModuleVisitor::visit_elemkind(self : ModuleVisitor, kind : ElemKind) -> Unit {
  match kind {
    FuncsElemKind(idxs) => idxs.each(fn(i) { self.visit_funcidx(i) })
    FuncExprsElemKind(exprs) => exprs.each(fn(e) { self.visit_expr(e) })
    TypedExprsElemKind(rt, exprs) => {
      self.visit_reftype(rt)
      exprs.each(fn(e) { self.visit_expr(e) })
    }
  }
}

pub fn ModuleVisitor::visit_codesec(self : ModuleVisitor, cs : CodeSec) -> Unit {
  let CodeSec(funcs) = cs
  funcs.each(fn(f) { self.visit_func(f) })
}

pub fn ModuleVisitor::visit_func(self : ModuleVisitor, f : Func) -> Unit {
  match self.visit_func {
    Some(cb) => cb(f)
    None => ()
  }
  if self.descend {
    let Func(locals, body) = f
    locals.each(fn(l) {
      let Locals(_, vt) = l
      self.visit_valtype(vt)
    })
    self.visit_expr(body)
  }
}

pub fn ModuleVisitor::visit_datasec(self : ModuleVisitor, ds : DataSec) -> Unit {
  let DataSec(data) = ds
  data.each(fn(d) { self.visit_data(d) })
}

pub fn ModuleVisitor::visit_data(self : ModuleVisitor, d : Data) -> Unit {
  match self.visit_data {
    Some(f) => f(d)
    None => ()
  }
  if self.descend {
    let Data(mode, _) = d
    self.visit_datamode(mode)
  }
}

pub fn ModuleVisitor::visit_datamode(self : ModuleVisitor, mode : DataMode) -> Unit {
  match mode {
    Active(midx, offset) => {
      self.visit_memidx(midx)
      self.visit_expr(offset)
    }
    Passive => ()
  }
}

