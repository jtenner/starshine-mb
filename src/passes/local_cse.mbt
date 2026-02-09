///|
priv struct HashedExpression {
  id : Int
  digest : UInt64
}

///|
priv struct RequestInfo {
  original : Int
  requests : Int
}

///|
priv struct Scanner {
  env : Env
  shrink_level : Int
  mut next_id : Int
  node_instrs : Array[TInstr]
  node_digests : Array[UInt64]
  node_children : Array[Array[Int]]
  request_infos : Array[RequestInfo?]
}

///|
fn Scanner::new(env : Env, shrink_level : Int) -> Scanner {
  {
    env,
    shrink_level,
    next_id: 0,
    node_instrs: [],
    node_digests: [],
    node_children: [],
    request_infos: [],
  }
}

///|
priv struct LCSActiveOriginal {
  requests_left : Int
  effects : LCSEffects
}

///|
priv struct Checker {
  mut next_id : Int
  request_infos : Array[RequestInfo?]
}

///|
fn Checker::new(request_infos : Array[RequestInfo?]) -> Checker {
  { next_id: 0, request_infos }
}

///|
priv struct Applier {
  env : Env
  node_instrs : Array[TInstr]
  request_infos : Array[RequestInfo?]
  mut next_id : Int
  locals : Array[ValType]
  mut original_to_local : Map[Int, LocalIdx]
  mut changed : Bool
}

///|
fn Applier::new(
  env : Env,
  node_instrs : Array[TInstr],
  request_infos : Array[RequestInfo?],
  locals : Array[ValType],
) -> Applier {
  {
    env,
    node_instrs,
    request_infos,
    next_id: 0,
    locals,
    original_to_local: Map::new(),
    changed: false,
  }
}

///|
priv struct LCSEffects {
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
fn LCSEffects::new() -> LCSEffects {
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
fn LCSEffects::invalidates(self : LCSEffects, other : LCSEffects) -> Bool {
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
fn LCSEffects::transfers_control_flow(self : LCSEffects) -> Bool {
  self.branches || self.throws
}

///|
fn LCSEffects::has_unremovable_side_effects(self : LCSEffects) -> Bool {
  self.writes_memory ||
  self.writes_globals ||
  self.calls ||
  self.branches ||
  self.throws ||
  self.traps ||
  self.locals_written.length() > 0
}

///|
fn lcs_collect_effects(instr : TInstr) -> LCSEffects {
  let effects = LCSEffects::new()
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    lcs_collect_shallow_effects_into(curr, effects)
    self.walk_tinstruction_default((), curr)
  })
  ignore(walker.walk_tinstruction((), instr))
  effects
}

///|
fn lcs_collect_shallow_effects(instr : TInstr) -> LCSEffects {
  let effects = LCSEffects::new()
  lcs_collect_shallow_effects_into(instr, effects)
  effects
}

///|
fn lcs_collect_shallow_effects_into(
  instr : TInstr,
  effects : LCSEffects,
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
    TArrayNew(_, _, _)
    | TArrayNewDefault(_, _)
    | TArrayNewFixed(_, _)
    | TArrayNewData(_, _, _, _)
    | TArrayNewElem(_, _, _, _) => {
      effects.writes_memory = true
      effects.traps = true
    }
    TArrayGet(_, _, _)
    | TArrayGetS(_, _, _)
    | TArrayGetU(_, _, _)
    | TArrayLen(_) => {
      effects.reads_memory = true
      effects.traps = true
    }
    TArraySet(_, _, _, _)
    | TArrayFill(_, _, _, _, _)
    | TArrayCopy(_, _, _, _, _, _, _)
    | TArrayInitData(_, _, _, _, _, _)
    | TArrayInitElem(_, _, _, _, _, _) => {
      effects.reads_memory = true
      effects.writes_memory = true
      effects.traps = true
    }
    TBinary(op, _, _) =>
      match op {
        I32DivSOp
        | I32DivUOp
        | I32RemSOp
        | I32RemUOp
        | I64DivSOp
        | I64DivUOp
        | I64RemSOp
        | I64RemUOp => effects.traps = true
        _ => ()
      }
    TUnary(op, _) =>
      match op {
        I32TruncF32SOp
        | I32TruncF32UOp
        | I32TruncF64SOp
        | I32TruncF64UOp
        | I64TruncF32SOp
        | I64TruncF32UOp
        | I64TruncF64SOp
        | I64TruncF64UOp => effects.traps = true
        _ => ()
      }
    _ => ()
  }
}

