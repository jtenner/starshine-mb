///|
enum ILTrivialKind {
  ILNotTrivial
  ILShrinks
  ILMayNotShrink
} derive(Eq)

///|
enum ILCallKind {
  ILDirectCall
  ILReturnCall
} derive(Eq)

///|
priv struct ILCallSite {
  id : Int
  caller_abs_idx : Int
  callee_abs_idx : Int
  kind : ILCallKind
  try_depth : Int
  force_unreachable : Bool
}

///|
priv struct ILInlineAction {
  callsite_id : Int
  caller_abs_idx : Int
  callee_abs_idx : Int
  kind : ILCallKind
  try_depth : Int
  force_unreachable : Bool
}

///|
priv struct ILFunctionInfo {
  imported : Bool
  func_type : FuncType
  body : TExpr?
  size : Int
  has_loops : Bool
  has_calls : Bool
  has_try_delegate : Bool
  direct_call_refs : Int
  ref_func_refs : Int
  used_globally : Bool
  trivial_kind : ILTrivialKind
  tail_wrapper : Bool
}

///|
fn il_func_idx_from_abs(abs_idx : Int) -> FuncIdx {
  FuncIdx::new(abs_idx.reinterpret_as_uint())
}

///|
fn il_local_idx_from_int(idx : Int) -> LocalIdx {
  LocalIdx::new(idx.reinterpret_as_uint())
}

///|
fn il_label_idx_from_int(idx : Int) -> LabelIdx {
  LabelIdx::new(idx.reinterpret_as_uint())
}

///|
fn il_count_imported_funcs(mod : Module) -> Int {
  let mut n = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(_)) => n += 1
          _ => ()
        }
      }
    None => ()
  }
  n
}

///|
fn il_total_functions(mod : Module, imported : Int) -> Int {
  let defined = match mod.code_sec {
    Some(CodeSec(funcs)) => funcs.length()
    None => 0
  }
  imported + defined
}

///|
fn il_collect_func_types(mod : Module, total_funcs : Int) -> Array[FuncType] {
  let env = Env::new().with_module(mod)
  let out : Array[FuncType] = []
  for i = 0; i < total_funcs; i = i + 1 {
    match env.get_functype_by_funcidx(il_func_idx_from_abs(i)) {
      Some(ft) => out.push(ft)
      None => out.push(FuncType::new([], []))
    }
  }
  out
}

///|
fn il_collect_funcs_by_abs(mod : Module, imported : Int) -> Array[Func?] {
  let out : Array[Func?] = []
  for i = 0; i < imported; i = i + 1 {
    out.push(None)
  }
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        out.push(Some(func))
      }
    None => ()
  }
  out
}

///|
fn il_mark_func_used(used : Array[Bool], idx : FuncIdx) -> Unit {
  let FuncIdx(raw) = idx
  let i = raw.reinterpret_as_int()
  if i >= 0 && i < used.length() {
    used[i] = true
  }
}

///|
fn il_compute_used_globally(mod : Module, total_funcs : Int) -> Array[Bool] {
  let used : Array[Bool] = []
  for i = 0; i < total_funcs; i = i + 1 {
    used.push(false)
  }
  match mod.export_sec {
    Some(ExportSec(exports)) =>
      for export_ in exports {
        match export_ {
          Export(_, FuncExternIdx(idx)) => il_mark_func_used(used, idx)
          _ => ()
        }
      }
    None => ()
  }
  match mod.start_sec {
    Some(StartSec(idx)) => il_mark_func_used(used, idx)
    None => ()
  }
  match mod.elem_sec {
    Some(ElemSec(elems)) =>
      for elem in elems {
        match elem {
          Elem(_, kind) =>
            match kind {
              FuncsElemKind(funcs) =>
                for idx in funcs {
                  il_mark_func_used(used, idx)
                }
              FuncExprsElemKind(exprs) | TypedExprsElemKind(_, exprs) =>
                for expr in exprs {
                  for instr in expr.0 {
                    match instr {
                      RefFunc(idx) => il_mark_func_used(used, idx)
                      _ => ()
                    }
                  }
                }
            }
        }
      }
    None => ()
  }
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TRefFunc(idx) => il_mark_func_used(used, idx)
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        match func {
          TFunc(_, body) => ignore(walker.walk_texpr((), body))
          _ => ()
        }
      }
    None => ()
  }
  match mod.global_sec {
    Some(GlobalSec(globals)) =>
      for global in globals {
        match global {
          Global(_, init) =>
            for instr in init.0 {
              match instr {
                RefFunc(idx) => il_mark_func_used(used, idx)
                _ => ()
              }
            }
        }
      }
    None => ()
  }
  used
}

///|
fn il_measure_body(body : TExpr) -> Int {
  let mut count = 0
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    count += 1
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  count
}

///|
fn il_is_non_control(instr : TInstr) -> Bool {
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
    | TCall(_, _)
    | TCallIndirect(_, _, _, _)
    | TCallRef(_, _, _)
    | TReturnCall(_, _)
    | TReturnCallIndirect(_, _, _, _)
    | TReturnCallRef(_, _, _)
    | TThrow(_, _)
    | TThrowRef(_) => false
    _ => true
  }
}

///|
fn il_is_trivial_leaf(instr : TInstr) -> Bool {
  match instr {
    TI32Const(_)
    | TI64Const(_)
    | TF32Const(_)
    | TF64Const(_)
    | TRefNull(_)
    | TRefFunc(_)
    | TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | TLocalGet(_)
    | TGlobalGet(_) => true
    _ => false
  }
}

///|
fn il_is_shrink_wrapper(instr : TInstr, _param_count : Int) -> Bool {
  if !il_is_non_control(instr) {
    return false
  }
  let children = eval_children(instr)
  if children.is_empty() {
    return false
  }
  let seen : Set[Int] = Set::new()
  let mut last_idx = -1
  for child in children {
    match child {
      TLocalGet(LocalIdx(raw)) => {
        let idx = raw.reinterpret_as_int()
        if seen.contains(idx) || idx < last_idx {
          return false
        }
        seen.add(idx)
        last_idx = idx
      }
      _ => return false
    }
  }
  true
}

///|
fn il_detect_trivial_kind(body : TExpr, param_count : Int) -> ILTrivialKind {
  if body.0.length() != 1 {
    return ILNotTrivial
  }
  let instr = body.0[0]
  if !il_is_non_control(instr) {
    return ILNotTrivial
  }
  if il_is_shrink_wrapper(instr, param_count) {
    return ILShrinks
  }
  for child in eval_children(instr) {
    if !il_is_trivial_leaf(child) {
      return ILNotTrivial
    }
  }
  ILMayNotShrink
}

///|
fn il_analyze_func(
  func : Func?,
  func_type : FuncType,
  used_globally : Bool,
) -> ILFunctionInfo {
  match func {
    None =>
      ILFunctionInfo::{
        imported: true,
        func_type,
        body: None,
        size: 0,
        has_loops: false,
        has_calls: false,
        has_try_delegate: false,
        direct_call_refs: 0,
        ref_func_refs: 0,
        used_globally,
        trivial_kind: ILNotTrivial,
        tail_wrapper: false,
      }
    Some(TFunc(locals, body)) => {
      let mut has_loops = false
      let mut has_calls = false
      let mut has_try_delegate = false
      let mut direct_call_refs = 0
      let mut ref_func_refs = 0
      let walker = ModuleTransformer::new().on_tinstruction_evt(fn(
        self,
        _,
        instr,
      ) {
        match instr {
          TLoop(_, _) => has_loops = true
          TCall(_, _)
          | TCallIndirect(_, _, _, _)
          | TCallRef(_, _, _)
          | TReturnCall(_, _)
          | TReturnCallIndirect(_, _, _, _)
          | TReturnCallRef(_, _, _) => {
            has_calls = true
            match instr {
              TCall(_, _) | TReturnCall(_, _) => direct_call_refs += 1
              _ => ()
            }
          }
          TTryTable(_, _, _) => has_try_delegate = true
          TRefFunc(_) => ref_func_refs += 1
          _ => ()
        }
        self.walk_tinstruction_default((), instr)
      })
      ignore(walker.walk_texpr((), body))
      let FuncType(params, _) = func_type
      let tail_wrapper = if locals.is_empty() {
        match body.0 {
          [TReturnCall(_, _)] => true
          [TReturnCallIndirect(_, _, _, _)] => true
          [TReturnCallRef(_, _, _)] => true
          _ => false
        }
      } else {
        false
      }
      ILFunctionInfo::{
        imported: false,
        func_type,
        body: Some(body),
        size: il_measure_body(body),
        has_loops,
        has_calls,
        has_try_delegate,
        direct_call_refs,
        ref_func_refs,
        used_globally,
        trivial_kind: il_detect_trivial_kind(body, params.length()),
        tail_wrapper,
      }
    }
    Some(Func(_, _)) =>
      ILFunctionInfo::{
        imported: false,
        func_type,
        body: None,
        size: 0,
        has_loops: false,
        has_calls: false,
        has_try_delegate: false,
        direct_call_refs: 0,
        ref_func_refs: 0,
        used_globally,
        trivial_kind: ILNotTrivial,
        tail_wrapper: false,
      }
  }
}

///|
fn il_collect_infos(
  mod : Module,
  funcs_by_abs : Array[Func?],
  func_types : Array[FuncType],
) -> Array[ILFunctionInfo] {
  let used_globally = il_compute_used_globally(mod, func_types.length())
  let out : Array[ILFunctionInfo] = []
  for i = 0; i < func_types.length(); i = i + 1 {
    out.push(il_analyze_func(funcs_by_abs[i], func_types[i], used_globally[i]))
  }
  out
}

///|
fn il_any_unreachable(values : Array[TInstr]) -> Bool {
  for value in values {
    if is_unreachable_instr(value) {
      return true
    }
  }
  false
}

