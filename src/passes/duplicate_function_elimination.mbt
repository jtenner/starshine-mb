///|
pub fn dfe_summary() -> String {
  "Merge duplicate defined functions, rewrite surviving function references, and compact duplicate simple function type indices."
}

///|
fn dfe_imported_func_count(mod_ : @lib.Module) -> Int {
  let mut count = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn dfe_func_annotation_map(
  mod_ : @lib.Module,
) -> Map[UInt, Array[@lib.FuncAnnotation]] {
  let by_idx : Map[UInt, Array[@lib.FuncAnnotation]] = {}
  match mod_.func_annotation_sec {
    Some(@lib.FuncAnnotationSec(entries)) =>
      for entry in entries {
        let @lib.FuncAnnotationAssoc(entry_idx, annotations) = entry
        by_idx[entry_idx] = annotations
      }
    None => ()
  }
  by_idx
}

///|
fn dfe_func_annotations(
  by_idx : Map[UInt, Array[@lib.FuncAnnotation]],
  abs_idx : UInt,
) -> Array[@lib.FuncAnnotation] {
  by_idx.get(abs_idx).unwrap_or([])
}

///|
fn dfe_ref_type_is_nullable_funcref(ref_type : @lib.RefType) -> Bool {
  ref_type == @lib.RefType::abs(@lib.AbsHeapType::func()) ||
  ref_type ==
  @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func()))
}

///|
fn dfe_compactable_elem_expr_func_idx(expr : @lib.Expr) -> @lib.FuncIdx? {
  match expr {
    @lib.Expr([@lib.RefFunc(func_idx)]) => Some(func_idx)
    _ => None
  }
}

///|
fn dfe_canonicalize_elem_kind(kind : @lib.ElemKind) -> @lib.ElemKind {
  match kind {
    @lib.FuncsElemKind(_) => kind
    @lib.FuncExprsElemKind(exprs) => {
      let funcs : Array[@lib.FuncIdx] = []
      for expr in exprs {
        match dfe_compactable_elem_expr_func_idx(expr) {
          Some(func_idx) => funcs.push(func_idx)
          None => return kind
        }
      }
      @lib.ElemKind::funcs(funcs)
    }
    @lib.TypedExprsElemKind(ref_type, exprs) => {
      if !dfe_ref_type_is_nullable_funcref(ref_type) {
        return kind
      }
      let funcs : Array[@lib.FuncIdx] = []
      for expr in exprs {
        match dfe_compactable_elem_expr_func_idx(expr) {
          Some(func_idx) => funcs.push(func_idx)
          None => return kind
        }
      }
      @lib.ElemKind::funcs(funcs)
    }
  }
}

///|
fn dfe_canonicalize_elem_segments(mod_ : @lib.Module) -> @lib.Module {
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) => {
      let next : Array[@lib.Elem] = []
      let mut changed = false
      for elem in elems {
        let @lib.Elem(mode, kind) = elem
        let rewritten_kind = dfe_canonicalize_elem_kind(kind)
        if rewritten_kind != kind {
          changed = true
        }
        next.push(@lib.Elem::new(mode, rewritten_kind))
      }
      if changed {
        mod_.with_elem_sec(@lib.ElemSec::new(next))
      } else {
        mod_
      }
    }
    None => mod_
  }
}

///|
fn dfe_supports_simple_type_dedup(rec_types : Array[@lib.RecType]) -> Bool {
  for rec_type in rec_types {
    match rec_type {
      @lib.SingleRecType(subtype) => {
        if subtype.super_types().length() > 0 ||
          subtype.describes_type() is Some(_) ||
          subtype.descriptor_type() is Some(_) {
          return false
        }
        match subtype.get_comptype() {
          @lib.FuncCompType(_, _) => ()
          _ => return false
        }
      }
      @lib.GroupRecType(_) => return false
    }
  }
  true
}

///|
fn dfe_duplicate_simple_type_canonical_map(
  rec_types : Array[@lib.RecType],
) -> Map[UInt, UInt] {
  let canonical_map : Map[UInt, UInt] = {}
  if !dfe_supports_simple_type_dedup(rec_types) {
    return canonical_map
  }
  let buckets : @hashmap.HashMap[Int, Array[Int]] = @hashmap.new(
    capacity=rec_types.length(),
  )
  let mut old_idx = 0
  while old_idx < rec_types.length() {
    let rec_type = rec_types[old_idx]
    let mut canonical_old_idx : UInt? = None
    let hash_key = rec_type.hash()
    match buckets.get(hash_key) {
      Some(bucket) => {
        let mut bucket_idx = 0
        while bucket_idx < bucket.length() {
          let prev_idx = bucket[bucket_idx]
          if rec_types[prev_idx] == rec_type {
            canonical_old_idx = Some(prev_idx.reinterpret_as_uint())
            break
          }
          bucket_idx += 1
        }
        if canonical_old_idx is None {
          bucket.push(old_idx)
        }
      }
      None => buckets.set(hash_key, [old_idx])
    }
    match canonical_old_idx {
      Some(canonical_old_idx) =>
        canonical_map[old_idx.reinterpret_as_uint()] = canonical_old_idx
      None => ()
    }
    old_idx += 1
  }
  canonical_map
}

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
  let { describes, descriptor } = metadata
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
    @lib.AbsHeapTypeHeapType(_) => false
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
fn dfe_comp_type_uses_remap(
  comp_type : @lib.CompType,
  remap : Map[UInt, UInt],
) -> Bool {
  match comp_type {
    @lib.ArrayCompType(field_type) =>
      dfe_field_type_uses_remap(field_type, remap)
    @lib.StructCompType(field_types) =>
      field_types.any(fn(field_type) {
        dfe_field_type_uses_remap(field_type, remap)
      })
    @lib.FuncCompType(params, results) =>
      params.any(fn(val_type) { dfe_val_type_uses_remap(val_type, remap) }) ||
      results.any(fn(val_type) { dfe_val_type_uses_remap(val_type, remap) })
  }
}

