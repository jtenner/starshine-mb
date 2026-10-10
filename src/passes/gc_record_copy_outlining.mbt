// Original Starshine implementation; licensing scope: ../../LICENSE.
// Copyright 2026 Joshua Tenner. No upstream counterpart is claimed.

///|
// Only an ordinary immutable i32 record copy is outlined. The helper creates
// one fresh record per call; it never mutates the borrowed source. Its extra
// read of the replaced field is harmless because every admitted copy already
// reads another immutable field, and thus already traps on a null source.
priv struct GcRecordCopySite {
  start : Int
  owner : UInt
  source : UInt
  field : Int
  value : Int
}

///|
fn gc_record_copy_type_fields(subtype : @lib.SubType) -> Int? {
  let metadata = subtype.metadata()
  if metadata.shared ||
    metadata.describes is Some(_) ||
    metadata.descriptor is Some(_) ||
    !subtype.super_types().is_empty() {
    return None
  }
  match subtype {
    @lib.SubType(false, _, _, _) => return None
    _ => ()
  }
  let fields = match subtype.get_comptype() {
    @lib.StructCompType(fields) if fields.length() >= 8 &&
      fields.length() <= 512 => fields
    _ => return None
  }
  for field in fields {
    match field {
      @lib.FieldType(
        @lib.ValTypeStorageType(@lib.NumTypeValType(@lib.I32NumType)),
        @lib.Const
      ) => ()
      _ => return None
    }
  }
  Some(fields.length())
}

///|
fn gc_record_copy_has_exact_type(type_ : @lib.ValType) -> Bool {
  match type_ {
    @lib.RefTypeValType(ref_type) => ref_type.is_exact()
    _ => false
  }
}

///|
fn gc_record_copy_function_local_count(
  signature : @lib.FuncType?,
  locals : @lib.Locals,
) -> Int? {
  let @lib.FuncType(params, results) = match signature {
    Some(signature) if signature.0.length() <= 65536 &&
      signature.1.length() <= 65536 => signature
    _ => return None
  }
  ignore(results)
  if locals.run_count() > 65536 {
    return None
  }
  let mut count = params.length().reinterpret_as_uint().to_uint64()
  // Bound compressed runs before the snapshot and unsigned declaration totals
  // before any indexed/dense local conversion. This owner needs neither one.
  for run in locals.runs() {
    count += run.count().to_uint64()
    if count > 65536UL {
      return None
    }
  }
  Some(count.to_int())
}

///|
fn gc_record_copy_function_bounded(
  signature : @lib.FuncType?,
  locals : @lib.Locals,
) -> Bool {
  gc_record_copy_function_local_count(signature, locals) is Some(_)
}

///|
fn gc_record_copy_function_supported(
  signature : @lib.FuncType?,
  locals : @lib.Locals,
) -> Bool {
  match signature {
    Some(@lib.FuncType(params, results)) => {
      if params.any(gc_record_copy_has_exact_type) ||
        results.any(gc_record_copy_has_exact_type) {
        return false
      }
      for run in locals.runs() {
        if gc_record_copy_has_exact_type(run.val_type()) {
          return false
        }
      }
      true
    }
    None => false
  }
}

///|
fn gc_record_copy_match(
  body : Array[@lib.Instruction],
  end : Int,
  fields_by_type : @hashmap.HashMap[UInt, Int],
) -> GcRecordCopySite? {
  let owner = match body[end] {
    @lib.StructNew(@lib.TypeIdx(owner)) => owner
    _ => return None
  }
  let fields = match fields_by_type.get(owner) {
    Some(fields) => fields
    None => return None
  }
  let mut cursor = end - 1
  let mut source : UInt? = None
  let mut replacement : (Int, Int)? = None
  for field = fields - 1; field >= 0; field = field - 1 {
    if cursor < 0 {
      return None
    }
    match body[cursor] {
      @lib.I32Const(@lib.I32(value)) => {
        if replacement is Some(_) {
          return None
        }
        replacement = Some((field, value))
        cursor -= 1
      }
      @lib.StructGet(@lib.TypeIdx(read_owner), @lib.U32(read_field)) => {
        if cursor < 1 ||
          read_owner != owner ||
          read_field != field.reinterpret_as_uint() {
          return None
        }
        let local_idx = match body[cursor - 1] {
          @lib.LocalGet(@lib.LocalIdx(idx)) => idx
          _ => return None
        }
        match source {
          Some(previous) if previous != local_idx => return None
          None => source = Some(local_idx)
          _ => ()
        }
        cursor -= 2
      }
      _ => return None
    }
  }
  match (source, replacement) {
    (Some(source), Some((field, value))) =>
      Some({ start: cursor + 1, owner, source, field, value, })
    _ => None
  }
}

