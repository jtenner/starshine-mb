///|
// Controls for the proposal slices covered by the Binaryen 132 intake. Other
// established Wasm features retain their existing validation policy.
pub enum ProposalFeature {
  AcquireReleaseAtomics
  RelaxedAtomics
  SharedEverything
  Multibyte
  RelaxedSimd
} derive(Eq, Debug)

///|
pub fn controlled_proposal_features() -> Array[ProposalFeature] {
  [
    AcquireReleaseAtomics,
    RelaxedAtomics,
    SharedEverything,
    Multibyte,
    RelaxedSimd,
  ]
}

///|
pub fn proposal_feature_name(feature : ProposalFeature) -> String {
  match feature {
    AcquireReleaseAtomics => "acquire-release-atomics"
    RelaxedAtomics => "relaxed-atomics"
    SharedEverything => "shared-everything"
    Multibyte => "multibyte"
    RelaxedSimd => "relaxed-simd"
  }
}

///|
pub fn proposal_feature_by_name(name : String) -> ProposalFeature? {
  for feature in controlled_proposal_features() {
    if proposal_feature_name(feature) == name {
      return Some(feature)
    }
  }
  None
}

///|
fn proposal_note(
  out : Array[ProposalFeature],
  feature : ProposalFeature,
) -> Unit {
  if !out.contains(feature) {
    out.push(feature)
  }
}

///|
fn proposal_heap(out : Array[ProposalFeature], heap : HeapType) -> Unit {
  match heap {
    SharedAbsHeapTypeHeapType(_)
    | AbsHeapTypeHeapType(WaitqueueAbsHeapType)
    | AbsHeapTypeHeapType(NoWaitqueueAbsHeapType) =>
      proposal_note(out, SharedEverything)
    DefTypeHeapType(DefType(rec, _)) => proposal_rec_type(out, rec)
    _ => ()
  }
}

///|
fn proposal_value(out : Array[ProposalFeature], value : ValType) -> Unit {
  if value is RefTypeValType(ref_type) {
    proposal_heap(out, ref_type.get_heap_type())
  }
}

///|
fn proposal_field(out : Array[ProposalFeature], field : FieldType) -> Unit {
  let FieldType(storage, _) = field
  if storage is ValTypeStorageType(value) {
    proposal_value(out, value)
  }
}

///|
fn proposal_rec_type(out : Array[ProposalFeature], rec : RecType) -> Unit {
  let subtypes = match rec {
    SingleRecType(subtype) => [subtype]
    GroupRecType(subtypes) => subtypes
  }
  for subtype in subtypes {
    if subtype.metadata().is_shared() {
      proposal_note(out, SharedEverything)
    }
    match subtype.get_comptype() {
      FuncCompType(params, results) => {
        for value in params {
          proposal_value(out, value)
        }
        for value in results {
          proposal_value(out, value)
        }
      }
      ArrayCompType(field) => proposal_field(out, field)
      StructCompType(fields) =>
        for field in fields {
          proposal_field(out, field)
        }
      _ => ()
    }
  }
}

///|
fn proposal_block_type(out : Array[ProposalFeature], block : BlockType) -> Unit {
  if block is ValTypeBlockType(value) {
    proposal_value(out, value)
  }
}