///|
fn il_collect_callsites_for_body(
  caller_abs_idx : Int,
  body : TExpr,
) -> Array[ILCallSite] {
  let sites : Array[ILCallSite] = []
  let mut next_id = 0
  let mut try_depth = 0
  let reachable_stack : Array[Bool] = []
  let mut reachable_depth = 0
  let walker = ModuleTransformer::new()
    .on_texpr_evt(fn(self, _, expr) {
      let start_reachable = if reachable_depth > 0 {
        reachable_stack[reachable_depth - 1]
      } else {
        true
      }
      if reachable_depth == reachable_stack.length() {
        reachable_stack.push(start_reachable)
      } else {
        reachable_stack[reachable_depth] = start_reachable
      }
      reachable_depth += 1
      let mut curr_reachable = start_reachable
      for instr in expr.0 {
        reachable_stack[reachable_depth - 1] = curr_reachable
        match self.walk_tinstruction((), instr) {
          Ok(_) => ()
          Err(e) => {
            reachable_depth -= 1
            return Err(e)
          }
        }
        if curr_reachable && is_unreachable_instr(instr) {
          curr_reachable = false
        }
      }
      reachable_depth -= 1
      change((), expr)
    })
    .on_tinstruction_evt(fn(self, _, instr) {
      match instr {
        TTryTable(bt, catches, try_body) => {
          try_depth += 1
          let walked_body = match self.walk_texpr((), try_body) {
            Ok(Some((_, next))) => next
            Ok(None) => try_body
            Err(e) => {
              try_depth -= 1
              return Err(e)
            }
          }
          try_depth -= 1
          if walked_body == try_body {
            unchanged()
          } else {
            change((), TInstr::try_table(bt, catches, walked_body))
          }
        }
        _ => {
          let walked = match self.walk_tinstruction_default((), instr) {
            Ok(Some((_, next))) => next
            Ok(None) => instr
            Err(e) => return Err(e)
          }
          let is_reachable = if reachable_depth > 0 {
            reachable_stack[reachable_depth - 1]
          } else {
            true
          }
          match walked {
            TCall(fi, args) => {
              let FuncIdx(raw) = fi
              let callee_abs_idx = raw.reinterpret_as_int()
              if is_reachable {
                sites.push({
                  id: next_id,
                  caller_abs_idx,
                  callee_abs_idx,
                  kind: ILDirectCall,
                  try_depth,
                  force_unreachable: il_any_unreachable(args),
                })
              }
              next_id += 1
            }
            TReturnCall(fi, args) => {
              let FuncIdx(raw) = fi
              let callee_abs_idx = raw.reinterpret_as_int()
              if is_reachable {
                sites.push({
                  id: next_id,
                  caller_abs_idx,
                  callee_abs_idx,
                  kind: ILReturnCall,
                  try_depth,
                  force_unreachable: il_any_unreachable(args),
                })
              }
              next_id += 1
            }
            _ => ()
          }
          if walked == instr {
            unchanged()
          } else {
            change((), walked)
          }
        }
      }
    })
  ignore(walker.walk_texpr((), body))
  sites
}

///|
fn il_collect_callsites(
  mod : Module,
  imported : Int,
) -> Array[Array[ILCallSite]] {
  let total = il_total_functions(mod, imported)
  let out : Array[Array[ILCallSite]] = []
  for i = 0; i < total; i = i + 1 {
    out.push([])
  }
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      for def_idx = 0; def_idx < funcs.length(); def_idx = def_idx + 1 {
        let abs_idx = imported + def_idx
        match funcs[def_idx] {
          TFunc(_, body) =>
            out[abs_idx] = il_collect_callsites_for_body(abs_idx, body)
          _ => ()
        }
      }
    None => ()
  }
  out
}

///|
fn il_collect_incoming_counts(
  callsites_by_caller : Array[Array[ILCallSite]],
  total_funcs : Int,
) -> Array[Int] {
  let incoming : Array[Int] = []
  for i = 0; i < total_funcs; i = i + 1 {
    incoming.push(0)
  }
  for sites in callsites_by_caller {
    for site in sites {
      let idx = site.callee_abs_idx
      if idx >= 0 && idx < incoming.length() {
        incoming[idx] += 1
      }
    }
  }
  incoming
}

///|
fn il_estimate_module_size(infos : Array[ILFunctionInfo]) -> Int {
  let mut size = 0
  for info in infos {
    size += info.size
  }
  size
}

///|
fn il_worth_full_inlining(
  info : ILFunctionInfo,
  incoming_calls : Int,
  options : OptimizeOptions,
) -> Bool {
  if info.imported || info.body is None {
    return false
  }
  if info.has_try_delegate {
    return false
  }
  let inlining_options = options.inlining
  if !inlining_options.allow_functions_with_loops && info.has_loops {
    return false
  }
  if options.optimize_level == 0 &&
    options.shrink_level == 0 &&
    info.has_calls &&
    info.size > inlining_options.always_inline_max_size {
    return false
  }
  if options.shrink_level > 0 &&
    info.used_globally &&
    info.ref_func_refs > 0 &&
    incoming_calls > 1 {
    return false
  }
  if options.shrink_level > 1 && info.direct_call_refs > 0 && incoming_calls > 1 {
    return false
  }
  let FuncType(_, results) = info.func_type
  if results.length() > 1 {
    return false
  }
  if info.trivial_kind == ILShrinks {
    return true
  }
  if info.size <= inlining_options.always_inline_max_size {
    return true
  }
  if incoming_calls == 1 {
    if inlining_options.one_caller_inline_max_size < 0 {
      return true
    }
    if info.size <= inlining_options.one_caller_inline_max_size {
      return true
    }
  }
  if options.shrink_level == 0 && options.optimize_level >= 2 {
    if info.trivial_kind == ILMayNotShrink {
      return true
    }
    if info.size <= inlining_options.flexible_inline_max_size {
      return true
    }
  }
  false
}

///|
fn il_apply_ir_transformer_pass(
  mod : Module,
  pass : ModuleTransformer[IRContext],
) -> Result[Module, String] {
  let ctx = IRContext::new()
  match pass.walk_module(ctx, mod) {
    Ok(Some((_, new_mod))) => Ok(new_mod)
    Ok(None) => Ok(mod)
    Err(e) => Err(e)
  }
}

///|
fn il_zero_of_type(vt : ValType) -> TInstr? {
  match vt {
    NumTypeValType(I32NumType) => Some(TInstr::i32_const(I32(0)))
    NumTypeValType(I64NumType) => Some(TInstr::i64_const(I64(0L)))
    NumTypeValType(F32NumType) => Some(TInstr::f32_const(F32(0.0)))
    NumTypeValType(F64NumType) => Some(TInstr::f64_const(F64(0.0)))
    VecTypeValType =>
      Some(TInstr::v128_const(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    RefTypeValType(rt) =>
      if rt.is_nullable() {
        Some(TInstr::ref_null(rt.get_heap_type()))
      } else {
        None
      }
    BotValType => Some(TInstr::unreachable_())
  }
}

///|
fn il_hoist_placeholder_values(results : Array[ValType]) -> Array[TInstr]? {
  let placeholders : Array[TInstr] = []
  for vt in results {
    match il_zero_of_type(vt) {
      Some(zero) => placeholders.push(zero)
      None => return None
    }
  }
  Some(placeholders)
}

///|
fn il_make_block_type(results : Array[ValType]) -> BlockType? {
  match results {
    [] => Some(BlockType::void_())
    [r] => Some(BlockType::val_type(r))
    _ => None
  }
}

///|
fn il_make_hoist_wrapper_block_type(
  caller_results : Array[ValType],
  caller_type_idx : TypeIdx?,
  env : Env,
) -> BlockType? {
  match il_make_block_type(caller_results) {
    Some(bt) => Some(bt)
    None =>
      match caller_type_idx {
        Some(type_idx) =>
          match env.resolve_functype(type_idx) {
            Some(FuncType(params, results)) =>
              if params.is_empty() && results == caller_results {
                Some(BlockType::type_idx(type_idx))
              } else {
                None
              }
            _ => None
          }
        None => None
      }
  }
}

///|
fn il_wrap_force_unreachable(
  replacement : TInstr,
  results : Array[ValType],
) -> TInstr {
  match results {
    [] =>
      TInstr::block(
        BlockType::void_(),
        TExpr::new([replacement, TInstr::unreachable_()]),
      )
    [r] =>
      TInstr::block(
        BlockType::val_type(r),
        TExpr::new([TInstr::drop(replacement), TInstr::unreachable_()]),
      )
    _ => replacement
  }
}

///|
fn il_rewrite_inlined_body(
  body : TExpr,
  callee_param_count : Int,
  mapped_params : Array[LocalIdx],
  mapped_locals : Array[LocalIdx],
  callee_results : Array[ValType],
  site_is_tail : Bool,
) -> Result[TExpr, String] {
  let mapper = ModuleTransformer::new()
    .on_localidx_evt(fn(_, _, idx) {
      let LocalIdx(raw) = idx
      let i = raw.reinterpret_as_int()
      let mapped = if i < callee_param_count {
        mapped_params.get(i)
      } else {
        mapped_locals.get(i - callee_param_count)
      }
      match mapped {
        Some(next) => if next == idx { unchanged() } else { change((), next) }
        None => Err("inlining: local index mapping out of range")
      }
    })
    .on_labelidx_evt(fn(_, _, idx) {
      let LabelIdx(raw) = idx
      change((), il_label_idx_from_int(raw.reinterpret_as_int() + 1))
    })
    .on_tinstruction_evt(fn(self, _, instr) {
      let walked = match self.walk_tinstruction_default((), instr) {
        Ok(Some((_, next))) => next
        Ok(None) => instr
        Err(e) => return Err(e)
      }
      let rewritten = match walked {
        TReturn(values) => TInstr::br(LabelIdx::new(0), values)
        TReturnCall(target, args) =>
          if site_is_tail {
            TInstr::return_call(target, args)
          } else {
            match callee_results {
              [] =>
                TInstr::block(
                  BlockType::void_(),
                  TExpr::new([
                    TInstr::call(target, args),
                    TInstr::br(LabelIdx::new(0), []),
                  ]),
                )
              [_] => TInstr::br(LabelIdx::new(0), [TInstr::call(target, args)])
              _ =>
                return Err(
                  "inlining: return_call rewrite for multi-value results is unsupported",
                )
            }
          }
        TReturnCallIndirect(type_idx, table_idx, args, idx) =>
          if site_is_tail {
            TInstr::return_call_indirect(type_idx, table_idx, args, idx)
          } else {
            match callee_results {
              [] =>
                TInstr::block(
                  BlockType::void_(),
                  TExpr::new([
                    TInstr::call_indirect(type_idx, table_idx, args, idx),
                    TInstr::br(LabelIdx::new(0), []),
                  ]),
                )
              [_] =>
                TInstr::br(LabelIdx::new(0), [
                  TInstr::call_indirect(type_idx, table_idx, args, idx),
                ])
              _ =>
                return Err(
                  "inlining: return_call_indirect rewrite for multi-value results is unsupported",
                )
            }
          }
        TReturnCallRef(type_idx, args, ref_) =>
          if site_is_tail {
            TInstr::return_call_ref(type_idx, args, ref_)
          } else {
            match callee_results {
              [] =>
                TInstr::block(
                  BlockType::void_(),
                  TExpr::new([
                    TInstr::call_ref(type_idx, args, ref_),
                    TInstr::br(LabelIdx::new(0), []),
                  ]),
                )
              [_] =>
                TInstr::br(LabelIdx::new(0), [
                  TInstr::call_ref(type_idx, args, ref_),
                ])
              _ =>
                return Err(
                  "inlining: return_call_ref rewrite for multi-value results is unsupported",
                )
            }
          }
        _ => walked
      }
      if rewritten == instr {
        unchanged()
      } else {
        change((), rewritten)
      }
    })
  match mapper.walk_texpr((), body) {
    Ok(Some((_, out))) => Ok(out)
    Ok(None) => Ok(body)
    Err(e) => Err(e)
  }
}

///|
fn il_substitute_params_in_instr(
  instr : TInstr,
  args : Array[TInstr],
) -> Result[TInstr, String] {
  let sub = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    let walked = match self.walk_tinstruction_default((), curr) {
      Ok(Some((_, next))) => next
      Ok(None) => curr
      Err(e) => return Err(e)
    }
    match walked {
      TLocalGet(LocalIdx(raw)) => {
        let idx = raw.reinterpret_as_int()
        match args.get(idx) {
          Some(arg) => change((), arg)
          None =>
            Err(
              "inlining: tail wrapper references non-parameter local during substitution",
            )
        }
      }
      TLocalSet(_, _) | TLocalTee(_, _) =>
        Err("inlining: tail wrapper local writes are unsupported")
      _ => if walked == curr { unchanged() } else { change((), walked) }
    }
  })
  match sub.walk_tinstruction((), instr) {
    Ok(Some((_, out))) => Ok(out)
    Ok(None) => Ok(instr)
    Err(e) => Err(e)
  }
}

