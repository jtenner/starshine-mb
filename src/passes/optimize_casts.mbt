///|
priv struct OCCastEffects {
  locals_read : Set[LocalIdx]
  locals_written : Set[LocalIdx]
  mut reads_memory : Bool
  mut writes_memory : Bool
  mut reads_globals : Bool
  mut writes_globals : Bool
  mut calls : Bool
  mut branches : Bool
  mut traps : Bool
  mut throws : Bool
}

///|
fn OCCastEffects::new() -> OCCastEffects {
  {
    locals_read: Set::new(),
    locals_written: Set::new(),
    reads_memory: false,
    writes_memory: false,
    reads_globals: false,
    writes_globals: false,
    calls: false,
    branches: false,
    traps: false,
    throws: false,
  }
}

///|
fn OCCastEffects::transfers_control_flow(self : OCCastEffects) -> Bool {
  self.branches || self.throws
}

///|
fn OCCastEffects::has_unremovable_side_effects(self : OCCastEffects) -> Bool {
  self.writes_memory ||
  self.writes_globals ||
  self.calls ||
  self.branches ||
  self.throws ||
  self.traps ||
  self.locals_written.length() > 0
}

///|
fn OCCastEffects::invalidates(
  self : OCCastEffects,
  other : OCCastEffects,
) -> Bool {
  for local_idx in self.locals_written {
    if other.locals_read.contains(local_idx) ||
      other.locals_written.contains(local_idx) {
      return true
    }
  }
  for local_idx in self.locals_read {
    if other.locals_written.contains(local_idx) {
      return true
    }
  }
  if (self.reads_memory && other.writes_memory) ||
    (self.writes_memory && other.reads_memory) ||
    (self.writes_memory && other.writes_memory) {
    return true
  }
  if (self.reads_globals && other.writes_globals) ||
    (self.writes_globals && other.reads_globals) ||
    (self.writes_globals && other.writes_globals) {
    return true
  }
  if self.calls || other.calls {
    if self.reads_memory ||
      self.writes_memory ||
      other.reads_memory ||
      other.writes_memory ||
      self.reads_globals ||
      self.writes_globals ||
      other.reads_globals ||
      other.writes_globals {
      return true
    }
  }
  if self.transfers_control_flow() || other.transfers_control_flow() {
    return true
  }
  if (self.traps && other.has_unremovable_side_effects()) ||
    (other.traps && self.has_unremovable_side_effects()) {
    return true
  }
  false
}

///|
fn oc_collect_shallow_effects_into(
  instr : TInstr,
  effects : OCCastEffects,
) -> Unit {
  match instr {
    TLocalGet(idx) => effects.locals_read.add(idx)
    TLocalSet(idx, _) => effects.locals_written.add(idx)
    TLocalTee(idx, _) => {
      effects.locals_read.add(idx)
      effects.locals_written.add(idx)
    }
    TGlobalGet(_) => effects.reads_globals = true
    TGlobalSet(_, _) => effects.writes_globals = true
    TLoad(_, _, _) => {
      effects.reads_memory = true
      effects.traps = true
    }
    TStore(_, _, _, _) => {
      effects.writes_memory = true
      effects.traps = true
    }
    TMemoryGrow(_, _) => effects.writes_memory = true
    TMemorySize(_) => effects.reads_memory = true
    TMemoryCopy(_, _, _, _, _) => {
      effects.reads_memory = true
      effects.writes_memory = true
    }
    TMemoryFill(_, _, _, _) => effects.writes_memory = true
    TMemoryInit(_, _, _, _, _) => {
      effects.reads_memory = true
      effects.writes_memory = true
    }
    TDataDrop(_) => effects.writes_memory = true
    TTableSet(_, _, _) | TTableGrow(_, _, _) | TTableFill(_, _, _, _) =>
      effects.writes_memory = true
    TTableGet(_, _) | TTableSize(_) => effects.reads_memory = true
    TTableCopy(_, _, _, _, _) | TTableInit(_, _, _, _, _) | TElemDrop(_) => {
      effects.reads_memory = true
      effects.writes_memory = true
    }
    TCall(_, _) | TCallIndirect(_, _, _, _) | TCallRef(_, _, _) =>
      effects.calls = true
    TReturnCall(_, _)
    | TReturnCallIndirect(_, _, _, _)
    | TReturnCallRef(_, _, _) => {
      effects.calls = true
      effects.branches = true
    }
    TBr(_, _)
    | TBrIf(_, _, _)
    | TBrTable(_, _, _, _)
    | TBrOnNull(_, _, _)
    | TBrOnNonNull(_, _, _)
    | TBrOnCast(_, _, _, _, _, _)
    | TBrOnCastFail(_, _, _, _, _, _)
    | TReturn(_) => effects.branches = true
    TThrow(_, _) | TThrowRef(_) => {
      effects.throws = true
      effects.branches = true
    }
    TUnreachable => effects.traps = true
    TRefAsNonNull(_) | TRefCast(_, _, _) => effects.traps = true
    _ => ()
  }
}

