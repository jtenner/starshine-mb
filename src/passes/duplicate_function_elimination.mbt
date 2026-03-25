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
fn dfe_strip_name_sec(mod_ : @lib.Module) -> @lib.Module {
  mod_.without_name_sec()
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
fn dfe_type_metadata_mentions_type_idxs(metadata : @lib.TypeMetadata) -> Bool {
  let { describes, descriptor } = metadata
  describes is Some(_) || descriptor is Some(_)
}

///|
fn dfe_heap_type_mentions_type_idxs(heap_type : @lib.HeapType) -> Bool {
  match heap_type {
    @lib.AbsHeapTypeHeapType(_) => false
    @lib.HeapType(_) => true
    @lib.DefTypeHeapType(@lib.DefType(rec_type, _)) =>
      dfe_rec_type_mentions_type_idxs(rec_type)
  }
}

///|
fn dfe_ref_type_mentions_type_idxs(ref_type : @lib.RefType) -> Bool {
  match ref_type {
    @lib.HeapTypeRefType(_, _, heap_type) =>
      dfe_heap_type_mentions_type_idxs(heap_type)
    @lib.AbsHeapTypeRefType(_) => false
  }
}

///|
fn dfe_val_type_mentions_type_idxs(val_type : @lib.ValType) -> Bool {
  match val_type {
    @lib.RefTypeValType(ref_type) => dfe_ref_type_mentions_type_idxs(ref_type)
    _ => false
  }
}

///|
fn dfe_storage_type_mentions_type_idxs(storage_type : @lib.StorageType) -> Bool {
  match storage_type {
    @lib.ValTypeStorageType(val_type) =>
      dfe_val_type_mentions_type_idxs(val_type)
    @lib.PackTypeStorageType(_) => false
  }
}

///|
fn dfe_field_type_mentions_type_idxs(field_type : @lib.FieldType) -> Bool {
  let @lib.FieldType(storage_type, _) = field_type
  dfe_storage_type_mentions_type_idxs(storage_type)
}

///|
fn dfe_field_types_mention_type_idxs(
  field_types : Array[@lib.FieldType],
) -> Bool {
  let mut idx = 0
  while idx < field_types.length() {
    if dfe_field_type_mentions_type_idxs(field_types[idx]) {
      return true
    }
    idx += 1
  }
  false
}

///|
fn dfe_val_types_mention_type_idxs(val_types : Array[@lib.ValType]) -> Bool {
  let mut idx = 0
  while idx < val_types.length() {
    if dfe_val_type_mentions_type_idxs(val_types[idx]) {
      return true
    }
    idx += 1
  }
  false
}

///|
fn dfe_type_idxs_mention_type_idxs(type_idxs : Array[@lib.TypeIdx]) -> Bool {
  let mut idx = 0
  while idx < type_idxs.length() {
    match type_idxs[idx] {
      @lib.TypeIdx(_) => return true
      @lib.RecIdx(_) => ()
    }
    idx += 1
  }
  false
}

///|
fn dfe_comp_type_mentions_type_idxs(comp_type : @lib.CompType) -> Bool {
  match comp_type {
    @lib.ArrayCompType(field_type) =>
      dfe_field_type_mentions_type_idxs(field_type)
    @lib.StructCompType(field_types) =>
      dfe_field_types_mention_type_idxs(field_types)
    @lib.FuncCompType(params, results) =>
      dfe_val_types_mention_type_idxs(params) ||
      dfe_val_types_mention_type_idxs(results)
  }
}

///|
fn dfe_sub_type_mentions_type_idxs(subtype : @lib.SubType) -> Bool {
  match subtype {
    @lib.SubType(_, supers, metadata, comp_type) =>
      dfe_type_idxs_mention_type_idxs(supers) ||
      dfe_type_metadata_mentions_type_idxs(metadata) ||
      dfe_comp_type_mentions_type_idxs(comp_type)
    @lib.CompTypeSubType(metadata, comp_type) =>
      dfe_type_metadata_mentions_type_idxs(metadata) ||
      dfe_comp_type_mentions_type_idxs(comp_type)
  }
}

///|
fn dfe_sub_types_mention_type_idxs(subtypes : Array[@lib.SubType]) -> Bool {
  let mut idx = 0
  while idx < subtypes.length() {
    if dfe_sub_type_mentions_type_idxs(subtypes[idx]) {
      return true
    }
    idx += 1
  }
  false
}

///|
fn dfe_rec_type_mentions_type_idxs(rec_type : @lib.RecType) -> Bool {
  match rec_type {
    @lib.SingleRecType(subtype) => dfe_sub_type_mentions_type_idxs(subtype)
    @lib.GroupRecType(subtypes) => dfe_sub_types_mention_type_idxs(subtypes)
  }
}

///|
fn dfe_block_type_mentions_type_idxs(block_type : @lib.BlockType) -> Bool {
  match block_type {
    @lib.VoidBlockType => false
    @lib.ValTypeBlockType(val_type) => dfe_val_type_mentions_type_idxs(val_type)
    @lib.TypeIdxBlockType(_) => true
  }
}

///|
fn dfe_instruction_array_mentions_type_idxs(
  instrs : Array[@lib.Instruction],
) -> Bool {
  let mut idx = 0
  while idx < instrs.length() {
    if dfe_instruction_mentions_type_idxs(instrs[idx]) {
      return true
    }
    idx += 1
  }
  false
}

///|
fn dfe_expr_mentions_type_idxs(expr : @lib.Expr) -> Bool {
  let @lib.Expr(instrs) = expr
  dfe_instruction_array_mentions_type_idxs(instrs)
}

///|
fn dfe_locals_mention_type_idxs(locals : @lib.Locals) -> Bool {
  let runs = locals.runs()
  let mut idx = 0
  while idx < runs.length() {
    if dfe_val_type_mentions_type_idxs(runs[idx].val_type()) {
      return true
    }
    idx += 1
  }
  false
}

///|
fn dfe_instruction_mentions_type_idxs(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Block(block_type, expr) =>
      dfe_block_type_mentions_type_idxs(block_type) ||
      dfe_expr_mentions_type_idxs(expr)
    @lib.Loop(block_type, expr) =>
      dfe_block_type_mentions_type_idxs(block_type) ||
      dfe_expr_mentions_type_idxs(expr)
    @lib.If(block_type, then_body, else_body) => {
      let else_mentions = match else_body {
        Some(body) => dfe_instruction_array_mentions_type_idxs(body)
        None => false
      }
      dfe_block_type_mentions_type_idxs(block_type) ||
      dfe_instruction_array_mentions_type_idxs(then_body) ||
      else_mentions
    }
    @lib.CallIndirect(_, _) => true
    @lib.ReturnCallIndirect(_, _) => true
    @lib.CallRef(_) => true
    @lib.ReturnCallRef(_) => true
    @lib.Select(Some(types)) => dfe_val_types_mention_type_idxs(types)
    @lib.Select(None) => false
    @lib.TryTable(block_type, _, body) =>
      dfe_block_type_mentions_type_idxs(block_type) ||
      dfe_expr_mentions_type_idxs(body)
    @lib.RefNull(ref_type) => dfe_ref_type_mentions_type_idxs(ref_type)
    @lib.StructNew(_) => true
    @lib.StructNewDefault(_) => true
    @lib.StructNewDesc(_) => true
    @lib.StructNewDefaultDesc(_) => true
    @lib.StructGet(_, _) => true
    @lib.StructGetS(_, _) => true
    @lib.StructGetU(_, _) => true
    @lib.StructSet(_, _) => true
    @lib.ArrayNew(_) => true
    @lib.ArrayNewDefault(_) => true
    @lib.ArrayNewFixed(_, _) => true
    @lib.ArrayNewData(_, _) => true
    @lib.ArrayNewElem(_, _) => true
    @lib.ArrayGet(_) => true
    @lib.ArrayGetS(_) => true
    @lib.ArrayGetU(_) => true
    @lib.ArraySet(_) => true
    @lib.ArrayFill(_) => true
    @lib.ArrayCopy(_, _) => true
    @lib.ArrayInitData(_, _) => true
    @lib.ArrayInitElem(_, _) => true
    @lib.RefGetDesc(_) => true
    @lib.RefTest(_, heap_type) => dfe_heap_type_mentions_type_idxs(heap_type)
    @lib.RefCast(_, heap_type) => dfe_heap_type_mentions_type_idxs(heap_type)
    @lib.RefTestDesc(_, heap_type) =>
      dfe_heap_type_mentions_type_idxs(heap_type)
    @lib.RefCastDescEq(_, heap_type) =>
      dfe_heap_type_mentions_type_idxs(heap_type)
    @lib.BrOnCast(_, _, source, target) =>
      dfe_heap_type_mentions_type_idxs(source) ||
      dfe_heap_type_mentions_type_idxs(target)
    @lib.BrOnCastFail(_, _, source, target) =>
      dfe_heap_type_mentions_type_idxs(source) ||
      dfe_heap_type_mentions_type_idxs(target)
    _ => false
  }
}