///|
fn il_inline_tail_wrapper_call(
  callee_func : Func,
  args : Array[TInstr],
) -> Result[TInstr?, String] {
  match callee_func {
    TFunc(locals, TExpr([TReturnCall(target, tail_args)])) =>
      if locals.is_empty() {
        match
          il_substitute_params_in_instr(
            TInstr::return_call(target, tail_args),
            args,
          ) {
          Ok(out) => Ok(Some(out))
          Err(e) => Err(e)
        }
      } else {
        Ok(None)
      }
    TFunc(
      locals,
      TExpr([TReturnCallIndirect(type_idx, table_idx, tail_args, idx)])
    ) =>
      if locals.is_empty() {
        match
          il_substitute_params_in_instr(
            TInstr::return_call_indirect(type_idx, table_idx, tail_args, idx),
            args,
          ) {
          Ok(out) => Ok(Some(out))
          Err(e) => Err(e)
        }
      } else {
        Ok(None)
      }
    TFunc(locals, TExpr([TReturnCallRef(type_idx, tail_args, ref_)])) =>
      if locals.is_empty() {
        match
          il_substitute_params_in_instr(
            TInstr::return_call_ref(type_idx, tail_args, ref_),
            args,
          ) {
          Ok(out) => Ok(Some(out))
          Err(e) => Err(e)
        }
      } else {
        Ok(None)
      }
    _ => Ok(None)
  }
}

///|
fn il_inline_normal_call(
  action : ILInlineAction,
  callee_func : Func,
  callee_type : FuncType,
  args : Array[TInstr],
  caller_param_count : Int,
  caller_locals : Array[ValType],
) -> Result[TInstr, String] {
  let FuncType(callee_params, callee_results) = callee_type
  let block_type = match il_make_block_type(callee_results) {
    Some(bt) => bt
    None =>
      return Err(
        "inlining: multi-value function results are not currently supported",
      )
  }
  if callee_params.length() != args.length() {
    return Err("inlining: call argument count mismatch")
  }
  match callee_func {
    TFunc(callee_locals, callee_body) => {
      let mapped_params : Array[LocalIdx] = []
      let mapped_locals : Array[LocalIdx] = []
      for param_ty in callee_params {
        let idx = caller_param_count + caller_locals.length()
        caller_locals.push(param_ty)
        mapped_params.push(il_local_idx_from_int(idx))
      }
      for local_ty in callee_locals {
        let idx = caller_param_count + caller_locals.length()
        caller_locals.push(local_ty)
        mapped_locals.push(il_local_idx_from_int(idx))
      }
      let prologue : Array[TInstr] = []
      for i = 0; i < mapped_params.length(); i = i + 1 {
        prologue.push(TInstr::local_set(mapped_params[i], args[i]))
      }
      for i = 0; i < mapped_locals.length(); i = i + 1 {
        match il_zero_of_type(callee_locals[i]) {
          Some(zero) => prologue.push(TInstr::local_set(mapped_locals[i], zero))
          None => ()
        }
      }
      let rewritten_body = match
        il_rewrite_inlined_body(
          callee_body,
          callee_params.length(),
          mapped_params,
          mapped_locals,
          callee_results,
          false,
        ) {
        Ok(body) => body
        Err(e) => return Err(e)
      }
      let wrapped_instrs = prologue.copy()
      for instr in rewritten_body.0 {
        wrapped_instrs.push(instr)
      }
      let mut replacement = TInstr::block(
        block_type,
        TExpr::new(wrapped_instrs),
      )
      if action.force_unreachable {
        replacement = il_wrap_force_unreachable(replacement, callee_results)
      }
      Ok(replacement)
    }
    _ => Err("inlining: callee must be a TFunc for inlining")
  }
}

///|
fn il_inline_at_callsite(
  action : ILInlineAction,
  callee_func : Func,
  callee_type : FuncType,
  args : Array[TInstr],
  caller_param_count : Int,
  caller_locals : Array[ValType],
) -> Result[TInstr?, String] {
  match action.kind {
    ILReturnCall =>
      match il_inline_tail_wrapper_call(callee_func, args) {
        Ok(Some(instr)) => Ok(Some(instr))
        Ok(None) => Ok(None)
        Err(e) => Err(e)
      }
    ILDirectCall =>
      match
        il_inline_normal_call(
          action, callee_func, callee_type, args, caller_param_count, caller_locals,
        ) {
        Ok(instr) => Ok(Some(instr))
        Err(e) => Err(e)
      }
  }
}

