///|
priv struct GenValidProposalFloorFacts {
  has_descriptors : Bool
  has_continuations : Bool
  has_waitqueues : Bool
  has_array_memory : Bool
  has_linear_atomics : Bool
}

///|
fn GenValidProposalFloorFacts::empty() -> GenValidProposalFloorFacts {
  {
    has_descriptors: false,
    has_continuations: false,
    has_waitqueues: false,
    has_array_memory: false,
    has_linear_atomics: false,
  }
}

///|
fn GenValidProposalFloorFacts::merge(
  self : GenValidProposalFloorFacts,
  other : GenValidProposalFloorFacts,
) -> GenValidProposalFloorFacts {
  {
    has_descriptors: self.has_descriptors || other.has_descriptors,
    has_continuations: self.has_continuations || other.has_continuations,
    has_waitqueues: self.has_waitqueues || other.has_waitqueues,
    has_array_memory: self.has_array_memory || other.has_array_memory,
    has_linear_atomics: self.has_linear_atomics || other.has_linear_atomics,
  }
}

///|
fn gen_valid_proposal_floor_heap(heap : HeapType) -> GenValidProposalFloorFacts {
  match heap {
    AbsHeapTypeHeapType(ContAbsHeapType)
    | AbsHeapTypeHeapType(NoContAbsHeapType)
    | SharedAbsHeapTypeHeapType(ContAbsHeapType)
    | SharedAbsHeapTypeHeapType(NoContAbsHeapType) =>
      GenValidProposalFloorFacts::{
        ..GenValidProposalFloorFacts::empty(),
        has_continuations: true,
      }
    AbsHeapTypeHeapType(WaitqueueAbsHeapType)
    | AbsHeapTypeHeapType(NoWaitqueueAbsHeapType)
    | SharedAbsHeapTypeHeapType(WaitqueueAbsHeapType)
    | SharedAbsHeapTypeHeapType(NoWaitqueueAbsHeapType) =>
      GenValidProposalFloorFacts::{
        ..GenValidProposalFloorFacts::empty(),
        has_waitqueues: true,
      }
    DefTypeHeapType(DefType(rec_type, _)) =>
      gen_valid_proposal_floor_rec_type(rec_type)
    _ => GenValidProposalFloorFacts::empty()
  }
}

///|
fn gen_valid_proposal_floor_value(
  value : ValType,
) -> GenValidProposalFloorFacts {
  match value {
    RefTypeValType(ref_type) =>
      gen_valid_proposal_floor_heap(ref_type.get_heap_type())
    _ => GenValidProposalFloorFacts::empty()
  }
}

///|
fn gen_valid_proposal_floor_field(
  field : FieldType,
) -> GenValidProposalFloorFacts {
  let FieldType(storage, _) = field
  match storage {
    ValTypeStorageType(value) => gen_valid_proposal_floor_value(value)
    PackTypeStorageType(_) => GenValidProposalFloorFacts::empty()
  }
}

///|
fn gen_valid_proposal_floor_comp_type(
  comp_type : CompType,
) -> GenValidProposalFloorFacts {
  match comp_type {
    ContCompType(_) =>
      GenValidProposalFloorFacts::{
        ..GenValidProposalFloorFacts::empty(),
        has_continuations: true,
      }
    FuncCompType(params, results) => {
      let mut facts = GenValidProposalFloorFacts::empty()
      for value in params {
        facts = facts.merge(gen_valid_proposal_floor_value(value))
      }
      for value in results {
        facts = facts.merge(gen_valid_proposal_floor_value(value))
      }
      facts
    }
    StructCompType(fields) => {
      let mut facts = GenValidProposalFloorFacts::empty()
      for field in fields {
        facts = facts.merge(gen_valid_proposal_floor_field(field))
      }
      facts
    }
    ArrayCompType(field) => gen_valid_proposal_floor_field(field)
  }
}

///|
fn gen_valid_proposal_floor_sub_type(
  subtype : SubType,
) -> GenValidProposalFloorFacts {
  gen_valid_proposal_floor_comp_type(subtype.get_comptype())
}

///|
fn gen_valid_proposal_floor_rec_type(
  rec_type : RecType,
) -> GenValidProposalFloorFacts {
  let mut facts = GenValidProposalFloorFacts::empty()
  match rec_type {
    SingleRecType(subtype) =>
      facts = facts.merge(gen_valid_proposal_floor_sub_type(subtype))
    GroupRecType(subtypes) =>
      for subtype in subtypes {
        facts = facts.merge(gen_valid_proposal_floor_sub_type(subtype))
      }
  }
  facts
}

///|
fn gen_valid_proposal_floor_block_type(
  block_type : BlockType,
) -> GenValidProposalFloorFacts {
  match block_type {
    ValTypeBlockType(value) => gen_valid_proposal_floor_value(value)
    _ => GenValidProposalFloorFacts::empty()
  }
}