///|
fn oc_collect_shallow_effects(instr : TInstr) -> OCCastEffects {
  let effects = OCCastEffects::new()
  oc_collect_shallow_effects_into(instr, effects)
  effects
}

///|
fn oc_is_non_linear_boundary(instr : TInstr) -> Bool {
  match instr {
    TBlock(_, _)
    | TLoop(_, _)
    | TIf(_, _, _, _)
    | TTryTable(_, _, _)
    | TBr(_, _)
    | TBrIf(_, _, _)
    | TBrTable(_, _, _, _)
    | TBrOnNull(_, _, _)
    | TBrOnNonNull(_, _, _)
    | TBrOnCast(_, _, _, _, _, _)
    | TBrOnCastFail(_, _, _, _, _, _)
    | TReturn(_)
    | TThrow(_, _)
    | TThrowRef(_)
    | TReturnCall(_, _)
    | TReturnCallIndirect(_, _, _, _)
    | TReturnCallRef(_, _, _) => true
    _ => false
  }
}

///|
fn oc_is_subtype(sub : RefType, sup : RefType, env : Env) -> Bool {
  Match::matches(sub, sup, env)
}

///|
priv struct RefCastInfo {
  mut target_get_id : Int?
  mut target_type : RefType?
  mut best_cast : RefType?
  mut best_fallthrough : Int?
}

///|
priv struct RefAsInfo {
  mut target_get_id : Int?
  mut has_best_cast : Bool
  mut best_fallthrough : Int?
}

///|
priv struct EarlyCastFinder {
  env : Env
  num_locals : Int
  mut next_get_id : Int
  curr_ref_cast_move : Array[RefCastInfo]
  curr_ref_as_move : Array[RefAsInfo]
  test_ref_cast : OCCastEffects
  test_ref_as : OCCastEffects
  ref_cast_to_apply : Map[Int, RefType]
  ref_as_to_apply : Set[Int]
}

///|
fn EarlyCastFinder::new(env : Env, num_locals : Int) -> EarlyCastFinder {
  let ref_move : Array[RefCastInfo] = []
  let as_move : Array[RefAsInfo] = []
  for i in 0..<num_locals {
    ignore(i)
    ref_move.push({
      target_get_id: None,
      target_type: None,
      best_cast: None,
      best_fallthrough: None,
    })
    as_move.push({
      target_get_id: None,
      has_best_cast: false,
      best_fallthrough: None,
    })
  }
  let test_ref_cast = OCCastEffects::new()
  test_ref_cast.traps = true
  let test_ref_as = OCCastEffects::new()
  test_ref_as.traps = true
  {
    env,
    num_locals,
    next_get_id: 0,
    curr_ref_cast_move: ref_move,
    curr_ref_as_move: as_move,
    test_ref_cast,
    test_ref_as,
    ref_cast_to_apply: Map::new(),
    ref_as_to_apply: Set::new(),
  }
}

///|
fn EarlyCastFinder::flush_ref_cast_result(
  self : EarlyCastFinder,
  index : Int,
) -> Unit {
  let info = self.curr_ref_cast_move[index]
  match (info.target_get_id, info.best_cast) {
    (Some(target), Some(best)) => {
      let can_apply = match info.best_fallthrough {
        Some(fallthrough) => fallthrough != target
        None => true
      }
      if can_apply {
        self.ref_cast_to_apply[target] = best
      }
    }
    _ => ()
  }
  self.curr_ref_cast_move[index].target_get_id = None
  self.curr_ref_cast_move[index].best_cast = None
  self.curr_ref_cast_move[index].best_fallthrough = None
}