///|
fn lcs_has_shallow_nontrap_side_effects(instr : TInstr) -> Bool {
  let effects = lcs_collect_shallow_effects(instr)
  effects.traps = false
  effects.writes_memory ||
  effects.writes_globals ||
  effects.calls ||
  effects.branches ||
  effects.throws ||
  effects.locals_written.length() > 0
}

///|
fn lcs_is_shallowly_generative(instr : TInstr) -> Bool {
  match instr {
    TStructNew(_, _)
    | TStructNewDefault(_)
    | TArrayNew(_, _, _)
    | TArrayNewDefault(_, _)
    | TArrayNewFixed(_, _)
    | TArrayNewData(_, _, _, _)
    | TArrayNewElem(_, _, _, _) => true
    _ => false
  }
}

///|
fn lcs_is_possible(instr : TInstr) -> Bool {
  !lcs_has_shallow_nontrap_side_effects(instr) &&
  !lcs_is_shallowly_generative(instr)
}

///|
fn lcs_is_constant_instr(instr : TInstr) -> Bool {
  match instr {
    TI32Const(_)
    | TI64Const(_)
    | TF32Const(_)
    | TF64Const(_)
    | TRefNull(_)
    | TRefFunc(_)
    | TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) => true
    _ => false
  }
}

///|
fn lcs_is_non_linear_boundary(instr : TInstr) -> Bool {
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
fn lcs_measure_texpr(expr : TExpr) -> Int {
  let mut total = 0
  for instr in expr.0 {
    total += lcs_measure(instr)
  }
  total
}

///|
fn lcs_measure(instr : TInstr) -> Int {
  let mut total = 1
  match instr {
    TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) =>
      total += lcs_measure_texpr(body)
    TIf(_, cond, then_, else_) => {
      total += lcs_measure(cond)
      total += lcs_measure_texpr(then_)
      match else_ {
        Some(other) => total += lcs_measure_texpr(other)
        None => ()
      }
    }
    _ =>
      for child in eval_children(instr) {
        total += lcs_measure(child)
      }
  }
  total
}

///|
fn lcs_cost(instr : TInstr) -> Int {
  match instr {
    TI32Const(_)
    | TI64Const(_)
    | TF32Const(_)
    | TF64Const(_)
    | TRefNull(_)
    | TRefFunc(_)
    | TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | TLocalGet(_)
    | TGlobalGet(_)
    | TNop
    | TUnreachable => 0
    _ => 1
  }
}

///|
fn lcs_can_handle_as_local(vt : ValType) -> Bool {
  match vt {
    NumTypeValType(_) | VecTypeValType(_) | RefTypeValType(_) => true
    _ => false
  }
}