///|
fn dfe_sub_type_uses_remap(
  subtype : @lib.SubType,
  remap : Map[UInt, UInt],
) -> Bool {
  match subtype {
    @lib.SubType(_, supers, metadata, comp_type) =>
      supers.any(fn(idx) { dfe_type_idx_is_remapped(idx, remap) }) ||
      dfe_type_metadata_uses_remap(metadata, remap) ||
      dfe_comp_type_uses_remap(comp_type, remap)
    @lib.CompTypeSubType(metadata, comp_type) =>
      dfe_type_metadata_uses_remap(metadata, remap) ||
      dfe_comp_type_uses_remap(comp_type, remap)
  }
}

///|
fn dfe_rec_type_uses_remap(
  rec_type : @lib.RecType,
  remap : Map[UInt, UInt],
) -> Bool {
  match rec_type {
    @lib.SingleRecType(subtype) => dfe_sub_type_uses_remap(subtype, remap)
    @lib.GroupRecType(subtypes) =>
      subtypes.any(fn(subtype) { dfe_sub_type_uses_remap(subtype, remap) })
  }
}

///|
fn dfe_rewrite_type_metadata(
  metadata : @lib.TypeMetadata,
  remap : Map[UInt, UInt],
) -> @lib.TypeMetadata {
  let { describes, descriptor } = metadata
  @lib.TypeMetadata::new(
    describes=match describes {
      Some(idx) => Some(dfe_rewrite_type_idx(idx, remap))
      None => None
    },
    descriptor=match descriptor {
      Some(idx) => Some(dfe_rewrite_type_idx(idx, remap))
      None => None
    },
  )
}

///|
fn dfe_rewrite_heap_type(
  heap_type : @lib.HeapType,
  remap : Map[UInt, UInt],
) -> @lib.HeapType {
  match heap_type {
    @lib.AbsHeapTypeHeapType(_) => heap_type
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
    @lib.TypeIdxBlockType(type_idx) =>
      @lib.BlockType::type_idx(dfe_rewrite_type_idx(type_idx, remap))
    _ => block_type
  }
}

///|
fn dfe_block_type_uses_remap(
  block_type : @lib.BlockType,
  remap : Map[UInt, UInt],
) -> Bool {
  match block_type {
    @lib.TypeIdxBlockType(type_idx) => dfe_type_idx_is_remapped(type_idx, remap)
    _ => false
  }
}

