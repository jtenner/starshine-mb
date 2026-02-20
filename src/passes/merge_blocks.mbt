///|
priv struct BranchCacheKey {
  instr : TInstr
  depth : Int
} derive(Eq, Hash)

///|
priv struct BranchCache {
  entries : Map[BranchCacheKey, Bool]
}

///|
fn BranchCache::new() -> BranchCache {
  { entries: Map::new() }
}

///|
priv struct MBEffects {
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
fn MBEffects::new() -> MBEffects {
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
fn MBEffects::merge(self : MBEffects, other : MBEffects) -> Unit {
  for idx in other.locals_read {
    self.locals_read.add(idx)
  }
  for idx in other.locals_written {
    self.locals_written.add(idx)
  }
  self.reads_memory = self.reads_memory || other.reads_memory
  self.writes_memory = self.writes_memory || other.writes_memory
  self.reads_globals = self.reads_globals || other.reads_globals
  self.writes_globals = self.writes_globals || other.writes_globals
  self.calls = self.calls || other.calls
  self.branches = self.branches || other.branches
  self.traps = self.traps || other.traps
  self.throws = self.throws || other.throws
}

///|
fn MBEffects::invalidates(self : MBEffects, other : MBEffects) -> Bool {
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
  if self.branches || other.branches || self.throws || other.throws {
    return true
  }
  if self.traps || other.traps {
    if self.has_side_effects() || other.has_side_effects() {
      return true
    }
  }
  false
}

///|
fn MBEffects::has_side_effects(self : MBEffects) -> Bool {
  self.locals_written.length() > 0 ||
  self.writes_memory ||
  self.writes_globals ||
  self.calls ||
  self.branches ||
  self.throws ||
  self.traps
}

///|
fn compute_effects(expr : TInstr) -> MBEffects {
  let effects = MBEffects::new()
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    mb_collect_shallow_effects(curr, effects)
    self.walk_tinstruction_default((), curr)
  })
  ignore(walker.walk_tinstruction((), expr))
  effects
}

///|
fn invalidates(a : MBEffects, b : MBEffects) -> Bool {
  a.invalidates(b)
}

///|
fn mb_collect_shallow_effects(instr : TInstr, effects : MBEffects) -> Unit {
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
    TThrow(_, _) => {
      effects.throws = true
      effects.branches = true
    }
    TThrowRef(_) => {
      effects.throws = true
      effects.branches = true
    }
    TUnreachable => effects.traps = true
    TRefAsNonNull(_) | TRefCast(_, _, _) => effects.traps = true
    TStructGet(_, _, _) | TStructGetS(_, _, _) | TStructGetU(_, _, _) => {
      effects.reads_memory = true
      effects.traps = true
    }
    TStructSet(_, _, _, _) => {
      effects.writes_memory = true
      effects.traps = true
    }
    TArrayGet(_, _, _) | TArrayGetS(_, _, _) | TArrayGetU(_, _, _) => {
      effects.reads_memory = true
      effects.traps = true
    }
    TArraySet(_, _, _, _) | TArrayFill(_, _, _, _, _) => {
      effects.writes_memory = true
      effects.traps = true
    }
    TArrayCopy(_, _, _, _, _, _, _)
    | TArrayInitData(_, _, _, _, _, _)
    | TArrayInitElem(_, _, _, _, _, _) => {
      effects.reads_memory = true
      effects.writes_memory = true
      effects.traps = true
    }
    TArrayNew(_, _, _)
    | TArrayNewDefault(_, _)
    | TArrayNewFixed(_, _)
    | TArrayNewData(_, _, _, _)
    | TArrayNewElem(_, _, _, _)
    | TStructNew(_, _)
    | TStructNewDefault(_) => effects.writes_memory = true
    _ => ()
  }
}

///|
priv struct MBContext {
  env : Env
  mut needs_refinalize : Bool
  branch_cache : BranchCache
}

///|
fn MBContext::new(env : Env) -> MBContext {
  { env, needs_refinalize: false, branch_cache: BranchCache::new() }
}

///|
priv enum ProblemResult {
  ProblemOk
  ProblemBlocked
}

///|
priv struct ProblemFinderState {
  mut blocked : String?
  mut total_br_if_values : Int
  mut dropped_br_if_values : Int
}

///|
fn ProblemFinderState::new() -> ProblemFinderState {
  { blocked: None, total_br_if_values: 0, dropped_br_if_values: 0 }
}

///|
fn mb_label_to_int(label : LabelIdx) -> Int {
  let LabelIdx(raw) = label
  raw.reinterpret_as_int()
}

///|
fn mb_label_matches_depth(label : LabelIdx, depth : Int) -> Bool {
  mb_label_to_int(label) == depth
}

///|
fn has_branch(expr : TInstr, name : LabelIdx) -> Bool {
  mb_has_branch_to_depth(expr, mb_label_to_int(name), BranchCache::new())
}

///|
fn mb_has_any_branch(instr : TInstr) -> Bool {
  match instr {
    TBr(_, _)
    | TBrIf(_, _, _)
    | TBrTable(_, _, _, _)
    | TBrOnNull(_, _, _)
    | TBrOnNonNull(_, _, _)
    | TBrOnCast(_, _, _, _, _, _)
    | TBrOnCastFail(_, _, _, _, _, _)
    | TReturn(_) => true
    TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) =>
      mb_has_any_branch_in_expr(body)
    TIf(_, cond, then_body, else_body) => {
      if mb_has_any_branch(cond) || mb_has_any_branch_in_expr(then_body) {
        return true
      }
      match else_body {
        Some(else_) => mb_has_any_branch_in_expr(else_)
        None => false
      }
    }
    _ => {
      for child in mb_eval_children(instr) {
        if mb_has_any_branch(child) {
          return true
        }
      }
      false
    }
  }
}

///|
fn mb_has_any_branch_in_expr(expr : TExpr) -> Bool {
  for instr in expr.0 {
    if mb_has_any_branch(instr) {
      return true
    }
  }
  false
}

///|
fn mb_has_branch_to_depth(
  instr : TInstr,
  depth : Int,
  cache : BranchCache,
) -> Bool {
  let key = { instr, depth }
  match cache.entries.get(key) {
    Some(v) => v
    None => {
      let v = mb_has_branch_to_depth_uncached(instr, depth, cache)
      cache.entries[key] = v
      v
    }
  }
}

///|
fn mb_has_branch_to_depth_uncached(
  instr : TInstr,
  depth : Int,
  cache : BranchCache,
) -> Bool {
  match instr {
    TBr(label, _) => mb_label_matches_depth(label, depth)
    TBrIf(label, _, _) => mb_label_matches_depth(label, depth)
    TBrTable(labels, default, _, _) => {
      if mb_label_matches_depth(default, depth) {
        return true
      }
      for label in labels {
        if mb_label_matches_depth(label, depth) {
          return true
        }
      }
      false
    }
    TBrOnNull(label, _, _)
    | TBrOnNonNull(label, _, _)
    | TBrOnCast(label, _, _, _, _, _)
    | TBrOnCastFail(label, _, _, _, _, _) =>
      mb_label_matches_depth(label, depth)
    TBlock(_, body) | TLoop(_, body) =>
      mb_has_branch_to_depth_in_expr(body, depth + 1, cache)
    TIf(_, cond, then_body, else_body) => {
      if mb_has_branch_to_depth(cond, depth, cache) {
        return true
      }
      if mb_has_branch_to_depth_in_expr(then_body, depth + 1, cache) {
        return true
      }
      match else_body {
        Some(other) => mb_has_branch_to_depth_in_expr(other, depth + 1, cache)
        None => false
      }
    }
    TTryTable(_, catches, body) => {
      for catch_ in catches {
        if mb_catch_targets_depth(catch_, depth + 1) {
          return true
        }
      }
      mb_has_branch_to_depth_in_expr(body, depth + 1, cache)
    }
    _ => {
      for child in mb_eval_children(instr) {
        if mb_has_branch_to_depth(child, depth, cache) {
          return true
        }
      }
      false
    }
  }
}

///|
fn mb_has_branch_to_depth_in_expr(
  expr : TExpr,
  depth : Int,
  cache : BranchCache,
) -> Bool {
  for instr in expr.0 {
    if mb_has_branch_to_depth(instr, depth, cache) {
      return true
    }
  }
  false
}

///|
fn mb_catch_targets_depth(catch_ : Catch, depth : Int) -> Bool {
  match catch_ {
    Catch(_, label)
    | CatchRef(_, label)
    | CatchAll(label)
    | CatchAllRef(label) => mb_label_matches_depth(label, depth)
  }
}

///|
fn mb_single_result_of_blocktype(bt : BlockType, env : Env) -> ValType? {
  match env.expand_blocktype(bt) {
    Ok((_, [vt])) => Some(vt)
    _ => None
  }
}

