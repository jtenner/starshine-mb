///|
fn sr_make_func_type(
  params : Array[ValType],
  results : Array[ValType],
) -> RecType {
  single_rec_type(comp_type_sub_type(func_comp_type(params, results)))
}

///|
fn sr_count_imported_funcs(mod : Module) -> Int {
  let mut n = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        let Import(_, _, ex) = import_
        match ex {
          FuncExternType(_) => n += 1
          _ => ()
        }
      }
    None => ()
  }
  n
}

///|
fn sr_name_to_string(n : Name) -> String {
  let Name(sv) = n
  sv.to_string()
}

///|
fn sr_collect_import_call_without_effects(mod : Module) -> Array[Bool] {
  let out : Array[Bool] = []
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(module_name, base_name, FuncExternType(_)) => {
            let module_s = sr_name_to_string(module_name)
            let base_s = sr_name_to_string(base_name)
            out.push(
              base_s == "call.without.effects" &&
              (
                module_s == "binaryen-intrinsics" ||
                module_s == "binaryen-intrinsics-optimized"
              ),
            )
          }
          _ => ()
        }
      }
    None => ()
  }
  out
}

///|
fn sr_collect_func_type_idxs(mod : Module) -> Array[TypeIdx] {
  let out : Array[TypeIdx] = []
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        let Import(_, _, ex) = import_
        match ex {
          FuncExternType(type_idx) => out.push(type_idx)
          _ => ()
        }
      }
    None => ()
  }
  match mod.func_sec {
    Some(FuncSec(type_idxs)) =>
      for type_idx in type_idxs {
        out.push(type_idx)
      }
    None => ()
  }
  out
}

///|
fn sr_typeidx_raw(type_idx : TypeIdx) -> Int {
  match type_idx {
    TypeIdx(i) => i.reinterpret_as_int()
    RecIdx(i) => i.reinterpret_as_int()
  }
}

///|
fn sr_resolve_type_idx(
  type_idx : TypeIdx,
  group_start : Int,
  total : Int,
) -> Int? {
  let idx = match type_idx {
    TypeIdx(i) => i.reinterpret_as_int()
    RecIdx(i) => group_start + i.reinterpret_as_int()
  }
  if idx < 0 || idx >= total {
    None
  } else {
    Some(idx)
  }
}

///|
fn sr_flattened_type_count(rec_types : Array[RecType]) -> Int {
  let mut n = 0
  for rec_type in rec_types {
    match rec_type {
      SingleRecType(_) => n += 1
      GroupRecType(sub_types) => n += sub_types.length()
    }
  }
  n
}

///|
fn sr_collect_valtype_refs(
  out : Array[Int],
  vt : ValType,
  group_start : Int,
  total : Int,
) -> Unit {
  match vt {
    RefTypeValType(rt) =>
      match rt {
        HeapTypeRefType(_, ht) =>
          match ht {
            HeapType(type_idx) =>
              match sr_resolve_type_idx(type_idx, group_start, total) {
                Some(idx) => out.push(idx)
                None => ()
              }
            _ => ()
          }
        _ => ()
      }
    _ => ()
  }
}

///|
fn sr_collect_storage_refs(
  out : Array[Int],
  st : StorageType,
  group_start : Int,
  total : Int,
) -> Unit {
  match st {
    ValTypeStorageType(vt) =>
      sr_collect_valtype_refs(out, vt, group_start, total)
    _ => ()
  }
}

///|
fn sr_collect_subtype_refs(
  subtype : SubType,
  group_start : Int,
  total : Int,
) -> Array[Int] {
  let out : Array[Int] = []
  for super_idx in subtype.super_types() {
    match sr_resolve_type_idx(super_idx, group_start, total) {
      Some(idx) => out.push(idx)
      None => ()
    }
  }
  match subtype.get_comptype() {
    FuncCompType(params, results) => {
      for p in params {
        sr_collect_valtype_refs(out, p, group_start, total)
      }
      for r in results {
        sr_collect_valtype_refs(out, r, group_start, total)
      }
    }
    StructCompType(fields) =>
      for field in fields {
        let FieldType(st, _) = field
        sr_collect_storage_refs(out, st, group_start, total)
      }
    ArrayCompType(field) => {
      let FieldType(st, _) = field
      sr_collect_storage_refs(out, st, group_start, total)
    }
  }
  out
}

///|
fn sr_collect_all_global_types(mod : Module) -> Array[GlobalType] {
  let out : Array[GlobalType] = []
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, GlobalExternType(global_type)) => out.push(global_type)
          _ => ()
        }
      }
    None => ()
  }
  match mod.global_sec {
    Some(GlobalSec(globals)) =>
      for global in globals {
        let Global(global_type, _) = global
        out.push(global_type)
      }
    None => ()
  }
  out
}

///|
fn sr_collect_all_table_types(mod : Module) -> Array[TableType] {
  let out : Array[TableType] = []
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, TableExternType(table_type)) => out.push(table_type)
          _ => ()
        }
      }
    None => ()
  }
  match mod.table_sec {
    Some(TableSec(tables)) =>
      for table in tables {
        let Table(table_type, _) = table
        out.push(table_type)
      }
    None => ()
  }
  out
}

///|
fn sr_collect_all_tag_types(mod : Module) -> Array[TagType] {
  let out : Array[TagType] = []
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, TagExternType(tag_type)) => out.push(tag_type)
          _ => ()
        }
      }
    None => ()
  }
  match mod.tag_sec {
    Some(TagSec(tags)) =>
      for tag in tags {
        out.push(tag)
      }
    None => ()
  }
  out
}

///|
fn sr_mark_public_type(
  public_types : Set[Int],
  subtypes : Array[SubType],
  group_starts : Array[Int],
  total : Int,
  idx : Int,
) -> Unit {
  let stack : Array[Int] = [idx]
  while !stack.is_empty() {
    let curr = stack.pop().unwrap()
    if curr < 0 || curr >= subtypes.length() || public_types.contains(curr) {
      continue
    }
    public_types.add(curr)
    for
      ref_ in sr_collect_subtype_refs(subtypes[curr], group_starts[curr], total) {
      stack.push(ref_)
    }
  }
}

///|
fn sr_mark_public_valtype(
  public_types : Set[Int],
  subtypes : Array[SubType],
  group_starts : Array[Int],
  total : Int,
  vt : ValType,
) -> Unit {
  match vt {
    RefTypeValType(HeapTypeRefType(_, HeapType(type_idx))) =>
      match sr_resolve_type_idx(type_idx, 0, total) {
        Some(idx) =>
          sr_mark_public_type(public_types, subtypes, group_starts, total, idx)
        None => ()
      }
    _ => ()
  }
}

///|
fn sr_mark_public_reftype(
  public_types : Set[Int],
  subtypes : Array[SubType],
  group_starts : Array[Int],
  total : Int,
  rt : RefType,
) -> Unit {
  match rt {
    HeapTypeRefType(_, HeapType(type_idx)) =>
      match sr_resolve_type_idx(type_idx, 0, total) {
        Some(idx) =>
          sr_mark_public_type(public_types, subtypes, group_starts, total, idx)
        None => ()
      }
    _ => ()
  }
}

