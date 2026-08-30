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
fn msf_call_type(
  module_ctx : @ir.HotModuleContext,
  target : @lib.FuncIdx,
) -> @lib.TypeIdx? {
  @ir.hot_module_resolve_func_type_idx(module_ctx, target)
}

///|
fn msf_legacy_catches_shape_hash(catches : Array[@lib.LegacyCatch]) -> Int {
  let mut key = catches.length().hash()
  for catch_ in catches {
    key *= 31
    match catch_ {
      @lib.LegacyCatch(tag, @lib.Expr(body)) =>
        key += (1 * 31 + tag.hash()) * 31 + msf_instrs_shape_hash(body)
      @lib.LegacyCatchAll(@lib.Expr(body)) =>
        key += 2 * 31 + msf_instrs_shape_hash(body)
    }
  }
  key
}

///|
fn msf_instr_shape_hash(instr : @lib.Instruction) -> Int {
  match instr {
    @lib.I32Const(_) => 1009
    @lib.I64Const(_) => 1013
    @lib.F32Const(_) => 1019
    @lib.F64Const(_) => 1021
    @lib.V128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) => 1031
    @lib.Call(_) => 1033
    @lib.ReturnCall(_) => 1039
    @lib.Block(block_type, @lib.Expr(body)) =>
      (1049 * 31 + block_type.hash()) * 31 + msf_instrs_shape_hash(body)
    @lib.Loop(block_type, @lib.Expr(body)) =>
      (1051 * 31 + block_type.hash()) * 31 + msf_instrs_shape_hash(body)
    @lib.If(block_type, then_body, else_body) => {
      let mut key = (1061 * 31 + block_type.hash()) * 31 +
        msf_instrs_shape_hash(then_body)
      match else_body {
        Some(body) => key = key * 31 + msf_instrs_shape_hash(body)
        None => key *= 31
      }
      key
    }
    @lib.Try(block_type, @lib.Expr(body), catches, delegate) =>
      (
        ((1063 * 31 + block_type.hash()) * 31 + delegate.hash()) * 31 +
        msf_instrs_shape_hash(body)
      ) *
      31 +
      msf_legacy_catches_shape_hash(catches)
    @lib.TryTable(block_type, catches, @lib.Expr(body)) =>
      ((1069 * 31 + block_type.hash()) * 31 + catches.hash()) * 31 +
      msf_instrs_shape_hash(body)
    _ => instr.hash()
  }
}

///|
fn msf_instrs_shape_hash(instrs : Array[@lib.Instruction]) -> Int {
  let mut key = instrs.length().hash()
  for instr in instrs {
    key = key * 31 + msf_instr_shape_hash(instr)
  }
  key
}

///|
fn msf_function_shape_hash(
  type_idx : @lib.TypeIdx,
  func : @lib.Func,
  module_ctx : @ir.HotModuleContext,
) -> Int {
  let @lib.Func(locals, @lib.Expr(body)) = func
  let type_hash = match
    @ir.hot_module_resolve_type_func_type(module_ctx, type_idx) {
    Some(func_type) => func_type.hash()
    None => type_idx.hash()
  }
  ((type_hash * 31 + locals.runs().hash()) * 31 + body.length().hash()) * 31 +
  msf_instrs_shape_hash(body)
}