///|
// Full candidate validation sees every body, even those we never rewrite.
// Bound it independently from the recursive matcher/rewrite ceiling. DFS keeps
// only suspended parent/sibling frames, borrowing arrays rather than slicing.
fn gc_record_copy_preflight(
  body : Array[@lib.Instruction],
  budget : Array[Int],
) -> Int? {
  let pending : Array[(Array[@lib.Instruction], Int, Int)] = [(body, 0, 0)]
  let mut maximum = 0
  while pending.length() > 0 {
    let (xs, idx, depth) = pending.pop().unwrap()
    if idx == 0 {
      if depth > 1024 || xs.length() > budget[0] {
        return None
      }
      budget[0] -= xs.length()
      if depth > maximum {
        maximum = depth
      }
    }
    if idx >= xs.length() {
      continue
    }
    if idx + 1 < xs.length() {
      pending.push((xs, idx + 1, depth))
    }
    match xs[idx] {
      @lib.Block(_, @lib.Expr(child)) | @lib.Loop(_, @lib.Expr(child)) =>
        pending.push((child, 0, depth + 1))
      @lib.If(_, left, right) => {
        if right is Some(child) {
          pending.push((child, 0, depth + 1))
        }
        pending.push((left, 0, depth + 1))
      }
      @lib.Try(_) | @lib.TryTable(_) => return None
      _ => ()
    }
  }
  Some(maximum)
}

///|
fn gc_record_copy_scan(
  body : Array[@lib.Instruction],
  fields_by_type : @hashmap.HashMap[UInt, Int],
  counts : @hashmap.HashMap[UInt, Int],
  budget : Array[Int],
  depth : Int,
  eligible : Bool,
) -> Bool {
  if depth > 128 || body.length() > budget[0] {
    return false
  }
  budget[0] -= body.length()
  for idx in 0..<body.length() {
    if eligible && gc_record_copy_match(body, idx, fields_by_type) is Some(site) {
      budget[1] += 1
      if budget[1] > 4096 {
        return false
      }
      counts.set(site.owner, counts.get(site.owner).unwrap_or(0) + 1)
    }
    match body[idx] {
      @lib.Block(_, @lib.Expr(child)) | @lib.Loop(_, @lib.Expr(child)) =>
        if !gc_record_copy_scan(
            child,
            fields_by_type,
            counts,
            budget,
            depth + 1,
            eligible,
          ) {
          return false
        }
      @lib.If(_, left, right) => {
        if !gc_record_copy_scan(
            left,
            fields_by_type,
            counts,
            budget,
            depth + 1,
            eligible,
          ) {
          return false
        }
        if right is Some(child) &&
          !gc_record_copy_scan(
            child,
            fields_by_type,
            counts,
            budget,
            depth + 1,
            eligible,
          ) {
          return false
        }
      }
      // Reject opaque exception containers instead of walking them through an
      // unbounded legacy preflight or letting their hidden bodies evade caps.
      @lib.Try(_) | @lib.TryTable(_) => return false
      _ => ()
    }
  }
  true
}

///|
fn gc_record_copy_rewrite(
  body : Array[@lib.Instruction],
  fields_by_type : @hashmap.HashMap[UInt, Int],
  helpers : @hashmap.HashMap[UInt, @lib.FuncIdx],
) -> Array[@lib.Instruction] {
  let mut output : Array[@lib.Instruction]? = None
  for idx in 0..<body.length() {
    let original = body[idx]
    let rewritten = match original {
      @lib.Block(type_, @lib.Expr(child)) => {
        let next = gc_record_copy_rewrite(child, fields_by_type, helpers)
        if physical_equal(next, child) {
          original
        } else {
          @lib.Instruction::block(type_, @lib.Expr::new(next))
        }
      }
      @lib.Loop(type_, @lib.Expr(child)) => {
        let next = gc_record_copy_rewrite(child, fields_by_type, helpers)
        if physical_equal(next, child) {
          original
        } else {
          @lib.Instruction::loop_(type_, @lib.Expr::new(next))
        }
      }
      @lib.If(type_, left, right) => {
        let next_left = gc_record_copy_rewrite(left, fields_by_type, helpers)
        let next_right = match right {
          Some(child) =>
            Some(gc_record_copy_rewrite(child, fields_by_type, helpers))
          None => None
        }
        let same_right = match (right, next_right) {
          (Some(old), Some(next)) => physical_equal(old, next)
          (None, None) => true
          _ => false
        }
        if physical_equal(left, next_left) && same_right {
          original
        } else {
          @lib.Instruction::if_(type_, next_left, next_right)
        }
      }
      _ => original
    }
    match gc_record_copy_match(body, idx, fields_by_type) {
      Some(site) if helpers.get(site.owner) is Some(helper) => {
        let next = match output {
          Some(next) => next
          None => {
            let next = body[:idx].to_array()
            output = Some(next)
            next
          }
        }
        // All preceding operands belong to this single matched constructor.
        // Rewritten control nodes cannot occur inside its admitted flat span.
        next.truncate(next.length() - (idx - site.start))
        next.append([
          @lib.Instruction::local_get(@lib.LocalIdx::new(site.source)),
          @lib.Instruction::i32_const(site.field),
          @lib.Instruction::i32_const(site.value),
          @lib.Instruction::call(helper),
        ])
      }
      _ => {
        if !physical_equal(original, rewritten) && output is None {
          output = Some(body[:idx].to_array())
        }
        if output is Some(next) {
          next.push(rewritten)
        }
      }
    }
  }
  output.unwrap_or(body)
}