///|
fn il_prepare_hoisted_tail_call(
  callee_func : Func,
  call_args : Array[TInstr],
  caller_param_count : Int,
  caller_locals : Array[ValType],
  env : Env,
  func_types : Array[FuncType],
  hoist_block_type : BlockType,
  hoist_placeholders : Array[TInstr],
) -> Result[(TInstr, TInstr, TInstr), String] {
  let inlined = match il_inline_tail_wrapper_call(callee_func, call_args) {
    Ok(Some(instr)) => instr
    Ok(None) =>
      return Err("inlining: expected a tail-wrapper callee for hoisting")
    Err(e) => return Err(e)
  }
  match inlined {
    TReturnCall(target, hoisted_args) => {
      let FuncIdx(target_raw) = target
      let target_abs = target_raw.reinterpret_as_int()
      if target_abs < 0 || target_abs >= func_types.length() {
        return Err("inlining: hoisted return_call target index out of range")
      }
      let FuncType(target_params, _) = func_types[target_abs]
      if target_params.length() != hoisted_args.length() {
        return Err("inlining: hoisted return_call argument count mismatch")
      }
      let stores : Array[TInstr] = []
      let localized_args : Array[TInstr] = []
      for i = 0; i < hoisted_args.length(); i = i + 1 {
        let idx = caller_param_count + caller_locals.length()
        caller_locals.push(target_params[i])
        let local_idx = il_local_idx_from_int(idx)
        stores.push(TInstr::local_set(local_idx, hoisted_args[i]))
        localized_args.push(TInstr::local_get(local_idx))
      }
      let flag_local_i = caller_param_count + caller_locals.length()
      caller_locals.push(ValType::i32())
      let flag_local = il_local_idx_from_int(flag_local_i)
      let flag_init = TInstr::local_set(flag_local, TInstr::i32_const(I32(0)))
      stores.push(TInstr::local_set(flag_local, TInstr::i32_const(I32(1))))
      stores.push(TInstr::unreachable_())
      for placeholder in hoist_placeholders {
        stores.push(placeholder)
      }
      let replacement = TInstr::block(hoist_block_type, TExpr::new(stores))
      let followup = TInstr::if_(
        BlockType::void_(),
        TInstr::local_get(flag_local),
        TExpr::new([TInstr::return_call(target, localized_args)]),
        None,
      )
      Ok((replacement, flag_init, followup))
    }
    TReturnCallIndirect(type_idx, table_idx, hoisted_args, idx) => {
      let FuncType(target_params, _) = match env.resolve_functype(type_idx) {
        Some(ft) => ft
        None =>
          return Err(
            "inlining: hoisted return_call_indirect has invalid function type index",
          )
      }
      if target_params.length() != hoisted_args.length() {
        return Err(
          "inlining: hoisted return_call_indirect argument count mismatch",
        )
      }
      let stores : Array[TInstr] = []
      let localized_args : Array[TInstr] = []
      for i = 0; i < hoisted_args.length(); i = i + 1 {
        let local_i = caller_param_count + caller_locals.length()
        caller_locals.push(target_params[i])
        let local_idx = il_local_idx_from_int(local_i)
        stores.push(TInstr::local_set(local_idx, hoisted_args[i]))
        localized_args.push(TInstr::local_get(local_idx))
      }
      let idx_local_i = caller_param_count + caller_locals.length()
      caller_locals.push(ValType::i32())
      let idx_local = il_local_idx_from_int(idx_local_i)
      stores.push(TInstr::local_set(idx_local, idx))
      let flag_local_i = caller_param_count + caller_locals.length()
      caller_locals.push(ValType::i32())
      let flag_local = il_local_idx_from_int(flag_local_i)
      let flag_init = TInstr::local_set(flag_local, TInstr::i32_const(I32(0)))
      stores.push(TInstr::local_set(flag_local, TInstr::i32_const(I32(1))))
      stores.push(TInstr::unreachable_())
      for placeholder in hoist_placeholders {
        stores.push(placeholder)
      }
      let replacement = TInstr::block(hoist_block_type, TExpr::new(stores))
      let followup = TInstr::if_(
        BlockType::void_(),
        TInstr::local_get(flag_local),
        TExpr::new([
          TInstr::return_call_indirect(
            type_idx,
            table_idx,
            localized_args,
            TInstr::local_get(idx_local),
          ),
        ]),
        None,
      )
      Ok((replacement, flag_init, followup))
    }
    TReturnCallRef(type_idx, hoisted_args, ref_) => {
      let FuncType(target_params, _) = match env.resolve_functype(type_idx) {
        Some(ft) => ft
        None =>
          return Err(
            "inlining: hoisted return_call_ref has invalid function type index",
          )
      }
      if target_params.length() != hoisted_args.length() {
        return Err("inlining: hoisted return_call_ref argument count mismatch")
      }
      let stores : Array[TInstr] = []
      let localized_args : Array[TInstr] = []
      for i = 0; i < hoisted_args.length(); i = i + 1 {
        let local_i = caller_param_count + caller_locals.length()
        caller_locals.push(target_params[i])
        let local_idx = il_local_idx_from_int(local_i)
        stores.push(TInstr::local_set(local_idx, hoisted_args[i]))
        localized_args.push(TInstr::local_get(local_idx))
      }
      let ref_local_i = caller_param_count + caller_locals.length()
      caller_locals.push(ValType::funcref())
      let ref_local = il_local_idx_from_int(ref_local_i)
      stores.push(TInstr::local_set(ref_local, ref_))
      let flag_local_i = caller_param_count + caller_locals.length()
      caller_locals.push(ValType::i32())
      let flag_local = il_local_idx_from_int(flag_local_i)
      let flag_init = TInstr::local_set(flag_local, TInstr::i32_const(I32(0)))
      stores.push(TInstr::local_set(flag_local, TInstr::i32_const(I32(1))))
      stores.push(TInstr::unreachable_())
      for placeholder in hoist_placeholders {
        stores.push(placeholder)
      }
      let replacement = TInstr::block(hoist_block_type, TExpr::new(stores))
      let followup = TInstr::if_(
        BlockType::void_(),
        TInstr::local_get(flag_local),
        TExpr::new([
          TInstr::return_call_ref(
            type_idx,
            localized_args,
            TInstr::local_get(ref_local),
          ),
        ]),
        None,
      )
      Ok((replacement, flag_init, followup))
    }
    _ =>
      Err(
        "inlining: hoist currently supports return_call/return_call_indirect/return_call_ref wrappers",
      )
  }
}

///|
fn il_apply_actions_to_func(
  caller_type : FuncType,
  caller_type_idx : TypeIdx?,
  caller_func : Func,
  actions : Map[Int, ILInlineAction],
  funcs_by_abs : Array[Func?],
  env : Env,
  func_types : Array[FuncType],
) -> Result[(Func, Int), String] {
  if actions.is_empty() {
    return Ok((caller_func, 0))
  }
  let FuncType(caller_params, _) = caller_type
  match caller_func {
    TFunc(locals, body) => {
      let caller_locals = locals.copy()
      let FuncType(_, caller_results) = caller_type
      let hoist_wrapper_type = il_make_hoist_wrapper_block_type(
        caller_results, caller_type_idx, env,
      )
      let hoist_placeholders = il_hoist_placeholder_values(caller_results)
      let mut next_id = 0
      let mut applied = 0
      let mut changed = false
      let hoisted_inits : Array[TInstr] = []
      let hoisted_followups : Array[TInstr] = []
      let rewriter = ModuleTransformer::new().on_tinstruction_evt(fn(
        self,
        _,
        instr,
      ) {
        match instr {
          TTryTable(bt, catches, try_body) => {
            let walked_body = match self.walk_texpr((), try_body) {
              Ok(Some((_, next))) => next
              Ok(None) => try_body
              Err(e) => return Err(e)
            }
            if walked_body == try_body {
              unchanged()
            } else {
              changed = true
              change((), TInstr::try_table(bt, catches, walked_body))
            }
          }
          _ => {
            let walked = match self.walk_tinstruction_default((), instr) {
              Ok(Some((_, next))) => next
              Ok(None) => instr
              Err(e) => return Err(e)
            }
            let maybe_action = match walked {
              TCall(fi, args) => {
                let id = next_id
                next_id += 1
                match actions.get(id) {
                  Some(action) => {
                    let FuncIdx(raw) = fi
                    let callee_abs_idx = raw.reinterpret_as_int()
                    if action.callee_abs_idx == callee_abs_idx &&
                      action.kind == ILDirectCall {
                      Some((action, args))
                    } else {
                      None
                    }
                  }
                  None => None
                }
              }
              TReturnCall(fi, args) => {
                let id = next_id
                next_id += 1
                match actions.get(id) {
                  Some(action) => {
                    let FuncIdx(raw) = fi
                    let callee_abs_idx = raw.reinterpret_as_int()
                    if action.callee_abs_idx == callee_abs_idx &&
                      action.kind == ILReturnCall {
                      Some((action, args))
                    } else {
                      None
                    }
                  }
                  None => None
                }
              }
              _ => None
            }
            match maybe_action {
              Some((action, call_args)) =>
                if action.callee_abs_idx < 0 ||
                  action.callee_abs_idx >= funcs_by_abs.length() {
                  Err("inlining: callee index out of range")
                } else {
                  match funcs_by_abs[action.callee_abs_idx] {
                    Some(callee_func) =>
                      if action.kind == ILReturnCall && action.try_depth > 0 {
                        match (hoist_wrapper_type, hoist_placeholders) {
                          (Some(wrapper_type), Some(placeholders)) =>
                            match
                              il_prepare_hoisted_tail_call(
                                callee_func,
                                call_args,
                                caller_params.length(),
                                caller_locals,
                                env,
                                func_types,
                                wrapper_type,
                                placeholders,
                              ) {
                              Ok((replacement, init, followup)) => {
                                hoisted_inits.push(init)
                                hoisted_followups.push(followup)
                                changed = true
                                applied += 1
                                change((), replacement)
                              }
                              Err(e) => Err(e)
                            }
                          _ =>
                            match
                              il_inline_at_callsite(
                                ILInlineAction::{
                                  callsite_id: action.callsite_id,
                                  caller_abs_idx: action.caller_abs_idx,
                                  callee_abs_idx: action.callee_abs_idx,
                                  kind: action.kind,
                                  try_depth: action.try_depth,
                                  force_unreachable: action.force_unreachable,
                                },
                                callee_func,
                                func_types[action.callee_abs_idx],
                                call_args,
                                caller_params.length(),
                                caller_locals,
                              ) {
                              Ok(Some(replacement)) => {
                                changed = true
                                applied += 1
                                change((), replacement)
                              }
                              Ok(None) =>
                                if walked == instr {
                                  unchanged()
                                } else {
                                  change((), walked)
                                }
                              Err(e) => Err(e)
                            }
                        }
                      } else {
                        match
                          il_inline_at_callsite(
                            ILInlineAction::{
                              callsite_id: action.callsite_id,
                              caller_abs_idx: action.caller_abs_idx,
                              callee_abs_idx: action.callee_abs_idx,
                              kind: action.kind,
                              try_depth: action.try_depth,
                              force_unreachable: action.force_unreachable,
                            },
                            callee_func,
                            func_types[action.callee_abs_idx],
                            call_args,
                            caller_params.length(),
                            caller_locals,
                          ) {
                          Ok(Some(replacement)) => {
                            changed = true
                            applied += 1
                            change((), replacement)
                          }
                          Ok(None) =>
                            if walked == instr {
                              unchanged()
                            } else {
                              change((), walked)
                            }
                          Err(e) => Err(e)
                        }
                      }
                    None => Err("inlining: callee function body is missing")
                  }
                }
              None =>
                if walked == instr {
                  unchanged()
                } else {
                  changed = true
                  change((), walked)
                }
            }
          }
        }
      })
      let new_body = match rewriter.walk_texpr((), body) {
        Ok(Some((_, next))) => next
        Ok(None) => body
        Err(e) => return Err(e)
      }
      let final_body = if hoisted_followups.is_empty() {
        new_body
      } else {
        let wrapper_type = match
          il_make_hoist_wrapper_block_type(caller_results, caller_type_idx, env) {
          Some(bt) => bt
          None =>
            return Err(
              "inlining: hoisted tail-call rewrite has no available wrapper block type",
            )
        }
        let wrapped_instrs = hoisted_inits.copy()
        for instr in new_body.0 {
          wrapped_instrs.push(instr)
        }
        let final_instrs : Array[TInstr] = [
          TInstr::block(wrapper_type, TExpr::new(wrapped_instrs)),
        ]
        for instr in hoisted_followups {
          final_instrs.push(instr)
        }
        TExpr::new(final_instrs)
      }
      if changed || caller_locals != locals {
        Ok((Func::t_func(caller_locals, final_body), applied))
      } else {
        Ok((caller_func, 0))
      }
    }
    _ => Ok((caller_func, 0))
  }
}