///|
fn EarlyCastFinder::flush_ref_as_result(
  self : EarlyCastFinder,
  index : Int,
) -> Unit {
  let info = self.curr_ref_as_move[index]
  match info.target_get_id {
    Some(target) if info.has_best_cast => {
      let can_apply = match info.best_fallthrough {
        Some(fallthrough) => fallthrough != target
        None => true
      }
      if can_apply {
        self.ref_as_to_apply.add(target)
      }
    }
    _ => ()
  }
  self.curr_ref_as_move[index].target_get_id = None
  self.curr_ref_as_move[index].has_best_cast = false
  self.curr_ref_as_move[index].best_fallthrough = None
}

///|
fn EarlyCastFinder::flush_all(self : EarlyCastFinder) -> Unit {
  for i in 0..<self.num_locals {
    self.flush_ref_cast_result(i)
    self.flush_ref_as_result(i)
  }
}

///|
fn EarlyCastFinder::visit_expression(
  self : EarlyCastFinder,
  curr : TInstr,
) -> Unit {
  let curr_analyzer = oc_collect_shallow_effects(curr)
  if self.test_ref_cast.invalidates(curr_analyzer) {
    for i in 0..<self.num_locals {
      self.flush_ref_cast_result(i)
    }
  }
  if self.test_ref_as.invalidates(curr_analyzer) {
    for i in 0..<self.num_locals {
      self.flush_ref_as_result(i)
    }
  }
}

///|
fn EarlyCastFinder::note_non_linear(
  self : EarlyCastFinder,
  curr : TInstr,
) -> Unit {
  if oc_is_non_linear_boundary(curr) {
    self.flush_all()
  }
}

///|
fn oc_local_index_int(idx : LocalIdx) -> Int {
  idx.0.reinterpret_as_int()
}

///|
fn EarlyCastFinder::visit_local_get(
  self : EarlyCastFinder,
  curr : LocalIdx,
) -> Int {
  let get_id = self.next_get_id
  self.next_get_id = self.next_get_id + 1
  let index = oc_local_index_int(curr)
  if self.curr_ref_cast_move[index].target_get_id is None {
    self.curr_ref_cast_move[index].target_get_id = Some(get_id)
    self.curr_ref_cast_move[index].target_type = match
      self.env.get_local_type(curr) {
      Some(RefTypeValType(rt)) => Some(rt)
      _ => None
    }
  }
  if self.curr_ref_as_move[index].target_get_id is None {
    let can_target = match self.env.get_local_type(curr) {
      Some(RefTypeValType(rt)) => rt.is_nullable()
      _ => false
    }
    if can_target {
      self.curr_ref_as_move[index].target_get_id = Some(get_id)
    }
  }
  get_id
}

///|
fn EarlyCastFinder::visit_ref_as(
  self : EarlyCastFinder,
  op : Bool,
  fallthrough : (LocalIdx, Int)?,
) -> Unit {
  if !op {
    return
  }
  match fallthrough {
    Some((idx, fallthrough_get_id)) => {
      let i = oc_local_index_int(idx)
      if self.curr_ref_as_move[i].target_get_id is Some(_) &&
        !self.curr_ref_as_move[i].has_best_cast {
        self.curr_ref_as_move[i].has_best_cast = true
        self.curr_ref_as_move[i].best_fallthrough = Some(fallthrough_get_id)
      }
    }
    None => ()
  }
}

///|
fn EarlyCastFinder::visit_ref_cast(
  self : EarlyCastFinder,
  nullable : Bool,
  ht : HeapType,
  fallthrough : (LocalIdx, Int)?,
) -> Unit {
  match fallthrough {
    Some((idx, fallthrough_get_id)) => {
      let i = oc_local_index_int(idx)
      let target = self.curr_ref_cast_move[i]
      let cast_type = RefType::new(nullable, ht)
      match (target.target_get_id, target.target_type) {
        (Some(_), Some(target_ty)) =>
          if target_ty != cast_type &&
            oc_is_subtype(cast_type, target_ty, self.env) {
            match target.best_cast {
              None => {
                self.curr_ref_cast_move[i].best_cast = Some(cast_type)
                self.curr_ref_cast_move[i].best_fallthrough = Some(
                  fallthrough_get_id,
                )
              }
              Some(best) =>
                if best != cast_type && oc_is_subtype(cast_type, best, self.env) {
                  self.curr_ref_cast_move[i].best_cast = Some(cast_type)
                  self.curr_ref_cast_move[i].best_fallthrough = Some(
                    fallthrough_get_id,
                  )
                }
            }
          }
        _ => ()
      }
    }
    None => ()
  }
}

