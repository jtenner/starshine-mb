///|
// The HOT rewrite keeps the exact target type until writeback, where casts
// and their descriptor operands have already been checked. At this final
// encoding boundary, a bottom null is a subtype of the nullable result.
fn oi_cleanup_descriptor_encoding(
  mod_ : @lib.Module,
  touched? : Array[Bool]? = None,
) -> @lib.Module {
  if !oi_descriptor_encoding_has_pair(mod_) ||
    !mod_.custom_secs.is_empty() ||
    mod_.name_sec is Some(_) ||
    mod_.raw_name_sec_payload is Some(_) ||
    oi_local_group_has_offset_metadata(mod_) {
    return mod_
  }
  let body_cleaned = oi_cleanup_descriptor_terminal_bodies(mod_, touched~)
  if pass_encoding_cleanup_may_remap_types(body_cleaned, touched) {
    oi_prune_unused_descriptor_func_types(body_cleaned)
  } else {
    body_cleaned
  }
}

///|
fn oi_descriptor_encoding_has_pair(mod_ : @lib.Module) -> Bool {
  match mod_.type_sec {
    Some(@lib.TypeSec(groups)) if groups.length() > 0 =>
      match groups[0] {
        @lib.GroupRecType(members) if members.length() == 2 =>
          members[0].descriptor_type() == Some(@lib.TypeIdx::new(1U)) &&
          members[1].describes_type() == Some(@lib.TypeIdx::new(0U))
        _ => false
      }
    _ => false
  }
}

///|
fn oi_cleanup_descriptor_terminal_bodies(
  mod_ : @lib.Module,
  touched? : Array[Bool]? = None,
) -> @lib.Module {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  let env = @validate.Env::new().with_module(mod_)
  let mut changed = false
  let rewritten = funcs.mapi(fn(index, func) {
    if touched is Some(selected) &&
      (index >= selected.length() || !selected[index]) {
      return func
    }
    let @lib.Func(locals, @lib.Expr(body)) = func
    if body.is_empty() {
      return func
    }
    let next = body.copy()
    let last = next.length() - 1
    // The prefix must have no control transfer or use of the block label.
    // Its effects stay ordered, and the terminal trap never produces a value.
    match next[last] {
      @lib.Block(block_type, @lib.Expr(child)) if !child.is_empty() &&
        child[child.length() - 1] is @lib.Unreachable => {
        let prefix = child[0:child.length() - 1].to_array()
        let (_, _, branchless) = pass_lower_flatten_branchless_blocks(
          prefix, env,
        )
        if branchless {
          match env.expand_blocktype(block_type) {
            Ok((params, _)) if params.is_empty() => {
              ignore(next.pop())
              for instr in child {
                next.push(instr)
              }
            }
            _ => ()
          }
        }
      }
      _ => ()
    }
    let final_idx = next.length() - 1
    match next[final_idx] {
      @lib.RefNull(ref_type) if ref_type.is_nullable() &&
        ref_type.get_heap_type() == @lib.HeapType::new(@lib.TypeIdx::new(0U)) =>
        next[final_idx] = @lib.Instruction::ref_null(
          @lib.HeapType::abs(@lib.AbsHeapType::none()),
        )
      _ => ()
    }
    if next == body {
      return func
    }
    changed = true
    @lib.Func::new(locals, @lib.Expr::new(next))
  })
  if !changed {
    return mod_
  }
  let candidate = mod_.with_code_sec(@lib.CodeSec::new(rewritten))
  let baseline = if mod_.compiler_fact_custom_section is Some(_) {
    mod_.without_compiler_fact_custom_section()
  } else {
    mod_
  }
  match @binary.encoded_module_sizes(baseline, candidate) {
    Ok((old_size, new_size)) if new_size < old_size =>
      if @validate.validate_module(candidate) is Ok(_) {
        return candidate
      }
    _ => ()
  }
  mod_
}

///|
// Keep this two-member recursive descriptor pair and remove only standalone
// function signatures that no module root or retained type references. The
// DFE collector and remapper cover the descriptor forms in this pair and the
// plain function types eligible for removal.
fn oi_prune_unused_descriptor_func_types(mod_ : @lib.Module) -> @lib.Module {
  let groups = match mod_.type_sec {
    Some(@lib.TypeSec(groups)) => groups
    None => return mod_
  }
  if groups.length() < 2 {
    return mod_
  }
  for idx = 1; idx < groups.length(); idx = idx + 1 {
    match groups[idx] {
      @lib.SingleRecType(subtype) => {
        if subtype.metadata().is_shared() ||
          subtype.super_types().length() > 0 ||
          subtype.describes_type() is Some(_) ||
          subtype.descriptor_type() is Some(_) {
          return mod_
        }
        match subtype.get_comptype() {
          @lib.FuncCompType(_, _) => ()
          _ => return mod_
        }
      }
      _ => return mod_
    }
  }
  // The recursive pair occupies flat indices 0 and 1. Each suffix
  // SingleRecType occupies one subsequent index.
  let live : Array[Bool] = Array::make(groups.length() + 1, false)
  live[0] = true
  live[1] = true
  let refs : DfeTypeRefs = { live, pending: [0], }
  dfe_type_refs_module_roots(mod_, refs)
  let mut cursor = 0
  while cursor < refs.pending.length() {
    let flat_idx = refs.pending[cursor]
    if flat_idx == 0 {
      dfe_type_refs_rec_type(groups[0], refs)
    } else if flat_idx >= 2 {
      dfe_type_refs_rec_type(groups[flat_idx - 1], refs)
    }
    cursor += 1
  }
  let kept : Array[@lib.RecType] = []
  let remap : Map[UInt, UInt] = Map([])
  kept.push(groups[0])
  remap[0U] = 0U
  remap[1U] = 1U
  for idx = 1; idx < groups.length(); idx = idx + 1 {
    if refs.live[idx + 1] {
      remap[(idx + 1).to_uint()] = (kept.length() + 1).to_uint()
      kept.push(groups[idx])
    }
  }
  if kept.length() == groups.length() {
    return mod_
  }
  let candidate = dfe_rewrite_module_type_idxs(
    mod_.with_type_sec(@lib.TypeSec::new(kept)),
    remap,
  )
  // Type edits invalidate compiler facts. Compare the same encoded surfaces
  // so discarded facts cannot be mistaken for a code-size saving.
  let baseline = if mod_.compiler_fact_custom_section is Some(_) {
    mod_.without_compiler_fact_custom_section()
  } else {
    mod_
  }
  match @binary.encoded_module_sizes(baseline, candidate) {
    Ok((old_size, new_size)) if new_size < old_size =>
      if @validate.validate_module(candidate) is Ok(_) {
        return candidate
      }
    _ => ()
  }
  mod_
}