///|
fn il_run_partial_splitting(
  mod : Module,
  options : OptimizeOptions,
) -> Result[Module, String] {
  if options.optimize_level < 3 ||
    options.shrink_level != 0 ||
    options.inlining.partial_inlining_ifs <= 0 {
    return Ok(mod)
  }
  let import_count = il_count_imported_funcs(mod)
  let func_types = il_collect_func_types(
    mod,
    il_total_functions(mod, import_count),
  )
  let type_idxs = match mod.func_sec {
    Some(FuncSec(items)) => items.copy()
    None => return Ok(mod)
  }
  let funcs = match mod.code_sec {
    Some(CodeSec(items)) => items.copy()
    None => return Ok(mod)
  }
  let original_len = funcs.length()
  let mut changed = false
  let max_ifs = options.inlining.partial_inlining_ifs
  for def_idx = 0; def_idx < original_len; def_idx = def_idx + 1 {
    let abs_idx = import_count + def_idx
    let func_type = func_types[abs_idx]
    let FuncType(params, results) = func_type
    if results.length() != 0 {
      continue
    }
    let curr = funcs[def_idx]
    match curr {
      TFunc(locals, body) => {
        // Pattern A: top-level if (cond) return; then remainder.
        if body.0.length() >= 2 {
          match body.0[0] {
            TIf(VoidBlockType, cond, then_body, None) => {
              let mut has_return = false
              for instr in then_body.0 {
                match instr {
                  TReturn([]) => has_return = true
                  _ => ()
                }
              }
              if has_return {
                let outlined_abs = import_count + funcs.length()
                let outlined_args : Array[TInstr] = []
                for p = 0; p < params.length(); p = p + 1 {
                  outlined_args.push(
                    TInstr::local_get(il_local_idx_from_int(p)),
                  )
                }
                let outlined_instrs : Array[TInstr] = []
                for i = 1; i < body.0.length(); i = i + 1 {
                  outlined_instrs.push(body.0[i])
                }
                funcs.push(Func::t_func(locals, TExpr::new(outlined_instrs)))
                type_idxs.push(type_idxs[def_idx])
                funcs[def_idx] = Func::t_func(
                  locals,
                  TExpr::new([
                    TInstr::if_(BlockType::void_(), cond, then_body, None),
                    TInstr::call(
                      il_func_idx_from_abs(outlined_abs),
                      outlined_args,
                    ),
                  ]),
                )
                changed = true
                continue
              }
            }
            _ => ()
          }
        }

        // Pattern B: 1..MaxIfs top-level ifs, optional trailing item.
        let mut prefix_ifs = 0
        while prefix_ifs < body.0.length() && prefix_ifs < max_ifs {
          match body.0[prefix_ifs] {
            TIf(VoidBlockType, _, _, None) => prefix_ifs += 1
            _ => break
          }
        }
        if prefix_ifs == 0 {
          continue
        }
        if body.0.length() > prefix_ifs + 1 {
          continue
        }
        let trailing = if body.0.length() == prefix_ifs + 1 {
          Some(body.0[prefix_ifs])
        } else {
          None
        }
        let if_writes : Set[LocalIdx] = Set::new()
        let mut invalid = false
        for i = 0; i < prefix_ifs; i = i + 1 {
          match body.0[i] {
            TIf(_, _, then_body, None) => {
              let then_is_unreachable = if then_body.0.length() == 1 {
                match then_body.0[0] {
                  TUnreachable => true
                  _ => false
                }
              } else {
                false
              }
              if !then_is_unreachable {
                let mut has_return = false
                let scan = ModuleTransformer::new().on_tinstruction_evt(fn(
                  self,
                  _,
                  instr,
                ) {
                  match instr {
                    TReturn(_) => has_return = true
                    TLocalSet(idx, _) | TLocalTee(idx, _) => if_writes.add(idx)
                    _ => ()
                  }
                  self.walk_tinstruction_default((), instr)
                })
                ignore(scan.walk_texpr((), then_body))
                if has_return {
                  invalid = true
                }
              }
            }
            _ => invalid = true
          }
        }
        if invalid {
          continue
        }
        match trailing {
          Some(last) => {
            let trailing_reads : Set[LocalIdx] = Set::new()
            let scan = ModuleTransformer::new().on_tinstruction_evt(fn(
              self,
              _,
              instr,
            ) {
              match instr {
                TLocalGet(idx) => trailing_reads.add(idx)
                _ => ()
              }
              self.walk_tinstruction_default((), instr)
            })
            ignore(scan.walk_tinstruction((), last))
            let mut dep = false
            for idx in trailing_reads.iter() {
              if if_writes.contains(idx) {
                dep = true
              }
            }
            if dep {
              continue
            }
          }
          None => ()
        }
        let outlined_args : Array[TInstr] = []
        for p = 0; p < params.length(); p = p + 1 {
          outlined_args.push(TInstr::local_get(il_local_idx_from_int(p)))
        }
        let replaced : Array[TInstr] = []
        for i = 0; i < prefix_ifs; i = i + 1 {
          match body.0[i] {
            TIf(_, cond, then_body, None) => {
              let outlined_abs = import_count + funcs.length()
              funcs.push(Func::t_func(locals, then_body))
              type_idxs.push(type_idxs[def_idx])
              replaced.push(
                TInstr::if_(
                  BlockType::void_(),
                  cond,
                  TExpr::new([
                    TInstr::call(
                      il_func_idx_from_abs(outlined_abs),
                      outlined_args,
                    ),
                  ]),
                  None,
                ),
              )
              changed = true
            }
            _ => ()
          }
        }
        match trailing {
          Some(last) => replaced.push(last)
          None => ()
        }
        if !replaced.is_empty() {
          funcs[def_idx] = Func::t_func(locals, TExpr::new(replaced))
        }
      }
      _ => ()
    }
  }
  if !changed {
    Ok(mod)
  } else {
    Ok(
      mod
      .with_func_sec(FuncSec::new(type_idxs))
      .with_code_sec(CodeSec::new(funcs)),
    )
  }
}

///|
fn il_plan_actions(
  infos : Array[ILFunctionInfo],
  callsites_by_caller : Array[Array[ILCallSite]],
  incoming_counts : Array[Int],
  options : OptimizeOptions,
  import_count : Int,
  inlined_into_count : Array[Int],
  module_size : Int,
) -> Array[ILInlineAction] {
  let prelim : Array[ILInlineAction] = []
  let mut planned_growth = 0
  for caller_abs = 0
      caller_abs < callsites_by_caller.length()
      caller_abs = caller_abs + 1 {
    if caller_abs < import_count {
      continue
    }
    let caller_def = caller_abs - import_count
    if caller_def < 0 || caller_def >= inlined_into_count.length() {
      continue
    }
    if inlined_into_count[caller_def] >= 5 {
      continue
    }
    for site in callsites_by_caller[caller_abs] {
      let callee_abs = site.callee_abs_idx
      if callee_abs < 0 || callee_abs >= infos.length() {
        continue
      }
      if callee_abs == caller_abs {
        continue
      }
      let callee_info = infos[callee_abs]
      let FuncType(_, callee_results) = callee_info.func_type
      let allow_multivalue_tail_wrapper = site.kind == ILReturnCall &&
        callee_info.tail_wrapper &&
        callee_results.length() > 1
      if !allow_multivalue_tail_wrapper &&
        !il_worth_full_inlining(
          callee_info,
          incoming_counts[callee_abs],
          options,
        ) {
        continue
      }
      if site.kind == ILReturnCall && !callee_info.tail_wrapper {
        continue
      }
      let growth = if callee_info.size > 1 { callee_info.size - 1 } else { 0 }
      if module_size + planned_growth + growth >
        options.inlining.max_combined_binary_size {
        continue
      }
      planned_growth += growth
      prelim.push({
        callsite_id: site.id,
        caller_abs_idx: site.caller_abs_idx,
        callee_abs_idx: site.callee_abs_idx,
        kind: site.kind,
        try_depth: site.try_depth,
        force_unreachable: site.force_unreachable,
      })
    }
  }
  let inlined_callees : Set[Int] = Set::new()
  for action in prelim {
    inlined_callees.add(action.callee_abs_idx)
  }
  let final_actions : Array[ILInlineAction] = []
  for action in prelim {
    if !inlined_callees.contains(action.caller_abs_idx) {
      final_actions.push(action)
    }
  }
  final_actions
}

///|
fn il_apply_actions_iteration(
  mod : Module,
  import_count : Int,
  func_types : Array[FuncType],
  funcs_by_abs : Array[Func?],
  actions : Array[ILInlineAction],
) -> Result[(Module, Array[Int], Bool), String] {
  if actions.is_empty() {
    return Ok((mod, [], false))
  }
  let funcs = match mod.code_sec {
    Some(CodeSec(items)) => items.copy()
    None => return Ok((mod, [], false))
  }
  let action_maps : Array[Map[Int, ILInlineAction]] = []
  for i = 0; i < funcs_by_abs.length(); i = i + 1 {
    action_maps.push(Map::new())
  }
  for action in actions {
    if action.caller_abs_idx >= 0 &&
      action.caller_abs_idx < action_maps.length() {
      action_maps[action.caller_abs_idx].set(action.callsite_id, action)
    }
  }
  let applied_by_def : Array[Int] = []
  for i = 0; i < funcs.length(); i = i + 1 {
    applied_by_def.push(0)
  }
  let defined_type_idxs = match mod.func_sec {
    Some(FuncSec(items)) => items.copy()
    None => []
  }
  let mut changed = false
  let env = Env::new().with_module(mod)
  for def_idx = 0; def_idx < funcs.length(); def_idx = def_idx + 1 {
    let abs_idx = import_count + def_idx
    let actions_for_func = action_maps[abs_idx]
    if actions_for_func.is_empty() {
      continue
    }
    let result = match
      il_apply_actions_to_func(
        func_types[abs_idx],
        defined_type_idxs.get(def_idx),
        funcs[def_idx],
        actions_for_func,
        funcs_by_abs,
        env,
        func_types,
      ) {
      Ok(next) => next
      Err(e) => return Err(e)
    }
    let (next_func, applied) = result
    if applied > 0 {
      funcs[def_idx] = next_func
      applied_by_def[def_idx] += applied
      changed = true
    }
  }
  if !changed {
    Ok((mod, applied_by_def, false))
  } else {
    Ok((mod.with_code_sec(CodeSec::new(funcs)), applied_by_def, true))
  }
}