///|
fn gen_valid_proposal_floor_instruction(
  instruction : Instruction,
  work : Array[Array[Instruction]],
) -> GenValidProposalFloorFacts {
  match instruction {
    ContNew(_)
    | ContBind(_, _)
    | Suspend(_)
    | Resume(_, _)
    | ResumeThrow(_, _, _)
    | ResumeThrowRef(_, _)
    | StackSwitch(_, _) =>
      GenValidProposalFloorFacts::{
        ..GenValidProposalFloorFacts::empty(),
        has_continuations: true,
      }
    WaitqueueNew | WaitqueueNotify | StructWait(_, _) =>
      GenValidProposalFloorFacts::{
        ..GenValidProposalFloorFacts::empty(),
        has_waitqueues: true,
      }
    ArrayLoad(_, _, _) | ArrayStore(_, _, _) =>
      GenValidProposalFloorFacts::{
        ..GenValidProposalFloorFacts::empty(),
        has_array_memory: true,
      }
    MemoryAtomicNotify(_)
    | MemoryAtomicWait32(_)
    | MemoryAtomicWait64(_)
    | AtomicFence(_)
    | I32AtomicLoad(_, _)
    | I64AtomicLoad(_, _)
    | I32AtomicLoad8U(_, _)
    | I32AtomicLoad16U(_, _)
    | I64AtomicLoad8U(_, _)
    | I64AtomicLoad16U(_, _)
    | I64AtomicLoad32U(_, _)
    | I32AtomicStore(_, _)
    | I64AtomicStore(_, _)
    | I32AtomicStore8(_, _)
    | I32AtomicStore16(_, _)
    | I64AtomicStore8(_, _)
    | I64AtomicStore16(_, _)
    | I64AtomicStore32(_, _)
    | AtomicRmw(_, _, _)
    | AtomicCmpxchg(_, _, _) =>
      GenValidProposalFloorFacts::{
        ..GenValidProposalFloorFacts::empty(),
        has_linear_atomics: true,
      }
    Block(block_type, Expr(body))
    | Loop(block_type, Expr(body))
    | TryTable(block_type, _, Expr(body)) => {
      work.push(body)
      gen_valid_proposal_floor_block_type(block_type)
    }
    If(block_type, then_body, else_body) => {
      work.push(then_body)
      if else_body is Some(body) {
        work.push(body)
      }
      gen_valid_proposal_floor_block_type(block_type)
    }
    Try(block_type, Expr(body), catches, _) => {
      work.push(body)
      for catch_ in catches {
        match catch_ {
          LegacyCatch(_, Expr(catch_body)) | LegacyCatchAll(Expr(catch_body)) =>
            work.push(catch_body)
        }
      }
      gen_valid_proposal_floor_block_type(block_type)
    }
    RefNull(ref_type) => gen_valid_proposal_floor_heap(ref_type.get_heap_type())
    RefTest(_, _, heap)
    | RefCast(_, _, heap)
    | RefTestDesc(_, heap)
    | RefCastDescEq(_, _, heap) => gen_valid_proposal_floor_heap(heap)
    BrOnCast(_, _, source, target) | BrOnCastFail(_, _, source, target) =>
      gen_valid_proposal_floor_heap(source).merge(
        gen_valid_proposal_floor_heap(target),
      )
    BrOnCastDescEq(_, source, target) | BrOnCastDescEqFail(_, source, target) =>
      gen_valid_proposal_floor_heap(source.get_heap_type()).merge(
        gen_valid_proposal_floor_heap(target.get_heap_type()),
      )
    Select(Some(values)) => {
      let mut facts = GenValidProposalFloorFacts::empty()
      for value in values {
        facts = facts.merge(gen_valid_proposal_floor_value(value))
      }
      facts
    }
    _ => GenValidProposalFloorFacts::empty()
  }
}

///|
fn gen_valid_proposal_floor_facts(mod_ : Module) -> GenValidProposalFloorFacts {
  let mut facts = GenValidProposalFloorFacts::{
    ..GenValidProposalFloorFacts::empty(),
    has_descriptors: @lib.module_uses_custom_descriptors(mod_),
  }
  let work : Array[Array[Instruction]] = []
  if mod_.type_sec is Some(TypeSec(groups)) {
    for group in groups {
      facts = facts.merge(gen_valid_proposal_floor_rec_type(group))
    }
  }
  if mod_.import_sec is Some(ImportSec(imports)) {
    for import_ in imports {
      let Import(_, _, kind) = import_
      match kind {
        GlobalExternType(GlobalType(value, _)) =>
          facts = facts.merge(gen_valid_proposal_floor_value(value))
        TableExternType(TableType(ref_type, _)) =>
          facts = facts.merge(
            gen_valid_proposal_floor_heap(ref_type.get_heap_type()),
          )
        _ => ()
      }
    }
  }
  if mod_.global_sec is Some(GlobalSec(globals)) {
    for global_ in globals {
      let Global(GlobalType(value, _), Expr(body)) = global_
      facts = facts.merge(gen_valid_proposal_floor_value(value))
      work.push(body)
    }
  }
  if mod_.table_sec is Some(TableSec(tables)) {
    for table in tables {
      let Table(TableType(ref_type, _), initializer) = table
      facts = facts.merge(
        gen_valid_proposal_floor_heap(ref_type.get_heap_type()),
      )
      if initializer is Some(Expr(body)) {
        work.push(body)
      }
    }
  }
  if mod_.elem_sec is Some(ElemSec(elements)) {
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
          facts = facts.merge(
            gen_valid_proposal_floor_heap(ref_type.get_heap_type()),
          )
          for expression in expressions {
            let Expr(body) = expression
            work.push(body)
          }
        }
      }
    }
  }
  if mod_.data_sec is Some(DataSec(segments)) {
    for segment in segments {
      let Data(mode, _) = segment
      if mode is Active(_, Expr(body)) {
        work.push(body)
      }
    }
  }
  if mod_.code_sec is Some(CodeSec(funcs)) {
    for func in funcs {
      let Func(locals, Expr(body)) = func
      for run in locals.runs() {
        facts = facts.merge(gen_valid_proposal_floor_value(run.vt))
      }
      work.push(body)
    }
  }
  while !work.is_empty() {
    for instruction in work.pop().unwrap() {
      facts = facts.merge(
        gen_valid_proposal_floor_instruction(instruction, work),
      )
    }
  }
  facts
}
