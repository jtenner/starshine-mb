// Shared type-index rewrite helpers used by the standalone RUME package.
// Keep these functions synchronized with duplicate_function_elimination.mbt.

///|
fn dfe_rewrite_type_idx(
  idx : @lib.TypeIdx,
  remap : Map[UInt, UInt],
) -> @lib.TypeIdx {
  match idx {
    @lib.TypeIdx(raw) => @lib.TypeIdx::new(remap.get(raw).unwrap_or(raw))
    @lib.RecIdx(_) => idx
  }
}

///|
fn dfe_try_rewrite_type_idx(
  idx : @lib.TypeIdx,
  remap : Map[UInt, UInt],
) -> @lib.TypeIdx? {
  match idx {
    @lib.TypeIdx(raw) =>
      match remap.get(raw) {
        Some(next) =>
          if next != raw {
            Some(@lib.TypeIdx::new(next))
          } else {
            None
          }
        None => None
      }
    @lib.RecIdx(_) => None
  }
}

///|
fn dfe_type_idx_is_remapped(
  idx : @lib.TypeIdx,
  remap : Map[UInt, UInt],
) -> Bool {
  match idx {
    @lib.TypeIdx(raw) => remap.get(raw) != None
    @lib.RecIdx(_) => false
  }
}

///|
fn dfe_type_metadata_uses_remap(
  metadata : @lib.TypeMetadata,
  remap : Map[UInt, UInt],
) -> Bool {
  let { describes, descriptor, .. } = metadata
  match describes {
    Some(idx) => if dfe_type_idx_is_remapped(idx, remap) { return true }
    None => ()
  }
  match descriptor {
    Some(idx) => dfe_type_idx_is_remapped(idx, remap)
    None => false
  }
}

///|
fn dfe_heap_type_uses_remap(
  heap_type : @lib.HeapType,
  remap : Map[UInt, UInt],
) -> Bool {
  match heap_type {
    @lib.AbsHeapTypeHeapType(_) | @lib.SharedAbsHeapTypeHeapType(_) => false
    @lib.HeapType(type_idx) => dfe_type_idx_is_remapped(type_idx, remap)
    @lib.DefTypeHeapType(@lib.DefType(rec_type, _)) =>
      dfe_rec_type_uses_remap(rec_type, remap)
  }
}

///|
fn dfe_ref_type_uses_remap(
  ref_type : @lib.RefType,
  remap : Map[UInt, UInt],
) -> Bool {
  match ref_type {
    @lib.HeapTypeRefType(_, _, heap_type) =>
      dfe_heap_type_uses_remap(heap_type, remap)
    @lib.AbsHeapTypeRefType(_) => false
  }
}

///|
fn dfe_val_type_uses_remap(
  val_type : @lib.ValType,
  remap : Map[UInt, UInt],
) -> Bool {
  match val_type {
    @lib.RefTypeValType(ref_type) => dfe_ref_type_uses_remap(ref_type, remap)
    _ => false
  }
}

///|
fn dfe_storage_type_uses_remap(
  storage_type : @lib.StorageType,
  remap : Map[UInt, UInt],
) -> Bool {
  match storage_type {
    @lib.ValTypeStorageType(val_type) =>
      dfe_val_type_uses_remap(val_type, remap)
    @lib.PackTypeStorageType(_) => false
  }
}

///|
fn dfe_field_type_uses_remap(
  field_type : @lib.FieldType,
  remap : Map[UInt, UInt],
) -> Bool {
  let @lib.FieldType(storage_type, _) = field_type
  dfe_storage_type_uses_remap(storage_type, remap)
}

///|
fn dfe_field_types_use_remap(
  field_types : Array[@lib.FieldType],
  remap : Map[UInt, UInt],
) -> Bool {
  let mut idx = 0
  while idx < field_types.length() {
    if dfe_field_type_uses_remap(field_types[idx], remap) {
      return true
    }
    idx += 1
  }
  false
}

///|
fn dfe_val_types_use_remap(
  val_types : Array[@lib.ValType],
  remap : Map[UInt, UInt],
) -> Bool {
  let mut idx = 0
  while idx < val_types.length() {
    if dfe_val_type_uses_remap(val_types[idx], remap) {
      return true
    }
    idx += 1
  }
  false
}

///|
fn dfe_comp_type_uses_remap(
  comp_type : @lib.CompType,
  remap : Map[UInt, UInt],
) -> Bool {
  match comp_type {
    @lib.ArrayCompType(field_type) =>
      dfe_field_type_uses_remap(field_type, remap)
    @lib.StructCompType(field_types) =>
      dfe_field_types_use_remap(field_types, remap)
    @lib.FuncCompType(params, results) =>
      dfe_val_types_use_remap(params, remap) ||
      dfe_val_types_use_remap(results, remap)
    @lib.ContCompType(func_type) => dfe_type_idx_is_remapped(func_type, remap)
  }
}

///|
fn dfe_type_idxs_use_remap(
  type_idxs : Array[@lib.TypeIdx],
  remap : Map[UInt, UInt],
) -> Bool {
  let mut idx = 0
  while idx < type_idxs.length() {
    if dfe_type_idx_is_remapped(type_idxs[idx], remap) {
      return true
    }
    idx += 1
  }
  false
}

///|
fn dfe_sub_type_uses_remap(
  subtype : @lib.SubType,
  remap : Map[UInt, UInt],
) -> Bool {
  match subtype {
    @lib.SubType(_, supers, metadata, comp_type) =>
      dfe_type_idxs_use_remap(supers, remap) ||
      dfe_type_metadata_uses_remap(metadata, remap) ||
      dfe_comp_type_uses_remap(comp_type, remap)
    @lib.CompTypeSubType(metadata, comp_type) =>
      dfe_type_metadata_uses_remap(metadata, remap) ||
      dfe_comp_type_uses_remap(comp_type, remap)
  }
}