///|
fn mb_unary_result_type(op : UnaryOp, operand_ty : ValType?) -> ValType? {
  match op {
    I32EqzOp
    | I32ClzOp
    | I32CtzOp
    | I32PopcntOp
    | I32WrapI64Op
    | I32TruncF32SOp
    | I32TruncF32UOp
    | I32TruncF64SOp
    | I32TruncF64UOp
    | I32ReinterpretF32Op
    | I32Extend8SOp
    | I32Extend16SOp
    | I32TruncSatF32SOp
    | I32TruncSatF32UOp
    | I32TruncSatF64SOp
    | I32TruncSatF64UOp
    | I64EqzOp
    | V128AnyTrueOp
    | I8x16AllTrueOp
    | I8x16BitmaskOp
    | I16x8AllTrueOp
    | I16x8BitmaskOp
    | I32x4AllTrueOp
    | I32x4BitmaskOp
    | I64x2AllTrueOp
    | I64x2BitmaskOp => Some(ValType::i32())
    I64ClzOp
    | I64CtzOp
    | I64PopcntOp
    | I64ExtendI32SOp
    | I64ExtendI32UOp
    | I64TruncF32SOp
    | I64TruncF32UOp
    | I64TruncF64SOp
    | I64TruncF64UOp
    | I64ReinterpretF64Op
    | I64Extend8SOp
    | I64Extend16SOp
    | I64Extend32SOp
    | I64TruncSatF32SOp
    | I64TruncSatF32UOp
    | I64TruncSatF64SOp
    | I64TruncSatF64UOp => Some(ValType::i64())
    F32AbsOp
    | F32NegOp
    | F32CeilOp
    | F32FloorOp
    | F32TruncOp
    | F32NearestOp
    | F32SqrtOp
    | F32ConvertI32SOp
    | F32ConvertI32UOp
    | F32ConvertI64SOp
    | F32ConvertI64UOp
    | F32DemoteF64Op
    | F32ReinterpretI32Op => Some(ValType::f32())
    F64AbsOp
    | F64NegOp
    | F64CeilOp
    | F64FloorOp
    | F64TruncOp
    | F64NearestOp
    | F64SqrtOp
    | F64ConvertI32SOp
    | F64ConvertI32UOp
    | F64ConvertI64SOp
    | F64ConvertI64UOp
    | F64PromoteF32Op
    | F64ReinterpretI64Op => Some(ValType::f64())
    _ => operand_ty
  }
}

///|
fn mb_binary_result_type(op : BinaryOp, lhs_ty : ValType?) -> ValType? {
  match op {
    I32EqOp
    | I32NeOp
    | I32LtSOp
    | I32LtUOp
    | I32GtSOp
    | I32GtUOp
    | I32LeSOp
    | I32LeUOp
    | I32GeSOp
    | I32GeUOp
    | I64EqOp
    | I64NeOp
    | I64LtSOp
    | I64LtUOp
    | I64GtSOp
    | I64GtUOp
    | I64LeSOp
    | I64LeUOp
    | I64GeSOp
    | I64GeUOp
    | F32EqOp
    | F32NeOp
    | F32LtOp
    | F32GtOp
    | F32LeOp
    | F32GeOp
    | F64EqOp
    | F64NeOp
    | F64LtOp
    | F64GtOp
    | F64LeOp
    | F64GeOp => Some(ValType::i32())
    I32AddOp
    | I32SubOp
    | I32MulOp
    | I32DivSOp
    | I32DivUOp
    | I32RemSOp
    | I32RemUOp
    | I32AndOp
    | I32OrOp
    | I32XorOp
    | I32ShlOp
    | I32ShrSOp
    | I32ShrUOp
    | I32RotlOp
    | I32RotrOp => Some(ValType::i32())
    I64AddOp
    | I64SubOp
    | I64MulOp
    | I64DivSOp
    | I64DivUOp
    | I64RemSOp
    | I64RemUOp
    | I64AndOp
    | I64OrOp
    | I64XorOp
    | I64ShlOp
    | I64ShrSOp
    | I64ShrUOp
    | I64RotlOp
    | I64RotrOp => Some(ValType::i64())
    F32AddOp
    | F32SubOp
    | F32MulOp
    | F32DivOp
    | F32MinOp
    | F32MaxOp
    | F32CopysignOp => Some(ValType::f32())
    F64AddOp
    | F64SubOp
    | F64MulOp
    | F64DivOp
    | F64MinOp
    | F64MaxOp
    | F64CopysignOp => Some(ValType::f64())
    _ => lhs_ty
  }
}

///|
fn mb_load_result_type(op : LoadOp) -> ValType {
  match op {
    I32LoadOp | I32Load8SOp | I32Load8UOp | I32Load16SOp | I32Load16UOp =>
      ValType::i32()
    I64LoadOp
    | I64Load8SOp
    | I64Load8UOp
    | I64Load16SOp
    | I64Load16UOp
    | I64Load32SOp
    | I64Load32UOp => ValType::i64()
    F32LoadOp => ValType::f32()
    F64LoadOp => ValType::f64()
    _ => ValType::v128()
  }
}

///|
fn mb_ref_func_type(fi : FuncIdx, env : Env) -> ValType {
  match env.get_functype_by_funcidx(fi) {
    Some(_) => ValType::funcref()
    None => ValType::funcref()
  }
}

///|
fn mb_infer_texpr_type(texpr : TExpr, env : Env) -> ValType? {
  let TExpr(instrs) = texpr
  if instrs.is_empty() {
    None
  } else {
    mb_infer_tinstr_type(instrs[instrs.length() - 1], env)
  }
}

///|
fn mb_infer_tinstr_type(instr : TInstr, env : Env) -> ValType? {
  match instr {
    TI32Const(_) => Some(ValType::i32())
    TI64Const(_) => Some(ValType::i64())
    TF32Const(_) => Some(ValType::f32())
    TF64Const(_) => Some(ValType::f64())
    TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      Some(ValType::v128())
    TRefNull(ht) => Some(ValType::ref_type(RefType::new(true, ht)))
    TRefFunc(fi) => Some(mb_ref_func_type(fi, env))
    TLocalGet(idx) => env.get_local_type(idx)
    TGlobalGet(idx) =>
      match env.get_global_type(idx) {
        Some(GlobalType(vt, _)) => Some(vt)
        None => None
      }
    TLocalTee(_, value) => mb_infer_tinstr_type(value, env)
    TUnary(op, value) =>
      mb_unary_result_type(op, mb_infer_tinstr_type(value, env))
    TBinary(op, lhs, _) =>
      mb_binary_result_type(op, mb_infer_tinstr_type(lhs, env))
    TRefEq(_, _) | TRefIsNull(_) | TRefTest(_, _, _) => Some(ValType::i32())
    TLoad(op, _, _) => Some(mb_load_result_type(op))
    TMemorySize(_) | TTableSize(_) => Some(ValType::i32())
    TRefAsNonNull(value) =>
      match mb_infer_tinstr_type(value, env) {
        Some(RefTypeValType(rt)) =>
          Some(ValType::ref_type(RefType::new(false, rt.get_heap_type())))
        _ => None
      }
    TRefCast(nullable, ht, _) =>
      Some(ValType::ref_type(RefType::new(nullable, ht)))
    TStructNew(type_idx, _)
    | TStructNewDefault(type_idx)
    | TArrayNew(type_idx, _, _)
    | TArrayNewDefault(type_idx, _)
    | TArrayNewFixed(type_idx, _)
    | TArrayNewData(type_idx, _, _, _)
    | TArrayNewElem(type_idx, _, _, _) =>
      Some(ValType::ref_type(RefType::new(false, HeapType::new(type_idx))))
    TStructGet(type_idx, field_idx, _)
    | TStructGetS(type_idx, field_idx, _)
    | TStructGetU(type_idx, field_idx, _) =>
      match env.resolve_struct_fields(type_idx) {
        Ok(fields) =>
          match field_idx {
            U32(raw_idx) =>
              match fields.get(raw_idx.reinterpret_as_int()) {
                Some(field_ty) => Some(field_ty.unpack())
                None => None
              }
          }
        Err(_) => None
      }
    TArrayGet(type_idx, _, _)
    | TArrayGetS(type_idx, _, _)
    | TArrayGetU(type_idx, _, _) =>
      match env.resolve_array_field(type_idx) {
        Ok(field_ty) => Some(field_ty.unpack())
        Err(_) => None
      }
    TArrayLen(_) => Some(ValType::i32())
    TExtractLane(op, _, _) =>
      match op {
        I8x16ExtractLaneSOp
        | I8x16ExtractLaneUOp
        | I16x8ExtractLaneSOp
        | I16x8ExtractLaneUOp
        | I32x4ExtractLaneOp => Some(ValType::i32())
        I64x2ExtractLaneOp => Some(ValType::i64())
        F32x4ExtractLaneOp => Some(ValType::f32())
        F64x2ExtractLaneOp => Some(ValType::f64())
      }
    TI31GetS(_) | TI31GetU(_) => Some(ValType::i32())
    TRefI31(_) =>
      Some(
        ValType::ref_type(
          RefType::new(false, HeapType::abs(AbsHeapType::i31())),
        ),
      )
    TAnyConvertExtern(_) => Some(ValType::anyref())
    TExternConvertAny(_) => Some(ValType::externref())
    TSelect(types, _, if_true, if_false) => {
      let from_decl = match types {
        Some(vts) if vts.length() == 1 => Some(vts[0])
        _ => None
      }
      let from_branches = match
        (
          mb_infer_tinstr_type(if_true, env),
          mb_infer_tinstr_type(if_false, env),
        ) {
        (Some(t), Some(f)) if t == f => Some(t)
        _ => None
      }
      match (from_branches, from_decl) {
        (Some(t), _) => Some(t)
        (_, Some(vt)) => Some(vt)
        _ => None
      }
    }
    TCall(target, _) =>
      match env.get_functype_by_funcidx(target) {
        Some(FuncType(_, [r])) => Some(r)
        _ => None
      }
    TCallIndirect(type_idx, _, _, _) | TCallRef(type_idx, _, _) =>
      match env.resolve_functype(type_idx) {
        Some(FuncType(_, [r])) => Some(r)
        _ => None
      }
    TBlock(bt, body) | TLoop(bt, body) | TTryTable(bt, _, body) =>
      match
        (mb_infer_texpr_type(body, env), mb_single_result_of_blocktype(bt, env)) {
        (Some(t), _) => Some(t)
        (_, Some(vt)) => Some(vt)
        _ => None
      }
    TIf(bt, _, then_, else_) => {
      let from_bt = mb_single_result_of_blocktype(bt, env)
      let from_branches = match else_ {
        Some(else_expr) =>
          match
            (
              mb_infer_texpr_type(then_, env),
              mb_infer_texpr_type(else_expr, env),
            ) {
            (Some(t), Some(e)) if t == e => Some(t)
            _ => None
          }
        None => None
      }
      match (from_branches, from_bt) {
        (Some(t), _) => Some(t)
        (_, Some(vt)) => Some(vt)
        _ => None
      }
    }
    _ => None
  }
}