///|
fn oc_walk_early_cast_finder_instr(
  finder : EarlyCastFinder,
  instr : TInstr,
) -> (LocalIdx, Int)? {
  finder.note_non_linear(instr)
  let fallthrough = match instr {
    TLocalGet(idx) => {
      finder.visit_expression(instr)
      let get_id = finder.visit_local_get(idx)
      Some((idx, get_id))
    }
    TLocalSet(idx, value) => {
      ignore(oc_walk_early_cast_finder_instr(finder, value))
      finder.visit_expression(instr)
      let i = oc_local_index_int(idx)
      finder.flush_ref_cast_result(i)
      finder.flush_ref_as_result(i)
      None
    }
    TLocalTee(idx, value) => {
      ignore(oc_walk_early_cast_finder_instr(finder, value))
      finder.visit_expression(instr)
      let i = oc_local_index_int(idx)
      finder.flush_ref_cast_result(i)
      finder.flush_ref_as_result(i)
      None
    }
    TRefAsNonNull(value) => {
      let ft = oc_walk_early_cast_finder_instr(finder, value)
      finder.visit_expression(instr)
      finder.visit_ref_as(true, ft)
      ft
    }
    TRefCast(nullable, ht, value) => {
      let ft = oc_walk_early_cast_finder_instr(finder, value)
      finder.visit_expression(instr)
      finder.visit_ref_cast(nullable, ht, ft)
      ft
    }
    TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) => {
      oc_walk_early_cast_finder_expr(finder, body)
      finder.flush_all()
      finder.visit_expression(instr)
      None
    }
    TIf(_, cond, then_, else_) => {
      ignore(oc_walk_early_cast_finder_instr(finder, cond))
      finder.flush_all()
      oc_walk_early_cast_finder_expr(finder, then_)
      finder.flush_all()
      match else_ {
        Some(other) => oc_walk_early_cast_finder_expr(finder, other)
        None => ()
      }
      finder.flush_all()
      finder.visit_expression(instr)
      None
    }
    _ => {
      for child in eval_children(instr) {
        ignore(oc_walk_early_cast_finder_instr(finder, child))
      }
      finder.visit_expression(instr)
      None
    }
  }
  fallthrough
}

///|
fn oc_walk_early_cast_finder_expr(
  finder : EarlyCastFinder,
  expr : TExpr,
) -> Unit {
  for instr in expr.0 {
    ignore(oc_walk_early_cast_finder_instr(finder, instr))
  }
}

///|
fn EarlyCastFinder::run(self : EarlyCastFinder, body : TExpr) -> Unit {
  oc_walk_early_cast_finder_expr(self, body)
  self.flush_all()
}

///|
fn EarlyCastFinder::has_casts_to_move(self : EarlyCastFinder) -> Bool {
  self.ref_cast_to_apply.length() > 0 || self.ref_as_to_apply.length() > 0
}

///|
fn oc_apply_early_casts(body : TExpr, finder : EarlyCastFinder) -> TExpr {
  let get_id = Ref::new(0)
  let pass = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    match curr {
      TLocalGet(_) => {
        let this_id = get_id.val
        get_id.update(fn(i) { i + 1 })
        let casted : TInstr = match finder.ref_cast_to_apply.get(this_id) {
          Some(rt) =>
            TInstr::ref_cast(rt.is_nullable(), rt.get_heap_type(), curr)
          None => curr
        }
        if finder.ref_as_to_apply.contains(this_id) {
          change((), TInstr::ref_as_non_null(casted))
        } else if casted == curr {
          unchanged()
        } else {
          change((), casted)
        }
      }
      _ => self.walk_tinstruction_default((), curr)
    }
  })
  match pass.walk_texpr((), body) {
    Ok(Some((_, updated))) => updated
    _ => body
  }
}

///|
priv struct BestCastFinder {
  env : Env
  most_casted_gets : Map[LocalIdx, RefType]
  less_casted_gets : Map[Int, Array[Int]]
  mut next_get_id : Int
  mut next_refinement_id : Int
  get_local_map : Map[Int, LocalIdx]
}