///|
fn sr_collect_public_types(
  mod : Module,
  subtypes : Array[SubType],
  group_starts : Array[Int],
  total : Int,
  func_type_idxs : Array[TypeIdx],
) -> Set[Int] {
  let public_types : Set[Int] = Set::new()
  let global_types = sr_collect_all_global_types(mod)
  let table_types = sr_collect_all_table_types(mod)
  let tag_types = sr_collect_all_tag_types(mod)

  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(type_idx)) =>
            match sr_resolve_type_idx(type_idx, 0, total) {
              Some(idx) =>
                sr_mark_public_type(
                  public_types, subtypes, group_starts, total, idx,
                )
              None => ()
            }
          Import(_, _, TagExternType(TagType(type_idx))) =>
            match sr_resolve_type_idx(type_idx, 0, total) {
              Some(idx) =>
                sr_mark_public_type(
                  public_types, subtypes, group_starts, total, idx,
                )
              None => ()
            }
          Import(_, _, GlobalExternType(GlobalType(vt, _))) =>
            sr_mark_public_valtype(
              public_types, subtypes, group_starts, total, vt,
            )
          Import(_, _, TableExternType(TableType(rt, _))) =>
            sr_mark_public_reftype(
              public_types, subtypes, group_starts, total, rt,
            )
          _ => ()
        }
      }
    None => ()
  }

  match mod.export_sec {
    Some(ExportSec(exports)) =>
      for export_ in exports {
        let Export(_, extern_idx) = export_
        match extern_idx {
          FuncExternIdx(FuncIdx(raw)) => {
            let idx = raw.reinterpret_as_int()
            if idx >= 0 && idx < func_type_idxs.length() {
              match sr_resolve_type_idx(func_type_idxs[idx], 0, total) {
                Some(type_abs) =>
                  sr_mark_public_type(
                    public_types, subtypes, group_starts, total, type_abs,
                  )
                None => ()
              }
            }
          }
          GlobalExternIdx(GlobalIdx(raw)) => {
            let idx = raw.reinterpret_as_int()
            if idx >= 0 && idx < global_types.length() {
              let GlobalType(vt, _) = global_types[idx]
              sr_mark_public_valtype(
                public_types, subtypes, group_starts, total, vt,
              )
            }
          }
          TableExternIdx(TableIdx(raw)) => {
            let idx = raw.reinterpret_as_int()
            if idx >= 0 && idx < table_types.length() {
              let TableType(rt, _) = table_types[idx]
              sr_mark_public_reftype(
                public_types, subtypes, group_starts, total, rt,
              )
            }
          }
          TagExternIdx(TagIdx(raw)) => {
            let idx = raw.reinterpret_as_int()
            if idx >= 0 && idx < tag_types.length() {
              let TagType(type_idx) = tag_types[idx]
              match sr_resolve_type_idx(type_idx, 0, total) {
                Some(type_abs) =>
                  sr_mark_public_type(
                    public_types, subtypes, group_starts, total, type_abs,
                  )
                None => ()
              }
            }
          }
          _ => ()
        }
      }
    None => ()
  }

  let initially_public : Array[Int] = []
  for idx in public_types {
    initially_public.push(idx)
  }
  for idx in initially_public {
    let group_start = group_starts[idx]
    for i = 0; i < group_starts.length(); i = i + 1 {
      if group_starts[i] == group_start {
        public_types.add(i)
      }
    }
  }
  public_types
}

///|
fn sr_collect_subtypes(
  rec_types : Array[RecType],
) -> (Array[SubType], Array[Int], Array[Array[Int]], Array[Bool]) {
  let subtypes : Array[SubType] = []
  let group_starts : Array[Int] = []
  let mut next = 0
  for rec in rec_types {
    match rec {
      SingleRecType(st) => {
        subtypes.push(st)
        group_starts.push(next)
        next += 1
      }
      GroupRecType(sts) => {
        let start = next
        for st in sts {
          subtypes.push(st)
          group_starts.push(start)
          next += 1
        }
      }
    }
  }

  let immediate_subs : Array[Array[Int]] = []
  let has_declared_super : Array[Bool] = []
  for _ in 0..<subtypes.length() {
    immediate_subs.push([])
    has_declared_super.push(false)
  }

  for i = 0; i < subtypes.length(); i = i + 1 {
    let supers = subtypes[i].super_types()
    if !supers.is_empty() {
      has_declared_super[i] = true
    }
    for super_idx in supers {
      match sr_resolve_type_idx(super_idx, group_starts[i], subtypes.length()) {
        Some(super_abs) => immediate_subs[super_abs].push(i)
        None => ()
      }
    }
  }

  (subtypes, group_starts, immediate_subs, has_declared_super)
}

///|
fn sr_mark_exports_unseen(mod : Module, has_unseen : Array[Bool]) -> Unit {
  match mod.export_sec {
    Some(ExportSec(exports)) =>
      for export_ in exports {
        let Export(_, extern_idx) = export_
        match extern_idx {
          FuncExternIdx(FuncIdx(raw)) => {
            let idx = raw.reinterpret_as_int()
            if idx >= 0 && idx < has_unseen.length() {
              has_unseen[idx] = true
            }
          }
          _ => ()
        }
      }
    None => ()
  }
}

///|
fn sr_mark_start_unseen(mod : Module, has_unseen : Array[Bool]) -> Unit {
  match mod.start_sec {
    Some(StartSec(FuncIdx(raw))) => {
      let idx = raw.reinterpret_as_int()
      if idx >= 0 && idx < has_unseen.length() {
        has_unseen[idx] = true
      }
    }
    None => ()
  }
}

///|
fn sr_mark_elem_unseen(mod : Module, has_unseen : Array[Bool]) -> Unit {
  match mod.elem_sec {
    Some(ElemSec(elems)) =>
      for elem in elems {
        let Elem(_, kind) = elem
        match kind {
          FuncsElemKind(funcs) =>
            for func_idx in funcs {
              let FuncIdx(raw) = func_idx
              let idx = raw.reinterpret_as_int()
              if idx >= 0 && idx < has_unseen.length() {
                has_unseen[idx] = true
              }
            }
          FuncExprsElemKind(exprs) | TypedExprsElemKind(_, exprs) =>
            for expr in exprs {
              for instr in expr.0 {
                match instr {
                  RefFunc(FuncIdx(raw)) => {
                    let idx = raw.reinterpret_as_int()
                    if idx >= 0 && idx < has_unseen.length() {
                      has_unseen[idx] = true
                    }
                  }
                  _ => ()
                }
              }
            }
        }
      }
    None => ()
  }
}

///|
fn sr_collect_global_types(mod : Module) -> Array[ValType] {
  let out : Array[ValType] = []
  match mod.global_sec {
    Some(GlobalSec(globals)) =>
      for global in globals {
        let Global(GlobalType(vt, _), _) = global
        out.push(vt)
      }
    None => ()
  }
  out
}

///|
fn sr_collect_func_types(env : Env, total : Int) -> Array[FuncType] {
  let out : Array[FuncType] = []
  for i = 0; i < total; i = i + 1 {
    let idx = FuncIdx::new(i.reinterpret_as_uint())
    match env.get_functype_by_funcidx(idx) {
      Some(ft) => out.push(ft)
      None => out.push(FuncType::new([], []))
    }
  }
  out
}

///|
fn sr_build_local_types_by_abs(
  func_types : Array[FuncType],
  funcs : Array[Func],
  import_func_count : Int,
) -> Array[Array[ValType]] {
  let out : Array[Array[ValType]] = []
  for abs_idx = 0; abs_idx < func_types.length(); abs_idx = abs_idx + 1 {
    let FuncType(params, _) = func_types[abs_idx]
    let locals = params.copy()
    let def_idx = abs_idx - import_func_count
    if def_idx >= 0 && def_idx < funcs.length() {
      match funcs[def_idx] {
        TFunc(extra_locals, _) =>
          for vt in extra_locals {
            locals.push(vt)
          }
        _ => ()
      }
    }
    out.push(locals)
  }
  out
}