///|
fn dfe_sub_types_use_remap(
  subtypes : Array[@lib.SubType],
  remap : Map[UInt, UInt],
) -> Bool {
  let mut idx = 0
  while idx < subtypes.length() {
    if dfe_sub_type_uses_remap(subtypes[idx], remap) {
      return true
    }
    idx += 1
  }
  false
}

///|
fn dfe_rec_type_uses_remap(
  rec_type : @lib.RecType,
  remap : Map[UInt, UInt],
) -> Bool {
  match rec_type {
    @lib.SingleRecType(subtype) => dfe_sub_type_uses_remap(subtype, remap)
    @lib.GroupRecType(subtypes) => dfe_sub_types_use_remap(subtypes, remap)
  }
}

///|
fn dfe_rewrite_type_metadata(
  metadata : @lib.TypeMetadata,
  remap : Map[UInt, UInt],
) -> @lib.TypeMetadata {
  let { describes, descriptor, shared, } = metadata
  @lib.TypeMetadata::new(
    describes=match describes {
      Some(idx) => Some(dfe_rewrite_type_idx(idx, remap))
      None => None
    },
    descriptor=match descriptor {
      Some(idx) => Some(dfe_rewrite_type_idx(idx, remap))
      None => None
    },
    shared~,
  )
}

///|
fn dfe_rewrite_heap_type(
  heap_type : @lib.HeapType,
  remap : Map[UInt, UInt],
) -> @lib.HeapType {
  match heap_type {
    @lib.AbsHeapTypeHeapType(_) | @lib.SharedAbsHeapTypeHeapType(_) => heap_type
    @lib.HeapType(type_idx) =>
      @lib.HeapType::new(dfe_rewrite_type_idx(type_idx, remap))
    @lib.DefTypeHeapType(@lib.DefType(rec_type, idx)) =>
      @lib.HeapType::def_type(
        @lib.DefType::new(dfe_rewrite_rec_type(rec_type, remap), idx),
      )
  }
}

///|
fn dfe_rewrite_ref_type(
  ref_type : @lib.RefType,
  remap : Map[UInt, UInt],
) -> @lib.RefType {
  match ref_type {
    @lib.HeapTypeRefType(nullable, exact, heap_type) =>
      @lib.RefType::new(
        nullable,
        dfe_rewrite_heap_type(heap_type, remap),
        exact~,
      )
    @lib.AbsHeapTypeRefType(_) => ref_type
  }
}

///|
fn dfe_try_rewrite_heap_type(
  heap_type : @lib.HeapType,
  remap : Map[UInt, UInt],
) -> @lib.HeapType? {
  if dfe_heap_type_uses_remap(heap_type, remap) {
    Some(dfe_rewrite_heap_type(heap_type, remap))
  } else {
    None
  }
}

///|
fn dfe_try_rewrite_ref_type(
  ref_type : @lib.RefType,
  remap : Map[UInt, UInt],
) -> @lib.RefType? {
  if dfe_ref_type_uses_remap(ref_type, remap) {
    Some(dfe_rewrite_ref_type(ref_type, remap))
  } else {
    None
  }
}

///|
fn dfe_rewrite_val_type(
  val_type : @lib.ValType,
  remap : Map[UInt, UInt],
) -> @lib.ValType {
  match val_type {
    @lib.RefTypeValType(ref_type) =>
      @lib.ValType::ref_type(dfe_rewrite_ref_type(ref_type, remap))
    _ => val_type
  }
}

///|
fn dfe_try_rewrite_val_type(
  val_type : @lib.ValType,
  remap : Map[UInt, UInt],
) -> @lib.ValType? {
  if dfe_val_type_uses_remap(val_type, remap) {
    Some(dfe_rewrite_val_type(val_type, remap))
  } else {
    None
  }
}

///|
fn dfe_try_rewrite_val_types(
  val_types : Array[@lib.ValType],
  remap : Map[UInt, UInt],
) -> Array[@lib.ValType]? {
  let rewritten : Array[@lib.ValType] = Array::new(capacity=val_types.length())
  let mut changed = false
  let mut idx = 0
  while idx < val_types.length() {
    let val_type = val_types[idx]
    match dfe_try_rewrite_val_type(val_type, remap) {
      Some(next) => {
        if !changed {
          let mut prefix = 0
          while prefix < idx {
            rewritten.push(val_types[prefix])
            prefix += 1
          }
          changed = true
        }
        rewritten.push(next)
      }
      None => if changed { rewritten.push(val_type) }
    }
    idx += 1
  }
  if changed {
    Some(rewritten)
  } else {
    None
  }
}

///|
fn dfe_rewrite_storage_type(
  storage_type : @lib.StorageType,
  remap : Map[UInt, UInt],
) -> @lib.StorageType {
  match storage_type {
    @lib.ValTypeStorageType(val_type) =>
      @lib.StorageType::val_type(dfe_rewrite_val_type(val_type, remap))
    @lib.PackTypeStorageType(_) => storage_type
  }
}

///|
fn dfe_rewrite_field_type(
  field_type : @lib.FieldType,
  remap : Map[UInt, UInt],
) -> @lib.FieldType {
  let @lib.FieldType(storage_type, mutability) = field_type
  @lib.FieldType::new(dfe_rewrite_storage_type(storage_type, remap), mutability)
}

///|
fn dfe_rewrite_result_type(
  values : Array[@lib.ValType],
  remap : Map[UInt, UInt],
) -> Array[@lib.ValType] {
  let rewritten : Array[@lib.ValType] = []
  for value in values {
    rewritten.push(dfe_rewrite_val_type(value, remap))
  }
  rewritten
}