///|
fn BestCastFinder::new(env : Env) -> BestCastFinder {
  {
    env,
    most_casted_gets: Map::new(),
    less_casted_gets: Map::new(),
    next_get_id: 0,
    next_refinement_id: 0,
    get_local_map: Map::new(),
  }
}

///|
fn BestCastFinder::note_non_linear(
  self : BestCastFinder,
  instr : TInstr,
) -> Unit {
  if oc_is_non_linear_boundary(instr) {
    self.most_casted_gets.clear()
  }
}

///|
fn BestCastFinder::visit_local_set(
  self : BestCastFinder,
  idx : LocalIdx,
) -> Unit {
  self.most_casted_gets.remove(idx)
}

///|
fn BestCastFinder::visit_local_get(
  self : BestCastFinder,
  idx : LocalIdx,
) -> Int {
  let get_id = self.next_get_id
  self.next_get_id = self.next_get_id + 1
  self.get_local_map[get_id] = idx
  match self.most_casted_gets.get(idx) {
    Some(best_cast) =>
      match self.env.get_local_type(idx) {
        Some(RefTypeValType(local_ty)) =>
          if local_ty != best_cast &&
            oc_is_subtype(best_cast, local_ty, self.env) {
            let wants = self.less_casted_gets
              .get(self.next_refinement_id - 1)
              .unwrap_or([])
            wants.push(get_id)
            self.less_casted_gets[self.next_refinement_id - 1] = wants
          }
        _ => ()
      }
    None => ()
  }
  get_id
}

///|
fn BestCastFinder::update_best_cast(
  self : BestCastFinder,
  refinement_id : Int,
  idx : LocalIdx,
  ty : RefType,
) -> Unit {
  ignore(refinement_id)
  match self.most_casted_gets.get(idx) {
    None => self.most_casted_gets[idx] = ty
    Some(best) =>
      if ty != best && oc_is_subtype(ty, best, self.env) {
        self.most_casted_gets[idx] = ty
      }
  }
}

///|
fn oc_refinement_target(instr : TInstr) -> LocalIdx? {
  match instr {
    TLocalGet(idx) => Some(idx)
    TLocalTee(idx, _) => Some(idx)
    TRefCast(_, _, child) | TRefAsNonNull(child) => oc_refinement_target(child)
    _ => None
  }
}

///|
fn BestCastFinder::visit_refinement(
  self : BestCastFinder,
  refinement_id : Int,
  ty : RefType?,
  root : TInstr,
) -> Unit {
  match (oc_refinement_target(root), ty) {
    (Some(idx), Some(rt)) => self.update_best_cast(refinement_id, idx, rt)
    _ => ()
  }
}

///|
fn oc_walk_best_cast_finder_instr(
  finder : BestCastFinder,
  instr : TInstr,
  active_refinement_id : Int?,
) -> Unit {
  finder.note_non_linear(instr)
  match instr {
    TLocalSet(idx, value) => {
      oc_walk_best_cast_finder_instr(finder, value, active_refinement_id)
      finder.visit_local_set(idx)
    }
    TLocalTee(idx, value) => {
      oc_walk_best_cast_finder_instr(finder, value, active_refinement_id)
      finder.visit_local_set(idx)
      let get_id = finder.visit_local_get(idx)
      match active_refinement_id {
        Some(rid) => {
          let wants = finder.less_casted_gets.get(rid).unwrap_or([])
          wants.push(get_id)
          finder.less_casted_gets[rid] = wants
        }
        None => ()
      }
    }
    TLocalGet(idx) => {
      let get_id = finder.visit_local_get(idx)
      match active_refinement_id {
        Some(rid) => {
          let wants = finder.less_casted_gets.get(rid).unwrap_or([])
          wants.push(get_id)
          finder.less_casted_gets[rid] = wants
        }
        None => ()
      }
      ignore(get_id)
    }
    TRefCast(nullable, ht, value) => {
      let rid = finder.next_refinement_id
      finder.next_refinement_id = rid + 1
      oc_walk_best_cast_finder_instr(finder, value, Some(rid))
      finder.visit_refinement(rid, Some(RefType::new(nullable, ht)), instr)
    }
    TRefAsNonNull(value) => {
      let rid = finder.next_refinement_id
      finder.next_refinement_id = rid + 1
      oc_walk_best_cast_finder_instr(finder, value, Some(rid))
      let ty = match oc_refinement_target(value) {
        Some(idx) =>
          match finder.env.get_local_type(idx) {
            Some(RefTypeValType(rt)) =>
              Some(RefType::new(false, rt.get_heap_type()))
            _ => None
          }
        None => None
      }
      finder.visit_refinement(rid, ty, instr)
    }
    TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) =>
      oc_walk_best_cast_finder_expr(finder, body)
    TIf(_, cond, then_, else_) => {
      oc_walk_best_cast_finder_instr(finder, cond, None)
      finder.most_casted_gets.clear()
      oc_walk_best_cast_finder_expr(finder, then_)
      finder.most_casted_gets.clear()
      match else_ {
        Some(other) => oc_walk_best_cast_finder_expr(finder, other)
        None => ()
      }
      finder.most_casted_gets.clear()
    }
    _ =>
      for child in eval_children(instr) {
        oc_walk_best_cast_finder_instr(finder, child, None)
      }
  }
}