///|
fn inlining(
  mod : Module,
  options : OptimizeOptions,
  optimizing : Bool,
) -> Result[Module, String] {
  let mut mod = mod
  mod = match il_run_partial_splitting(mod, options) {
    Ok(m) => m
    Err(e) => return Err(e)
  }
  let import_count = il_count_imported_funcs(mod)
  let original_defined = match mod.code_sec {
    Some(CodeSec(funcs)) => funcs.length()
    None => 0
  }
  let max_iterations = if original_defined > 0 { original_defined } else { 1 }
  let inlined_into_count : Array[Int] = []
  for i = 0; i < original_defined; i = i + 1 {
    inlined_into_count.push(0)
  }
  let mut changed_any = false
  for iter_i = 0; iter_i < max_iterations; iter_i = iter_i + 1 {
    let total_funcs = il_total_functions(mod, import_count)
    let func_types = il_collect_func_types(mod, total_funcs)
    let funcs_by_abs = il_collect_funcs_by_abs(mod, import_count)
    let infos = il_collect_infos(mod, funcs_by_abs, func_types)
    let callsites_by_caller = il_collect_callsites(mod, import_count)
    let incoming_counts = il_collect_incoming_counts(
      callsites_by_caller, total_funcs,
    )
    let module_size = il_estimate_module_size(infos)
    let actions = il_plan_actions(
      infos, callsites_by_caller, incoming_counts, options, import_count, inlined_into_count,
      module_size,
    )
    if actions.is_empty() {
      break
    }
    let iter = match
      il_apply_actions_iteration(
        mod, import_count, func_types, funcs_by_abs, actions,
      ) {
      Ok(next) => next
      Err(e) => return Err(e)
    }
    let (next_mod, applied_by_def, changed) = iter
    if !changed {
      break
    }
    for i = 0; i < inlined_into_count.length(); i = i + 1 {
      inlined_into_count[i] += applied_by_def[i]
    }
    mod = next_mod
    changed_any = true
  }
  if optimizing && changed_any {
    mod = match
      il_apply_ir_transformer_pass(mod, dead_code_elimination_ir_pass(mod)) {
      Ok(next) => next
      Err(e) => return Err(e)
    }
    mod = match il_apply_ir_transformer_pass(mod, code_folding_ir_pass(mod)) {
      Ok(next) => next
      Err(e) => return Err(e)
    }
  }
  Ok(mod)
}

///|
fn il_find_exported_func(mod : Module, name : String) -> FuncIdx? {
  let expected = Name::new(name)
  match mod.export_sec {
    Some(ExportSec(exports)) =>
      for export_ in exports {
        match export_ {
          Export(n, FuncExternIdx(idx)) if n == expected => return Some(idx)
          _ => ()
        }
      }
    None => ()
  }
  None
}

///|
fn inline_main(
  mod : Module,
  _options : OptimizeOptions,
) -> Result[Module, String] {
  let main_idx = match il_find_exported_func(mod, "main") {
    Some(idx) => idx
    None => return Ok(mod)
  }
  let original_idx = match il_find_exported_func(mod, "__original_main") {
    Some(idx) => idx
    None => return Ok(mod)
  }
  let import_count = il_count_imported_funcs(mod)
  let FuncIdx(main_raw) = main_idx
  let FuncIdx(orig_raw) = original_idx
  let main_abs = main_raw.reinterpret_as_int()
  let orig_abs = orig_raw.reinterpret_as_int()
  if main_abs < import_count || orig_abs < import_count {
    return Ok(mod)
  }
  let main_def = main_abs - import_count
  let funcs = match mod.code_sec {
    Some(CodeSec(items)) => items.copy()
    None => return Ok(mod)
  }
  let main_type_idx = match mod.func_sec {
    Some(FuncSec(items)) => items.get(main_def)
    None => None
  }
  if main_def < 0 || main_def >= funcs.length() {
    return Ok(mod)
  }
  let sites = match funcs[main_def] {
    TFunc(_, body) => il_collect_callsites_for_body(main_abs, body)
    _ => return Ok(mod)
  }
  let target_sites : Array[ILCallSite] = []
  for site in sites {
    if site.kind == ILDirectCall && site.callee_abs_idx == orig_abs {
      target_sites.push(site)
    }
  }
  if target_sites.length() != 1 {
    return Ok(mod)
  }
  let total_funcs = il_total_functions(mod, import_count)
  let func_types = il_collect_func_types(mod, total_funcs)
  let funcs_by_abs = il_collect_funcs_by_abs(mod, import_count)
  let action_map : Map[Int, ILInlineAction] = Map::new()
  let site = target_sites[0]
  action_map.set(site.id, {
    callsite_id: site.id,
    caller_abs_idx: main_abs,
    callee_abs_idx: orig_abs,
    kind: ILDirectCall,
    try_depth: site.try_depth,
    force_unreachable: site.force_unreachable,
  })
  let applied = match
    il_apply_actions_to_func(
      func_types[main_abs],
      main_type_idx,
      funcs[main_def],
      action_map,
      funcs_by_abs,
      Env::new().with_module(mod),
      func_types,
    ) {
    Ok(next) => next
    Err(e) => return Err(e)
  }
  let (new_main, n_applied) = applied
  if n_applied == 0 {
    return Ok(mod)
  }
  funcs[main_def] = new_main
  Ok(mod.with_code_sec(CodeSec::new(funcs)))
}

///|
fn il_make_type(params : Array[ValType], results : Array[ValType]) -> RecType {
  single_rec_type(comp_type_sub_type(func_comp_type(params, results)))
}

///|
fn il_count_calls(body : TExpr, target : FuncIdx) -> Int {
  let mut calls = 0
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TCall(fi, _) | TReturnCall(fi, _) => if fi == target { calls += 1 }
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  calls
}

///|
fn il_count_direct_calls(body : TExpr, target : FuncIdx) -> Int {
  let mut calls = 0
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TCall(fi, _) => if fi == target { calls += 1 }
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  calls
}

///|
fn il_count_return_calls(body : TExpr, target : FuncIdx) -> Int {
  let mut calls = 0
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TReturnCall(fi, _) => if fi == target { calls += 1 }
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  calls
}

///|
fn il_count_return_call_indirects(body : TExpr) -> Int {
  let mut calls = 0
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TReturnCallIndirect(_, _, _, _) => calls += 1
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  calls
}

///|
fn il_count_return_call_refs(body : TExpr) -> Int {
  let mut calls = 0
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TReturnCallRef(_, _, _) => calls += 1
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  calls
}

///|
fn il_has_return(body : TExpr) -> Bool {
  let mut found = false
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TReturn(_) => found = true
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  found
}

///|
fn il_count_br_to(body : TExpr, label : LabelIdx) -> Int {
  let mut found = 0
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TBr(li, _) => if li == label { found += 1 }
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  found
}

///|
fn il_make_simple_two_func_module(
  caller_type : RecType,
  callee_type : RecType,
  caller_body : TExpr,
  callee_locals : Array[ValType],
  callee_body : TExpr,
) -> Module {
  Module::new()
  .with_type_sec(TypeSec::new([caller_type, callee_type]))
  .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func([], caller_body),
      Func::t_func(callee_locals, callee_body),
    ]),
  )
}

///|
test "inlining always-inlines tiny callee by default" {
  let mod = il_make_simple_two_func_module(
    il_make_type([], [ValType::i32()]),
    il_make_type([ValType::i32()], [ValType::i32()]),
    TExpr::new([TInstr::call(FuncIdx::new(1), [TInstr::i32_const(I32(7))])]),
    [],
    TExpr::new([TInstr::local_get(LocalIdx::new(0))]),
  )
  let optimized = match inlining(mod, OptimizeOptions::new(), false) {
    Ok(m) => m
    Err(e) => fail("unexpected inlining error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, body), _])) =>
      assert_eq(il_count_direct_calls(body, FuncIdx::new(1)), 0)
    _ => fail("expected caller body")
  }
}

///|
test "inlining honors one-caller-inline-max-size threshold" {
  let mod = il_make_simple_two_func_module(
    il_make_type([], [ValType::i32()]),
    il_make_type([ValType::i32()], [ValType::i32()]),
    TExpr::new([TInstr::call(FuncIdx::new(1), [TInstr::i32_const(I32(7))])]),
    [],
    TExpr::new([
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(1)),
      ),
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(2)),
      ),
      TInstr::local_get(LocalIdx::new(0)),
    ]),
  )
  let options = OptimizeOptions::new(
    inlining=InliningOptions::new(
      always_inline_max_size=0,
      one_caller_inline_max_size=1,
      flexible_inline_max_size=0,
    ),
  )
  let optimized = match inlining(mod, options, false) {
    Ok(m) => m
    Err(e) => fail("unexpected inlining error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, body), _])) =>
      assert_eq(il_count_direct_calls(body, FuncIdx::new(1)), 1)
    _ => fail("expected caller body")
  }
}