///|
fn dfe_rewrite_comp_type(
  comp_type : @lib.CompType,
  remap : Map[UInt, UInt],
) -> @lib.CompType {
  match comp_type {
    @lib.ArrayCompType(field_type) =>
      @lib.CompType::array(dfe_rewrite_field_type(field_type, remap))
    @lib.StructCompType(field_types) => {
      let rewritten : Array[@lib.FieldType] = []
      for field_type in field_types {
        rewritten.push(dfe_rewrite_field_type(field_type, remap))
      }
      @lib.CompType::struct_(rewritten)
    }
    @lib.FuncCompType(params, results) =>
      @lib.CompType::func(
        dfe_rewrite_result_type(params, remap),
        dfe_rewrite_result_type(results, remap),
      )
    @lib.ContCompType(func_type) =>
      @lib.CompType::cont(dfe_rewrite_type_idx(func_type, remap))
  }
}

///|
fn dfe_rewrite_sub_type(
  subtype : @lib.SubType,
  remap : Map[UInt, UInt],
) -> @lib.SubType {
  match subtype {
    @lib.SubType(is_final, supers, metadata, comp_type) => {
      let rewritten_supers : Array[@lib.TypeIdx] = []
      for super_type in supers {
        rewritten_supers.push(dfe_rewrite_type_idx(super_type, remap))
      }
      @lib.SubType::new(
        is_final,
        rewritten_supers,
        dfe_rewrite_comp_type(comp_type, remap),
        metadata=dfe_rewrite_type_metadata(metadata, remap),
      )
    }
    @lib.CompTypeSubType(metadata, comp_type) =>
      @lib.SubType::comp_type(
        dfe_rewrite_comp_type(comp_type, remap),
        metadata=dfe_rewrite_type_metadata(metadata, remap),
      )
  }
}

///|
fn dfe_rewrite_rec_type(
  rec_type : @lib.RecType,
  remap : Map[UInt, UInt],
) -> @lib.RecType {
  match rec_type {
    @lib.SingleRecType(subtype) =>
      @lib.RecType::new(dfe_rewrite_sub_type(subtype, remap))
    @lib.GroupRecType(subtypes) => {
      let rewritten : Array[@lib.SubType] = []
      for subtype in subtypes {
        rewritten.push(dfe_rewrite_sub_type(subtype, remap))
      }
      @lib.RecType::group(rewritten)
    }
  }
}

///|
fn dfe_rewrite_block_type(
  block_type : @lib.BlockType,
  remap : Map[UInt, UInt],
) -> @lib.BlockType {
  match block_type {
    @lib.ValTypeBlockType(val_type) =>
      @lib.BlockType::val_type(dfe_rewrite_val_type(val_type, remap))
    @lib.TypeIdxBlockType(type_idx) =>
      @lib.BlockType::type_idx(dfe_rewrite_type_idx(type_idx, remap))
    _ => block_type
  }
}

///|
fn dfe_try_rewrite_block_type(
  block_type : @lib.BlockType,
  remap : Map[UInt, UInt],
) -> @lib.BlockType? {
  match block_type {
    @lib.ValTypeBlockType(val_type) =>
      match dfe_try_rewrite_val_type(val_type, remap) {
        Some(next) => Some(@lib.BlockType::val_type(next))
        None => None
      }
    @lib.TypeIdxBlockType(type_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) => Some(@lib.BlockType::type_idx(next))
        None => None
      }
    _ => None
  }
}

///|
fn dfe_try_rewrite_instruction_array_type_idxs(
  instrs : Array[@lib.Instruction],
  remap : Map[UInt, UInt],
) -> Array[@lib.Instruction]? {
  let rewritten : Array[@lib.Instruction] = Array::new(capacity=instrs.length())
  let mut changed = false
  let mut idx = 0
  while idx < instrs.length() {
    let instr = instrs[idx]
    match dfe_try_rewrite_instruction_type_idxs(instr, remap) {
      Some(next) => {
        if !changed {
          let mut prefix = 0
          while prefix < idx {
            rewritten.push(instrs[prefix])
            prefix += 1
          }
          changed = true
        }
        rewritten.push(next)
      }
      None => if changed { rewritten.push(instr) }
    }
    idx += 1
  }
  if changed {
    Some(rewritten)
  } else {
    None
  }
}

///|
fn dfe_try_rewrite_expr_type_idxs(
  expr : @lib.Expr,
  remap : Map[UInt, UInt],
) -> @lib.Expr? {
  let @lib.Expr(instrs) = expr
  match dfe_try_rewrite_instruction_array_type_idxs(instrs, remap) {
    Some(rewritten) => Some(@lib.Expr::new(rewritten))
    None => None
  }
}

///|
fn dfe_try_rewrite_locals_type_idxs(
  locals : @lib.Locals,
  remap : Map[UInt, UInt],
) -> @lib.Locals? {
  let runs = locals.runs()
  let rewritten : Array[@lib.LocalRun] = Array::new(capacity=runs.length())
  let mut changed = false
  let mut idx = 0
  while idx < runs.length() {
    let run = runs[idx]
    match dfe_try_rewrite_val_type(run.val_type(), remap) {
      Some(next) => {
        if !changed {
          let mut prefix = 0
          while prefix < idx {
            rewritten.push(runs[prefix])
            prefix += 1
          }
          changed = true
        }
        rewritten.push(@lib.LocalRun::new(run.count(), next))
      }
      None => if changed { rewritten.push(run) }
    }
    idx += 1
  }
  if changed {
    Some(@lib.Locals::new(rewritten))
  } else {
    None
  }
}