///|
fn gc_record_copy_helper(owner : UInt, fields : Int) -> @lib.Func {
  let body : Array[@lib.Instruction] = []
  for field in 0..<fields {
    body.append([
      @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::struct_get(
        @lib.TypeIdx::new(owner),
        @lib.U32::new(field.reinterpret_as_uint()),
      ),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::i32_const(field),
      @lib.Instruction::i32_eq(),
      @lib.Instruction::select(),
    ])
  }
  body.push(@lib.Instruction::struct_new(@lib.TypeIdx::new(owner)))
  @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
}

///|
fn gc_record_copy_initializer_bounded(
  expr : @lib.Expr,
  fields : @hashmap.HashMap[UInt, Int],
  counts : @hashmap.HashMap[UInt, Int],
  budget : Array[Int],
) -> Bool {
  if budget[0] <= 0 {
    return false
  }
  budget[0] -= 1
  ignore(fields)
  ignore(counts)
  gc_record_copy_preflight(expr.0, budget) is Some(_)
}

///|
fn gc_record_copy_initializers_bounded(
  mod_ : @lib.Module,
  fields : @hashmap.HashMap[UInt, Int],
  counts : @hashmap.HashMap[UInt, Int],
  budget : Array[Int],
) -> Bool {
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) => {
      if globals.length() > 65536 {
        return false
      }
      for @lib.Global(_, init) in globals {
        if !gc_record_copy_initializer_bounded(init, fields, counts, budget) {
          return false
        }
      }
    }
    None => ()
  }
  match mod_.table_sec {
    Some(@lib.TableSec(tables)) => {
      if tables.length() > 65536 {
        return false
      }
      for @lib.Table(_, init) in tables {
        if init is Some(expr) &&
          !gc_record_copy_initializer_bounded(expr, fields, counts, budget) {
          return false
        }
      }
    }
    None => ()
  }
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) => {
      if elems.length() > 65536 {
        return false
      }
      for @lib.Elem(mode, kind) in elems {
        if mode is @lib.Active(_, offset) &&
          !gc_record_copy_initializer_bounded(offset, fields, counts, budget) {
          return false
        }
        match kind {
          @lib.FuncExprsElemKind(exprs) | @lib.TypedExprsElemKind(_, exprs) => {
            if exprs.length() > 65536 {
              return false
            }
            for expr in exprs {
              if !gc_record_copy_initializer_bounded(
                  expr, fields, counts, budget,
                ) {
                return false
              }
            }
          }
          @lib.FuncsElemKind(funcs) =>
            if funcs.length() > 65536 {
              return false
            }
        }
      }
    }
    None => ()
  }
  match mod_.data_sec {
    Some(@lib.DataSec(datas)) => {
      if datas.length() > 65536 {
        return false
      }
      for @lib.Data(mode, _) in datas {
        if mode is @lib.Active(_, offset) &&
          !gc_record_copy_initializer_bounded(offset, fields, counts, budget) {
          return false
        }
      }
    }
    None => ()
  }
  true
}