///|
fn dfe_instruction_uses_type_idxs(
  instr : @lib.Instruction,
  remap : Map[UInt, UInt],
) -> Bool {
  match instr {
    @lib.Block(block_type, expr) =>
      dfe_block_type_uses_remap(block_type, remap) ||
      dfe_expr_uses_type_idxs(expr, remap)
    @lib.Loop(block_type, expr) =>
      dfe_block_type_uses_remap(block_type, remap) ||
      dfe_expr_uses_type_idxs(expr, remap)
    @lib.If(block_type, then_body, else_body) => {
      if dfe_block_type_uses_remap(block_type, remap) {
        return true
      }
      if then_body.any(fn(nested) {
          dfe_instruction_uses_type_idxs(nested, remap)
        }) {
        return true
      }
      match else_body {
        Some(body) =>
          body.any(fn(nested) { dfe_instruction_uses_type_idxs(nested, remap) })
        None => false
      }
    }
    @lib.CallIndirect(type_idx, _) => dfe_type_idx_is_remapped(type_idx, remap)
    @lib.ReturnCallIndirect(type_idx, _) =>
      dfe_type_idx_is_remapped(type_idx, remap)
    @lib.CallRef(type_idx) => dfe_type_idx_is_remapped(type_idx, remap)
    @lib.ReturnCallRef(type_idx) => dfe_type_idx_is_remapped(type_idx, remap)
    @lib.TryTable(block_type, _, body) =>
      dfe_block_type_uses_remap(block_type, remap) ||
      dfe_expr_uses_type_idxs(body, remap)
    @lib.RefNull(ref_type) => dfe_ref_type_uses_remap(ref_type, remap)
    @lib.StructNew(type_idx) => dfe_type_idx_is_remapped(type_idx, remap)
    @lib.StructNewDefault(type_idx) => dfe_type_idx_is_remapped(type_idx, remap)
    @lib.StructNewDesc(type_idx) => dfe_type_idx_is_remapped(type_idx, remap)
    @lib.StructNewDefaultDesc(type_idx) =>
      dfe_type_idx_is_remapped(type_idx, remap)
    @lib.StructGet(type_idx, _) => dfe_type_idx_is_remapped(type_idx, remap)
    @lib.StructGetS(type_idx, _) => dfe_type_idx_is_remapped(type_idx, remap)
    @lib.StructGetU(type_idx, _) => dfe_type_idx_is_remapped(type_idx, remap)
    @lib.StructSet(type_idx, _) => dfe_type_idx_is_remapped(type_idx, remap)
    @lib.ArrayNew(type_idx) => dfe_type_idx_is_remapped(type_idx, remap)
    @lib.ArrayNewDefault(type_idx) => dfe_type_idx_is_remapped(type_idx, remap)
    @lib.ArrayNewFixed(type_idx, _) => dfe_type_idx_is_remapped(type_idx, remap)
    @lib.ArrayNewData(type_idx, _) => dfe_type_idx_is_remapped(type_idx, remap)
    @lib.ArrayNewElem(type_idx, _) => dfe_type_idx_is_remapped(type_idx, remap)
    @lib.ArrayGet(type_idx) => dfe_type_idx_is_remapped(type_idx, remap)
    @lib.ArrayGetS(type_idx) => dfe_type_idx_is_remapped(type_idx, remap)
    @lib.ArrayGetU(type_idx) => dfe_type_idx_is_remapped(type_idx, remap)
    @lib.ArraySet(type_idx) => dfe_type_idx_is_remapped(type_idx, remap)
    @lib.ArrayFill(type_idx) => dfe_type_idx_is_remapped(type_idx, remap)
    @lib.ArrayInitData(type_idx, _) => dfe_type_idx_is_remapped(type_idx, remap)
    @lib.ArrayInitElem(type_idx, _) => dfe_type_idx_is_remapped(type_idx, remap)
    @lib.RefGetDesc(type_idx) => dfe_type_idx_is_remapped(type_idx, remap)
    @lib.ArrayCopy(src_type, dst_type) =>
      dfe_type_idx_is_remapped(src_type, remap) ||
      dfe_type_idx_is_remapped(dst_type, remap)
    @lib.RefTest(_, heap_type) => dfe_heap_type_uses_remap(heap_type, remap)
    @lib.RefCast(_, heap_type) => dfe_heap_type_uses_remap(heap_type, remap)
    @lib.RefTestDesc(_, heap_type) => dfe_heap_type_uses_remap(heap_type, remap)
    @lib.RefCastDescEq(_, heap_type) =>
      dfe_heap_type_uses_remap(heap_type, remap)
    @lib.BrOnCast(_, _, source, target) =>
      dfe_heap_type_uses_remap(source, remap) ||
      dfe_heap_type_uses_remap(target, remap)
    @lib.BrOnCastFail(_, _, source, target) =>
      dfe_heap_type_uses_remap(source, remap) ||
      dfe_heap_type_uses_remap(target, remap)
    _ => false
  }
}

///|
fn dfe_expr_uses_type_idxs(expr : @lib.Expr, remap : Map[UInt, UInt]) -> Bool {
  let @lib.Expr(instrs) = expr
  instrs.any(fn(instr) { dfe_instruction_uses_type_idxs(instr, remap) })
}