///|
fn mb_instr_is_concrete(instr : TInstr, env : Env) -> Bool {
  match mb_infer_tinstr_type(instr, env) {
    Some(_) => true
    None => false
  }
}

///|
fn mb_blocktype_is_concrete(bt : BlockType, env : Env) -> Bool {
  match mb_single_result_of_blocktype(bt, env) {
    Some(_) => true
    None => false
  }
}

///|
fn mb_is_unreachable_instr(instr : TInstr) -> Bool {
  match instr {
    TUnreachable
    | TBr(_, _)
    | TBrTable(_, _, _, _)
    | TReturn(_)
    | TReturnCall(_, _)
    | TReturnCallIndirect(_, _, _, _)
    | TReturnCallRef(_, _, _)
    | TThrow(_, _)
    | TThrowRef(_) => true
    TBlock(_, body) => mb_texpr_is_unreachable(body)
    TLoop(_, body) => mb_texpr_is_unreachable(body)
    TIf(_, cond, then_body, else_body) => {
      if mb_is_unreachable_instr(cond) {
        return true
      }
      match else_body {
        Some(else_) =>
          mb_texpr_is_unreachable(then_body) && mb_texpr_is_unreachable(else_)
        None => false
      }
    }
    TTryTable(_, _, body) => mb_texpr_is_unreachable(body)
    _ => false
  }
}

///|
fn mb_texpr_is_unreachable(expr : TExpr) -> Bool {
  for instr in expr.0 {
    if mb_is_unreachable_instr(instr) {
      return true
    }
  }
  false
}

///|
fn has_dead_code(block : TInstr) -> Bool {
  match block {
    TBlock(_, body) | TLoop(_, body) => mb_has_dead_code_in_expr(body)
    _ => false
  }
}

///|
fn mb_has_dead_code_in_expr(body : TExpr) -> Bool {
  let instrs = body.0
  for i = 0; i < instrs.length(); i = i + 1 {
    if mb_is_unreachable_instr(instrs[i]) && i + 1 < instrs.length() {
      return true
    }
  }
  false
}

///|
fn mb_finalize_block(block : TInstr, env : Env) -> TInstr {
  match block {
    TBlock(bt, body) => {
      let next_bt = mb_finalize_block_type(bt, body, env)
      TInstr::block(next_bt, body)
    }
    TLoop(bt, body) => {
      let next_bt = mb_finalize_block_type(bt, body, env)
      TInstr::loop_(next_bt, body)
    }
    TTryTable(bt, catches, body) => {
      let next_bt = mb_finalize_block_type(bt, body, env)
      TInstr::try_table(next_bt, catches, body)
    }
    _ => block
  }
}

///|
fn mb_finalize_block_type(bt : BlockType, body : TExpr, env : Env) -> BlockType {
  match bt {
    VoidBlockType => BlockType::void_()
    ValTypeBlockType(_) =>
      match mb_infer_texpr_type(body, env) {
        Some(vt) => BlockType::val_type(vt)
        None => BlockType::void_()
      }
    TypeIdxBlockType(_) => bt
  }
}

///|
fn mb_refinalize_instr(instr : TInstr, env : Env) -> TInstr {
  match instr {
    TBlock(bt, body) => {
      let next_body = mb_refinalize_texpr(body, env)
      mb_finalize_block(TInstr::block(bt, next_body), env)
    }
    TLoop(bt, body) => {
      let next_body = mb_refinalize_texpr(body, env)
      mb_finalize_block(TInstr::loop_(bt, next_body), env)
    }
    TTryTable(bt, catches, body) => {
      let next_body = mb_refinalize_texpr(body, env)
      mb_finalize_block(TInstr::try_table(bt, catches, next_body), env)
    }
    TIf(bt, cond, then_, else_) => {
      let next_cond = mb_refinalize_instr(cond, env)
      let next_then = mb_refinalize_texpr(then_, env)
      let next_else = match else_ {
        Some(e) => Some(mb_refinalize_texpr(e, env))
        None => None
      }
      let next_bt = match bt {
        TypeIdxBlockType(_) => bt
        _ =>
          match next_else {
            Some(e) =>
              match
                (
                  mb_infer_texpr_type(next_then, env),
                  mb_infer_texpr_type(e, env),
                ) {
                (Some(t), Some(u)) if t == u => BlockType::val_type(t)
                _ => BlockType::void_()
              }
            None => BlockType::void_()
          }
      }
      TInstr::if_(next_bt, next_cond, next_then, next_else)
    }
    _ => {
      let children = mb_eval_children(instr)
      if children.is_empty() {
        instr
      } else {
        let next_children = []
        for child in children {
          next_children.push(mb_refinalize_instr(child, env))
        }
        mb_rebuild_non_control(instr, next_children)
      }
    }
  }
}

///|
fn mb_refinalize_texpr(expr : TExpr, env : Env) -> TExpr {
  let out : Array[TInstr] = []
  for instr in expr.0 {
    out.push(mb_refinalize_instr(instr, env))
  }
  TExpr::new(out)
}

///|
fn mb_sequence(instrs : Array[TInstr]) -> TInstr {
  match instrs {
    [] => TInstr::nop()
    [single] => single
    _ => TInstr::block(BlockType::void_(), TExpr::new(instrs))
  }
}

///|
fn mb_drop_or_value(value : TInstr, env : Env) -> TInstr {
  if mb_instr_is_concrete(value, env) {
    TInstr::drop(value)
  } else {
    value
  }
}

///|
fn mb_can_extract_child_block(
  bt : BlockType,
  body : TExpr,
  env : Env,
  branch_cache : BranchCache,
) -> (Bool, Array[TInstr], TInstr) {
  let items = body.0
  if items.length() < 2 {
    return (false, [], TInstr::nop())
  }
  if mb_has_branch_to_depth_in_expr(body, 0, branch_cache) {
    return (false, [], TInstr::nop())
  }
  let back = items[items.length() - 1]
  if mb_is_unreachable_instr(back) {
    return (false, [], TInstr::nop())
  }
  let block_ty = mb_single_result_of_blocktype(bt, env)
  let back_ty = mb_infer_tinstr_type(back, env)
  match bt {
    TypeIdxBlockType(_) => return (false, [], TInstr::nop())
    _ => ()
  }
  if block_ty != back_ty {
    return (false, [], TInstr::nop())
  }
  let prefix = []
  for i = 0; i + 1 < items.length(); i = i + 1 {
    prefix.push(items[i])
  }
  (true, prefix, back)
}

///|
fn optimize_expression_restructure(
  parent_expr : TInstr,
  mod : Module,
  options : OptimizeOptions,
  branch_cache : BranchCache,
  ctx : MBContext,
) -> (TInstr, Bool) {
  match parent_expr {
    TIf(bt, cond, then_, else_) =>
      match cond {
        TBlock(cbt, cbody) => {
          let (ok, prefix, back) = mb_can_extract_child_block(
            cbt,
            cbody,
            ctx.env,
            branch_cache,
          )
          if !ok {
            return (parent_expr, false)
          }
          let moved_effects = MBEffects::new()
          for item in prefix {
            moved_effects.merge(compute_effects(item))
          }
          if moved_effects.has_side_effects() {
            ctx.needs_refinalize = true
          }
          let wrapped = []
          for item in prefix {
            wrapped.push(item)
          }
          wrapped.push(TInstr::if_(bt, back, then_, else_))
          let wrapper_bt = match mb_infer_tinstr_type(parent_expr, ctx.env) {
            Some(vt) => BlockType::val_type(vt)
            None => BlockType::void_()
          }
          return (TInstr::block(wrapper_bt, TExpr::new(wrapped)), true)
        }
        _ => (parent_expr, false)
      }
    TThrow(_, args) => {
      for arg in args {
        if compute_effects(arg).has_side_effects() {
          return (parent_expr, false)
        }
      }
      mb_restructure_non_control(parent_expr, mod, options, branch_cache, ctx)
    }
    TBlock(_, _) | TLoop(_, _) | TTryTable(_, _, _) => (parent_expr, false)
    _ =>
      mb_restructure_non_control(parent_expr, mod, options, branch_cache, ctx)
  }
}

///|
fn mb_restructure_non_control(
  parent_expr : TInstr,
  _mod : Module,
  _options : OptimizeOptions,
  branch_cache : BranchCache,
  ctx : MBContext,
) -> (TInstr, Bool) {
  let children = mb_eval_children(parent_expr)
  if children.is_empty() {
    return (parent_expr, false)
  }
  let pulled : Array[TInstr] = []
  let rebuilt_children : Array[TInstr] = []
  let effects_before = MBEffects::new()
  let mut changed = false
  for child in children {
    let mut next_child = child
    match child {
      TBlock(bt, body) => {
        let (ok, prefix, back) = mb_can_extract_child_block(
          bt,
          body,
          ctx.env,
          branch_cache,
        )
        if ok {
          let moved_effects = MBEffects::new()
          let mut move_ok = true
          for item in prefix {
            moved_effects.merge(compute_effects(item))
            if mb_has_any_branch(item) {
              move_ok = false
            }
          }
          if move_ok &&
            !invalidates(moved_effects, effects_before) &&
            !invalidates(effects_before, moved_effects) {
            for item in prefix {
              pulled.push(item)
            }
            next_child = back
            changed = true
            ctx.needs_refinalize = true
          }
        }
      }
      _ => ()
    }
    rebuilt_children.push(next_child)
    effects_before.merge(compute_effects(next_child))
  }
  if !changed {
    return (parent_expr, false)
  }
  let rebuilt_parent = mb_rebuild_non_control(parent_expr, rebuilt_children)
  let wrapper_items = []
  for item in pulled {
    wrapper_items.push(item)
  }
  wrapper_items.push(rebuilt_parent)
  let wrapper_bt = match mb_infer_tinstr_type(rebuilt_parent, ctx.env) {
    Some(vt) => BlockType::val_type(vt)
    None => BlockType::void_()
  }
  (TInstr::block(wrapper_bt, TExpr::new(wrapper_items)), true)
}

