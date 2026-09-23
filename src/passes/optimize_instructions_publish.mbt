///|
fn oi_publish_fresh(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.StructNew(_)
    | @lib.StructNewDefault(_)
    | @lib.ArrayNew(_)
    | @lib.ArrayNewDefault(_)
    | @lib.ArrayNewFixed(_, _)
    | @lib.ArrayNewData(_, _)
    | @lib.ArrayNewElem(_, _) => true
    _ => false
  }
}

///|
fn oi_publish_local_unshared(
  local_idx : @lib.LocalIdx,
  params : Array[@lib.ValType],
  subtypes : Array[@lib.SubType],
) -> Bool {
  let @lib.LocalIdx(raw) = local_idx
  let index = raw.to_int()
  if index < 0 || index >= params.length() {
    return false
  }
  match params[index] {
    @lib.RefTypeValType(
      @lib.HeapTypeRefType(_, _, @lib.HeapType(@lib.TypeIdx(type_raw)))
    ) => {
      let type_index = type_raw.to_int()
      type_index >= 0 &&
      type_index < subtypes.length() &&
      !subtypes[type_index].metadata().is_shared()
    }
    _ => false
  }
}

///|
fn oi_publish_rewrite_instrs(
  instrs : Array[@lib.Instruction],
  params : Array[@lib.ValType],
  subtypes : Array[@lib.SubType],
  changed : Array[Bool],
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    match instr {
      @lib.Block(block_type, @lib.Expr(body)) =>
        out.push(
          @lib.Instruction::block(
            block_type,
            @lib.Expr::new(
              oi_publish_rewrite_instrs(body, params, subtypes, changed),
            ),
          ),
        )
      @lib.Loop(block_type, @lib.Expr(body)) =>
        out.push(
          @lib.Instruction::loop_(
            block_type,
            @lib.Expr::new(
              oi_publish_rewrite_instrs(body, params, subtypes, changed),
            ),
          ),
        )
      @lib.If(block_type, then_body, else_body) => {
        let next_then = oi_publish_rewrite_instrs(
          then_body, params, subtypes, changed,
        )
        let next_else = match else_body {
          Some(body) =>
            Some(oi_publish_rewrite_instrs(body, params, subtypes, changed))
          None => None
        }
        out.push(@lib.Instruction::if_(block_type, next_then, next_else))
      }
      @lib.Publish => {
        let n = out.length()
        if n == 0 {
          out.push(instr)
          continue
        }
        let last = out[n - 1]
        if oi_publish_fresh(last) || last is @lib.Publish {
          changed[0] = true
        } else if last is @lib.RefAsNonNull &&
          n >= 2 &&
          oi_publish_fresh(out[n - 2]) {
          ignore(out.pop())
          changed[0] = true
        } else if last is @lib.LocalGet(local_idx) &&
          oi_publish_local_unshared(local_idx, params, subtypes) {
          changed[0] = true
        } else {
          match last {
            @lib.Block(_, @lib.Expr(body)) if !body.is_empty() => {
              let final_instr = body[body.length() - 1]
              if (oi_publish_fresh(final_instr) || final_instr is @lib.Publish) &&
                body.all(fn(item) {
                  item is @lib.Nop ||
                  item is @lib.LocalGet(_) ||
                  item is @lib.I32Const(_) ||
                  oi_publish_fresh(item) ||
                  item is @lib.Publish
                }) {
                ignore(out.pop())
                for item in body {
                  if !(item is @lib.Nop) {
                    out.push(item)
                  }
                }
                changed[0] = true
              } else {
                out.push(instr)
              }
            }
            _ => out.push(instr)
          }
        }
      }
      _ => out.push(instr)
    }
  }
  out
}

///|
fn oi_publish_rewrite_func(
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
  func : @lib.Func,
) -> @lib.Func? {
  let call_types = msf_build_call_type_cache(mod_)
  let @lib.FuncIdx(raw) = func_idx
  let index = raw.to_int()
  if index < 0 || index >= call_types.length() {
    return None
  }
  let type_idx = match call_types[index] {
    Some(type_idx) => type_idx
    None => return None
  }
  let signatures = msf_build_type_signature_cache(mod_)
  let params = match msf_cached_signature(signatures, type_idx) {
    Some(@lib.FuncType(params, _)) => params
    None => return None
  }
  let subtypes = cl_module_subtypes(mod_)
  let @lib.Func(locals, @lib.Expr(body)) = func
  let changed = [false]
  let next = oi_publish_rewrite_instrs(body, params, subtypes, changed)
  if changed[0] {
    Some(@lib.Func::new(locals, @lib.Expr::new(next)))
  } else {
    None
  }
}
