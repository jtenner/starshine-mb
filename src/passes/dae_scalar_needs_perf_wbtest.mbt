///|
// Frozen v3 scanner; flat benchmark fixtures isolate the need stack.
fn dae_pure_suffix_array_reference(
  out : Array[@lib.Instruction],
  type_sec : @lib.TypeSec?,
) -> Int? {
  if out.length() == 0 {
    return None
  }
  // Need marker 0 accepts any recognized pure/nontrapping value stack.
  // Need marker 1 accepts only a stack ending in ref.i31, which constructs a
  // non-null i31 reference and makes i31.get/ref.as_non_null/ref.cast to
  // i31 supertypes nontrapping. Need marker 2 accepts only a stack ending in
  // ref.null, which makes nullable ref.cast nontrapping while still preserving
  // null-trapping ref.as_non_null and non-nullable ref.cast. Need marker 3 is
  // for nullable ref.cast targets that accept both null and ref.i31 roots.
  let needs : Array[Int] = [0]
  for start = out.length() - 1; start >= 0; start = start - 1 {
    let need = match needs.pop() {
      Some(v) => v
      None => return None
    }
    if need == 1 {
      match out[start] {
        @lib.RefI31 => needs.push(0)
        instr if dae_instr_is_i31_success_ref_cast(instr) => needs.push(1)
        _ => return None
      }
    } else if need == 2 {
      match out[start] {
        @lib.RefNull(_) => ()
        instr if dae_instr_is_nullable_ref_cast(instr) => needs.push(2)
        _ => return None
      }
    } else if need == 3 {
      match out[start] {
        @lib.RefNull(_) => ()
        @lib.RefI31 => needs.push(0)
        @lib.RefCast(true, _, ht) if dae_heap_type_accepts_i31_ref(ht) =>
          needs.push(3)
        instr if dae_instr_is_nullable_ref_cast(instr) => needs.push(2)
        _ => return None
      }
    } else {
      if start >= 1 &&
        needs.length() == 0 &&
        dae_instr_is_const_safe_float_to_int_unary(out[start - 1], out[start]) {
        return Some(start - 1)
      }
      if start >= 2 &&
        needs.length() == 0 &&
        dae_instr_is_const_safe_numeric_binary(
          out[start - 2],
          out[start - 1],
          out[start],
        ) {
        return Some(start - 2)
      }
      match out[start] {
        @lib.I31GetS | @lib.I31GetU => needs.push(1)
        @lib.RefAsNonNull => needs.push(1)
        @lib.RefCast(true, _, ht) if dae_heap_type_accepts_i31_ref(ht) =>
          needs.push(3)
        instr if dae_instr_is_i31_success_ref_cast(instr) => needs.push(1)
        instr if dae_instr_is_nullable_ref_cast(instr) => needs.push(2)
        _ =>
          match dae_instr_dropped_pure_value_arity(out[start], type_sec) {
            Some(arity) => {
              let mut input = 0
              while input < arity {
                needs.push(0)
                input += 1
              }
            }
            None => return None
          }
      }
    }
    if needs.length() == 0 {
      return Some(start)
    }
  }
  None
}

///|
fn dae_scalar_needs_bench(
  it : @bench.T,
  width : Int,
  refs : Bool,
  reference : Bool,
) -> Unit {
  let wat = ["(module (func (param i32) (result i32)"]
  if refs {
    wat.push("i32.const 7 ref.i31 i31.get_s")
  } else {
    wat.push("local.get 0")
  }
  for _ in 1..<width {
    if refs {
      wat.push("i32.const 7 ref.i31 i31.get_u i32.add")
    } else {
      wat.push("i32.const 1 i32.add")
    }
  }
  wat.push("))")
  let mod_ = pass_test_module_from_wat(wat.join(" "))
  let @lib.Func(_, @lib.Expr(body)) = mod_.code_sec.unwrap().0[0]
  let saved = @binary.encode_module(mod_).unwrap()
  let stacks = [0]
  if dae_pure_suffix_array_reference(body, mod_.type_sec) != Some(0) ||
    dae_find_droppable_pure_stack_expr_start_with_scalar_needs(
      body,
      mod_.type_sec,
      need_stacks=Some(stacks),
    ) !=
    Some(0) ||
    stacks[0] != (if refs { 1 } else { 0 }) {
    abort("scalar needs benchmark changed suffix or marker allocation")
  }
  if reference {
    it.bench(fn() {
      it.keep(dae_pure_suffix_array_reference(body, mod_.type_sec))
    })
  } else {
    it.bench(fn() {
      it.keep(dae_find_droppable_pure_stack_expr_start(body, mod_.type_sec))
    })
  }
  if @binary.encode_module(mod_).unwrap() != saved {
    abort("scalar needs benchmark changed its reusable input")
  }
}

///|
test "bench DAE suffix reference arithmetic width=1" (it : @bench.T) {
  dae_scalar_needs_bench(it, 1, false, true)
}

///|
test "bench DAE suffix scalar arithmetic width=1" (it : @bench.T) {
  dae_scalar_needs_bench(it, 1, false, false)
}

///|
test "bench DAE suffix reference arithmetic width=128" (it : @bench.T) {
  dae_scalar_needs_bench(it, 128, false, true)
}

///|
test "bench DAE suffix scalar arithmetic width=128" (it : @bench.T) {
  dae_scalar_needs_bench(it, 128, false, false)
}

///|
test "bench DAE suffix reference arithmetic width=4096" (it : @bench.T) {
  dae_scalar_needs_bench(it, 4096, false, true)
}

///|
test "bench DAE suffix scalar arithmetic width=4096" (it : @bench.T) {
  dae_scalar_needs_bench(it, 4096, false, false)
}

///|
test "bench DAE suffix reference reference operands width=1" (it : @bench.T) {
  dae_scalar_needs_bench(it, 1, true, true)
}

///|
test "bench DAE suffix scalar reference operands width=1" (it : @bench.T) {
  dae_scalar_needs_bench(it, 1, true, false)
}

///|
test "bench DAE suffix reference reference operands width=32" (it : @bench.T) {
  dae_scalar_needs_bench(it, 32, true, true)
}

///|
test "bench DAE suffix scalar reference operands width=32" (it : @bench.T) {
  dae_scalar_needs_bench(it, 32, true, false)
}
