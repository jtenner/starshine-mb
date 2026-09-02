///|
pub fn merge_similar_functions_summary() -> String {
  "Merge profitable near-duplicate defined functions through shared parameterized helpers and preserving thunks."
}

///|
priv struct MsfSite {
  value : @lib.Instruction
  value_type : @lib.ValType
  call_type : @lib.TypeIdx?
}

///|
priv struct MsfParam {
  values : Array[@lib.Instruction]
  value_type : @lib.ValType
  call_type : @lib.TypeIdx?
  uses : Array[Int]
}

///|
priv struct MsfClass {
  members : Array[Int]
}

///|
priv struct MsfFunctionSummary {
  signature : @lib.FuncType?
  shape_hash : Int
  instruction_count : Int
}

///|
fn msf_literal_type(instr : @lib.Instruction) -> @lib.ValType? {
  match instr {
    @lib.I32Const(_) => Some(@lib.ValType::i32())
    @lib.I64Const(_) => Some(@lib.ValType::i64())
    @lib.F32Const(_) => Some(@lib.ValType::f32())
    @lib.F64Const(_) => Some(@lib.ValType::f64())
    @lib.V128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      Some(@lib.ValType::v128())
    _ => None
  }
}

///|
fn msf_typed_func_ref(type_idx : @lib.TypeIdx) -> @lib.ValType {
  @lib.ValType::ref_type(@lib.RefType::new(false, @lib.HeapType::new(type_idx)))
}

///|
fn msf_build_call_type_cache(mod_ : @lib.Module) -> Array[@lib.TypeIdx?] {
  let call_types : Array[@lib.TypeIdx?] = []
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(type_idx)) =>
            call_types.push(Some(type_idx))
          _ => ()
        }
      }
    None => ()
  }
  match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) =>
      for type_idx in type_idxs {
        call_types.push(Some(type_idx))
      }
    None => ()
  }
  call_types
}

///|
fn msf_call_type_cached(
  call_types : Array[@lib.TypeIdx?],
  target : @lib.FuncIdx,
) -> @lib.TypeIdx? {
  let @lib.FuncIdx(raw) = target
  let idx = raw.reinterpret_as_int()
  if idx < 0 || idx >= call_types.length() {
    None
  } else {
    call_types[idx]
  }
}

///|
fn msf_analyze_legacy_catches(catches : Array[@lib.LegacyCatch]) -> (Int, Int) {
  let mut key = catches.length().hash()
  let mut count = 0
  for catch_ in catches {
    key *= 31
    match catch_ {
      @lib.LegacyCatch(tag, @lib.Expr(body)) => {
        let (body_hash, body_count) = msf_analyze_instrs(body)
        key += (1 * 31 + tag.hash()) * 31 + body_hash
        count += body_count
      }
      @lib.LegacyCatchAll(@lib.Expr(body)) => {
        let (body_hash, body_count) = msf_analyze_instrs(body)
        key += 2 * 31 + body_hash
        count += body_count
      }
    }
  }
  (key, count)
}

///|
fn msf_analyze_instr(instr : @lib.Instruction) -> (Int, Int) {
  match instr {
    @lib.I32Const(_) => (1009, 1)
    @lib.I64Const(_) => (1013, 1)
    @lib.F32Const(_) => (1019, 1)
    @lib.F64Const(_) => (1021, 1)
    @lib.V128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) => (1031, 1)
    @lib.Call(_) => (1033, 1)
    @lib.ReturnCall(_) => (1039, 1)
    @lib.Block(block_type, @lib.Expr(body)) => {
      let (body_hash, body_count) = msf_analyze_instrs(body)
      ((1049 * 31 + block_type.hash()) * 31 + body_hash, 1 + body_count)
    }
    @lib.Loop(block_type, @lib.Expr(body)) => {
      let (body_hash, body_count) = msf_analyze_instrs(body)
      ((1051 * 31 + block_type.hash()) * 31 + body_hash, 1 + body_count)
    }
    @lib.If(block_type, then_body, else_body) => {
      let (then_hash, then_count) = msf_analyze_instrs(then_body)
      let mut key = (1061 * 31 + block_type.hash()) * 31 + then_hash
      let mut count = 1 + then_count
      match else_body {
        Some(body) => {
          let (body_hash, body_count) = msf_analyze_instrs(body)
          key = key * 31 + body_hash
          count += body_count
        }
        None => key *= 31
      }
      (key, count)
    }
    @lib.Try(block_type, @lib.Expr(body), catches, delegate) => {
      let (body_hash, body_count) = msf_analyze_instrs(body)
      let (catches_hash, catches_count) = msf_analyze_legacy_catches(catches)
      (
        (
          ((1063 * 31 + block_type.hash()) * 31 + delegate.hash()) * 31 +
          body_hash
        ) *
        31 +
        catches_hash,
        1 + body_count + catches_count,
      )
    }
    @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
      let (body_hash, body_count) = msf_analyze_instrs(body)
      (
        ((1069 * 31 + block_type.hash()) * 31 + catches.hash()) * 31 + body_hash,
        1 + body_count,
      )
    }
    _ => (instr.hash(), 1)
  }
}