///|
fn dfe_try_rewrite_func_type_idxs(
  func : @lib.Func,
  remap : Map[UInt, UInt],
) -> @lib.Func? {
  let @lib.Func(locals, body) = func
  let rewritten_locals = dfe_try_rewrite_locals_type_idxs(locals, remap)
  let rewritten_body = dfe_try_rewrite_expr_type_idxs(body, remap)
  if rewritten_locals is None && rewritten_body is None {
    None
  } else {
    let next_locals = match rewritten_locals {
      Some(next) => next
      None => locals
    }
    let next_body = match rewritten_body {
      Some(next) => next
      None => body
    }
    Some(@lib.Func::new(next_locals, next_body))
  }
}

///|
fn dfe_rewrite_instruction_type_idxs(
  instr : @lib.Instruction,
  remap : Map[UInt, UInt],
) -> @lib.Instruction {
  match instr {
    @lib.Block(block_type, expr) =>
      @lib.Instruction::block(
        dfe_rewrite_block_type(block_type, remap),
        dfe_rewrite_expr_type_idxs(expr, remap),
      )
    @lib.Loop(block_type, expr) =>
      @lib.Instruction::loop_(
        dfe_rewrite_block_type(block_type, remap),
        dfe_rewrite_expr_type_idxs(expr, remap),
      )
    @lib.If(block_type, then_body, else_body) => {
      let rewritten_then : Array[@lib.Instruction] = []
      for nested in then_body {
        rewritten_then.push(dfe_rewrite_instruction_type_idxs(nested, remap))
      }
      let rewritten_else = match else_body {
        Some(body) => {
          let rewritten : Array[@lib.Instruction] = []
          for nested in body {
            rewritten.push(dfe_rewrite_instruction_type_idxs(nested, remap))
          }
          Some(rewritten)
        }
        None => None
      }
      @lib.Instruction::if_(
        dfe_rewrite_block_type(block_type, remap),
        rewritten_then,
        rewritten_else,
      )
    }
    @lib.CallIndirect(type_idx, table_idx) =>
      @lib.Instruction::call_indirect(
        dfe_rewrite_type_idx(type_idx, remap),
        table_idx,
      )
    @lib.ReturnCallIndirect(type_idx, table_idx) =>
      @lib.Instruction::return_call_indirect(
        dfe_rewrite_type_idx(type_idx, remap),
        table_idx,
      )
    @lib.CallRef(type_idx) =>
      @lib.Instruction::call_ref(dfe_rewrite_type_idx(type_idx, remap))
    @lib.ReturnCallRef(type_idx) =>
      @lib.Instruction::return_call_ref(dfe_rewrite_type_idx(type_idx, remap))
    @lib.Select(Some(types)) =>
      @lib.Instruction::select(
        types=Some(
          types.map(fn(val_type) { dfe_rewrite_val_type(val_type, remap) }),
        ),
      )
    @lib.TryTable(block_type, catches, body) =>
      @lib.Instruction::try_table(
        dfe_rewrite_block_type(block_type, remap),
        catches,
        dfe_rewrite_expr_type_idxs(body, remap),
      )
    @lib.RefNull(ref_type) =>
      @lib.Instruction::ref_null_type(dfe_rewrite_ref_type(ref_type, remap))
    @lib.StructNew(type_idx) =>
      @lib.Instruction::struct_new(dfe_rewrite_type_idx(type_idx, remap))
    @lib.StructNewDefault(type_idx) =>
      @lib.Instruction::struct_new_default(
        dfe_rewrite_type_idx(type_idx, remap),
      )
    @lib.StructNewDesc(type_idx) =>
      @lib.Instruction::struct_new_desc(dfe_rewrite_type_idx(type_idx, remap))
    @lib.StructNewDefaultDesc(type_idx) =>
      @lib.Instruction::struct_new_default_desc(
        dfe_rewrite_type_idx(type_idx, remap),
      )
    @lib.StructGet(type_idx, field_idx) =>
      @lib.Instruction::struct_get(
        dfe_rewrite_type_idx(type_idx, remap),
        field_idx,
      )
    @lib.StructGetS(type_idx, field_idx) =>
      @lib.Instruction::struct_get_s(
        dfe_rewrite_type_idx(type_idx, remap),
        field_idx,
      )
    @lib.StructGetU(type_idx, field_idx) =>
      @lib.Instruction::struct_get_u(
        dfe_rewrite_type_idx(type_idx, remap),
        field_idx,
      )
    @lib.StructAtomicGet(order, type_idx, field_idx) =>
      @lib.Instruction::struct_atomic_get(
        order,
        dfe_rewrite_type_idx(type_idx, remap),
        field_idx,
      )
    @lib.StructAtomicGetS(order, type_idx, field_idx) =>
      @lib.Instruction::struct_atomic_get_s(
        order,
        dfe_rewrite_type_idx(type_idx, remap),
        field_idx,
      )
    @lib.StructAtomicGetU(order, type_idx, field_idx) =>
      @lib.Instruction::struct_atomic_get_u(
        order,
        dfe_rewrite_type_idx(type_idx, remap),
        field_idx,
      )
    @lib.StructSet(type_idx, field_idx) =>
      @lib.Instruction::struct_set(
        dfe_rewrite_type_idx(type_idx, remap),
        field_idx,
      )
    @lib.ArrayNew(type_idx) =>
      @lib.Instruction::array_new(dfe_rewrite_type_idx(type_idx, remap))
    @lib.ArrayNewDefault(type_idx) =>
      @lib.Instruction::array_new_default(dfe_rewrite_type_idx(type_idx, remap))
    @lib.ArrayNewFixed(type_idx, len) =>
      @lib.Instruction::array_new_fixed(
        dfe_rewrite_type_idx(type_idx, remap),
        len,
      )
    @lib.ArrayNewData(type_idx, data_idx) =>
      @lib.Instruction::array_new_data(
        dfe_rewrite_type_idx(type_idx, remap),
        data_idx,
      )
    @lib.ArrayNewElem(type_idx, elem_idx) =>
      @lib.Instruction::array_new_elem(
        dfe_rewrite_type_idx(type_idx, remap),
        elem_idx,
      )
    @lib.ArrayGet(type_idx) =>
      @lib.Instruction::array_get(dfe_rewrite_type_idx(type_idx, remap))
    @lib.ArrayGetS(type_idx) =>
      @lib.Instruction::array_get_s(dfe_rewrite_type_idx(type_idx, remap))
    @lib.ArrayGetU(type_idx) =>
      @lib.Instruction::array_get_u(dfe_rewrite_type_idx(type_idx, remap))
    @lib.ArraySet(type_idx) =>
      @lib.Instruction::array_set(dfe_rewrite_type_idx(type_idx, remap))
    @lib.ArrayFill(type_idx) =>
      @lib.Instruction::array_fill(dfe_rewrite_type_idx(type_idx, remap))
    @lib.ArrayCopy(src_type, dst_type) =>
      @lib.Instruction::array_copy(
        dfe_rewrite_type_idx(src_type, remap),
        dfe_rewrite_type_idx(dst_type, remap),
      )
    @lib.ArrayInitData(type_idx, data_idx) =>
      @lib.Instruction::array_init_data(
        dfe_rewrite_type_idx(type_idx, remap),
        data_idx,
      )
    @lib.ArrayInitElem(type_idx, elem_idx) =>
      @lib.Instruction::array_init_elem(
        dfe_rewrite_type_idx(type_idx, remap),
        elem_idx,
      )
    @lib.RefGetDesc(type_idx) =>
      @lib.Instruction::ref_get_desc(dfe_rewrite_type_idx(type_idx, remap))
    @lib.RefTest(nullable, exact, heap_type) =>
      @lib.Instruction::ref_test_type(
        @lib.RefType::new(
          nullable,
          dfe_rewrite_heap_type(heap_type, remap),
          exact~,
        ),
      )
    @lib.RefCast(nullable, exact, heap_type) =>
      @lib.Instruction::ref_cast_type(
        @lib.RefType::new(
          nullable,
          dfe_rewrite_heap_type(heap_type, remap),
          exact~,
        ),
      )
    @lib.RefTestDesc(nullable, heap_type) =>
      @lib.Instruction::ref_test_desc(
        nullable,
        dfe_rewrite_heap_type(heap_type, remap),
      )
    @lib.RefCastDescEq(nullable, exact, heap_type) =>
      @lib.Instruction::ref_cast_desc_eq_type(
        @lib.RefType::new(
          nullable,
          dfe_rewrite_heap_type(heap_type, remap),
          exact~,
        ),
      )
    @lib.BrOnCast(label_idx, cast_op, source, target) =>
      @lib.Instruction::br_on_cast(
        label_idx,
        cast_op.source_nullable(),
        dfe_rewrite_heap_type(source, remap),
        cast_op.target_nullable(),
        dfe_rewrite_heap_type(target, remap),
      )
    @lib.BrOnCastFail(label_idx, cast_op, source, target) =>
      @lib.Instruction::br_on_cast_fail(
        label_idx,
        cast_op.source_nullable(),
        dfe_rewrite_heap_type(source, remap),
        cast_op.target_nullable(),
        dfe_rewrite_heap_type(target, remap),
      )
    _ => instr
  }
}