///|
fn problem_finder(
  origin : LabelIdx,
  expr : TInstr,
  mod : Module,
  options : OptimizeOptions,
  ctx : MBContext,
) -> ProblemResult {
  ignore(mod)
  ignore(options)
  let st = ProblemFinderState::new()
  mb_problem_finder_walk(origin, expr, 0, false, st, ctx.env)
  match st.blocked {
    Some(_) => ProblemBlocked
    None =>
      if st.total_br_if_values != st.dropped_br_if_values {
        ProblemBlocked
      } else {
        ProblemOk
      }
  }
}

///|
fn mb_problem_finder_walk(
  origin : LabelIdx,
  expr : TInstr,
  depth : Int,
  under_drop : Bool,
  st : ProblemFinderState,
  env : Env,
) -> Unit {
  if st.blocked is Some(_) {
    return
  }
  let origin_depth = mb_label_to_int(origin) + depth
  match expr {
    TBr(label, values) =>
      if mb_label_matches_depth(label, origin_depth) && !values.is_empty() {
        for value in values {
          if compute_effects(value).has_side_effects() {
            st.blocked = Some("side effects in br value")
            return
          }
        }
      }
    TBrIf(label, cond, values) => {
      mb_problem_finder_walk(origin, cond, depth, false, st, env)
      if st.blocked is Some(_) {
        return
      }
      if mb_label_matches_depth(label, origin_depth) && !values.is_empty() {
        st.total_br_if_values += 1
        if under_drop {
          st.dropped_br_if_values += 1
        }
        for value in values {
          if compute_effects(value).has_side_effects() {
            st.blocked = Some("side effects in br_if value")
            return
          }
        }
      }
      for value in values {
        mb_problem_finder_walk(origin, value, depth, false, st, env)
        if st.blocked is Some(_) {
          return
        }
      }
    }
    TBrTable(labels, default, index, values) => {
      let mut targets_origin = mb_label_matches_depth(default, origin_depth)
      if !targets_origin {
        for label in labels {
          if mb_label_matches_depth(label, origin_depth) {
            targets_origin = true
            break
          }
        }
      }
      if targets_origin {
        st.blocked = Some("unsupported branch op targeting origin")
        return
      }
      mb_problem_finder_walk(origin, index, depth, false, st, env)
      for value in values {
        mb_problem_finder_walk(origin, value, depth, false, st, env)
      }
    }
    TBrOnNull(label, ref_, values)
    | TBrOnNonNull(label, ref_, values)
    | TBrOnCast(label, _, _, _, ref_, values)
    | TBrOnCastFail(label, _, _, _, ref_, values) => {
      if mb_label_matches_depth(label, origin_depth) {
        st.blocked = Some("unsupported branch op targeting origin")
        return
      }
      mb_problem_finder_walk(origin, ref_, depth, false, st, env)
      for value in values {
        mb_problem_finder_walk(origin, value, depth, false, st, env)
      }
    }
    TTryTable(_, catches, body) => {
      for catch_ in catches {
        match catch_ {
          Catch(_, label)
          | CatchRef(_, label)
          | CatchAll(label)
          | CatchAllRef(label) =>
            if mb_label_matches_depth(label, origin_depth + 1) {
              match catch_ {
                CatchAllRef(_) => ()
                CatchRef(tag_idx, _) =>
                  match env.resolve_tag_functype(tag_idx) {
                    Some(FuncType(params, _)) if params.is_empty() => ()
                    _ => {
                      st.blocked = Some(
                        "catch_ref with paramful tag targets origin",
                      )
                      return
                    }
                  }
                _ => {
                  st.blocked = Some("unsupported catch targeting origin")
                  return
                }
              }
            }
        }
      }
      mb_problem_finder_walk_expr(origin, body, depth + 1, false, st, env)
    }
    TDrop(value) => mb_problem_finder_walk(origin, value, depth, true, st, env)
    TBlock(_, body) | TLoop(_, body) =>
      mb_problem_finder_walk_expr(origin, body, depth + 1, false, st, env)
    TIf(_, cond, then_, else_) => {
      mb_problem_finder_walk(origin, cond, depth, false, st, env)
      if st.blocked is Some(_) {
        return
      }
      mb_problem_finder_walk_expr(origin, then_, depth + 1, false, st, env)
      if st.blocked is Some(_) {
        return
      }
      match else_ {
        Some(e) =>
          mb_problem_finder_walk_expr(origin, e, depth + 1, false, st, env)
        None => ()
      }
    }
    _ =>
      for child in mb_eval_children(expr) {
        mb_problem_finder_walk(origin, child, depth, false, st, env)
        if st.blocked is Some(_) {
          return
        }
      }
  }
}

///|
fn mb_problem_finder_walk_expr(
  origin : LabelIdx,
  expr : TExpr,
  depth : Int,
  under_drop : Bool,
  st : ProblemFinderState,
  env : Env,
) -> Unit {
  for instr in expr.0 {
    mb_problem_finder_walk(origin, instr, depth, under_drop, st, env)
    if st.blocked is Some(_) {
      return
    }
  }
}

///|
fn break_value_dropper(
  origin : LabelIdx,
  expr : TInstr,
  mod : Module,
  options : OptimizeOptions,
  branch_cache : BranchCache,
  ctx : MBContext,
) -> TInstr {
  ignore(options)
  mb_break_value_dropper_walk(origin, expr, 0, mod, branch_cache, ctx)
}

///|
fn mb_break_value_dropper_walk(
  origin : LabelIdx,
  expr : TInstr,
  depth : Int,
  mod : Module,
  branch_cache : BranchCache,
  ctx : MBContext,
) -> TInstr {
  let origin_depth = mb_label_to_int(origin) + depth
  match expr {
    TBr(label, values) =>
      if mb_label_matches_depth(label, origin_depth) && !values.is_empty() {
        let prefix : Array[TInstr] = []
        for value in values {
          if mb_is_unreachable_instr(value) {
            return TInstr::unreachable_()
          }
          prefix.push(mb_drop_or_value(value, ctx.env))
        }
        prefix.push(TInstr::br(label, []))
        mb_sequence(prefix)
      } else {
        expr
      }
    TBrIf(label, cond, values) => {
      let next_cond = mb_break_value_dropper_walk(
        origin, cond, depth, mod, branch_cache, ctx,
      )
      let next_values : Array[TInstr] = []
      for value in values {
        next_values.push(
          mb_break_value_dropper_walk(
            origin, value, depth, mod, branch_cache, ctx,
          ),
        )
      }
      if mb_label_matches_depth(label, origin_depth) && !next_values.is_empty() {
        let prefix : Array[TInstr] = []
        for value in next_values {
          if mb_is_unreachable_instr(value) {
            return TInstr::unreachable_()
          }
          prefix.push(mb_drop_or_value(value, ctx.env))
        }
        prefix.push(TInstr::br_if(label, next_cond, []))
        mb_sequence(prefix)
      } else {
        TInstr::br_if(label, next_cond, next_values)
      }
    }
    TTryTable(bt, catches, body) => {
      let next_catches : Array[Catch] = []
      for catch_ in catches {
        let next = match catch_ {
          CatchRef(tag, label) if mb_label_matches_depth(
              label,
              origin_depth + 1,
            ) => Catch::new(tag, label)
          CatchAllRef(label) if mb_label_matches_depth(label, origin_depth + 1) =>
            Catch::all(label)
          _ => catch_
        }
        next_catches.push(next)
      }
      let next_body = mb_break_value_dropper_expr(
        origin,
        body,
        depth + 1,
        mod,
        branch_cache,
        ctx,
      )
      let rewritten = TInstr::try_table(bt, next_catches, next_body)
      let (optimized, _) = optimize_block(
        rewritten,
        mod,
        OptimizeOptions::new(),
        branch_cache,
        ctx,
      )
      optimized
    }
    TDrop(value) => {
      let next_value = mb_break_value_dropper_walk(
        origin, value, depth, mod, branch_cache, ctx,
      )
      if mb_instr_is_concrete(next_value, ctx.env) {
        TInstr::drop(next_value)
      } else {
        next_value
      }
    }
    TBlock(bt, body) => {
      let next_body = mb_break_value_dropper_expr(
        origin,
        body,
        depth + 1,
        mod,
        branch_cache,
        ctx,
      )
      let rewritten = TInstr::block(bt, next_body)
      let (optimized, _) = optimize_block(
        rewritten,
        mod,
        OptimizeOptions::new(),
        branch_cache,
        ctx,
      )
      optimized
    }
    TLoop(bt, body) => {
      let next_body = mb_break_value_dropper_expr(
        origin,
        body,
        depth + 1,
        mod,
        branch_cache,
        ctx,
      )
      let rewritten = TInstr::loop_(bt, next_body)
      let (optimized, _) = optimize_block(
        rewritten,
        mod,
        OptimizeOptions::new(),
        branch_cache,
        ctx,
      )
      optimized
    }
    TIf(bt, cond, then_, else_) => {
      let next_cond = mb_break_value_dropper_walk(
        origin, cond, depth, mod, branch_cache, ctx,
      )
      let next_then = mb_break_value_dropper_expr(
        origin,
        then_,
        depth + 1,
        mod,
        branch_cache,
        ctx,
      )
      let next_else = match else_ {
        Some(e) =>
          Some(
            mb_break_value_dropper_expr(
              origin,
              e,
              depth + 1,
              mod,
              branch_cache,
              ctx,
            ),
          )
        None => None
      }
      TInstr::if_(bt, next_cond, next_then, next_else)
    }
    _ => {
      let children = mb_eval_children(expr)
      if children.is_empty() {
        expr
      } else {
        let next_children = []
        for child in children {
          next_children.push(
            mb_break_value_dropper_walk(
              origin, child, depth, mod, branch_cache, ctx,
            ),
          )
        }
        mb_rebuild_non_control(expr, next_children)
      }
    }
  }
}