///|
fn oc_walk_best_cast_finder_expr(finder : BestCastFinder, expr : TExpr) -> Unit {
  for instr in expr.0 {
    oc_walk_best_cast_finder_instr(finder, instr, None)
  }
}

///|
fn BestCastFinder::run(self : BestCastFinder, body : TExpr) -> Unit {
  oc_walk_best_cast_finder_expr(self, body)
}

///|
fn oc_apply_best_casts(
  func : Func,
  body : TExpr,
  finder : BestCastFinder,
) -> (Func, Bool) {
  if finder.less_casted_gets.is_empty() {
    return (func, false)
  }
  let match_get_to_refinement : Map[Int, Int] = Map::new()
  for entry in finder.less_casted_gets {
    let (refinement_id, gets) = entry
    for get_id in gets {
      match_get_to_refinement[get_id] = refinement_id
    }
  }
  let refinement_temps : Map[Int, LocalIdx] = Map::new()
  let new_locals = match func {
    TFunc(locals, _) => locals.copy()
    _ => []
  }
  let next_local = Ref::new(new_locals.length())
  let next_refinement_id = Ref::new(0)
  let pass_refinement = ModuleTransformer::new().on_tinstruction_evt(fn(
    self,
    _,
    curr,
  ) {
    match curr {
      TRefCast(nullable, ht, _) => {
        let rid = next_refinement_id.val
        next_refinement_id.update(fn(i) { i + 1 })
        let walked = match self.walk_tinstruction_default((), curr) {
          Ok(Some((_, updated))) => updated
          _ => curr
        }
        match finder.less_casted_gets.get(rid) {
          Some(gets) if gets.length() > 0 => {
            let temp = LocalIdx::new(next_local.val.reinterpret_as_uint())
            next_local.update(fn(i) { i + 1 })
            new_locals.push(ValType::ref_type(RefType::new(nullable, ht)))
            refinement_temps[rid] = temp
            change((), TInstr::local_tee(temp, walked))
          }
          _ => change((), walked)
        }
      }
      TRefAsNonNull(_) => {
        let rid = next_refinement_id.val
        next_refinement_id.update(fn(i) { i + 1 })
        let walked = match self.walk_tinstruction_default((), curr) {
          Ok(Some((_, updated))) => updated
          _ => curr
        }
        match finder.less_casted_gets.get(rid) {
          Some(gets) if gets.length() > 0 => {
            let temp = LocalIdx::new(next_local.val.reinterpret_as_uint())
            next_local.update(fn(i) { i + 1 })
            // Non-nullable by construction of ref.as_non_null.
            let temp_ty = match walked {
              TRefAsNonNull(inner) =>
                match oc_refinement_target(inner) {
                  Some(idx) =>
                    match finder.env.get_local_type(idx) {
                      Some(RefTypeValType(rt)) =>
                        ValType::ref_type(
                          RefType::new(false, rt.get_heap_type()),
                        )
                      _ => ValType::anyref()
                    }
                  None => ValType::anyref()
                }
              _ => ValType::anyref()
            }
            new_locals.push(temp_ty)
            refinement_temps[rid] = temp
            change((), TInstr::local_tee(temp, walked))
          }
          _ => change((), walked)
        }
      }
      _ => self.walk_tinstruction_default((), curr)
    }
  })
  let body_with_tees = match pass_refinement.walk_texpr((), body) {
    Ok(Some((_, updated))) => updated
    _ => body
  }
  let get_id = Ref::new(0)
  let pass_gets = ModuleTransformer::new().on_tinstruction_evt(fn(
    self,
    _,
    curr,
  ) {
    match curr {
      TLocalGet(_) => {
        let id = get_id.val
        get_id.update(fn(i) { i + 1 })
        match match_get_to_refinement.get(id) {
          Some(rid) =>
            match refinement_temps.get(rid) {
              Some(temp) => change((), TInstr::local_get(temp))
              None => unchanged()
            }
          None => unchanged()
        }
      }
      _ => self.walk_tinstruction_default((), curr)
    }
  })
  let final_body = match pass_gets.walk_texpr((), body_with_tees) {
    Ok(Some((_, updated))) => updated
    _ => body_with_tees
  }
  let original_local_count = match func {
    TFunc(locals, _) => locals.length()
    _ => 0
  }
  let changed = final_body != body || next_local.val != original_local_count
  let next_func = match func {
    TFunc(_, _) => Func::t_func(new_locals, final_body)
    _ => func
  }
  (next_func, changed)
}

