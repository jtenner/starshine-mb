///|
fn il_import_targets(mod_ : @lib.Module) -> Array[Bool] {
  let targets : Array[Bool] = []
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(module_name, field_name, @lib.FuncExternType(_)) =>
            targets.push(
              module_name == @lib.Name::from_string("binaryen-intrinsics") &&
              field_name == @lib.Name::from_string("call.without.effects"),
            )
          _ => ()
        }
      }
    None => ()
  }
  targets
}

///|
fn il_local_target_type(
  params : Array[@lib.ValType],
  local : @lib.LocalIdx,
) -> @lib.TypeIdx? {
  let @lib.LocalIdx(raw) = local
  let index = raw.to_int()
  if index < 0 || index >= params.length() {
    return None
  }
  match params[index] {
    @lib.RefTypeValType(@lib.HeapTypeRefType(_, _, @lib.HeapType(type_idx))) =>
      Some(type_idx)
    _ => None
  }
}

///|
fn il_rewrite_expr(
  expr : @lib.Expr,
  targets : Array[Bool],
  params : Array[@lib.ValType],
  changed : Array[Bool],
) -> @lib.Expr {
  let @lib.Expr(instrs) = expr
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    match instr {
      @lib.Block(block_type, body) =>
        out.push(
          @lib.Instruction::block(
            block_type,
            il_rewrite_expr(body, targets, params, changed),
          ),
        )
      @lib.Loop(block_type, body) =>
        out.push(
          @lib.Instruction::loop_(
            block_type,
            il_rewrite_expr(body, targets, params, changed),
          ),
        )
      @lib.If(block_type, then_body, else_body) => {
        let @lib.Expr(next_then) = il_rewrite_expr(
          @lib.Expr::new(then_body),
          targets,
          params,
          changed,
        )
        let next_else = match else_body {
          Some(body) => {
            let @lib.Expr(next_body) = il_rewrite_expr(
              @lib.Expr::new(body),
              targets,
              params,
              changed,
            )
            Some(next_body)
          }
          None => None
        }
        out.push(@lib.Instruction::if_(block_type, next_then, next_else))
      }
      @lib.Call(target) | @lib.ReturnCall(target) => {
        let @lib.FuncIdx(raw) = target
        let index = raw.to_int()
        if index < 0 ||
          index >= targets.length() ||
          !targets[index] ||
          out.is_empty() {
          out.push(instr)
          continue
        }
        match out[out.length() - 1] {
          @lib.RefFunc(callee) => {
            ignore(out.pop())
            if instr is @lib.ReturnCall(_) {
              out.push(@lib.Instruction::return_call(callee))
            } else {
              out.push(@lib.Instruction::call(callee))
            }
            changed[0] = true
          }
          @lib.LocalGet(local) =>
            match il_local_target_type(params, local) {
              Some(type_idx) => {
                if instr is @lib.ReturnCall(_) {
                  out.push(@lib.Instruction::return_call_ref(type_idx))
                } else {
                  out.push(@lib.Instruction::call_ref(type_idx))
                }
                changed[0] = true
              }
              None => out.push(instr)
            }
          _ => out.push(instr)
        }
      }
      _ => out.push(instr)
    }
  }
  @lib.Expr::new(out)
}

///|
fn intrinsic_lowering_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  let type_indices = match mod_.func_sec {
    Some(@lib.FuncSec(type_indices)) => type_indices
    None => return mod_
  }
  if type_indices.length() != funcs.length() {
    return mod_
  }
  let signatures = msf_build_type_signature_cache(mod_)
  let targets = il_import_targets(mod_)
  let changed = [false]
  let rewritten : Array[@lib.Func] = []
  for index, func in funcs {
    let @lib.Func(locals, body) = func
    let params = match msf_cached_signature(signatures, type_indices[index]) {
      Some(@lib.FuncType(params, _)) => params
      None => []
    }
    rewritten.push(
      @lib.Func::new(locals, il_rewrite_expr(body, targets, params, changed)),
    )
  }
  if !changed[0] {
    return mod_
  }
  let candidate = mod_.with_code_sec(@lib.CodeSec::new(rewritten))
  if @validate.validate_module(candidate).is_ok() {
    candidate
  } else {
    mod_
  }
}