///|
fn dfe_func_uses_type_idxs(func : @lib.Func, remap : Map[UInt, UInt]) -> Bool {
  let @lib.Func(locals, body) = func
  locals.runs().any(fn(run) { dfe_val_type_uses_remap(run.val_type(), remap) }) ||
  dfe_expr_uses_type_idxs(body, remap)
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
    @lib.RefTest(nullable, heap_type) =>
      @lib.Instruction::ref_test(
        nullable,
        dfe_rewrite_heap_type(heap_type, remap),
      )
    @lib.RefCast(nullable, heap_type) =>
      @lib.Instruction::ref_cast(
        nullable,
        dfe_rewrite_heap_type(heap_type, remap),
      )
    @lib.RefTestDesc(nullable, heap_type) =>
      @lib.Instruction::ref_test_desc(
        nullable,
        dfe_rewrite_heap_type(heap_type, remap),
      )
    @lib.RefCastDescEq(nullable, heap_type) =>
      @lib.Instruction::ref_cast_desc_eq(
        nullable,
        dfe_rewrite_heap_type(heap_type, remap),
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
fn dfe_rewrite_expr_type_idxs(
  expr : @lib.Expr,
  remap : Map[UInt, UInt],
) -> @lib.Expr {
  let @lib.Expr(instrs) = expr
  let rewritten : Array[@lib.Instruction] = []
  for instr in instrs {
    rewritten.push(dfe_rewrite_instruction_type_idxs(instr, remap))
  }
  @lib.Expr::new(rewritten)
}

///|
fn dfe_rewrite_locals_type_idxs(
  locals : @lib.Locals,
  remap : Map[UInt, UInt],
) -> @lib.Locals {
  let rewritten : Array[@lib.LocalRun] = []
  for run in locals.runs() {
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
fn dfe_rewrite_func_type_idxs(
  func : @lib.Func,
  remap : Map[UInt, UInt],
) -> @lib.Func {
  let @lib.Func(locals, body) = func
  @lib.Func::new(
    dfe_rewrite_locals_type_idxs(locals, remap),
    dfe_rewrite_expr_type_idxs(body, remap),
  )
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
        next.push(dfe_rewrite_func_type_idxs(func, remap))
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

///|
fn dfe_rewrite_func_idx(
  idx : @lib.FuncIdx,
  remap : Map[UInt, UInt],
) -> @lib.FuncIdx {
  let @lib.FuncIdx(raw) = idx
  @lib.FuncIdx::new(remap.get(raw).unwrap_or(raw))
}

///|
fn dfe_rewrite_instruction_func_idxs(
  instr : @lib.Instruction,
  remap : Map[UInt, UInt],
) -> @lib.Instruction {
  match instr {
    @lib.Block(block_type, expr) =>
      @lib.Instruction::block(
        block_type,
        dfe_rewrite_expr_func_idxs(expr, remap),
      )
    @lib.Loop(block_type, expr) =>
      @lib.Instruction::loop_(
        block_type,
        dfe_rewrite_expr_func_idxs(expr, remap),
      )
    @lib.If(block_type, then_body, else_body) => {
      let rewritten_then : Array[@lib.Instruction] = []
      for nested in then_body {
        rewritten_then.push(dfe_rewrite_instruction_func_idxs(nested, remap))
      }
      let rewritten_else = match else_body {
        Some(body) => {
          let rewritten : Array[@lib.Instruction] = []
          for nested in body {
            rewritten.push(dfe_rewrite_instruction_func_idxs(nested, remap))
          }
          Some(rewritten)
        }
        None => None
      }
      @lib.Instruction::if_(block_type, rewritten_then, rewritten_else)
    }
    @lib.Call(func_idx) =>
      @lib.Instruction::call(dfe_rewrite_func_idx(func_idx, remap))
    @lib.ReturnCall(func_idx) =>
      @lib.Instruction::return_call(dfe_rewrite_func_idx(func_idx, remap))
    @lib.TryTable(block_type, catches, body) =>
      @lib.Instruction::try_table(
        block_type,
        catches,
        dfe_rewrite_expr_func_idxs(body, remap),
      )
    @lib.RefFunc(func_idx) =>
      @lib.Instruction::ref_func(dfe_rewrite_func_idx(func_idx, remap))
    _ => instr
  }
}

///|
fn dfe_rewrite_expr_func_idxs(
  expr : @lib.Expr,
  remap : Map[UInt, UInt],
) -> @lib.Expr {
  let @lib.Expr(instrs) = expr
  let rewritten : Array[@lib.Instruction] = []
  for instr in instrs {
    rewritten.push(dfe_rewrite_instruction_func_idxs(instr, remap))
  }
  @lib.Expr::new(rewritten)
}

///|
fn dfe_rewrite_func_func_idxs(
  func : @lib.Func,
  remap : Map[UInt, UInt],
) -> @lib.Func {
  let @lib.Func(locals, body) = func
  @lib.Func::new(locals, dfe_rewrite_expr_func_idxs(body, remap))
}

///|
fn dfe_rewrite_extern_idx_func_idxs(
  idx : @lib.ExternIdx,
  remap : Map[UInt, UInt],
) -> @lib.ExternIdx {
  match idx {
    @lib.FuncExternIdx(func_idx) =>
      @lib.ExternIdx::func(dfe_rewrite_func_idx(func_idx, remap))
    _ => idx
  }
}

///|
fn dfe_rewrite_export_func_idxs(
  export_ : @lib.Export,
  remap : Map[UInt, UInt],
) -> @lib.Export {
  let @lib.Export(name, idx) = export_
  @lib.Export::new(name, dfe_rewrite_extern_idx_func_idxs(idx, remap))
}

///|
fn dfe_rewrite_elem_kind_func_idxs(
  kind : @lib.ElemKind,
  remap : Map[UInt, UInt],
) -> @lib.ElemKind {
  match kind {
    @lib.FuncsElemKind(funcs) => {
      let rewritten : Array[@lib.FuncIdx] = []
      for func_idx in funcs {
        rewritten.push(dfe_rewrite_func_idx(func_idx, remap))
      }
      @lib.ElemKind::funcs(rewritten)
    }
    @lib.FuncExprsElemKind(exprs) => {
      let rewritten : Array[@lib.Expr] = []
      for expr in exprs {
        rewritten.push(dfe_rewrite_expr_func_idxs(expr, remap))
      }
      @lib.ElemKind::func_exprs(rewritten)
    }
    @lib.TypedExprsElemKind(ref_type, exprs) => {
      let rewritten : Array[@lib.Expr] = []
      for expr in exprs {
        rewritten.push(dfe_rewrite_expr_func_idxs(expr, remap))
      }
      @lib.ElemKind::typed_exprs(ref_type, rewritten)
    }
  }
}

///|
fn dfe_rewrite_func_annotation_sec(
  sec : @lib.FuncAnnotationSec,
  remap : Map[UInt, UInt],
  drop_unmapped : Bool,
) -> @lib.FuncAnnotationSec {
  let @lib.FuncAnnotationSec(entries) = sec
  let rewritten : Array[@lib.FuncAnnotationAssoc] = []
  let mut last_idx : UInt? = None
  for entry in entries {
    let @lib.FuncAnnotationAssoc(idx, annotations) = entry
    match remap.get(idx) {
      Some(next_idx) => {
        if last_idx == Some(next_idx) {
          continue
        }
        rewritten.push(@lib.FuncAnnotationAssoc::new(next_idx, annotations))
        last_idx = Some(next_idx)
      }
      None =>
        if !drop_unmapped {
          if last_idx == Some(idx) {
            continue
          }
          rewritten.push(entry)
          last_idx = Some(idx)
        }
    }
  }
  @lib.FuncAnnotationSec::new(rewritten)
}

///|
fn dfe_rewrite_func_annotation_sec_in_module(
  mod_ : @lib.Module,
  remap : Map[UInt, UInt],
  drop_unmapped : Bool,
) -> @lib.Module {
  match mod_.func_annotation_sec {
    Some(sec) =>
      mod_.with_func_annotation_sec(
        dfe_rewrite_func_annotation_sec(sec, remap, drop_unmapped),
      )
    None => mod_
  }
}

///|
fn dfe_rewrite_module_func_idxs(
  mod_ : @lib.Module,
  remap : Map[UInt, UInt],
) -> @lib.Module {
  let mut rewritten = mod_
  match mod_.export_sec {
    Some(@lib.ExportSec(exports)) => {
      let next : Array[@lib.Export] = []
      for export_ in exports {
        next.push(dfe_rewrite_export_func_idxs(export_, remap))
      }
      rewritten = rewritten.with_export_sec(@lib.ExportSec::new(next))
    }
    None => ()
  }
  match mod_.start_sec {
    Some(@lib.StartSec(func_idx)) =>
      rewritten = rewritten.with_start_sec(
        @lib.StartSec::new(dfe_rewrite_func_idx(func_idx, remap)),
      )
    None => ()
  }
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) => {
      let next : Array[@lib.Elem] = []
      for elem in elems {
        let @lib.Elem(mode, kind) = elem
        next.push(
          @lib.Elem::new(
            match mode {
              @lib.Active(table_idx, expr) =>
                @lib.ElemMode::active(
                  table_idx,
                  dfe_rewrite_expr_func_idxs(expr, remap),
                )
              _ => mode
            },
            dfe_rewrite_elem_kind_func_idxs(kind, remap),
          ),
        )
      }
      rewritten = rewritten.with_elem_sec(@lib.ElemSec::new(next))
    }
    None => ()
  }
  match mod_.table_sec {
    Some(@lib.TableSec(tables)) => {
      let next : Array[@lib.Table] = []
      for table in tables {
        let @lib.Table(table_type, init) = table
        next.push(
          @lib.Table::new(
            table_type,
            match init {
              Some(expr) => Some(dfe_rewrite_expr_func_idxs(expr, remap))
              None => None
            },
          ),
        )
      }
      rewritten = rewritten.with_table_sec(@lib.TableSec::new(next))
    }
    None => ()
  }
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) => {
      let next : Array[@lib.Global] = []
      for global in globals {
        let @lib.Global(global_type, expr) = global
        next.push(
          @lib.Global::new(global_type, dfe_rewrite_expr_func_idxs(expr, remap)),
        )
      }
      rewritten = rewritten.with_global_sec(@lib.GlobalSec::new(next))
    }
    None => ()
  }
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let next : Array[@lib.Func] = []
      for func in funcs {
        next.push(dfe_rewrite_func_func_idxs(func, remap))
      }
      rewritten = rewritten.with_code_sec(@lib.CodeSec::new(next))
    }
    None => ()
  }
  match mod_.data_sec {
    Some(@lib.DataSec(datas)) => {
      let next : Array[@lib.Data] = []
      for data in datas {
        let @lib.Data(mode, bytes) = data
        next.push(
          @lib.Data::new(
            match mode {
              @lib.Active(mem_idx, expr) =>
                @lib.DataMode::active(
                  mem_idx,
                  dfe_rewrite_expr_func_idxs(expr, remap),
                )
              @lib.Passive => mode
            },
            bytes,
          ),
        )
      }
      rewritten = rewritten.with_data_sec(@lib.DataSec::new(next))
    }
    None => ()
  }
  dfe_rewrite_func_annotation_sec_in_module(rewritten, remap, false)
}