///|
fn optimize_casts_on_func(func : Func, mod : Module) -> Result[Func, String] {
  match func {
    Func(_, _) => Ok(func)
    TFunc(locals, body) => {
      let env = Env::new().with_module(mod).with_locals(locals)
      let early_finder = EarlyCastFinder::new(env, locals.length())
      early_finder.run(body)
      let after_early = if early_finder.has_casts_to_move() {
        oc_apply_early_casts(body, early_finder)
      } else {
        body
      }
      let best_finder = BestCastFinder::new(env)
      best_finder.run(after_early)
      let (next_func, _) = oc_apply_best_casts(
        Func::t_func(locals, after_early),
        after_early,
        best_finder,
      )
      Ok(next_func)
    }
  }
}

///|
fn optimize_casts_ir_pass(mod : Module) -> ModuleTransformer[IRContext] {
  ModuleTransformer::new().on_func_evt(fn(_self, t : IRContext, func) {
    match optimize_casts_on_func(func, mod) {
      Ok(next_func) =>
        match (func, next_func) {
          (TFunc(orig_locals, orig_body), TFunc(next_locals, next_body)) => {
            t.set_body(next_body)
            if orig_locals == next_locals && orig_body == next_body {
              unchanged()
            } else {
              change(t, Func::t_func(next_locals, next_body))
            }
          }
          _ => unchanged()
        }
      Err(e) => Err(e)
    }
  })
}

///|
fn optimize_casts(mod : Module) -> Module {
  let pass = optimize_casts_ir_pass(mod)
  match pass.walk_module(IRContext::new(), mod) {
    Ok(Some((_, out))) => out
    _ => mod
  }
}

///|
fn oc_add_func(mod : Module, func : Func) -> Module {
  let func_type = FuncType::new([], [])
  let type_sec = match mod.type_sec {
    Some(TypeSec(recs)) => {
      let next = recs.copy()
      next.push(
        RecType::new(
          SubType::new(true, [], CompType::func(func_type.0, func_type.1)),
        ),
      )
      TypeSec::new(next)
    }
    None =>
      TypeSec::new([
        RecType::new(
          SubType::new(true, [], CompType::func(func_type.0, func_type.1)),
        ),
      ])
  }
  let type_idx = TypeIdx::new(type_sec.0.length().reinterpret_as_uint() - 1)
  mod
  .with_type_sec(type_sec)
  .with_func_sec(FuncSec::new([type_idx]))
  .with_code_sec(CodeSec::new([func]))
}

///|
fn oc_get_func(mod : Module) -> Func? {
  match mod.code_sec {
    Some(CodeSec([f])) => Some(f)
    _ => None
  }
}

///|
fn oc_test_module() -> Module {
  let t0 = SubType::new(false, [], CompType::struct_([]))
  let t1 = SubType::new(false, [TypeIdx::new(0)], CompType::struct_([]))
  let t2 = SubType::new(false, [TypeIdx::new(1)], CompType::struct_([]))
  Module::new().with_type_sec(
    TypeSec::new([RecType::new(t0), RecType::new(t1), RecType::new(t2)]),
  )
}