///|
fn dfe_try_rewrite_instruction_type_idxs(
  instr : @lib.Instruction,
  remap : Map[UInt, UInt],
) -> @lib.Instruction? {
  match instr {
    @lib.Block(block_type, expr) => {
      let rewritten_block_type = dfe_try_rewrite_block_type(block_type, remap)
      let rewritten_expr = dfe_try_rewrite_expr_type_idxs(expr, remap)
      if rewritten_block_type is None && rewritten_expr is None {
        None
      } else {
        let next_block_type = match rewritten_block_type {
          Some(next) => next
          None => block_type
        }
        let next_expr = match rewritten_expr {
          Some(next) => next
          None => expr
        }
        Some(@lib.Instruction::block(next_block_type, next_expr))
      }
    }
    @lib.Loop(block_type, expr) => {
      let rewritten_block_type = dfe_try_rewrite_block_type(block_type, remap)
      let rewritten_expr = dfe_try_rewrite_expr_type_idxs(expr, remap)
      if rewritten_block_type is None && rewritten_expr is None {
        None
      } else {
        let next_block_type = match rewritten_block_type {
          Some(next) => next
          None => block_type
        }
        let next_expr = match rewritten_expr {
          Some(next) => next
          None => expr
        }
        Some(@lib.Instruction::loop_(next_block_type, next_expr))
      }
    }
    @lib.If(block_type, then_body, else_body) => {
      let rewritten_block_type = dfe_try_rewrite_block_type(block_type, remap)
      let rewritten_then = dfe_try_rewrite_instruction_array_type_idxs(
        then_body, remap,
      )
      let rewritten_else = match else_body {
        Some(body) =>
          match dfe_try_rewrite_instruction_array_type_idxs(body, remap) {
            Some(next) => Some(Some(next))
            None => None
          }
        None => None
      }
      if rewritten_block_type is None &&
        rewritten_then is None &&
        rewritten_else is None {
        None
      } else {
        let next_block_type = match rewritten_block_type {
          Some(next) => next
          None => block_type
        }
        let next_then = match rewritten_then {
          Some(next) => next
          None => then_body
        }
        let next_else = match rewritten_else {
          Some(next) => next
          None => else_body
        }
        Some(@lib.Instruction::if_(next_block_type, next_then, next_else))
      }
    }
    @lib.CallIndirect(type_idx, table_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) => Some(@lib.Instruction::call_indirect(next, table_idx))
        None => None
      }
    @lib.ReturnCallIndirect(type_idx, table_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) =>
          Some(@lib.Instruction::return_call_indirect(next, table_idx))
        None => None
      }
    @lib.CallRef(type_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) => Some(@lib.Instruction::call_ref(next))
        None => None
      }
    @lib.ReturnCallRef(type_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) => Some(@lib.Instruction::return_call_ref(next))
        None => None
      }
    @lib.Select(Some(types)) =>
      match dfe_try_rewrite_val_types(types, remap) {
        Some(next) => Some(@lib.Instruction::select(types=Some(next)))
        None => None
      }
    @lib.TryTable(block_type, catches, body) => {
      let rewritten_block_type = dfe_try_rewrite_block_type(block_type, remap)
      let rewritten_body = dfe_try_rewrite_expr_type_idxs(body, remap)
      if rewritten_block_type is None && rewritten_body is None {
        None
      } else {
        let next_block_type = match rewritten_block_type {
          Some(next) => next
          None => block_type
        }
        let next_body = match rewritten_body {
          Some(next) => next
          None => body
        }
        Some(@lib.Instruction::try_table(next_block_type, catches, next_body))
      }
    }
    @lib.RefNull(ref_type) =>
      match dfe_try_rewrite_ref_type(ref_type, remap) {
        Some(next) => Some(@lib.Instruction::ref_null_type(next))
        None => None
      }
    @lib.StructNew(type_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) => Some(@lib.Instruction::struct_new(next))
        None => None
      }
    @lib.StructNewDefault(type_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) => Some(@lib.Instruction::struct_new_default(next))
        None => None
      }
    @lib.StructNewDesc(type_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) => Some(@lib.Instruction::struct_new_desc(next))
        None => None
      }
    @lib.StructNewDefaultDesc(type_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) => Some(@lib.Instruction::struct_new_default_desc(next))
        None => None
      }
    @lib.StructGet(type_idx, field_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) => Some(@lib.Instruction::struct_get(next, field_idx))
        None => None
      }
    @lib.StructGetS(type_idx, field_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) => Some(@lib.Instruction::struct_get_s(next, field_idx))
        None => None
      }
    @lib.StructGetU(type_idx, field_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) => Some(@lib.Instruction::struct_get_u(next, field_idx))
        None => None
      }
    @lib.StructAtomicGet(order, type_idx, field_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) =>
          Some(@lib.Instruction::struct_atomic_get(order, next, field_idx))
        None => None
      }
    @lib.StructAtomicGetS(order, type_idx, field_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) =>
          Some(@lib.Instruction::struct_atomic_get_s(order, next, field_idx))
        None => None
      }
    @lib.StructAtomicGetU(order, type_idx, field_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) =>
          Some(@lib.Instruction::struct_atomic_get_u(order, next, field_idx))
        None => None
      }
    @lib.StructSet(type_idx, field_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) => Some(@lib.Instruction::struct_set(next, field_idx))
        None => None
      }
    @lib.ArrayNew(type_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) => Some(@lib.Instruction::array_new(next))
        None => None
      }
    @lib.ArrayNewDefault(type_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) => Some(@lib.Instruction::array_new_default(next))
        None => None
      }
    @lib.ArrayNewFixed(type_idx, len) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) => Some(@lib.Instruction::array_new_fixed(next, len))
        None => None
      }
    @lib.ArrayNewData(type_idx, data_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) => Some(@lib.Instruction::array_new_data(next, data_idx))
        None => None
      }
    @lib.ArrayNewElem(type_idx, elem_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) => Some(@lib.Instruction::array_new_elem(next, elem_idx))
        None => None
      }
    @lib.ArrayGet(type_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) => Some(@lib.Instruction::array_get(next))
        None => None
      }
    @lib.ArrayGetS(type_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) => Some(@lib.Instruction::array_get_s(next))
        None => None
      }
    @lib.ArrayGetU(type_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) => Some(@lib.Instruction::array_get_u(next))
        None => None
      }
    @lib.ArraySet(type_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) => Some(@lib.Instruction::array_set(next))
        None => None
      }
    @lib.ArrayFill(type_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) => Some(@lib.Instruction::array_fill(next))
        None => None
      }
    @lib.ArrayCopy(src_type, dst_type) =>
      match
        (
          dfe_try_rewrite_type_idx(src_type, remap),
          dfe_try_rewrite_type_idx(dst_type, remap),
        ) {
        (Some(next_src), Some(next_dst)) =>
          Some(@lib.Instruction::array_copy(next_src, next_dst))
        (Some(next_src), None) =>
          Some(@lib.Instruction::array_copy(next_src, dst_type))
        (None, Some(next_dst)) =>
          Some(@lib.Instruction::array_copy(src_type, next_dst))
        (None, None) => None
      }
    @lib.ArrayInitData(type_idx, data_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) => Some(@lib.Instruction::array_init_data(next, data_idx))
        None => None
      }
    @lib.ArrayInitElem(type_idx, elem_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) => Some(@lib.Instruction::array_init_elem(next, elem_idx))
        None => None
      }
    @lib.RefGetDesc(type_idx) =>
      match dfe_try_rewrite_type_idx(type_idx, remap) {
        Some(next) => Some(@lib.Instruction::ref_get_desc(next))
        None => None
      }
    @lib.RefTest(nullable, exact, heap_type) =>
      match dfe_try_rewrite_heap_type(heap_type, remap) {
        Some(next) =>
          Some(
            @lib.Instruction::ref_test_type(
              @lib.RefType::new(nullable, next, exact~),
            ),
          )
        None => None
      }
    @lib.RefCast(nullable, exact, heap_type) =>
      match dfe_try_rewrite_heap_type(heap_type, remap) {
        Some(next) =>
          Some(
            @lib.Instruction::ref_cast_type(
              @lib.RefType::new(nullable, next, exact~),
            ),
          )
        None => None
      }
    @lib.RefTestDesc(nullable, heap_type) =>
      match dfe_try_rewrite_heap_type(heap_type, remap) {
        Some(next) => Some(@lib.Instruction::ref_test_desc(nullable, next))
        None => None
      }
    @lib.RefCastDescEq(nullable, exact, heap_type) =>
      match dfe_try_rewrite_heap_type(heap_type, remap) {
        Some(next) =>
          Some(
            @lib.Instruction::ref_cast_desc_eq_type(
              @lib.RefType::new(nullable, next, exact~),
            ),
          )
        None => None
      }
    @lib.BrOnCast(label_idx, cast_op, source, target) =>
      match
        (
          dfe_try_rewrite_heap_type(source, remap),
          dfe_try_rewrite_heap_type(target, remap),
        ) {
        (Some(next_source), Some(next_target)) =>
          Some(
            @lib.Instruction::br_on_cast(
              label_idx,
              cast_op.source_nullable(),
              next_source,
              cast_op.target_nullable(),
              next_target,
            ),
          )
        (Some(next_source), None) =>
          Some(
            @lib.Instruction::br_on_cast(
              label_idx,
              cast_op.source_nullable(),
              next_source,
              cast_op.target_nullable(),
              target,
            ),
          )
        (None, Some(next_target)) =>
          Some(
            @lib.Instruction::br_on_cast(
              label_idx,
              cast_op.source_nullable(),
              source,
              cast_op.target_nullable(),
              next_target,
            ),
          )
        (None, None) => None
      }
    @lib.BrOnCastFail(label_idx, cast_op, source, target) =>
      match
        (
          dfe_try_rewrite_heap_type(source, remap),
          dfe_try_rewrite_heap_type(target, remap),
        ) {
        (Some(next_source), Some(next_target)) =>
          Some(
            @lib.Instruction::br_on_cast_fail(
              label_idx,
              cast_op.source_nullable(),
              next_source,
              cast_op.target_nullable(),
              next_target,
            ),
          )
        (Some(next_source), None) =>
          Some(
            @lib.Instruction::br_on_cast_fail(
              label_idx,
              cast_op.source_nullable(),
              next_source,
              cast_op.target_nullable(),
              target,
            ),
          )
        (None, Some(next_target)) =>
          Some(
            @lib.Instruction::br_on_cast_fail(
              label_idx,
              cast_op.source_nullable(),
              source,
              cast_op.target_nullable(),
              next_target,
            ),
          )
        (None, None) => None
      }
    _ => None
  }
}