///|
fn msf_analyze_instrs(instrs : Array[@lib.Instruction]) -> (Int, Int) {
  let mut key = instrs.length().hash()
  let mut count = 0
  for instr in instrs {
    let (instr_hash, instr_count) = msf_analyze_instr(instr)
    key = key * 31 + instr_hash
    count += instr_count
  }
  (key, count)
}

///|
fn msf_build_type_signature_cache(mod_ : @lib.Module) -> Array[@lib.FuncType?] {
  let signatures : Array[@lib.FuncType?] = []
  match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) =>
      for rec_type in rec_types {
        match rec_type {
          @lib.SingleRecType(subtype) =>
            match subtype.get_comptype() {
              @lib.FuncCompType(params, results) =>
                signatures.push(Some(@lib.FuncType::new(params, results)))
              _ => signatures.push(None)
            }
          @lib.GroupRecType(subtypes) =>
            for subtype in subtypes {
              match subtype.get_comptype() {
                @lib.FuncCompType(params, results) =>
                  signatures.push(Some(@lib.FuncType::new(params, results)))
                _ => signatures.push(None)
              }
            }
        }
      }
    None => ()
  }
  signatures
}

///|
fn msf_cached_signature(
  signatures : Array[@lib.FuncType?],
  type_idx : @lib.TypeIdx,
) -> @lib.FuncType? {
  match type_idx {
    @lib.TypeIdx(raw) => {
      let idx = raw.reinterpret_as_int()
      if idx < 0 || idx >= signatures.length() {
        None
      } else {
        signatures[idx]
      }
    }
    @lib.RecIdx(_) => None
  }
}

///|
fn msf_build_function_summaries(
  type_idxs : Array[@lib.TypeIdx],
  funcs : Array[@lib.Func],
  signatures : Array[@lib.FuncType?],
) -> Array[MsfFunctionSummary] {
  let summaries : Array[MsfFunctionSummary] = []
  for idx = 0; idx < funcs.length(); idx = idx + 1 {
    let type_idx = type_idxs[idx]
    let signature = msf_cached_signature(signatures, type_idx)
    let @lib.Func(locals, @lib.Expr(body)) = funcs[idx]
    let (body_hash, instruction_count) = msf_analyze_instrs(body)
    let type_hash = match signature {
      Some(func_type) => func_type.hash()
      None => type_idx.hash()
    }
    summaries.push({
      signature,
      shape_hash: (
        (type_hash * 31 + locals.runs().hash()) * 31 + body.length().hash()
      ) *
      31 +
      body_hash,
      instruction_count,
    })
  }
  summaries
}

///|
fn msf_legacy_catches_equivalent(
  left : Array[@lib.LegacyCatch],
  right : Array[@lib.LegacyCatch],
  call_types : Array[@lib.TypeIdx?],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for idx = 0; idx < left.length(); idx = idx + 1 {
    match (left[idx], right[idx]) {
      (
        @lib.LegacyCatch(left_tag, @lib.Expr(left_body)),
        @lib.LegacyCatch(right_tag, @lib.Expr(right_body)),
      ) if left_tag == right_tag =>
        if !msf_instrs_equivalent(left_body, right_body, call_types) {
          return false
        }
      (
        @lib.LegacyCatchAll(@lib.Expr(left_body)),
        @lib.LegacyCatchAll(@lib.Expr(right_body)),
      ) =>
        if !msf_instrs_equivalent(left_body, right_body, call_types) {
          return false
        }
      _ => return false
    }
  }
  true
}