///|
fn gc_record_copy_outline_module(mod_ : @lib.Module) -> @lib.Module {
  if mod_.func_annotation_sec is Some(_) ||
    pass_module_has_offset_sensitive_metadata(mod_) {
    return mod_
  }
  let (types, function_types, funcs) = match
    (mod_.type_sec, mod_.func_sec, mod_.code_sec) {
    (
      Some(@lib.TypeSec(types)),
      Some(@lib.FuncSec(function_types)),
      Some(@lib.CodeSec(funcs)),
    ) if funcs.length() <= 65536 && funcs.length() == function_types.length() =>
      (types, function_types, funcs)
    _ => return mod_
  }
  if types.length() > 65536 {
    return mod_
  }
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) if imports.length() > 65536 => return mod_
    _ => ()
  }
  let imported = run_hot_pipeline_imported_func_count(mod_)
  if imported > 65536 - funcs.length() {
    return mod_
  }
  let fields_by_type : @hashmap.HashMap[UInt, Int] = @hashmap.new()
  let mut type_count = 0
  for type_ in types {
    match type_ {
      @lib.SingleRecType(subtype) => {
        if gc_record_copy_type_fields(subtype) is Some(fields) {
          fields_by_type.set(type_count.reinterpret_as_uint(), fields)
        }
        type_count += 1
      }
      @lib.GroupRecType(group) => {
        if group.length() > 65536 - type_count {
          return mod_
        }
        type_count += group.length()
      }
    }
    if type_count > 65536 {
      return mod_
    }
  }
  if fields_by_type.is_empty() {
    return mod_
  }
  let signatures = msf_build_type_signature_cache(mod_)
  let supported : Array[Bool] = []
  let counts : @hashmap.HashMap[UInt, Int] = @hashmap.new()
  let budget = [8000000, 0]
  for idx in 0..<funcs.length() {
    let @lib.Func(locals, @lib.Expr(body)) = funcs[idx]
    let signature = msf_cached_signature(signatures, function_types[idx])
    // Charge declaration traversal before compressed snapshots or exact-type
    // checks. Empty bodies and excluded functions share the same module budget.
    let declaration_cost = match signature {
      Some(@lib.FuncType(params, results)) if params.length() <= 65536 &&
        results.length() <= 65536 &&
        locals.run_count() <= 65536 =>
        1 + params.length() + results.length() + locals.run_count()
      _ => return mod_
    }
    if declaration_cost > budget[0] {
      return mod_
    }
    budget[0] -= declaration_cost
    let local_count = match
      gc_record_copy_function_local_count(signature, locals) {
      Some(count) if count <= budget[0] => count
      _ => return mod_
    }
    // Full validation initializes every local, including excluded functions.
    // Charge that dense work as well as the compressed declaration traversal.
    budget[0] -= local_count
    let maximum = match gc_record_copy_preflight(body, budget) {
      Some(maximum) => maximum
      None => return mod_
    }
    let eligible = maximum <= 128 &&
      gc_record_copy_function_supported(signature, locals)
    supported.push(eligible)
    if eligible &&
      !gc_record_copy_scan(body, fields_by_type, counts, budget, 0, true) {
      return mod_
    }
  }
  if !gc_record_copy_initializers_bounded(mod_, fields_by_type, counts, budget) {
    return mod_
  }
  let owners : Array[UInt] = []
  for owner, count in counts {
    if count >= 8 {
      owners.push(owner)
    }
  }
  if owners.is_empty() ||
    owners.length() > 32 ||
    owners.length() > 65536 - type_count ||
    owners.length() > 65536 - funcs.length() - imported {
    return mod_
  }
  owners.sort()
  let helpers : @hashmap.HashMap[UInt, @lib.FuncIdx] = @hashmap.new()
  let next_types = types.copy()
  let next_function_types = function_types.copy()
  let next_funcs = funcs.copy()
  for ordinal in 0..<owners.length() {
    let owner = owners[ordinal]
    helpers.set(
      owner,
      @lib.FuncIdx::new(
        (imported + funcs.length() + ordinal).reinterpret_as_uint(),
      ),
    )
    let heap = @lib.HeapType::new(@lib.TypeIdx::new(owner))
    next_types.push(
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func(
            [
              @lib.ValType::ref_type(@lib.RefType::new(true, heap)),
              @lib.ValType::i32(),
              @lib.ValType::i32(),
            ],
            [@lib.ValType::ref_type(@lib.RefType::new(false, heap))],
          ),
        ),
      ),
    )
    next_function_types.push(
      @lib.TypeIdx::new((type_count + ordinal).reinterpret_as_uint()),
    )
    next_funcs.push(
      gc_record_copy_helper(owner, fields_by_type.get(owner).unwrap()),
    )
  }
  for idx in 0..<funcs.length() {
    if !supported[idx] {
      continue
    }
    let @lib.Func(locals, @lib.Expr(body)) = funcs[idx]
    let next = gc_record_copy_rewrite(body, fields_by_type, helpers)
    if !physical_equal(next, body) {
      next_funcs[idx] = @lib.Func::new(locals, @lib.Expr::new(next))
    }
  }
  let candidate = mod_
    .with_type_sec(@lib.TypeSec::new(next_types))
    .with_func_sec(@lib.FuncSec::new(next_function_types))
    .with_code_sec(@lib.CodeSec::new(next_funcs))
  match @binary.encoded_module_sizes(mod_, candidate) {
    Ok((before, after)) if after < before =>
      if @validate.validate_module(candidate) is Ok(_) {
        return candidate
      }
    _ => ()
  }
  mod_
}