///|
fn mb_break_value_dropper_expr(
  origin : LabelIdx,
  expr : TExpr,
  depth : Int,
  mod : Module,
  branch_cache : BranchCache,
  ctx : MBContext,
) -> TExpr {
  let out : Array[TInstr] = []
  for instr in expr.0 {
    out.push(
      mb_break_value_dropper_walk(origin, instr, depth, mod, branch_cache, ctx),
    )
  }
  TExpr::new(out)
}

///|
fn optimize_dropped_block(
  drop_instr : TInstr,
  block_instr : TInstr,
  mod : Module,
  options : OptimizeOptions,
  branch_cache : BranchCache,
  ctx : MBContext,
) -> (TInstr, Bool) {
  ignore(options)
  ignore(block_instr)
  let mut next_body = match drop_instr {
    TDrop(TBlock(_, body)) => body
    _ => return (drop_instr, false)
  }
  for instr in next_body.0 {
    match problem_finder(LabelIdx::new(0), instr, mod, options, ctx) {
      ProblemBlocked => return (drop_instr, false)
      ProblemOk => ()
    }
  }
  {
    let rewritten_items : Array[TInstr] = []
    for instr in next_body.0 {
      rewritten_items.push(
        break_value_dropper(
          LabelIdx::new(0),
          instr,
          mod,
          options,
          branch_cache,
          ctx,
        ),
      )
    }
    next_body = TExpr::new(rewritten_items)
  }
  let next_items = next_body.0.copy()
  if !next_items.is_empty() {
    let last = next_items.pop().unwrap()
    next_items.push(mb_drop_or_value(last, ctx.env))
  }
  let rewritten = mb_finalize_block(
    TInstr::block(BlockType::void_(), TExpr::new(next_items)),
    ctx.env,
  )
  let (optimized, _) = optimize_block(
    rewritten, mod, options, branch_cache, ctx,
  )
  (optimized, true)
}

///|
fn mb_prepare_moved_item(item : TInstr, has_after : Bool, env : Env) -> TInstr {
  if has_after && mb_instr_is_concrete(item, env) {
    TInstr::drop(item)
  } else {
    item
  }
}

///|
fn optimize_block(
  block : TInstr,
  mod : Module,
  options : OptimizeOptions,
  branch_cache : BranchCache,
  ctx : MBContext,
) -> (TInstr, Bool) {
  match block {
    TBlock(bt, body) => {
      let curr_items = body.0.copy()
      let mut any_change = false
      let mut rounds = 0
      while rounds < 20 {
        rounds += 1
        let out : Array[TInstr] = []
        let mut round_change = false
        let n = curr_items.length()
        for i = 0; i < curr_items.length(); i = i + 1 {
          let item0 = curr_items[i]
          let (item1, nested_changed) = mb_optimize_instr(
            item0, mod, options, branch_cache, ctx,
          )
          if nested_changed {
            round_change = true
          }
          match item1 {
            TDrop(TBlock(_, _)) => {
              let (rewritten, changed) = optimize_dropped_block(
                item1,
                match item1 {
                  TDrop(inner) => inner
                  _ => item1
                },
                mod,
                options,
                branch_cache,
                ctx,
              )
              if changed {
                out.push(rewritten)
                round_change = true
                continue
              }
            }
            _ => ()
          }
          match item1 {
            TBlock(child_bt, child_body) => {
              if has_dead_code(item1) {
                out.push(item1)
                continue
              }
              let child_items = child_body.0
              let mut split = child_items.length()
              let mut named = false
              for j = 0; j < child_items.length(); j = j + 1 {
                if has_branch(child_items[j], LabelIdx::new(0)) {
                  split = j
                  named = true
                  break
                }
              }
              if named && mb_blocktype_is_concrete(child_bt, ctx.env) {
                out.push(item1)
                continue
              }
              if split == 0 {
                out.push(item1)
                continue
              }
              let mut can_move = true
              for j = 0; j < split; j = j + 1 {
                if mb_has_any_branch(child_items[j]) {
                  can_move = false
                  break
                }
              }
              if !can_move {
                out.push(item1)
                continue
              }
              for j = 0; j < split; j = j + 1 {
                let has_after = j + 1 < split ||
                  split < child_items.length() ||
                  i + 1 < n
                out.push(
                  mb_prepare_moved_item(child_items[j], has_after, ctx.env),
                )
              }
              if split < child_items.length() {
                let rest : Array[TInstr] = []
                for j = split; j < child_items.length(); j = j + 1 {
                  rest.push(child_items[j])
                }
                out.push(
                  mb_finalize_block(
                    TInstr::block(child_bt, TExpr::new(rest)),
                    ctx.env,
                  ),
                )
              }
              round_change = true
              continue
            }
            TLoop(loop_bt, TExpr([TBlock(inner_bt, inner_body)])) => {
              if mb_has_dead_code_in_expr(inner_body) {
                out.push(item1)
                continue
              }
              let inner_items = inner_body.0
              if inner_items.is_empty() {
                out.push(item1)
                continue
              }
              let mut last_back_branch = -1
              for j = 0; j < inner_items.length(); j = j + 1 {
                if mb_has_branch_to_depth(inner_items[j], 1, branch_cache) {
                  last_back_branch = j
                }
              }
              let split = last_back_branch + 1
              if split >= inner_items.length() {
                out.push(item1)
                continue
              }
              if split > 0 && mb_blocktype_is_concrete(loop_bt, ctx.env) {
                out.push(item1)
                continue
              }
              let mut can_move = true
              for j = split; j < inner_items.length(); j = j + 1 {
                if mb_has_branch_to_depth(inner_items[j], 0, branch_cache) ||
                  mb_has_branch_to_depth(inner_items[j], 1, branch_cache) ||
                  mb_has_any_branch(inner_items[j]) {
                  can_move = false
                  break
                }
              }
              if !can_move {
                out.push(item1)
                continue
              }
              let keep : Array[TInstr] = []
              for j = 0; j < split; j = j + 1 {
                keep.push(inner_items[j])
              }
              let updated_loop = TInstr::loop_(
                loop_bt,
                TExpr::new([
                  mb_finalize_block(
                    TInstr::block(inner_bt, TExpr::new(keep)),
                    ctx.env,
                  ),
                ]),
              )
              out.push(updated_loop)
              for j = split; j < inner_items.length(); j = j + 1 {
                let has_after = j + 1 < inner_items.length() || i + 1 < n
                out.push(
                  mb_prepare_moved_item(inner_items[j], has_after, ctx.env),
                )
              }
              round_change = true
              continue
            }
            _ => ()
          }
          let (restructured, restructured_changed) = optimize_expression_restructure(
            item1, mod, options, branch_cache, ctx,
          )
          if restructured_changed {
            out.push(restructured)
            round_change = true
          } else {
            out.push(item1)
          }
        }
        if !round_change {
          break
        }
        any_change = true
        curr_items.clear()
        for item in out {
          curr_items.push(item)
        }
      }
      let finalized = mb_finalize_block(
        TInstr::block(bt, TExpr::new(curr_items)),
        ctx.env,
      )
      (finalized, any_change)
    }
    _ => (block, false)
  }
}

///|
fn mb_optimize_instr(
  instr : TInstr,
  mod : Module,
  options : OptimizeOptions,
  branch_cache : BranchCache,
  ctx : MBContext,
) -> (TInstr, Bool) {
  match instr {
    TBlock(_, _) => optimize_block(instr, mod, options, branch_cache, ctx)
    TLoop(bt, body) => {
      let (next_body, changed) = mb_optimize_texpr(
        body, mod, options, branch_cache, ctx,
      )
      (mb_finalize_block(TInstr::loop_(bt, next_body), ctx.env), changed)
    }
    TTryTable(bt, catches, body) => {
      let (next_body, changed) = mb_optimize_texpr(
        body, mod, options, branch_cache, ctx,
      )
      (
        mb_finalize_block(TInstr::try_table(bt, catches, next_body), ctx.env),
        changed,
      )
    }
    TIf(bt, cond, then_, else_) => {
      let (next_cond, changed_cond) = mb_optimize_instr(
        cond, mod, options, branch_cache, ctx,
      )
      let (next_then, changed_then) = mb_optimize_texpr(
        then_, mod, options, branch_cache, ctx,
      )
      let (next_else, changed_else) = match else_ {
        Some(e) => {
          let (next, changed) = mb_optimize_texpr(
            e, mod, options, branch_cache, ctx,
          )
          (Some(next), changed)
        }
        None => (None, false)
      }
      (
        TInstr::if_(bt, next_cond, next_then, next_else),
        changed_cond || changed_then || changed_else,
      )
    }
    _ => {
      let children = mb_eval_children(instr)
      if children.is_empty() {
        (instr, false)
      } else {
        let next_children = []
        let mut changed = false
        for child in children {
          let (next_child, child_changed) = mb_optimize_instr(
            child, mod, options, branch_cache, ctx,
          )
          if child_changed {
            changed = true
          }
          next_children.push(next_child)
        }
        if changed {
          (mb_rebuild_non_control(instr, next_children), true)
        } else {
          (instr, false)
        }
      }
    }
  }
}

///|
fn mb_optimize_texpr(
  expr : TExpr,
  mod : Module,
  options : OptimizeOptions,
  branch_cache : BranchCache,
  ctx : MBContext,
) -> (TExpr, Bool) {
  let out : Array[TInstr] = []
  let mut changed = false
  for instr in expr.0 {
    let (next, child_changed) = mb_optimize_instr(
      instr, mod, options, branch_cache, ctx,
    )
    if child_changed {
      changed = true
    }
    out.push(next)
  }
  (TExpr::new(out), changed)
}