///|
test "optimize casts duplicates earlier cast and tees best cast" {
  let local_ty = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let body = TExpr::new([
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::drop(TInstr::nop()),
    TInstr::ref_cast(
      false,
      HeapType::new(TypeIdx::new(1)),
      TInstr::local_get(LocalIdx::new(0)),
    ),
    TInstr::drop(TInstr::nop()),
    TInstr::local_get(LocalIdx::new(0)),
  ])
  let mod_ = oc_add_func(oc_test_module(), Func::t_func([local_ty], body))
  let out = optimize_casts(mod_)
  match oc_get_func(out) {
    Some(TFunc(locals, new_body)) => {
      assert_true(locals.length() >= 2)
      let mut saw_tee = false
      for instr in new_body.0 {
        match instr {
          TLocalTee(_, _) => saw_tee = true
          _ => ()
        }
      }
      assert_true(saw_tee)
    }
    _ => fail("expected transformed function")
  }
}

///|
test "optimize casts uses most refined cast" {
  let local_ty = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let body = TExpr::new([
    TInstr::ref_cast(
      false,
      HeapType::new(TypeIdx::new(1)),
      TInstr::ref_cast(
        false,
        HeapType::new(TypeIdx::new(2)),
        TInstr::local_get(LocalIdx::new(0)),
      ),
    ),
    TInstr::drop(TInstr::nop()),
    TInstr::local_get(LocalIdx::new(0)),
  ])
  let mod_ = oc_add_func(oc_test_module(), Func::t_func([local_ty], body))
  let out = optimize_casts(mod_)
  match oc_get_func(out) {
    Some(TFunc(_, new_body)) => {
      let mut saw_refined = false
      let walk = ModuleTransformer::new().on_tinstruction_evt(fn(
        self,
        _,
        curr,
      ) {
        match curr {
          TRefCast(_, HeapType(TypeIdx(i)), _) if i.reinterpret_as_int() == 2 =>
            saw_refined = true
          _ => ()
        }
        self.walk_tinstruction_default((), curr)
      })
      ignore(walk.walk_texpr((), new_body))
      assert_true(saw_refined)
    }
    _ => fail("expected transformed function")
  }
}

///|
test "optimize casts handles ref.as_non_null movement" {
  let local_ty = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let body = TExpr::new([
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::drop(TInstr::nop()),
    TInstr::ref_as_non_null(TInstr::local_get(LocalIdx::new(0))),
    TInstr::drop(TInstr::nop()),
  ])
  let mod_ = oc_add_func(oc_test_module(), Func::t_func([local_ty], body))
  let out = optimize_casts(mod_)
  match oc_get_func(out) {
    Some(TFunc(_, new_body)) => {
      let mut count_non_null = 0
      let walk = ModuleTransformer::new().on_tinstruction_evt(fn(
        self,
        _,
        curr,
      ) {
        match curr {
          TRefAsNonNull(_) => count_non_null += 1
          _ => ()
        }
        self.walk_tinstruction_default((), curr)
      })
      ignore(walk.walk_texpr((), new_body))
      assert_true(count_non_null >= 1)
    }
    _ => fail("expected transformed function")
  }
}

///|
test "optimize casts resets at non linear boundaries" {
  let local_ty = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let body = TExpr::new([
    TInstr::ref_cast(
      false,
      HeapType::new(TypeIdx::new(1)),
      TInstr::local_get(LocalIdx::new(0)),
    ),
    TInstr::drop(TInstr::nop()),
    TInstr::block(
      BlockType::void_(),
      TExpr::new([TInstr::local_get(LocalIdx::new(0))]),
    ),
  ])
  let mod_ = oc_add_func(oc_test_module(), Func::t_func([local_ty], body))
  let out = optimize_casts(mod_)
  match oc_get_func(out) {
    Some(TFunc(_, new_body)) =>
      match new_body.0[2] {
        TBlock(_, TExpr([inner])) =>
          match inner {
            TLocalGet(i) => assert_eq(i.0.reinterpret_as_int(), 0)
            _ => ()
          }
        _ => fail("expected block")
      }
    _ => fail("expected transformed function")
  }
}