///|
test "inlining can inline multi-use callee at higher optimize levels" {
  let t0 = il_make_type([], [])
  let t1 = il_make_type([ValType::i32()], [ValType::i32()])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0, t1]))
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(0), TypeIdx::new(1)]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::drop(
              TInstr::call(FuncIdx::new(2), [TInstr::i32_const(I32(1))]),
            ),
          ]),
        ),
        Func::t_func(
          [],
          TExpr::new([
            TInstr::drop(
              TInstr::call(FuncIdx::new(2), [TInstr::i32_const(I32(2))]),
            ),
          ]),
        ),
        Func::t_func([], TExpr::new([TInstr::local_get(LocalIdx::new(0))])),
      ]),
    )
  let options = OptimizeOptions::new(optimize_level=3, shrink_level=0)
  let optimized = match inlining(mod, options, false) {
    Ok(m) => m
    Err(e) => fail("unexpected inlining error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, body0), TFunc(_, body1), _])) => {
      assert_eq(il_count_direct_calls(body0, FuncIdx::new(2)), 0)
      assert_eq(il_count_direct_calls(body1, FuncIdx::new(2)), 0)
    }
    _ => fail("expected caller bodies")
  }
}

///|
test "inlining enforces maxCombinedBinarySize growth cap" {
  let mod = il_make_simple_two_func_module(
    il_make_type([], [ValType::i32()]),
    il_make_type([ValType::i32()], [ValType::i32()]),
    TExpr::new([TInstr::call(FuncIdx::new(1), [TInstr::i32_const(I32(7))])]),
    [],
    TExpr::new([TInstr::local_get(LocalIdx::new(0))]),
  )
  let options = OptimizeOptions::new(
    inlining=InliningOptions::new(max_combined_binary_size=1),
  )
  let optimized = match inlining(mod, options, false) {
    Ok(m) => m
    Err(e) => fail("unexpected inlining error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, body), _])) =>
      assert_eq(il_count_direct_calls(body, FuncIdx::new(1)), 1)
    _ => fail("expected caller body")
  }
}

///|
test "inlining only plans callsites in reachable code" {
  let mod = il_make_simple_two_func_module(
    il_make_type([], []),
    il_make_type([], []),
    TExpr::new([TInstr::unreachable_(), TInstr::call(FuncIdx::new(1), [])]),
    [],
    TExpr::new([TInstr::nop()]),
  )
  let optimized = match inlining(mod, OptimizeOptions::new(), false) {
    Ok(m) => m
    Err(e) => fail("unexpected inlining error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, body), _])) =>
      // Unreachable tail call must not be considered for inlining.
      assert_eq(il_count_direct_calls(body, FuncIdx::new(1)), 1)
    _ => fail("expected caller body")
  }
}

///|
test "inlining shifts callee branch labels when wrapping callsite" {
  let mod = il_make_simple_two_func_module(
    il_make_type([], []),
    il_make_type([], []),
    TExpr::new([TInstr::call(FuncIdx::new(1), [])]),
    [],
    TExpr::new([
      TInstr::block(
        BlockType::void_(),
        TExpr::new([TInstr::br(LabelIdx::new(0), [])]),
      ),
    ]),
  )
  let optimized = match inlining(mod, OptimizeOptions::new(), false) {
    Ok(m) => m
    Err(e) => fail("unexpected inlining error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, body), _])) =>
      assert_true(il_count_br_to(body, LabelIdx::new(1)) > 0)
    _ => fail("expected caller body")
  }
}

///|
test "inlining maps locals and only zero-inits defaultable callee locals" {
  let mod = il_make_simple_two_func_module(
    il_make_type([], []),
    il_make_type([ValType::i32()], []),
    TExpr::new([
      TInstr::drop(TInstr::call(FuncIdx::new(1), [TInstr::i32_const(I32(5))])),
    ]),
    [ValType::i32(), ValType::i31ref()],
    TExpr::new([TInstr::drop(TInstr::local_get(LocalIdx::new(1)))]),
  )
  let optimized = match inlining(mod, OptimizeOptions::new(), false) {
    Ok(m) => m
    Err(e) => fail("unexpected inlining error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(locals, body), _])) => {
      assert_true(locals.length() >= 2)
      let mut has_i32_zero = false
      let mut has_ref_null_init = false
      let walker = ModuleTransformer::new().on_tinstruction_evt(fn(
        self,
        _,
        instr,
      ) {
        match instr {
          TLocalSet(_, TI32Const(I32(0))) => has_i32_zero = true
          TLocalSet(_, TRefNull(_)) => has_ref_null_init = true
          _ => ()
        }
        self.walk_tinstruction_default((), instr)
      })
      ignore(walker.walk_texpr((), body))
      assert_true(has_i32_zero)
      assert_false(has_ref_null_init)
    }
    _ => fail("expected caller body")
  }
}

///|
test "inlining rewrites returns in callee body into breaks from wrapper" {
  let mod = il_make_simple_two_func_module(
    il_make_type([], [ValType::i32()]),
    il_make_type([], [ValType::i32()]),
    TExpr::new([TInstr::call(FuncIdx::new(1), [])]),
    [],
    TExpr::new([TInstr::return_([TInstr::i32_const(I32(9))])]),
  )
  let optimized = match inlining(mod, OptimizeOptions::new(), false) {
    Ok(m) => m
    Err(e) => fail("unexpected inlining error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, body), _])) => {
      assert_false(il_has_return(body))
      assert_true(il_count_br_to(body, LabelIdx::new(0)) > 0)
    }
    _ => fail("expected caller body")
  }
}

///|
test "inlining rewrites return_call in normal context to call plus break" {
  let t0 = il_make_type([], [ValType::i32()])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(0), TypeIdx::new(0)]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(1), [])])),
        Func::t_func([], TExpr::new([TInstr::return_call(FuncIdx::new(2), [])])),
        Func::t_func([], TExpr::new([TInstr::i32_const(I32(11))])),
      ]),
    )
  let optimized = match inlining(mod, OptimizeOptions::new(), false) {
    Ok(m) => m
    Err(e) => fail("unexpected inlining error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, body), _, _])) => {
      assert_eq(il_count_return_calls(body, FuncIdx::new(2)), 0)
      assert_eq(il_count_direct_calls(body, FuncIdx::new(1)), 0)
      assert_true(il_count_br_to(body, LabelIdx::new(0)) > 0)
    }
    _ => fail("expected caller body")
  }
}

///|
test "inlining preserves return_call chaining for tail-call callsites" {
  let t0 = il_make_type([], [ValType::i32()])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(0), TypeIdx::new(0)]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], TExpr::new([TInstr::return_call(FuncIdx::new(1), [])])),
        Func::t_func([], TExpr::new([TInstr::return_call(FuncIdx::new(2), [])])),
        Func::t_func([], TExpr::new([TInstr::i32_const(I32(4))])),
      ]),
    )
  let optimized = match inlining(mod, OptimizeOptions::new(), false) {
    Ok(m) => m
    Err(e) => fail("unexpected inlining error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, body), _, _])) =>
      assert_true(il_count_return_calls(body, FuncIdx::new(2)) > 0)
    _ => fail("expected caller body")
  }
}

///|
test "inlining rewrites return_call under try_table context" {
  let t0 = il_make_type([], [ValType::i32()])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(0), TypeIdx::new(0)]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::try_table(
              BlockType::val_type(ValType::i32()),
              [],
              TExpr::new([TInstr::call(FuncIdx::new(1), [])]),
            ),
          ]),
        ),
        Func::t_func([], TExpr::new([TInstr::return_call(FuncIdx::new(2), [])])),
        Func::t_func([], TExpr::new([TInstr::i32_const(I32(3))])),
      ]),
    )
  let optimized = match inlining(mod, OptimizeOptions::new(), false) {
    Ok(m) => m
    Err(e) => fail("unexpected inlining error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, body), _, _])) =>
      assert_eq(il_count_calls(body, FuncIdx::new(1)), 0)
    _ => fail("expected caller body")
  }
}

///|
test "inlining hoists tail-call inlining out of try_table context" {
  let t0 = il_make_type([], [ValType::i32()])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(0), TypeIdx::new(0)]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::try_table(
              BlockType::val_type(ValType::i32()),
              [],
              TExpr::new([TInstr::return_call(FuncIdx::new(1), [])]),
            ),
          ]),
        ),
        Func::t_func([], TExpr::new([TInstr::return_call(FuncIdx::new(2), [])])),
        Func::t_func([], TExpr::new([TInstr::i32_const(I32(19))])),
      ]),
    )
  let optimized = match inlining(mod, OptimizeOptions::new(), false) {
    Ok(m) => m
    Err(e) => fail("unexpected inlining error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, body), _, _])) => {
      // Wrapper return_call should be gone and target return_call must remain.
      assert_eq(il_count_return_calls(body, FuncIdx::new(1)), 0)
      assert_true(il_count_return_calls(body, FuncIdx::new(2)) > 0)
      match body.0 {
        [TBlock(_, _), TIf(_, _, _, _)] => ()
        _ => fail("expected hoisted control flow shape for try tail-call")
      }
    }
    _ => fail("expected caller body")
  }
}

