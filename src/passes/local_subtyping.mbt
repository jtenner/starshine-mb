///|
pub fn local_subtyping_summary() -> String {
  "Narrow reference-typed body locals to the most specific safe supertype of their writes."
}

///|
fn ls_imported_func_count(mod_ : @lib.Module) -> Int {
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
fn ls_abs_heap_is_subtype(
  source : @lib.AbsHeapType,
  target : @lib.AbsHeapType,
) -> Bool {
  if source == target {
    return true
  }
  match (source, target) {
    (@lib.NoneAbsHeapType, @lib.StructAbsHeapType)
    | (@lib.NoneAbsHeapType, @lib.ArrayAbsHeapType)
    | (@lib.NoneAbsHeapType, @lib.EqAbsHeapType)
    | (@lib.NoneAbsHeapType, @lib.AnyAbsHeapType)
    | (@lib.NoFuncAbsHeapType, @lib.FuncAbsHeapType)
    | (@lib.NoFuncAbsHeapType, @lib.AnyAbsHeapType)
    | (@lib.NoExternAbsHeapType, @lib.ExternAbsHeapType)
    | (@lib.NoExnAbsHeapType, @lib.ExnAbsHeapType)
    | (@lib.I31AbsHeapType, @lib.EqAbsHeapType)
    | (@lib.I31AbsHeapType, @lib.AnyAbsHeapType)
    | (@lib.StructAbsHeapType, @lib.EqAbsHeapType)
    | (@lib.StructAbsHeapType, @lib.AnyAbsHeapType)
    | (@lib.ArrayAbsHeapType, @lib.EqAbsHeapType)
    | (@lib.ArrayAbsHeapType, @lib.AnyAbsHeapType)
    | (@lib.EqAbsHeapType, @lib.AnyAbsHeapType)
    | (@lib.FuncAbsHeapType, @lib.AnyAbsHeapType)
    | (@lib.ExternAbsHeapType, @lib.AnyAbsHeapType) => true
    _ => false
  }
}

///|
fn ls_comptype_matches_abs(ct : @lib.CompType, abs : @lib.AbsHeapType) -> Bool {
  match ct {
    @lib.StructCompType(_) =>
      abs == @lib.AbsHeapType::struct_() ||
      abs == @lib.AbsHeapType::eq() ||
      abs == @lib.AbsHeapType::any()
    @lib.ArrayCompType(_) =>
      abs == @lib.AbsHeapType::array() ||
      abs == @lib.AbsHeapType::eq() ||
      abs == @lib.AbsHeapType::any()
    @lib.FuncCompType(_, _) =>
      abs == @lib.AbsHeapType::func() || abs == @lib.AbsHeapType::any()
  }
}

///|
fn ls_subtype_as_heap_is_subtype(
  module_ctx : @ir.HotModuleContext,
  subtype : @lib.SubType,
  target : @lib.HeapType,
  fuel : Int,
) -> Bool {
  if fuel <= 0 {
    return false
  }
  let (is_final, supers, ct) = match subtype {
    @lib.CompTypeSubType(_, ct) => (false, [], ct)
    @lib.SubType(is_final, supers, _, ct) => (is_final, supers, ct)
  }
  match target {
    @lib.AbsHeapTypeHeapType(abs) => {
      if ls_comptype_matches_abs(ct, abs) {
        return true
      }
      if is_final {
        return false
      }
    }
    _ => ()
  }
  for super_idx in supers {
    if ls_heap_is_subtype(
        module_ctx,
        @lib.HeapType::new(super_idx),
        target,
        fuel - 1,
      ) {
      return true
    }
  }
  false
}

///|
fn ls_heap_is_subtype(
  module_ctx : @ir.HotModuleContext,
  source : @lib.HeapType,
  target : @lib.HeapType,
  fuel : Int,
) -> Bool {
  if source == target {
    return true
  }
  if fuel <= 0 {
    return false
  }
  match (source, target) {
    (@lib.AbsHeapTypeHeapType(source_abs), @lib.AbsHeapTypeHeapType(target_abs)) =>
      ls_abs_heap_is_subtype(source_abs, target_abs)
    (@lib.HeapType(source_idx), _) =>
      match @ir.hot_module_resolve_subtype(module_ctx, source_idx) {
        Some(subtype) =>
          ls_subtype_as_heap_is_subtype(module_ctx, subtype, target, fuel - 1)
        None => false
      }
    (_, @lib.HeapType(target_idx)) =>
      match source {
        @lib.AbsHeapTypeHeapType(@lib.NoneAbsHeapType) =>
          match @ir.hot_module_resolve_subtype(module_ctx, target_idx) {
            Some(subtype) =>
              match subtype.get_comptype() {
                @lib.StructCompType(_) | @lib.ArrayCompType(_) => true
                _ => false
              }
            None => false
          }
        @lib.AbsHeapTypeHeapType(@lib.NoFuncAbsHeapType) =>
          match @ir.hot_module_resolve_subtype(module_ctx, target_idx) {
            Some(subtype) =>
              match subtype.get_comptype() {
                @lib.FuncCompType(_, _) => true
                _ => false
              }
            None => false
          }
        _ => false
      }
    _ => false
  }
}

///|
fn ls_ref_is_subtype(
  module_ctx : @ir.HotModuleContext,
  source : @lib.RefType,
  target : @lib.RefType,
) -> Bool {
  if source.is_nullable() && !target.is_nullable() {
    return false
  }
  if target.is_exact() {
    return source.is_exact() && source.get_heap_type() == target.get_heap_type()
  }
  ls_heap_is_subtype(
    module_ctx,
    source.get_heap_type(),
    target.get_heap_type(),
    512,
  )
}

///|
fn ls_as_ref(vt : @lib.ValType) -> @lib.RefType? {
  match vt {
    @lib.RefTypeValType(ref_type) => Some(ref_type)
    _ => None
  }
}

///|
fn ls_local_idx_raw(idx : @lib.LocalIdx) -> Int {
  let @lib.LocalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn ls_ref_body_local_mask(body_locals : @lib.Locals) -> Array[Bool]? {
  let body_local_count = body_locals.length()
  let mask : Array[Bool] = Array::new(capacity=body_local_count)
  let mut has_ref = false
  for body_idx = 0; body_idx < body_local_count; body_idx = body_idx + 1 {
    match ls_as_ref(body_locals[body_idx]) {
      Some(_) => {
        mask.push(true)
        has_ref = true
      }
      None => mask.push(false)
    }
  }
  if has_ref {
    Some(mask)
  } else {
    None
  }
}

///|
fn ls_write_targets_ref_body_local(
  idx : @lib.LocalIdx,
  param_count : Int,
  ref_body_locals : Array[Bool],
) -> Bool {
  let raw = ls_local_idx_raw(idx)
  let body_idx = raw - param_count
  body_idx >= 0 &&
  body_idx < ref_body_locals.length() &&
  ref_body_locals[body_idx]
}

///|
fn ls_instrs_write_ref_body_local(
  instrs : Array[@lib.Instruction],
  param_count : Int,
  ref_body_locals : Array[Bool],
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Block(_, body) | @lib.Loop(_, body) | @lib.TryTable(_, _, body) =>
        if ls_expr_writes_ref_body_local(body, param_count, ref_body_locals) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if ls_instrs_write_ref_body_local(
            then_body, param_count, ref_body_locals,
          ) {
          return true
        }
        match else_body {
          Some(body) =>
            if ls_instrs_write_ref_body_local(
                body, param_count, ref_body_locals,
              ) {
              return true
            }
          None => ()
        }
      }
      @lib.LocalSet(idx) | @lib.LocalTee(idx) =>
        if ls_write_targets_ref_body_local(idx, param_count, ref_body_locals) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn ls_expr_writes_ref_body_local(
  expr : @lib.Expr,
  param_count : Int,
  ref_body_locals : Array[Bool],
) -> Bool {
  let @lib.Expr(instrs) = expr
  ls_instrs_write_ref_body_local(instrs, param_count, ref_body_locals)
}

///|
fn ls_ref_with_nullable(rt : @lib.RefType, nullable : Bool) -> @lib.RefType {
  @lib.RefType::new(
    nullable || rt.is_nullable(),
    rt.get_heap_type(),
    exact=rt.is_exact(),
  )
}

///|
fn ls_ref_abs_lub_candidate(
  module_ctx : @ir.HotModuleContext,
  left : @lib.RefType,
  right : @lib.RefType,
  nullable : Bool,
  abs : @lib.AbsHeapType,
) -> @lib.RefType? {
  let candidate = @lib.RefType::new(
    nullable,
    @lib.HeapType::abs(abs),
    exact=false,
  )
  if ls_ref_is_subtype(module_ctx, left, candidate) &&
    ls_ref_is_subtype(module_ctx, right, candidate) {
    Some(candidate)
  } else {
    None
  }
}

///|
fn ls_ref_pair_lub(
  module_ctx : @ir.HotModuleContext,
  left : @lib.RefType,
  right : @lib.RefType,
) -> @lib.RefType? {
  let nullable = left.is_nullable() || right.is_nullable()
  if ls_ref_is_subtype(module_ctx, left, right) {
    return Some(ls_ref_with_nullable(right, nullable))
  }
  if ls_ref_is_subtype(module_ctx, right, left) {
    return Some(ls_ref_with_nullable(left, nullable))
  }
  match
    ls_ref_abs_lub_candidate(
      module_ctx,
      left,
      right,
      nullable,
      @lib.AbsHeapType::func(),
    ) {
    Some(candidate) => return Some(candidate)
    None => ()
  }
  match
    ls_ref_abs_lub_candidate(
      module_ctx,
      left,
      right,
      nullable,
      @lib.AbsHeapType::extern_(),
    ) {
    Some(candidate) => return Some(candidate)
    None => ()
  }
  match
    ls_ref_abs_lub_candidate(
      module_ctx,
      left,
      right,
      nullable,
      @lib.AbsHeapType::eq(),
    ) {
    Some(candidate) => return Some(candidate)
    None => ()
  }
  ls_ref_abs_lub_candidate(
    module_ctx,
    left,
    right,
    nullable,
    @lib.AbsHeapType::any(),
  )
}

///|
fn ls_candidate_select_type(
  declared : @lib.ValType?,
  left : @lib.ValType,
  right : @lib.ValType,
  module_ctx : @ir.HotModuleContext,
) -> @lib.ValType? {
  let left_ref = match ls_as_ref(left) {
    Some(ref_type) => ref_type
    None => return None
  }
  let right_ref = match ls_as_ref(right) {
    Some(ref_type) => ref_type
    None => return None
  }
  let candidate = match ls_ref_pair_lub(module_ctx, left_ref, right_ref) {
    Some(ref_type) => @lib.ValType::ref_type(ref_type)
    None => return None
  }
  match declared {
    Some(declared_type) => {
      if candidate == declared_type {
        return None
      }
      let candidate_ref = match ls_as_ref(candidate) {
        Some(ref_type) => ref_type
        None => return None
      }
      let declared_ref = match ls_as_ref(declared_type) {
        Some(ref_type) => ref_type
        None => return None
      }
      if ls_ref_is_subtype(module_ctx, candidate_ref, declared_ref) {
        Some(candidate)
      } else {
        None
      }
    }
    None => Some(candidate)
  }
}

///|
fn ls_candidate_local_type(
  declared : @lib.ValType,
  assigned : Array[@lib.ValType],
  module_ctx : @ir.HotModuleContext,
  allow_non_null : Bool,
) -> @lib.ValType? {
  let declared_ref = match ls_as_ref(declared) {
    Some(ref_type) => ref_type
    None => return None
  }
  if assigned.is_empty() {
    return None
  }
  let ref_candidates : Array[@lib.RefType] = []
  for vt in assigned {
    match ls_as_ref(vt) {
      Some(ref_type) => ref_candidates.push(ref_type)
      None => return None
    }
  }
  let mut best : @lib.RefType? = None
  for candidate in ref_candidates {
    let candidate_nullable = if allow_non_null {
      candidate.is_nullable()
    } else {
      declared_ref.is_nullable() || candidate.is_nullable()
    }
    let local_candidate = @lib.RefType::new(
      candidate_nullable,
      candidate.get_heap_type(),
      exact=candidate.is_exact(),
    )
    if !ls_ref_is_subtype(module_ctx, local_candidate, declared_ref) {
      continue
    }
    let mut accepts_all = true
    for assigned_ref in ref_candidates {
      if !ls_ref_is_subtype(module_ctx, assigned_ref, local_candidate) {
        accepts_all = false
        break
      }
    }
    if !accepts_all {
      continue
    }
    match best {
      None => best = Some(local_candidate)
      Some(best_ref) =>
        if ls_ref_is_subtype(module_ctx, local_candidate, best_ref) {
          best = Some(local_candidate)
        }
    }
  }
  match best {
    Some(best_ref) => {
      let vt = @lib.ValType::ref_type(best_ref)
      if vt == declared {
        None
      } else {
        Some(vt)
      }
    }
    None => None
  }
}

///|
fn ls_body_local_idx(
  idx : @lib.LocalIdx,
  param_count : Int,
  body_local_count : Int,
) -> Int? {
  let raw = ls_local_idx_raw(idx)
  let body_idx = raw - param_count
  if body_idx >= 0 && body_idx < body_local_count {
    Some(body_idx)
  } else {
    None
  }
}

///|
fn ls_local_declared_type(
  idx : @lib.LocalIdx,
  param_types : Array[@lib.ValType],
  body_locals : @lib.Locals,
) -> @lib.ValType? {
  let raw = ls_local_idx_raw(idx)
  if raw < 0 {
    return None
  }
  if raw < param_types.length() {
    return Some(param_types[raw])
  }
  let body_idx = raw - param_types.length()
  if body_idx >= 0 && body_idx < body_locals.length() {
    Some(body_locals[body_idx])
  } else {
    None
  }
}

///|
fn ls_select_declared_type(types : Array[@lib.ValType]?) -> @lib.ValType? {
  match types {
    Some([single]) => Some(single)
    _ => None
  }
}

///|
priv struct LsFuncShape {
  params : Array[@lib.ValType]
  results : Array[@lib.ValType]
}

///|
fn LsFuncShape::new(
  params : Array[@lib.ValType],
  results : Array[@lib.ValType],
) -> LsFuncShape {
  { params, results }
}

///|
fn ls_resolve_func_type_idx(
  module_ctx : @ir.HotModuleContext,
  type_idx : @lib.TypeIdx,
) -> LsFuncShape? {
  match @ir.hot_module_resolve_subtype(module_ctx, type_idx) {
    Some(subtype) =>
      match subtype.get_comptype() {
        @lib.FuncCompType(params, results) =>
          Some(LsFuncShape::new(params, results))
        _ => None
      }
    None => None
  }
}

///|
fn ls_val_is_subtype(
  module_ctx : @ir.HotModuleContext,
  source : @lib.ValType,
  target : @lib.ValType,
) -> Bool {
  if source == target {
    return true
  }
  match (ls_as_ref(source), ls_as_ref(target)) {
    (Some(source_ref), Some(target_ref)) =>
      ls_ref_is_subtype(module_ctx, source_ref, target_ref)
    _ => false
  }
}

///|
fn ls_results_are_subtypes(
  module_ctx : @ir.HotModuleContext,
  source : Array[@lib.ValType],
  target : Array[@lib.ValType],
) -> Bool {
  if source.length() != target.length() {
    return false
  }
  for idx = 0; idx < source.length(); idx = idx + 1 {
    if !ls_val_is_subtype(module_ctx, source[idx], target[idx]) {
      return false
    }
  }
  true
}

///|
fn ls_candidate_call_ref_type(
  current_type_idx : @lib.TypeIdx,
  target_type : @lib.ValType,
  module_ctx : @ir.HotModuleContext,
) -> @lib.TypeIdx? {
  let target_ref = match ls_as_ref(target_type) {
    Some(ref_type) => ref_type
    None => return None
  }
  let target_type_idx = match target_ref.get_heap_type() {
    @lib.HeapType(type_idx) => type_idx
    _ => return None
  }
  if target_type_idx == current_type_idx {
    return None
  }
  let current_shape = match
    ls_resolve_func_type_idx(module_ctx, current_type_idx) {
    Some(func_type) => func_type
    None => return None
  }
  let target_shape = match
    ls_resolve_func_type_idx(module_ctx, target_type_idx) {
    Some(func_type) => func_type
    None => return None
  }
  if target_shape.params != current_shape.params {
    return None
  }
  if !ls_results_are_subtypes(
      module_ctx,
      target_shape.results,
      current_shape.results,
    ) {
    return None
  }
  if !ls_heap_is_subtype(
      module_ctx,
      target_ref.get_heap_type(),
      @lib.HeapType::new(current_type_idx),
      512,
    ) {
    return None
  }
  Some(target_type_idx)
}

///|
fn ls_call_ref_has_no_params(
  module_ctx : @ir.HotModuleContext,
  type_idx : @lib.TypeIdx,
) -> Bool {
  match ls_resolve_func_type_idx(module_ctx, type_idx) {
    Some(shape) => shape.params.is_empty()
    None => false
  }
}

///|
fn ls_is_nullable_nofunc_ref(val_type : @lib.ValType) -> Bool {
  match ls_as_ref(val_type) {
    Some(ref_type) =>
      ref_type.is_nullable() &&
      ref_type.get_heap_type() ==
      @lib.HeapType::abs(@lib.AbsHeapType::no_func())
    None => false
  }
}

///|
fn ls_refine_selects_instrs(
  instrs : Array[@lib.Instruction],
  param_types : Array[@lib.ValType],
  body_locals : @lib.Locals,
  module_ctx : @ir.HotModuleContext,
) -> (Array[@lib.Instruction], Bool) {
  let rewritten : Array[@lib.Instruction] = Array::new(capacity=instrs.length())
  let mut changed = false
  for instr in instrs {
    let next_instr = match instr {
      @lib.Block(block_type, body) => {
        let (next_body, body_changed) = ls_refine_selects_expr(
          body, param_types, body_locals, module_ctx,
        )
        if body_changed {
          changed = true
          @lib.Instruction::block(block_type, next_body)
        } else {
          instr
        }
      }
      @lib.Loop(block_type, body) => {
        let (next_body, body_changed) = ls_refine_selects_expr(
          body, param_types, body_locals, module_ctx,
        )
        if body_changed {
          changed = true
          @lib.Instruction::loop_(block_type, next_body)
        } else {
          instr
        }
      }
      @lib.TryTable(block_type, catches, body) => {
        let (next_body, body_changed) = ls_refine_selects_expr(
          body, param_types, body_locals, module_ctx,
        )
        if body_changed {
          changed = true
          @lib.Instruction::try_table(block_type, catches, next_body)
        } else {
          instr
        }
      }
      @lib.If(block_type, then_body, else_body) => {
        let (next_then, then_changed) = ls_refine_selects_instrs(
          then_body, param_types, body_locals, module_ctx,
        )
        let (next_else, else_changed) = match else_body {
          Some(body) => {
            let (next, changed) = ls_refine_selects_instrs(
              body, param_types, body_locals, module_ctx,
            )
            (Some(next), changed)
          }
          None => (None, false)
        }
        if then_changed || else_changed {
          changed = true
          @lib.Instruction::if_(block_type, next_then, next_else)
        } else {
          instr
        }
      }
      _ => instr
    }
    match next_instr {
      @lib.Select(types) => {
        let len = rewritten.length()
        let candidate = if len >= 3 {
          match (rewritten[len - 3], rewritten[len - 2]) {
            (@lib.LocalGet(left_idx), @lib.LocalGet(right_idx)) => {
              let left_type = match
                ls_local_declared_type(left_idx, param_types, body_locals) {
                Some(val_type) => val_type
                None => {
                  rewritten.push(next_instr)
                  continue
                }
              }
              let right_type = match
                ls_local_declared_type(right_idx, param_types, body_locals) {
                Some(val_type) => val_type
                None => {
                  rewritten.push(next_instr)
                  continue
                }
              }
              ls_candidate_select_type(
                ls_select_declared_type(types),
                left_type,
                right_type,
                module_ctx,
              )
            }
            _ => None
          }
        } else {
          None
        }
        match candidate {
          Some(val_type) => {
            rewritten.push(@lib.Instruction::select(types=Some([val_type])))
            changed = true
          }
          None => rewritten.push(next_instr)
        }
      }
      @lib.CallRef(type_idx) => {
        let len = rewritten.length()
        let target_type = if len >= 1 {
          match rewritten[len - 1] {
            @lib.LocalGet(target_idx) =>
              ls_local_declared_type(target_idx, param_types, body_locals)
            _ => None
          }
        } else {
          None
        }
        match target_type {
          Some(val_type) =>
            match ls_candidate_call_ref_type(type_idx, val_type, module_ctx) {
              Some(next_type_idx) => {
                rewritten.push(@lib.Instruction::call_ref(next_type_idx))
                changed = true
              }
              None =>
                if ls_is_nullable_nofunc_ref(val_type) &&
                  ls_call_ref_has_no_params(module_ctx, type_idx) {
                  match rewritten[len - 1] {
                    @lib.LocalGet(target_idx) => {
                      let bottom_ref = @lib.ValType::ref_type(
                        @lib.RefType::new(
                          false,
                          @lib.HeapType::abs(@lib.AbsHeapType::none()),
                        ),
                      )
                      ignore(
                        rewritten.set(
                          len - 1,
                          @lib.Instruction::block(
                            @lib.BlockType::val_type(bottom_ref),
                            @lib.Expr::new([
                              @lib.Instruction::local_get(target_idx),
                              @lib.Instruction::drop(),
                              @lib.Instruction::unreachable_(),
                            ]),
                          ),
                        ),
                      )
                      changed = true
                    }
                    _ => rewritten.push(next_instr)
                  }
                } else {
                  rewritten.push(next_instr)
                }
            }
          None => rewritten.push(next_instr)
        }
      }
      _ => rewritten.push(next_instr)
    }
  }
  (rewritten, changed)
}

///|
fn ls_refine_selects_expr(
  expr : @lib.Expr,
  param_types : Array[@lib.ValType],
  body_locals : @lib.Locals,
  module_ctx : @ir.HotModuleContext,
) -> (@lib.Expr, Bool) {
  let @lib.Expr(instrs) = expr
  let (next_instrs, changed) = ls_refine_selects_instrs(
    instrs, param_types, body_locals, module_ctx,
  )
  if changed {
    (@lib.Expr::new(next_instrs), true)
  } else {
    (expr, false)
  }
}

///|
priv struct LsDominanceScanResult {
  valid : Bool
  propagates : Bool
}

///|
fn LsDominanceScanResult::new(
  valid : Bool,
  propagates : Bool,
) -> LsDominanceScanResult {
  { valid, propagates }
}

///|
fn ls_copy_bool_state(dst : Array[Bool], src : Array[Bool]) -> Unit {
  let limit = if dst.length() < src.length() {
    dst.length()
  } else {
    src.length()
  }
  for idx = 0; idx < limit; idx = idx + 1 {
    ignore(dst.set(idx, src[idx]))
  }
}

///|
fn ls_scan_branch_free_dominance_instrs(
  instrs : Array[@lib.Instruction],
  param_count : Int,
  ref_body_locals : Array[Bool],
  initialized : Array[Bool],
  safe : Array[Bool],
  allow_return_skip? : Bool = false,
  allow_throw_skip? : Bool = false,
  allow_terminal_return? : Bool = false,
  allow_terminal_throw? : Bool = false,
  allow_non_final_return_tail? : Bool = false,
  allow_non_final_throw_tail? : Bool = false,
) -> LsDominanceScanResult {
  let body_local_count = ref_body_locals.length()
  let mut allow_later_write_init = true
  let mut propagates = true
  for instr_idx = 0; instr_idx < instrs.length(); instr_idx = instr_idx + 1 {
    let instr = instrs[instr_idx]
    match instr {
      @lib.LocalGet(idx) =>
        match ls_body_local_idx(idx, param_count, body_local_count) {
          Some(body_idx) =>
            if ref_body_locals[body_idx] && !initialized[body_idx] {
              ignore(safe.set(body_idx, false))
            }
          None => ()
        }
      @lib.LocalSet(idx) | @lib.LocalTee(idx) =>
        match ls_body_local_idx(idx, param_count, body_local_count) {
          Some(body_idx) =>
            if allow_later_write_init && ref_body_locals[body_idx] {
              ignore(initialized.set(body_idx, true))
            }
          None => ()
        }
      @lib.Block(_, @lib.Expr(body)) => {
        let block_initialized = initialized.copy()
        let block_result = ls_scan_branch_free_dominance_instrs(
          body,
          param_count,
          ref_body_locals,
          block_initialized,
          safe,
          allow_return_skip~,
          allow_throw_skip~,
          allow_terminal_return=allow_terminal_return || allow_return_skip,
          allow_terminal_throw=allow_terminal_throw || allow_throw_skip,
          allow_non_final_return_tail~,
          allow_non_final_throw_tail~,
        )
        if !block_result.valid {
          return LsDominanceScanResult::new(false, false)
        }
        if allow_later_write_init && block_result.propagates {
          ls_copy_bool_state(initialized, block_initialized)
        }
      }
      @lib.Loop(_, @lib.Expr(body)) => {
        let loop_initialized = initialized.copy()
        let loop_result = ls_scan_branch_free_dominance_instrs(
          body, param_count, ref_body_locals, loop_initialized, safe,
        )
        if !loop_result.valid {
          return LsDominanceScanResult::new(false, false)
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) => {
        let try_initialized = initialized.copy()
        let try_result = ls_scan_branch_free_dominance_instrs(
          body,
          param_count,
          ref_body_locals,
          try_initialized,
          safe,
          allow_terminal_return=true,
          allow_terminal_throw=true,
          allow_non_final_return_tail=true,
          allow_non_final_throw_tail=true,
        )
        if !try_result.valid {
          return LsDominanceScanResult::new(false, false)
        }
      }
      @lib.If(_, then_body, else_body) => {
        let then_initialized = initialized.copy()
        let then_result = ls_scan_branch_free_dominance_instrs(
          then_body,
          param_count,
          ref_body_locals,
          then_initialized,
          safe,
          allow_return_skip=true,
          allow_throw_skip=true,
        )
        if !then_result.valid {
          return LsDominanceScanResult::new(false, false)
        }
        match else_body {
          Some(body) => {
            let else_initialized = initialized.copy()
            let else_result = ls_scan_branch_free_dominance_instrs(
              body,
              param_count,
              ref_body_locals,
              else_initialized,
              safe,
              allow_return_skip=true,
              allow_throw_skip=true,
            )
            if !else_result.valid {
              return LsDominanceScanResult::new(false, false)
            }
          }
          None => ()
        }
      }
      @lib.Unreachable => allow_later_write_init = false
      @lib.BrIf(_) => allow_later_write_init = false
      @lib.Br(_) | @lib.BrTable(_, _) => {
        allow_later_write_init = false
        propagates = false
      }
      @lib.Return
      | @lib.ReturnCall(_)
      | @lib.ReturnCallIndirect(_, _)
      | @lib.ReturnCallRef(_) =>
        if allow_return_skip {
          ()
        } else if allow_terminal_return &&
          (allow_non_final_return_tail || instr_idx + 1 == instrs.length()) {
          allow_later_write_init = false
          propagates = false
        } else {
          return LsDominanceScanResult::new(false, false)
        }
      @lib.Throw(_) | @lib.ThrowRef =>
        if allow_throw_skip {
          ()
        } else if allow_terminal_throw &&
          (allow_non_final_throw_tail || instr_idx + 1 == instrs.length()) {
          allow_later_write_init = false
          propagates = false
        } else {
          return LsDominanceScanResult::new(false, false)
        }
      _ => ()
    }
  }
  LsDominanceScanResult::new(true, propagates)
}

///|
fn ls_non_null_dominated_linear_locals(
  expr : @lib.Expr,
  param_count : Int,
  ref_body_locals : Array[Bool],
) -> Array[Bool] {
  let body_local_count = ref_body_locals.length()
  let initialized : Array[Bool] = []
  let safe : Array[Bool] = []
  for body_idx = 0; body_idx < body_local_count; body_idx = body_idx + 1 {
    initialized.push(false)
    safe.push(ref_body_locals[body_idx])
  }
  let @lib.Expr(instrs) = expr
  let scan_result = ls_scan_branch_free_dominance_instrs(
    instrs,
    param_count,
    ref_body_locals,
    initialized,
    safe,
    allow_terminal_return=true,
    allow_terminal_throw=true,
    allow_non_final_return_tail=true,
  )
  if !scan_result.valid {
    for body_idx = 0; body_idx < body_local_count; body_idx = body_idx + 1 {
      if ref_body_locals[body_idx] {
        ignore(safe.set(body_idx, false))
      }
    }
  }
  safe
}

///|
fn ls_collect_assignments(func : @ir.HotFunc) -> Array[Array[@lib.ValType]] {
  let locals : Array[Array[@lib.ValType]] = []
  for i = 0; i < @ir.hot_local_count(func); i = i + 1 {
    ignore(i)
    locals.push([])
  }
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => {
        if node.imm0 < 0 || node.imm0 >= locals.length() {
          continue
        }
        if @ir.hot_child_count(func, node_id) != 1 {
          continue
        }
        let child = @ir.hot_child_get(func, node_id, 0)
        let results = @ir.hot_type_results(func, @ir.hot_node_type(func, child))
        if results.length() == 1 {
          locals[node.imm0].push(results[0])
        }
      }
      _ => ()
    }
  }
  locals
}

///|
fn ls_rewrite_func(
  func : @lib.Func,
  func_idx : @lib.FuncIdx,
  mod_ : @lib.Module,
  module_ctx : @ir.HotModuleContext,
) -> (@lib.Func, Bool) {
  let @lib.Func(body_locals, body) = func
  let ref_body_locals = match ls_ref_body_local_mask(body_locals) {
    Some(mask) => mask
    None => return (func, false)
  }
  let (raw_param_count, param_types) = match
    @ir.hot_module_resolve_func_type(module_ctx, func_idx) {
    Some(@lib.FuncType(params, _)) => (params.length(), params)
    None => (-1, [])
  }
  if raw_param_count >= 0 &&
    !ls_expr_writes_ref_body_local(body, raw_param_count, ref_body_locals) {
    return (func, false)
  }
  let (refined_body, body_changed) = if raw_param_count >= 0 {
    ls_refine_selects_expr(body, param_types, body_locals, module_ctx)
  } else {
    (body, false)
  }
  let hot_func = @ir.hot_lift_func_with_context(mod_, func_idx, module_ctx)
  let assignments = ls_collect_assignments(hot_func)
  let param_count = if raw_param_count >= 0 {
    raw_param_count
  } else {
    @ir.hot_local_param_count(hot_func)
  }
  let non_null_safe = if raw_param_count >= 0 {
    ls_non_null_dominated_linear_locals(body, raw_param_count, ref_body_locals)
  } else {
    let fallback : Array[Bool] = []
    for body_idx = 0; body_idx < body_locals.length(); body_idx = body_idx + 1 {
      ignore(body_idx)
      fallback.push(false)
    }
    fallback
  }
  let rewritten_locals = body_locals.copy()
  let mut changed = false
  for body_idx = 0; body_idx < body_locals.length(); body_idx = body_idx + 1 {
    let local_idx = param_count + body_idx
    let declared = match body_locals.at(body_idx) {
      Some(vt) => vt
      None => continue
    }
    let assigned = match assignments.get(local_idx) {
      Some(types) => types
      None => continue
    }
    let allow_non_null = match non_null_safe.get(body_idx) {
      Some(value) => value
      None => false
    }
    match
      ls_candidate_local_type(declared, assigned, module_ctx, allow_non_null) {
      Some(next) => if rewritten_locals.set(body_idx, next) { changed = true }
      None => ()
    }
  }
  if changed || body_changed {
    (@lib.Func::new(rewritten_locals, refined_body), true)
  } else {
    (func, false)
  }
}

///|
fn ls_rebuild_module(
  mod_ : @lib.Module,
  next_code_sec : @lib.CodeSec?,
) -> @lib.Module {
  @lib.Module::new(
    custom_secs=mod_.custom_secs,
    type_sec=mod_.type_sec,
    import_sec=mod_.import_sec,
    func_annotation_sec=mod_.func_annotation_sec,
    func_sec=mod_.func_sec,
    table_sec=mod_.table_sec,
    mem_sec=mod_.mem_sec,
    tag_sec=mod_.tag_sec,
    stringrefs_sec=mod_.stringrefs_sec,
    global_sec=mod_.global_sec,
    export_sec=mod_.export_sec,
    start_sec=mod_.start_sec,
    elem_sec=mod_.elem_sec,
    data_cnt_sec=mod_.data_cnt_sec,
    code_sec=next_code_sec,
    data_sec=mod_.data_sec,
    name_sec=mod_.name_sec,
  )
}

///|
fn ls_ref_body_local_iteration_limit(funcs : Array[@lib.Func]) -> Int {
  let mut limit = 1
  for func in funcs {
    let @lib.Func(body_locals, _) = func
    for idx = 0; idx < body_locals.length(); idx = idx + 1 {
      match ls_as_ref(body_locals[idx]) {
        Some(_) => limit += 1
        None => ()
      }
    }
  }
  limit
}

///|
pub fn local_subtyping_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  let mut current_mod = mod_
  let mut did_change = false
  let mut iteration = 0
  let iteration_limit = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => ls_ref_body_local_iteration_limit(funcs)
    None => return mod_
  }
  while iteration < iteration_limit {
    let funcs = match current_mod.code_sec {
      Some(@lib.CodeSec(funcs)) => funcs
      None => return current_mod
    }
    let module_ctx = @ir.hot_module_context_from_module(current_mod)
    let imported_func_count = ls_imported_func_count(current_mod)
    let rewritten_funcs : Array[@lib.Func] = Array::new(capacity=funcs.length())
    let mut changed = false
    for code_idx = 0; code_idx < funcs.length(); code_idx = code_idx + 1 {
      let func_idx = @lib.FuncIdx::new(
        (imported_func_count + code_idx).reinterpret_as_uint(),
      )
      let (next_func, next_changed) = ls_rewrite_func(
        funcs[code_idx],
        func_idx,
        current_mod,
        module_ctx,
      )
      rewritten_funcs.push(next_func)
      if next_changed {
        changed = true
      }
    }
    if !changed {
      return if did_change { current_mod } else { mod_ }
    }
    current_mod = ls_rebuild_module(
      current_mod,
      Some(@lib.CodeSec::new(rewritten_funcs)),
    )
    did_change = true
    iteration += 1
  }
  current_mod
}