///|
fn sr_is_func_heap(ht : HeapType, env : Env) -> Bool {
  match ht {
    AbsHeapTypeHeapType(FuncAbsHeapType) => true
    HeapType(tidx) =>
      match env.resolve_comptype(tidx) {
        Some(FuncCompType(_, _)) => true
        _ => false
      }
    _ => false
  }
}

///|
fn sr_common_ref_heap_supertype(
  a : HeapType,
  b : HeapType,
  env : Env,
) -> HeapType? {
  if Match::matches(a, b, env) {
    return Some(b)
  }
  if Match::matches(b, a, env) {
    return Some(a)
  }

  let candidates = [
    AbsHeapType::i31(),
    AbsHeapType::struct_(),
    AbsHeapType::array(),
    AbsHeapType::eq(),
    AbsHeapType::func(),
    AbsHeapType::extern_(),
    AbsHeapType::exn(),
    AbsHeapType::any(),
  ]
  for abs in candidates {
    let super_ht = HeapType::abs(abs)
    if Match::matches(a, super_ht, env) && Match::matches(b, super_ht, env) {
      return Some(super_ht)
    }
  }

  if sr_is_func_heap(a, env) && sr_is_func_heap(b, env) {
    return Some(HeapType::abs(AbsHeapType::func()))
  }

  None
}

///|
fn sr_common_ref_type_supertype(
  a : RefType,
  b : RefType,
  env : Env,
) -> RefType? {
  if Match::matches(a, b, env) {
    return Some(b)
  }
  if Match::matches(b, a, env) {
    return Some(a)
  }
  match
    sr_common_ref_heap_supertype(a.get_heap_type(), b.get_heap_type(), env) {
    Some(ht) => Some(RefType::new(a.is_nullable() || b.is_nullable(), ht))
    None => None
  }
}

///|
fn sr_common_val_supertype(a : ValType, b : ValType, env : Env) -> ValType? {
  if Match::matches(a, b, env) {
    return Some(b)
  }
  if Match::matches(b, a, env) {
    return Some(a)
  }
  match (a, b) {
    (RefTypeValType(r0), RefTypeValType(r1)) =>
      match sr_common_ref_type_supertype(r0, r1, env) {
        Some(rt) => Some(ValType::ref_type(rt))
        None => None
      }
    _ => None
  }
}

///|
fn sr_single_result_of_blocktype(bt : BlockType, env : Env) -> ValType? {
  match env.expand_blocktype(bt) {
    Ok((_, [vt])) => Some(vt)
    _ => None
  }
}

///|
fn sr_known_instr_type(
  instr : TInstr,
  caller_abs_idx : Int,
  local_types_by_abs : Array[Array[ValType]],
  global_types : Array[ValType],
  env : Env,
  func_type_idxs : Array[TypeIdx],
) -> ValType? {
  fn infer_texpr_type(texpr : TExpr) -> ValType? {
    let TExpr(instrs) = texpr
    if instrs.is_empty() {
      None
    } else {
      sr_known_instr_type(
        instrs[instrs.length() - 1],
        caller_abs_idx,
        local_types_by_abs,
        global_types,
        env,
        func_type_idxs,
      )
    }
  }

  match instr {
    TI32Const(_) => Some(ValType::i32())
    TI64Const(_) => Some(ValType::i64())
    TF32Const(_) => Some(ValType::f32())
    TF64Const(_) => Some(ValType::f64())
    TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      Some(ValType::v128())
    TRefNull(ht) => Some(ValType::ref_type(RefType::new(true, ht)))
    TRefFunc(_) => Some(ValType::funcref())
    TLocalGet(LocalIdx(raw)) => {
      let idx = raw.reinterpret_as_int()
      if caller_abs_idx < 0 || caller_abs_idx >= local_types_by_abs.length() {
        return None
      }
      let locals = local_types_by_abs[caller_abs_idx]
      if idx < 0 || idx >= locals.length() {
        return None
      }
      Some(locals[idx])
    }
    TGlobalGet(GlobalIdx(raw)) => {
      let idx = raw.reinterpret_as_int()
      if idx < 0 || idx >= global_types.length() {
        return None
      }
      Some(global_types[idx])
    }
    TLocalTee(_, value) =>
      sr_known_instr_type(
        value, caller_abs_idx, local_types_by_abs, global_types, env, func_type_idxs,
      )
    TRefAsNonNull(value) =>
      match
        sr_known_instr_type(
          value, caller_abs_idx, local_types_by_abs, global_types, env, func_type_idxs,
        ) {
        Some(RefTypeValType(rt)) =>
          Some(ValType::ref_type(RefType::new(false, rt.get_heap_type())))
        _ => None
      }
    TRefCast(nullable, ht, _) =>
      Some(ValType::ref_type(RefType::new(nullable, ht)))
    TCall(target, _) | TReturnCall(target, _) =>
      match env.get_functype_by_funcidx(target) {
        Some(FuncType(_, [r])) => Some(r)
        _ => None
      }
    TCallIndirect(type_idx, _, _, _)
    | TCallRef(type_idx, _, _)
    | TReturnCallIndirect(type_idx, _, _, _)
    | TReturnCallRef(type_idx, _, _) =>
      match env.resolve_functype(type_idx) {
        Some(FuncType(_, [r])) => Some(r)
        _ => None
      }
    TBlock(bt, body) | TLoop(bt, body) | TTryTable(bt, _, body) => {
      let from_body = infer_texpr_type(body)
      let from_bt = sr_single_result_of_blocktype(bt, env)
      match (from_body, from_bt) {
        (Some(t), Some(vt)) =>
          if Match::matches(t, vt, env) {
            Some(t)
          } else {
            Some(vt)
          }
        (Some(t), None) => Some(t)
        (None, Some(vt)) => Some(vt)
        _ => None
      }
    }
    TIf(bt, _, then_, else_) => {
      let from_bt = sr_single_result_of_blocktype(bt, env)
      let from_branches = match else_ {
        Some(else_expr) =>
          match (infer_texpr_type(then_), infer_texpr_type(else_expr)) {
            (Some(t), Some(e)) => sr_common_val_supertype(t, e, env)
            _ => None
          }
        None => None
      }
      match (from_branches, from_bt) {
        (Some(t), Some(vt)) =>
          if Match::matches(t, vt, env) {
            Some(t)
          } else {
            Some(vt)
          }
        (Some(t), None) => Some(t)
        (None, Some(vt)) => Some(vt)
        _ => None
      }
    }
    TSelect(types, _, if_true, if_false) => {
      let declared = match types {
        Some([vt]) => Some(vt)
        _ => None
      }
      let merged = match
        (
          sr_known_instr_type(
            if_true, caller_abs_idx, local_types_by_abs, global_types, env, func_type_idxs,
          ),
          sr_known_instr_type(
            if_false, caller_abs_idx, local_types_by_abs, global_types, env, func_type_idxs,
          ),
        ) {
        (Some(t), Some(f)) => sr_common_val_supertype(t, f, env)
        _ => None
      }
      match (merged, declared) {
        (Some(t), Some(vt)) =>
          if Match::matches(t, vt, env) {
            Some(t)
          } else {
            Some(vt)
          }
        (Some(t), None) => Some(t)
        (None, Some(vt)) => Some(vt)
        _ => None
      }
    }
    _ => None
  }
}