///|
fn run_on_function(
  func : Func,
  mod : Module,
  options : OptimizeOptions,
) -> (Func, Bool) {
  match func {
    TFunc(locals, body) => {
      let env = Env::new().with_module(mod).with_locals(locals)
      let ctx = MBContext::new(env)
      let root = TInstr::block(BlockType::void_(), body)
      let (next_root, changed) = optimize_block(
        root,
        mod,
        options,
        ctx.branch_cache,
        ctx,
      )
      let next_body = match next_root {
        TBlock(_, b) => b
        _ => body
      }
      let mut final_body = next_body
      if changed {
        final_body = mb_refinalize_texpr(final_body, env)
      }
      if ctx.needs_refinalize {
        final_body = mb_refinalize_texpr(final_body, env)
      }
      if changed || ctx.needs_refinalize {
        (Func::t_func(locals, final_body), true)
      } else {
        (func, false)
      }
    }
    _ => (func, false)
  }
}

///|
fn merge_blocks_ir_pass(
  mod : Module,
  options? : OptimizeOptions = OptimizeOptions::new(),
) -> ModuleTransformer[IRContext] {
  ModuleTransformer::new().on_func_evt(fn(_, ctx, func) {
    let (next_func, changed) = run_on_function(func, mod, options)
    if changed {
      change(ctx, next_func)
    } else {
      unchanged()
    }
  })
}

///|
fn run_merge_blocks(
  mod : Module,
  options? : OptimizeOptions = OptimizeOptions::new(),
) -> Module {
  let pass = merge_blocks_ir_pass(mod, options~)
  match pass.walk_module(IRContext::new(), mod) {
    Ok(Some((_, out))) => out
    _ => mod
  }
}

///|
fn mb_eval_children(instr : TInstr) -> Array[TInstr] {
  match instr {
    // Zero-operand instructions.
    TI32Const(_)
    | TI64Const(_)
    | TF32Const(_)
    | TF64Const(_)
    | TRefNull(_)
    | TRefFunc(_)
    | TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | TUnreachable
    | TNop
    | TLocalGet(_)
    | TGlobalGet(_)
    | TMemorySize(_)
    | TAtomicFence
    | TTableSize(_)
    | TDataDrop(_)
    | TElemDrop(_)
    | TStructNewDefault(_) => []

    // Unary operands.
    TUnary(_, child)
    | TDrop(child)
    | TLocalSet(_, child)
    | TLocalTee(_, child)
    | TGlobalSet(_, child)
    | TRefIsNull(child)
    | TRefAsNonNull(child)
    | TI31GetS(child)
    | TI31GetU(child)
    | TRefI31(child)
    | TArrayLen(child)
    | TAnyConvertExtern(child)
    | TExternConvertAny(child)
    | TThrowRef(child)
    | TMemoryGrow(_, child)
    | TTableGet(_, child)
    | TLoad(_, _, child)
    | TArrayNewDefault(_, child)
    | TStructGet(_, _, child)
    | TStructGetS(_, _, child)
    | TStructGetU(_, _, child)
    | TI8x16Splat(child)
    | TI16x8Splat(child)
    | TI32x4Splat(child)
    | TI64x2Splat(child)
    | TF32x4Splat(child)
    | TF64x2Splat(child)
    | TExtractLane(_, _, child)
    | TRefTest(_, _, child)
    | TRefCast(_, _, child)
    | TRefGetDesc(child)
    | TRefTestDesc(_, _, child)
    | TRefCastDescEq(_, _, child) => [child]

    // Two operands.
    TBinary(_, left, right)
    | TRefEq(left, right)
    | TStore(_, _, left, right)
    | TMemoryAtomicNotify(_, left, right)
    | TAtomicRmw(_, _, left, right)
    | TTableSet(_, left, right)
    | TTableGrow(_, left, right)
    | TStructSet(_, _, left, right)
    | TArrayNew(_, left, right)
    | TArrayNewData(_, _, left, right)
    | TArrayNewElem(_, _, left, right)
    | TArrayGet(_, left, right)
    | TArrayGetS(_, left, right)
    | TArrayGetU(_, left, right)
    | TReplaceLane(_, _, left, right)
    | TI8x16Swizzle(left, right)
    | TI8x16RelaxedSwizzle(left, right)
    | TV128Shift(_, left, right)
    | TV128LoadLane(_, _, _, left, right)
    | TV128StoreLane(_, _, _, left, right) => [left, right]

    // Three operands.
    TMemoryFill(_, a, b, c)
    | TMemoryCopy(_, _, a, b, c)
    | TMemoryInit(_, _, a, b, c)
    | TMemoryAtomicWait32(_, a, b, c)
    | TMemoryAtomicWait64(_, a, b, c)
    | TAtomicCmpxchg(_, _, a, b, c)
    | TTableFill(_, a, b, c)
    | TTableCopy(_, _, a, b, c)
    | TTableInit(_, _, a, b, c)
    | TSelect(_, c, a, b)
    | TV128Ternary(_, a, b, c) => [a, b, c]

    // Variable-length operands.
    TCall(_, args)
    | TReturnCall(_, args)
    | TThrow(_, args)
    | TBr(_, args)
    | TReturn(args)
    | TStructNew(_, args)
    | TArrayNewFixed(_, args) => args.copy()
    TCallIndirect(_, _, args, index) | TReturnCallIndirect(_, _, args, index) => {
      let out = args.copy()
      out.push(index)
      out
    }
    TCallRef(_, args, ref_) | TReturnCallRef(_, args, ref_) => {
      let out = args.copy()
      out.push(ref_)
      out
    }
    TBrIf(_, cond, values) => {
      let out = values.copy()
      out.push(cond)
      out
    }
    TBrTable(_, _, index, values) => {
      let out = values.copy()
      out.push(index)
      out
    }
    TBrOnNull(_, ref_, values)
    | TBrOnNonNull(_, ref_, values)
    | TBrOnCast(_, _, _, _, ref_, values)
    | TBrOnCastFail(_, _, _, _, ref_, values) => {
      let out = values.copy()
      out.push(ref_)
      out
    }
    TArraySet(_, a, b, c) => [a, b, c]
    TArrayFill(_, a, b, c, d) => [a, b, c, d]
    TArrayCopy(_, _, a, b, c, d, e) => [a, b, c, d, e]
    TArrayInitData(_, _, a, b, c, d) => [a, b, c, d]
    TArrayInitElem(_, _, a, b, c, d) => [a, b, c, d]
    TI8x16Shuffle(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, left, right) =>
      [left, right]

    // Control-flow structures are handled directly by control-flow logic.
    TBlock(_, _) | TLoop(_, _) | TIf(_, _, _, _) | TTryTable(_, _, _) => []
  }
}