///|
fn lcs_unary_result_type(op : UnaryOp, operand_ty : ValType?) -> ValType? {
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
fn lcs_binary_result_type(op : BinaryOp, lhs_ty : ValType?) -> ValType? {
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
fn lcs_load_result_type(op : LoadOp) -> ValType {
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
fn lcs_ref_func_type(fi : FuncIdx, env : Env) -> ValType {
  match env.get_functype_by_funcidx(fi) {
    Some(_) => ValType::funcref()
    None => ValType::funcref()
  }
}

///|
fn lcs_infer_tinstr_type(instr : TInstr, env : Env) -> ValType? {
  fn single_result_of_blocktype(bt : BlockType, env : Env) -> ValType? {
    match env.expand_blocktype(bt) {
      Ok((_, [vt])) => Some(vt)
      _ => None
    }
  }

  fn infer_texpr_type(texpr : TExpr, env : Env) -> ValType? {
    let TExpr(instrs) = texpr
    if instrs.is_empty() {
      None
    } else {
      lcs_infer_tinstr_type(instrs[instrs.length() - 1], env)
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
    TRefFunc(fi) => Some(lcs_ref_func_type(fi, env))
    TLocalGet(idx) => env.get_local_type(idx)
    TGlobalGet(idx) =>
      match env.get_global_type(idx) {
        Some(GlobalType(vt, _)) => Some(vt)
        None => None
      }
    TLocalTee(_, value) => lcs_infer_tinstr_type(value, env)
    TUnary(op, value) =>
      lcs_unary_result_type(op, lcs_infer_tinstr_type(value, env))
    TBinary(op, lhs, _) =>
      lcs_binary_result_type(op, lcs_infer_tinstr_type(lhs, env))
    TRefEq(_, _) | TRefIsNull(_) | TRefTest(_, _, _) => Some(ValType::i32())
    TLoad(op, _, _) => Some(lcs_load_result_type(op))
    TMemorySize(_) | TTableSize(_) => Some(ValType::i32())
    TRefAsNonNull(value) =>
      match lcs_infer_tinstr_type(value, env) {
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
          lcs_infer_tinstr_type(if_true, env),
          lcs_infer_tinstr_type(if_false, env),
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
      match (infer_texpr_type(body, env), single_result_of_blocktype(bt, env)) {
        (Some(t), _) => Some(t)
        (_, Some(vt)) => Some(vt)
        _ => None
      }
    TIf(bt, _, then_, else_) => {
      let from_bt = single_result_of_blocktype(bt, env)
      let from_branches = match else_ {
        Some(else_expr) =>
          match
            (infer_texpr_type(then_, env), infer_texpr_type(else_expr, env)) {
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
fn lcs_is_relevant(instr : TInstr, env : Env, shrink_level : Int) -> Bool {
  if lcs_is_constant_instr(instr) {
    return false
  }
  match instr {
    TLocalGet(_) | TLocalSet(_, _) => return false
    _ => ()
  }
  let vt = match lcs_infer_tinstr_type(instr, env) {
    Some(vt) => vt
    None => return false
  }
  if !lcs_can_handle_as_local(vt) {
    return false
  }
  let size = lcs_measure(instr)
  if shrink_level > 0 {
    return size >= 3
  }
  lcs_cost(instr) > 0 && size >= 2
}

///|
fn lcs_shallow_hash(instr : TInstr) -> UInt64 {
  let tag : UInt64 = match instr {
    TI32Const(_) => 1UL
    TI64Const(_) => 2UL
    TF32Const(_) => 3UL
    TF64Const(_) => 4UL
    TRefNull(_) => 5UL
    TRefFunc(_) => 6UL
    TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) => 7UL
    TUnreachable => 8UL
    TNop => 9UL
    TLocalGet(_) => 10UL
    TGlobalGet(_) => 11UL
    TMemorySize(_) => 12UL
    TTableSize(_) => 13UL
    TUnary(_, _) => 14UL
    TDrop(_) => 15UL
    TLocalSet(_, _) => 16UL
    TLocalTee(_, _) => 17UL
    TGlobalSet(_, _) => 18UL
    TRefIsNull(_) => 19UL
    TRefAsNonNull(_) => 20UL
    TI31GetS(_) => 21UL
    TI31GetU(_) => 22UL
    TRefI31(_) => 23UL
    TArrayLen(_) => 24UL
    TAnyConvertExtern(_) => 25UL
    TExternConvertAny(_) => 26UL
    TThrowRef(_) => 27UL
    TBinary(_, _, _) => 28UL
    TRefEq(_, _) => 29UL
    TStore(_, _, _, _) => 30UL
    TLoad(_, _, _) => 31UL
    TMemoryGrow(_, _) => 32UL
    TMemoryFill(_, _, _, _) => 33UL
    TMemoryCopy(_, _, _, _, _) => 34UL
    TMemoryInit(_, _, _, _, _) => 35UL
    TDataDrop(_) => 36UL
    TTableGet(_, _) => 37UL
    TTableSet(_, _, _) => 38UL
    TTableGrow(_, _, _) => 39UL
    TTableFill(_, _, _, _) => 40UL
    TTableCopy(_, _, _, _, _) => 41UL
    TTableInit(_, _, _, _, _) => 42UL
    TElemDrop(_) => 43UL
    TCall(_, _) => 44UL
    TCallIndirect(_, _, _, _) => 45UL
    TCallRef(_, _, _) => 46UL
    TReturnCall(_, _) => 47UL
    TReturnCallIndirect(_, _, _, _) => 48UL
    TReturnCallRef(_, _, _) => 49UL
    TBlock(_, _) => 50UL
    TLoop(_, _) => 51UL
    TIf(_, _, _, _) => 52UL
    TTryTable(_, _, _) => 53UL
    TThrow(_, _) => 54UL
    TBr(_, _) => 55UL
    TBrIf(_, _, _) => 56UL
    TBrTable(_, _, _, _) => 57UL
    TBrOnNull(_, _, _) => 58UL
    TBrOnNonNull(_, _, _) => 59UL
    TBrOnCast(_, _, _, _, _, _) => 60UL
    TBrOnCastFail(_, _, _, _, _, _) => 61UL
    TReturn(_) => 62UL
    TSelect(_, _, _, _) => 63UL
    TStructNew(_, _) => 64UL
    TStructNewDefault(_) => 65UL
    TStructGet(_, _, _) => 66UL
    TStructGetS(_, _, _) => 67UL
    TStructGetU(_, _, _) => 68UL
    TStructSet(_, _, _, _) => 69UL
    TArrayNew(_, _, _) => 70UL
    TArrayNewDefault(_, _) => 71UL
    TArrayNewFixed(_, _) => 72UL
    TArrayNewData(_, _, _, _) => 73UL
    TArrayNewElem(_, _, _, _) => 74UL
    TArrayGet(_, _, _) => 75UL
    TArrayGetS(_, _, _) => 76UL
    TArrayGetU(_, _, _) => 77UL
    TArraySet(_, _, _, _) => 78UL
    TArrayFill(_, _, _, _, _) => 79UL
    TArrayCopy(_, _, _, _, _, _, _) => 80UL
    TArrayInitData(_, _, _, _, _, _) => 81UL
    TArrayInitElem(_, _, _, _, _, _) => 82UL
    TRefTest(_, _, _) => 83UL
    TRefCast(_, _, _) => 84UL
    TI8x16Splat(_) => 85UL
    TI16x8Splat(_) => 86UL
    TI32x4Splat(_) => 87UL
    TI64x2Splat(_) => 88UL
    TF32x4Splat(_) => 89UL
    TF64x2Splat(_) => 90UL
    TExtractLane(_, _, _) => 91UL
    TReplaceLane(_, _, _, _) => 92UL
    TI8x16Shuffle(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) => 93UL
    TI8x16Swizzle(_, _) => 94UL
    TI8x16RelaxedSwizzle(_, _) => 95UL
    TV128Shift(_, _, _) => 96UL
    TV128Ternary(_, _, _, _) => 97UL
    TV128LoadLane(_, _, _, _, _) => 98UL
    TV128StoreLane(_, _, _, _, _) => 99UL
  }
  tag * 11400714819323198485UL
}

///|
fn lcs_digest(instr : TInstr, child_digests : Array[UInt64]) -> UInt64 {
  let mut digest = lcs_shallow_hash(instr)
  for child_digest in child_digests {
    digest = (digest ^ child_digest) * 1099511628211UL
  }
  digest
}

///|
fn lcs_scanner_suppress_child(scanner : Scanner, child_id : Int) -> Unit {
  if child_id < 0 || child_id >= scanner.request_infos.length() {
    return
  }
  match scanner.request_infos[child_id] {
    None => ()
    Some(info) => {
      let original_id = info.original
      if original_id == child_id {
        let next_requests = info.requests - 1
        if next_requests <= 0 {
          scanner.request_infos[child_id] = None
        } else {
          scanner.request_infos[child_id] = Some({
            original: original_id,
            requests: next_requests,
          })
        }
      } else {
        scanner.request_infos[child_id] = None
        if original_id >= 0 && original_id < scanner.request_infos.length() {
          match scanner.request_infos[original_id] {
            Some(orig_info) => {
              let next_requests = orig_info.requests - 1
              if next_requests <= 0 {
                scanner.request_infos[original_id] = None
              } else {
                scanner.request_infos[original_id] = Some({
                  original: original_id,
                  requests: next_requests,
                })
              }
            }
            None => ()
          }
        }
      }
    }
  }
}

///|
fn lcs_scanner_finalize_node(
  scanner : Scanner,
  instr : TInstr,
  child_ids : Array[Int],
  active_exprs : Map[UInt64, Array[HashedExpression]],
) -> (Int, Map[UInt64, Array[HashedExpression]]) {
  let active_exprs = active_exprs
  let child_digests : Array[UInt64] = []
  for child_id in child_ids {
    child_digests.push(scanner.node_digests[child_id])
  }
  let digest = lcs_digest(instr, child_digests)
  let id = scanner.next_id
  scanner.next_id += 1
  scanner.node_instrs.push(instr)
  scanner.node_digests.push(digest)
  scanner.node_children.push(child_ids)
  scanner.request_infos.push(None)
  if lcs_is_possible(instr) &&
    lcs_is_relevant(instr, scanner.env, scanner.shrink_level) {
    let bucket = active_exprs.get(digest).unwrap_or([])
    let mut found_original : Int? = None
    for item in bucket {
      if item.digest == digest && scanner.node_instrs[item.id] == instr {
        found_original = Some(item.id)
        break
      }
    }
    match found_original {
      Some(original_id) => {
        scanner.request_infos[id] = Some({ original: original_id, requests: 0 })
        match scanner.request_infos[original_id] {
          Some(info) =>
            scanner.request_infos[original_id] = Some({
              original: original_id,
              requests: info.requests + 1,
            })
          None =>
            scanner.request_infos[original_id] = Some({
              original: original_id,
              requests: 1,
            })
        }
        for child_id in child_ids {
          lcs_scanner_suppress_child(scanner, child_id)
        }
      }
      None => {
        let next_bucket = bucket.copy()
        next_bucket.push({ id, digest })
        active_exprs[digest] = next_bucket
      }
    }
  }
  (id, active_exprs)
}

///|
fn lcs_scan_tinstr(
  scanner : Scanner,
  instr : TInstr,
  active_exprs : Map[UInt64, Array[HashedExpression]],
) -> (Int, Map[UInt64, Array[HashedExpression]]) {
  let mut active_exprs = active_exprs
  if lcs_is_non_linear_boundary(instr) {
    active_exprs = Map::new()
  }
  match instr {
    TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) => {
      lcs_scan_texpr(scanner, body)
      let (id, _) = lcs_scanner_finalize_node(scanner, instr, [], active_exprs)
      (id, Map::new())
    }
    TIf(_, cond, then_, else_) => {
      let (cond_id, _) = lcs_scan_tinstr(scanner, cond, active_exprs)
      lcs_scan_texpr(scanner, then_)
      match else_ {
        Some(other) => lcs_scan_texpr(scanner, other)
        None => ()
      }
      let (id, _) = lcs_scanner_finalize_node(
        scanner,
        instr,
        [cond_id],
        Map::new(),
      )
      (id, Map::new())
    }
    _ => {
      let child_ids : Array[Int] = []
      let mut curr_active = active_exprs
      for child in eval_children(instr) {
        let (child_id, next_active) = lcs_scan_tinstr(
          scanner, child, curr_active,
        )
        child_ids.push(child_id)
        curr_active = next_active
      }
      lcs_scanner_finalize_node(scanner, instr, child_ids, curr_active)
    }
  }
}

///|
fn lcs_scan_texpr(scanner : Scanner, expr : TExpr) -> Unit {
  let mut active_exprs : Map[UInt64, Array[HashedExpression]] = Map::new()
  for instr in expr.0 {
    let (_, next_active) = lcs_scan_tinstr(scanner, instr, active_exprs)
    active_exprs = next_active
  }
}

///|
fn lcs_checker_invalidate_original(
  checker : Checker,
  original_id : Int,
  active_info : LCSActiveOriginal,
) -> Unit {
  match checker.request_infos[original_id] {
    Some(info) => {
      let next_requests = info.requests - active_info.requests_left
      if next_requests <= 0 {
        checker.request_infos[original_id] = None
      } else {
        checker.request_infos[original_id] = Some({
          original: info.original,
          requests: next_requests,
        })
      }
    }
    None => ()
  }
}

///|
fn lcs_checker_process_node(
  checker : Checker,
  id : Int,
  instr : TInstr,
  active_originals : Map[Int, LCSActiveOriginal],
) -> Map[Int, LCSActiveOriginal] {
  let active_originals = active_originals
  let curr_effects = lcs_collect_shallow_effects(instr)
  curr_effects.traps = false
  let to_invalidate : Array[Int] = []
  for original_id, active_info in active_originals {
    if curr_effects.invalidates(active_info.effects) {
      to_invalidate.push(original_id)
    }
  }
  for original_id in to_invalidate {
    match active_originals.get(original_id) {
      Some(active_info) => {
        lcs_checker_invalidate_original(checker, original_id, active_info)
        active_originals.remove(original_id)
      }
      None => ()
    }
  }
  match checker.request_infos[id] {
    Some(info) if info.original == id && info.requests > 0 =>
      active_originals[id] = {
        requests_left: info.requests,
        effects: lcs_collect_effects(instr),
      }
    _ => ()
  }
  match checker.request_infos[id] {
    Some(info) if info.original != id => {
      let original_id = info.original
      match active_originals.get(original_id) {
        None => checker.request_infos[id] = None
        Some(active_info) => {
          let next_left = active_info.requests_left - 1
          if next_left <= 0 {
            active_originals.remove(original_id)
          } else {
            active_originals[original_id] = {
              requests_left: next_left,
              effects: active_info.effects,
            }
          }
        }
      }
    }
    _ => ()
  }
  active_originals
}

///|
fn lcs_check_tinstr(
  checker : Checker,
  instr : TInstr,
  active_originals : Map[Int, LCSActiveOriginal],
) -> (Int, Map[Int, LCSActiveOriginal]) {
  let mut active_originals = active_originals
  if lcs_is_non_linear_boundary(instr) {
    active_originals = Map::new()
  }
  match instr {
    TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) => {
      lcs_check_texpr(checker, body)
      let id = checker.next_id
      checker.next_id += 1
      let next_active = lcs_checker_process_node(
        checker, id, instr, active_originals,
      )
      (
        id,
        if lcs_is_non_linear_boundary(instr) {
          Map::new()
        } else {
          next_active
        },
      )
    }
    TIf(_, cond, then_, else_) => {
      let (_, _) = lcs_check_tinstr(checker, cond, active_originals)
      lcs_check_texpr(checker, then_)
      match else_ {
        Some(other) => lcs_check_texpr(checker, other)
        None => ()
      }
      let id = checker.next_id
      checker.next_id += 1
      ignore(lcs_checker_process_node(checker, id, instr, Map::new()))
      (id, Map::new())
    }
    _ => {
      let mut curr_active = active_originals
      for child in eval_children(instr) {
        let (_, next_active) = lcs_check_tinstr(checker, child, curr_active)
        curr_active = next_active
      }
      let id = checker.next_id
      checker.next_id += 1
      let next_active = lcs_checker_process_node(
        checker, id, instr, curr_active,
      )
      (id, next_active)
    }
  }
}

///|
fn lcs_check_texpr(checker : Checker, expr : TExpr) -> Unit {
  let mut active_originals : Map[Int, LCSActiveOriginal] = Map::new()
  for instr in expr.0 {
    let (_, next_active) = lcs_check_tinstr(checker, instr, active_originals)
    active_originals = next_active
  }
  if !active_originals.is_empty() {
    active_originals = Map::new()
    ignore(active_originals)
  }
}

///|
fn lcs_rebuild_non_control(instr : TInstr, children : Array[TInstr]) -> TInstr {
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

    // Two operands.
    TBinary(op, _, _) => TInstr::binary(op, children[0], children[1])
    TRefEq(_, _) => TInstr::ref_eq(children[0], children[1])
    TStore(op, memarg, _, _) =>
      TInstr::store(op, memarg, children[0], children[1])
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
fn lcs_applier_finalize_node(
  applier : Applier,
  rewritten : TInstr,
) -> (TInstr, Int) {
  let id = applier.next_id
  applier.next_id += 1
  let mut out = rewritten
  if id < applier.request_infos.length() {
    match applier.request_infos[id] {
      Some(info) if info.original == id && info.requests > 0 =>
        match lcs_infer_tinstr_type(applier.node_instrs[id], applier.env) {
          Some(vt) => {
            let local_idx = LocalIdx::new(
              applier.locals.length().reinterpret_as_uint(),
            )
            applier.locals.push(vt)
            applier.original_to_local[id] = local_idx
            out = TInstr::local_tee(local_idx, out)
            applier.changed = true
          }
          None => ()
        }
      Some(info) if info.original != id => {
        let original_id = info.original
        match applier.request_infos.get(original_id) {
          Some(Some(original_info)) if original_info.requests > 0 =>
            match applier.original_to_local.get(original_id) {
              Some(local_idx) => {
                out = TInstr::local_get(local_idx)
                applier.changed = true
                let next_requests = original_info.requests - 1
                if next_requests <= 0 {
                  applier.request_infos[original_id] = None
                  applier.original_to_local.remove(original_id)
                } else {
                  applier.request_infos[original_id] = Some({
                    original: original_info.original,
                    requests: next_requests,
                  })
                }
              }
              None => ()
            }
          _ => ()
        }
      }
      _ => ()
    }
  }
  (out, id)
}

///|
fn lcs_apply_tinstr(applier : Applier, instr : TInstr) -> (TInstr, Int) {
  if lcs_is_non_linear_boundary(instr) {
    applier.original_to_local = Map::new()
  }
  let (rewritten, id) = match instr {
    TBlock(bt, body) => {
      let new_body = lcs_apply_texpr(applier, body)
      lcs_applier_finalize_node(applier, TInstr::block(bt, new_body))
    }
    TLoop(bt, body) => {
      let new_body = lcs_apply_texpr(applier, body)
      lcs_applier_finalize_node(applier, TInstr::loop_(bt, new_body))
    }
    TTryTable(bt, catches, body) => {
      let new_body = lcs_apply_texpr(applier, body)
      lcs_applier_finalize_node(
        applier,
        TInstr::try_table(bt, catches, new_body),
      )
    }
    TIf(bt, cond, then_, else_) => {
      let (new_cond, _) = lcs_apply_tinstr(applier, cond)
      let new_then = lcs_apply_texpr(applier, then_)
      let new_else = match else_ {
        Some(other) => Some(lcs_apply_texpr(applier, other))
        None => None
      }
      lcs_applier_finalize_node(
        applier,
        TInstr::if_(bt, new_cond, new_then, new_else),
      )
    }
    _ => {
      let rewritten_children : Array[TInstr] = []
      for child in eval_children(instr) {
        let (new_child, _) = lcs_apply_tinstr(applier, child)
        rewritten_children.push(new_child)
      }
      let rebuilt = lcs_rebuild_non_control(instr, rewritten_children)
      lcs_applier_finalize_node(applier, rebuilt)
    }
  }
  if lcs_is_non_linear_boundary(instr) {
    applier.original_to_local = Map::new()
  }
  (rewritten, id)
}

///|
fn lcs_apply_texpr(applier : Applier, expr : TExpr) -> TExpr {
  let prev = applier.original_to_local
  applier.original_to_local = Map::new()
  let out : Array[TInstr] = []
  for instr in expr.0 {
    let (new_instr, _) = lcs_apply_tinstr(applier, instr)
    out.push(new_instr)
  }
  applier.original_to_local = prev
  TExpr::new(out)
}

///|
fn lcs_has_live_requests(request_infos : Array[RequestInfo?]) -> Bool {
  for info_opt in request_infos {
    match info_opt {
      Some(info) if info.original == info.original && info.requests > 0 =>
        if info.original >= 0 {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn run_local_cse_on_func(
  env : Env,
  locals : Array[ValType],
  body : TExpr,
  shrink_level : Int,
) -> (Array[ValType], TExpr, Bool) {
  let scanner = Scanner::new(env, shrink_level)
  lcs_scan_texpr(scanner, body)
  if !lcs_has_live_requests(scanner.request_infos) {
    return (locals, body, false)
  }
  let checker = Checker::new(scanner.request_infos.copy())
  lcs_check_texpr(checker, body)
  if !lcs_has_live_requests(checker.request_infos) {
    return (locals, body, false)
  }
  let applier = Applier::new(
    env,
    scanner.node_instrs,
    checker.request_infos,
    locals.copy(),
  )
  let new_body = lcs_apply_texpr(applier, body)
  (applier.locals, new_body, applier.changed)
}

///|
fn local_cse_ir_pass(
  mod : Module,
  options : OptimizeOptions,
) -> ModuleTransformer[IRContext] {
  let base_env = Env::new().with_module(mod)
  ModuleTransformer::new().on_func_evt(fn(_, ctx, func) {
    match func {
      TFunc(locals, body) => {
        let env = base_env.with_locals(locals)
        let (new_locals, new_body, changed) = run_local_cse_on_func(
          env,
          locals,
          body,
          options.shrink_level,
        )
        if changed {
          change(ctx, Func::t_func(new_locals, new_body))
        } else {
          unchanged()
        }
      }
      _ => unchanged()
    }
  })
}

///|
fn run_local_cse(
  mod : Module,
  options? : OptimizeOptions = OptimizeOptions::new(),
) -> Module {
  let pass = local_cse_ir_pass(mod, options)
  match pass.walk_module(IRContext::new(), mod) {
    Ok(Some((_, out))) => out
    _ => mod
  }
}

///|
fn count_local_tees(body : TExpr) -> Int {
  let mut count = 0
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TLocalTee(_, _) => count += 1
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  count
}

///|
fn count_local_gets(body : TExpr) -> Int {
  let mut count = 0
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TLocalGet(_) => count += 1
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  count
}

///|
test "local cse rewrites repeated whole trees inside block" {
  let func = Func::t_func(
    [],
    TExpr::new([
      TInstr::drop(
        TInstr::binary(
          BinaryOp::i32_add(),
          TInstr::binary(
            BinaryOp::i32_mul(),
            TInstr::i32_const(I32(3)),
            TInstr::i32_const(I32(4)),
          ),
          TInstr::binary(
            BinaryOp::i32_mul(),
            TInstr::i32_const(I32(3)),
            TInstr::i32_const(I32(4)),
          ),
        ),
      ),
    ]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let out = run_local_cse(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => {
      assert_true(count_local_tees(body) >= 1)
      assert_true(count_local_gets(body) >= 1)
    }
    _ => fail("expected transformed function")
  }
}

///|
test "local cse does not connect across non-linear boundaries" {
  let repeated = TInstr::binary(
    BinaryOp::i32_add(),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::i32_const(I32(1)),
  )
  let func = Func::t_func(
    [ValType::i32()],
    TExpr::new([
      TInstr::drop(repeated),
      TInstr::if_(
        BlockType::void_(),
        TInstr::i32_const(I32(0)),
        TExpr::new([TInstr::nop()]),
        None,
      ),
      TInstr::drop(repeated),
    ]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let out = run_local_cse(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_eq(count_local_tees(body), 0)
    _ => fail("expected transformed function")
  }
}

///|
test "local cse suppresses direct-child reuse when parent is repeated" {
  let child = TInstr::binary(
    BinaryOp::i32_add(),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::i32_const(I32(1)),
  )
  let parent = TInstr::binary(BinaryOp::i32_mul(), child, child)
  let func = Func::t_func(
    [ValType::i32()],
    TExpr::new([TInstr::drop(parent), TInstr::drop(parent)]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let out = run_local_cse(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(locals, body)])) => {
      // Parent should CSE and child-direct requests in the repeated parent are suppressed.
      // A first-parent child repeat may still remain CSE-eligible.
      assert_true(locals.length() >= 2)
      assert_true(count_local_tees(body) >= 1)
    }
    _ => fail("expected transformed function")
  }
}

///|
test "local cse checker invalidates across memory interference" {
  let ma = MemArg::new(0, None, 0)
  let repeated_load = TInstr::load(
    LoadOp::i32_load(),
    ma,
    TInstr::i32_const(I32(0)),
  )
  let func = Func::t_func(
    [],
    TExpr::new([
      TInstr::drop(repeated_load),
      TInstr::store(
        StoreOp::i32_store(),
        ma,
        TInstr::i32_const(I32(0)),
        TInstr::i32_const(I32(7)),
      ),
      TInstr::drop(repeated_load),
    ]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let out = run_local_cse(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_eq(count_local_tees(body), 0)
    _ => fail("expected transformed function")
  }
}

///|
test "local cse allows trap-only operations as candidates" {
  let ma = MemArg::new(0, None, 0)
  let repeated_load = TInstr::load(
    LoadOp::i32_load(),
    ma,
    TInstr::i32_const(I32(0)),
  )
  let func = Func::t_func(
    [],
    TExpr::new([TInstr::drop(repeated_load), TInstr::drop(repeated_load)]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let out = run_local_cse(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_true(count_local_tees(body) >= 1)
    _ => fail("expected transformed function")
  }
}

///|
test "local cse ignores trivial constants and local.get" {
  let func = Func::t_func(
    [ValType::i32()],
    TExpr::new([
      TInstr::drop(TInstr::i32_const(I32(5))),
      TInstr::drop(TInstr::i32_const(I32(5))),
      TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
      TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
    ]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let out = run_local_cse(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_eq(count_local_tees(body), 0)
    _ => fail("expected transformed function")
  }
}

///|
test "local cse shrink mode requires larger nodes" {
  let repeated = TInstr::unary(
    UnaryOp::i32_eqz(),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let func = Func::t_func(
    [ValType::i32()],
    TExpr::new([TInstr::drop(repeated), TInstr::drop(repeated)]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let out = run_local_cse(mod, options=OptimizeOptions::new(shrink_level=1))
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_eq(count_local_tees(body), 0)
    _ => fail("expected transformed function")
  }
}

///|
test "local cse is idempotent" {
  let repeated = TInstr::binary(
    BinaryOp::i32_add(),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::i32_const(I32(1)),
  )
  let func = Func::t_func(
    [ValType::i32()],
    TExpr::new([TInstr::drop(repeated), TInstr::drop(repeated)]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let once = run_local_cse(mod)
  let twice = run_local_cse(once)
  assert_eq(once, twice)
}