///|
fn dfe_canonical_remap_sources(remap : Map[UInt, UInt]) -> Map[UInt, UInt] {
  let canonical : Map[UInt, UInt] = {}
  for source_idx in remap.keys() {
    let target_idx = remap[source_idx]
    match canonical.get(target_idx) {
      Some(existing) =>
        if source_idx < existing {
          canonical[target_idx] = source_idx
        }
      None => canonical[target_idx] = source_idx
    }
  }
  canonical
}

///|
fn dfe_rewrite_name_map_filtered(
  names : @lib.NameMap,
  remap : Map[UInt, UInt],
  drop_unmapped : Bool,
) -> @lib.NameMap {
  let @lib.NameMap(entries) = names
  let canonical_sources = dfe_canonical_remap_sources(remap)
  let by_idx : Map[UInt, @lib.NameAssoc] = {}
  for entry in entries {
    let @lib.NameAssoc(idx, name) = entry
    match remap.get(idx) {
      Some(next_idx) =>
        if canonical_sources.get(next_idx) == Some(idx) &&
          by_idx.get(next_idx) is None {
          by_idx[next_idx] = @lib.NameAssoc::new(next_idx, name)
        }
      None =>
        if !drop_unmapped && by_idx.get(idx) is None {
          by_idx[idx] = entry
        }
    }
  }
  let ordered_idxs : Array[UInt] = []
  for idx in by_idx.keys() {
    ordered_idxs.push(idx)
  }
  ordered_idxs.sort_by(fn(lhs, rhs) {
    if lhs < rhs {
      -1
    } else if lhs > rhs {
      1
    } else {
      0
    }
  })
  let rewritten : Array[@lib.NameAssoc] = []
  for idx in ordered_idxs {
    match by_idx.get(idx) {
      Some(entry) => rewritten.push(entry)
      None => abort("expected name entry for idx \{idx}")
    }
  }
  @lib.NameMap::new(rewritten)
}