///|
fn dfe_rewrite_expr_type_idxs(
  expr : @lib.Expr,
  remap : Map[UInt, UInt],
) -> @lib.Expr {
  let @lib.Expr(instrs) = expr
  let rewritten : Array[@lib.Instruction] = Array::new(capacity=instrs.length())
  for instr in instrs {
    rewritten.push(dfe_rewrite_instruction_type_idxs(instr, remap))
  }
  @lib.Expr::new(rewritten)
}

///|
fn _dfe_rewrite_locals_type_idxs(
  locals : @lib.Locals,
  remap : Map[UInt, UInt],
) -> @lib.Locals {
  let runs = locals.runs()
  let rewritten : Array[@lib.LocalRun] = Array::new(capacity=runs.length())
  for run in runs {
    rewritten.push(
      @lib.LocalRun::new(
        run.count(),
        dfe_rewrite_val_type(run.val_type(), remap),
      ),
    )
  }
  @lib.Locals::new(rewritten)
}

///|
fn dfe_rewrite_extern_type(
  extern_type : @lib.ExternType,
  remap : Map[UInt, UInt],
) -> @lib.ExternType {
  match extern_type {
    @lib.FuncExternType(type_idx) =>
      @lib.ExternType::func(dfe_rewrite_type_idx(type_idx, remap))
    @lib.TableExternType(table_type) => {
      let @lib.TableType(ref_type, limits) = table_type
      @lib.ExternType::table(
        @lib.TableType::new(dfe_rewrite_ref_type(ref_type, remap), limits),
      )
    }
    @lib.MemExternType(_) => extern_type
    @lib.GlobalExternType(@lib.GlobalType(val_type, mutable_)) =>
      @lib.ExternType::global(
        @lib.GlobalType::new(dfe_rewrite_val_type(val_type, remap), mutable_),
      )
    @lib.TagExternType(@lib.TagType(type_idx)) =>
      @lib.ExternType::tag(
        @lib.TagType::new(dfe_rewrite_type_idx(type_idx, remap)),
      )
  }
}