///|
fn sr_note_result_observation(
  type_abs : Int,
  observed : ValType,
  old_result : ValType,
  result_candidate : Array[ValType?],
  result_noted : Array[Bool],
  result_unknown : Array[Bool],
  env : Env,
) -> Unit {
  if type_abs < 0 || type_abs >= result_candidate.length() {
    return
  }
  if !Match::matches(observed, old_result, env) {
    result_unknown[type_abs] = true
    return
  }
  match result_candidate[type_abs] {
    None => {
      result_candidate[type_abs] = Some(observed)
      result_noted[type_abs] = true
    }
    Some(prev) =>
      match sr_common_val_supertype(prev, observed, env) {
        Some(merged) =>
          if Match::matches(merged, old_result, env) {
            result_candidate[type_abs] = Some(merged)
            result_noted[type_abs] = true
          } else {
            result_unknown[type_abs] = true
          }
        None => result_unknown[type_abs] = true
      }
  }
}

///|
priv struct SRCallSite {
  caller_abs_idx : Int
  args : Array[TInstr]
}

///|
fn sr_callsite(caller_abs_idx : Int, args : Array[TInstr]) -> SRCallSite {
  { caller_abs_idx, args }
}

///|
fn sr_record_callsite(
  type_abs : Int,
  caller_abs_idx : Int,
  args : Array[TInstr],
  calls_by_type : Array[Array[SRCallSite]],
) -> Unit {
  if type_abs < 0 || type_abs >= calls_by_type.length() {
    return
  }
  calls_by_type[type_abs].push(sr_callsite(caller_abs_idx, args.copy()))
}