///|
test "inlining hoists tail-call-indirect inlining out of try_table context" {
  let t0 = il_make_type([], [ValType::i32()])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(0), TypeIdx::new(0)]),
    )
    .with_table_sec(
      TableSec::new([
        Table::new(
          TableType::new(
            RefType::new(true, HeapType::abs(AbsHeapType::func())),
            Limits::i32(1, Some(1)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      ElemSec::new([
        Elem::new(
          ElemMode::active(
            TableIdx::new(0),
            Expr::new([Instruction::i32_const(I32(0))]),
          ),
          ElemKind::funcs([FuncIdx::new(2)]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::try_table(
              BlockType::val_type(ValType::i32()),
              [],
              TExpr::new([TInstr::return_call(FuncIdx::new(1), [])]),
            ),
          ]),
        ),
        Func::t_func(
          [],
          TExpr::new([
            TInstr::return_call_indirect(
              TypeIdx::new(0),
              TableIdx::new(0),
              [],
              TInstr::i32_const(I32(0)),
            ),
          ]),
        ),
        Func::t_func([], TExpr::new([TInstr::i32_const(I32(23))])),
      ]),
    )
  let optimized = match inlining(mod, OptimizeOptions::new(), false) {
    Ok(m) => m
    Err(e) => fail("unexpected inlining error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, body), _, _])) => {
      assert_eq(il_count_return_calls(body, FuncIdx::new(1)), 0)
      assert_true(il_count_return_call_indirects(body) > 0)
      match body.0 {
        [TBlock(_, _), TIf(_, _, _, _)] => ()
        _ =>
          fail("expected hoisted control flow shape for try tail-call-indirect")
      }
    }
    _ => fail("expected caller body")
  }
}

///|
test "inlining hoists tail-call-ref inlining out of try_table context" {
  let t0 = il_make_type([], [ValType::i32()])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(0), TypeIdx::new(0)]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::try_table(
              BlockType::val_type(ValType::i32()),
              [],
              TExpr::new([TInstr::return_call(FuncIdx::new(1), [])]),
            ),
          ]),
        ),
        Func::t_func(
          [],
          TExpr::new([
            TInstr::return_call_ref(
              TypeIdx::new(0),
              [],
              TInstr::ref_func(FuncIdx::new(2)),
            ),
          ]),
        ),
        Func::t_func([], TExpr::new([TInstr::i32_const(I32(29))])),
      ]),
    )
  let optimized = match inlining(mod, OptimizeOptions::new(), false) {
    Ok(m) => m
    Err(e) => fail("unexpected inlining error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, body), _, _])) => {
      assert_eq(il_count_return_calls(body, FuncIdx::new(1)), 0)
      assert_true(il_count_return_call_refs(body) > 0)
      match body.0 {
        [TBlock(_, _), TIf(_, _, _, _)] => ()
        _ => fail("expected hoisted control flow shape for try tail-call-ref")
      }
    }
    _ => fail("expected caller body")
  }
}

///|
test "inlining hoists multi-value tail-call wrapper out of try_table context" {
  let t_multi = il_make_type([], [ValType::i32(), ValType::i32()])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_multi]))
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(0), TypeIdx::new(0)]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::try_table(
              BlockType::type_idx(TypeIdx::new(0)),
              [],
              TExpr::new([TInstr::return_call(FuncIdx::new(1), [])]),
            ),
          ]),
        ),
        Func::t_func([], TExpr::new([TInstr::return_call(FuncIdx::new(2), [])])),
        Func::t_func(
          [],
          TExpr::new([
            TInstr::return_([
              TInstr::i32_const(I32(31)),
              TInstr::i32_const(I32(32)),
            ]),
          ]),
        ),
      ]),
    )
  let optimized = match inlining(mod, OptimizeOptions::new(), false) {
    Ok(m) => m
    Err(e) => fail("unexpected inlining error: \{e}")
  }
  assert_eq(validate_module(optimized), Ok(()))
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, body), _, _])) => {
      assert_eq(il_count_return_calls(body, FuncIdx::new(1)), 0)
      assert_true(il_count_return_calls(body, FuncIdx::new(2)) > 0)
      match body.0 {
        [TBlock(bt, _), TIf(_, _, _, _)] =>
          match bt {
            TypeIdxBlockType(_) => ()
            _ => fail("expected typed block wrapper for multi-value hoist")
          }
        _ =>
          fail(
            "expected hoisted control flow shape for try multi-value tail-call",
          )
      }
    }
    _ => fail("expected caller body")
  }
}

///|
test "inlining hoists multi-value tail-call-indirect wrapper out of try_table context" {
  let t_multi = il_make_type([], [ValType::i32(), ValType::i32()])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_multi]))
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(0), TypeIdx::new(0)]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::try_table(
              BlockType::type_idx(TypeIdx::new(0)),
              [],
              TExpr::new([TInstr::return_call(FuncIdx::new(1), [])]),
            ),
          ]),
        ),
        Func::t_func(
          [],
          TExpr::new([
            TInstr::return_call_indirect(
              TypeIdx::new(0),
              TableIdx::new(0),
              [],
              TInstr::i32_const(I32(0)),
            ),
          ]),
        ),
        Func::t_func(
          [],
          TExpr::new([
            TInstr::return_([
              TInstr::i32_const(I32(41)),
              TInstr::i32_const(I32(42)),
            ]),
          ]),
        ),
      ]),
    )
  let optimized = match inlining(mod, OptimizeOptions::new(), false) {
    Ok(m) => m
    Err(e) => fail("unexpected inlining error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, body), _, _])) => {
      assert_eq(il_count_return_calls(body, FuncIdx::new(1)), 0)
      assert_true(il_count_return_call_indirects(body) > 0)
      match body.0 {
        [TBlock(bt, _), TIf(_, _, _, _)] =>
          match bt {
            TypeIdxBlockType(_) => ()
            _ => fail("expected typed block wrapper for multi-value hoist")
          }
        _ =>
          fail(
            "expected hoisted control flow shape for try multi-value tail-call-indirect",
          )
      }
    }
    _ => fail("expected caller body")
  }
}

///|
test "inlining hoists multi-value tail-call-ref wrapper out of try_table context" {
  let t_multi = il_make_type([], [ValType::i32(), ValType::i32()])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_multi]))
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(0), TypeIdx::new(0)]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::try_table(
              BlockType::type_idx(TypeIdx::new(0)),
              [],
              TExpr::new([TInstr::return_call(FuncIdx::new(1), [])]),
            ),
          ]),
        ),
        Func::t_func(
          [],
          TExpr::new([
            TInstr::return_call_ref(
              TypeIdx::new(0),
              [],
              TInstr::ref_func(FuncIdx::new(2)),
            ),
          ]),
        ),
        Func::t_func(
          [],
          TExpr::new([
            TInstr::return_([
              TInstr::i32_const(I32(51)),
              TInstr::i32_const(I32(52)),
            ]),
          ]),
        ),
      ]),
    )
  let optimized = match inlining(mod, OptimizeOptions::new(), false) {
    Ok(m) => m
    Err(e) => fail("unexpected inlining error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, body), _, _])) => {
      assert_eq(il_count_return_calls(body, FuncIdx::new(1)), 0)
      assert_true(il_count_return_call_refs(body) > 0)
      match body.0 {
        [TBlock(bt, _), TIf(_, _, _, _)] =>
          match bt {
            TypeIdxBlockType(_) => ()
            _ => fail("expected typed block wrapper for multi-value hoist")
          }
        _ =>
          fail(
            "expected hoisted control flow shape for try multi-value tail-call-ref",
          )
      }
    }
    _ => fail("expected caller body")
  }
}

///|
test "inlining split pattern A can outline post-if path" {
  let t0 = il_make_type([ValType::i32()], [])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([TInstr::return_([])]),
              None,
            ),
            TInstr::nop(),
          ]),
        ),
      ]),
    )
  let options = OptimizeOptions::new(
    optimize_level=3,
    shrink_level=0,
    inlining=InliningOptions::new(partial_inlining_ifs=1),
  )
  let optimized = match inlining(mod, options, false) {
    Ok(m) => m
    Err(e) => fail("unexpected inlining error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec(funcs)) => assert_true(funcs.length() >= 2)
    _ => fail("expected code section")
  }
}

///|
test "inlining split pattern B rejects local dependency in trailing item" {
  let t0 = il_make_type([ValType::i32()], [])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([
                TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(9))),
              ]),
              None,
            ),
            TInstr::drop(TInstr::local_get(LocalIdx::new(1))),
          ]),
        ),
      ]),
    )
  let options = OptimizeOptions::new(
    optimize_level=3,
    shrink_level=0,
    inlining=InliningOptions::new(partial_inlining_ifs=2),
  )
  let optimized = match inlining(mod, options, false) {
    Ok(m) => m
    Err(e) => fail("unexpected inlining error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 1)
    _ => fail("expected code section")
  }
}

///|
test "inline_main inlines __original_main into main on a single callsite" {
  let t0 = il_make_type([], [])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)]))
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(0))),
        Export::new(
          Name::new("__original_main"),
          ExternIdx::func(FuncIdx::new(1)),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(1), [])])),
        Func::t_func([], TExpr::new([TInstr::nop()])),
      ]),
    )
  let optimized = match inline_main(mod, OptimizeOptions::new()) {
    Ok(m) => m
    Err(e) => fail("unexpected inline_main error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, body), _])) =>
      assert_eq(il_count_direct_calls(body, FuncIdx::new(1)), 0)
    _ => fail("expected main body")
  }
}

///|
test "inline_main skips when main has zero __original_main callsites" {
  let t0 = il_make_type([], [])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)]))
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(0))),
        Export::new(
          Name::new("__original_main"),
          ExternIdx::func(FuncIdx::new(1)),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], TExpr::new([TInstr::nop()])),
        Func::t_func([], TExpr::new([TInstr::nop()])),
      ]),
    )
  let optimized = match inline_main(mod, OptimizeOptions::new()) {
    Ok(m) => m
    Err(e) => fail("unexpected inline_main error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, body), _])) =>
      assert_eq(il_count_direct_calls(body, FuncIdx::new(1)), 0)
    _ => fail("expected main body")
  }
}

///|
test "inline_main skips when main has multiple __original_main callsites" {
  let t0 = il_make_type([], [])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)]))
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(0))),
        Export::new(
          Name::new("__original_main"),
          ExternIdx::func(FuncIdx::new(1)),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::call(FuncIdx::new(1), []),
            TInstr::call(FuncIdx::new(1), []),
          ]),
        ),
        Func::t_func([], TExpr::new([TInstr::nop()])),
      ]),
    )
  let optimized = match inline_main(mod, OptimizeOptions::new()) {
    Ok(m) => m
    Err(e) => fail("unexpected inline_main error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, body), _])) =>
      assert_eq(il_count_direct_calls(body, FuncIdx::new(1)), 2)
    _ => fail("expected main body")
  }
}