///|
fn dfe_rewrite_import_type_idxs(
  import_ : @lib.Import,
  remap : Map[UInt, UInt],
) -> @lib.Import {
  let @lib.Import(module_name, field_name, extern_type) = import_
  @lib.Import::new(
    module_name,
    field_name,
    dfe_rewrite_extern_type(extern_type, remap),
  )
}

///|
fn dfe_rewrite_table_type_idxs(
  table : @lib.Table,
  remap : Map[UInt, UInt],
) -> @lib.Table {
  let @lib.Table(@lib.TableType(ref_type, limits), init) = table
  @lib.Table::new(
    @lib.TableType::new(dfe_rewrite_ref_type(ref_type, remap), limits),
    match init {
      Some(expr) => Some(dfe_rewrite_expr_type_idxs(expr, remap))
      None => None
    },
  )
}

///|
fn dfe_rewrite_global_type_idxs(
  global : @lib.Global,
  remap : Map[UInt, UInt],
) -> @lib.Global {
  let @lib.Global(@lib.GlobalType(val_type, mutable_), expr) = global
  @lib.Global::new(
    @lib.GlobalType::new(dfe_rewrite_val_type(val_type, remap), mutable_),
    dfe_rewrite_expr_type_idxs(expr, remap),
  )
}

///|
fn dfe_rewrite_elem_mode_type_idxs(
  mode : @lib.ElemMode,
  remap : Map[UInt, UInt],
) -> @lib.ElemMode {
  match mode {
    @lib.Active(table_idx, expr) =>
      @lib.ElemMode::active(table_idx, dfe_rewrite_expr_type_idxs(expr, remap))
    _ => mode
  }
}