///|
fn msf_instr_equivalent(
  left : @lib.Instruction,
  right : @lib.Instruction,
  call_types : Array[@lib.TypeIdx?],
) -> Bool {
  match (left, right) {
    (@lib.I32Const(_), @lib.I32Const(_))
    | (@lib.I64Const(_), @lib.I64Const(_))
    | (@lib.F32Const(_), @lib.F32Const(_))
    | (@lib.F64Const(_), @lib.F64Const(_))
    | (
      @lib.V128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _),
      @lib.V128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _),
    ) => true
    (@lib.Call(left_target), @lib.Call(right_target))
    | (@lib.ReturnCall(left_target), @lib.ReturnCall(right_target)) =>
      if left_target == right_target {
        true
      } else {
        match
          (
            msf_call_type_cached(call_types, left_target),
            msf_call_type_cached(call_types, right_target),
          ) {
          (Some(left_type), Some(right_type)) => left_type == right_type
          _ => false
        }
      }
    (
      @lib.Block(left_type, @lib.Expr(left_body)),
      @lib.Block(right_type, @lib.Expr(right_body)),
    )
    | (
      @lib.Loop(left_type, @lib.Expr(left_body)),
      @lib.Loop(right_type, @lib.Expr(right_body)),
    ) =>
      left_type == right_type &&
      msf_instrs_equivalent(left_body, right_body, call_types)
    (
      @lib.If(left_type, left_then, left_else),
      @lib.If(right_type, right_then, right_else),
    ) => {
      if left_type != right_type ||
        !msf_instrs_equivalent(left_then, right_then, call_types) {
        return false
      }
      match (left_else, right_else) {
        (Some(left_body), Some(right_body)) =>
          msf_instrs_equivalent(left_body, right_body, call_types)
        (None, None) => true
        _ => false
      }
    }
    (
      @lib.Try(left_type, @lib.Expr(left_body), left_catches, left_delegate),
      @lib.Try(right_type, @lib.Expr(right_body), right_catches, right_delegate),
    ) =>
      left_type == right_type &&
      left_delegate == right_delegate &&
      msf_instrs_equivalent(left_body, right_body, call_types) &&
      msf_legacy_catches_equivalent(left_catches, right_catches, call_types)
    (
      @lib.TryTable(left_type, left_catches, @lib.Expr(left_body)),
      @lib.TryTable(right_type, right_catches, @lib.Expr(right_body)),
    ) =>
      left_type == right_type &&
      left_catches == right_catches &&
      msf_instrs_equivalent(left_body, right_body, call_types)
    _ => left == right
  }
}

///|
fn msf_instrs_equivalent(
  left : Array[@lib.Instruction],
  right : Array[@lib.Instruction],
  call_types : Array[@lib.TypeIdx?],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for idx = 0; idx < left.length(); idx = idx + 1 {
    if !msf_instr_equivalent(left[idx], right[idx], call_types) {
      return false
    }
  }
  true
}

///|
fn msf_local_access_types_compatible(
  instrs : Array[@lib.Instruction],
  left_locals : @lib.Locals,
  right_locals : @lib.Locals,
  param_count : Int,
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.LocalGet(@lib.LocalIdx(raw))
      | @lib.LocalSet(@lib.LocalIdx(raw))
      | @lib.LocalTee(@lib.LocalIdx(raw)) => {
        let idx = raw.reinterpret_as_int()
        if idx >= param_count &&
          left_locals.at(idx - param_count) !=
          right_locals.at(idx - param_count) {
          return false
        }
      }
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        if !msf_local_access_types_compatible(
            body, left_locals, right_locals, param_count,
          ) {
          return false
        }
      @lib.If(_, then_body, else_body) => {
        if !msf_local_access_types_compatible(
            then_body, left_locals, right_locals, param_count,
          ) {
          return false
        }
        match else_body {
          Some(body) =>
            if !msf_local_access_types_compatible(
                body, left_locals, right_locals, param_count,
              ) {
              return false
            }
          None => ()
        }
      }
      @lib.Try(_, @lib.Expr(body), catches, _) => {
        if !msf_local_access_types_compatible(
            body, left_locals, right_locals, param_count,
          ) {
          return false
        }
        for catch_ in catches {
          let @lib.Expr(catch_body) = match catch_ {
            @lib.LegacyCatch(_, expr) | @lib.LegacyCatchAll(expr) => expr
          }
          if !msf_local_access_types_compatible(
              catch_body, left_locals, right_locals, param_count,
            ) {
            return false
          }
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        if !msf_local_access_types_compatible(
            body, left_locals, right_locals, param_count,
          ) {
          return false
        }
      _ => ()
    }
  }
  true
}

///|
fn msf_functions_equivalent(
  left_idx : Int,
  right_idx : Int,
  funcs : Array[@lib.Func],
  summaries : Array[MsfFunctionSummary],
  call_types : Array[@lib.TypeIdx?],
) -> Bool {
  match (summaries[left_idx].signature, summaries[right_idx].signature) {
    (Some(left_signature), Some(right_signature)) if left_signature ==
      right_signature => ()
    _ => return false
  }
  let @lib.Func(left_locals, @lib.Expr(left_body)) = funcs[left_idx]
  let @lib.Func(right_locals, @lib.Expr(right_body)) = funcs[right_idx]
  if left_locals.length() != right_locals.length() ||
    !msf_instrs_equivalent(left_body, right_body, call_types) {
    return false
  }
  let param_count = match summaries[left_idx].signature {
    Some(@lib.FuncType(params, _)) => params.length()
    None => return false
  }
  msf_local_access_types_compatible(
    left_body, left_locals, right_locals, param_count,
  )
}