///|
fn sr_local_idx_to_int(idx : LocalIdx) -> Int {
  let LocalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn sr_local_idx_from_int(i : Int) -> LocalIdx {
  LocalIdx::new(i.reinterpret_as_uint())
}

///|
fn sr_update_param_types(
  body : TExpr,
  old_param_types : Array[ValType],
  new_param_types : Array[ValType],
  locals : Array[ValType],
  local_types_by_abs : Array[Array[ValType]],
  global_types : Array[ValType],
  env : Env,
  abs_idx : Int,
  func_type_idxs : Array[TypeIdx],
) -> (Array[ValType], TExpr) {
  let param_fixups : Map[Int, Int] = Map::new()
  let next_local = [old_param_types.length() + locals.length()]

  let scan_sets = ModuleTransformer::new().on_tinstruction_evt(fn(
    self,
    _,
    instr,
  ) {
    match instr {
      TLocalSet(idx, value) | TLocalTee(idx, value) => {
        let local_i = sr_local_idx_to_int(idx)
        if local_i >= 0 &&
          local_i < old_param_types.length() &&
          !param_fixups.contains(local_i) {
          let compatible = match
            sr_known_instr_type(
              value, abs_idx, local_types_by_abs, global_types, env, func_type_idxs,
            ) {
            Some(vt) => Match::matches(vt, new_param_types[local_i], env)
            None => false
          }
          if !compatible {
            let fixup = next_local[0]
            next_local[0] = fixup + 1
            param_fixups[local_i] = fixup
          }
        }
      }
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(scan_sets.walk_texpr((), body))

  let next_locals = locals.copy()
  let param_count = old_param_types.length()
  for i = 0; i < param_count; i = i + 1 {
    match param_fixups.get(i) {
      Some(_) => next_locals.push(old_param_types[i])
      None => ()
    }
  }

  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    let walked = match self.walk_tinstruction_default((), instr) {
      Ok(Some((_, out))) => out
      Ok(None) => instr
      Err(e) => return Err(e)
    }
    match walked {
      TLocalGet(idx) => {
        let local_i = sr_local_idx_to_int(idx)
        match param_fixups.get(local_i) {
          Some(fixup) =>
            change((), TInstr::local_get(sr_local_idx_from_int(fixup)))
          None => if walked == instr { unchanged() } else { change((), walked) }
        }
      }
      TLocalSet(idx, value) => {
        let local_i = sr_local_idx_to_int(idx)
        match param_fixups.get(local_i) {
          Some(fixup) =>
            change((), TInstr::local_set(sr_local_idx_from_int(fixup), value))
          None => if walked == instr { unchanged() } else { change((), walked) }
        }
      }
      TLocalTee(idx, value) => {
        let local_i = sr_local_idx_to_int(idx)
        match param_fixups.get(local_i) {
          Some(fixup) =>
            change((), TInstr::local_tee(sr_local_idx_from_int(fixup), value))
          None => if walked == instr { unchanged() } else { change((), walked) }
        }
      }
      _ => if walked == instr { unchanged() } else { change((), walked) }
    }
  })

  let rewritten = match walker.walk_texpr((), body) {
    Ok(Some((_, out))) => out
    _ => body
  }

  if param_fixups.is_empty() {
    return (next_locals, rewritten)
  }

  let prologue : Array[TInstr] = []
  for i = 0; i < param_count; i = i + 1 {
    match param_fixups.get(i) {
      Some(fixup) =>
        prologue.push(
          TInstr::local_set(
            sr_local_idx_from_int(fixup),
            TInstr::local_get(sr_local_idx_from_int(i)),
          ),
        )
      None => ()
    }
  }

  let next_body = TExpr::new([..prologue, ..rewritten.0])
  (next_locals, next_body)
}

///|
fn sr_extract_signature_type_abs_from_instr(
  instr : TInstr,
  caller_abs_idx : Int,
  local_types_by_abs : Array[Array[ValType]],
  global_types : Array[ValType],
  env : Env,
  func_type_idxs : Array[TypeIdx],
) -> Int? {
  match instr {
    TRefFunc(FuncIdx(raw)) => {
      let idx = raw.reinterpret_as_int()
      if idx < 0 || idx >= func_type_idxs.length() {
        None
      } else {
        Some(sr_typeidx_raw(func_type_idxs[idx]))
      }
    }
    TRefAsNonNull(value) =>
      sr_extract_signature_type_abs_from_instr(
        value, caller_abs_idx, local_types_by_abs, global_types, env, func_type_idxs,
      )
    _ =>
      match
        sr_known_instr_type(
          instr, caller_abs_idx, local_types_by_abs, global_types, env, func_type_idxs,
        ) {
        Some(RefTypeValType(HeapTypeRefType(_, HeapType(type_idx)))) =>
          Some(sr_typeidx_raw(type_idx))
        _ => None
      }
  }
}

///|
fn sr_subtype_with_new_comptype(st : SubType, new_ct : CompType) -> SubType {
  match st {
    SubType(is_final, supers, _) => SubType::new(is_final, supers, new_ct)
    CompTypeSubType(_) => SubType::comp_type(new_ct)
  }
}

///|
fn sr_apply_new_signatures(
  type_recs : Array[RecType],
  new_sigs : Array[FuncType?],
) -> Array[RecType] {
  let out : Array[RecType] = []
  let mut abs_idx = 0
  for rec in type_recs {
    match rec {
      SingleRecType(st) => {
        let next_st = match new_sigs[abs_idx] {
          Some(FuncType(params, results)) =>
            sr_subtype_with_new_comptype(st, CompType::func(params, results))
          None => st
        }
        out.push(RecType::new(next_st))
        abs_idx += 1
      }
      GroupRecType(sts) => {
        let next_group : Array[SubType] = []
        for st in sts {
          let next_st = match new_sigs[abs_idx] {
            Some(FuncType(params, results)) =>
              sr_subtype_with_new_comptype(st, CompType::func(params, results))
            None => st
          }
          next_group.push(next_st)
          abs_idx += 1
        }
        out.push(RecType::group(next_group))
      }
    }
  }
  out
}

///|
fn sr_refinalize_changed_functions(
  mod : Module,
  changed_type_abs : Array[Bool],
  func_type_idxs : Array[TypeIdx],
) -> Result[Module, String] {
  let funcs = match mod.code_sec {
    Some(CodeSec(fs)) => fs
    None => return Ok(mod)
  }
  let import_func_count = sr_count_imported_funcs(mod)
  let env = Env::new().with_module(mod)
  let next_funcs = funcs.copy()
  let mut changed = false

  for def_idx = 0; def_idx < funcs.length(); def_idx = def_idx + 1 {
    let abs_idx = import_func_count + def_idx
    if abs_idx < 0 || abs_idx >= func_type_idxs.length() {
      continue
    }
    let type_abs = sr_typeidx_raw(func_type_idxs[abs_idx])
    if type_abs < 0 ||
      type_abs >= changed_type_abs.length() ||
      !changed_type_abs[type_abs] {
      continue
    }
    match next_funcs[def_idx] {
      TFunc(locals, body) => {
        let params = match
          env.get_functype_by_funcidx(
            FuncIdx::new(abs_idx.reinterpret_as_uint()),
          ) {
          Some(FuncType(ps, _)) => ps
          None => []
        }
        let all_locals = params.copy()
        all_locals.append(locals)
        let local_env = env.with_locals(all_locals)
        let lowered = body.to_expr()
        match to_texpr(lowered, local_env) {
          Ok(new_body) =>
            if new_body != body {
              next_funcs[def_idx] = Func::t_func(locals, new_body)
              changed = true
            }
          Err(_) => ()
        }
      }
      _ => return Err("signature_refining: expected TFunc")
    }
  }

  if changed {
    Ok(mod.with_code_sec(CodeSec::new(next_funcs)))
  } else {
    Ok(mod)
  }
}

///|
fn signature_refining(mod : Module) -> Result[Module, String] {
  match mod.table_sec {
    Some(TableSec(tables)) if !tables.is_empty() => return Ok(mod)
    _ => ()
  }

  let type_recs = match mod.type_sec {
    Some(TypeSec(recs)) => recs.copy()
    None => return Ok(mod)
  }

  let funcs = match mod.code_sec {
    Some(CodeSec(fs)) => fs
    None => return Ok(mod)
  }
  let func_sec = match mod.func_sec {
    Some(FuncSec(type_idxs)) => type_idxs
    None => return Ok(mod)
  }
  if funcs.is_empty() || func_sec.is_empty() {
    return Ok(mod)
  }

  let env = Env::new().with_module(mod)
  let func_type_idxs = sr_collect_func_type_idxs(mod)
  let total_func_count = func_type_idxs.length()
  if total_func_count == 0 {
    return Ok(mod)
  }

  let func_types = sr_collect_func_types(env, total_func_count)
  if func_types.length() != total_func_count {
    return Ok(mod)
  }

  let total_types = sr_flattened_type_count(type_recs)
  if total_types == 0 {
    return Ok(mod)
  }

  let import_func_count = sr_count_imported_funcs(mod)
  let import_call_without_effects = sr_collect_import_call_without_effects(mod)
  let global_types = sr_collect_global_types(mod)
  let local_types_by_abs = sr_build_local_types_by_abs(
    func_types, funcs, import_func_count,
  )

  let (subtypes, group_starts, immediate_subs, has_declared_super) = sr_collect_subtypes(
    type_recs,
  )

  let calls_by_type : Array[Array[SRCallSite]] = []
  let can_modify : Array[Bool] = Array::make(total_types, true)
  let can_modify_params : Array[Bool] = Array::make(total_types, true)
  let result_candidate : Array[ValType?] = Array::make(total_types, None)
  let result_noted : Array[Bool] = Array::make(total_types, false)
  let result_unknown : Array[Bool] = Array::make(total_types, false)

  for _ in 0..<total_types {
    calls_by_type.push([])
  }

  let has_unseen_calls : Array[Bool] = Array::make(total_func_count, false)
  sr_mark_exports_unseen(mod, has_unseen_calls)
  sr_mark_start_unseen(mod, has_unseen_calls)
  sr_mark_elem_unseen(mod, has_unseen_calls)
  let public_types = sr_collect_public_types(
    mod, subtypes, group_starts, total_types, func_type_idxs,
  )

  for abs_idx = 0; abs_idx < total_func_count; abs_idx = abs_idx + 1 {
    let type_abs = sr_typeidx_raw(func_type_idxs[abs_idx])
    if type_abs < 0 || type_abs >= total_types {
      continue
    }

    if abs_idx < import_func_count {
      can_modify[type_abs] = false
      continue
    }

    let def_idx = abs_idx - import_func_count
    if def_idx < 0 || def_idx >= funcs.length() {
      continue
    }

    let FuncType(_, old_results) = func_types[abs_idx]
    match funcs[def_idx] {
      TFunc(_, body) => {
        let walker = ModuleTransformer::new().on_tinstruction_evt(fn(
          self,
          _,
          instr,
        ) {
          match instr {
            TCall(target, args) | TReturnCall(target, args) => {
              let FuncIdx(raw) = target
              let callee_abs_idx = raw.reinterpret_as_int()
              if callee_abs_idx >= 0 && callee_abs_idx < total_func_count {
                let callee_type_abs = sr_typeidx_raw(
                  func_type_idxs[callee_abs_idx],
                )
                sr_record_callsite(
                  callee_type_abs, abs_idx, args, calls_by_type,
                )
                if callee_abs_idx >= 0 &&
                  callee_abs_idx < import_call_without_effects.length() &&
                  import_call_without_effects[callee_abs_idx] &&
                  !args.is_empty() {
                  match
                    sr_extract_signature_type_abs_from_instr(
                      args[args.length() - 1],
                      abs_idx,
                      local_types_by_abs,
                      global_types,
                      env,
                      func_type_idxs,
                    ) {
                    Some(extra_type_abs) =>
                      sr_record_callsite(
                        extra_type_abs, abs_idx, args, calls_by_type,
                      )
                    None => ()
                  }
                }
              }
            }
            TCallRef(type_idx, args, _) | TReturnCallRef(type_idx, args, _) => {
              let called_type_abs = sr_typeidx_raw(type_idx)
              sr_record_callsite(called_type_abs, abs_idx, args, calls_by_type)
            }
            TReturn(values) =>
              if old_results.length() == 1 {
                if values.length() != 1 {
                  result_unknown[type_abs] = true
                } else {
                  match
                    sr_known_instr_type(
                      values[0],
                      abs_idx,
                      local_types_by_abs,
                      global_types,
                      env,
                      func_type_idxs,
                    ) {
                    Some(vt) =>
                      sr_note_result_observation(
                        type_abs,
                        vt,
                        old_results[0],
                        result_candidate,
                        result_noted,
                        result_unknown,
                        env,
                      )
                    None => result_unknown[type_abs] = true
                  }
                }
              }
            _ => ()
          }
          self.walk_tinstruction_default((), instr)
        })
        ignore(walker.walk_texpr((), body))

        if old_results.length() == 1 && !body.0.is_empty() {
          let tail = body.0[body.0.length() - 1]
          match tail {
            TReturn(_) => ()
            _ =>
              match
                sr_known_instr_type(
                  tail, abs_idx, local_types_by_abs, global_types, env, func_type_idxs,
                ) {
                Some(vt) =>
                  sr_note_result_observation(
                    type_abs,
                    vt,
                    old_results[0],
                    result_candidate,
                    result_noted,
                    result_unknown,
                    env,
                  )
                None => ()
              }
          }
        }
      }
      _ => return Err("signature_refining: expected TFunc")
    }
  }

  for abs_idx = 0; abs_idx < total_func_count; abs_idx = abs_idx + 1 {
    if !has_unseen_calls[abs_idx] {
      continue
    }
    let type_abs = sr_typeidx_raw(func_type_idxs[abs_idx])
    if type_abs >= 0 && type_abs < total_types {
      can_modify_params[type_abs] = false
    }
  }

  for type_abs in public_types {
    if type_abs < 0 || type_abs >= total_types {
      continue
    }
    if env.resolve_functype(TypeIdx::new(type_abs.reinterpret_as_uint()))
      is Some(_) {
      can_modify[type_abs] = false
    }
  }

  match mod.tag_sec {
    Some(TagSec(tags)) =>
      for tag in tags {
        let TagType(type_idx) = tag
        let type_abs = sr_typeidx_raw(type_idx)
        if type_abs >= 0 && type_abs < total_types {
          can_modify[type_abs] = false
        }
      }
    None => ()
  }

  for type_abs = 0; type_abs < total_types; type_abs = type_abs + 1 {
    if !immediate_subs[type_abs].is_empty() || has_declared_super[type_abs] {
      can_modify[type_abs] = false
    }
  }

  let new_sigs : Array[FuncType?] = Array::make(total_types, None)
  let changed_type_abs : Array[Bool] = Array::make(total_types, false)
  let mut any_sig_change = false

  for type_abs = 0; type_abs < total_types; type_abs = type_abs + 1 {
    if !can_modify[type_abs] {
      continue
    }

    let old_sig = match
      env.resolve_functype(TypeIdx::new(type_abs.reinterpret_as_uint())) {
      Some(ft) => ft
      None => continue
    }
    let FuncType(old_params, old_results) = old_sig

    let mut new_params = old_params
    if can_modify_params[type_abs] && old_params.length() > 0 {
      let calls = calls_by_type[type_abs]
      if !calls.is_empty() {
        let candidate_params : Array[ValType] = []
        let all_known = [true]
        for p = 0; p < old_params.length(); p = p + 1 {
          let old_param = old_params[p]
          let candidate : Array[ValType?] = [None]
          for callsite in calls {
            if p >= callsite.args.length() {
              all_known[0] = false
              break
            }
            match
              sr_known_instr_type(
                callsite.args[p],
                callsite.caller_abs_idx,
                local_types_by_abs,
                global_types,
                env,
                func_type_idxs,
              ) {
              Some(arg_ty) => {
                if !Match::matches(arg_ty, old_param, env) {
                  all_known[0] = false
                  break
                }
                candidate[0] = match candidate[0] {
                  None => Some(arg_ty)
                  Some(prev) => sr_common_val_supertype(prev, arg_ty, env)
                }
                if candidate[0] is None {
                  all_known[0] = false
                  break
                }
              }
              None => {
                all_known[0] = false
                break
              }
            }
          }
          if !all_known[0] {
            break
          }
          match candidate[0] {
            Some(vt) =>
              if Match::matches(vt, old_param, env) {
                candidate_params.push(vt)
              } else {
                all_known[0] = false
              }
            None => all_known[0] = false
          }
          if !all_known[0] {
            break
          }
        }

        if all_known[0] && candidate_params.length() == old_params.length() {
          new_params = candidate_params
        }
      }
    }

    let mut new_results = old_results
    if old_results.length() == 1 &&
      result_noted[type_abs] &&
      !result_unknown[type_abs] {
      match result_candidate[type_abs] {
        Some(vt) if Match::matches(vt, old_results[0], env) =>
          new_results = [vt]
        _ => ()
      }
    }

    if new_params != old_params || new_results != old_results {
      new_sigs[type_abs] = Some(FuncType::new(new_params, new_results))
      changed_type_abs[type_abs] = true
      any_sig_change = true
    }
  }

  if !any_sig_change {
    return Ok(mod)
  }

  let next_type_recs = sr_apply_new_signatures(type_recs, new_sigs)

  let next_funcs = funcs.copy()
  let mut changed_code = false
  for def_idx = 0; def_idx < funcs.length(); def_idx = def_idx + 1 {
    let abs_idx = import_func_count + def_idx
    if abs_idx < 0 || abs_idx >= total_func_count {
      continue
    }
    let type_abs = sr_typeidx_raw(func_type_idxs[abs_idx])
    if type_abs < 0 || type_abs >= total_types {
      continue
    }
    let new_sig = match new_sigs[type_abs] {
      Some(sig) => sig
      None => continue
    }
    let FuncType(old_params, _) = func_types[abs_idx]
    let FuncType(new_params, _) = new_sig
    if old_params == new_params {
      continue
    }

    match funcs[def_idx] {
      TFunc(locals, body) => {
        let (new_locals, new_body) = sr_update_param_types(
          body, old_params, new_params, locals, local_types_by_abs, global_types,
          env, abs_idx, func_type_idxs,
        )
        if new_locals != locals || new_body != body {
          next_funcs[def_idx] = Func::t_func(new_locals, new_body)
          changed_code = true
        }
      }
      _ => return Err("signature_refining: expected TFunc")
    }
  }

  let out = mod.with_type_sec(TypeSec::new(next_type_recs))
  let out = if changed_code {
    out.with_code_sec(CodeSec::new(next_funcs))
  } else {
    out
  }

  sr_refinalize_changed_functions(out, changed_type_abs, func_type_idxs)
}

///|
test "signature refining does not modify publicly-observable function type via exported global ref" {
  let non_null_funcref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::func())),
  )
  let nullable_funcref = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let public_target_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(1))),
  )

  let t_caller = sr_make_func_type([non_null_funcref], [])
  let t_target = sr_make_func_type([nullable_funcref], [])

  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(1), [TInstr::local_get(LocalIdx::new(0))]),
    ]),
  )
  let callee = Func::t_func([], TExpr::new([TInstr::nop()]))

  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_caller, t_target]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(public_target_ref, false),
          Expr::new([Instruction::ref_null(HeapType::new(TypeIdx::new(1)))]),
        ),
      ]),
    )
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("g"), ExternIdx::global(GlobalIdx::new(0))),
      ]),
    )
    .with_code_sec(CodeSec::new([caller, callee]))

  let out = run_signature_refining(mod)
  let env = Env::new().with_module(out)
  let ft = match env.resolve_functype(TypeIdx::new(1)) {
    Some(ft) => ft
    None => fail("expected target function type")
  }
  match ft {
    FuncType(params, _) => {
      assert_eq(params.length(), 1)
      assert_eq(params[0], nullable_funcref)
    }
  }
}