///|
fn msf_legacy_catches_equivalent(
  left : Array[@lib.LegacyCatch],
  right : Array[@lib.LegacyCatch],
  module_ctx : @ir.HotModuleContext,
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
        if !msf_instrs_equivalent(left_body, right_body, module_ctx) {
          return false
        }
      (
        @lib.LegacyCatchAll(@lib.Expr(left_body)),
        @lib.LegacyCatchAll(@lib.Expr(right_body)),
      ) =>
        if !msf_instrs_equivalent(left_body, right_body, module_ctx) {
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
  module_ctx : @ir.HotModuleContext,
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
            msf_call_type(module_ctx, left_target),
            msf_call_type(module_ctx, right_target),
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
      msf_instrs_equivalent(left_body, right_body, module_ctx)
    (
      @lib.If(left_type, left_then, left_else),
      @lib.If(right_type, right_then, right_else),
    ) => {
      if left_type != right_type ||
        !msf_instrs_equivalent(left_then, right_then, module_ctx) {
        return false
      }
      match (left_else, right_else) {
        (Some(left_body), Some(right_body)) =>
          msf_instrs_equivalent(left_body, right_body, module_ctx)
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
      msf_instrs_equivalent(left_body, right_body, module_ctx) &&
      msf_legacy_catches_equivalent(left_catches, right_catches, module_ctx)
    (
      @lib.TryTable(left_type, left_catches, @lib.Expr(left_body)),
      @lib.TryTable(right_type, right_catches, @lib.Expr(right_body)),
    ) =>
      left_type == right_type &&
      left_catches == right_catches &&
      msf_instrs_equivalent(left_body, right_body, module_ctx)
    _ => left == right
  }
}

///|
fn msf_instrs_equivalent(
  left : Array[@lib.Instruction],
  right : Array[@lib.Instruction],
  module_ctx : @ir.HotModuleContext,
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for idx = 0; idx < left.length(); idx = idx + 1 {
    if !msf_instr_equivalent(left[idx], right[idx], module_ctx) {
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
  left_type : @lib.TypeIdx,
  left : @lib.Func,
  right_type : @lib.TypeIdx,
  right : @lib.Func,
  module_ctx : @ir.HotModuleContext,
) -> Bool {
  match
    (
      @ir.hot_module_resolve_type_func_type(module_ctx, left_type),
      @ir.hot_module_resolve_type_func_type(module_ctx, right_type),
    ) {
    (Some(left_signature), Some(right_signature)) if left_signature ==
      right_signature => ()
    _ => return false
  }
  let @lib.Func(left_locals, @lib.Expr(left_body)) = left
  let @lib.Func(right_locals, @lib.Expr(right_body)) = right
  if left_locals.length() != right_locals.length() ||
    !msf_instrs_equivalent(left_body, right_body, module_ctx) {
    return false
  }
  let param_count = match
    @ir.hot_module_resolve_type_func_type(module_ctx, left_type) {
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
  module_ctx : @ir.HotModuleContext,
  sites : Array[MsfSite],
) -> Bool {
  for instr in instrs {
    match msf_literal_type(instr) {
      Some(value_type) => {
        sites.push({ value: instr, value_type, call_type: None })
        continue
      }
      None => ()
    }
    match instr {
      @lib.Call(target) | @lib.ReturnCall(target) =>
        match msf_call_type(module_ctx, target) {
          Some(call_type) =>
            sites.push({
              value: @lib.Instruction::ref_func(target),
              value_type: msf_typed_func_ref(call_type),
              call_type: Some(call_type),
            })
          None => return false
        }
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        if !msf_collect_sites(body, module_ctx, sites) {
          return false
        }
      @lib.If(_, then_body, else_body) => {
        if !msf_collect_sites(then_body, module_ctx, sites) {
          return false
        }
        match else_body {
          Some(body) =>
            if !msf_collect_sites(body, module_ctx, sites) {
              return false
            }
          None => ()
        }
      }
      @lib.Try(_, @lib.Expr(body), catches, _) => {
        if !msf_collect_sites(body, module_ctx, sites) {
          return false
        }
        for catch_ in catches {
          let @lib.Expr(catch_body) = match catch_ {
            @lib.LegacyCatch(_, expr) | @lib.LegacyCatchAll(expr) => expr
          }
          if !msf_collect_sites(catch_body, module_ctx, sites) {
            return false
          }
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        if !msf_collect_sites(body, module_ctx, sites) {
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
fn msf_derive_params(
  funcs : Array[@lib.Func],
  class_ : MsfClass,
  module_ctx : @ir.HotModuleContext,
) -> (Array[MsfParam], Int)? {
  let member_sites : Array[Array[MsfSite]] = []
  for member_idx in class_.members {
    let @lib.Func(_, @lib.Expr(body)) = funcs[member_idx]
    let sites : Array[MsfSite] = []
    if !msf_collect_sites(body, module_ctx, sites) {
      return None
    }
    member_sites.push(sites)
  }
  if member_sites.is_empty() {
    return None
  }
  let site_count = member_sites[0].length()
  for sites in member_sites {
    if sites.length() != site_count {
      return None
    }
  }
  let params : Array[MsfParam] = []
  let mut site_idx = site_count - 1
  while site_idx >= 0 {
    let first = member_sites[0][site_idx]
    let values : Array[@lib.Instruction] = []
    let mut all_same = true
    for member_idx = 0
        member_idx < member_sites.length()
        member_idx = member_idx + 1 {
      let site = member_sites[member_idx][site_idx]
      if site.value_type != first.value_type ||
        site.call_type != first.call_type {
        return None
      }
      values.push(site.value)
      if site.value != first.value {
        all_same = false
      }
    }
    if all_same {
      site_idx -= 1
      continue
    }
    let mut reused = false
    for param in params {
      if param.value_type == first.value_type &&
        param.call_type == first.call_type &&
        msf_instruction_vectors_equal(param.values, values) {
        param.uses.push(site_idx)
        reused = true
        break
      }
    }
    if !reused {
      params.push({
        values,
        value_type: first.value_type,
        call_type: first.call_type,
        uses: [site_idx],
      })
    }
    site_idx -= 1
  }
  Some((params, site_count))
}

///|
fn msf_instr_count(instr : @lib.Instruction) -> Int {
  match instr {
    @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
      1 + msf_instrs_count(body)
    @lib.If(_, then_body, else_body) => {
      let mut count = 1 + msf_instrs_count(then_body)
      match else_body {
        Some(body) => count += msf_instrs_count(body)
        None => ()
      }
      count
    }
    @lib.Try(_, @lib.Expr(body), catches, _) => {
      let mut count = 1 + msf_instrs_count(body)
      for catch_ in catches {
        let @lib.Expr(catch_body) = match catch_ {
          @lib.LegacyCatch(_, expr) | @lib.LegacyCatchAll(expr) => expr
        }
        count += msf_instrs_count(catch_body)
      }
      count
    }
    @lib.TryTable(_, _, @lib.Expr(body)) => 1 + msf_instrs_count(body)
    _ => 1
  }
}

///|
fn msf_instrs_count(instrs : Array[@lib.Instruction]) -> Int {
  let mut count = 0
  for instr in instrs {
    count += msf_instr_count(instr)
  }
  count
}

///|
fn msf_has_merge_benefit(
  primary : @lib.Func,
  original_param_count : Int,
  member_count : Int,
  param_count : Int,
) -> Bool {
  if original_param_count + param_count > 255 {
    return false
  }
  let @lib.Func(_, @lib.Expr(body)) = primary
  let expression_size = msf_instrs_count(body)
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
fn msf_collect_classes(
  type_idxs : Array[@lib.TypeIdx],
  funcs : Array[@lib.Func],
  module_ctx : @ir.HotModuleContext,
) -> Array[MsfClass] {
  let first_by_hash : @hashmap.HashMap[Int, Int] = @hashmap.new(
    capacity=funcs.length(),
  )
  let collision_group_by_hash : @hashmap.HashMap[Int, Int] = @hashmap.new(
    capacity=funcs.length() / 8 + 1,
  )
  let hash_groups : Array[Array[Int]] = []
  for idx = 0; idx < funcs.length(); idx = idx + 1 {
    let key = msf_function_shape_hash(type_idxs[idx], funcs[idx], module_ctx)
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
            type_idxs[primary],
            funcs[primary],
            type_idxs[member_idx],
            funcs[member_idx],
            module_ctx,
          ) {
          class_.members.push(member_idx)
          found = true
          break
        }
      }
      if !found {
        group_classes.push({ members: [member_idx] })
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
pub fn merge_similar_functions_run_module_pass(
  mod_ : @lib.Module,
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
  let module_ctx = @ir.hot_module_context_from_module(mod_)
  let classes = msf_collect_classes(type_idxs, funcs, module_ctx)
  if classes.is_empty() {
    return mod_
  }
  let rec_types = match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) => rec_types.copy()
    None => []
  }
  let next_type_idxs = type_idxs.copy()
  let next_funcs = funcs.copy()
  let imported_count = run_hot_pipeline_imported_func_count(mod_)
  let base_type_count = @ir.hot_module_subtype_count(module_ctx)
  let use_tail_call = true
  let ref_targets : Array[@lib.FuncIdx] = []
  let mut merged_count = 0
  for class_ in classes {
    let primary_idx = class_.members[0]
    let signature = match
      @ir.hot_module_resolve_type_func_type(module_ctx, type_idxs[primary_idx]) {
      Some(signature) => signature
      None => continue
    }
    let @lib.FuncType(original_params, original_results) = signature
    let (params, site_count) = match
      msf_derive_params(funcs, class_, module_ctx) {
      Some(value) => value
      None => continue
    }
    if !msf_has_merge_benefit(
        funcs[primary_idx],
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
      next_funcs[class_.members[ordinal]] = msf_make_thunk(
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
  match @validate.validate_module(candidate) {
    Ok(_) => candidate
    Err(_) => mod_
  }
}