///|
fn msf_collect_sites(
  instrs : Array[@lib.Instruction],
  call_types : Array[@lib.TypeIdx?],
  sites : Array[MsfSite],
) -> Bool {
  for instr in instrs {
    match msf_literal_type(instr) {
      Some(value_type) => {
        sites.push({ value: instr, value_type, call_type: None, })
        continue
      }
      None => ()
    }
    match instr {
      @lib.Call(target) | @lib.ReturnCall(target) =>
        match msf_call_type_cached(call_types, target) {
          Some(call_type) =>
            sites.push({
              value: @lib.Instruction::ref_func(target),
              value_type: msf_typed_func_ref(call_type),
              call_type: Some(call_type),
            })
          None => return false
        }
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        if !msf_collect_sites(body, call_types, sites) {
          return false
        }
      @lib.If(_, then_body, else_body) => {
        if !msf_collect_sites(then_body, call_types, sites) {
          return false
        }
        match else_body {
          Some(body) =>
            if !msf_collect_sites(body, call_types, sites) {
              return false
            }
          None => ()
        }
      }
      @lib.Try(_, @lib.Expr(body), catches, _) => {
        if !msf_collect_sites(body, call_types, sites) {
          return false
        }
        for catch_ in catches {
          let @lib.Expr(catch_body) = match catch_ {
            @lib.LegacyCatch(_, expr) | @lib.LegacyCatchAll(expr) => expr
          }
          if !msf_collect_sites(catch_body, call_types, sites) {
            return false
          }
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        if !msf_collect_sites(body, call_types, sites) {
          return false
        }
      _ => ()
    }
  }
  true
}

///|
fn msf_collect_site_values(
  instrs : Array[@lib.Instruction],
  call_types : Array[@lib.TypeIdx?],
  values : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    if msf_literal_type(instr) is Some(_) {
      values.push(instr)
      continue
    }
    match instr {
      @lib.Call(target) | @lib.ReturnCall(target) =>
        match msf_call_type_cached(call_types, target) {
          Some(_) => values.push(@lib.Instruction::ref_func(target))
          None => return false
        }
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        if !msf_collect_site_values(body, call_types, values) {
          return false
        }
      @lib.If(_, then_body, else_body) => {
        if !msf_collect_site_values(then_body, call_types, values) {
          return false
        }
        match else_body {
          Some(body) =>
            if !msf_collect_site_values(body, call_types, values) {
              return false
            }
          None => ()
        }
      }
      @lib.Try(_, @lib.Expr(body), catches, _) => {
        if !msf_collect_site_values(body, call_types, values) {
          return false
        }
        for catch_ in catches {
          let @lib.Expr(catch_body) = match catch_ {
            @lib.LegacyCatch(_, expr) | @lib.LegacyCatchAll(expr) => expr
          }
          if !msf_collect_site_values(catch_body, call_types, values) {
            return false
          }
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        if !msf_collect_site_values(body, call_types, values) {
          return false
        }
      _ => ()
    }
  }
  true
}

///|
fn msf_instruction_vectors_equal(
  left : Array[@lib.Instruction],
  right : Array[@lib.Instruction],
) -> Bool {
  left == right
}

///|
fn msf_param_vector_hash(
  value_type : @lib.ValType,
  call_type : @lib.TypeIdx?,
  values : Array[@lib.Instruction],
) -> Int {
  (value_type.hash() * 31 + call_type.hash()) * 31 + values.hash()
}

///|
fn msf_derive_params(
  funcs : Array[@lib.Func],
  class_ : MsfClass,
  call_types : Array[@lib.TypeIdx?],
) -> (Array[MsfParam], Int)? {
  if class_.members.is_empty() {
    return None
  }
  let primary_idx = class_.members[0]
  let @lib.Func(_, @lib.Expr(primary_body)) = funcs[primary_idx]
  let primary_sites : Array[MsfSite] = []
  if !msf_collect_sites(primary_body, call_types, primary_sites) {
    return None
  }
  let site_count = primary_sites.length()
  let member_values : Array[Array[@lib.Instruction]] = []
  let primary_values : Array[@lib.Instruction] = []
  for site in primary_sites {
    primary_values.push(site.value)
  }
  member_values.push(primary_values)
  for ordinal = 1; ordinal < class_.members.length(); ordinal = ordinal + 1 {
    let @lib.Func(_, @lib.Expr(body)) = funcs[class_.members[ordinal]]
    let values : Array[@lib.Instruction] = []
    if !msf_collect_site_values(body, call_types, values) ||
      values.length() != site_count {
      return None
    }
    member_values.push(values)
  }
  let params : Array[MsfParam] = []
  let param_indices_by_hash : @hashmap.HashMap[Int, Array[Int]] = @hashmap.new(
    capacity=site_count / 4 + 1,
  )
  let mut site_idx = site_count - 1
  while site_idx >= 0 {
    let first = primary_sites[site_idx]
    let mut all_same = true
    for member_idx = 1
        member_idx < member_values.length()
        member_idx = member_idx + 1 {
      if member_values[member_idx][site_idx] != first.value {
        all_same = false
        break
      }
    }
    if all_same {
      site_idx -= 1
      continue
    }
    let values : Array[@lib.Instruction] = []
    for member_idx = 0
        member_idx < member_values.length()
        member_idx = member_idx + 1 {
      values.push(member_values[member_idx][site_idx])
    }
    let key = msf_param_vector_hash(first.value_type, first.call_type, values)
    let mut reused = false
    match param_indices_by_hash.get(key) {
      Some(candidate_indices) =>
        for param_idx in candidate_indices {
          let param = params[param_idx]
          if param.value_type == first.value_type &&
            param.call_type == first.call_type &&
            msf_instruction_vectors_equal(param.values, values) {
            param.uses.push(site_idx)
            reused = true
            break
          }
        }
      None => ()
    }
    if !reused {
      let param_idx = params.length()
      params.push({
        values,
        value_type: first.value_type,
        call_type: first.call_type,
        uses: [site_idx],
      })
      match param_indices_by_hash.get(key) {
        Some(indices) => indices.push(param_idx)
        None => param_indices_by_hash.set(key, [param_idx])
      }
    }
    site_idx -= 1
  }
  Some((params, site_count))
}

///|
fn msf_has_merge_benefit_for_count(
  expression_size : Int,
  original_param_count : Int,
  member_count : Int,
  param_count : Int,
) -> Bool {
  if original_param_count + param_count > 255 {
    return false
  }
  let positive_score = (member_count - 1) * expression_size
  let negative_score = member_count * (1 + original_param_count + param_count) +
    member_count * (param_count + 2) +
    member_count * 2
  negative_score < positive_score
}

///|
fn msf_site_param_map(params : Array[MsfParam], site_count : Int) -> Array[Int] {
  let site_to_param = Array::make(site_count, -1)
  for param_idx = 0; param_idx < params.length(); param_idx = param_idx + 1 {
    for site_idx in params[param_idx].uses {
      site_to_param[site_idx] = param_idx
    }
  }
  site_to_param
}

///|
fn msf_shift_local_idx(
  local_idx : @lib.LocalIdx,
  original_param_count : Int,
  extra_param_count : Int,
) -> @lib.LocalIdx {
  let @lib.LocalIdx(raw) = local_idx
  let idx = raw.reinterpret_as_int()
  if idx < original_param_count {
    local_idx
  } else {
    @lib.LocalIdx::new((idx + extra_param_count).reinterpret_as_uint())
  }
}

///|
fn msf_rewrite_shared_legacy_catches(
  catches : Array[@lib.LegacyCatch],
  params : Array[MsfParam],
  site_to_param : Array[Int],
  site_cursor : Array[Int],
  original_param_count : Int,
) -> Array[@lib.LegacyCatch] {
  let out : Array[@lib.LegacyCatch] = []
  for catch_ in catches {
    match catch_ {
      @lib.LegacyCatch(tag, @lib.Expr(body)) =>
        out.push(
          @lib.LegacyCatch::tagged(
            tag,
            @lib.Expr::new(
              msf_rewrite_shared_instrs(
                body, params, site_to_param, site_cursor, original_param_count,
              ),
            ),
          ),
        )
      @lib.LegacyCatchAll(@lib.Expr(body)) =>
        out.push(
          @lib.LegacyCatch::all(
            @lib.Expr::new(
              msf_rewrite_shared_instrs(
                body, params, site_to_param, site_cursor, original_param_count,
              ),
            ),
          ),
        )
    }
  }
  out
}

///|
fn msf_rewrite_shared_instrs(
  instrs : Array[@lib.Instruction],
  params : Array[MsfParam],
  site_to_param : Array[Int],
  site_cursor : Array[Int],
  original_param_count : Int,
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    let is_site = msf_literal_type(instr) is Some(_) ||
      instr is @lib.Call(_) ||
      instr is @lib.ReturnCall(_)
    if is_site {
      let site_idx = site_cursor[0]
      site_cursor[0] += 1
      let param_idx = site_to_param[site_idx]
      if param_idx >= 0 {
        let local_idx = @lib.LocalIdx::new(
          (original_param_count + param_idx).reinterpret_as_uint(),
        )
        match instr {
          @lib.Call(_) => {
            out.push(@lib.Instruction::local_get(local_idx))
            match params[param_idx].call_type {
              Some(call_type) => out.push(@lib.Instruction::call_ref(call_type))
              None => abort("MSF call site missing call type")
            }
          }
          @lib.ReturnCall(_) => {
            out.push(@lib.Instruction::local_get(local_idx))
            match params[param_idx].call_type {
              Some(call_type) =>
                out.push(@lib.Instruction::return_call_ref(call_type))
              None => abort("MSF return_call site missing call type")
            }
          }
          _ => out.push(@lib.Instruction::local_get(local_idx))
        }
        continue
      }
    }
    match instr {
      @lib.Block(block_type, @lib.Expr(body)) =>
        out.push(
          @lib.Instruction::block(
            block_type,
            @lib.Expr::new(
              msf_rewrite_shared_instrs(
                body, params, site_to_param, site_cursor, original_param_count,
              ),
            ),
          ),
        )
      @lib.Loop(block_type, @lib.Expr(body)) =>
        out.push(
          @lib.Instruction::loop_(
            block_type,
            @lib.Expr::new(
              msf_rewrite_shared_instrs(
                body, params, site_to_param, site_cursor, original_param_count,
              ),
            ),
          ),
        )
      @lib.If(block_type, then_body, else_body) =>
        out.push(
          @lib.Instruction::if_(
            block_type,
            msf_rewrite_shared_instrs(
              then_body, params, site_to_param, site_cursor, original_param_count,
            ),
            match else_body {
              Some(body) =>
                Some(
                  msf_rewrite_shared_instrs(
                    body, params, site_to_param, site_cursor, original_param_count,
                  ),
                )
              None => None
            },
          ),
        )
      @lib.Try(block_type, @lib.Expr(body), catches, delegate) =>
        out.push(
          @lib.Instruction::try_(
            block_type,
            @lib.Expr::new(
              msf_rewrite_shared_instrs(
                body, params, site_to_param, site_cursor, original_param_count,
              ),
            ),
            msf_rewrite_shared_legacy_catches(
              catches, params, site_to_param, site_cursor, original_param_count,
            ),
            delegate~,
          ),
        )
      @lib.TryTable(block_type, catches, @lib.Expr(body)) =>
        out.push(
          @lib.Instruction::try_table(
            block_type,
            catches,
            @lib.Expr::new(
              msf_rewrite_shared_instrs(
                body, params, site_to_param, site_cursor, original_param_count,
              ),
            ),
          ),
        )
      @lib.LocalGet(local_idx) =>
        out.push(
          @lib.Instruction::local_get(
            msf_shift_local_idx(
              local_idx,
              original_param_count,
              params.length(),
            ),
          ),
        )
      @lib.LocalSet(local_idx) =>
        out.push(
          @lib.Instruction::local_set(
            msf_shift_local_idx(
              local_idx,
              original_param_count,
              params.length(),
            ),
          ),
        )
      @lib.LocalTee(local_idx) =>
        out.push(
          @lib.Instruction::local_tee(
            msf_shift_local_idx(
              local_idx,
              original_param_count,
              params.length(),
            ),
          ),
        )
      _ => out.push(instr)
    }
  }
  out
}

///|
fn msf_make_thunk(
  original_param_count : Int,
  params : Array[MsfParam],
  member_ordinal : Int,
  helper_idx : @lib.FuncIdx,
  use_tail_call : Bool,
) -> @lib.Func {
  let body : Array[@lib.Instruction] = []
  for param_idx = 0; param_idx < original_param_count; param_idx = param_idx + 1 {
    body.push(
      @lib.Instruction::local_get(
        @lib.LocalIdx::new(param_idx.reinterpret_as_uint()),
      ),
    )
  }
  for param in params {
    body.push(param.values[member_ordinal])
  }
  body.push(
    if use_tail_call {
      @lib.Instruction::return_call(helper_idx)
    } else {
      @lib.Instruction::call(helper_idx)
    },
  )
  @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
}

///|
fn msf_append_declarative_targets(
  mod_ : @lib.Module,
  targets : Array[@lib.FuncIdx],
) -> @lib.Module {
  if targets.is_empty() {
    return mod_
  }
  let unique : Array[@lib.FuncIdx] = []
  for target in targets {
    if !unique.contains(target) {
      unique.push(target)
    }
  }
  let elems = match mod_.elem_sec {
    Some(@lib.ElemSec(existing)) => existing.copy()
    None => []
  }
  elems.push(
    @lib.Elem::new(@lib.ElemMode::declarative(), @lib.ElemKind::funcs(unique)),
  )
  mod_.with_elem_sec(@lib.ElemSec::new(elems))
}

///|
fn msf_validate_append_only_candidate_detail(
  original : @lib.Module,
  candidate : @lib.Module,
) -> Result[Unit, String] {
  if original.custom_secs != candidate.custom_secs ||
    original.import_sec != candidate.import_sec ||
    original.func_annotation_sec != candidate.func_annotation_sec ||
    original.table_sec != candidate.table_sec ||
    original.mem_sec != candidate.mem_sec ||
    original.tag_sec != candidate.tag_sec ||
    original.stringrefs_sec != candidate.stringrefs_sec ||
    original.global_sec != candidate.global_sec ||
    original.export_sec != candidate.export_sec ||
    original.start_sec != candidate.start_sec ||
    original.data_cnt_sec != candidate.data_cnt_sec ||
    original.data_sec != candidate.data_sec {
    return Err("untouched module section changed")
  }
  let original_elems = match original.elem_sec {
    Some(@lib.ElemSec(elems)) => elems
    None => []
  }
  let candidate_elems = match candidate.elem_sec {
    Some(@lib.ElemSec(elems)) => elems
    None => []
  }
  if candidate_elems.length() < original_elems.length() ||
    candidate_elems.length() > original_elems.length() + 1 {
    return Err("candidate element section is not append-only")
  }
  for idx = 0; idx < original_elems.length(); idx = idx + 1 {
    if original_elems[idx] != candidate_elems[idx] {
      return Err("existing element segment changed")
    }
  }
  if candidate_elems.length() == original_elems.length() + 1 {
    match candidate_elems[candidate_elems.length() - 1] {
      @lib.Elem(@lib.Declarative, @lib.FuncsElemKind(_)) => ()
      _ => return Err("appended element segment is not declarative funcs")
    }
  }
  let original_types = match original.type_sec {
    Some(@lib.TypeSec(types)) => types
    None => []
  }
  let candidate_types = match candidate.type_sec {
    Some(@lib.TypeSec(types)) => types
    None => []
  }
  if candidate_types.length() < original_types.length() {
    return Err("candidate type section shrank")
  }
  for idx = 0; idx < original_types.length(); idx = idx + 1 {
    if original_types[idx] != candidate_types[idx] {
      return Err("original type prefix changed")
    }
  }
  let original_type_idxs = match original.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs
    None => []
  }
  let candidate_type_idxs = match candidate.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs
    None => []
  }
  let original_funcs = match original.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => []
  }
  let candidate_funcs = match candidate.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => []
  }
  if original_type_idxs.length() != original_funcs.length() ||
    candidate_type_idxs.length() != candidate_funcs.length() ||
    candidate_funcs.length() < original_funcs.length() {
    return Err("function/code section length invariant failed")
  }
  for idx = 0; idx < original_type_idxs.length(); idx = idx + 1 {
    if original_type_idxs[idx] != candidate_type_idxs[idx] {
      return Err("original function type prefix changed")
    }
  }
  let imported_count = run_hot_pipeline_imported_func_count(original)
  let funcs_to_validate : Array[(@lib.FuncIdx, @lib.Func)] = []
  for idx = 0; idx < original_funcs.length(); idx = idx + 1 {
    if original_funcs[idx] != candidate_funcs[idx] {
      funcs_to_validate.push(
        (
          @lib.FuncIdx::new((imported_count + idx).reinterpret_as_uint()),
          candidate_funcs[idx],
        ),
      )
    }
  }
  for idx = original_funcs.length()
      idx < candidate_funcs.length()
      idx = idx + 1 {
    funcs_to_validate.push(
      (
        @lib.FuncIdx::new((imported_count + idx).reinterpret_as_uint()),
        candidate_funcs[idx],
      ),
    )
  }
  match
    @validate.validate_defined_funcs_against_module(
      candidate, funcs_to_validate,
    ) {
    Ok(errors) if errors.is_empty() => Ok(())
    Ok(errors) => Err("changed function validation failed: \{errors}")
    Err(err) => Err("candidate environment validation failed: \{err}")
  }
}