///|
fn mb_rebuild_non_control(instr : TInstr, children : Array[TInstr]) -> TInstr {
  match instr {
    // Zero-operand instructions.
    TI32Const(_)
    | TI64Const(_)
    | TF32Const(_)
    | TF64Const(_)
    | TRefNull(_)
    | TRefFunc(_)
    | TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | TUnreachable
    | TNop
    | TLocalGet(_)
    | TGlobalGet(_)
    | TMemorySize(_)
    | TAtomicFence
    | TTableSize(_)
    | TDataDrop(_)
    | TElemDrop(_)
    | TStructNewDefault(_) => instr

    // Unary operands.
    TUnary(op, _) => TInstr::unary(op, children[0])
    TDrop(_) => TInstr::drop(children[0])
    TLocalSet(idx, _) => TInstr::local_set(idx, children[0])
    TLocalTee(idx, _) => TInstr::local_tee(idx, children[0])
    TGlobalSet(idx, _) => TInstr::global_set(idx, children[0])
    TRefIsNull(_) => TInstr::ref_is_null(children[0])
    TRefAsNonNull(_) => TInstr::ref_as_non_null(children[0])
    TI31GetS(_) => TInstr::i31_get_s(children[0])
    TI31GetU(_) => TInstr::i31_get_u(children[0])
    TRefI31(_) => TInstr::ref_i31(children[0])
    TArrayLen(_) => TInstr::array_len(children[0])
    TAnyConvertExtern(_) => TInstr::any_convert_extern(children[0])
    TExternConvertAny(_) => TInstr::extern_convert_any(children[0])
    TThrowRef(_) => TInstr::throw_ref(children[0])
    TMemoryGrow(idx, _) => TInstr::memory_grow(idx, children[0])
    TTableGet(idx, _) => TInstr::table_get(idx, children[0])
    TLoad(op, memarg, _) => TInstr::load(op, memarg, children[0])
    TArrayNewDefault(type_idx, _) =>
      TInstr::array_new_default(type_idx, children[0])
    TStructGet(type_idx, field_idx, _) =>
      TInstr::struct_get(type_idx, field_idx, children[0])
    TStructGetS(type_idx, field_idx, _) =>
      TInstr::struct_get_s(type_idx, field_idx, children[0])
    TStructGetU(type_idx, field_idx, _) =>
      TInstr::struct_get_u(type_idx, field_idx, children[0])
    TI8x16Splat(_) => TInstr::i8x16_splat(children[0])
    TI16x8Splat(_) => TInstr::i16x8_splat(children[0])
    TI32x4Splat(_) => TInstr::i32x4_splat(children[0])
    TI64x2Splat(_) => TInstr::i64x2_splat(children[0])
    TF32x4Splat(_) => TInstr::f32x4_splat(children[0])
    TF64x2Splat(_) => TInstr::f64x2_splat(children[0])
    TExtractLane(op, lane, _) => TInstr::extract_lane(op, lane, children[0])
    TRefTest(nullable, ht, _) => TInstr::ref_test(nullable, ht, children[0])
    TRefCast(nullable, ht, _) => TInstr::ref_cast(nullable, ht, children[0])
    TRefGetDesc(_) => TInstr::ref_get_desc(children[0])
    TRefTestDesc(nullable, ht, _) =>
      TInstr::ref_test_desc(nullable, ht, children[0])
    TRefCastDescEq(nullable, ht, _) =>
      TInstr::ref_cast_desc_eq(nullable, ht, children[0])

    // Two operands.
    TBinary(op, _, _) => TInstr::binary(op, children[0], children[1])
    TRefEq(_, _) => TInstr::ref_eq(children[0], children[1])
    TStore(op, memarg, _, _) =>
      TInstr::store(op, memarg, children[0], children[1])
    TMemoryAtomicNotify(memarg, _, _) =>
      TInstr::memory_atomic_notify(memarg, children[0], children[1])
    TAtomicRmw(op, memarg, _, _) =>
      TInstr::atomic_rmw(op, memarg, children[0], children[1])
    TTableSet(table_idx, _, _) =>
      TInstr::table_set(table_idx, children[0], children[1])
    TTableGrow(table_idx, _, _) =>
      TInstr::table_grow(table_idx, children[0], children[1])
    TStructSet(type_idx, field_idx, _, _) =>
      TInstr::struct_set(type_idx, field_idx, children[0], children[1])
    TArrayNew(type_idx, _, _) =>
      TInstr::array_new(type_idx, children[0], children[1])
    TArrayNewData(type_idx, data_idx, _, _) =>
      TInstr::array_new_data(type_idx, data_idx, children[0], children[1])
    TArrayNewElem(type_idx, elem_idx, _, _) =>
      TInstr::array_new_elem(type_idx, elem_idx, children[0], children[1])
    TArrayGet(type_idx, _, _) =>
      TInstr::array_get(type_idx, children[0], children[1])
    TArrayGetS(type_idx, _, _) =>
      TInstr::array_get_s(type_idx, children[0], children[1])
    TArrayGetU(type_idx, _, _) =>
      TInstr::array_get_u(type_idx, children[0], children[1])
    TReplaceLane(op, lane, _, _) =>
      TInstr::replace_lane(op, lane, children[0], children[1])
    TI8x16Swizzle(_, _) => TInstr::i8x16_swizzle(children[0], children[1])
    TI8x16RelaxedSwizzle(_, _) =>
      TInstr::i8x16_relaxed_swizzle(children[0], children[1])
    TV128Shift(op, _, _) => TInstr::v128_shift(op, children[0], children[1])
    TV128LoadLane(op, memarg, lane, _, _) =>
      TInstr::v128_load_lane(op, memarg, lane, children[0], children[1])
    TV128StoreLane(op, memarg, lane, _, _) =>
      TInstr::v128_store_lane(op, memarg, lane, children[0], children[1])

    // Three operands.
    TMemoryFill(mem_idx, _, _, _) =>
      TInstr::memory_fill(mem_idx, children[0], children[1], children[2])
    TMemoryCopy(dst, src, _, _, _) =>
      TInstr::memory_copy(dst, src, children[0], children[1], children[2])
    TMemoryInit(data_idx, mem_idx, _, _, _) =>
      TInstr::memory_init(
        data_idx,
        mem_idx,
        children[0],
        children[1],
        children[2],
      )
    TMemoryAtomicWait32(memarg, _, _, _) =>
      TInstr::memory_atomic_wait32(
        memarg,
        children[0],
        children[1],
        children[2],
      )
    TMemoryAtomicWait64(memarg, _, _, _) =>
      TInstr::memory_atomic_wait64(
        memarg,
        children[0],
        children[1],
        children[2],
      )
    TAtomicCmpxchg(op, memarg, _, _, _) =>
      TInstr::atomic_cmpxchg(op, memarg, children[0], children[1], children[2])
    TTableFill(table_idx, _, _, _) =>
      TInstr::table_fill(table_idx, children[0], children[1], children[2])
    TTableCopy(dst, src, _, _, _) =>
      TInstr::table_copy(dst, src, children[0], children[1], children[2])
    TTableInit(elem_idx, table_idx, _, _, _) =>
      TInstr::table_init(
        elem_idx,
        table_idx,
        children[0],
        children[1],
        children[2],
      )
    TSelect(types, _, _, _) =>
      TInstr::select(types, children[2], children[0], children[1])
    TV128Ternary(op, _, _, _) =>
      TInstr::v128_ternary(op, children[0], children[1], children[2])

    // Variable-length operands.
    TCall(func_idx, args) => {
      let rebuilt = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt.push(children[i])
      }
      TInstr::call(func_idx, rebuilt)
    }
    TReturnCall(func_idx, args) => {
      let rebuilt = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt.push(children[i])
      }
      TInstr::return_call(func_idx, rebuilt)
    }
    TThrow(tag_idx, args) => {
      let rebuilt = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt.push(children[i])
      }
      TInstr::throw_(tag_idx, rebuilt)
    }
    TBr(label_idx, args) => {
      let rebuilt = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt.push(children[i])
      }
      TInstr::br(label_idx, rebuilt)
    }
    TReturn(args) => {
      let rebuilt = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt.push(children[i])
      }
      TInstr::return_(rebuilt)
    }
    TStructNew(type_idx, args) => {
      let rebuilt = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt.push(children[i])
      }
      TInstr::struct_new(type_idx, rebuilt)
    }
    TArrayNewFixed(type_idx, args) => {
      let rebuilt = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt.push(children[i])
      }
      TInstr::array_new_fixed(type_idx, rebuilt)
    }
    TCallIndirect(type_idx, table_idx, args, _) => {
      let rebuilt_args = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt_args.push(children[i])
      }
      TInstr::call_indirect(
        type_idx,
        table_idx,
        rebuilt_args,
        children[args.length()],
      )
    }
    TReturnCallIndirect(type_idx, table_idx, args, _) => {
      let rebuilt_args = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt_args.push(children[i])
      }
      TInstr::return_call_indirect(
        type_idx,
        table_idx,
        rebuilt_args,
        children[args.length()],
      )
    }
    TCallRef(type_idx, args, _) => {
      let rebuilt_args = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt_args.push(children[i])
      }
      TInstr::call_ref(type_idx, rebuilt_args, children[args.length()])
    }
    TReturnCallRef(type_idx, args, _) => {
      let rebuilt_args = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt_args.push(children[i])
      }
      TInstr::return_call_ref(type_idx, rebuilt_args, children[args.length()])
    }
    TBrIf(label_idx, _, values) => {
      let rebuilt_values = []
      for i = 0; i < values.length(); i = i + 1 {
        rebuilt_values.push(children[i])
      }
      TInstr::br_if(label_idx, children[values.length()], rebuilt_values)
    }
    TBrTable(labels, default, _, values) => {
      let rebuilt_values = []
      for i = 0; i < values.length(); i = i + 1 {
        rebuilt_values.push(children[i])
      }
      TInstr::br_table(
        labels,
        default,
        children[values.length()],
        rebuilt_values,
      )
    }
    TBrOnNull(label_idx, _, values) => {
      let rebuilt_values = []
      for i = 0; i < values.length(); i = i + 1 {
        rebuilt_values.push(children[i])
      }
      TInstr::br_on_null(label_idx, children[values.length()], rebuilt_values)
    }
    TBrOnNonNull(label_idx, _, values) => {
      let rebuilt_values = []
      for i = 0; i < values.length(); i = i + 1 {
        rebuilt_values.push(children[i])
      }
      TInstr::br_on_non_null(
        label_idx,
        children[values.length()],
        rebuilt_values,
      )
    }
    TBrOnCast(label_idx, castop, ht1, ht2, _, values) => {
      let rebuilt_values = []
      for i = 0; i < values.length(); i = i + 1 {
        rebuilt_values.push(children[i])
      }
      TInstr::br_on_cast(
        label_idx,
        castop.0,
        ht1,
        castop.1,
        ht2,
        children[values.length()],
        rebuilt_values,
      )
    }
    TBrOnCastFail(label_idx, castop, ht1, ht2, _, values) => {
      let rebuilt_values = []
      for i = 0; i < values.length(); i = i + 1 {
        rebuilt_values.push(children[i])
      }
      TInstr::br_on_cast_fail(
        label_idx,
        castop.0,
        ht1,
        castop.1,
        ht2,
        children[values.length()],
        rebuilt_values,
      )
    }
    TArraySet(type_idx, _, _, _) =>
      TInstr::array_set(type_idx, children[0], children[1], children[2])
    TArrayFill(type_idx, _, _, _, _) =>
      TInstr::array_fill(
        type_idx,
        children[0],
        children[1],
        children[2],
        children[3],
      )
    TArrayCopy(dst_type, src_type, _, _, _, _, _) =>
      TInstr::array_copy(
        dst_type,
        src_type,
        children[0],
        children[1],
        children[2],
        children[3],
        children[4],
      )
    TArrayInitData(type_idx, data_idx, _, _, _, _) =>
      TInstr::array_init_data(
        type_idx,
        data_idx,
        children[0],
        children[1],
        children[2],
        children[3],
      )
    TArrayInitElem(type_idx, elem_idx, _, _, _, _) =>
      TInstr::array_init_elem(
        type_idx,
        elem_idx,
        children[0],
        children[1],
        children[2],
        children[3],
      )
    TI8x16Shuffle(
      l0,
      l1,
      l2,
      l3,
      l4,
      l5,
      l6,
      l7,
      l8,
      l9,
      l10,
      l11,
      l12,
      l13,
      l14,
      l15,
      _,
      _
    ) =>
      TInstr::i8x16_shuffle(
        l0,
        l1,
        l2,
        l3,
        l4,
        l5,
        l6,
        l7,
        l8,
        l9,
        l10,
        l11,
        l12,
        l13,
        l14,
        l15,
        children[0],
        children[1],
      )

    // Control-flow structures are rebuilt in dedicated handlers.
    TBlock(_, _) | TLoop(_, _) | TIf(_, _, _, _) | TTryTable(_, _, _) => instr
  }
}