///|
fn dfe_func_mentions_type_idxs(func : @lib.Func) -> Bool {
  let @lib.Func(locals, body) = func
  dfe_locals_mention_type_idxs(locals) || dfe_expr_mentions_type_idxs(body)
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
priv struct DfeTypeRewriteScan[T] {
  rewritten : T?
  mentions_type_idxs : Bool
}

///|
fn dfe_scan_rewrite_val_type(
  val_type : @lib.ValType,
  remap : Map[UInt, UInt],
) -> DfeTypeRewriteScan[@lib.ValType] {
  {
    rewritten: dfe_try_rewrite_val_type(val_type, remap),
    mentions_type_idxs: dfe_val_type_mentions_type_idxs(val_type),
  }
}

///|
fn dfe_scan_rewrite_val_types(
  val_types : Array[@lib.ValType],
  remap : Map[UInt, UInt],
) -> DfeTypeRewriteScan[Array[@lib.ValType]] {
  let rewritten : Array[@lib.ValType] = Array::new(capacity=val_types.length())
  let mut changed = false
  let mut mentions_type_idxs = false
  let mut idx = 0
  while idx < val_types.length() {
    let val_type = val_types[idx]
    let scan = dfe_scan_rewrite_val_type(val_type, remap)
    mentions_type_idxs = mentions_type_idxs || scan.mentions_type_idxs
    match scan.rewritten {
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
  {
    rewritten: if changed {
      Some(rewritten)
    } else {
      None
    },
    mentions_type_idxs,
  }
}

///|
fn dfe_scan_rewrite_block_type(
  block_type : @lib.BlockType,
  remap : Map[UInt, UInt],
) -> DfeTypeRewriteScan[@lib.BlockType] {
  match block_type {
    @lib.VoidBlockType => { rewritten: None, mentions_type_idxs: false }
    @lib.ValTypeBlockType(val_type) => {
      let scan = dfe_scan_rewrite_val_type(val_type, remap)
      {
        rewritten: match scan.rewritten {
          Some(next) => Some(@lib.BlockType::val_type(next))
          None => None
        },
        mentions_type_idxs: scan.mentions_type_idxs,
      }
    }
    @lib.TypeIdxBlockType(type_idx) =>
      {
        rewritten: match dfe_try_rewrite_type_idx(type_idx, remap) {
          Some(next) => Some(@lib.BlockType::type_idx(next))
          None => None
        },
        mentions_type_idxs: true,
      }
  }
}

///|
fn dfe_scan_rewrite_instruction_array_type_idxs(
  instrs : Array[@lib.Instruction],
  remap : Map[UInt, UInt],
) -> DfeTypeRewriteScan[Array[@lib.Instruction]] {
  let rewritten : Array[@lib.Instruction] = Array::new(capacity=instrs.length())
  let mut changed = false
  let mut mentions_type_idxs = false
  let mut idx = 0
  while idx < instrs.length() {
    let instr = instrs[idx]
    let scan = dfe_scan_rewrite_instruction_type_idxs(instr, remap)
    mentions_type_idxs = mentions_type_idxs || scan.mentions_type_idxs
    match scan.rewritten {
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
  {
    rewritten: if changed {
      Some(rewritten)
    } else {
      None
    },
    mentions_type_idxs,
  }
}

///|
fn dfe_scan_rewrite_expr_type_idxs(
  expr : @lib.Expr,
  remap : Map[UInt, UInt],
) -> DfeTypeRewriteScan[@lib.Expr] {
  let @lib.Expr(instrs) = expr
  let scan = dfe_scan_rewrite_instruction_array_type_idxs(instrs, remap)
  {
    rewritten: match scan.rewritten {
      Some(next) => Some(@lib.Expr::new(next))
      None => None
    },
    mentions_type_idxs: scan.mentions_type_idxs,
  }
}

///|
fn dfe_scan_rewrite_locals_type_idxs(
  locals : @lib.Locals,
  remap : Map[UInt, UInt],
) -> DfeTypeRewriteScan[@lib.Locals] {
  let runs = locals.runs()
  let rewritten : Array[@lib.LocalRun] = Array::new(capacity=runs.length())
  let mut changed = false
  let mut mentions_type_idxs = false
  let mut idx = 0
  while idx < runs.length() {
    let run = runs[idx]
    let scan = dfe_scan_rewrite_val_type(run.val_type(), remap)
    mentions_type_idxs = mentions_type_idxs || scan.mentions_type_idxs
    match scan.rewritten {
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
  {
    rewritten: if changed {
      Some(@lib.Locals::new(rewritten))
    } else {
      None
    },
    mentions_type_idxs,
  }
}

///|
fn dfe_scan_rewrite_func_type_idxs(
  func : @lib.Func,
  remap : Map[UInt, UInt],
) -> DfeTypeRewriteScan[@lib.Func] {
  let @lib.Func(locals, body) = func
  let locals_scan = dfe_scan_rewrite_locals_type_idxs(locals, remap)
  let body_scan = dfe_scan_rewrite_expr_type_idxs(body, remap)
  {
    rewritten: if locals_scan.rewritten is None && body_scan.rewritten is None {
      None
    } else {
      Some(
        @lib.Func::new(
          match locals_scan.rewritten {
            Some(next) => next
            None => locals
          },
          match body_scan.rewritten {
            Some(next) => next
            None => body
          },
        ),
      )
    },
    mentions_type_idxs: locals_scan.mentions_type_idxs ||
    body_scan.mentions_type_idxs,
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
fn dfe_scan_rewrite_instruction_type_idxs(
  instr : @lib.Instruction,
  remap : Map[UInt, UInt],
) -> DfeTypeRewriteScan[@lib.Instruction] {
  match instr {
    @lib.Block(block_type, expr) => {
      let block_scan = dfe_scan_rewrite_block_type(block_type, remap)
      let expr_scan = dfe_scan_rewrite_expr_type_idxs(expr, remap)
      {
        rewritten: if block_scan.rewritten is None &&
          expr_scan.rewritten is None {
          None
        } else {
          Some(
            @lib.Instruction::block(
              match block_scan.rewritten {
                Some(next) => next
                None => block_type
              },
              match expr_scan.rewritten {
                Some(next) => next
                None => expr
              },
            ),
          )
        },
        mentions_type_idxs: block_scan.mentions_type_idxs ||
        expr_scan.mentions_type_idxs,
      }
    }
    @lib.Loop(block_type, expr) => {
      let block_scan = dfe_scan_rewrite_block_type(block_type, remap)
      let expr_scan = dfe_scan_rewrite_expr_type_idxs(expr, remap)
      {
        rewritten: if block_scan.rewritten is None &&
          expr_scan.rewritten is None {
          None
        } else {
          Some(
            @lib.Instruction::loop_(
              match block_scan.rewritten {
                Some(next) => next
                None => block_type
              },
              match expr_scan.rewritten {
                Some(next) => next
                None => expr
              },
            ),
          )
        },
        mentions_type_idxs: block_scan.mentions_type_idxs ||
        expr_scan.mentions_type_idxs,
      }
    }
    @lib.If(block_type, then_body, else_body) => {
      let block_scan = dfe_scan_rewrite_block_type(block_type, remap)
      let then_scan = dfe_scan_rewrite_instruction_array_type_idxs(
        then_body, remap,
      )
      let else_scan = match else_body {
        Some(body) => dfe_scan_rewrite_instruction_array_type_idxs(body, remap)
        None => { rewritten: None, mentions_type_idxs: false }
      }
      {
        rewritten: if block_scan.rewritten is None &&
          then_scan.rewritten is None &&
          else_scan.rewritten is None {
          None
        } else {
          Some(
            @lib.Instruction::if_(
              match block_scan.rewritten {
                Some(next) => next
                None => block_type
              },
              match then_scan.rewritten {
                Some(next) => next
                None => then_body
              },
              match else_body {
                Some(body) =>
                  Some(
                    match else_scan.rewritten {
                      Some(next) => next
                      None => body
                    },
                  )
                None => None
              },
            ),
          )
        },
        mentions_type_idxs: block_scan.mentions_type_idxs ||
        then_scan.mentions_type_idxs ||
        else_scan.mentions_type_idxs,
      }
    }
    @lib.CallIndirect(type_idx, table_idx) =>
      {
        rewritten: match dfe_try_rewrite_type_idx(type_idx, remap) {
          Some(next) => Some(@lib.Instruction::call_indirect(next, table_idx))
          None => None
        },
        mentions_type_idxs: true,
      }
    @lib.ReturnCallIndirect(type_idx, table_idx) =>
      {
        rewritten: match dfe_try_rewrite_type_idx(type_idx, remap) {
          Some(next) =>
            Some(@lib.Instruction::return_call_indirect(next, table_idx))
          None => None
        },
        mentions_type_idxs: true,
      }
    @lib.CallRef(type_idx) =>
      {
        rewritten: match dfe_try_rewrite_type_idx(type_idx, remap) {
          Some(next) => Some(@lib.Instruction::call_ref(next))
          None => None
        },
        mentions_type_idxs: true,
      }
    @lib.ReturnCallRef(type_idx) =>
      {
        rewritten: match dfe_try_rewrite_type_idx(type_idx, remap) {
          Some(next) => Some(@lib.Instruction::return_call_ref(next))
          None => None
        },
        mentions_type_idxs: true,
      }
    @lib.Select(Some(types)) => {
      let scan = dfe_scan_rewrite_val_types(types, remap)
      {
        rewritten: match scan.rewritten {
          Some(next) => Some(@lib.Instruction::select(types=Some(next)))
          None => None
        },
        mentions_type_idxs: scan.mentions_type_idxs,
      }
    }
    @lib.Select(None) => { rewritten: None, mentions_type_idxs: false }
    @lib.TryTable(block_type, catches, body) => {
      let block_scan = dfe_scan_rewrite_block_type(block_type, remap)
      let body_scan = dfe_scan_rewrite_expr_type_idxs(body, remap)
      {
        rewritten: if block_scan.rewritten is None &&
          body_scan.rewritten is None {
          None
        } else {
          Some(
            @lib.Instruction::try_table(
              match block_scan.rewritten {
                Some(next) => next
                None => block_type
              },
              catches,
              match body_scan.rewritten {
                Some(next) => next
                None => body
              },
            ),
          )
        },
        mentions_type_idxs: block_scan.mentions_type_idxs ||
        body_scan.mentions_type_idxs,
      }
    }
    @lib.RefNull(ref_type) =>
      {
        rewritten: match dfe_try_rewrite_ref_type(ref_type, remap) {
          Some(next) => Some(@lib.Instruction::ref_null_type(next))
          None => None
        },
        mentions_type_idxs: dfe_ref_type_mentions_type_idxs(ref_type),
      }
    @lib.StructNew(type_idx) =>
      {
        rewritten: match dfe_try_rewrite_type_idx(type_idx, remap) {
          Some(next) => Some(@lib.Instruction::struct_new(next))
          None => None
        },
        mentions_type_idxs: true,
      }
    @lib.StructNewDefault(type_idx) =>
      {
        rewritten: match dfe_try_rewrite_type_idx(type_idx, remap) {
          Some(next) => Some(@lib.Instruction::struct_new_default(next))
          None => None
        },
        mentions_type_idxs: true,
      }
    @lib.StructNewDesc(type_idx) =>
      {
        rewritten: match dfe_try_rewrite_type_idx(type_idx, remap) {
          Some(next) => Some(@lib.Instruction::struct_new_desc(next))
          None => None
        },
        mentions_type_idxs: true,
      }
    @lib.StructNewDefaultDesc(type_idx) =>
      {
        rewritten: match dfe_try_rewrite_type_idx(type_idx, remap) {
          Some(next) => Some(@lib.Instruction::struct_new_default_desc(next))
          None => None
        },
        mentions_type_idxs: true,
      }
    @lib.StructGet(type_idx, field_idx) =>
      {
        rewritten: match dfe_try_rewrite_type_idx(type_idx, remap) {
          Some(next) => Some(@lib.Instruction::struct_get(next, field_idx))
          None => None
        },
        mentions_type_idxs: true,
      }
    @lib.StructGetS(type_idx, field_idx) =>
      {
        rewritten: match dfe_try_rewrite_type_idx(type_idx, remap) {
          Some(next) => Some(@lib.Instruction::struct_get_s(next, field_idx))
          None => None
        },
        mentions_type_idxs: true,
      }
    @lib.StructGetU(type_idx, field_idx) =>
      {
        rewritten: match dfe_try_rewrite_type_idx(type_idx, remap) {
          Some(next) => Some(@lib.Instruction::struct_get_u(next, field_idx))
          None => None
        },
        mentions_type_idxs: true,
      }
    @lib.StructSet(type_idx, field_idx) =>
      {
        rewritten: match dfe_try_rewrite_type_idx(type_idx, remap) {
          Some(next) => Some(@lib.Instruction::struct_set(next, field_idx))
          None => None
        },
        mentions_type_idxs: true,
      }
    @lib.ArrayNew(type_idx) =>
      {
        rewritten: match dfe_try_rewrite_type_idx(type_idx, remap) {
          Some(next) => Some(@lib.Instruction::array_new(next))
          None => None
        },
        mentions_type_idxs: true,
      }
    @lib.ArrayNewDefault(type_idx) =>
      {
        rewritten: match dfe_try_rewrite_type_idx(type_idx, remap) {
          Some(next) => Some(@lib.Instruction::array_new_default(next))
          None => None
        },
        mentions_type_idxs: true,
      }
    @lib.ArrayNewFixed(type_idx, len) =>
      {
        rewritten: match dfe_try_rewrite_type_idx(type_idx, remap) {
          Some(next) => Some(@lib.Instruction::array_new_fixed(next, len))
          None => None
        },
        mentions_type_idxs: true,
      }
    @lib.ArrayNewData(type_idx, data_idx) =>
      {
        rewritten: match dfe_try_rewrite_type_idx(type_idx, remap) {
          Some(next) => Some(@lib.Instruction::array_new_data(next, data_idx))
          None => None
        },
        mentions_type_idxs: true,
      }
    @lib.ArrayNewElem(type_idx, elem_idx) =>
      {
        rewritten: match dfe_try_rewrite_type_idx(type_idx, remap) {
          Some(next) => Some(@lib.Instruction::array_new_elem(next, elem_idx))
          None => None
        },
        mentions_type_idxs: true,
      }
    @lib.ArrayGet(type_idx) =>
      {
        rewritten: match dfe_try_rewrite_type_idx(type_idx, remap) {
          Some(next) => Some(@lib.Instruction::array_get(next))
          None => None
        },
        mentions_type_idxs: true,
      }
    @lib.ArrayGetS(type_idx) =>
      {
        rewritten: match dfe_try_rewrite_type_idx(type_idx, remap) {
          Some(next) => Some(@lib.Instruction::array_get_s(next))
          None => None
        },
        mentions_type_idxs: true,
      }
    @lib.ArrayGetU(type_idx) =>
      {
        rewritten: match dfe_try_rewrite_type_idx(type_idx, remap) {
          Some(next) => Some(@lib.Instruction::array_get_u(next))
          None => None
        },
        mentions_type_idxs: true,
      }
    @lib.ArraySet(type_idx) =>
      {
        rewritten: match dfe_try_rewrite_type_idx(type_idx, remap) {
          Some(next) => Some(@lib.Instruction::array_set(next))
          None => None
        },
        mentions_type_idxs: true,
      }
    @lib.ArrayFill(type_idx) =>
      {
        rewritten: match dfe_try_rewrite_type_idx(type_idx, remap) {
          Some(next) => Some(@lib.Instruction::array_fill(next))
          None => None
        },
        mentions_type_idxs: true,
      }
    @lib.ArrayCopy(src_type, dst_type) =>
      {
        rewritten: match
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
        },
        mentions_type_idxs: true,
      }
    @lib.ArrayInitData(type_idx, data_idx) =>
      {
        rewritten: match dfe_try_rewrite_type_idx(type_idx, remap) {
          Some(next) => Some(@lib.Instruction::array_init_data(next, data_idx))
          None => None
        },
        mentions_type_idxs: true,
      }
    @lib.ArrayInitElem(type_idx, elem_idx) =>
      {
        rewritten: match dfe_try_rewrite_type_idx(type_idx, remap) {
          Some(next) => Some(@lib.Instruction::array_init_elem(next, elem_idx))
          None => None
        },
        mentions_type_idxs: true,
      }
    @lib.RefGetDesc(type_idx) =>
      {
        rewritten: match dfe_try_rewrite_type_idx(type_idx, remap) {
          Some(next) => Some(@lib.Instruction::ref_get_desc(next))
          None => None
        },
        mentions_type_idxs: true,
      }
    @lib.RefTest(nullable, heap_type) =>
      {
        rewritten: match dfe_try_rewrite_heap_type(heap_type, remap) {
          Some(next) => Some(@lib.Instruction::ref_test(nullable, next))
          None => None
        },
        mentions_type_idxs: dfe_heap_type_mentions_type_idxs(heap_type),
      }
    @lib.RefCast(nullable, heap_type) =>
      {
        rewritten: match dfe_try_rewrite_heap_type(heap_type, remap) {
          Some(next) => Some(@lib.Instruction::ref_cast(nullable, next))
          None => None
        },
        mentions_type_idxs: dfe_heap_type_mentions_type_idxs(heap_type),
      }
    @lib.RefTestDesc(nullable, heap_type) =>
      {
        rewritten: match dfe_try_rewrite_heap_type(heap_type, remap) {
          Some(next) => Some(@lib.Instruction::ref_test_desc(nullable, next))
          None => None
        },
        mentions_type_idxs: dfe_heap_type_mentions_type_idxs(heap_type),
      }
    @lib.RefCastDescEq(nullable, heap_type) =>
      {
        rewritten: match dfe_try_rewrite_heap_type(heap_type, remap) {
          Some(next) => Some(@lib.Instruction::ref_cast_desc_eq(nullable, next))
          None => None
        },
        mentions_type_idxs: dfe_heap_type_mentions_type_idxs(heap_type),
      }
    @lib.BrOnCast(label_idx, cast_op, source, target) =>
      {
        rewritten: match
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
        },
        mentions_type_idxs: dfe_heap_type_mentions_type_idxs(source) ||
        dfe_heap_type_mentions_type_idxs(target),
      }
    @lib.BrOnCastFail(label_idx, cast_op, source, target) =>
      {
        rewritten: match
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
        },
        mentions_type_idxs: dfe_heap_type_mentions_type_idxs(source) ||
        dfe_heap_type_mentions_type_idxs(target),
      }
    _ => { rewritten: None, mentions_type_idxs: false }
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
    @lib.RefTest(nullable, heap_type) =>
      match dfe_try_rewrite_heap_type(heap_type, remap) {
        Some(next) => Some(@lib.Instruction::ref_test(nullable, next))
        None => None
      }
    @lib.RefCast(nullable, heap_type) =>
      match dfe_try_rewrite_heap_type(heap_type, remap) {
        Some(next) => Some(@lib.Instruction::ref_cast(nullable, next))
        None => None
      }
    @lib.RefTestDesc(nullable, heap_type) =>
      match dfe_try_rewrite_heap_type(heap_type, remap) {
        Some(next) => Some(@lib.Instruction::ref_test_desc(nullable, next))
        None => None
      }
    @lib.RefCastDescEq(nullable, heap_type) =>
      match dfe_try_rewrite_heap_type(heap_type, remap) {
        Some(next) => Some(@lib.Instruction::ref_cast_desc_eq(nullable, next))
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
fn dfe_rewrite_locals_type_idxs(
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
  perf? : HotPerfSession? = None,
  code_rewrite_flags? : Array[Bool]? = None,
) -> @lib.Module {
  let mut rewritten = mod_
  match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) => {
      let timer = dfe_perf_start_timer_opt(perf, "type-rewrite:type-sec")
      let next : Array[@lib.RecType] = []
      for rec_type in rec_types {
        next.push(dfe_rewrite_rec_type(rec_type, remap))
      }
      rewritten = rewritten.with_type_sec(@lib.TypeSec::new(next))
      dfe_perf_stop_timer_opt(perf, "type-rewrite:type-sec", timer)
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
      let timer = dfe_perf_start_timer_opt(perf, "type-rewrite:func-sec")
      let next : Array[@lib.TypeIdx] = []
      for type_idx in type_idxs {
        next.push(dfe_rewrite_type_idx(type_idx, remap))
      }
      rewritten = rewritten.with_func_sec(@lib.FuncSec::new(next))
      dfe_perf_stop_timer_opt(perf, "type-rewrite:func-sec", timer)
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
      let timer = dfe_perf_start_timer_opt(perf, "type-rewrite:code-sec")
      let next : Array[@lib.Func] = []
      match code_rewrite_flags {
        Some(flags) if flags.length() == funcs.length() => {
          let mut idx = 0
          while idx < funcs.length() {
            let func = funcs[idx]
            if flags[idx] {
              match dfe_try_rewrite_func_type_idxs(func, remap) {
                Some(rewritten_func) => next.push(rewritten_func)
                None => next.push(func)
              }
            } else {
              next.push(func)
            }
            idx += 1
          }
        }
        _ =>
          for func in funcs {
            match dfe_try_rewrite_func_type_idxs(func, remap) {
              Some(rewritten_func) => next.push(rewritten_func)
              None => next.push(func)
            }
          }
      }
      rewritten = rewritten.with_code_sec(@lib.CodeSec::new(next))
      dfe_perf_stop_timer_opt(perf, "type-rewrite:code-sec", timer)
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
  remap : Array[UInt],
) -> @lib.FuncIdx {
  let @lib.FuncIdx(raw) = idx
  let next = remap[raw.reinterpret_as_int()]
  if next == raw {
    idx
  } else {
    @lib.FuncIdx::new(next)
  }
}

///|
fn dfe_func_idx_is_remapped(idx : @lib.FuncIdx, remap : Array[UInt]) -> Bool {
  let @lib.FuncIdx(raw) = idx
  match remap.get(raw.reinterpret_as_int()) {
    Some(next) => next != raw
    None => false
  }
}

///|
fn dfe_rewrite_instruction_func_idxs(
  instr : @lib.Instruction,
  remap : Array[UInt],
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
      let rewritten_then : Array[@lib.Instruction] = Array::new(
        capacity=then_body.length(),
      )
      for nested in then_body {
        rewritten_then.push(dfe_rewrite_instruction_func_idxs(nested, remap))
      }
      let rewritten_else = match else_body {
        Some(body) => {
          let rewritten : Array[@lib.Instruction] = Array::new(
            capacity=body.length(),
          )
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
  remap : Array[UInt],
) -> @lib.Expr {
  let @lib.Expr(instrs) = expr
  let rewritten : Array[@lib.Instruction] = Array::new(capacity=instrs.length())
  for instr in instrs {
    rewritten.push(dfe_rewrite_instruction_func_idxs(instr, remap))
  }
  @lib.Expr::new(rewritten)
}

///|
fn dfe_rewrite_func_func_idxs(
  func : @lib.Func,
  remap : Array[UInt],
) -> @lib.Func {
  let @lib.Func(locals, body) = func
  @lib.Func::new(locals, dfe_rewrite_expr_func_idxs(body, remap))
}

///|
fn dfe_rewrite_extern_idx_func_idxs(
  idx : @lib.ExternIdx,
  remap : Array[UInt],
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
  remap : Array[UInt],
) -> @lib.Export {
  let @lib.Export(name, idx) = export_
  @lib.Export::new(name, dfe_rewrite_extern_idx_func_idxs(idx, remap))
}

///|
fn dfe_rewrite_elem_kind_func_idxs(
  kind : @lib.ElemKind,
  remap : Array[UInt],
) -> @lib.ElemKind {
  match kind {
    @lib.FuncsElemKind(funcs) => {
      let rewritten : Array[@lib.FuncIdx] = Array::new(capacity=funcs.length())
      for func_idx in funcs {
        rewritten.push(dfe_rewrite_func_idx(func_idx, remap))
      }
      @lib.ElemKind::funcs(rewritten)
    }
    @lib.FuncExprsElemKind(exprs) => {
      let rewritten : Array[@lib.Expr] = Array::new(capacity=exprs.length())
      for expr in exprs {
        rewritten.push(dfe_rewrite_expr_func_idxs(expr, remap))
      }
      @lib.ElemKind::func_exprs(rewritten)
    }
    @lib.TypedExprsElemKind(ref_type, exprs) => {
      let rewritten : Array[@lib.Expr] = Array::new(capacity=exprs.length())
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
  remap : Array[UInt],
  drop_unmapped : Bool,
) -> @lib.FuncAnnotationSec {
  let @lib.FuncAnnotationSec(entries) = sec
  let rewritten : Array[@lib.FuncAnnotationAssoc] = Array::new(
    capacity=entries.length(),
  )
  let mut last_idx : UInt? = None
  for entry in entries {
    let @lib.FuncAnnotationAssoc(idx, annotations) = entry
    match remap.get(idx.reinterpret_as_int()) {
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
  remap : Array[UInt],
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
  remap : Array[UInt],
  perf? : HotPerfSession? = None,
) -> @lib.Module {
  let mut rewritten = mod_
  match mod_.export_sec {
    Some(@lib.ExportSec(exports)) => {
      let next : Array[@lib.Export] = Array::new(capacity=exports.length())
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
      let next : Array[@lib.Elem] = Array::new(capacity=elems.length())
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
      let next : Array[@lib.Table] = Array::new(capacity=tables.length())
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
      let next : Array[@lib.Global] = Array::new(capacity=globals.length())
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
      let timer = dfe_perf_start_timer_opt(perf, "func-rewrite:code-sec")
      let next : Array[@lib.Func] = Array::new(capacity=funcs.length())
      for func in funcs {
        next.push(dfe_rewrite_func_func_idxs(func, remap))
      }
      rewritten = rewritten.with_code_sec(@lib.CodeSec::new(next))
      dfe_perf_stop_timer_opt(perf, "func-rewrite:code-sec", timer)
    }
    None => ()
  }
  match mod_.data_sec {
    Some(@lib.DataSec(datas)) => {
      let next : Array[@lib.Data] = Array::new(capacity=datas.length())
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
  let rewritten : Array[@lib.NameAssoc] = []
  let mut last_idx : UInt? = None
  for entry in entries {
    let @lib.NameAssoc(idx, name) = entry
    match remap.get(idx) {
      Some(next_idx) =>
        if canonical_sources.get(next_idx) == Some(idx) &&
          last_idx != Some(next_idx) {
          rewritten.push(@lib.NameAssoc::new(next_idx, name))
          last_idx = Some(next_idx)
        }
      None =>
        if !drop_unmapped && last_idx != Some(idx) {
          rewritten.push(entry)
          last_idx = Some(idx)
        }
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
  let rewritten : Array[@lib.IndirectNameAssoc] = []
  let mut last_idx : UInt? = None
  for entry in entries {
    let @lib.IndirectNameAssoc(idx, local_names) = entry
    match remap.get(idx) {
      Some(next_idx) =>
        if canonical_sources.get(next_idx) == Some(idx) &&
          last_idx != Some(next_idx) {
          rewritten.push(@lib.IndirectNameAssoc::new(next_idx, local_names))
          last_idx = Some(next_idx)
        }
      None =>
        if !drop_unmapped && last_idx != Some(idx) {
          rewritten.push(entry)
          last_idx = Some(idx)
        }
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
fn dfe_perf_start_timer_opt(perf : HotPerfSession?, name : String) -> UInt64 {
  match perf {
    Some(session) =>
      perf_start_timer(session, "detail:duplicate-function-elimination:\{name}")
    None => 0UL
  }
}

///|
fn dfe_perf_stop_timer_opt(
  perf : HotPerfSession?,
  name : String,
  start_us : UInt64,
) -> Unit {
  match perf {
    Some(session) =>
      perf_stop_timer(
        session,
        "detail:duplicate-function-elimination:\{name}",
        start_us,
      )
    None => ()
  }
}

///|
fn dfe_trace_opt(perf : HotPerfSession?, msg : String) -> Unit {
  match perf {
    Some(session) =>
      if session.enabled {
        (session.trace)("detail:duplicate-function-elimination:\{msg}")
      }
    None => ()
  }
}

///|
priv struct DfeIterationResult {
  mod_ : @lib.Module
  kept_type_rewrite_flags : Array[Bool]
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
fn dfe_instruction_sample_hash(instr : @lib.Instruction) -> Int {
  match instr {
    @lib.Block(block_type, @lib.Expr(instrs)) =>
      (1 * 31 + block_type.hash()) * 31 + instrs.length().hash()
    @lib.Loop(block_type, @lib.Expr(instrs)) =>
      (2 * 31 + block_type.hash()) * 31 + instrs.length().hash()
    @lib.If(block_type, then_body, else_body) => {
      let else_len = match else_body {
        Some(body) => body.length().hash()
        None => 0
      }
      ((3 * 31 + block_type.hash()) * 31 + then_body.length().hash()) * 31 +
      else_len
    }
    @lib.TryTable(block_type, catches, @lib.Expr(instrs)) =>
      ((4 * 31 + block_type.hash()) * 31 + catches.length().hash()) * 31 +
      instrs.length().hash()
    @lib.Call(func_idx) => 5 * 31 + func_idx.hash()
    @lib.ReturnCall(func_idx) => 6 * 31 + func_idx.hash()
    @lib.RefFunc(func_idx) => 7 * 31 + func_idx.hash()
    @lib.CallIndirect(type_idx, table_idx) =>
      (8 * 31 + type_idx.hash()) * 31 + table_idx.hash()
    @lib.ReturnCallIndirect(type_idx, table_idx) =>
      (9 * 31 + type_idx.hash()) * 31 + table_idx.hash()
    @lib.CallRef(type_idx) => 10 * 31 + type_idx.hash()
    @lib.ReturnCallRef(type_idx) => 11 * 31 + type_idx.hash()
    _ => instr.hash()
  }
}

///|
fn dfe_functions_equivalent(
  left_canon_type : UInt,
  left_func : @lib.Func,
  left_annotations : Array[@lib.FuncAnnotation],
  right_canon_type : UInt,
  right_func : @lib.Func,
  right_annotations : Array[@lib.FuncAnnotation],
) -> Bool {
  if !dfe_funcs_semantically_equal(left_func, right_func) ||
    left_annotations != right_annotations {
    return false
  }
  left_canon_type == right_canon_type
}

///|
fn dfe_functions_equivalent_no_annotations(
  left_canon_type : UInt,
  left_func : @lib.Func,
  right_canon_type : UInt,
  right_func : @lib.Func,
) -> Bool {
  if !dfe_funcs_semantically_equal(left_func, right_func) {
    return false
  }
  left_canon_type == right_canon_type
}

///|
fn dfe_function_hash_key(
  type_hash : Int,
  func : @lib.Func,
  annotations : Array[@lib.FuncAnnotation],
) -> Int {
  let @lib.Func(locals, body) = func
  let @lib.Expr(instrs) = body
  let mut key = (
      (dfe_locals_shape_hash(locals) * 31 + type_hash) * 31 +
      instrs.length().hash()
    ) *
    31 +
    annotations.hash()
  let sample_count = if instrs.length() < 3 { instrs.length() } else { 3 }
  let mut i = 0
  while i < sample_count {
    key = key * 31 + dfe_instruction_sample_hash(instrs[i])
    i += 1
  }
  let sample_start = if instrs.length() > sample_count {
    instrs.length() - sample_count
  } else {
    sample_count
  }
  if instrs.length() > sample_count + 1 {
    let quarter = instrs.length() / 4
    if quarter >= sample_count && quarter < sample_start {
      key = key * 31 + dfe_instruction_sample_hash(instrs[quarter])
    }
    let mid = instrs.length() / 2
    if mid >= sample_count && mid < sample_start && mid != quarter {
      key = key * 31 + dfe_instruction_sample_hash(instrs[mid])
    }
    let three_quarter = instrs.length() * 3 / 4
    if three_quarter >= sample_count &&
      three_quarter < sample_start &&
      three_quarter != mid &&
      three_quarter != quarter {
      key = key * 31 + dfe_instruction_sample_hash(instrs[three_quarter])
    }
  }
  i = sample_start
  while i < instrs.length() {
    key = key * 31 + dfe_instruction_sample_hash(instrs[i])
    i += 1
  }
  key
}

///|
fn dfe_function_hash_key_no_annotations(
  type_hash : Int,
  func : @lib.Func,
) -> Int {
  let @lib.Func(locals, body) = func
  let @lib.Expr(instrs) = body
  let mut key = (
      (dfe_locals_shape_hash(locals) * 31 + type_hash) * 31 +
      instrs.length().hash()
    ) *
    31
  let sample_count = if instrs.length() < 3 { instrs.length() } else { 3 }
  let mut i = 0
  while i < sample_count {
    key = key * 31 + dfe_instruction_sample_hash(instrs[i])
    i += 1
  }
  let sample_start = if instrs.length() > sample_count {
    instrs.length() - sample_count
  } else {
    sample_count
  }
  if instrs.length() > sample_count + 1 {
    let quarter = instrs.length() / 4
    if quarter >= sample_count && quarter < sample_start {
      key = key * 31 + dfe_instruction_sample_hash(instrs[quarter])
    }
    let mid = instrs.length() / 2
    if mid >= sample_count && mid < sample_start && mid != quarter {
      key = key * 31 + dfe_instruction_sample_hash(instrs[mid])
    }
    let three_quarter = instrs.length() * 3 / 4
    if three_quarter >= sample_count &&
      three_quarter < sample_start &&
      three_quarter != mid &&
      three_quarter != quarter {
      key = key * 31 + dfe_instruction_sample_hash(instrs[three_quarter])
    }
  }
  i = sample_start
  while i < instrs.length() {
    key = key * 31 + dfe_instruction_sample_hash(instrs[i])
    i += 1
  }
  key
}

///|
fn dfe_canonical_local_idx(replacements : Array[Int], local_idx : Int) -> Int {
  let mut current = local_idx
  while true {
    let next = replacements[current]
    if next >= 0 {
      current = next
    } else {
      return current
    }
  }
  current
}

///|
fn dfe_canonicalize_duplicate_simple_type_indices(
  mod_ : @lib.Module,
  perf? : HotPerfSession? = None,
  code_rewrite_flags? : Array[Bool]? = None,
) -> @lib.Module {
  match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) => {
      let map_timer = dfe_perf_start_timer_opt(perf, "type-canon:map")
      let canonical_old_idxs = dfe_duplicate_simple_type_canonical_map(
        rec_types,
      )
      dfe_perf_stop_timer_opt(perf, "type-canon:map", map_timer)
      if canonical_old_idxs.length() == 0 {
        return mod_
      }
      let keep_timer = dfe_perf_start_timer_opt(perf, "type-canon:kept-types")
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
      dfe_perf_stop_timer_opt(perf, "type-canon:kept-types", keep_timer)
      if kept_types.length() == rec_types.length() {
        return mod_
      }
      let remap_timer = dfe_perf_start_timer_opt(perf, "type-canon:remap")
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
      dfe_perf_stop_timer_opt(perf, "type-canon:remap", remap_timer)
      let rewrite_timer = dfe_perf_start_timer_opt(perf, "type-canon:rewrite")
      let rewritten = dfe_rewrite_module_type_idxs(
        mod_,
        type_remap,
        perf~,
        code_rewrite_flags~,
      )
      dfe_perf_stop_timer_opt(perf, "type-canon:rewrite", rewrite_timer)
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
fn dfe_iteration(
  mod_ : @lib.Module,
  perf? : HotPerfSession? = None,
) -> DfeIterationResult? {
  match (mod_.func_sec, mod_.code_sec) {
    (Some(@lib.FuncSec(type_idxs)), Some(@lib.CodeSec(funcs))) => {
      if type_idxs.length() != funcs.length() {
        return None
      }
      let type_canon_timer = dfe_perf_start_timer_opt(perf, "type-canon")
      let type_canon = match mod_.type_sec {
        Some(@lib.TypeSec(rec_types)) =>
          dfe_duplicate_simple_type_canonical_map(rec_types)
        None => {}
      }
      dfe_perf_stop_timer_opt(perf, "type-canon", type_canon_timer)
      let imported_count = dfe_imported_func_count(mod_)
      let annotations_by_abs_idx = dfe_func_annotation_map(mod_)
      let normalize_timer = dfe_perf_start_timer_opt(perf, "normalize-funcs")
      let mut normalized_rewrite_count = 0
      let normalized_mentions_type_idxs : Array[Bool] = Array::new(
        capacity=funcs.length(),
      )
      let normalized_funcs : Array[@lib.Func] = if type_canon.length() == 0 {
        for _ in funcs {
          normalized_mentions_type_idxs.push(false)
        }
        funcs
      } else {
        let rewritten : Array[@lib.Func] = Array::new(capacity=funcs.length())
        for func in funcs {
          let scan = dfe_scan_rewrite_func_type_idxs(func, type_canon)
          normalized_mentions_type_idxs.push(scan.mentions_type_idxs)
          match scan.rewritten {
            Some(next) => {
              normalized_rewrite_count += 1
              rewritten.push(next)
            }
            None => rewritten.push(func)
          }
        }
        rewritten
      }
      dfe_perf_stop_timer_opt(perf, "normalize-funcs", normalize_timer)
      dfe_trace_opt(
        perf,
        "normalize rewritten_funcs=\{normalized_rewrite_count} total_funcs=\{funcs.length()}",
      )
      let has_annotations = annotations_by_abs_idx.length() > 0
      let canonical_type_raws : Array[UInt] = Array::new(
        capacity=type_idxs.length(),
      )
      let canonical_type_hashes : Array[Int] = Array::new(
        capacity=type_idxs.length(),
      )
      for type_idx in type_idxs {
        let canonical_raw = match type_idx {
          @lib.TypeIdx(raw) => type_canon.get(raw).unwrap_or(raw)
          @lib.RecIdx(raw) => raw
        }
        canonical_type_raws.push(canonical_raw)
        canonical_type_hashes.push(canonical_raw.hash())
      }
      let normalized_annotations : Array[Array[@lib.FuncAnnotation]] = Array::new(
        capacity=funcs.length(),
      )
      let hash_group_timer = dfe_perf_start_timer_opt(perf, "hash-groups")
      let first_by_hash : @hashmap.HashMap[Int, Int] = @hashmap.new(
        capacity=funcs.length(),
      )
      let collision_group_by_hash : @hashmap.HashMap[Int, Int] = @hashmap.new(
        capacity=funcs.length() / 8 + 1,
      )
      let hash_groups : Array[Array[Int]] = []
      let mut local_idx = 0
      if has_annotations {
        while local_idx < funcs.length() {
          let abs_idx = imported_count + local_idx
          let annotations = dfe_func_annotations(
            annotations_by_abs_idx,
            abs_idx.reinterpret_as_uint(),
          )
          normalized_annotations.push(annotations)
          let key = dfe_function_hash_key(
            canonical_type_hashes[local_idx],
            normalized_funcs[local_idx],
            annotations,
          )
          match first_by_hash.get(key) {
            Some(first_idx) =>
              match collision_group_by_hash.get(key) {
                Some(group_idx) => hash_groups[group_idx].push(local_idx)
                None => {
                  collision_group_by_hash.set(key, hash_groups.length())
                  hash_groups.push([first_idx, local_idx])
                }
              }
            None => first_by_hash.set(key, local_idx)
          }
          local_idx += 1
        }
      } else {
        while local_idx < funcs.length() {
          let key = dfe_function_hash_key_no_annotations(
            canonical_type_hashes[local_idx],
            normalized_funcs[local_idx],
          )
          match first_by_hash.get(key) {
            Some(first_idx) =>
              match collision_group_by_hash.get(key) {
                Some(group_idx) => hash_groups[group_idx].push(local_idx)
                None => {
                  collision_group_by_hash.set(key, hash_groups.length())
                  hash_groups.push([first_idx, local_idx])
                }
              }
            None => first_by_hash.set(key, local_idx)
          }
          local_idx += 1
        }
      }
      dfe_perf_stop_timer_opt(perf, "hash-groups", hash_group_timer)
      dfe_trace_opt(
        perf,
        "hash groups=\{hash_groups.length()} singleton_hashes=\{first_by_hash.length()}",
      )

      let replacements : Array[Int] = Array::make(funcs.length(), -1)
      let mut changed = false
      let mut comparison_count = 0
      let mut replacement_count = 0
      let collision_timer = dfe_perf_start_timer_opt(perf, "collision-check")
      for group in hash_groups {
        if group.length() <= 1 {
          continue
        }
        let mut i = 0
        while i < group.length() - 1 {
          let first = group[i]
          if replacements[first] >= 0 {
            i += 1
            continue
          }
          let mut j = i + 1
          while j < group.length() {
            let second = group[j]
            if replacements[second] >= 0 {
              j += 1
              continue
            }
            comparison_count += 1
            let equivalent = if has_annotations {
              dfe_functions_equivalent(
                canonical_type_raws[first],
                normalized_funcs[first],
                normalized_annotations[first],
                canonical_type_raws[second],
                normalized_funcs[second],
                normalized_annotations[second],
              )
            } else {
              dfe_functions_equivalent_no_annotations(
                canonical_type_raws[first],
                normalized_funcs[first],
                canonical_type_raws[second],
                normalized_funcs[second],
              )
            }
            if equivalent {
              replacements[second] = first
              changed = true
              replacement_count += 1
            }
            j += 1
          }
          i += 1
        }
      }
      dfe_perf_stop_timer_opt(perf, "collision-check", collision_timer)
      dfe_trace_opt(
        perf,
        "collision comparisons=\{comparison_count} replacements=\{replacement_count}",
      )

      if !changed {
        return None
      }

      let rebuild_timer = dfe_perf_start_timer_opt(perf, "rebuild")
      let kept_types : Array[@lib.TypeIdx] = Array::new(capacity=funcs.length())
      let kept_funcs : Array[@lib.Func] = Array::new(capacity=funcs.length())
      let kept_type_rewrite_flags : Array[Bool] = Array::new(
        capacity=funcs.length(),
      )
      let track_kept_type_rewrite_flags = type_canon.length() != 0
      let kept_abs : Array[Int] = Array::make(funcs.length(), -1)
      let kept_timer = dfe_perf_start_timer_opt(perf, "rebuild:kept")
      let mut next_abs = imported_count.reinterpret_as_uint()
      let mut idx = 0
      while idx < funcs.length() {
        if replacements[idx] < 0 {
          kept_abs[idx] = next_abs.reinterpret_as_int()
          kept_types.push(type_idxs[idx])
          kept_funcs.push(normalized_funcs[idx])
          kept_type_rewrite_flags.push(
            track_kept_type_rewrite_flags && normalized_mentions_type_idxs[idx],
          )
          next_abs += 1U
        }
        idx += 1
      }
      dfe_perf_stop_timer_opt(perf, "rebuild:kept", kept_timer)
      dfe_trace_opt(
        perf,
        "rebuild kept_funcs=\{kept_funcs.length()} removed_funcs=\{funcs.length() - kept_funcs.length()}",
      )

      let remap_timer = dfe_perf_start_timer_opt(perf, "rebuild:remap")
      let abs_remap : Array[UInt] = Array::new(
        capacity=imported_count + funcs.length(),
      )
      let mut import_idx = 0
      while import_idx < imported_count {
        abs_remap.push(import_idx.reinterpret_as_uint())
        import_idx += 1
      }

      idx = 0
      while idx < funcs.length() {
        let canonical = dfe_canonical_local_idx(replacements, idx)
        let next = kept_abs[canonical]
        if next >= 0 {
          abs_remap.push(next.reinterpret_as_uint())
        } else {
          return None
        }
        idx += 1
      }
      dfe_perf_stop_timer_opt(perf, "rebuild:remap", remap_timer)

      let compacted = mod_
        .without_name_sec()
        .with_func_sec(@lib.FuncSec::new(kept_types))
        .with_code_sec(@lib.CodeSec::new(kept_funcs))
      let rewrite_timer = dfe_perf_start_timer_opt(
        perf, "rebuild:rewrite-module",
      )
      let rewritten = dfe_rewrite_module_func_idxs(compacted, abs_remap, perf~)
      dfe_perf_stop_timer_opt(perf, "rebuild:rewrite-module", rewrite_timer)
      dfe_perf_stop_timer_opt(perf, "rebuild", rebuild_timer)
      Some({ mod_: rewritten, kept_type_rewrite_flags })
    }
    _ => None
  }
}

///|
fn dfe_run_module_pass_with_perf(
  mod_ : @lib.Module,
  perf : HotPerfSession?,
) -> @lib.Module {
  let iteration_timer = dfe_perf_start_timer_opt(perf, "iteration")
  let iteration = match dfe_iteration(mod_, perf~) {
    Some(next) => next
    None => {
      dfe_perf_stop_timer_opt(perf, "iteration", iteration_timer)
      let elem_timer = dfe_perf_start_timer_opt(
        perf, "canonicalize-elem-segments",
      )
      let rewritten = dfe_strip_name_sec(dfe_canonicalize_elem_segments(mod_))
      dfe_perf_stop_timer_opt(perf, "canonicalize-elem-segments", elem_timer)
      return rewritten
    }
  }
  dfe_perf_stop_timer_opt(perf, "iteration", iteration_timer)
  let elem_timer = dfe_perf_start_timer_opt(perf, "canonicalize-elem-segments")
  let with_elem_segments = dfe_canonicalize_elem_segments(iteration.mod_)
  dfe_perf_stop_timer_opt(perf, "canonicalize-elem-segments", elem_timer)
  let type_timer = dfe_perf_start_timer_opt(
    perf, "canonicalize-duplicate-types",
  )
  let rewritten = dfe_canonicalize_duplicate_simple_type_indices(
    with_elem_segments,
    perf~,
    code_rewrite_flags=Some(iteration.kept_type_rewrite_flags),
  )
  dfe_perf_stop_timer_opt(perf, "canonicalize-duplicate-types", type_timer)
  rewritten
}

///|
pub fn dfe_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  dfe_run_module_pass_with_perf(mod_, None)
}