///|
fn msf_collect_classes(
  funcs : Array[@lib.Func],
  summaries : Array[MsfFunctionSummary],
  call_types : Array[@lib.TypeIdx?],
) -> Array[MsfClass] {
  let first_by_hash : @hashmap.HashMap[Int, Int] = @hashmap.new(
    capacity=funcs.length(),
  )
  let collision_group_by_hash : @hashmap.HashMap[Int, Int] = @hashmap.new(
    capacity=funcs.length() / 8 + 1,
  )
  let hash_groups : Array[Array[Int]] = []
  for idx = 0; idx < funcs.length(); idx = idx + 1 {
    let key = summaries[idx].shape_hash
    match first_by_hash.get(key) {
      Some(first_idx) =>
        match collision_group_by_hash.get(key) {
          Some(group_idx) => hash_groups[group_idx].push(idx)
          None => {
            collision_group_by_hash.set(key, hash_groups.length())
            hash_groups.push([first_idx, idx])
          }
        }
      None => first_by_hash.set(key, idx)
    }
  }
  let classes : Array[MsfClass] = []
  for group in hash_groups {
    let group_classes : Array[MsfClass] = []
    for member_idx in group {
      let mut found = false
      for class_ in group_classes {
        let primary = class_.members[0]
        if msf_functions_equivalent(
            primary, member_idx, funcs, summaries, call_types,
          ) {
          class_.members.push(member_idx)
          found = true
          break
        }
      }
      if !found {
        group_classes.push({ members: [member_idx], })
      }
    }
    for class_ in group_classes {
      if class_.members.length() >= 2 {
        classes.push(class_)
      }
    }
  }
  classes.sort_by(fn(left, right) { left.members[0] - right.members[0] })
  classes
}