///|
fn mb_make_test_module_with_body(
  locals : Array[ValType],
  body : TExpr,
  results? : Array[ValType] = [],
) -> Module {
  Module::new()
  .with_type_sec(
    TypeSec::new([
      single_rec_type(comp_type_sub_type(func_comp_type([], results))),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  .with_code_sec(CodeSec::new([Func::t_func(locals, body)]))
}

///|
fn mb_extract_only_tfunc(mod : Module) -> Func? {
  match mod.code_sec {
    Some(CodeSec([func])) => Some(func)
    _ => None
  }
}

///|
fn mb_run_on_body(body : TExpr, locals? : Array[ValType] = []) -> TExpr {
  let mod = mb_make_test_module_with_body(locals, body)
  let out = run_merge_blocks(mod)
  match mb_extract_only_tfunc(out) {
    Some(TFunc(_, new_body)) => new_body
    _ => body
  }
}

///|
test "merge blocks: nested unnamed block fully merges" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::i32_const(I32(1)),
        TInstr::drop(TInstr::i32_const(I32(2))),
      ]),
    ),
  ])
  let out = mb_run_on_body(body)
  match out.0 {
    [TDrop(TI32Const(I32(1))), TDrop(TI32Const(I32(2)))] => ()
    _ => fail("expected child block to merge into parent")
  }
}

///|
test "merge blocks: converges through two-level nesting" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([TInstr::i32_const(I32(3))]),
        ),
      ]),
    ),
  ])
  let out = mb_run_on_body(body)
  match out.0 {
    [TI32Const(I32(3))] => ()
    _ => fail("expected full convergence")
  }
}

///|
test "merge blocks: concrete moved to middle gets drop" {
  let body = TExpr::new([
    TInstr::block(BlockType::void_(), TExpr::new([TInstr::i32_const(I32(4))])),
    TInstr::nop(),
  ])
  let out = mb_run_on_body(body)
  match out.0 {
    [TDrop(TI32Const(I32(4))), TNop] => ()
    _ => fail("expected concrete merged value to be dropped in middle")
  }
}

///|
test "merge blocks: named child only merges prefix before branch" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::i32_const(I32(7)),
        TInstr::br_if(LabelIdx::new(0), TInstr::i32_const(I32(1)), []),
        TInstr::i32_const(I32(9)),
      ]),
    ),
  ])
  let out = mb_run_on_body(body)
  match out.0 {
    [
      first,
      TBlock(
        VoidBlockType,
        TExpr([TBrIf(LabelIdx(target), _, []), TI32Const(I32(9))])
      ),
    ] => {
      match first {
        TI32Const(I32(7)) | TDrop(TI32Const(I32(7))) => ()
        _ => fail("expected merged prefix value")
      }
      assert_eq(target.reinterpret_as_int(), 0)
    }
    _ => fail("expected partial merge before first self-branch: \{out}")
  }
}

///|
test "merge blocks: named concrete child not merged" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::val_type(ValType::i32()),
      TExpr::new([
        TInstr::br(LabelIdx::new(0), [TInstr::i32_const(I32(1))]),
        TInstr::i32_const(I32(2)),
      ]),
    ),
  ])
  let out = mb_run_on_body(body)
  assert_eq(out, body)
}

///|
test "merge blocks: loop tail merge moves non-branching suffix outward" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::br_if(LabelIdx::new(1), TInstr::i32_const(I32(0)), []),
                TInstr::call(FuncIdx::new(0), []),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  ])
  let mod = mb_make_test_module_with_body([], body)
  let out = run_merge_blocks(mod)
  match mb_extract_only_tfunc(out) {
    Some(
      TFunc(
        _,
        TExpr(
          [
            TBlock(
              _,
              TExpr(
                [
                  TLoop(_, TExpr([TBlock(_, TExpr([TBrIf(_, _, [])]))])),
                  TCall(_, []),
                ]
              )
            ),
          ]
        )
      )
    ) => ()
    _ => fail("expected loop tail instruction moved outward")
  }
}

///|
test "merge blocks: loop tail blocked when last item branches to loop" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::i32_const(I32(1)),
                TInstr::br_if(LabelIdx::new(1), TInstr::i32_const(I32(0)), []),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  ])
  let out = mb_run_on_body(body)
  assert_eq(out, body)
}

///|
test "merge blocks: loop partial merge with concrete loop value is skipped" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::br_if(LabelIdx::new(1), TInstr::i32_const(I32(0)), []),
                TInstr::i32_const(I32(11)),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  ])
  let out = mb_run_on_body(body)
  assert_eq(out, body)
}

///|
test "merge blocks: dropped block pushes drop inward" {
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::call(FuncIdx::new(0), []),
          TInstr::i32_const(I32(1)),
        ]),
      ),
    ),
  ])
  let mod = mb_make_test_module_with_body([], body)
  let out = run_merge_blocks(mod)
  match mb_extract_only_tfunc(out) {
    Some(TFunc(_, TExpr([TCall(_, []), TDrop(TI32Const(I32(1)))]))) => ()
    _ => fail("expected drop moved inside block")
  }
}

///|
test "merge blocks: named dropped block removes break values when safe" {
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::br(LabelIdx::new(0), [TInstr::i32_const(I32(5))]),
          TInstr::i32_const(I32(7)),
        ]),
      ),
    ),
  ])
  let out = mb_run_on_body(body)
  let mut saw_value_br = false
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TBr(_, values) if !values.is_empty() => saw_value_br = true
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), out))
  assert_false(saw_value_br)
}

///|
test "merge blocks: problem finder blocks side-effecting br value" {
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::br(LabelIdx::new(0), [TInstr::call(FuncIdx::new(0), [])]),
          TInstr::i32_const(I32(0)),
        ]),
      ),
    ),
  ])
  let out = mb_run_on_body(body)
  assert_eq(out, body)
}

///|
test "merge blocks: problem finder blocks br_if mismatch" {
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::br_if(LabelIdx::new(0), TInstr::i32_const(I32(1)), [
            TInstr::i32_const(I32(3)),
          ]),
          TInstr::i32_const(I32(4)),
        ]),
      ),
    ),
  ])
  let out = mb_run_on_body(body)
  assert_eq(out, body)
}

///|
test "merge blocks: problem finder blocks unsupported br_table target" {
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::br_table(
            [LabelIdx::new(0)],
            LabelIdx::new(0),
            TInstr::i32_const(I32(0)),
            [TInstr::i32_const(I32(1))],
          ),
          TInstr::i32_const(I32(9)),
        ]),
      ),
    ),
  ])
  let out = mb_run_on_body(body)
  assert_eq(out, body)
}

///|
test "merge blocks: try_table catch_all_ref targeting origin is allowed" {
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::try_table(
            BlockType::void_(),
            [Catch::all_ref(LabelIdx::new(1))],
            TExpr::new([TInstr::nop()]),
          ),
          TInstr::i32_const(I32(10)),
        ]),
      ),
    ),
  ])
  let out = mb_run_on_body(body)
  let mut saw_ref_catch = false
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TTryTable(_, catches, _) =>
        for catch_ in catches {
          match catch_ {
            CatchAllRef(_) | CatchRef(_, _) => saw_ref_catch = true
            _ => ()
          }
        }
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), out))
  assert_false(saw_ref_catch)
}

///|
test "merge blocks: try_table catch_ref with params blocks optimization" {
  let tag_type = TagType::new(TypeIdx::new(0))
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::try_table(
            BlockType::void_(),
            [Catch::ref_(TagIdx::new(0), LabelIdx::new(1))],
            TExpr::new([TInstr::nop()]),
          ),
          TInstr::i32_const(I32(1)),
        ]),
      ),
    ),
  ])
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        single_rec_type(
          comp_type_sub_type(func_comp_type([ValType::i32()], [])),
        ),
        single_rec_type(comp_type_sub_type(func_comp_type([], []))),
      ]),
    )
    .with_tag_sec(TagSec::new([tag_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([Func::t_func([], body)]))
  let out = run_merge_blocks(mod)
  assert_eq(out, mod)
}

///|
test "merge blocks: restructure pulls operand block outward with effect checks" {
  let body = TExpr::new([
    TInstr::drop(
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::drop(TInstr::i32_const(I32(1))),
            TInstr::i32_const(I32(2)),
          ]),
        ),
        TInstr::i32_const(I32(3)),
      ),
    ),
  ])
  let out = mb_run_on_body(body)
  let mut wrapped = false
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TBlock(_, TExpr(items)) if items.length() >= 2 => wrapped = true
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), out))
  assert_true(wrapped)
}

///|
test "merge blocks: second operand pull blocked by effect invalidation" {
  let body = TExpr::new([
    TInstr::drop(
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::call(FuncIdx::new(0), []),
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::call(FuncIdx::new(0), []),
            TInstr::i32_const(I32(2)),
          ]),
        ),
      ),
    ),
  ])
  let out = mb_run_on_body(body)
  assert_eq(out, body)
}

///|
test "merge blocks: transformed output stays typable and pass is idempotent" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::drop(
          TInstr::block(
            BlockType::val_type(ValType::i32()),
            TExpr::new([TInstr::i32_const(I32(1)), TInstr::i32_const(I32(2))]),
          ),
        ),
      ]),
    ),
  ])
  let mod = mb_make_test_module_with_body([], body)
  let out = run_merge_blocks(mod)
  match mb_extract_only_tfunc(out) {
    Some(TFunc(locals, texpr)) => {
      let env = Env::new().with_module(out).with_locals(locals)
      let lowered = texpr.to_expr()
      match to_texpr(lowered, env) {
        Ok(_) => ()
        Err(e) => fail("expected typable output, got: \{e}")
      }
    }
    _ => fail("expected tfunc")
  }
  let once = run_merge_blocks(mod)
  let twice = run_merge_blocks(once)
  assert_eq(once, twice)
}