///|
fn run_signature_refining(mod : Module) -> Module {
  match signature_refining(mod) {
    Ok(out) => out
    Err(_) => mod
  }
}

///|
test "signature refining refines parameter types from direct calls" {
  let non_null_funcref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::func())),
  )
  let nullable_funcref = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let t_caller = sr_make_func_type([non_null_funcref], [])
  let t_target = sr_make_func_type([nullable_funcref], [])

  let caller_a = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(2), [TInstr::local_get(LocalIdx::new(0))]),
    ]),
  )
  let caller_b = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(3), [TInstr::local_get(LocalIdx::new(0))]),
    ]),
  )
  let callee_a = Func::t_func([], TExpr::new([TInstr::nop()]))
  let callee_b = Func::t_func([], TExpr::new([TInstr::nop()]))

  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_caller, t_target]))
    .with_func_sec(
      FuncSec::new([
        TypeIdx::new(0),
        TypeIdx::new(0),
        TypeIdx::new(1),
        TypeIdx::new(1),
      ]),
    )
    .with_code_sec(CodeSec::new([caller_a, caller_b, callee_a, callee_b]))

  let out = run_signature_refining(mod)
  let env = Env::new().with_module(out)
  let ft = match env.resolve_functype(TypeIdx::new(1)) {
    Some(ft) => ft
    None => fail("expected target function type")
  }
  match ft {
    FuncType(params, _) => {
      assert_eq(params.length(), 1)
      let param = params[0]
      assert_true(Match::matches(param, nullable_funcref, env))
      assert_true(param != nullable_funcref)
    }
  }
}