///|
fn dfe_rewrite_local_name_map_filtered(
  names : @lib.IndirectNameMap,
  remap : Map[UInt, UInt],
  drop_unmapped : Bool,
) -> @lib.IndirectNameMap {
  let @lib.IndirectNameMap(entries) = names
  let canonical_sources = dfe_canonical_remap_sources(remap)
  let by_idx : Map[UInt, @lib.IndirectNameAssoc] = {}
  for entry in entries {
    let @lib.IndirectNameAssoc(idx, local_names) = entry
    match remap.get(idx) {
      Some(next_idx) =>
        if canonical_sources.get(next_idx) == Some(idx) &&
          by_idx.get(next_idx) is None {
          by_idx[next_idx] = @lib.IndirectNameAssoc::new(next_idx, local_names)
        }
      None =>
        if !drop_unmapped && by_idx.get(idx) is None {
          by_idx[idx] = entry
        }
    }
  }
  let ordered_idxs : Array[UInt] = []
  for idx in by_idx.keys() {
    ordered_idxs.push(idx)
  }
  ordered_idxs.sort_by(fn(lhs, rhs) {
    if lhs < rhs {
      -1
    } else if lhs > rhs {
      1
    } else {
      0
    }
  })
  let rewritten : Array[@lib.IndirectNameAssoc] = []
  for idx in ordered_idxs {
    match by_idx.get(idx) {
      Some(entry) => rewritten.push(entry)
      None => abort("expected indirect name entry for idx \{idx}")
    }
  }
  @lib.IndirectNameMap::new(rewritten)
}

///|
fn dfe_rewrite_name_sec(
  name_sec : @lib.NameSec,
  remap : Map[UInt, UInt],
) -> @lib.NameSec {
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
  } = name_sec
  @lib.NameSec::new(
    module_name~,
    func_names=match func_names {
      Some(names) => Some(dfe_rewrite_name_map_filtered(names, remap, false))
      None => None
    },
    local_names=match local_names {
      Some(names) =>
        Some(dfe_rewrite_local_name_map_filtered(names, remap, false))
      None => None
    },
    label_names~,
    type_names~,
    table_names~,
    memory_names~,
    global_names~,
    elem_names~,
    data_names~,
    field_names~,
    tag_names~,
  )
}

///|
fn dfe_rewrite_type_name_sec(
  name_sec : @lib.NameSec,
  type_remap : Map[UInt, UInt],
) -> @lib.NameSec {
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
  } = name_sec
  @lib.NameSec::new(
    module_name~,
    func_names~,
    local_names~,
    label_names~,
    type_names=match type_names {
      Some(names) =>
        Some(dfe_rewrite_name_map_filtered(names, type_remap, true))
      None => None
    },
    table_names~,
    memory_names~,
    global_names~,
    elem_names~,
    data_names~,
    field_names~,
    tag_names~,
  )
}