///|
fn msf_run_module_pass_with_perf(
  mod_ : @lib.Module,
  perf : HotPerfSession?,
) -> @lib.Module {
  if mod_.func_annotation_sec is Some(_) {
    return mod_
  }
  let (type_idxs, funcs) = match (mod_.func_sec, mod_.code_sec) {
    (Some(@lib.FuncSec(type_idxs)), Some(@lib.CodeSec(funcs))) if type_idxs.length() ==
      funcs.length() &&
      funcs.length() >= 2 => (type_idxs, funcs)
    _ => return mod_
  }
  let analysis_start_us = perf_start_timer_opt(
    perf, "detail:msf:build-analysis",
  )
  let call_types = msf_build_call_type_cache(mod_)
  let signatures = msf_build_type_signature_cache(mod_)
  let summaries = msf_build_function_summaries(type_idxs, funcs, signatures)
  perf_stop_timer_opt(perf, "detail:msf:build-analysis", analysis_start_us)
  let classes_start_us = perf_start_timer_opt(
    perf, "detail:msf:collect-classes",
  )
  let classes = msf_collect_classes(funcs, summaries, call_types)
  perf_stop_timer_opt(perf, "detail:msf:collect-classes", classes_start_us)
  if classes.is_empty() {
    return mod_
  }
  let plan_start_us = perf_start_timer_opt(perf, "detail:msf:plan-and-rewrite")
  let rec_types = match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) => rec_types.copy()
    None => []
  }
  let next_type_idxs = type_idxs.copy()
  let next_funcs = funcs.copy()
  let imported_count = run_hot_pipeline_imported_func_count(mod_)
  let base_type_count = signatures.length()
  let use_tail_call = true
  let ref_targets : Array[@lib.FuncIdx] = []
  let mut merged_count = 0
  for class_ in classes {
    let primary_idx = class_.members[0]
    let signature = match summaries[primary_idx].signature {
      Some(signature) => signature
      None => continue
    }
    let @lib.FuncType(original_params, original_results) = signature
    let (params, site_count) = match
      msf_derive_params(funcs, class_, call_types) {
      Some(value) => value
      None => continue
    }
    if !msf_has_merge_benefit_for_count(
        summaries[primary_idx].instruction_count,
        original_params.length(),
        class_.members.length(),
        params.length(),
      ) {
      continue
    }
    let helper_type_idx = @lib.TypeIdx::new(
      (base_type_count + merged_count).reinterpret_as_uint(),
    )
    let helper_params = original_params.copy()
    for param in params {
      helper_params.push(param.value_type)
      match param.call_type {
        Some(_) =>
          for value in param.values {
            match value {
              @lib.RefFunc(target) => ref_targets.push(target)
              _ => ()
            }
          }
        None => ()
      }
    }
    rec_types.push(
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func(helper_params, original_results.copy()),
        ),
      ),
    )
    let helper_idx = @lib.FuncIdx::new(
      (imported_count + next_funcs.length()).reinterpret_as_uint(),
    )
    let @lib.Func(primary_locals, @lib.Expr(primary_body)) = funcs[primary_idx]
    let helper_body = msf_rewrite_shared_instrs(
      primary_body,
      params,
      msf_site_param_map(params, site_count),
      [0],
      original_params.length(),
    )
    for ordinal = 0; ordinal < class_.members.length(); ordinal = ordinal + 1 {
      let member_idx = class_.members[ordinal]
      next_funcs[member_idx] = msf_make_thunk(
        original_params.length(),
        params,
        ordinal,
        helper_idx,
        use_tail_call,
      )
    }
    next_type_idxs.push(helper_type_idx)
    next_funcs.push(
      @lib.Func::new(primary_locals.copy(), @lib.Expr::new(helper_body)),
    )
    merged_count += 1
  }
  if merged_count == 0 {
    perf_stop_timer_opt(perf, "detail:msf:plan-and-rewrite", plan_start_us)
    return mod_
  }
  let candidate = msf_append_declarative_targets(
    mod_
    .with_type_sec(@lib.TypeSec::new(rec_types))
    .with_func_sec(@lib.FuncSec::new(next_type_idxs))
    .with_code_sec(@lib.CodeSec::new(next_funcs))
    .without_name_sec(),
    ref_targets,
  )
  perf_stop_timer_opt(perf, "detail:msf:plan-and-rewrite", plan_start_us)
  let validate_start_us = perf_start_timer_opt(
    perf, "detail:msf:validate-candidate",
  )
  let result = match
    msf_validate_append_only_candidate_detail(mod_, candidate) {
    Ok(_) => candidate
    Err(reason) => {
      match perf {
        Some(session) =>
          (session.trace)("msf:validation-reject reason=\{reason}")
        None => ()
      }
      mod_
    }
  }
  perf_stop_timer_opt(perf, "detail:msf:validate-candidate", validate_start_us)
  result
}

///|
pub fn merge_similar_functions_run_module_pass(
  mod_ : @lib.Module,
) -> @lib.Module {
  msf_run_module_pass_with_perf(mod_, None)
}