///|
test "signature refining refines parameter types from call_ref sites" {
  let non_null_funcref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::func())),
  )
  let nullable_funcref = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let t_caller = sr_make_func_type([non_null_funcref], [])
  let t_target = sr_make_func_type([nullable_funcref], [ValType::i32()])

  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::drop(
        TInstr::call_ref(
          TypeIdx::new(1),
          [TInstr::local_get(LocalIdx::new(0))],
          TInstr::ref_func(FuncIdx::new(1)),
        ),
      ),
    ]),
  )
  let callee = Func::t_func([], TExpr::new([TInstr::i32_const(I32(7))]))

  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_caller, t_target]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([caller, callee]))

  let out = run_signature_refining(mod)
  let env = Env::new().with_module(out)
  let ft = match env.resolve_functype(TypeIdx::new(1)) {
    Some(ft) => ft
    None => fail("expected target function type")
  }
  match ft {
    FuncType(params, _) => {
      assert_eq(params.length(), 1)
      let param = params[0]
      assert_true(Match::matches(param, nullable_funcref, env))
      assert_true(param != nullable_funcref)
    }
  }
}

///|
test "signature refining keeps params when ref.func escapes but still refines results" {
  let non_null_funcref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::func())),
  )
  let nullable_funcref = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let t_caller = sr_make_func_type([non_null_funcref], [])
  let t_target = sr_make_func_type([nullable_funcref], [nullable_funcref])

  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::drop(
        TInstr::call(FuncIdx::new(1), [TInstr::local_get(LocalIdx::new(0))]),
      ),
    ]),
  )
  let callee = Func::t_func(
    [],
    TExpr::new([
      TInstr::ref_as_non_null(
        TInstr::ref_null(HeapType::abs(AbsHeapType::func())),
      ),
    ]),
  )

  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_caller, t_target]))
    .with_elem_sec(
      ElemSec::new([
        Elem::new(ElemMode::declarative(), ElemKind::funcs([FuncIdx::new(1)])),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([caller, callee]))

  let out = run_signature_refining(mod)
  let env = Env::new().with_module(out)
  let ft = match env.resolve_functype(TypeIdx::new(1)) {
    Some(ft) => ft
    None => fail("expected target function type")
  }
  match ft {
    FuncType(params, results) => {
      assert_eq(params.length(), 1)
      assert_eq(results.length(), 1)
      let param = params[0]
      let result = results[0]
      assert_eq(param, nullable_funcref)
      assert_true(result != nullable_funcref)
      assert_true(Match::matches(result, nullable_funcref, env))
      match result {
        RefTypeValType(rt) => assert_false(rt.is_nullable())
        _ => fail("expected refined reference result type")
      }
    }
  }
}

///|
test "signature refining does not run when tables are present" {
  let nullable_funcref = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let t_void = sr_make_func_type([], [])
  let t_target = sr_make_func_type([nullable_funcref], [])

  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(1), [TInstr::ref_func(FuncIdx::new(1))]),
    ]),
  )
  let callee = Func::t_func([], TExpr::new([TInstr::nop()]))

  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void, t_target]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_table_sec(
      TableSec::new([
        Table::new(
          TableType::new(
            RefType::new(true, HeapType::abs(AbsHeapType::func())),
            Limits::i32(1, None),
          ),
          Some(
            Expr::new([
              Instruction::ref_null(HeapType::abs(AbsHeapType::func())),
            ]),
          ),
        ),
      ]),
    )
    .with_code_sec(CodeSec::new([caller, callee]))

  let out = run_signature_refining(mod)
  assert_eq(out, mod)
}

///|
test "signature refining does not modify imported function signatures" {
  let nullable_funcref = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let t_import = sr_make_func_type([nullable_funcref], [])
  let t_void = sr_make_func_type([], [])

  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(0), [TInstr::ref_func(FuncIdx::new(0))]),
    ]),
  )

  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_import, t_void]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("imp"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([caller]))

  let out = run_signature_refining(mod)
  let env = Env::new().with_module(out)
  let ft = match env.resolve_functype(TypeIdx::new(0)) {
    Some(ft) => ft
    None => fail("expected import type")
  }
  match ft {
    FuncType(params, _) => {
      assert_eq(params.length(), 1)
      assert_eq(params[0], nullable_funcref)
    }
  }
}

///|
test "signature refining does not modify tag-used function signatures" {
  let nullable_funcref = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let t_void = sr_make_func_type([], [])
  let t_target = sr_make_func_type([nullable_funcref], [])

  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(1), [TInstr::ref_func(FuncIdx::new(1))]),
    ]),
  )
  let callee = Func::t_func([], TExpr::new([TInstr::nop()]))

  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void, t_target]))
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(1))]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([caller, callee]))

  let out = run_signature_refining(mod)
  let env = Env::new().with_module(out)
  let ft = match env.resolve_functype(TypeIdx::new(1)) {
    Some(ft) => ft
    None => fail("expected target type")
  }
  match ft {
    FuncType(params, _) => {
      assert_eq(params.length(), 1)
      assert_eq(params[0], nullable_funcref)
    }
  }
}

///|
test "signature refining does not modify function types with subtypes" {
  let nullable_funcref = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let super_ty = RecType::new(
    SubType::comp_type(CompType::func([nullable_funcref], [])),
  )
  let sub_ty = RecType::new(
    SubType::new(
      false,
      [TypeIdx::new(0)],
      CompType::func([nullable_funcref], []),
    ),
  )
  let void_ty = sr_make_func_type([], [])

  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(1), [TInstr::ref_func(FuncIdx::new(1))]),
    ]),
  )
  let super_func = Func::t_func([], TExpr::new([TInstr::nop()]))
  let sub_func = Func::t_func([], TExpr::new([TInstr::nop()]))

  let mod = Module::new()
    .with_type_sec(TypeSec::new([super_ty, sub_ty, void_ty]))
    .with_func_sec(
      FuncSec::new([TypeIdx::new(2), TypeIdx::new(0), TypeIdx::new(1)]),
    )
    .with_code_sec(CodeSec::new([caller, super_func, sub_func]))

  let out = run_signature_refining(mod)
  let env = Env::new().with_module(out)
  let ft = match env.resolve_functype(TypeIdx::new(0)) {
    Some(ft) => ft
    None => fail("expected super function type")
  }
  match ft {
    FuncType(params, _) => {
      assert_eq(params.length(), 1)
      assert_eq(params[0], nullable_funcref)
    }
  }
}