///|
fn dfe_funcs_semantically_equal(left : @lib.Func, right : @lib.Func) -> Bool {
  left == right
}

///|
fn dfe_canonicalize_func_duplicate_simple_type_indices(
  func : @lib.Func,
  type_canon : Map[UInt, UInt],
) -> @lib.Func {
  if type_canon.length() == 0 {
    return func
  }
  dfe_rewrite_func_type_idxs(func, type_canon)
}

///|
fn dfe_locals_shape_hash(locals : @lib.Locals) -> Int {
  let mut key = 17
  for run in locals.runs() {
    key = key * 31 + run.count().hash()
    key = key * 31 + run.val_type().hash()
  }
  key
}

///|
fn dfe_functions_equivalent(
  type_canon : Map[UInt, UInt],
  left_type : @lib.TypeIdx,
  left_func : @lib.Func,
  left_annotations : Array[@lib.FuncAnnotation],
  right_type : @lib.TypeIdx,
  right_func : @lib.Func,
  right_annotations : Array[@lib.FuncAnnotation],
) -> Bool {
  if !dfe_funcs_semantically_equal(left_func, right_func) ||
    left_annotations != right_annotations {
    return false
  }
  let left_canon = match left_type {
    @lib.TypeIdx(raw) => type_canon.get(raw).unwrap_or(raw)
    @lib.RecIdx(raw) => raw
  }
  let right_canon = match right_type {
    @lib.TypeIdx(raw) => type_canon.get(raw).unwrap_or(raw)
    @lib.RecIdx(raw) => raw
  }
  left_canon == right_canon
}

///|
fn dfe_function_hash_key(
  type_canon : Map[UInt, UInt],
  type_idx : @lib.TypeIdx,
  func : @lib.Func,
  annotations : Array[@lib.FuncAnnotation],
) -> Int {
  let @lib.Func(locals, body) = func
  let @lib.Expr(instrs) = body
  let type_hash = match type_idx {
    @lib.TypeIdx(raw) => type_canon.get(raw).unwrap_or(raw).hash()
    @lib.RecIdx(_) => type_idx.hash()
  }
  let mut key = (
      (dfe_locals_shape_hash(locals) * 31 + type_hash) * 31 +
      instrs.length().hash()
    ) *
    31 +
    annotations.hash()
  let sample_count = if instrs.length() < 3 { instrs.length() } else { 3 }
  let mut i = 0
  while i < sample_count {
    key = key * 31 + instrs[i].hash()
    i += 1
  }
  let sample_start = if instrs.length() > sample_count {
    instrs.length() - sample_count
  } else {
    sample_count
  }
  i = sample_start
  while i < instrs.length() {
    key = key * 31 + instrs[i].hash()
    i += 1
  }
  key
}

///|
fn dfe_canonical_local_idx(
  replacements : Map[Int, Int],
  local_idx : Int,
) -> Int {
  let mut current = local_idx
  while true {
    match replacements.get(current) {
      Some(next) => current = next
      None => return current
    }
  }
  current
}

///|
fn dfe_canonicalize_duplicate_simple_type_indices(
  mod_ : @lib.Module,
) -> @lib.Module {
  match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) => {
      let canonical_old_idxs = dfe_duplicate_simple_type_canonical_map(
        rec_types,
      )
      if canonical_old_idxs.length() == 0 {
        return mod_
      }
      let kept_types : Array[@lib.RecType] = []
      let old_to_new : Map[UInt, UInt] = {}
      let mut old_idx = 0
      while old_idx < rec_types.length() {
        let raw_old_idx = old_idx.reinterpret_as_uint()
        let canonical_old_idx = canonical_old_idxs
          .get(raw_old_idx)
          .unwrap_or(raw_old_idx)
        if canonical_old_idx == old_idx.reinterpret_as_uint() {
          old_to_new[canonical_old_idx] = kept_types
            .length()
            .reinterpret_as_uint()
          kept_types.push(rec_types[old_idx])
        }
        old_idx += 1
      }
      if kept_types.length() == rec_types.length() {
        return mod_
      }
      let type_remap : Map[UInt, UInt] = {}
      old_idx = 0
      while old_idx < rec_types.length() {
        let raw_old_idx = old_idx.reinterpret_as_uint()
        let canonical_old_idx = canonical_old_idxs
          .get(raw_old_idx)
          .unwrap_or(raw_old_idx)
        match old_to_new.get(canonical_old_idx) {
          Some(new_idx) => type_remap[raw_old_idx] = new_idx
          None => return mod_
        }
        old_idx += 1
      }
      let rewritten = dfe_rewrite_module_type_idxs(mod_, type_remap)
      let with_types = rewritten.with_type_sec(@lib.TypeSec::new(kept_types))
      match with_types.name_sec {
        Some(name_sec) =>
          with_types.with_name_sec(
            dfe_rewrite_type_name_sec(name_sec, type_remap),
          )
        None => with_types
      }
    }
    None => mod_
  }
}