///|
fn proposal_instruction(
  out : Array[ProposalFeature],
  instruction : Instruction,
  work : Array[Array[Instruction]],
) -> Unit {
  let order = match instruction {
    AtomicFence(order)
    | I32AtomicLoad(order, _)
    | I64AtomicLoad(order, _)
    | I32AtomicLoad8U(order, _)
    | I32AtomicLoad16U(order, _)
    | I64AtomicLoad8U(order, _)
    | I64AtomicLoad16U(order, _)
    | I64AtomicLoad32U(order, _)
    | I32AtomicStore(order, _)
    | I64AtomicStore(order, _)
    | I32AtomicStore8(order, _)
    | I32AtomicStore16(order, _)
    | I64AtomicStore8(order, _)
    | I64AtomicStore16(order, _)
    | I64AtomicStore32(order, _)
    | AtomicRmw(order, _, _)
    | AtomicCmpxchg(order, _, _)
    | StructAtomicSet(order, _, _)
    | ArrayAtomicSet(order, _)
    | StructAtomicGet(order, _, _)
    | StructAtomicGetS(order, _, _)
    | StructAtomicGetU(order, _, _)
    | StructAtomicRmw(order, _, _, _)
    | StructAtomicCmpxchg(order, _, _)
    | ArrayAtomicGet(order, _)
    | ArrayAtomicGetS(order, _)
    | ArrayAtomicGetU(order, _)
    | ArrayAtomicRmw(order, _, _)
    | ArrayAtomicCmpxchg(order, _) => Some(order)
    _ => None
  }
  match order {
    Some(AcqRel) => proposal_note(out, AcquireReleaseAtomics)
    Some(Relaxed) => proposal_note(out, RelaxedAtomics)
    _ => ()
  }
  match instruction {
    StructAtomicSet(_, _, _)
    | ArrayAtomicSet(_, _)
    | StructAtomicGet(_, _, _)
    | StructAtomicGetS(_, _, _)
    | StructAtomicGetU(_, _, _)
    | StructAtomicRmw(_, _, _, _)
    | StructAtomicCmpxchg(_, _, _)
    | ArrayAtomicGet(_, _)
    | ArrayAtomicGetS(_, _)
    | ArrayAtomicGetU(_, _)
    | ArrayAtomicRmw(_, _, _)
    | ArrayAtomicCmpxchg(_, _)
    | WaitqueueNew
    | WaitqueueNotify
    | StructWait(_, _) => proposal_note(out, SharedEverything)
    Publish => proposal_note(out, SharedEverything)
    RefI31Shared => proposal_note(out, SharedEverything)
    ArrayLoad(_, _, _) | ArrayStore(_, _, _) => proposal_note(out, Multibyte)
    I8x16RelaxedSwizzle
    | I32x4RelaxedTruncF32x4S
    | I32x4RelaxedTruncF32x4U
    | I32x4RelaxedTruncZeroF64x2S
    | I32x4RelaxedTruncZeroF64x2U
    | F32x4RelaxedMadd
    | F32x4RelaxedNmadd
    | F64x2RelaxedMadd
    | F64x2RelaxedNmadd
    | I8x16RelaxedLaneselect
    | I16x8RelaxedLaneselect
    | I32x4RelaxedLaneselect
    | I64x2RelaxedLaneselect
    | F32x4RelaxedMin
    | F32x4RelaxedMax
    | F64x2RelaxedMin
    | F64x2RelaxedMax
    | I16x8RelaxedQ15mulrS
    | I16x8RelaxedDotI8x16I7x16S
    | I32x4RelaxedDotI8x16I7x16AddS => proposal_note(out, RelaxedSimd)
    Block(block_type, Expr(body))
    | Loop(block_type, Expr(body))
    | TryTable(block_type, _, Expr(body)) => {
      proposal_block_type(out, block_type)
      work.push(body)
    }
    If(block_type, yes, no) => {
      proposal_block_type(out, block_type)
      work.push(yes)
      if no is Some(no) {
        work.push(no)
      }
    }
    Try(block_type, Expr(body), catches, _) => {
      proposal_block_type(out, block_type)
      work.push(body)
      for catch_ in catches {
        match catch_ {
          LegacyCatch(_, Expr(body)) | LegacyCatchAll(Expr(body)) =>
            work.push(body)
        }
      }
    }
    RefNull(ref_type) => proposal_heap(out, ref_type.get_heap_type())
    RefTest(_, _, heap)
    | RefCast(_, _, heap)
    | RefTestDesc(_, heap)
    | RefCastDescEq(_, _, heap) => proposal_heap(out, heap)
    BrOnCast(_, _, source, target) | BrOnCastFail(_, _, source, target) => {
      proposal_heap(out, source)
      proposal_heap(out, target)
    }
    BrOnCastDescEq(_, source, target) | BrOnCastDescEqFail(_, source, target) => {
      proposal_heap(out, source.get_heap_type())
      proposal_heap(out, target.get_heap_type())
    }
    Select(Some(values)) =>
      for value in values {
        proposal_value(out, value)
      }
    _ => ()
  }
}

///|
// Infer requirements from all declarations and expression regions, including
// initializers and unreachable code. Stable order is independent of traversal.
pub fn module_proposal_features(module_ : Module) -> Array[ProposalFeature] {
  let out : Array[ProposalFeature] = []
  let work : Array[Array[Instruction]] = []
  if module_.type_sec is Some(TypeSec(groups)) {
    for rec in groups {
      proposal_rec_type(out, rec)
    }
  }
  if module_.import_sec is Some(ImportSec(imports)) {
    for import_ in imports {
      let Import(_, _, kind) = import_
      match kind {
        GlobalExternType(GlobalType(value, _)) => proposal_value(out, value)
        TableExternType(TableType(ref_type, _)) =>
          proposal_heap(out, ref_type.get_heap_type())
        _ => ()
      }
    }
  }
  if module_.global_sec is Some(GlobalSec(globals)) {
    for global_ in globals {
      let Global(GlobalType(value, _), Expr(body)) = global_
      proposal_value(out, value)
      work.push(body)
    }
  }
  if module_.table_sec is Some(TableSec(tables)) {
    for table in tables {
      let Table(TableType(ref_type, _), initial) = table
      proposal_heap(out, ref_type.get_heap_type())
      if initial is Some(Expr(body)) {
        work.push(body)
      }
    }
  }
  if module_.elem_sec is Some(ElemSec(elements)) {
    for element in elements {
      let Elem(mode, kind) = element
      if mode is Active(_, Expr(body)) {
        work.push(body)
      }
      match kind {
        FuncsElemKind(_) => ()
        FuncExprsElemKind(expressions) =>
          for expression in expressions {
            let Expr(body) = expression
            work.push(body)
          }
        TypedExprsElemKind(ref_type, expressions) => {
          proposal_heap(out, ref_type.get_heap_type())
          for expression in expressions {
            let Expr(body) = expression
            work.push(body)
          }
        }
      }
    }
  }
  if module_.data_sec is Some(DataSec(data)) {
    for item in data {
      let Data(mode, _) = item
      if mode is Active(_, Expr(body)) {
        work.push(body)
      }
    }
  }
  if module_.code_sec is Some(CodeSec(bodies)) {
    for func in bodies {
      let Func(locals, Expr(body)) = func
      for run in locals.runs {
        proposal_value(out, run.vt)
      }
      work.push(body)
    }
  }
  while !work.is_empty() {
    for instruction in work.pop().unwrap() {
      proposal_instruction(out, instruction, work)
    }
  }
  controlled_proposal_features().filter(fn(feature) { out.contains(feature) })
}