///|
test "signature refining inserts parameter fixup locals for incompatible param sets" {
  let non_null_funcref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::func())),
  )
  let nullable_funcref = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )

  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(1), [TInstr::local_get(LocalIdx::new(0))]),
    ]),
  )
  let callee = Func::t_func(
    [],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::ref_null(HeapType::abs(AbsHeapType::func())),
      ),
      TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
    ]),
  )

  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        sr_make_func_type([non_null_funcref], []),
        sr_make_func_type([nullable_funcref], []),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([caller, callee]))

  let out = run_signature_refining(mod)

  let env = Env::new().with_module(out)
  let ft = match env.resolve_functype(TypeIdx::new(1)) {
    Some(ft) => ft
    None => fail("expected refined callee type")
  }
  match ft {
    FuncType(params, _) => {
      assert_eq(params.length(), 1)
      assert_eq(params[0], non_null_funcref)
    }
  }

  match out.code_sec {
    Some(CodeSec([_, TFunc(locals, TExpr(instrs))])) => {
      assert_eq(locals.length(), 1)
      assert_eq(locals[0], nullable_funcref)
      assert_eq(
        instrs[0],
        TInstr::local_set(LocalIdx::new(1), TInstr::local_get(LocalIdx::new(0))),
      )
      assert_eq(
        instrs[1],
        TInstr::local_set(
          LocalIdx::new(1),
          TInstr::ref_null(HeapType::abs(AbsHeapType::func())),
        ),
      )
    }
    _ => fail("expected rewritten callee with fixup local")
  }
}

///|
test "signature refining uses call.without.effects intrinsic extra-call signature" {
  let non_null_funcref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::func())),
  )
  let nullable_funcref = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let funcref = ValType::funcref()

  let t_intrinsic = sr_make_func_type([nullable_funcref, funcref], [])
  let t_caller = sr_make_func_type([non_null_funcref], [])
  let t_target = sr_make_func_type([nullable_funcref], [])

  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(0), [
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::ref_func(FuncIdx::new(2)),
      ]),
    ]),
  )
  let callee = Func::t_func([], TExpr::new([TInstr::nop()]))

  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_intrinsic, t_caller, t_target]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("binaryen-intrinsics"),
          Name::new("call.without.effects"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1), TypeIdx::new(2)]))
    .with_code_sec(CodeSec::new([caller, callee]))

  let out = run_signature_refining(mod)
  let env = Env::new().with_module(out)
  let ft = match env.resolve_functype(TypeIdx::new(2)) {
    Some(ft) => ft
    None => fail("expected target function type")
  }
  match ft {
    FuncType(params, _) => {
      assert_eq(params.length(), 1)
      assert_eq(params[0], non_null_funcref)
    }
  }
}

///|
test "signature refining updates shared result type from function bodies" {
  let nullable_funcref = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let t_caller = sr_make_func_type([], [ValType::i32()])
  let t_target = sr_make_func_type([], [nullable_funcref])

  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::drop(TInstr::call(FuncIdx::new(1), [])),
      TInstr::drop(TInstr::call(FuncIdx::new(2), [])),
      TInstr::i32_const(I32(0)),
    ]),
  )
  let ret_a = Func::t_func(
    [],
    TExpr::new([
      TInstr::ref_as_non_null(
        TInstr::ref_null(HeapType::abs(AbsHeapType::func())),
      ),
    ]),
  )
  let ret_b = Func::t_func(
    [],
    TExpr::new([
      TInstr::ref_as_non_null(
        TInstr::ref_null(HeapType::abs(AbsHeapType::func())),
      ),
    ]),
  )

  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_caller, t_target]))
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(1), TypeIdx::new(1)]),
    )
    .with_code_sec(CodeSec::new([caller, ret_a, ret_b]))

  let out = run_signature_refining(mod)
  let env = Env::new().with_module(out)
  let ft = match env.resolve_functype(TypeIdx::new(1)) {
    Some(ft) => ft
    None => fail("expected target type")
  }
  match ft {
    FuncType(_, results) => {
      assert_eq(results.length(), 1)
      assert_true(results[0] != nullable_funcref)
      assert_true(Match::matches(results[0], nullable_funcref, env))
      match results[0] {
        RefTypeValType(rt) => assert_false(rt.is_nullable())
        _ => fail("expected refined reference result type")
      }
    }
  }
}

///|
test "signature refining does not refine start function parameter types" {
  let non_null_funcref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::func())),
  )
  let nullable_funcref = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let t_caller = sr_make_func_type([non_null_funcref], [])
  let t_start = sr_make_func_type([nullable_funcref], [])

  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(1), [TInstr::local_get(LocalIdx::new(0))]),
    ]),
  )
  let start_func = Func::t_func([], TExpr::new([TInstr::nop()]))

  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_caller, t_start]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([caller, start_func]))
    .with_start_sec(StartSec::new(FuncIdx::new(1)))

  let out = run_signature_refining(mod)
  let env = Env::new().with_module(out)
  let ft = match env.resolve_functype(TypeIdx::new(1)) {
    Some(ft) => ft
    None => fail("expected start function type")
  }
  match ft {
    FuncType(params, _) => {
      assert_eq(params.length(), 1)
      assert_eq(params[0], nullable_funcref)
    }
  }
}

///|
test "signature refining does not refine params when ref.func escapes in typed elem expr" {
  let non_null_funcref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::func())),
  )
  let nullable_funcref = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let t_caller = sr_make_func_type([non_null_funcref], [])
  let t_target = sr_make_func_type([nullable_funcref], [])

  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(1), [TInstr::local_get(LocalIdx::new(0))]),
    ]),
  )
  let callee = Func::t_func([], TExpr::new([TInstr::nop()]))

  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_caller, t_target]))
    .with_elem_sec(
      ElemSec::new([
        Elem::new(
          ElemMode::declarative(),
          ElemKind::typed_exprs(
            RefType::new(true, HeapType::abs(AbsHeapType::func())),
            [Expr::new([Instruction::ref_func(FuncIdx::new(1))])],
          ),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([caller, callee]))

  let out = run_signature_refining(mod)
  let env = Env::new().with_module(out)
  let ft = match env.resolve_functype(TypeIdx::new(1)) {
    Some(ft) => ft
    None => fail("expected target function type")
  }
  match ft {
    FuncType(params, _) => {
      assert_eq(params.length(), 1)
      assert_eq(params[0], nullable_funcref)
    }
  }
}

///|
test "signature refining uses binaryen-intrinsics-optimized call.without.effects alias" {
  let non_null_funcref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::func())),
  )
  let nullable_funcref = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let funcref = ValType::funcref()

  let t_intrinsic = sr_make_func_type([nullable_funcref, funcref], [])
  let t_caller = sr_make_func_type([non_null_funcref], [])
  let t_target = sr_make_func_type([nullable_funcref], [])

  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(0), [
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::ref_func(FuncIdx::new(2)),
      ]),
    ]),
  )
  let callee = Func::t_func([], TExpr::new([TInstr::nop()]))

  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_intrinsic, t_caller, t_target]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("binaryen-intrinsics-optimized"),
          Name::new("call.without.effects"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1), TypeIdx::new(2)]))
    .with_code_sec(CodeSec::new([caller, callee]))

  let out = run_signature_refining(mod)
  let env = Env::new().with_module(out)
  let ft = match env.resolve_functype(TypeIdx::new(2)) {
    Some(ft) => ft
    None => fail("expected target function type")
  }
  match ft {
    FuncType(params, _) => {
      assert_eq(params.length(), 1)
      assert_eq(params[0], non_null_funcref)
    }
  }
}
