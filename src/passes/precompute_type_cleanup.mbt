///|
// The shared DFE remapper predates several proposal instructions. Admit only
// instructions whose type references it scans and rewrites, including children.
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
// Run only after writeback repair: pruning changes every surviving type index,
// including functions outside the touched set. Byte equality avoids NaN != NaN.
fn precompute_cleanup_unused_gc_types(
  original : @lib.Module,
  mod_ : @lib.Module,
) -> @lib.Module {
  if !precompute_type_cleanup_supported(mod_) {
    return mod_
  }
  let old_code = match original.code_sec {
    Some(code) => @binary.encode_module(@lib.Module::new().with_code_sec(code))
    None => return mod_
  }
  let new_code = match mod_.code_sec {
    Some(code) => @binary.encode_module(@lib.Module::new().with_code_sec(code))
    None => return mod_
  }
  match (old_code, new_code) {
    (Ok(old_bytes), Ok(new_bytes)) if old_bytes != new_bytes => ()
    _ => return mod_
  }
  let pruned = dfe_prune_unused_simple_types(mod_)
  match (@binary.encode_module(mod_), @binary.encode_module(pruned)) {
    (Ok(before), Ok(after)) if after.length() < before.length() =>
      if @validate.validate_module(pruned) is Ok(_) {
        return pruned
      }
    _ => ()
  }
  mod_
}
