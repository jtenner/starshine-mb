// Licensing scope: see ../../LICENSE and this directory's LICENSE and NOTICE.
// Potentially incorporated Binaryen expression retains Apache-2.0 terms.
// Original Starshine contributions use the scoped MIT grant in ../../LICENSE.
// Modified for Starshine through 2026: implementation and validation use
// Starshine's representations and APIs; this is not an unchanged upstream file.
// Conservative notice retention does not establish copying or independence.

///|
// The shared DFE remapper predates several proposal instructions. Admit only
// instructions whose type references it scans and rewrites, including children.
// Scalar i32.add carries no type index and is preserved unchanged.
fn precompute_type_cleanup_instrs_supported(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Block(_, _) | @lib.Loop(_, _) | @lib.If(_, _, _) => {
        let mut supported = true
        ignore(
          pass_lower_map_children(instr, fn(body) {
            if !precompute_type_cleanup_instrs_supported(body) {
              supported = false
            }
            body
          }),
        )
        if !supported {
          return false
        }
      }
      @lib.Unreachable
      | @lib.Nop
      | @lib.Drop
      | @lib.Return
      | @lib.Br(_)
      | @lib.BrIf(_)
      | @lib.BrTable(_, _)
      | @lib.Call(_)
      | @lib.CallIndirect(_, _)
      | @lib.CallRef(_)
      | @lib.ReturnCall(_)
      | @lib.ReturnCallIndirect(_, _)
      | @lib.ReturnCallRef(_)
      | @lib.LocalGet(_)
      | @lib.LocalSet(_)
      | @lib.LocalTee(_)
      | @lib.GlobalGet(_)
      | @lib.GlobalSet(_)
      | @lib.I32Add
      | @lib.I32Const(_)
      | @lib.I64Const(_)
      | @lib.F32Const(_)
      | @lib.F64Const(_)
      | @lib.Select(_)
      | @lib.RefNull(_)
      | @lib.RefFunc(_)
      | @lib.RefIsNull
      | @lib.RefEq
      | @lib.RefAsNonNull
      | @lib.RefI31
      | @lib.RefTest(_, _, _)
      | @lib.RefCast(_, _, _)
      | @lib.StructNew(_)
      | @lib.StructNewDefault(_)
      | @lib.StructGet(_, _)
      | @lib.StructGetS(_, _)
      | @lib.StructGetU(_, _)
      | @lib.StructSet(_, _)
      | @lib.ArrayNew(_)
      | @lib.ArrayNewDefault(_)
      | @lib.ArrayNewFixed(_, _)
      | @lib.ArrayGet(_)
      | @lib.ArrayGetS(_)
      | @lib.ArrayGetU(_)
      | @lib.ArraySet(_)
      | @lib.ArrayLen => ()
      _ => return false
    }
  }
  true
}

///|
fn precompute_type_cleanup_supported(mod_ : @lib.Module) -> Bool {
  // Ordinary custom sections are opaque here. They may encode type indices or
  // section-relative offsets (for example branch hints, DWARF, or reloc.CODE),
  // and the simple-type remapper cannot update those payloads.
  if !mod_.custom_secs.is_empty() {
    return false
  }
  let types = match mod_.type_sec {
    Some(@lib.TypeSec(types)) => types
    None => return false
  }
  let mut has_gc = false
  for rec_type in types {
    match rec_type {
      @lib.SingleRecType(subtype) => {
        if subtype.metadata().is_shared() ||
          !subtype.super_types().is_empty() ||
          subtype.describes_type() is Some(_) ||
          subtype.descriptor_type() is Some(_) {
          return false
        }
        match subtype.get_comptype() {
          @lib.FuncCompType(params, results) =>
            if dfe_val_types_mention_type_idxs(params) ||
              dfe_val_types_mention_type_idxs(results) {
              return false
            }
          @lib.ArrayCompType(field) => {
            if dfe_field_type_mentions_type_idxs(field) {
              return false
            }
            has_gc = true
          }
          @lib.StructCompType(fields) => {
            if dfe_field_types_mention_type_idxs(fields) {
              return false
            }
            has_gc = true
          }
          _ => return false
        }
      }
      @lib.GroupRecType(_) => return false
    }
  }
  if !has_gc {
    return false
  }
  pass_type_cleanup_reference_surfaces_supported(mod_)
}

///|
fn precompute_cleanup_code_changed(
  original : @lib.Module,
  mod_ : @lib.Module,
) -> Bool {
  let old_funcs = match original.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return false
  }
  let new_funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return false
  }
  if old_funcs.length() != new_funcs.length() {
    return true
  }
  for index, old_func in old_funcs {
    let new_func = new_funcs[index]
    if physical_equal(old_func, new_func) {
      continue
    }
    let @lib.Func(old_locals, @lib.Expr(old_body)) = old_func
    let @lib.Func(new_locals, @lib.Expr(new_body)) = new_func
    if old_locals != new_locals ||
      !pass_const_instruction_vectors_bits_equal(old_body, new_body) {
      return true
    }
  }
  false
}

///|
// Run only after writeback repair: pruning can remap types in untouched bodies.
// Compare literal bits directly; IEEE NaN equality is unsuitable here.
fn precompute_cleanup_unused_gc_types(
  original : @lib.Module,
  mod_ : @lib.Module,
) -> @lib.Module {
  if !precompute_type_cleanup_supported(mod_) {
    return mod_
  }
  if !precompute_cleanup_code_changed(original, mod_) {
    return mod_
  }
  let named = if mod_.name_sec is None {
    match mod_.raw_name_sec_payload {
      Some(payload) => {
        let decoded : Result[(@lib.NameSec, Int32), @binary.BinaryDecodeError] = @binary.Decode::decode(
          payload, 0,
        )
        match decoded {
          Ok((names, end)) if end == payload.length() =>
            mod_.with_name_sec(names)
          // Prepare only the candidate without opaque names. If pruning does
          // not commit, return the original module with its payload unchanged.
          _ => mod_.without_name_sec()
        }
      }
      None => mod_
    }
  } else {
    mod_
  }
  let pruned = dfe_prune_unused_simple_types(named)
  if physical_equal(named, pruned) {
    return mod_
  }
  // Raw-only input metadata must participate in both sides of the size test.
  match @binary.encoded_module_sizes(named, pruned) {
    Ok((before, after)) if after < before =>
      if @validate.validate_module(pruned) is Ok(_) {
        return pruned
      }
    _ => ()
  }
  mod_
}