///|
fn dfe_rewrite_elem_kind_type_idxs(
  kind : @lib.ElemKind,
  remap : Map[UInt, UInt],
) -> @lib.ElemKind {
  match kind {
    @lib.FuncsElemKind(_) => kind
    @lib.FuncExprsElemKind(exprs) => {
      let rewritten : Array[@lib.Expr] = []
      for expr in exprs {
        rewritten.push(dfe_rewrite_expr_type_idxs(expr, remap))
      }
      @lib.ElemKind::func_exprs(rewritten)
    }
    @lib.TypedExprsElemKind(ref_type, exprs) => {
      let rewritten : Array[@lib.Expr] = []
      for expr in exprs {
        rewritten.push(dfe_rewrite_expr_type_idxs(expr, remap))
      }
      @lib.ElemKind::typed_exprs(
        dfe_rewrite_ref_type(ref_type, remap),
        rewritten,
      )
    }
  }
}

///|
fn dfe_rewrite_elem_type_idxs(
  elem : @lib.Elem,
  remap : Map[UInt, UInt],
) -> @lib.Elem {
  let @lib.Elem(mode, kind) = elem
  @lib.Elem::new(
    dfe_rewrite_elem_mode_type_idxs(mode, remap),
    dfe_rewrite_elem_kind_type_idxs(kind, remap),
  )
}

///|
fn dfe_rewrite_data_mode_type_idxs(
  mode : @lib.DataMode,
  remap : Map[UInt, UInt],
) -> @lib.DataMode {
  match mode {
    @lib.Active(mem_idx, expr) =>
      @lib.DataMode::active(mem_idx, dfe_rewrite_expr_type_idxs(expr, remap))
    @lib.Passive => mode
  }
}

///|
fn dfe_rewrite_data_type_idxs(
  data : @lib.Data,
  remap : Map[UInt, UInt],
) -> @lib.Data {
  let @lib.Data(mode, bytes) = data
  @lib.Data::new(dfe_rewrite_data_mode_type_idxs(mode, remap), bytes)
}

///|

///|
fn dfe_rewrite_module_type_idxs(
  mod_ : @lib.Module,
  remap : Map[UInt, UInt],
) -> @lib.Module {
  let mut rewritten = mod_
  match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) => {
      let next : Array[@lib.RecType] = []
      for rec_type in rec_types {
        next.push(dfe_rewrite_rec_type(rec_type, remap))
      }
      rewritten = rewritten.with_type_sec(@lib.TypeSec::new(next))
    }
    None => ()
  }
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) => {
      let next : Array[@lib.Import] = []
      for import_ in imports {
        next.push(dfe_rewrite_import_type_idxs(import_, remap))
      }
      rewritten = rewritten.with_import_sec(@lib.ImportSec::new(next))
    }
    None => ()
  }
  match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => {
      let next : Array[@lib.TypeIdx] = []
      for type_idx in type_idxs {
        next.push(dfe_rewrite_type_idx(type_idx, remap))
      }
      rewritten = rewritten.with_func_sec(@lib.FuncSec::new(next))
    }
    None => ()
  }
  match mod_.table_sec {
    Some(@lib.TableSec(tables)) => {
      let next : Array[@lib.Table] = []
      for table in tables {
        next.push(dfe_rewrite_table_type_idxs(table, remap))
      }
      rewritten = rewritten.with_table_sec(@lib.TableSec::new(next))
    }
    None => ()
  }
  match mod_.tag_sec {
    Some(@lib.TagSec(tags)) => {
      let next : Array[@lib.TagType] = []
      for tag in tags {
        let @lib.TagType(type_idx) = tag
        next.push(@lib.TagType::new(dfe_rewrite_type_idx(type_idx, remap)))
      }
      rewritten = rewritten.with_tag_sec(@lib.TagSec::new(next))
    }
    None => ()
  }
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) => {
      let next : Array[@lib.Global] = []
      for global in globals {
        next.push(dfe_rewrite_global_type_idxs(global, remap))
      }
      rewritten = rewritten.with_global_sec(@lib.GlobalSec::new(next))
    }
    None => ()
  }
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) => {
      let next : Array[@lib.Elem] = []
      for elem in elems {
        next.push(dfe_rewrite_elem_type_idxs(elem, remap))
      }
      rewritten = rewritten.with_elem_sec(@lib.ElemSec::new(next))
    }
    None => ()
  }
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let next : Array[@lib.Func] = []
      for func in funcs {
        match dfe_try_rewrite_func_type_idxs(func, remap) {
          Some(rewritten_func) => next.push(rewritten_func)
          None => next.push(func)
        }
      }
      rewritten = rewritten.with_code_sec(@lib.CodeSec::new(next))
    }
    None => ()
  }
  match mod_.data_sec {
    Some(@lib.DataSec(datas)) => {
      let next : Array[@lib.Data] = []
      for data in datas {
        next.push(dfe_rewrite_data_type_idxs(data, remap))
      }
      rewritten = rewritten.with_data_sec(@lib.DataSec::new(next))
    }
    None => ()
  }
  rewritten
}