///|
fn dfe_iteration(mod_ : @lib.Module) -> @lib.Module? {
  match (mod_.func_sec, mod_.code_sec) {
    (Some(@lib.FuncSec(type_idxs)), Some(@lib.CodeSec(funcs))) => {
      if type_idxs.length() != funcs.length() {
        return None
      }
      let type_canon = match mod_.type_sec {
        Some(@lib.TypeSec(rec_types)) =>
          dfe_duplicate_simple_type_canonical_map(rec_types)
        None => {}
      }
      let imported_count = dfe_imported_func_count(mod_)
      let annotations_by_abs_idx = dfe_func_annotation_map(mod_)
      let normalized_funcs : Array[@lib.Func] = if type_canon.length() == 0 {
        funcs
      } else {
        let rewritten : Array[@lib.Func] = []
        for func in funcs {
          if dfe_func_uses_type_idxs(func, type_canon) {
            rewritten.push(
              dfe_canonicalize_func_duplicate_simple_type_indices(
                func, type_canon,
              ),
            )
          } else {
            rewritten.push(func)
          }
        }
        rewritten
      }
      let normalized_annotations : Array[Array[@lib.FuncAnnotation]] = []
      let first_by_hash : Map[Int, Int] = {}
      let collision_group_by_hash : Map[Int, Int] = {}
      let hash_groups : Array[Array[Int]] = []
      let mut local_idx = 0
      while local_idx < funcs.length() {
        let abs_idx = imported_count + local_idx
        let annotations = dfe_func_annotations(
          annotations_by_abs_idx,
          abs_idx.reinterpret_as_uint(),
        )
        normalized_annotations.push(annotations)
        let key = dfe_function_hash_key(
          type_canon,
          type_idxs[local_idx],
          normalized_funcs[local_idx],
          annotations,
        )
        match first_by_hash.get(key) {
          Some(first_idx) =>
            match collision_group_by_hash.get(key) {
              Some(group_idx) => hash_groups[group_idx].push(local_idx)
              None => {
                collision_group_by_hash[key] = hash_groups.length()
                hash_groups.push([first_idx, local_idx])
              }
            }
          None => first_by_hash[key] = local_idx
        }
        local_idx += 1
      }

      let replacements : Map[Int, Int] = {}
      let mut changed = false
      for group in hash_groups {
        if group.length() <= 1 {
          continue
        }
        let mut i = 0
        while i < group.length() - 1 {
          let first = group[i]
          if replacements.get(first) is Some(_) {
            i += 1
            continue
          }
          let mut j = i + 1
          while j < group.length() {
            let second = group[j]
            if replacements.get(second) is Some(_) {
              j += 1
              continue
            }
            if dfe_functions_equivalent(
                type_canon,
                type_idxs[first],
                normalized_funcs[first],
                normalized_annotations[first],
                type_idxs[second],
                normalized_funcs[second],
                normalized_annotations[second],
              ) {
              replacements[second] = first
              changed = true
            }
            j += 1
          }
          i += 1
        }
      }

      if !changed {
        return None
      }

      let kept_types : Array[@lib.TypeIdx] = []
      let kept_funcs : Array[@lib.Func] = []
      let kept_abs : Map[Int, UInt] = {}
      let mut next_abs = imported_count.reinterpret_as_uint()
      let mut idx = 0
      while idx < funcs.length() {
        if replacements.get(idx) is None {
          kept_abs[idx] = next_abs
          kept_types.push(type_idxs[idx])
          kept_funcs.push(funcs[idx])
          next_abs += 1U
        }
        idx += 1
      }

      let abs_remap : Map[UInt, UInt] = {}
      let mut import_idx = 0
      while import_idx < imported_count {
        let raw = import_idx.reinterpret_as_uint()
        abs_remap[raw] = raw
        import_idx += 1
      }

      idx = 0
      while idx < funcs.length() {
        let canonical = dfe_canonical_local_idx(replacements, idx)
        match kept_abs.get(canonical) {
          Some(next) =>
            abs_remap[(imported_count + idx).reinterpret_as_uint()] = next
          None => return None
        }
        idx += 1
      }

      let mut compacted = mod_
        .with_func_sec(@lib.FuncSec::new(kept_types))
        .with_code_sec(@lib.CodeSec::new(kept_funcs))
      match mod_.name_sec {
        Some(name_sec) =>
          compacted = compacted.with_name_sec(
            dfe_rewrite_name_sec(name_sec, abs_remap),
          )
        None => ()
      }
      Some(dfe_rewrite_module_func_idxs(compacted, abs_remap))
    }
    _ => None
  }
}

///|
pub fn dfe_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  let current = match dfe_iteration(mod_) {
    Some(next) => next
    None => return dfe_canonicalize_elem_segments(mod_)
  }
  dfe_canonicalize_duplicate_simple_type_indices(
    dfe_canonicalize_elem_segments(current),
  )
}
